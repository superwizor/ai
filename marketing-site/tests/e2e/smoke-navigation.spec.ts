// Playwright E2E: smoke navigation tests.
//
// Verifies that the main public pages load without crashes and key
// navigation elements are present. These are fast, lightweight tests
// that run in both PL and EN locales to catch routing / i18n issues
// before the heavier form-interaction specs.

import { test, expect } from "@playwright/test";
import { forLocale, urlPrefix } from "./_locales";

test.describe("Smoke Navigation", () => {
  test("landing page loads and shows hero heading", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);

    // The landing page renders a hero with the main value prop heading.
    await expect(page.locator("h1").first()).toBeVisible();
  });

  test("navbar has link to register/therapist", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);

    const registerLabel = forLocale({
      pl: /Wypróbuj za darmo/i,
      en: /Try for free/i,
    });
    const registerLink = page.getByRole("link", { name: registerLabel }).first();
    await expect(registerLink).toBeVisible();
  });

  test("register therapist page loads", async ({ page }) => {
    // Mock ListModalities so the page doesn't fail on the RPC.
    await page.route(
      /clinical\.v1\.ClinicalService\/ListModalities/,
      async (route) => {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({ modalities: [] }),
        });
      },
    );

    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist`);
    await expect(page).toHaveURL(
      new RegExp(`${prefix}/register/therapist`),
    );

    const heading = forLocale({
      pl: "Zarejestruj się jako terapeuta",
      en: "Sign up as a therapist",
    });
    await expect(page.locator("h1")).toContainText(heading);
  });

  test("login page loads", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/login`);
    await expect(page).toHaveURL(
      new RegExp(`(${prefix}|/pl)?/login\\/?$`),
    );

    const heading = forLocale({
      pl: "Witaj z powrotem",
      en: "Welcome back",
    });
    await expect(page.locator("h1")).toContainText(heading);
  });

  test("legal terms page loads", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/legal/terms`);

    // Should have content — the page renders markdown.
    await expect(page.locator("main")).toBeVisible();
  });

  test("legal privacy page loads", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/legal/privacy`);
    await expect(page.locator("main")).toBeVisible();
  });
});
