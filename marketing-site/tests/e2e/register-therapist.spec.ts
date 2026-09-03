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
  mockCheckEmailExists,
  mockCheckPhoneNumberExists,
} from "./fixtures/connect-rpc";
import { RegisterTherapistPage } from "./pages/register.page";

// ── Setup shared by all tests ──────────────────────────────────────

test.beforeEach(async ({ page }) => {
  await mockFirebaseAuth(page, THERAPIST_USER);
  await mockListModalities(page);
  await mockCheckEmailExists(page, false);
  await mockCheckPhoneNumberExists(page, false);
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
    
    // Step 1: Pitch only
    await expect(page.locator("#start-trial-btn")).toBeVisible();
    await expect(reg.emailInput).not.toBeVisible();
    await expect(reg.firstNameInput).not.toBeVisible();

    // Go to Step 2
    await page.locator("#start-trial-btn").click();
    await expect(page.locator("#signup-email-btn")).toBeVisible();

    // Go to Step 3
    await page.locator("#signup-email-btn").click();
    await expect(reg.emailInput).toBeVisible();
    await expect(reg.passwordInput).toBeVisible();
    await expect(reg.tosCheckbox).toBeVisible();
    await expect(reg.firstNameInput).not.toBeVisible();

    // Fill Step 3 & Go to Step 4
    await reg.emailInput.fill("e2e@example.com");
    await reg.passwordInput.fill("Sup3rwizor!");
    await reg.tosCheckbox.check();
    await reg.nextStepButton.click();

    // Step 4
    await expect(reg.firstNameInput).toBeVisible();
    await expect(reg.lastNameInput).toBeVisible();
    await expect(reg.phoneNumberInput).toBeVisible();
    await expect(reg.uiLanguageField).not.toBeVisible();

    // Fill Step 4 & Go to Step 5
    await reg.firstNameInput.fill("Anna");
    await reg.lastNameInput.fill("Kowalska");
    await reg.phoneNumberInput.fill("+48500100200");
    await reg.nextStepButton.click();

    // Step 5
    await expect(reg.uiLanguageField).toBeVisible();
  });

  test("shows validation errors on empty submit", async ({ page }) => {
    const prefix = urlPrefix();
    const reg = new RegisterTherapistPage(page);

    await reg.goto(prefix);

    // Go to Step 3
    await page.locator("#start-trial-btn").click();
    await page.locator("#signup-email-btn").click();

    // Submit empty fields in Step 3
    await reg.nextStepButton.click();

    // Still on the same page — no redirect happened.
    await reg.expectStillOnRegisterPage(prefix);
    // At least one validation error is shown.
    await reg.expectValidationErrors();
  });

  test("shows validation error on empty phone number in Step 4", async ({ page }) => {
    const prefix = urlPrefix();
    const reg = new RegisterTherapistPage(page);

    await reg.goto(prefix);

    // Go to Step 3
    await page.locator("#start-trial-btn").click();
    await page.locator("#signup-email-btn").click();

    // Step 3 -> Step 4
    await reg.emailInput.fill("e2e@example.com");
    await reg.passwordInput.fill("Sup3rwizor!");
    await reg.tosCheckbox.check();
    await reg.nextStepButton.click();

    // Step 4
    await reg.firstNameInput.fill("Anna");
    await reg.lastNameInput.fill("Kowalska");
    // Leave phone number empty
    await reg.nextStepButton.click();

    // Wciąż na kroku 4 (pole języka z kroku 5 jeszcze niewidoczne)
    await expect(reg.uiLanguageField).not.toBeVisible();
    await expect(page.locator("p[role='alert']")).toBeVisible();
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

    // UpdateProfile leci tylko wtedy, gdy formularz zebrał pola
    // opcjonalne — dziś jest nim numer telefonu. professionalTitle
    // usunięto z rejestracji (zostało w panelu admina), więc nie ma go
    // czego tu oczekiwać.
    const updated = updateProfile.getCaptured();
    expect(updated).not.toBeNull();
    // Formularz formatuje numer przy wpisywaniu (grupy po trzy cyfry
    // rozdzielone myślnikiem), więc do backendu leci postać
    // sformatowana. Asercja na surowy ciąg opisywała stan sprzed
    // wprowadzenia formatowania.
    expect(updated!.phoneNumber).toBe("+48 500-100-200");
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
    await expect(page.locator("p[role='alert']").first()).toBeVisible();
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
    await expect(page.locator("p[role='alert']").first()).toBeVisible();
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

test("login page back button redirects to landing page", async ({ page }) => {
  const prefix = urlPrefix();
  await page.goto(`${prefix}/login`);

  const backLabel = forLocale({
    pl: /wróć do strony głównej/i,
    en: /back to home/i,
  });
  await page.getByRole("link", { name: backLabel }).click();

  // Should land on the landing page (which is /pl/ or /en/ or / depending on prefix)
  await expect(page).toHaveURL(new RegExp(`(${prefix}|/pl|/en)?/?$`));
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

