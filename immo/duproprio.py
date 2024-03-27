import time

from selenium.webdriver import ActionChains
from selenium.webdriver.common.by import By

from shared import click_by_id, setup, click_by_class

from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.wait import WebDriverWait


def searchParcEx():
    WebDriverWait(driver, 10).until(
        EC.visibility_of_element_located((By.CSS_SELECTOR, "#search-field__form__input")))
    searchField = driver.find_element(By.CSS_SELECTOR, "#search-field__form__input")
    driver.execute_script("arguments[0].click();", searchField)
    driver.implicitly_wait(5)

    # driver.find_element(By.CLASS_NAME, "select2-search__field").click()

    time.sleep(3)
    searchField.send_keys("parc-ex")
    # wait until the included search settles
    WebDriverWait(driver, 10).until(
        EC.visibility_of_element_located((By.CLASS_NAME, "select2-search__field")))
    time.sleep(3)
    driver.find_element(By.CLASS_NAME, "select2-search__field").send_keys(Keys.ENTER)
    WebDriverWait(driver, 10).until(
        EC.visibility_of_element_located((By.CLASS_NAME, "select2-search__field")))
    driver.implicitly_wait(5)

    driver.find_element(By.CSS_SELECTOR, "#search-field__form__input").click()
    driver.find_element(By.CSS_SELECTOR, "#search-field__form__input").click()
    element = driver.find_element(By.CSS_SELECTOR, " #search-field__form__input")
    actions = ActionChains(driver)
    actions.double_click(element).perform()
    element = driver.find_element(By.CSS_SELECTOR,
                                  ".Base__SearchBarTagsStyled-sc-kdbjwa-6 .StyledTag__StyledTagButtonWrapper-sc-1oikr97-0:nth-child(2) > .StyledTag__StyledTagLabel-sc-1oikr97-1")
    actions = ActionChains(driver)
    actions.move_to_element(element).perform()
    element = driver.find_element(By.CSS_SELECTOR, "body")
    actions = ActionChains(driver)
    actions.move_to_element(element, 0, 0).perform()
    driver.find_element(By.CSS_SELECTOR, "#search-field__form__input").send_keys("Parc-exten")


def resultsAsList():
    driver.find_element(By.CSS_SELECTOR, ".Results__SearchResultsLabelStyled-sc-wz8a02-9 rect").click()
    driver.find_element(By.CSS_SELECTOR, ".sc-gsFSXq:nth-child(5)").click()
    driver.find_element(By.LINK_TEXT, "List").click()
    driver.find_element(By.CSS_SELECTOR, ".featured-builder__content").click()

driver = setup()
driver.get("https://duproprio.com/fr/rechercher/liste")
driver.implicitly_wait(5)
click_by_id(driver, "onetrust-accept-btn-handler")   # accept cookies
# click_by_class(driver, "bByjIz")


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