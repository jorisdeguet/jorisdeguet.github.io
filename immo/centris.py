
from selenium.webdriver import ActionChains
from selenium.webdriver.common.by import By

from immo.shared import click_data_target, click_by_id, setup


def startSearch(driver):
    search_button = driver.find_element(by=By.CLASS_NAME, value="js-trigger-search")
    search_button.click()

def selectLastModified(driver, date):
    # get the text field for LastModifiedDate-dateFilterPicker
    last_modified_date = driver.find_element(by=By.ID, value="LastModifiedDate-dateFilterPicker")
    last_modified_date.send_keys(date)


# type be in "PropertyType-Plex-input" "PropertyType-SingleFamilyHome-input" "PropertyType-Chalet-input"
def select_type(driver, type):
    # TYPE OF PROPERTY
    click_data_target("#PropertyTypeSection-secondary")
    click_by_id(driver, type)
    driver.implicitly_wait(5)




def minArea(driver, squarefeet):
    click_data_target("#OtherCriteriaSection-secondary")
    land_area_min = driver.find_element(by=By.ID, value="LandArea-min")
    land_area_min.send_keys(str(squarefeet))

def selectPrice(driver, value):
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




driver = setup()
driver.get("https://www.centris.ca/")
driver.implicitly_wait(5)
click_by_id(driver, "didomi-notice-agree-button")   # accept cookies

#### Price is right  #### 17 is 300 000, 33 is 900 000
selectPrice(driver, 33)


#### Dates and types ####
click_by_id(driver, "filter-search")
select_type(driver, "PropertyType-Plex-input")
# TODO select Parc-Extension as location

# minArea(driver, 50000)
# TODO go get everything since yesterday or last date in folder
selectLastModified(driver, "2024-02-06")

startSearch(driver)

print(driver.current_url)

# get all element with class "a-more-detail"
# iterate until there is no more "More" button
while(True):
    elements = driver.find_elements(By.CLASS_NAME, 'a-more-detail')

    for e in elements:
        print(e.text)



driver.quit()