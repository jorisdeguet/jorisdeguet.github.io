import time

from selenium.webdriver import Keys, ActionChains
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.wait import WebDriverWait

from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium import webdriver

from test_twilio import send_sms


def setup():
    options = ChromeOptions()
    #options.add_argument("--headless=new")
    options.add_argument("--window-size=1000,1000")
    #options.add_argument("--start-maximized")
    options.add_argument("--disable-gpu")
    options.add_argument(
        "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36")
    driver = webdriver.Chrome(options=options)
    driver.delete_all_cookies()
    return driver

def click_data_target(driver, data_target):
    for i in range(3):
        try:
            secondary_button = driver.find_element(by=By.CSS_SELECTOR,
                                                   value="[data-target='"+data_target+"']")
            driver.execute_script("arguments[0].click();", secondary_button)
            break
        except Exception as inst:
            print(inst)
            print('Retry in 1 second')
            time.sleep(1)
    driver.implicitly_wait(5)

def click_by_id(driver, id):
    for i in range(3):
        try:
            element = driver.find_element(by=By.ID, value=id)
            driver.execute_script("arguments[0].click();", element)
            break
        except Exception as inst:
            print(inst)
            print('Retry in 1 second')
            # sleep for 1 second
            time.sleep(1)
    driver.implicitly_wait(5)


def click_by_class(driver, class_name):
    for i in range(3):
        try:
            element = driver.find_element(by=By.CLASS_NAME, value=class_name)
            driver.execute_script("arguments[0].click();", element)
            break
        except Exception as inst:
            print(inst)
            print('Retry in 1 second')
            # sleep for 1 second
            time.sleep(1)
    driver.implicitly_wait(5)


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


def startSearch(driver):
    search_button = driver.find_element(by=By.CLASS_NAME, value="js-trigger-search")
    driver.execute_script("arguments[0].click();", search_button)





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

    driver.find_element(By.CLASS_NAME, "select2-search__field").send_keys("Parc-Extension P")
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



def alreadySeen(url, filePath="/mnt/Photos/duplex"):
    # open file duplex in current folder
    try:
        with open(filePath, "r") as file:
            # read all lines into a list
            lines = file.readlines()
            # check if the url is in the list
            if url+"\n" in lines:
                return True
        return False
    except Exception as e:
        print(e)
        return False

def addToAlreadySeen(newOnes, filePath="/mnt/Photos/duplex"):
    try:
        with open(filePath, "a") as file:
            file.write("\n\nnew entry \n\n")
            for url in newOnes:
                file.write(url + "\n")
    except Exception as e:
        print(e)

# ATTENTION, marche sur MacOS mais pas sur Ubuntu en headless
# def selectLastModified(driver, date):
#     # get the text field for LastModifiedDate-dateFilterPicker
#     click_by_id(driver, "filter-search")
#     click_data_target(driver, "#OtherCriteriaSection-secondary")
#
#     WebDriverWait(driver, 10).until(
#         EC.visibility_of_element_located((By.CSS_SELECTOR, "#OtherCriteriaSection-heading-filters .btn")))
#     bouton = driver.find_element(By.CSS_SELECTOR, "#OtherCriteriaSection-heading-filters .btn")
#     driver.execute_script("arguments[0].click();", bouton)
#     driver.find_element(By.CSS_SELECTOR, ".calendar-icon").click()
#     driver.find_element(By.ID, "LastModifiedDate-dateFilterPicker").click()
#     driver.find_element(By.ID, "LastModifiedDate-dateFilterPicker").send_keys(date)
#     driver.find_element(By.ID, "LastModifiedDate-dateFilterPicker").send_keys(Keys.ENTER)
#     driver.find_element(By.CSS_SELECTOR, ".btn-search:nth-child(3)").click()
#     last_modified_date = driver.find_element(by=By.ID, value="LastModifiedDate-dateFilterPicker")
#     last_modified_date.send_keys(date)
# #    driver.find_element(By.CSS_SELECTOR, "#OtherCriteriaSection-heading-filters .btn").click()
#     click_by_id(driver, "filter-search")



def explore_and_send(driver, text, filePath):
    addresses = []
    urls = []
    onlyTheNew = []
    while (True):
        time.sleep(2)
        WebDriverWait(driver, 10).until(
            EC.visibility_of_element_located((By.CSS_SELECTOR, ".col-12 > #divWrapperPager .next > a")))
        nextButton = driver.find_element(By.CSS_SELECTOR, ".col-12 > #divWrapperPager .next > a")
        print("nextButton is " + str(nextButton))
        # elements = driver.find_elements(By.CLASS_NAME, 'address')
        elements = driver.find_elements(By.CSS_SELECTOR, ".shell")
        duplicate = False
        for e in elements:
            addressElement = e.find_element(By.CLASS_NAME, 'address')
            url = e.find_element(By.TAG_NAME, 'a').get_attribute("href")
            urls.append(url)
            print(url)
            # transform the relative url into an absolute url
            if "Nouveau prix" in e.text:
                onlyTheNew.append(url)
            if addresses.count(addressElement.text) == 0:
                addresses.append(addressElement.text)
            else:
                duplicate = True
                break
        if duplicate:
            break
        try:
            driver.execute_script("arguments[0].click();", nextButton)
        except:
            print("ouch")
    for ad in sorted(addresses):
        print(ad)
    for url in urls:
        if alreadySeen(url, filePath):
            print("seen")
        else:
            onlyTheNew.append(url)
            print("not seen " + url)
    # marked as already seen
    addToAlreadySeen(urls, filePath)
    return onlyTheNew

