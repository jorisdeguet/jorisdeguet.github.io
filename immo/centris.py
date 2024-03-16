
from shared import click_by_id, setup,  select_parc_ex, select_type, \
    startSearch, selectPrice, explore_and_send

driver = setup()
driver.get("https://www.centris.ca/")
driver.implicitly_wait(5)
click_by_id(driver, "didomi-notice-agree-button")   # accept cookies

select_parc_ex(driver)
selectPrice(driver, 33)   # 33 is 900 000
select_type(driver, "PropertyType-Plex-input")
startSearch(driver)

explore_and_send(driver, "Duplex", "/mnt/Photos/duplex")
driver.quit()
