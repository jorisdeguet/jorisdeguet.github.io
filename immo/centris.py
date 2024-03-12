import time

from selenium.webdriver import ActionChains, Keys
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.wait import WebDriverWait

from shared import click_data_target, click_by_id, setup


def startSearch(driver):
    search_button = driver.find_element(by=By.CLASS_NAME, value="js-trigger-search")
    driver.execute_script("arguments[0].click();", search_button)

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
            # driver.implicitly_wait(10)
        # driver.implicitly_wait(5)
    #driver.implicitly_wait(5)




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

# TODO go get everything since yesterday or last date in folder
addresses = []
while(True):
    time.sleep(3)
    WebDriverWait(driver, 10).until(
        EC.visibility_of_element_located((By.CSS_SELECTOR, ".col-12 > #divWrapperPager .next > a")))
    nextButton = driver.find_element(By.CSS_SELECTOR, ".col-12 > #divWrapperPager .next > a")
    print("nextButton is " + str(nextButton))
    elements = driver.find_elements(By.CLASS_NAME, 'address')
    duplicate = False
    for e in elements:
        if addresses.count(e.text) == 0:
            addresses.append(e.text)
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

driver.quit()