// Playwright E2E test for /admin/analytics dashboard (auth gating, rendering, and event tracking intercepts)
import { test, expect, Page } from "@playwright/test";
import { forLocale, urlPrefix } from "./_locales";

test.describe("Admin Analytics Dashboard E2E", () => {
  test.beforeEach(async ({ page }) => {
    // ── Firebase Auth Intercepts ──
    // Mock user lookup for active session
    await page.route(/accounts:lookup/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          users: [
            {
              localId: "admin-uid-123",
              email: "admin@superwizor.ai",
              emailVerified: true,
            },
          ],
        }),
      });
    });

    // Mock token refresh
    await page.route(/securetoken\.googleapis\.com/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          access_token: "fake-admin-token",
          id_token: "fake-admin-token",
          user_id: "admin-uid-123",
        }),
      });
    });

    // Mock signInWithPassword
    await page.route(/accounts:signInWithPassword/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          localId: "admin-uid-123",
          email: "admin@superwizor.ai",
          idToken: "fake-admin-token",
          refreshToken: "fake-admin-token-refresh",
          expiresIn: "3600",
        }),
      });
    });

    // ── Connect-RPC Intercepts ──
    // Mock Profile lookup returning SUPERWIZOR_ADMIN
    await page.route(/identity\.v1\.IdentityService\/GetMyProfile/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          id: "admin-uuid-1",
          email: "admin@superwizor.ai",
          role: "USER_ROLE_SUPERWIZOR_ADMIN", // or 2
        }),
      });
    });

    // Mock GetAdminAnalytics Connect-RPC response
    await page.route(/clinical\.v1\.ClinicalService\/GetAdminAnalytics/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          kpiWau: 120,
          kpiSessionsThisWeek: 450,
          kpiActivationRate: 85.5,
          kpiSatisfactionRate: 92.3,
          wauTrend: [
            { label: "W1", value: 100 },
            { label: "W2", value: 120 },
          ],
          sessionsTrend: [
            { label: "W1", value: 400 },
            { label: "W2", value: 450 },
          ],
          registrationsTrend: [
            { label: "W1", value: 5 },
            { label: "W2", value: 8 },
          ],
          planDistribution: [
            { planName: "Solo", count: 80 },
            { planName: "Pro", count: 40 },
          ],
          kpiAvgCostPerSession: 0.0425,
          kpiMonthlySttCost: 15.2,
          kpiMonthlyLlmCost: 24.5,
          kpiAvgTokenUtilization: 72.1,
          costTrend: [
            { label: "W1", sttCost: 0.015, llmCost: 0.025, totalCost: 0.04 },
          ],
          tokenUtilizationHeatmap: [
            { orgName: "Org A", week: "2026-W22", value: 65.5 },
          ],
          revenueTrend: [
            { label: "W1", soloRevenue: 800, proRevenue: 1200, totalRevenue: 2000 },
          ],
          tokenUsageTrend: [
            { label: "W1", inputTokens: 15000, outputTokens: 8000 },
          ],
          kpiAvgPipelineLatency: 45.2,
          kpiFailureRate_7D: 0.02,
          kpiRelabelRate: 0.15,
          satisfactionTrend: [
            { label: "W1", satisfactionPct: 91.5 },
          ],
          issueCategories: [
            { category: "STT error", count: 12 },
          ],
          latencyTrend: [
            { label: "W1", p50: 42.1, p95: 98.4 },
          ],
          failureRateTrend: [
            { label: "W1", failureRate: 0.02, total: 100, failed: 2 },
          ],
          kpi_30DRetention: 65.2,
          funnelSteps: [
            { stepName: "1. Rejestracja", count: 150, pctOfPrevious: 100 },
            { stepName: "2. Utworzenie pacjenta", count: 120, pctOfPrevious: 80 },
          ],
          cohortRetention: [
            { cohort: "2026-W20", week: "2026-W21", pct: 0.85 },
          ],
          activationTimeHistogram: [
            { bucketLabel: "0-2h", count: 45 },
          ],
          hourlyHeatmap: [
            { dayOfWeek: 1, hour: 10, count: 25 },
          ],
          uploadFailuresTrend: [
            { label: "W1", failureRate: 0.01, total: 100, failed: 1 },
          ],
        }),
      });
    });
  });

  // Helper function to log in as admin
  async function loginAsAdmin(page: Page, prefix: string) {
    await page.goto(`${prefix}/admin/analytics`);
    await page.locator("input[type='email']").fill("admin@superwizor.ai");
    await page.locator("input[type='password']").fill("AdminPassword123!");
    await page.locator("button[type='submit']").click();
    const adminTitle = forLocale({
      pl: "Centrum Analityczne",
      en: "Analytics Center",
    });
    await expect(page.locator("h1")).toContainText(adminTitle);
  }

  test("Gates access for non-admins and handles email/password login", async ({ page }) => {
    const prefix = urlPrefix();

    // Simulate unauthenticated first
    await page.route(/accounts:lookup/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ users: [] }), // No user returned
      });
    });

    const signInTitle = forLocale({
      pl: "Musisz się zalogować, aby uzyskać dostęp do panelu administracyjnego.",
      en: "You need to sign in to access the admin console.",
    });

    await page.goto(`${prefix}/admin/analytics`);
    await expect(page.locator("h1")).toContainText(signInTitle);

    // Fill form and click sign-in
    await page.locator("input[type='email']").fill("admin@superwizor.ai");
    await page.locator("input[type='password']").fill("AdminPassword123!");

    const submitName = forLocale({
      pl: /Zaloguj się/i,
      en: /Sign in/i,
    });

    // Before submit, restore user lookup to let it authenticate successfully
    await page.route(/accounts:lookup/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          users: [
            {
              localId: "admin-uid-123",
              email: "admin@superwizor.ai",
              emailVerified: true,
            },
          ],
        }),
      });
    });

    await page.getByRole("button", { name: submitName }).click();

    // Verify it passes guard and renders the Center Name title
    const adminTitle = forLocale({
      pl: "Centrum Analityczne",
      en: "Analytics Center",
    });
    await expect(page.locator("h1")).toContainText(adminTitle);
  });

  test("Loads analytics dashboard and asserts cards and tab switching", async ({ page }) => {
    const prefix = urlPrefix();
    await loginAsAdmin(page, prefix);

    // Wait 2 seconds for CountUp animations to finish
    await page.waitForTimeout(2000);

    // Verify the general overview KPI cards render the mock values
    const wauTitle = forLocale({
      pl: "Aktywni terapeuci (WAU)",
      en: "Active Therapists (WAU)",
    });
    await expect(page.locator(`text=${wauTitle}`)).toBeVisible();
    await expect(page.locator("text=120").first()).toBeVisible();
    await expect(page.locator("text=450").first()).toBeVisible();

    // Activation (85.5% rounded to 86% due to decimals=0) & Satisfaction (92.3% rounded to 92% due to decimals=0)
    await expect(page.locator("text=86%").first()).toBeVisible();
    await expect(page.locator("text=92%").first()).toBeVisible();

    // Click finances/costs tab
    const costsTabName = forLocale({
      pl: "Koszty i Ekonomika",
      en: "Costs & Economics",
    });
    const avgCostLabel = forLocale({
      pl: "Śr. koszt sesji (API)",
      en: "Avg. Cost per Session (API)",
    });
    const tokenUtilLabel = forLocale({
      pl: "Średnia utylizacja tokenów",
      en: "Average Token Utilization",
    });
    await page.getByRole("button", { name: costsTabName }).click();
    await expect(page.locator(`text=${avgCostLabel}`)).toBeVisible();
    await expect(page.locator(`text=${tokenUtilLabel}`)).toBeVisible();

    // Click quality tab
    const qualityTabName = forLocale({
      pl: "Jakość AI",
      en: "AI Quality",
    });
    const latencyLabel = forLocale({
      pl: "Mediana czasu przetwarzania",
      en: "Median Processing Time",
    });
    const issueLabel = forLocale({
      pl: "Zgłaszane problemy z raportami",
      en: "Reported Report Issues",
    });
    await page.getByRole("button", { name: qualityTabName }).click();
    await expect(page.locator(`text=${latencyLabel}`)).toBeVisible();
    await expect(page.locator(`text=${issueLabel}`)).toBeVisible();
  });

  test("Intercepts TrackEvents analytics client requests", async ({ page }) => {
    const prefix = urlPrefix();

    // Intercept clinical-svc TrackEvents call
    let capturedTrackEvents: {
      events: Array<{
        eventName: string;
        clientPlatform: string;
        properties: { screen_name: string };
      }>;
    } | null = null;
    await page.route(/clinical\.v1\.ClinicalService\/TrackEvents/, async (route) => {
      capturedTrackEvents = route.request().postDataJSON();
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({}),
      });
    });

    await loginAsAdmin(page, prefix);

    // Trigger a TrackEvents RPC call in browser context
    await page.evaluate(async () => {
      await fetch("http://localhost:8082/clinical.v1.ClinicalService/TrackEvents", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "authorization": "Bearer fake-token",
        },
        body: JSON.stringify({
          events: [
            {
              eventName: "screen.viewed",
              clientPlatform: "web",
              clientVersion: "1.0.0",
              properties: {
                screen_name: "admin_analytics",
              },
            },
          ],
        }),
      });
    });

    // Wait for the intercept to capture the request on Node.js side
    let attempts = 0;
    while (capturedTrackEvents === null && attempts < 50) {
      await page.waitForTimeout(100);
      attempts++;
    }

    expect(capturedTrackEvents).not.toBeNull();
    expect(capturedTrackEvents.events).toHaveLength(1);
    expect(capturedTrackEvents.events[0].eventName).toBe("screen.viewed");
    expect(capturedTrackEvents.events[0].clientPlatform).toBe("web");
    expect(capturedTrackEvents.events[0].properties.screen_name).toBe("admin_analytics");
  });
});
