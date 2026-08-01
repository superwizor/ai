// Playwright E2E: the web-app entry points are desktop-only.
//
// On a phone or a tablet we steer the therapist to the native
// iOS/Android app instead of the Flutter web build, so neither the
// dashboard tile nor the navbar CTA that link to superwizor-app.web.app
// may render there. The remaining tiles ("Ściągnij na telefon",
// "Zarządzaj kontem") and the rest of the navigation are unaffected.
//
// The detection under test (src/lib/hooks/useHandheldDevice.ts) is
// device-shaped, not viewport-shaped — hence the deliberately awkward
// third case: an iPad serves a desktop-class "Macintosh" user agent and
// only multi-touch gives it away.

import { test, expect, type Page } from "@playwright/test";
import { urlPrefix } from "./_locales";
import { mockFirebaseAuth } from "./fixtures/auth";
import { mockGetMyProfile, mockGetSubscription } from "./fixtures/connect-rpc";

const IPHONE_UA =
  "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1";

// iPadOS 13+ default: indistinguishable from desktop Safari by UA alone.
const IPAD_DESKTOP_UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15";

/** Signs in through the mocked Firebase endpoints and lands on /dashboard. */
async function signInToDashboard(page: Page) {
  await mockFirebaseAuth(page);
  await mockGetMyProfile(page, {
    id: "user-uuid-1",
    email: "e2e@example.com",
    firstName: "Dariusz",
    lastName: "Testowy",
    // Non-empty so the onboarding guard doesn't redirect us away.
    defaultModalityId: "44f77c8e-8a71-4770-96f3-42e13297a7e8",
    organizationId: "org-uuid-1",
    role: "USER_ROLE_THERAPIST",
  });
  await mockGetSubscription(page);

  const prefix = urlPrefix();
  await page.goto(`${prefix}/login`);
  await page.locator("input[type='email']").fill("e2e@example.com");
  await page.locator("input[type='password']").fill("Sup3rwizor!");
  await page.locator("form button[type='submit']").click();
  await expect(page).toHaveURL(new RegExp(`(${prefix}|/pl|/en)?/dashboard`));
}

// Scoped to the card's heading on purpose — the navbar carries a second
// link to the same APP_URL, asserted separately by navbarAppCta().
function webAppTile(page: Page) {
  return page.getByRole("heading", {
    name: /Przejdź do aplikacji|Go to Application/,
  });
}

function navbarAppCta(page: Page) {
  return page.getByRole("link", { name: /Otwórz aplikację|Open App/i });
}

function mobileTile(page: Page) {
  return page.getByRole("heading", { name: /Ściągnij na telefon|Download on Phone/ });
}

test.describe("Web-app entry points", () => {
  test("desktop keeps the tile and the navbar CTA", async ({ page }, testInfo) => {
    await signInToDashboard(page);

    await expect(mobileTile(page)).toBeVisible();
    await expect(webAppTile(page)).toBeVisible();
    await expect(navbarAppCta(page)).toBeVisible();

    await page.screenshot({
      path: `../evidence/dashboard-handheld/${testInfo.project.name}-desktop.png`,
      fullPage: false,
    });
  });

  test.describe("phone", () => {
    test.use({
      userAgent: IPHONE_UA,
      viewport: { width: 393, height: 852 },
      hasTouch: true,
      isMobile: true,
    });

    test("hides the tile and the navbar CTA", async ({ page }, testInfo) => {
      await signInToDashboard(page);

      await expect(mobileTile(page)).toBeVisible();
      await expect(webAppTile(page)).toHaveCount(0);
      await expect(navbarAppCta(page)).toHaveCount(0);

      await page.screenshot({
        path: `../evidence/dashboard-handheld/${testInfo.project.name}-iphone.png`,
        fullPage: false,
      });
    });
  });

  test.describe("tablet with a desktop-class user agent", () => {
    test.use({
      userAgent: IPAD_DESKTOP_UA,
      viewport: { width: 1024, height: 1366 },
      hasTouch: true,
    });

    test("hides the tile and the navbar CTA", async ({ page }, testInfo) => {
      // Playwright's touch emulation reports maxTouchPoints = 1; a real
      // iPad reports 5. Pin it so this exercises the same branch the
      // device does — the UA alone says "Macintosh".
      await page.addInitScript(() => {
        Object.defineProperty(navigator, "maxTouchPoints", { get: () => 5 });
      });

      await signInToDashboard(page);

      await expect(mobileTile(page)).toBeVisible();
      await expect(webAppTile(page)).toHaveCount(0);
      await expect(navbarAppCta(page)).toHaveCount(0);

      await page.screenshot({
        path: `../evidence/dashboard-handheld/${testInfo.project.name}-ipad.png`,
        fullPage: false,
      });
    });
  });
});
