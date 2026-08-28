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
          defaultModalityId: captured?.defaultModalityId || "dd8d84ff-16a5-470a-95cc-4b5a99e61f6b",
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
    { label: "2026-34", value: 100 },
    { label: "2026-35", value: 120 },
  ],
  sessionsTrend: [
    { label: "2026-34", value: 400 },
    { label: "2026-35", value: 450 },
  ],
  registrationsTrend: [
    { label: "2026-34", value: 5 },
    { label: "2026-35", value: 8 },
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
  costTrend: [{ label: "2026-34", sttCost: 0.015, llmCost: 0.025, totalCost: 0.04 }],
  tokenUtilizationHeatmap: [{ orgName: "Org A", week: "2026-22", value: 65.5 }],
  revenueTrend: [{ label: "2026-34", soloRevenue: 800, proRevenue: 1200, totalRevenue: 2000 }],
  tokenUsageTrend: [{ label: "2026-34", inputTokens: 15000, outputTokens: 8000 }],
  kpiAvgPipelineLatency: 45.2,
  kpiFailureRate7d: 2.0,
  kpiRelabelRate: 15.0,
  satisfactionTrend: [{ label: "2026-34", satisfactionPct: 91.5 }],
  issueCategories: [{ category: "STT error", count: 12 }],
  latencyTrend: [{ label: "2026-34", p50: 42.1, p95: 98.4 }],
  failureRateTrend: [{ label: "2026-34", failureRate: 2.0, total: 100, failed: 2 }],
  kpi30dRetention: 65.2,
  funnelSteps: [
    { stepName: "1. Rejestracja", count: 150, pctOfPrevious: 100 },
    { stepName: "2. Utworzenie pacjenta", count: 120, pctOfPrevious: 80 },
    { stepName: "3. Zakończenie sesji", count: 90, pctOfPrevious: 75 },
    { stepName: "4. Przeczytanie raportu", count: 70, pctOfPrevious: 77.8 },
    { stepName: "5. Ocena raportu", count: 40, pctOfPrevious: 57.1 },
  ],
  cohortRetention: [{ cohort: "2026-20", week: "2026-21", pct: 85.0 }],
  activationTimeHistogram: [{ bucketLabel: "0-2h", count: 45 }],
  hourlyHeatmap: [{ dayOfWeek: 1, hour: 10, count: 25 }],
  uploadFailuresTrend: [{ label: "2026-34", failureRate: 1.0, total: 100, failed: 1 }],
  platformFixedCosts: [],
  sessionDurationTrend: [{ label: "2026-34", value: 2700 }],
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

/**
 * Standard modality catalog for registration form tests.
 *
 * UUID-y sa PRAWDZIWE — skopiowane z tabeli `modalities`. Wczesniej byly
 * tu wartosci zmyslone, identyczne z zaszytym "katalogiem zapasowym"
 * w kodzie produkcyjnym, wiec atrapa potwierdzala sama siebie i nie mogla
 * wykryc, ze te id nie istnieja w bazie (wiez fk_users_default_modality,
 * SQLSTATE 23503 → UpdateProfile 500 → "Pomin" w onboardingu nie dzialalo).
 */
const MODALITY_CATALOG = [
  {
    id: "dd8d84ff-16a5-470a-95cc-4b5a99e61f6b",
    systemCode: "CBT",
    displayName: "Poznawczo-behawioralna (CBT)",
    isSupported: true,
  },
  {
    id: "081ce34d-43d2-4215-b7f9-8120ac2e430c",
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

// ── Invitations (docs/39, docs/43) ─────────────────────────────────

/**
 * Mock identity.v1.IdentityService/GetInvitationPreview.
 * Defaults to a THERAPIST invite — the variant that must collect a
 * phone number. Pass `{ invitedRole: "USER_ROLE_PATIENT" }` for the
 * pseudonymous client variant.
 */
export async function mockGetInvitationPreview(
  page: Page,
  overrides: Record<string, unknown> = {},
) {
  await page.route(
    /identity\.v1\.IdentityService\/GetInvitationPreview/,
    async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          email: "zaproszony@example.com",
          invitedRole: "USER_ROLE_THERAPIST",
          organizationName: "Klinika Testowa",
          inviterFirstName: "Maciek",
          requiresPairingCode: false,
          ...overrides,
        }),
      });
    },
  );
}

/**
 * Mock identity.v1.IdentityService/AcceptInvitation.
 * Returns the captured request so specs can assert what the form sent —
 * phone_number in particular (see accept-invite-phone.spec.ts).
 */
export async function mockAcceptInvitation(
  page: Page,
  overrides: Record<string, unknown> = {},
): Promise<{ getCaptured: () => Record<string, unknown> | null }> {
  let captured: Record<string, unknown> | null = null;

  await page.route(
    /identity\.v1\.IdentityService\/AcceptInvitation/,
    async (route) => {
      captured = route.request().postDataJSON();
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          user: {
            id: "user-uuid-invited",
            email: "zaproszony@example.com",
            firstName: "Jan",
            lastName: "Zaproszony",
            role: "USER_ROLE_THERAPIST",
          },
          ...overrides,
        }),
      });
    },
  );

  return { getCaptured: () => captured };
}
