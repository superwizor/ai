// Verify /pl/login/ + that nav/footer login links land there.
// Also confirm the "already have account" links on register pages
// point at the new internal /login (not the old cross-origin URL).

import { chromium } from "@playwright/test";

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext();
const page = await ctx.newPage();

async function check(path) {
  await page.goto(`https://superwizor.web.app${path}`, { waitUntil: "networkidle" });
  const finalUrl = page.url();
  const loginLinks = await page.$$eval('a[href*="login"]', (as) =>
    Array.from(as).map((a) => a.getAttribute("href")).filter((h) => h && !h.startsWith("javascript")),
  );
  return { path, final_url: finalUrl, login_links: Array.from(new Set(loginLinks)).slice(0, 10) };
}

const results = [];
results.push(await check("/pl/"));
results.push(await check("/pl/login/"));
results.push(await check("/pl/register/therapist/"));
results.push(await check("/en/register/organization/"));

// Also visit /pl/login/ and check the form actually renders
await page.goto("https://superwizor.web.app/pl/login/", { waitUntil: "networkidle" });
await page.waitForTimeout(2000);
const form_state = {
  has_email_input: await page.locator('input[type="email"]').count(),
  has_password_input: await page.locator('input[type="password"]').count(),
  has_submit: await page.locator('button[type="submit"]').count(),
  has_forgot_password: await page.locator('button:has-text("zapomn"), button:has-text("forgot")').count(),
  h1: (await page.locator("h1").first().textContent())?.trim().slice(0, 80) ?? "",
};

console.log(JSON.stringify({ navigation: results, form_state }, null, 2));
await page.screenshot({ path: "evidence/login-page/01-pl-login.png", fullPage: true });
await browser.close();
