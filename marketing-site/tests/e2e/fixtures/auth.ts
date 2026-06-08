// Shared Firebase Auth + identity-svc mock fixtures for Playwright E2E.
//
// Every spec that needs an authenticated session imports `mockFirebaseAuth`
// and/or `mockAdminSession` instead of copy-pasting 60+ lines of route
// handlers. Centralised here so a Firebase SDK update that changes an
// endpoint path is a one-line fix, not a grep-and-pray across N specs.

import type { Page } from "@playwright/test";

// ── Default fake identities ────────────────────────────────────────

export const ADMIN_USER = {
  localId: "admin-uid-123",
  email: "admin@superwizor.ai",
  emailVerified: true,
} as const;

export const THERAPIST_USER = {
  localId: "test-uid-12345",
  email: "e2e@example.com",
  emailVerified: false,
} as const;

const FAKE_TOKEN = "fake-id-token";

// ── Low-level route installers ─────────────────────────────────────

/**
 * Mock Firebase Auth REST endpoints so no real Google calls happen.
 *
 * Installs intercepts for:
 *   - accounts:lookup       (getAccountInfo)
 *   - accounts:signInWithPassword
 *   - accounts:signUp       (createUserWithEmailAndPassword)
 *   - accounts:sendOobCode  (sendEmailVerification)
 *   - securetoken / token   (token refresh)
 *
 * @param page  Playwright Page
 * @param user  The fake user to return from lookup/signIn/signUp.
 *              Defaults to THERAPIST_USER.
 */
export async function mockFirebaseAuth(
  page: Page,
  user: typeof ADMIN_USER | typeof THERAPIST_USER = THERAPIST_USER,
) {
  // accounts:lookup — called by onAuthStateChanged / currentUser.reload()
  await page.route(/accounts:lookup/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        kind: "identitytoolkit#GetAccountInfoResponse",
        users: [
          {
            localId: user.localId,
            email: user.email,
            emailVerified: user.emailVerified,
            providerUserInfo: [],
            validSince: "1",
            createdAt: String(Date.now()),
          },
        ],
      }),
    });
  });

  // accounts:signInWithPassword
  await page.route(/accounts:signInWithPassword/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        localId: user.localId,
        email: user.email,
        idToken: FAKE_TOKEN,
        refreshToken: `${FAKE_TOKEN}-refresh`,
        expiresIn: "3600",
      }),
    });
  });

  // accounts:signUp — createUserWithEmailAndPassword
  await page.route(/accounts:signUp/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        kind: "identitytoolkit#SignupNewUserResponse",
        idToken: FAKE_TOKEN,
        email: user.email,
        refreshToken: `${FAKE_TOKEN}-refresh`,
        expiresIn: "3600",
        localId: user.localId,
      }),
    });
  });

  // accounts:sendOobCode — verification email
  await page.route(/accounts:sendOobCode/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ email: user.email }),
    });
  });

  // Token refresh
  await page.route(/securetoken\.googleapis\.com|\/token($|\?)/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        access_token: FAKE_TOKEN,
        expires_in: "3600",
        token_type: "Bearer",
        refresh_token: `${FAKE_TOKEN}-refresh`,
        id_token: FAKE_TOKEN,
        user_id: user.localId,
        project_id: "demo-superwizor",
      }),
    });
  });
}

/**
 * Clear the Firebase session so the page sees no signed-in user.
 * Use this to test auth-gated pages in their unsigned state.
 */
export async function mockFirebaseSignedOut(page: Page) {
  await page.route(/accounts:lookup/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ users: [] }),
    });
  });

  await page.route(/securetoken\.googleapis\.com|\/token($|\?)/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        access_token: FAKE_TOKEN,
        expires_in: "3600",
        token_type: "Bearer",
        refresh_token: `${FAKE_TOKEN}-refresh`,
        id_token: FAKE_TOKEN,
        user_id: "",
        project_id: "demo-superwizor",
      }),
    });
  });
}
