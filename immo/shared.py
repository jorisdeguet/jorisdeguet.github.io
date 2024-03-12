import time

from selenium.webdriver.common.by import By

from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium import webdriver
def setup():
    options = ChromeOptions()
    options.add_argument("--headless=new")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--start-maximized")
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
