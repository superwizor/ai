// Connect-RPC mock factory for Playwright E2E tests.
//
// Provides typed mock installers for every Connect-RPC service method
// that E2E tests intercept. Each function takes a Page and optional
// overrides for the response payload — so specs only specify what's
// relevant to the test scenario, not 140 lines of boilerplate.

import type { Page } from "@playwright/test";

// ── Identity Service ───────────────────────────────────────────────

/**
 * Mock identity.v1.IdentityService/GetMyProfile.
 * Defaults to returning a SUPERWIZOR_ADMIN.
 */
export async function mockGetMyProfile(
  page: Page,
  overrides: Record<string, unknown> = {},
) {
  await page.route(
    /identity\.v1\.IdentityService\/GetMyProfile/,
    async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          id: "admin-uuid-1",
          email: "admin@superwizor.ai",
          role: "USER_ROLE_SUPERWIZOR_ADMIN",
          ...overrides,
        }),
      });
    },
  );
}

/**
 * Mock identity.v1.IdentityService/CreateUser.
 * Returns the captured request body so specs can assert on the payload.
 */
export async function mockCreateUser(
  page: Page,
  overrides: Record<string, unknown> = {},
): Promise<{ getCaptured: () => Record<string, unknown> | null }> {
  let captured: Record<string, unknown> | null = null;

  await page.route(
    /identity\.v1\.IdentityService\/CreateUser/,
    async (route) => {
      captured = route.request().postDataJSON();
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          id: "user-uuid-1",
          firebaseUid: "test-uid-12345",
          email: "e2e@example.com",
          firstName: "Anna",
          lastName: "Kowalska",
          role: 1,
          ...overrides,
        }),
      });
    },
  );

  return { getCaptured: () => captured };
}

/**
 * Mock identity.v1.IdentityService/UpdateProfile.
 * Returns the captured request body for assertions.
 */
export async function mockUpdateProfile(
  page: Page,
): Promise<{ getCaptured: () => Record<string, unknown> | null }> {
  let captured: Record<string, unknown> | null = null;

  await page.route(
    /identity\.v1\.IdentityService\/UpdateProfile/,
    async (route) => {
      captured = route.request().postDataJSON();
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          id: "user-uuid-1",
          email: "e2e@example.com",
          firstName: captured?.firstName || "Maciej",
          lastName: captured?.lastName || "Kolodziejczyk",
          phoneNumber: captured?.phoneNumber || "+48 510417781",
          professionalTitle: captured?.professionalTitle || "Psycholog",
          credentialsNumber: captured?.credentialsNumber || "LIC-1234",
          defaultModalityId: captured?.defaultModalityId || "44f77c8e-8a71-4770-96f3-42e13297a7e8",
          organizationId: "org-uuid-1",
          role: "USER_ROLE_THERAPIST",
        }),
      });
    },
  );

  return { getCaptured: () => captured };
}

/**
 * Mock identity.v1.IdentityService/CheckEmailExists.
 */
export async function mockCheckEmailExists(
  page: Page,
  exists = false,
) {
  await page.route(
    /identity\.v1\.IdentityService\/CheckEmailExists/,
    async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ exists }),
      });
    },
  );
}

/**
 * Mock identity.v1.IdentityService/GetMyOrganization.
 */
export async function mockGetMyOrganization(
  page: Page,
  overrides: Record<string, unknown> = {},
) {
  await page.route(
    /identity\.v1\.IdentityService\/GetMyOrganization/,
    async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          id: "org-uuid-1",
          legalName: "Maciej Kolodziejczyk Org",
          type: 1, // solo
          taxId: "6793219020",
          vatIdEu: "PL6793219020",
          headquartersAddress: {
            countryCode: "PL",
            city: "Kraków",
            streetLine: "Odrzańska",
            buildingNumber: "10",
            unitNumber: "48",
            postalCode: "30-408",
            region: "Małopolskie",
          },
          ...overrides,
        }),
      });
    },
  );
}

/**
 * Mock identity.v1.IdentityService/UpdateMyOrganization.
 */
export async function mockUpdateMyOrganization(
  page: Page,
): Promise<{ getCaptured: () => Record<string, unknown> | null }> {
  let captured: Record<string, unknown> | null = null;

  await page.route(
    /identity\.v1\.IdentityService\/UpdateMyOrganization/,
    async (route) => {
      captured = route.request().postDataJSON();
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ id: "org-uuid-1" }),
      });
    },
  );

  return { getCaptured: () => captured };
}

/**
 * Mock billing.v1.BillingService/GetSubscription.
 */
export async function mockGetSubscription(
  page: Page,
  overrides: Record<string, unknown> = {},
) {
  await page.route(
    /billing\.v1\.BillingService\/GetSubscription/,
    async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          id: "sub-uuid-1",
          organizationId: "org-uuid-1",
          planTier: "TRIAL",
          status: "TRIALING",
          tokensPerPeriod: 30,
          tokensUsedThisPeriod: 5,
          tokensReservedThisPeriod: 0,
          // google.protobuf.Timestamp w kodowaniu JSON Connecta to
          // ŁAŃCUCH RFC3339, nie obiekt {seconds}. Kształt obiektowy
          // należy do kodowania binarnego proto i klient odrzuca go
          // komunikatem "cannot decode message google.protobuf.Timestamp
          // from JSON: object" — co wywracało cały ekran /account i
          // /dashboard, a wyglądało na błąd nawigacji (net::ERR_ABORTED).
          currentPeriodEnd: "2026-06-11T12:33:29Z",
          ...overrides,
        }),
      });
    },
  );
}

// ── Clinical Service ───────────────────────────────────────────────

/** Minimal valid GetAdminAnalytics response with all required fields. */
const DEFAULT_ANALYTICS = {
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
  modalityDistribution: [],
  kpiAvgCostPerSession: 0.0425,
  kpiMonthlySttCost: 15.2,
  kpiMonthlyLlmCost: 24.5,
  kpiAvgTokenUtilization: 72.1,
  costTrend: [{ label: "W1", sttCost: 0.015, llmCost: 0.025, totalCost: 0.04 }],
  tokenUtilizationHeatmap: [{ orgName: "Org A", week: "2026-W22", value: 65.5 }],
  revenueTrend: [{ label: "W1", soloRevenue: 800, proRevenue: 1200, totalRevenue: 2000 }],
  tokenUsageTrend: [{ label: "W1", inputTokens: 15000, outputTokens: 8000 }],
  kpiAvgPipelineLatency: 45.2,
  kpiFailureRate7d: 0.02,
  kpiRelabelRate: 0.15,
  satisfactionTrend: [{ label: "W1", satisfactionPct: 91.5 }],
  issueCategories: [{ category: "STT error", count: 12 }],
  latencyTrend: [{ label: "W1", p50: 42.1, p95: 98.4 }],
  failureRateTrend: [{ label: "W1", failureRate: 0.02, total: 100, failed: 2 }],
  kpi30dRetention: 65.2,
  funnelSteps: [
    { stepName: "1. Rejestracja", count: 150, pctOfPrevious: 100 },
    { stepName: "2. Utworzenie pacjenta", count: 120, pctOfPrevious: 80 },
  ],
  cohortRetention: [{ cohort: "2026-W20", week: "2026-W21", pct: 0.85 }],
  activationTimeHistogram: [{ bucketLabel: "0-2h", count: 45 }],
  hourlyHeatmap: [{ dayOfWeek: 1, hour: 10, count: 25 }],
  uploadFailuresTrend: [{ label: "W1", failureRate: 0.01, total: 100, failed: 1 }],
  platformFixedCosts: [],
  sessionDurationTrend: [{ label: "W1", value: 2700 }],
  kpiAvgSessionDuration: 2700,
} as const;

/**
 * Mock clinical.v1.ClinicalService/GetAdminAnalytics.
 * Merges overrides into DEFAULT_ANALYTICS, so tests can override
 * individual fields without specifying the full 40-field response.
 */
export async function mockGetAdminAnalytics(
  page: Page,
  overrides: Record<string, unknown> = {},
) {
  await page.route(
    /clinical\.v1\.ClinicalService\/GetAdminAnalytics/,
    async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ ...DEFAULT_ANALYTICS, ...overrides }),
      });
    },
  );
}

/**
 * Mock clinical.v1.ClinicalService/GetAdminAnalytics to return an error.
 * Simulates a backend failure for testing error UI.
 */
export async function mockGetAdminAnalyticsError(
  page: Page,
  code = 13,
  message = "internal server error",
) {
  await page.route(
    /clinical\.v1\.ClinicalService\/GetAdminAnalytics/,
    async (route) => {
      await route.fulfill({
        status: 500,
        contentType: "application/json",
        body: JSON.stringify({ code, message }),
      });
    },
  );
}

/** Standard modality catalog for registration form tests. */
const MODALITY_CATALOG = [
  {
    id: "44f77c8e-8a71-4770-96f3-42e13297a7e8",
    systemCode: "CBT",
    displayName: "Poznawczo-behawioralna (CBT)",
    isSupported: true,
  },
  {
    id: "33e66b8d-8a71-4770-96f3-42e13297a7e7",
    systemCode: "UNIV",
    displayName: "Uniwersalny / Integracyjny",
    isSupported: true,
  },
];

export { MODALITY_CATALOG };

/**
 * Mock clinical.v1.ClinicalService/ListModalities.
 */
export async function mockListModalities(page: Page) {
  await page.route(
    /clinical\.v1\.ClinicalService\/ListModalities/,
    async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ modalities: MODALITY_CATALOG }),
      });
    },
  );
}

/**
 * Intercept clinical.v1.ClinicalService/TrackEvents and return the
 * captured events for assertion.
 */
export async function mockTrackEvents(
  page: Page,
): Promise<{ getCaptured: () => Record<string, unknown> | null }> {
  let captured: Record<string, unknown> | null = null;

  await page.route(
    /clinical\.v1\.ClinicalService\/TrackEvents/,
    async (route) => {
      captured = route.request().postDataJSON();
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({}),
      });
    },
  );

  return { getCaptured: () => captured };
}
