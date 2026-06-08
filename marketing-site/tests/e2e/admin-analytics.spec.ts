// Playwright E2E: /admin/analytics dashboard.
//
// Each test installs its own Firebase Auth + Connect-RPC route mocks,
// keeping tests fully isolated. The login flow takes ~1s — acceptable
// for 6 tests, and avoids the complexity of storageState when auth
// lives at the mock-route level rather than real browser sessions.
//
// Fixtures:  fixtures/auth.ts       — Firebase Auth intercepts
//            fixtures/connect-rpc.ts — identity-svc & clinical-svc mocks
// Page objs: pages/admin-login.page.ts, pages/analytics.page.ts

import { test, expect } from "@playwright/test";
import { forLocale, urlPrefix } from "./_locales";
import {
  mockFirebaseAuth,
  mockFirebaseSignedOut,
  ADMIN_USER,
} from "./fixtures/auth";
import {
  mockGetMyProfile,
  mockGetAdminAnalytics,
  mockGetAdminAnalyticsError,
} from "./fixtures/connect-rpc";
import { AdminLoginPage } from "./pages/admin-login.page";
import { AnalyticsDashboardPage } from "./pages/analytics.page";

// ── Helpers ────────────────────────────────────────────────────────

/** Full mock setup for an admin session (auth + identity + analytics). */
async function setupAdminMocks(page: import("@playwright/test").Page) {
  await mockFirebaseAuth(page, ADMIN_USER);
  await mockGetMyProfile(page);
  await mockGetAdminAnalytics(page);
  // Mock NBP rate API that the dashboard calls for PLN conversion.
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
}

/** Navigate to analytics and sign in through AdminGuard. */
async function navigateAndSignIn(page: import("@playwright/test").Page) {
  const prefix = urlPrefix();
  await page.goto(`${prefix}/admin/analytics`);
  const loginPage = new AdminLoginPage(page);
  await loginPage.signIn("admin@superwizor.ai", "AdminPassword123!");
}

// ── Auth Gating ────────────────────────────────────────────────────

test.describe("Admin Analytics — Auth Gating", () => {
  test("shows sign-in form when not authenticated", async ({ page }) => {
    const prefix = urlPrefix();
    await mockFirebaseSignedOut(page);

    await page.goto(`${prefix}/admin/analytics`);
    const loginPage = new AdminLoginPage(page);
    await loginPage.expectSignInRequired();
  });

  test("authenticates via email and loads dashboard", async ({ page }) => {
    const prefix = urlPrefix();
    await mockFirebaseSignedOut(page);

    await page.goto(`${prefix}/admin/analytics`);
    const loginPage = new AdminLoginPage(page);
    await loginPage.expectSignInRequired();

    // Install full admin session mocks before submitting.
    await setupAdminMocks(page);

    await loginPage.signIn("admin@superwizor.ai", "AdminPassword123!");

    const dashboard = new AnalyticsDashboardPage(page);
    await dashboard.expectDashboardLoaded();
  });
});

// ── Dashboard Rendering ────────────────────────────────────────────

test.describe("Admin Analytics — Dashboard", () => {
  test("loads Overview tab with KPI cards", async ({ page }) => {
    await setupAdminMocks(page);
    await navigateAndSignIn(page);

    const dashboard = new AnalyticsDashboardPage(page);
    await dashboard.expectDashboardLoaded();

    // KPI cards render the mock values via CountUp animation.
    const wauTitle = forLocale({
      pl: "Aktywni terapeuci (WAU)",
      en: "Active Therapists (WAU)",
    });
    await dashboard.expectKpiVisible(wauTitle);
    await expect(page.locator("text=120").first()).toBeVisible();
    await expect(page.locator("text=450").first()).toBeVisible();
  });

  test("switches to Costs tab and shows cost KPIs", async ({ page }) => {
    await setupAdminMocks(page);
    await navigateAndSignIn(page);

    const dashboard = new AnalyticsDashboardPage(page);
    await dashboard.expectDashboardLoaded();
    await dashboard.switchToTab("costs");

    const avgCostLabel = forLocale({
      pl: "Śr. koszt sesji (API)",
      en: "Avg. Cost per Session (API)",
    });
    await dashboard.expectKpiVisible(avgCostLabel);
  });

  test("switches to AI Quality tab and shows quality KPIs", async ({
    page,
  }) => {
    await setupAdminMocks(page);
    await navigateAndSignIn(page);

    const dashboard = new AnalyticsDashboardPage(page);
    await dashboard.expectDashboardLoaded();
    await dashboard.switchToTab("quality");

    const latencyLabel = forLocale({
      pl: "Mediana czasu przetwarzania",
      en: "Median Processing Time",
    });
    await dashboard.expectKpiVisible(latencyLabel);
  });
});

// ── Error Handling ─────────────────────────────────────────────────

test.describe("Admin Analytics — Error Handling", () => {
  test("shows error state when GetAdminAnalytics fails", async ({ page }) => {
    await mockFirebaseAuth(page, ADMIN_USER);
    await mockGetMyProfile(page);
    await mockGetAdminAnalyticsError(page);
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

    await navigateAndSignIn(page);

    const dashboard = new AnalyticsDashboardPage(page);
    await dashboard.expectErrorState();
  });
});
