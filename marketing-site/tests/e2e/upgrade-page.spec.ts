// Playwright E2E: /upgrade page tests.
//
// The /upgrade page is the post-trial conversion page for existing users.
// It shows two paid plans (Równowaga + Rozkwit) with a billing cycle
// toggle (monthly/annual). No trial card — users already had their trial.
//
// Tests validate:
// - Page loads with correct heading and pitch copy
// - Both plan cards render with correct names, prices, sessions
// - Billing cycle toggle works (monthly ↔ annual)
// - CTAs are present and interactive
// - VAT footnote is visible
// - "Most popular" badge on the Rozkwit card

import { test, expect } from "@playwright/test";
import { forLocale, urlPrefix } from "./_locales";

test.describe("Upgrade Page", () => {
  test("page loads with h1 heading", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/upgrade`);

    const heading = forLocale({
      pl: /Twój okres próbny/i,
      en: /Your trial has ended/i,
    });
    await expect(page.locator("h1")).toContainText(heading);
  });

  test("shows motivational pitch paragraph", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/upgrade`);

    const pitch = forLocale({
      pl: /Wybierz plan dopasowany/i,
      en: /Choose the plan that fits/i,
    });
    await expect(page.locator("body")).toContainText(pitch);
  });

  test("shows Równowaga (Balance) card with 179 zł", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/upgrade`);

    const cardTitle = forLocale({
      pl: "Równowaga",
      en: "Balance",
    });
    // Use heading role to avoid matching "Everything in Balance, plus:" text
    await expect(page.getByRole("heading", { name: cardTitle })).toBeVisible();
    await expect(page.locator("body")).toContainText("179");
  });

  test("shows Rozkwit (Growth) card with 299 zł", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/upgrade`);

    const cardTitle = forLocale({
      pl: "Rozkwit",
      en: "Growth",
    });
    // Use heading role to avoid matching the ROZKWIT30 coupon code
    await expect(page.getByRole("heading", { name: cardTitle })).toBeVisible();
    await expect(page.locator("body")).toContainText("299");
  });

  test("Rozkwit card has 'Most popular' badge", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/upgrade`);

    const badge = forLocale({
      pl: /Najpopularniejszy/i,
      en: /Most popular/i,
    });
    await expect(page.getByText(badge)).toBeVisible();
  });

  test("shows correct session counts (30 + 90)", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/upgrade`);

    const solo = forLocale({
      pl: /30 sesji/i,
      en: /30 sessions/i,
    });
    const pro = forLocale({
      pl: /90 sesji/i,
      en: /90 sessions/i,
    });
    await expect(page.getByText(solo).first()).toBeVisible();
    await expect(page.getByText(pro).first()).toBeVisible();
  });

  test("billing cycle toggle exists and defaults to monthly", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/upgrade`);

    const monthlyTab = page.getByRole("tab", {
      name: forLocale({
        pl: /Miesięcznie/i,
        en: /Monthly/i,
      }),
    });
    const annualTab = page.getByRole("tab", {
      name: forLocale({
        pl: /Rocznie/i,
        en: /Annually/i,
      }),
    });

    await expect(monthlyTab).toBeVisible();
    await expect(annualTab).toBeVisible();
    // Monthly is default
    await expect(monthlyTab).toHaveAttribute("aria-selected", "true");
  });

  test("switching to annual billing shows discount note", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/upgrade`);

    // Wait for the page to hydrate before clicking
    const annualLabel = forLocale({
      pl: /Rocznie/i,
      en: /Annually/i,
    });
    const annualBtn = page.getByRole("tab", { name: annualLabel });
    await annualBtn.waitFor({ state: "visible", timeout: 10_000 });
    await annualBtn.click();

    const discount = forLocale({
      pl: /17% taniej/i,
      en: /17% off/i,
    });
    await expect(page.getByText(discount)).toBeVisible();
  });

  test("CTA buttons are present for both plans", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/upgrade`);

    const ctaLabel = forLocale({
      pl: /Wybierz ten plan/i,
      en: /Choose this plan/i,
    });
    const buttons = page.getByRole("button", { name: ctaLabel });
    await expect(buttons).toHaveCount(2);
  });

  test("VAT footnote is visible", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/upgrade`);

    const vatText = forLocale({
      pl: /brutto.*VAT.*23%/i,
      en: /23%.*VAT/i,
    });
    await expect(page.getByText(vatText).first()).toBeVisible();
  });

  test("features list shows expected items", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/upgrade`);

    // Check that feature lists contain key items
    const reportFeature = forLocale({
      pl: /raporty kliniczne/i,
      en: /clinical reports/i,
    });
    await expect(page.getByText(reportFeature).first()).toBeVisible();

    const kartotekiFeature = forLocale({
      pl: /kartoteki/i,
      en: /patient files/i,
    });
    await expect(page.getByText(kartotekiFeature).first()).toBeVisible();
  });

  test("navbar and footer are present", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/upgrade`);

    await expect(page.locator("nav")).toBeVisible();
    await expect(page.locator("footer")).toBeVisible();
  });
});
