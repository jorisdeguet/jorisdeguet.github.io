import datetime
import time

# TODO always add Nouveau prix

from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.wait import WebDriverWait


from test_twilio import send_sms
from shared import click_by_id, setup, select_parc_ex, select_type, selectPrice, startSearch, alreadySeen, \
    addToAlreadySeen

driver = setup()
driver.get("https://www.centris.ca/")
driver.implicitly_wait(5)
click_by_id(driver, "didomi-notice-agree-button")   # accept cookies


select_parc_ex(driver)
selectPrice(driver, 29)         # 29 is 700 000
select_type(driver, "PropertyType-SingleFamilyHome-input")
startSearch(driver)

addresses = []
urls = []
while(True):
    time.sleep(2)
    WebDriverWait(driver, 10).until(
        EC.visibility_of_element_located((By.CSS_SELECTOR, ".col-12 > #divWrapperPager .next > a")))
    nextButton = driver.find_element(By.CSS_SELECTOR, ".col-12 > #divWrapperPager .next > a")
    print("nextButton is " + str(nextButton))
    #elements = driver.find_elements(By.CLASS_NAME, 'address')
    elements = driver.find_elements(By.CSS_SELECTOR, ".shell")
    duplicate = False
    for e in elements:
        addressElement = e.find_element(By.CLASS_NAME, 'address')
        url = e.find_element(By.TAG_NAME, 'a').get_attribute("href")
        urls.append(url)
        # get today's date as YYYY-MM-DD
        today = datetime.date.today().strftime("%Y-%m-%d")
        print(url)
        # transform the relative url into an absolute url

        if addresses.count(addressElement.text) == 0:
            addresses.append(addressElement.text)
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
# join urls with newlines
onlyTheNew = []
for url in urls:
    if alreadySeen(url, "/mnt/Photos/maison"):
        print("seen")
    else:
        onlyTheNew.append(url)
        print("not seen " + url)
urls = onlyTheNew
if len(urls) == 0:
    send_sms("pas de maison cette fois-ci")
else:
    chunks = [urls[i:i + 10] for i in range(0, len(urls), 10)]
    for chunk in chunks:
        url_list = '\n  \n  \n'.join(chunk)
        send_sms(url_list)

# marked as already seen
addToAlreadySeen(urls, "/mnt/Photos/maison")
driver.quit()
