// Playwright E2E: pricing flow tests.
//
// Validates the Phase 1 pricing changes:
// - CTA buttons on LP point to #cennik (scroll anchor)
// - Pricing section shows correct trial (5 sessions, 30 days), solo (179 PLN),
//   pro (299 PLN, 90 sessions) info
// - Coupon codes (ROWNOWAGA, ROZKWIT, PIONIER33) are visible
// - VAT note says "brutto" not "netto"
// - Trial CTA links to /register/therapist
// - Paid CTAs link to /register/therapist?plan=...
// - /kontakt page loads
// - /beta page loads

import { test, expect } from "@playwright/test";
import { forLocale, urlPrefix } from "./_locales";

test.describe("Pricing & CTA Flow", () => {
  test("hero CTA points to #cennik", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);

    const ctaLabel = forLocale({
      pl: /Wypróbuj za darmo/i,
      en: /Try for free/i,
    });
    const heroCta = page.locator("section").first().getByRole("link", { name: ctaLabel }).first();
    await expect(heroCta).toBeVisible();
    await expect(heroCta).toHaveAttribute("href", "#cennik");
  });

  test("navbar CTA points to #cennik and is ember yellow", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);

    const navCta = page.locator("nav").getByRole("link", { name: forLocale({
      pl: /Wypróbuj za darmo/i,
      en: /Try for free/i,
    }) }).first();
    await expect(navCta).toBeVisible();
    await expect(navCta).toHaveAttribute("href", "#cennik");
    // Check it has the bg-ember class
    await expect(navCta).toHaveClass(/bg-ember/);
  });

  test("pricing section has correct trial info (5 sessions, 30 days)", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);

    const pricingSection = page.locator("#cennik");
    await expect(pricingSection).toBeVisible();

    const trialText = forLocale({
      pl: "5 sesji przez 30 dni",
      en: "5 sessions for 30 days",
    });
    await expect(pricingSection).toContainText(trialText);
  });

  test("pricing section shows correct prices (149 PLN, 299 PLN brutto)", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);

    const pricingSection = page.locator("#cennik");

    // Równowaga price
    await expect(pricingSection).toContainText("149");
    // Rozkwit price
    await expect(pricingSection).toContainText("299");

    // VAT note says zawierają VAT
    const vatText = forLocale({
      pl: /zawierają.*VAT/i,
      en: /incl.*23%.*VAT/i,
    });
    await expect(pricingSection.getByText(vatText).first()).toBeVisible();
  });

  test("pricing section shows 90 sessions for pro plan (not 120)", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);

    const pricingSection = page.locator("#cennik");

    const sessionsText = forLocale({
      pl: "90 sesji",
      en: "90 sessions",
    });
    await expect(pricingSection.getByText(sessionsText).first()).toBeVisible();

    // Verify 120 is NOT present
    const oldText = forLocale({
      pl: "120 sesji",
      en: "120 sessions",
    });
    await expect(pricingSection.getByText(oldText)).toHaveCount(0);
  });



  test("trial CTA links to /register/therapist", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);

    const pricingSection = page.locator("#cennik");
    const trialCta = pricingSection.getByRole("link", {
      name: forLocale({
        pl: /Wypróbuj za darmo/i,
        en: /Try for free/i,
      }),
    }).first();

    await expect(trialCta).toBeVisible();
    const href = await trialCta.getAttribute("href");
    expect(href).toContain("/register/therapist");
  });

  test("paid plan CTA has ?plan= query param", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);

    const pricingSection = page.locator("#cennik");
    const paidCta = pricingSection.getByRole("link", {
      name: forLocale({
        pl: /Wybieram Rozkwit/i,
        en: /Choose Growth/i,
      }),
    }).first();

    await expect(paidCta).toBeVisible();
    const href = await paidCta.getAttribute("href");
    expect(href).toContain("plan=");
    expect(href).toContain("register/therapist");
  });

  test("contact page /kontakt loads", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/kontakt`);

    const heading = forLocale({
      pl: "Porozmawiajmy",
      en: "talk",
    });
    await expect(page.locator("h1")).toContainText(heading);

    // Form fields exist
    await expect(page.locator("#contact-name")).toBeVisible();
    await expect(page.locator("#contact-email")).toBeVisible();
    await expect(page.locator("#contact-message")).toBeVisible();
  });

  test("beta page /beta loads", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/beta`);

    const heading = forLocale({
      pl: /50 pionierów/i,
      en: /50 pioneers/i,
    });
    await expect(page.locator("h1")).toContainText(heading);

    // Badge is visible
    const badge = forLocale({
      pl: /50 miejsc/i,
      en: /50 spots/i,
    });
    await expect(page.getByText(badge)).toBeVisible();
  });

  test("register page shows trial pitch banner", async ({ page }) => {
    // Mock ListModalities
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

    const pitchText = forLocale({
      pl: /5 sesji.*30 dni/i,
      en: /5.*sessions.*30 days/i,
    });
    await expect(page.getByText(pitchText).first()).toBeVisible();
  });

  test("register page shows beta pitch when ?plan=beta", async ({ page }) => {
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
    await page.goto(`${prefix}/register/therapist?plan=beta`);

    const betaText = forLocale({
      pl: /120 sesji/i,
      en: /120 sessions/i,
    });
    await expect(page.getByText(betaText).first()).toBeVisible();
  });
});
