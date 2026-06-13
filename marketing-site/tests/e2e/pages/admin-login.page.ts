// Page Object for the admin sign-in form that guards /admin/* routes.
//
// Encapsulates selectors and actions so spec files read like plain
// English: `await adminLogin.signIn("admin@superwizor.ai", "pass")`.
// If a selector changes in the component, fix it here once.

import { expect, type Locator, type Page } from "@playwright/test";
import { forLocale } from "../_locales";

export class AdminLoginPage {
  readonly page: Page;

  // Locators derived from the actual AdminGuard.tsx DOM.
  // AdminSignInForm uses <label> wrappers with translated <span> text.
  readonly heading: Locator;
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorAlert: Locator;

  constructor(page: Page) {
    this.page = page;

    this.heading = page.locator("h1");

    // AdminGuard uses <label><span>{t("signinEmailLabel")}</span><input>
    // so getByLabel matches the label text.
    const emailLabel = forLocale({ pl: "Email", en: "Email" });
    const passwordLabel = forLocale({ pl: "Hasło", en: "Password" });
    this.emailInput = page.getByLabel(emailLabel);
    this.passwordInput = page.getByLabel(passwordLabel);

    const submitName = forLocale({
      pl: /Zaloguj się/i,
      en: /Sign in/i,
    });
    this.submitButton = page.getByRole("button", { name: submitName });
    this.errorAlert = page.locator("[role='alert']");
  }

  /** Assert the sign-in gate is shown. */
  async expectSignInRequired() {
    const title = forLocale({
      pl: "Musisz się zalogować, aby uzyskać dostęp do panelu administracyjnego.",
      en: "You need to sign in to access the admin console.",
    });
    await expect(this.heading).toContainText(title, { timeout: 10_000 });
  }

  /** Fill credentials and submit the admin sign-in form. */
  async signIn(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }
}
