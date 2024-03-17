
from shared import click_by_id, setup,  select_parc_ex, select_type, \
    startSearch, selectPrice, explore_and_send

# pour ubuntu, en headless, certains trucs ne marchent pas
# il fallait le driver avec la bonne version de chrome
# uniquement trouvé le driver pour la version  ici
# https://chrome-versions.com/google-chrome-stable-114.0.5735.90-1.deb
# https://chromedriver.storage.googleapis.com/index.html?path=114.0.5735.90/
# TODO regarder https://googlechromelabs.github.io/chrome-for-testing/#stable

# si on met à jour Chrome, le script ne marche plus

# le script va sur la page, met les critères re recherche, itère sur les pages
# collecte les urls, compare avec les urls connues, envoie un sms si nouvelle url

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
