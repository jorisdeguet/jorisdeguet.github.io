
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.action_chains import ActionChains

class TestDuproprio():
  def setup_method(self, method):
    self.driver = webdriver.Chrome()
    self.vars = {}
  
  def teardown_method(self, method):
    self.driver.quit()
  
  def test_duproprio(self):
    self.driver.get("https://duproprio.com/en")
    self.driver.set_window_size(1359, 875)
    self.driver.find_element(By.CSS_SELECTOR, ".Types__SearchTypesStyled-sc-pineeu-0 > .sc-gsFSXq").click()
    self.driver.find_element(By.CSS_SELECTOR, "li:nth-child(1) > .TypesPopoverOption__SearchTypesPopoverOptionTypeStyled-sc-1ppo7b8-1 rect").click()
    self.driver.find_element(By.CSS_SELECTOR, "li:nth-child(3) .AdvancedCheckbox__Label-sc-8xasvc-0").click()
    self.driver.find_element(By.CSS_SELECTOR, ".PriceRange__PriceRangeStyled-sc-163co5r-0 > .sc-gsFSXq").click()
    element = self.driver.find_element(By.CSS_SELECTOR, ".noUi-active > .noUi-touch-area")
    actions = ActionChains(self.driver)
    actions.move_to_element(element).click_and_hold().perform()
    element = self.driver.find_element(By.CSS_SELECTOR, ".noUi-active > .noUi-touch-area")
    actions = ActionChains(self.driver)
    actions.move_to_element(element).perform()
    element = self.driver.find_element(By.CSS_SELECTOR, ".noUi-active > .noUi-touch-area")
    actions = ActionChains(self.driver)
    actions.move_to_element(element).release().perform()
    self.driver.find_element(By.CSS_SELECTOR, ".PriceRangeSlider__PriceRangeWrapperStyled-sc-14js1is-1:nth-child(1) .noUi-origin:nth-child(3) .noUi-touch-area").click()
    self.driver.find_element(By.CSS_SELECTOR, ".hrJbIL #search-field__form__input").click()
    self.driver.find_element(By.CSS_SELECTOR, ".hrJbIL #search-field__form__input").click()
    element = self.driver.find_element(By.CSS_SELECTOR, ".hrJbIL #search-field__form__input")
    actions = ActionChains(self.driver)
    actions.double_click(element).perform()
    element = self.driver.find_element(By.CSS_SELECTOR, ".Base__SearchBarTagsStyled-sc-kdbjwa-6 .StyledTag__StyledTagButtonWrapper-sc-1oikr97-0:nth-child(2) > .StyledTag__StyledTagLabel-sc-1oikr97-1")
    actions = ActionChains(self.driver)
    actions.move_to_element(element).perform()
    element = self.driver.find_element(By.CSS_SELECTOR, "body")
    actions = ActionChains(self.driver)
    actions.move_to_element(element, 0, 0).perform()
    self.driver.find_element(By.CSS_SELECTOR, ".hrJbIL #search-field__form__input").send_keys("Parc-exten")
    self.driver.find_element(By.CSS_SELECTOR, ".Results__SearchResultsLabelStyled-sc-wz8a02-9 rect").click()
    self.driver.find_element(By.CSS_SELECTOR, ".sc-gsFSXq:nth-child(5)").click()
    self.driver.find_element(By.LINK_TEXT, "List").click()
    self.driver.find_element(By.CSS_SELECTOR, ".featured-builder__content").click()
    self.driver.close()
  
