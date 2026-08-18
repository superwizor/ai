// Playwright E2E: ekran po potwierdzeniu adresu e-mail.
//
// Ta karta bywa otwarta w innym oknie niż to, w którym trwa rejestracja
// — a wtedy nie ma w niej sesji Firebase. Przycisk prowadzący do
// kreatora wysyłał więc użytkownika prosto na przekierowanie do
// logowania (patrz onboarding-auth-guard.spec.ts). Właściwe miejsce to
// karta pierwotna, która sama wykrywa potwierdzenie, dlatego ekran ma
// wyłącznie informować i nie proponować przejścia dalej.
//
// applyActionCode() uderza do identitytoolkit; podstawiamy odpowiedź,
// żeby dojść do stanu "success" bez prawdziwego kodu z maila.

import { test, expect } from "@playwright/test";
import { forLocale, urlPrefix } from "./_locales";

async function udajPotwierdzenie(page: import("@playwright/test").Page) {
  await page.route(/identitytoolkit\.googleapis\.com\/v1\/accounts:update/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        kind: "identitytoolkit#SetAccountInfoResponse",
        email: "e2e@example.com",
        emailVerified: true,
      }),
    });
  });
}

test.describe("Potwierdzenie e-maila — ekran sukcesu", () => {
  test("pokazuje potwierdzenie i prosi o powrót do poprzedniej karty", async ({
    page,
  }, testInfo) => {
    const prefix = urlPrefix();
    await udajPotwierdzenie(page);

    await page.goto(`${prefix}/auth/action?mode=verifyEmail&oobCode=testowy-kod`);

    const tytul = forLocale({ pl: /E-mail zweryfikowany!/i, en: /Email Verified!/i });
    await expect(page.getByText(tytul)).toBeVisible();

    const powrot = forLocale({
      pl: /zamknąć tę kartę i wrócić do poprzedniej strony/i,
      en: /close this tab and return to the previous page/i,
    });
    await expect(page.getByText(powrot)).toBeVisible();

    await page.screenshot({
      path: `../evidence/auth-action/${testInfo.project.name}-verify-success.png`,
      fullPage: true,
    });
  });

  test("nie proponuje przejścia dalej", async ({ page }) => {
    const prefix = urlPrefix();
    await udajPotwierdzenie(page);

    await page.goto(`${prefix}/auth/action?mode=verifyEmail&oobCode=testowy-kod`);

    const tytul = forLocale({ pl: /E-mail zweryfikowany!/i, en: /Email Verified!/i });
    await expect(page.getByText(tytul)).toBeVisible();

    // Sedno zmiany: żadnego odnośnika do kreatora ani zachęty do klikania.
    await expect(page.locator('a[href*="/onboarding"]')).toHaveCount(0);

    const zachetaDoKlikania = forLocale({
      pl: /kliknąć przycisk poniżej/i,
      en: /click below to continue/i,
    });
    await expect(page.getByText(zachetaDoKlikania)).toHaveCount(0);
  });

  test("nie przenosi użytkownika nigdzie po chwili", async ({ page }) => {
    const prefix = urlPrefix();
    await udajPotwierdzenie(page);

    const adres = `${prefix}/auth/action?mode=verifyEmail&oobCode=testowy-kod`;
    await page.goto(adres);

    const tytul = forLocale({ pl: /E-mail zweryfikowany!/i, en: /Email Verified!/i });
    await expect(page.getByText(tytul)).toBeVisible();

    // Gałąź dla zużytego kodu przerzucała kiedyś na /onboarding/ po 1,5 s.
    await page.waitForTimeout(2500);
    await expect(page).toHaveURL(new RegExp("/auth/action"));
  });
});
