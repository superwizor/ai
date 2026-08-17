// Page Object for /register/therapist email form.
//
// Maps every form field to a Playwright locator derived from the real
// DOM (FieldShell renders <label htmlFor={id}> + <input id={id}>).
// Playwright's getByLabel matches the `htmlFor`-linked label text.

import { expect, type Locator, type Page } from "@playwright/test";
import { forLocale } from "../_locales";

export class RegisterTherapistPage {
  readonly page: Page;
  readonly heading: Locator;

  // Form fields — locators built from translated label text.
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly firstNameInput: Locator;
  readonly lastNameInput: Locator;
  /** Krok 5 to dziś wybór języka interfejsu — pole `professionalTitle`
   *  zostało usunięte z formularza rejestracji (żyje już tylko w panelu
   *  admina).
   *
   *  Lokator celuje w ETYKIETĘ, nie w pole: FieldShell przekazuje `id`
   *  wyłącznie do htmlFor na <label>, więc element o id="uiLanguage"
   *  nie istnieje w DOM. */
  readonly uiLanguageField: Locator;
  readonly tosCheckbox: Locator;
  readonly submitButton: Locator;
  readonly validationErrors: Locator;
  readonly nextStepButton: Locator;
  readonly phoneNumberInput: Locator;

  constructor(page: Page) {
    this.page = page;
    this.heading = page.locator("h1");

    // FieldShell renders <label htmlFor="email">Adres e-mail *</label>
    // getByLabel matches the visible label text (excluding the * span
    // which has aria-hidden). Using the field label id as fallback
    // because getByLabel may be unreliable with uppercase monospaced
    // labels — FieldShell uses htmlFor, so #id selectors are stable.
    this.emailInput = page.locator("#email");
    this.passwordInput = page.locator("#password");
    this.firstNameInput = page.locator("#firstName");
    this.lastNameInput = page.locator("#lastName");
    this.uiLanguageField = page.locator('label[for="uiLanguage"]');
    this.tosCheckbox = page.locator("#tos");
    this.nextStepButton = page.locator("#next-step-btn");
    this.phoneNumberInput = page.locator("#phoneNumber");

    const submitName = forLocale({
      pl: /Załóż konto/i,
      en: /Create account/i,
    });
    this.submitButton = page.getByRole("button", { name: submitName });
    this.validationErrors = page.locator("[role='alert']");
  }

  /** Navigate to the register therapist page. */
  async goto(prefix: string) {
    await this.page.goto(`${prefix}/register/therapist`);
  }

  /** Assert the page heading matches the locale. */
  async expectHeading() {
    const heading = forLocale({
      pl: "Zarejestruj się jako terapeuta",
      en: "Sign up as a therapist",
    });
    await expect(this.heading).toContainText(heading);
  }

  /** Fill the minimum required fields for a valid submission. */
  async fillRequiredFields(overrides: Partial<{
    email: string;
    password: string;
    firstName: string;
    lastName: string;
    phoneNumber: string;
  }> = {}) {
    const defaults = {
      email: "e2e@example.com",
      password: "Sup3rwizor!",
      firstName: "Anna",
      lastName: "Kowalska",
      phoneNumber: "+48500100200",
    };
    const data = { ...defaults, ...overrides };

    // Navigate Wizard Steps 1 & 2
    await this.page.locator("#start-trial-btn").click();
    await this.page.locator("#signup-email-btn").click();

    // Step 3 (Credentials)
    await this.emailInput.fill(data.email);
    await this.passwordInput.fill(data.password);
    await this.tosCheckbox.check();
    await this.nextStepButton.click();

    // Step 4 (Personal Details)
    await this.firstNameInput.fill(data.firstName);
    await this.lastNameInput.fill(data.lastName);
    await this.phoneNumberInput.fill(data.phoneNumber);
    await this.nextStepButton.click();

    // Krok 5 (język interfejsu) to RadioGroup z domyślnie zaznaczonym
    // językiem strony — nie wymaga interakcji. Czekamy na PRZYCISK
    // WYSYŁKI, bo to jest właściwy kontrakt tej metody: zostawić
    // formularz gotowy do submit(). Wcześniejsza wersja czekała na samo
    // pole języka i wywracała test "identity-svc unreachable", który
    // przez ten krok nie przechodzi.
    await this.submitButton.waitFor({ state: "visible" });
  }

  /** Submit the form. */
  async submit() {
    await this.submitButton.click();
  }

  /** Assert still on the registration page (no redirect happened). */
  async expectStillOnRegisterPage(prefix: string) {
    await expect(this.page).toHaveURL(
      new RegExp(`${prefix}/register/therapist\\/?$`),
    );
  }

  /** Assert redirected to verify-email page. */
  async expectRedirectToVerifyEmail(prefix: string, email: string) {
    await this.page.waitForURL(
      new RegExp(`${prefix}/register/therapist/verify-email`),
      { timeout: 10_000 },
    );
    expect(this.page.url()).toContain(
      `email=${encodeURIComponent(email)}`,
    );
  }

  /** Assert validation errors are shown. */
  async expectValidationErrors() {
    await expect(this.validationErrors.first()).toBeVisible();
  }
}
