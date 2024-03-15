import datetime
import time
from dataclasses import dataclass

# TODO regarder dans les fichiers AAAA-MM-JJ.txt si on a déjà vu cette annonce
# TODO fix un provider de courriel pour envoyer le fichier texte
# TODO always add Nouveau prix

import mailchimp_transactional as MailchimpTransactional
from mailchimp_transactional.api_client import ApiClientError

from selenium.webdriver import ActionChains, Keys
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.wait import WebDriverWait

import os
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail

from immo.test_twilio import send_sms
from shared import click_data_target, click_by_id, setup


@dataclass
class Item:
    url: str
    date: datetime

def startSearch(driver):
    search_button = driver.find_element(by=By.CLASS_NAME, value="js-trigger-search")
    driver.execute_script("arguments[0].click();", search_button)

def alreadySeen(url):
    # open file duplex in current folder
    with open("./immo/duplex", "r") as file:
        # read all lines into a list
        lines = file.readlines()
        # check if the url is in the list
        if url+"\n" in lines:
            return True
    return False

def selectLastModified(driver, date):
    # get the text field for LastModifiedDate-dateFilterPicker
    click_by_id(driver, "filter-search")
    click_data_target(driver, "#OtherCriteriaSection-secondary")

    WebDriverWait(driver, 10).until(
        EC.visibility_of_element_located((By.CSS_SELECTOR, "#OtherCriteriaSection-heading-filters .btn")))
    bouton = driver.find_element(By.CSS_SELECTOR, "#OtherCriteriaSection-heading-filters .btn")
    driver.execute_script("arguments[0].click();", bouton)
    driver.find_element(By.CSS_SELECTOR, ".calendar-icon").click()
    driver.find_element(By.ID, "LastModifiedDate-dateFilterPicker").click()
    driver.find_element(By.ID, "LastModifiedDate-dateFilterPicker").send_keys(date)
    driver.find_element(By.ID, "LastModifiedDate-dateFilterPicker").send_keys(Keys.ENTER)
    driver.find_element(By.CSS_SELECTOR, ".btn-search:nth-child(3)").click()
    last_modified_date = driver.find_element(by=By.ID, value="LastModifiedDate-dateFilterPicker")
    last_modified_date.send_keys(date)
#    driver.find_element(By.CSS_SELECTOR, "#OtherCriteriaSection-heading-filters .btn").click()
    click_by_id(driver, "filter-search")


# type be in "PropertyType-Plex-input" "PropertyType-SingleFamilyHome-input" "PropertyType-Chalet-input"
def select_type(driver, type):
    click_by_id(driver, "filter-search")
    driver.find_element(By.CSS_SELECTOR, "#OtherCriteriaSection-heading-filters .btn").click()
    # TYPE OF PROPERTY
    click_data_target(driver,"#PropertyTypeSection-secondary")
    click_by_id(driver, type)
    driver.implicitly_wait(5)
    driver.find_element(By.CSS_SELECTOR, "#OtherCriteriaSection-heading-filters .btn").click()
    click_by_id(driver, "filter-search")

def select_parc_ex(driver):
    #field = driver.find_element(By.CLASS_NAME, "select2-search__field")
    search_container = driver.find_element(By.CSS_SELECTOR, ".select2-selection__rendered")
    driver.execute_script("arguments[0].click();", search_container)
    driver.implicitly_wait(5)
    #driver.find_element(By.CLASS_NAME, "select2-search__field").click()
    WebDriverWait(driver, 10).until(
        EC.visibility_of_element_located((By.CLASS_NAME, "select2-search__field")))

    driver.find_element(By.CLASS_NAME, "select2-search__field").send_keys("parc-ex")
    # wait until the included search settles
    WebDriverWait(driver, 10).until(
        EC.visibility_of_element_located((By.CLASS_NAME, "select2-search__field")))
    time.sleep(3)
    driver.find_element(By.CLASS_NAME, "select2-search__field").send_keys(Keys.ENTER)
    WebDriverWait(driver, 10).until(
        EC.visibility_of_element_located((By.CLASS_NAME, "select2-search__field")))
    driver.implicitly_wait(5)
    # target = driver.find_element(By.CSS_SELECTOR, "#filter-search > span")
    # driver.execute_script("arguments[0].click();", target)



def minArea(driver, squarefeet):
    land_area_min = driver.find_element(by=By.ID, value="LandArea-min")
    land_area_min.send_keys(str(squarefeet))

def selectPrice(driver, value):
    # price selection
    click_by_id(driver, "SalePrice-button")
    # get the div with class "max-slider-handle"
    max_price = driver.find_element(by=By.CLASS_NAME, value="max-slider-handle")
    move = ActionChains(driver)
    move.click_and_hold(max_price).move_by_offset(-20, 0).release().perform()
    # move the slider to the left until aria-valuenow is 17
    for i in range(200):
        print(str(max_price.get_attribute("aria-valuenow")))
        if max_price.get_attribute("aria-valuenow") <= str(value):
            break
        else:
            # move the slider to the left
            move = ActionChains(driver)
            move.click_and_hold(max_price).move_by_offset(-5, 0).release().perform()

driver = setup()
driver.get("https://www.centris.ca/")
driver.implicitly_wait(5)
click_by_id(driver, "didomi-notice-agree-button")   # accept cookies


select_parc_ex(driver)
#### Price is right  #### 17 is 300 000, 33 is 900 000
selectPrice(driver, 33)
#### Dates and types ####
select_type(driver, "PropertyType-Plex-input")
#selectLastModified(driver, "2024-03-10")

startSearch(driver)

print(driver.current_url)

# get all element with class "a-more-detail"
# iterate until there is no more "More" button

# create the data folder if it does not exist

# TODO go get everything since yesterday or last date in folder
addresses = []
urls = []
while(True):
    time.sleep(2)
    WebDriverWait(driver, 10).until(
        EC.visibility_of_element_located((By.CSS_SELECTOR, ".col-12 > #divWrapperPager .next > a")))
    nextButton = driver.find_element(By.CSS_SELECTOR, ".col-12 > #divWrapperPager .next > a")
    print("nextButton is " + str(nextButton))
    #elements = driver.find_elements(By.CLASS_NAME, 'address')
    elements = driver.find_elements(By.CSS_SELECTOR, ".shell")
    duplicate = False
    for e in elements:
        addressElement = e.find_element(By.CLASS_NAME, 'address')
        url = e.find_element(By.TAG_NAME, 'a').get_attribute("href")
        urls.append(url)
        # get today's date as YYYY-MM-DD
        today = datetime.date.today().strftime("%Y-%m-%d")
        print(url)
        # transform the relative url into an absolute url

        if addresses.count(addressElement.text) == 0:
            addresses.append(addressElement.text)
        else:
            duplicate = True
            break
    if duplicate:
        break
    try:
        #nextButton.click()
        driver.execute_script("arguments[0].click();", nextButton)
    except:
        print("ouch")
for ad in sorted(addresses):
    print(ad)
#print(sorted(addresses))
# join urls with newlines
onlyTheNew = []
for url in urls:
    if alreadySeen(url):
        print("seen")
    else:
        onlyTheNew.append(url)
        print("not seen " + url)
urls = onlyTheNew
chunks = [urls[i:i + 10] for i in range(0, len(urls), 10)]
for chunk in chunks:
    url_list = '\n'.join(chunk)
    #send_sms(url_list)


driver.quit()