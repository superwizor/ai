// Admin auth setup — runs once before admin spec files.
//
// Signs in as SUPERWIZOR_ADMIN via the admin sign-in form at
// /admin/analytics, then saves the browser storage state so all
// admin tests in the same locale project start already authenticated.
//
// This eliminates the ~1s login overhead per test and removes the
// duplicated sign-in boilerplate from every admin spec.

import { test as setup } from "@playwright/test";
import path from "node:path";

import { mockFirebaseAuth, ADMIN_USER } from "./fixtures/auth";
import { mockGetMyProfile, mockGetAdminAnalytics } from "./fixtures/connect-rpc";
import { urlPrefix } from "./_locales";
import { AdminLoginPage } from "./pages/admin-login.page";

// Storage state output paths — one per locale.
const authDir = path.join(__dirname, ".auth");
const authStatePL = path.join(authDir, "admin-pl.json");
const authStateEN = path.join(authDir, "admin-en.json");

setup("authenticate admin session", async ({ page }) => {
  // Install all necessary mocks.
  await mockFirebaseAuth(page, ADMIN_USER);
  await mockGetMyProfile(page);
  await mockGetAdminAnalytics(page);

  // Mock NBP rate API.
  await page.route(/api\.nbp\.pl/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        rates: [{ mid: 3.95 }],
        effectiveDate: "2026-06-07",
      }),
    });
  });

  const prefix = urlPrefix();
  await page.goto(`${prefix}/admin/analytics`);

  const loginPage = new AdminLoginPage(page);
  await loginPage.signIn("admin@superwizor.ai", "AdminPassword123!");

  // Wait for the dashboard to load — confirms auth succeeded.
  await page.waitForSelector("h1", { timeout: 10_000 });

  // Save storage state for the locale.
  const outputPath = prefix === "/en" ? authStateEN : authStatePL;
  await page.context().storageState({ path: outputPath });
});
