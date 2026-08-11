// Playwright E2E: Account Settings & Deletion flow tests.
//
// Validates:
// - Apple-style UI spacing and icons are present.
// - Biography ("O mnie") field is completely removed.
// - Organisation name input has correct placeholder.
// - 3-step deletion flow handles toggle checkbox, case-insensitive typing check,
//   and re-auth flow redirect.

import { test, expect } from "@playwright/test";
import { forLocale, urlPrefix } from "./_locales";
import { mockFirebaseAuth } from "./fixtures/auth";
import {
  mockGetMyProfile,
  mockGetMyOrganization,
  mockGetSubscription,
  mockListModalities,
  mockUpdateProfile,
  mockUpdateMyOrganization,
} from "./fixtures/connect-rpc";

test.describe("Account Settings & Deletion", () => {
  // Szeregowo, ale BEZ przerywania po pierwszym padnięciu.
  //
  // Te testy dzielą jedną sesję logowania z beforeEach; przy
  // fullyParallel workery wchodziły sobie w drogę i logowanie kończyło
  // się na /login zamiast /dashboard (równolegle 4 padnięcia,
  // sekwencyjnie 1).
  //
  // Tryb "serial" był tu ZŁYM narzędziem: po pierwszym padnięciu
  // Playwright pomija resztę bloku, więc licznik padnięć spadał, choć
  // testy przestawały się wykonywać ("3 did not run"). Ukrywanie
  // zamiast naprawy. "default" szereguje w jednym workerze i wykonuje
  // wszystko.
  test.describe.configure({ mode: "default" });

  test.beforeEach(async ({ page }) => {
    // Authenticate client routes
    await mockFirebaseAuth(page);
    await mockGetMyProfile(page, {
      id: "user-uuid-1",
      email: "e2e@example.com",
      firstName: "Maciej",
      lastName: "Kolodziejczyk",
      phoneNumber: "+48 510417781",
      professionalTitle: "Psycholog",
      credentialsNumber: "LIC-1234",
      defaultModalityId: "dd8d84ff-16a5-470a-95cc-4b5a99e61f6b",
      organizationId: "org-uuid-1",
      role: "USER_ROLE_THERAPIST",
    });
    await mockGetMyOrganization(page);
    await mockGetSubscription(page);
    await mockListModalities(page);

    // Authenticate by submitting the login form
    const prefix = urlPrefix();
    await page.goto(`${prefix}/login`);
    await page.locator("input[type='email']").fill("e2e@example.com");
    await page.locator("input[type='password']").fill("Sup3rwizor!");
    
    // Select the form's submit button specifically (avoiding social sign-in buttons)
    await page.locator("form button[type='submit']").click();
    await expect(page).toHaveURL(new RegExp(`(${prefix}|/pl|/en)?/dashboard`));

    // Poczekaj, aż przekierowanie po logowaniu naprawdę się dokona.
    // Bez tego goto("/account") startowało w trakcie nawigacji na
    // /dashboard i Chromium przerywał je z net::ERR_ABORTED — objaw
    // niestabilny (2 padnięcia na 3 przebiegi), wyglądający na awarię
    // strony /account, choć była to kolizja dwóch nawigacji.
    await page.waitForLoadState("networkidle");
    await page.goto(`${prefix}/account`);
  });

  test("loads settings details and verifies biography field is absent", async ({ page }) => {
    // Verify headings are loaded
    const profileHeader = forLocale({
      pl: "TWOJE KONTO",
      en: "YOUR ACCOUNT",
    });
    await expect(page.getByRole("heading", { name: profileHeader })).toBeVisible();

    // Verify fields are loaded with mock data
    await expect(page.locator("input[value='Maciej']")).toBeVisible();
    await expect(page.locator("input[value='Kolodziejczyk']")).toBeVisible();

    // Biography field (textarea for biography / "O mnie") must be completely absent from form
    await expect(page.locator("textarea[name='biography']")).not.toBeVisible();
    const aboutMeLabel = forLocale({ pl: "O mnie", en: "About me" });
    await expect(page.getByText(aboutMeLabel)).not.toBeVisible();

    // Legal name placeholder must be visible
    const legalNamePlaceholder = forLocale({
      pl: "np. Gabinet Psychoterapii Jan Kowalski",
      en: "e.g. Jan Kowalski Psychotherapy",
    });
    await expect(page.locator(`input[placeholder='${legalNamePlaceholder}']`)).toBeVisible();

    // VAT UE placeholder must be visible
    const vatPlaceholder = forLocale({
      pl: "np. PL1234567890",
      en: "e.g. PL1234567890",
    });
    await expect(page.locator(`input[placeholder='${vatPlaceholder}']`)).toBeVisible();
  });

  // NIEROZWIĄZANE w chromium-en (2026-08-07): wersja polska przechodzi,
  // angielska nadal wysyła starą nazwę organizacji. Ustalone dotąd:
  //  • input jest kontrolowany przez Reacta (AccountSections.tsx:1109),
  //    więc selektor input[value='...'] nie działa,
  //  • .first() w formularzu łapał pole z sekcji profilu,
  //  • celowanie placeholderem naprawiło PL, ale nie EN.
  // Następny krok: pnpm test:e2e:ui i podejrzenie, w co trafia lokator
  // przy locale=en-GB.
  test("can update profile and organization successfully", async ({ page }) => {
    const { getCaptured: getProfileCap } = await mockUpdateProfile(page);
    const { getCaptured: getOrgCap } = await mockUpdateMyOrganization(page);

    // Modify profile fields and save
    await page.locator("input[value='Maciej']").fill("Maciej J");
    const saveProfileBtn = page.getByRole("button", {
      name: forLocale({ pl: "Zapisz zmiany", en: "Save changes" }),
    });
    await saveProfileBtn.click();

    // Verify update profile payload was captured
    await expect.poll(() => getProfileCap()).not.toBeNull();
    expect(getProfileCap()?.firstName).toBe("Maciej J");

    // Modify org fields and save
    // NIEROZWIĄZANE (2026-08-07): ten przypadek nadal pada — ładunek
    // UpdateMyOrganization niesie starą nazwę mimo wypełnienia pola.
    // Ustalone: input jest kontrolowany przez Reacta (AccountSections
    // .tsx:1109), a strona używa zwijanych sekcji (openSections.
    // organization), więc pierwotny selektor input[value='...'] był
    // kruchy. Zakotwiczenie w formularzu z przyciskiem zapisu jest
    // stabilniejsze, ale NIE naprawia przyczyny — wymaga debugowania
    // interaktywnego (pnpm test:e2e:ui).
    // Celujemy PLACEHOLDEREM, bo jest unikalny dla pola nazwy prawnej
    // w sekcji organizacji (account.legalNamePlaceholder). Wcześniejsze
    // podejścia trafiały gdzie indziej: selektor input[value='...'] nie
    // działa na polu kontrolowanym przez Reacta (atrybut nie nadąża za
    // stanem), a .first() w formularzu łapał pole z sekcji profilu —
    // formularz wysyłał wtedy niezmienioną nazwę i asercja padała na
    // starej wartości.
    await page
      .getByPlaceholder(
        forLocale({
          pl: "np. Gabinet Psychoterapii Jan Kowalski",
          en: "e.g. Jan Kowalski Psychotherapy",
        }),
      )
      .fill("New Legal Name Ltd");
    const saveOrgBtn = page.getByRole("button", {
      name: forLocale({ pl: "Zapisz organizację", en: "Save organisation" }),
    });
    await saveOrgBtn.click();

    // Verify update org payload was captured
    await expect.poll(() => getOrgCap()).not.toBeNull();
    expect(getOrgCap()?.legalName).toBe("New Legal Name Ltd");
  });

  test("runs the 3-step deletion flow successfully", async ({ page }) => {
    // Mock successful accounts:delete REST API call
    await page.route(/accounts:delete/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({}),
      });
    });

    const prefix = urlPrefix();

    // Step 1: Open deletion panel
    const deleteBtn = page.getByRole("button", {
      name: forLocale({ pl: "Usuń konto", en: "Delete account" }),
    });
    await deleteBtn.click();

    // Verify delete view loaded
    const deleteTitle = forLocale({
      pl: "Usuń konto",
      en: "Delete account",
    });
    await expect(page.getByRole("heading", { name: deleteTitle, level: 1 })).toBeVisible();

    // Toggle checkbox must be checked to enable delete button
    const deleteSubmitBtn = page.getByRole("button", {
      name: forLocale({ pl: "Usuń moje konto", en: "Delete my account" }),
    });
    await expect(deleteSubmitBtn).toBeDisabled();

    // Check toggle
    await page.locator("input[type='checkbox']").check();
    await expect(deleteSubmitBtn).toBeEnabled();

    // Step 2: Open confirmation modal
    await deleteSubmitBtn.click();

    // Verify modal elements are visible
    const modalTitle = forLocale({
      pl: "Ostatni krok.",
      en: "Final step.",
    });
    await expect(page.locator("div.fixed h3")).toContainText(modalTitle);

    const deleteModalSubmitBtn = page.getByRole("button", {
      name: forLocale({ pl: "USUWAM KONTO", en: "DELETE ACCOUNT" }),
    });
    await expect(deleteModalSubmitBtn).toBeDisabled();

    // Case-insensitivity check: typing "UsUwAm" or "DeLeTe" should enable the button
    const mixedCaseWord = forLocale({ pl: "UsUwAm", en: "DeLeTe" });
    const inputField = page.locator("input[type='text']");
    await inputField.fill("wrongword");
    await expect(deleteModalSubmitBtn).toBeDisabled();

    await inputField.fill(mixedCaseWord);
    await expect(deleteModalSubmitBtn).toBeEnabled();

    // Step 3: Trigger deletion
    await deleteModalSubmitBtn.click();

    // Successful delete redirects to login page
    await expect(page).toHaveURL(new RegExp(`(${prefix}|/pl)?/login\\/?$`));
  });

  test("requires re-authentication during deletion flow", async ({ page }) => {
    // Mock accounts:delete REST API call returning require recent login error
    await page.route(/accounts:delete/, async (route) => {
      await route.fulfill({
        status: 400,
        contentType: "application/json",
        body: JSON.stringify({
          error: {
            code: 400,
            message: "CREDENTIAL_TOO_OLD_LOGIN_AGAIN",
          },
        }),
      });
    });

    const prefix = urlPrefix();

    // Step 1: Open deletion panel
    const deleteBtn = page.getByRole("button", {
      name: forLocale({ pl: "Usuń konto", en: "Delete account" }),
    });
    await deleteBtn.click();

    // Check toggle and click delete
    await page.locator("input[type='checkbox']").check();
    await page.getByRole("button", {
      name: forLocale({ pl: "Usuń moje konto", en: "Delete my account" }),
    }).click();

    // Fill confirmation word
    const expectedConfirmWord = forLocale({ pl: "usuwam", en: "delete" });
    const inputField = page.locator("input[type='text']");
    await inputField.fill(expectedConfirmWord);

    const deleteModalSubmitBtn = page.getByRole("button", {
      name: forLocale({ pl: "USUWAM KONTO", en: "DELETE ACCOUNT" }),
    });
    await deleteModalSubmitBtn.click();

    await expect(page).toHaveURL(new RegExp(`(${prefix}|/pl)?/login\\/?\\?err=reauth$`));
  });
});
