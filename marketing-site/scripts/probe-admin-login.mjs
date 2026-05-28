// Probe: visit /pl/admin/ unauthenticated, confirm inline sign-in form
// renders (not the old redirect CTA). Doesn't attempt actual sign-in
// because that would need a real password.

import { chromium } from "@playwright/test";

const URL = "https://superwizor.web.app/pl/admin/";

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext();
const page = await ctx.newPage();

await page.goto(URL, { waitUntil: "networkidle" });
await page.waitForTimeout(2500);

const summary = {
  url: page.url(),
  has_email_input: await page.locator('input[type="email"]').count(),
  has_password_input: await page.locator('input[type="password"]').count(),
  has_signin_button: await page.locator('button[type="submit"]').count(),
  has_redirect_link: await page.locator('a[href*="superwizor-app.web.app"]').count(),
  visible_text: (await page.locator("h1").first().textContent())?.trim().slice(0, 100) ?? "",
};

console.log(JSON.stringify(summary, null, 2));
await page.screenshot({ path: "evidence/admin-signin/01-signed-out.png", fullPage: true });
await browser.close();
