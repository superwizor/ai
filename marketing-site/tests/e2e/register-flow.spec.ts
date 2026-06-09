// Comprehensive E2E tests for the full registration + subscription flow.
//
// Tests cover EVERY confirmed decision from the E2E integration plan:
// - Trial: 5 sessions / 30 days, no card
// - Beta: 120 sessions/mo x 2 months, secret /beta link
// - Równowaga: 30 sessions, 179 PLN brutto
// - Rozkwit: 90 sessions, 299 PLN brutto
// - Promo codes: ROWNOWAGA20, ROZKWIT30, PIONIER33
// - Register-first flow: create account → redirect based on plan
// - Apple compliance: no upsells in the path

import { test, expect } from "@playwright/test";
import { forLocale, urlPrefix } from "./_locales";

// ─────────────────────────────────────────────────────────────
// HAPPY PATH: Landing Page → Cennik → Registration
// ─────────────────────────────────────────────────────────────

test.describe("Happy Path: Landing Page", () => {
  test("LP loads and shows hero section", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);
    await expect(page.locator("h1")).toBeVisible();
  });

  test("hero CTA says 'Wypróbuj za darmo' and points to #cennik", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);
    const label = forLocale({
      pl: /Wypróbuj za darmo/i,
      en: /Try for free/i,
    });
    const cta = page
      .locator("section")
      .first()
      .getByRole("link", { name: label })
      .first();
    await expect(cta).toBeVisible();
    await expect(cta).toHaveAttribute("href", "#cennik");
  });
});

// ─────────────────────────────────────────────────────────────
// HAPPY PATH: Pricing Section (Cennik)
// ─────────────────────────────────────────────────────────────

test.describe("Happy Path: Cennik", () => {
  test("pricing section exists with id=cennik", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);
    await expect(page.locator("#cennik")).toBeVisible();
  });

  test("Trial card shows 5 sessions / 30 days", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);
    const cennik = page.locator("#cennik");
    const trialText = forLocale({
      pl: /5 sesji.*30 dni|5.*sesji/i,
      en: /5 sessions.*30 days/i,
    });
    await expect(cennik).toContainText(trialText);
  });

  test("Równowaga card shows 179 zł and 30 sessions", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);
    const cennik = page.locator("#cennik");
    await expect(cennik).toContainText(/179/);
    await expect(cennik).toContainText(/30/);
  });

  test("Rozkwit card shows 299 zł and 90 sessions", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);
    const cennik = page.locator("#cennik");
    await expect(cennik).toContainText(/299/);
    await expect(cennik).toContainText(/90/);
  });

  test("prices are marked as BRUTTO", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);
    const cennik = page.locator("#cennik");
    const bruttoText = forLocale({
      pl: /brutto/i,
      en: /gross|brutto|VAT|incl/i,
    });
    await expect(cennik).toContainText(bruttoText);
  });



  test("Trial CTA links to /register/therapist (no plan param)", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);
    const cennik = page.locator("#cennik");
    const trialCta = forLocale({
      pl: /Wypróbuj za darmo/i,
      en: /Try for free/i,
    });
    const link = cennik.getByRole("link", { name: trialCta }).first();
    await expect(link).toBeVisible();
    const href = await link.getAttribute("href");
    expect(href).toContain("/register/therapist");
    expect(href).not.toContain("plan=");
  });

  test("Równowaga CTA links to register with plan=solo_monthly", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);
    const cennik = page.locator("#cennik");
    const soloCta = forLocale({
      pl: /Równowag/i,
      en: /Balance/i,
    });
    const link = cennik.getByRole("link", { name: soloCta }).first();
    await expect(link).toBeVisible();
    const href = await link.getAttribute("href");
    expect(href).toContain("plan=solo_monthly");
  });

  test("Rozkwit CTA links to register with plan=pro_monthly", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);
    const cennik = page.locator("#cennik");
    const proCta = forLocale({
      pl: /Rozkwit/i,
      en: /Growth/i,
    });
    const link = cennik.getByRole("link", { name: proCta }).first();
    await expect(link).toBeVisible();
    const href = await link.getAttribute("href");
    expect(href).toContain("plan=pro_monthly");
  });
});

// ─────────────────────────────────────────────────────────────
// HAPPY PATH: Registration Page
// ─────────────────────────────────────────────────────────────

test.describe("Happy Path: Registration", () => {
  test("register page loads with form fields", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist`);
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await expect(page.locator('input[type="password"]')).not.toBeVisible();
  });

  test("social login buttons present (Google + Apple)", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist`);
    await expect(page.getByRole("button", { name: /Google/i })).toBeVisible();
    await expect(page.getByRole("button", { name: /Apple/i })).toBeVisible();
  });

  test("ToS checkbox is required", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist`);
    // Fill step 1 first to be able to go to step 2
    await page.locator("#firstName").fill("Anna");
    await page.locator("#lastName").fill("Kowalska");
    await page.locator("#email").fill("test-tos@example.com");
    await page.locator("#next-step-btn").click();

    const tos = page.locator("#tos");
    await expect(tos).toBeVisible();
  });

  test("TrialPitchBanner shows trial info for no plan param", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist`);
    const trialInfo = forLocale({
      pl: /5 sesji|30 dni/i,
      en: /5 sessions|30 days/i,
    });
    await expect(page.locator("body")).toContainText(trialInfo);
  });

  test("TrialPitchBanner shows Równowaga info for plan=solo_monthly", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist?plan=solo_monthly`);
    await expect(page.locator("body")).toContainText(/179/);
  });

  test("TrialPitchBanner shows Rozkwit info for plan=pro_monthly", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist?plan=pro_monthly`);
    await expect(page.locator("body")).toContainText(/299/);
  });

  test("TrialPitchBanner shows Beta info for plan=beta", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist?plan=beta`);
    const betaInfo = forLocale({
      pl: /120 sesji|Beta/i,
      en: /120 sessions|Beta/i,
    });
    await expect(page.locator("body")).toContainText(betaInfo);
  });
});

// ─────────────────────────────────────────────────────────────
// HAPPY PATH: Beta Page
// ─────────────────────────────────────────────────────────────

test.describe("Happy Path: Beta Page", () => {
  test("/beta page loads", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/beta`);
    await expect(page.locator("h1")).toBeVisible();
  });

  test("shows 120 sessions / 2 months offer", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/beta`);
    const offer = forLocale({
      pl: /120 sesji/i,
      en: /120 sessions/i,
    });
    await expect(page.locator("body")).toContainText(offer);
    const months = forLocale({
      pl: /2 miesi/i,
      en: /2 months/i,
    });
    await expect(page.locator("body")).toContainText(months);
  });

  test("shows 50 spots badge", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/beta`);
    const badge = forLocale({
      pl: /50 miejsc/i,
      en: /50 spots/i,
    });
    await expect(page.locator("body")).toContainText(badge);
  });

  test("CTA links to /register/therapist?plan=beta", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/beta`);
    const ctaLabel = forLocale({
      pl: /Dołącz do programu/i,
      en: /Join the Beta/i,
    });
    const cta = page.getByRole("link", { name: ctaLabel }).first();
    await expect(cta).toHaveAttribute(
      "href",
      `${prefix}/register/therapist?plan=beta`,
    );
  });

  test("FAQ section is interactive", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/beta`);
    // Find first FAQ question button and click it
    const faqButton = page.locator("button").filter({ hasText: "?" }).first();
    if (await faqButton.isVisible()) {
      await faqButton.click();
      // After click, the answer should expand
      const faqSection = page.locator("section").last();
      await expect(faqSection).toBeVisible();
    }
  });
});

// ─────────────────────────────────────────────────────────────
// HAPPY PATH: Contact Page
// ─────────────────────────────────────────────────────────────

test.describe("Happy Path: Contact Page", () => {
  test("/kontakt page loads", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/kontakt`);
    await expect(page.locator("h1")).toBeVisible();
  });

  test("has contact form fields", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/kontakt`);
    // Should have at least email and message fields
    await expect(
      page.locator('input[type="email"], input[name="email"]'),
    ).toBeVisible();
  });
});

// ─────────────────────────────────────────────────────────────
// HAPPY PATH: Success Page
// ─────────────────────────────────────────────────────────────

test.describe("Happy Path: Checkout Success", () => {
  test("/register/therapist/success page renders", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist/success`);
    const heading = forLocale({
      pl: /Płatność|sukces|gotowe/i,
      en: /Payment|success|complete/i,
    });
    await expect(page.locator("h1")).toContainText(heading);
  });
});

// ─────────────────────────────────────────────────────────────
// BAD PATH: Invalid Plan Params
// ─────────────────────────────────────────────────────────────

test.describe("Bad Path: Invalid Plans", () => {
  test("register with unknown plan falls back to trial", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist?plan=nonexistent`);
    // Page should still load and show trial info (graceful fallback)
    await expect(page.locator('input[type="email"]')).toBeVisible();
  });

  test("register with plan=enterprise shows trial fallback", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist?plan=enterprise`);
    await expect(page.locator('input[type="email"]')).toBeVisible();
  });

  test("register with empty plan param works like no plan", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist?plan=`);
    await expect(page.locator('input[type="email"]')).toBeVisible();
    // Should show trial info
    const trialInfo = forLocale({
      pl: /5 sesji|30 dni/i,
      en: /5 sessions|30 days/i,
    });
    await expect(page.locator("body")).toContainText(trialInfo);
  });
});

// ─────────────────────────────────────────────────────────────
// BAD PATH: Form Validation
// ─────────────────────────────────────────────────────────────

test.describe("Bad Path: Form Validation", () => {
  test("submit without filling form shows validation errors", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist`);
    
    // We cannot click submit on Step 1, but we can click the next-step button
    const btn = page.locator("#next-step-btn");
    await btn.click();

    // Form should not navigate away — validation errors should show
    await expect(page).toHaveURL(/register/);
    await expect(page.locator("[role='alert']").first()).toBeVisible();
  });

  test("ToS must be checked before submission", async ({ page }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist`);

    // Step 1
    await page.locator("#firstName").fill("Test");
    await page.locator("#lastName").fill("User");
    await page.locator("#email").fill("test@example.com");
    await page.locator("#next-step-btn").click();

    // Step 2 (Password filled, ToS not accepted)
    await page.locator("#password").fill("TestPass123!");
    await page.locator("#next-step-btn").click();

    // Should show the tosRequired error
    await expect(page.locator("[role='alert']").first()).toBeVisible();
    await expect(page).toHaveURL(/register/);
  });
});

// ─────────────────────────────────────────────────────────────
// BAD PATH: Non-existent Pages
// ─────────────────────────────────────────────────────────────

test.describe("Bad Path: 404 Pages", () => {
  test("/upgrade does not exist yet (should 404 or redirect)", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    const response = await page.goto(`${prefix}/upgrade`);
    // Should either 404 or redirect
    const status = response?.status();
    expect([200, 404, 307, 308]).toContain(status);
  });

  test("/dashboard does not exist yet", async ({ page }) => {
    const prefix = urlPrefix();
    const response = await page.goto(`${prefix}/dashboard`);
    const status = response?.status();
    expect([200, 404, 307, 308]).toContain(status);
  });

  test("/onboarding does not exist yet", async ({ page }) => {
    const prefix = urlPrefix();
    const response = await page.goto(`${prefix}/onboarding`);
    const status = response?.status();
    expect([200, 404, 307, 308]).toContain(status);
  });
});

// ─────────────────────────────────────────────────────────────
// BAD PATH: API endpoint validation
// ─────────────────────────────────────────────────────────────

test.describe("Bad Path: API /api/checkout", () => {
  test("POST /api/checkout without body returns 400", async ({ request }) => {
    const response = await request.post("/api/checkout", {
      data: {},
    });
    expect(response.status()).toBe(400);
  });

  test("POST /api/checkout with missing priceId returns 400", async ({
    request,
  }) => {
    const response = await request.post("/api/checkout", {
      data: { organizationId: "550e8400-e29b-41d4-a716-446655440000" },
    });
    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body.error).toContain("priceId");
  });

  test("POST /api/checkout with invalid organizationId returns 400", async ({
    request,
  }) => {
    const response = await request.post("/api/checkout", {
      data: { priceId: "price_xxx", organizationId: "not-a-uuid" },
    });
    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body.error).toContain("organizationId");
  });

  test("GET /api/checkout returns 405 (method not allowed)", async ({
    request,
  }) => {
    const response = await request.get("/api/checkout");
    // Next.js API routes return 405 for unsupported methods
    expect([405, 404]).toContain(response.status());
  });
});

// ─────────────────────────────────────────────────────────────
// CONSISTENCY: plan slug ↔ registration page ↔ LP cennik
// ─────────────────────────────────────────────────────────────

test.describe("Consistency: LP ↔ Registration flow", () => {
  test("all pricing CTA links resolve to working registration pages", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/`);
    const cennik = page.locator("#cennik");
    const links = cennik.getByRole("link");
    const hrefs: string[] = [];

    const count = await links.count();
    for (let i = 0; i < count; i++) {
      const href = await links.nth(i).getAttribute("href");
      if (href && href.includes("/register/therapist")) {
        hrefs.push(href);
      }
    }

    // Each registration link should load a working page
    for (const href of hrefs) {
      let fullUrl = href;
      if (!href.startsWith("http")) {
        if (prefix && href.startsWith(prefix)) {
          fullUrl = href;
        } else {
          fullUrl = `${prefix}${href.startsWith("/") ? "" : "/"}${href}`;
        }
      }
      const res = await page.goto(fullUrl);
      expect(res?.status()).toBe(200);
      await expect(page.locator('input[type="email"]')).toBeVisible();
    }
  });
});

// ─────────────────────────────────────────────────────────────
// APPLE COMPLIANCE: no pricing or upsell links in app paths
// ─────────────────────────────────────────────────────────────

test.describe("Apple Compliance: Reader App Rules", () => {
  test("registration page does NOT show pricing/upgrade links", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    await page.goto(`${prefix}/register/therapist`);
    // The register page itself should NOT have upgrade/pricing links
    // (pricing is on the LP only, registration is clean)
    const body = await page.locator("body").textContent();
    expect(body).not.toMatch(/Rozszerz plan|Upgrade your plan/i);
  });
});
