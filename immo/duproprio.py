import time

from selenium.webdriver import ActionChains
from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium import webdriver
from selenium.webdriver.common.by import By



def searchParcEx():
    global element, actions
    driver.find_element(By.CSS_SELECTOR, ".hrJbIL #search-field__form__input").click()
    driver.find_element(By.CSS_SELECTOR, ".hrJbIL #search-field__form__input").click()
    element = driver.find_element(By.CSS_SELECTOR, ".hrJbIL #search-field__form__input")
    actions = ActionChains(driver)
    actions.double_click(element).perform()
    element = driver.find_element(By.CSS_SELECTOR,
                                  ".Base__SearchBarTagsStyled-sc-kdbjwa-6 .StyledTag__StyledTagButtonWrapper-sc-1oikr97-0:nth-child(2) > .StyledTag__StyledTagLabel-sc-1oikr97-1")
    actions = ActionChains(driver)
    actions.move_to_element(element).perform()
    element = driver.find_element(By.CSS_SELECTOR, "body")
    actions = ActionChains(driver)
    actions.move_to_element(element, 0, 0).perform()
    driver.find_element(By.CSS_SELECTOR, ".hrJbIL #search-field__form__input").send_keys("Parc-exten")



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


def resultsAsList():
    driver.find_element(By.CSS_SELECTOR, ".Results__SearchResultsLabelStyled-sc-wz8a02-9 rect").click()
    driver.find_element(By.CSS_SELECTOR, ".sc-gsFSXq:nth-child(5)").click()
    driver.find_element(By.LINK_TEXT, "List").click()
    driver.find_element(By.CSS_SELECTOR, ".featured-builder__content").click()



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

def click_by_class(class_name):
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
driver.get("https://duproprio.com/")
driver.implicitly_wait(5)
click_by_id("onetrust-accept-btn-handler")   # accept cookies
click_by_class("bByjIz")
#
# click_by_class("ikKuLf")
# click_by_class("hvNUuP")


searchParcEx()


resultsAsList()
#
#
# driver.find_element(By.CSS_SELECTOR, ".Types__SearchTypesStyled-sc-pineeu-0 > .sc-gsFSXq").click()
# driver.find_element(By.CSS_SELECTOR,
#                          "li:nth-child(1) > .TypesPopoverOption__SearchTypesPopoverOptionTypeStyled-sc-1ppo7b8-1 rect").click()
# driver.find_element(By.CSS_SELECTOR, "li:nth-child(3) .AdvancedCheckbox__Label-sc-8xasvc-0").click()
# driver.find_element(By.CSS_SELECTOR, ".PriceRange__PriceRangeStyled-sc-163co5r-0 > .sc-gsFSXq").click()
# element = driver.find_element(By.CSS_SELECTOR, ".noUi-active > .noUi-touch-area")
# actions = ActionChains(driver)
# actions.move_to_element(element).click_and_hold().perform()
# element = driver.find_element(By.CSS_SELECTOR, ".noUi-active > .noUi-touch-area")
# actions = ActionChains(driver)
# actions.move_to_element(element).perform()
# element = driver.find_element(By.CSS_SELECTOR, ".noUi-active > .noUi-touch-area")
# actions = ActionChains(driver)
# actions.move_to_element(element).release().perform()
# driver.find_element(By.CSS_SELECTOR,
#                          ".PriceRangeSlider__PriceRangeWrapperStyled-sc-14js1is-1:nth-child(1) .noUi-origin:nth-child(3) .noUi-touch-area").click()
#



driver.quit()