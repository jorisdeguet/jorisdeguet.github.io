import time

from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium import webdriver
from selenium.webdriver import ActionChains
from selenium.webdriver.common.by import By


def select_type():
    # TYPE OF PROPERTY
    click_data_target("#PropertyTypeSection-secondary")
    # click_by_id("PropertyType-SingleFamilyHome-input")
    click_by_id("PropertyType-Plex-input")
    # click_by_id("PropertyType-HobbyFarm-input")
    # click_by_id("PropertyType-Chalet-input")
    driver.implicitly_wait(5)

def click_data_target(data_target):
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


def minArea(squarefeet):
    click_data_target("#OtherCriteriaSection-secondary")
    land_area_min = driver.find_element(by=By.ID, value="LandArea-min")
    land_area_min.send_keys(str(squarefeet))


def click_by_id(id):
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


def setup():
    global driver
    options = ChromeOptions()
    # options.add_argument("--headless=new")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--disable-gpu")
    options.add_argument(
        "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36")
    driver = webdriver.Chrome(options=options)
    driver.delete_all_cookies()


setup()
driver.get("https://www.centris.ca/")
driver.implicitly_wait(5)
click_by_id("didomi-notice-agree-button")   # accept cookies


def selectPrice(value):
    # price selection
    click_by_id("SalePrice-button")
    # get the div with class "max-slider-handle"
    max_price = driver.find_element(by=By.CLASS_NAME, value="max-slider-handle")
    move = ActionChains(driver)
    move.click_and_hold(max_price).move_by_offset(-75, 0).release().perform()
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
    driver.implicitly_wait(5)


# 17 is 300 000, 33 is 900 000
selectPrice(33)

click_by_id("filter-search")





select_type()
minArea(50000)
# get the text field for LastModifiedDate-dateFilterPicker
last_modified_date = driver.find_element(by=By.ID, value="LastModifiedDate-dateFilterPicker")
last_modified_date.send_keys("2024-02-06")

# find button "Rechercher" by class
search_button = driver.find_element(by=By.CLASS_NAME, value = "js-trigger-search")
search_button.click()

# get all element with class "a-more-detail"




print(driver.current_url)
#driver.quit()