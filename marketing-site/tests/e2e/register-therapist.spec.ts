// Playwright E2E: /register/therapist email registration flow.
//
// Split into focused, isolated scenarios instead of one 200-line
// monolith. Each test exercises exactly one behaviour so failures
// pinpoint the broken feature immediately.
//
// Fixtures:  fixtures/auth.ts       — Firebase Auth intercepts
//            fixtures/connect-rpc.ts — identity-svc & clinical-svc mocks
// Page obj:  pages/register.page.ts — selectors & high-level actions

import { test, expect } from "@playwright/test";
import { forLocale, urlPrefix } from "./_locales";
import { mockFirebaseAuth, THERAPIST_USER } from "./fixtures/auth";
import {
  mockCreateUser,
  mockUpdateProfile,
  mockListModalities,
} from "./fixtures/connect-rpc";
import { RegisterTherapistPage } from "./pages/register.page";

// ── Setup shared by all tests ──────────────────────────────────────

test.beforeEach(async ({ page }) => {
  await mockFirebaseAuth(page, THERAPIST_USER);
  await mockListModalities(page);
});

// ── Scenarios ──────────────────────────────────────────────────────

test.describe("Therapist Registration", () => {
  test("renders form with heading and required fields visible", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    const reg = new RegisterTherapistPage(page);

    await reg.goto(prefix);

    await reg.expectHeading();
    await expect(reg.firstNameInput).toBeVisible();
    await expect(reg.lastNameInput).toBeVisible();
    await expect(reg.emailInput).toBeVisible();
    await expect(reg.nextStepButton).toBeVisible();

    // Step 2 & 3 fields should be hidden initially
    await expect(reg.passwordInput).not.toBeVisible();
    await expect(reg.modalitySelect).not.toBeVisible();
    await expect(reg.tosCheckbox).not.toBeVisible();
  });

  test("shows validation errors on empty submit", async ({ page }) => {
    const prefix = urlPrefix();
    const reg = new RegisterTherapistPage(page);

    await reg.goto(prefix);
    await reg.nextStepButton.click();

    // Still on the same page — no redirect happened.
    await reg.expectStillOnRegisterPage(prefix);
    // At least one validation error is shown.
    await reg.expectValidationErrors();
  });

  test("happy path: fills form, fires CreateUser + UpdateProfile, redirects to verify-email", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    const reg = new RegisterTherapistPage(page);
    const createUser = await mockCreateUser(page);
    const updateProfile = await mockUpdateProfile(page);

    await reg.goto(prefix);
    await reg.fillRequiredFields();
    await reg.submit();

    // Should redirect to verify-email with the email query param.
    await reg.expectRedirectToVerifyEmail(prefix, "e2e@example.com");

    // Assert CreateUser payload shape.
    const created = createUser.getCaptured();
    expect(created).not.toBeNull();
    expect(created!.firebaseUid).toBe("test-uid-12345");
    expect(created!.email).toBe("e2e@example.com");
    expect([1, "USER_ROLE_THERAPIST"]).toContain(created!.role);
    expect(created!.firstName).toBe("Anna");
    expect(created!.lastName).toBe("Kowalska");

    // Assert UpdateProfile was called with the selected modality.
    const updated = updateProfile.getCaptured();
    expect(updated).not.toBeNull();
    expect(updated!.defaultModalityId).toBe(
      "44f77c8e-8a71-4770-96f3-42e13297a7e8",
    );
  });

  test("shows server error when Firebase rejects email-already-in-use", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    const reg = new RegisterTherapistPage(page);

    // Override accounts:signUp to return email-already-in-use error.
    await page.route(/accounts:signUp/, async (route) => {
      await route.fulfill({
        status: 400,
        contentType: "application/json",
        body: JSON.stringify({
          error: {
            code: 400,
            message: "EMAIL_EXISTS",
            errors: [{ message: "EMAIL_EXISTS", domain: "global", reason: "invalid" }],
          },
        }),
      });
    });

    await reg.goto(prefix);
    await reg.fillRequiredFields();
    await reg.submit();

    // Should stay on the page and show an error alert.
    await reg.expectStillOnRegisterPage(prefix);
    // Use p[role='alert'] to exclude Next.js __next-route-announcer__ div.
    await expect(page.locator("p[role='alert']")).toBeVisible();
  });

  test("shows server error when identity-svc is unreachable", async ({
    page,
  }) => {
    const prefix = urlPrefix();
    const reg = new RegisterTherapistPage(page);

    // Let Firebase succeed but identity-svc CreateUser fails.
    await page.route(
      /identity\.v1\.IdentityService\/CreateUser/,
      async (route) => {
        await route.abort("connectionrefused");
      },
    );

    await reg.goto(prefix);
    await reg.fillRequiredFields();
    await reg.submit();

    // Should stay on page and show network error.
    await reg.expectStillOnRegisterPage(prefix);
    await expect(page.locator("p[role='alert']")).toBeVisible();
  });
});

// ── Login page smoke ───────────────────────────────────────────────

test("login page loads and displays login form", async ({ page }) => {
  const prefix = urlPrefix();
  await page.goto(`${prefix}/login`);
  await expect(page).toHaveURL(new RegExp(`(${prefix}|/pl)?/login\\/?$`));

  const headingText = forLocale({
    pl: "Witaj z powrotem",
    en: "Welcome back",
  });
  await expect(page.locator("h1")).toContainText(headingText);

  await expect(page.locator("input[type='email']")).toBeVisible();
  await expect(page.locator("input[type='password']")).toBeVisible();
});

// ── Password Reset Flow ────────────────────────────────────────────

test("password reset shows success message when valid email submitted", async ({
  page,
}) => {
  const prefix = urlPrefix();

  // Mock the Firebase password reset endpoint.
  await page.route(/accounts:sendOobCode/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ email: "test@example.com" }),
    });
  });

  await page.goto(`${prefix}/login`);

  // Fill email field.
  await page.locator("input[type='email']").fill("test@example.com");

  // Click "Nie pamiętam hasła" / "Forgot password?" button.
  const forgotLabel = forLocale({
    pl: /nie pamiętam hasła/i,
    en: /forgot password/i,
  });
  await page.getByRole("button", { name: forgotLabel }).click();

  // Should show a success status message (not an error alert).
  const successMessage = page.locator("[role='status']");
  await expect(successMessage).toBeVisible();

  const sentText = forLocale({
    pl: "Wysłaliśmy link do resetu hasła",
    en: "We've sent a password-reset link",
  });
  await expect(successMessage).toContainText(sentText);
});

test("password reset shows error when email field is empty", async ({
  page,
}) => {
  const prefix = urlPrefix();
  await page.goto(`${prefix}/login`);

  // Click forgot password without filling email.
  const forgotLabel = forLocale({
    pl: /nie pamiętam hasła/i,
    en: /forgot password/i,
  });
  await page.getByRole("button", { name: forgotLabel }).click();

  // Should show an error asking for email.
  const errorAlert = page.locator("p[role='alert']");
  await expect(errorAlert).toBeVisible();
});

