// Playwright happy-path: /register/therapist email flow.
//
// docs/18 §13.2 acceptance: visitor lands on the form, fills the
// required fields, accepts ToS, submit fires:
//   1. Firebase createUserWithEmailAndPassword (we intercept this via
//      the auth emulator — see CI setup below),
//   2. identityClient.createUser (we intercept the Connect request,
//      assert payload shape, return a stub User),
//   3. window.location → verify-email page with ?email= populated.
//
// Local run: `pnpm exec playwright test` boots `pnpm dev` itself.
// CI run: pre-start the Firebase Auth emulator at :9099 (see
// firebase.json) and a Go httptest stub for identity-svc, OR rely on
// the page.route() intercepts in this file for a purely-frontend E2E.
// The intercept path is what the in-session smoke verifies — we don't
// hit real backends here. The full-stack live run lives in CI.

import { test, expect } from "@playwright/test";
import { forLocale, urlPrefix } from "./_locales";

test("therapist email form: validates + fires CreateUser on submit", async ({ page }) => {
  // ── Network intercepts ────────────────────────────────────────
  //
  // Firebase Auth — match both real Google endpoints AND the emulator
  // proxy at 127.0.0.1:9099. Local dev defaults to the emulator
  // (.env.local NEXT_PUBLIC_FIREBASE_USE_EMULATOR=1); CI runs without
  // it. Same intercept handles both — they share the URL path suffix.
  await page.route(
    /accounts:signUp/,
    async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          kind: "identitytoolkit#SignupNewUserResponse",
          idToken: "fake-id-token",
          email: "e2e@example.com",
          refreshToken: "fake-refresh-token",
          expiresIn: "3600",
          localId: "test-uid-12345",
        }),
      });
    },
  );

  // Firebase Auth — sendOobCode (verification email).
  await page.route(/accounts:sendOobCode/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ email: "e2e@example.com" }),
    });
  });

  // Firebase Auth — accounts:lookup (called by reload() / currentUser).
  await page.route(/accounts:lookup/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        kind: "identitytoolkit#GetAccountInfoResponse",
        users: [
          {
            localId: "test-uid-12345",
            email: "e2e@example.com",
            emailVerified: false,
            providerUserInfo: [],
            validSince: "1",
            createdAt: String(Date.now()),
          },
        ],
      }),
    });
  });

  // Firebase token refresh.
  await page.route(/securetoken\.googleapis\.com|\/token($|\?)/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        access_token: "fake-id-token",
        expires_in: "3600",
        token_type: "Bearer",
        refresh_token: "fake-refresh-token",
        id_token: "fake-id-token",
        user_id: "test-uid-12345",
        project_id: "demo-superwizor",
      }),
    });
  });

  // Connect-RPC: identity.v1.IdentityService/CreateUser
  // Connect-Web posts to /identity.v1.IdentityService/CreateUser
  // relative to the configured base URL (NEXT_PUBLIC_IDENTITY_URL).
  // Capture the request, assert its body shape, return a stub User.
  let capturedCreateUser: { firebaseUid?: string; email?: string; role?: number | string; firstName?: string; lastName?: string } | null = null;
  await page.route(/identity\.v1\.IdentityService\/CreateUser/, async (route) => {
    const body = route.request().postDataJSON();
    capturedCreateUser = body;
    // Connect protocol response — a JSON message matching the proto
    // shape. id is what UpdateProfile would target next.
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        id: "user-uuid-1",
        firebaseUid: "test-uid-12345",
        email: "e2e@example.com",
        firstName: "Anna",
        lastName: "Kowalska",
        role: 1, // UserRole.THERAPIST
      }),
    });
  });

  // UpdateProfile — not strictly called for the minimal happy path
  // (no optional extras filled), but stub it just in case the form
  // submits with modality (which it must — modality is required).
  let capturedUpdateProfile: { defaultModalityId?: string } | null = null;
  await page.route(/identity\.v1\.IdentityService\/UpdateProfile/, async (route) => {
    capturedUpdateProfile = route.request().postDataJSON();
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ id: "user-uuid-1" }),
    });
  });

  // Mock ListModalities Connect-RPC response
  await page.route(/clinical\.v1\.ClinicalService\/ListModalities/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        modalities: [
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
        ],
      }),
    });
  });

  // ── Test steps ───────────────────────────────────────────────
  //
  // Per-locale UI copy. The PL+EN happy paths run from a single spec
  // (see playwright.config.ts projects); each project surfaces the
  // copy via forLocale() and adjusts the route prefix via urlPrefix().
  const prefix = urlPrefix();
  const heading = forLocale({
    pl: "Zarejestruj się jako terapeuta",
    en: "Sign up as a therapist",
  });
  const submitName = forLocale({
    pl: /Załóż konto/i,
    en: /Create account/i,
  });

  await page.goto(`${prefix}/register/therapist`);
  await expect(page).toHaveURL(new RegExp(`${prefix}/register/therapist`));
  await expect(page.locator("h1")).toContainText(heading);

  // Empty submit triggers zod validation. The form should NOT navigate.
  await page.getByRole("button", { name: submitName }).click();
  await expect(page).toHaveURL(new RegExp(`${prefix}/register/therapist\\/?$`));

  // Fill minimum required fields.
  await page.locator("#email").fill("e2e@example.com");
  await page.locator("#password").fill("Sup3rwizor!");
  await page.locator("#firstName").fill("Anna");
  await page.locator("#lastName").fill("Kowalska");
  await page.locator("#modality").selectOption("44f77c8e-8a71-4770-96f3-42e13297a7e8");
  await page.locator("#tos").check();

  // Submit and wait for the redirect to verify-email.
  await page.getByRole("button", { name: submitName }).click();

  await page.waitForURL(new RegExp(`${prefix}/register/therapist/verify-email`), {
    timeout: 10_000,
  });

  // Assertions on the redirect target.
  expect(page.url()).toContain("email=e2e%40example.com");

  // Assertions on the CreateUser payload shape.
  expect(capturedCreateUser).not.toBeNull();
  expect(capturedCreateUser!.firebaseUid).toBe("test-uid-12345");
  expect(capturedCreateUser!.email).toBe("e2e@example.com");
  // Connect-Web's JSON wire format serialises enums as their proto
  // names (USER_ROLE_THERAPIST), not numeric values. Accept either to
  // stay flexible if a future Connect upgrade flips the format.
  expect([1, "USER_ROLE_THERAPIST"]).toContain(capturedCreateUser!.role);
  expect(capturedCreateUser!.firstName).toBe("Anna");
  expect(capturedCreateUser!.lastName).toBe("Kowalska");

  // UpdateProfile fired with the modality.
  expect(capturedUpdateProfile).not.toBeNull();
  expect(capturedUpdateProfile!.defaultModalityId).toBe("44f77c8e-8a71-4770-96f3-42e13297a7e8");
});

test("login page loads and displays login form", async ({ page }) => {
  const prefix = urlPrefix();
  await page.goto(`${prefix}/login`);
  await expect(page).toHaveURL(new RegExp(`(${prefix}|/pl)?/login\\/?$`));

  const heading = forLocale({
    pl: "Witaj z powrotem",
    en: "Welcome back",
  });
  await expect(page.locator("h1")).toContainText(heading);

  await expect(page.locator("input[type='email']")).toBeVisible();
  await expect(page.locator("input[type='password']")).toBeVisible();
});
