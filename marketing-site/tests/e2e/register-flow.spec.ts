// Playwright E2E: registration flow tests.
//
// Validates the Phase 2 changes:
// - /register/therapist page loads with ?plan= variants
// - TrialPitchBanner shows correct content for each plan
// - /register/therapist/success page loads
// - /beta page CTA links to register with ?plan=beta
// - Social buttons are present on register page

import { test, expect } from "@playwright/test";
import { forLocale, urlPrefix } from "./_locales";

test.describe("Registration Flow", () => {
  test("register page loads without plan param", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist`);
    // Should have Social buttons
    await expect(page.getByRole("button", { name: /Google/i })).toBeVisible();
    await expect(page.getByRole("button", { name: /Apple/i })).toBeVisible();
  });

  test("register page loads with ?plan=trial", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist?plan=trial`);
    // TrialPitchBanner should show trial content
    const pitchContent = forLocale({
      pl: /5 sesji|30 dni/i,
      en: /5 sessions|30 days/i,
    });
    await expect(page.locator("body")).toContainText(pitchContent);
  });

  test("register page loads with ?plan=solo_monthly", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist?plan=solo_monthly`);
    // TrialPitchBanner should show solo plan content
    const pitchContent = forLocale({
      pl: /Równowaga|30 sesji|179/i,
      en: /Balance|30 sessions|179/i,
    });
    await expect(page.locator("body")).toContainText(pitchContent);
  });

  test("register page loads with ?plan=beta", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist?plan=beta`);
    // TrialPitchBanner should show beta content
    const pitchContent = forLocale({
      pl: /120 sesji|Beta/i,
      en: /120 sessions|Beta/i,
    });
    await expect(page.locator("body")).toContainText(pitchContent);
  });

  test("success page renders after checkout", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist/success`);
    const heading = forLocale({
      pl: /Płatność zakończona/i,
      en: /Payment successful/i,
    });
    await expect(page.locator("h1")).toContainText(heading);
  });

  test("beta page CTA links to register with plan=beta", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/beta`);
    const ctaLabel = forLocale({
      pl: /Dołącz do programu Beta/i,
      en: /Join the Beta Program/i,
    });
    const cta = page.getByRole("link", { name: ctaLabel }).first();
    await expect(cta).toBeVisible();
    await expect(cta).toHaveAttribute(
      "href",
      `${prefix}/register/therapist?plan=beta`,
    );
  });

  test("register form has email field, password, and submit", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist`);
    // Email input
    await expect(page.locator('input[type="email"]')).toBeVisible();
    // Password input
    await expect(page.locator('input[type="password"]')).toBeVisible();
    // Submit button
    const submitLabel = forLocale({
      pl: /Zarejestruj się|Wyślij/i,
      en: /Sign up|Submit/i,
    });
    await expect(
      page.getByRole("button", { name: submitLabel }),
    ).toBeVisible();
  });

  test("register form has ToS checkbox", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist`);
    const tosCheckbox = page.locator("#tos");
    await expect(tosCheckbox).toBeVisible();
  });
});
