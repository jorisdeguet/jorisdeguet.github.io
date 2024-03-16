

from shared import click_by_id, setup, select_parc_ex, select_type, selectPrice, startSearch, explore_and_send

driver = setup()
driver.get("https://www.centris.ca/")
driver.implicitly_wait(5)
click_by_id(driver, "didomi-notice-agree-button")   # accept cookies


select_parc_ex(driver)
selectPrice(driver, 29)         # 29 is 700 000
select_type(driver, "PropertyType-SingleFamilyHome-input")
startSearch(driver)

explore_and_send(driver, "Maison", "/mnt/Photos/maison")
driver.quit()
