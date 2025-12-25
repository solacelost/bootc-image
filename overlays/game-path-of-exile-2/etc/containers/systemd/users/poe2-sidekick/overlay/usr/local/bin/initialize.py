#!/usr/bin/env python3

import time

from playwright.sync_api import sync_playwright


try:
    playwright = sync_playwright().start()
    browser = playwright.chromium.launch()

    page = browser.new_page(viewport={"width": 1920, "height": 1080})
    while True:
        try:
            page.goto("http://localhost:5000/setup")
            content = page.content()
            while "Ready" not in content and "Development" not in content:
                time.sleep(1)
                content = page.content()
            print("[INITIALIZER] Successfully initialized sidekick!")
            break
        except:
            pass
finally:
    try:
        browser.close()
    except:
        pass
    try:
        playwright.stop()
    except:
        pass

print("[INITIALIZER] Script is closing")
