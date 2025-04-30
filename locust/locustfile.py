from locust import User, HttpUser, task, between, events
from playwright.async_api import async_playwright, expect
import requests
import asyncio
import random
import os

class HostUser0(HttpUser):
    host = f"http://{os.getenv('APP00', 'app00')}:3000"
    weight = 2
    wait_time = between(60, 300)

    @task
    def request_to_host(self):
        self.client.get('/')
        self.client.get('/products')

class HostUser1(HttpUser):
    host = f"http://{os.getenv('APP01', 'app01')}:3000"
    weight = 2
    wait_time = between(60, 300)

    @task
    def request_to_host(self):
        self.client.get('/')
        self.client.get('/products')

class HostUser2(HttpUser):
    host = f"http://{os.getenv('APP02', 'app02')}:3000"
    weight = 6
    wait_time = between(60, 300)

    @task
    def request_to_host(self):
        self.client.get('/')
        self.client.get('/products')

class HostUser3(HttpUser):
    host = f"http://{os.getenv('APP03', 'app03')}:3000"
    weight = 8
    wait_time = between(60, 300)

    @task
    def request_to_host(self):
        self.client.get('/')
        self.client.get('/products')
        self.client.get(f"/products/{random.randint(1, 1000)}")

class NoPlaywrightUser(HttpUser):
    host = f"http://{os.getenv('APP00', 'app00')}:3000"
    weight = 2
    wait_time = between(80, 400)

    @task
    def request_to_host(self):
        if os.getenv('DISABLE_PLAYWRIGHT', '') != '':
            self.client.get('/')
            self.client.get('/docs')
            file_list = [
                "1001-kabinetas.jpg",
                "1087-lengvas.jpg",
                "1152-valgomasis.jpg",
                "1528-rytosviesa.jpg",
                "2896-anglis.jpg",
                "3820-siltumas.jpg",
                "blog.css"
            ]
            for file in file_list:
                self.client.get(f"/docs/{file}")

class PlaywrightUser(User):
    host = f"http://{os.getenv('APP00', 'app00')}:3000"
    weight = 2
    wait_time = between(80, 400)

    @task
    def request_to_host(self):
        asyncio.run(self.run_playwright())

    async def run_playwright(self):
        async with async_playwright() as p:
            browser = await p.chromium.launch()
            page = await browser.new_page()
            host = f"http://{os.getenv('APP00', 'app00')}:3000"
            await page.goto(f"{host}/", wait_until='networkidle')
            await page.goto(f"{host}/docs", wait_until='networkidle')

            images = await page.get_by_role("img").all()
            for img in images:
                await expect(img).to_have_js_property("complete", True)
                await expect(img).not_to_have_js_property("naturalWidth", 0)

            await browser.close()

async def run():
    user = PlaywrightUser()
    await user.request_to_host()

if os.getenv("DISABLE_PLAYWRIGHT", '') != '' and os.getenv("DISABLE_PLAYWRIGHT", '') != '0' and os.getenv("DISABLE_PLAYWRIGHT", '') != 'false':
    PlaywrightUser = None
else:
    NoPlaywrightUser = None
