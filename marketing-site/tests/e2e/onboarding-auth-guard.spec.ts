// Playwright E2E: strażnik sesji na /onboarding.
//
// Regresja z 2026-08-11. Kreator onboardingu nie sprawdzał, czy ktoś
// jest zalogowany — czytał `useAuth()` wyłącznie po to, by zbudować
// klucz localStorage. Niezalogowany użytkownik dostawał pełny kreator,
// przechodził go do końca i dopiero zapis wracał z 401
// ("no authorization header": interceptor w src/lib/connect/transport.ts
// pomija nagłówek, gdy nie ma tokenu, i wysyła żądanie mimo to).
// Na ekranie wyglądało to jak awaria zapisu preferencji.
//
// Realny scenariusz: rejestracja zaczęta w jednym oknie, dokończona w
// oknie otwartym z linku potwierdzającego e-mail, które nie dzieliło
// sesji z pierwszym.
//
// Te testy działają BEZ logowania — stan niezalogowany jest domyślny
// dla świeżego kontekstu przeglądarki, więc dokładnie odtwarzają awarię.

import { test, expect } from "@playwright/test";
import { forLocale, urlPrefix } from "./_locales";

test.describe("Onboarding — strażnik sesji", () => {
  test("niezalogowany użytkownik jest przekierowany na logowanie", async ({
    page,
  }) => {
    const prefix = urlPrefix();

    await page.goto(`${prefix}/onboarding/`);

    // Cel: /login z powodem "session". Regex, bo Next dokłada / na końcu.
    await expect(page).toHaveURL(/\/login\/?\?err=session/);
  });

  test("logowanie tłumaczy, dlaczego użytkownik tam trafił", async ({
    page,
  }) => {
    const prefix = urlPrefix();

    await page.goto(`${prefix}/onboarding/`);
    await expect(page).toHaveURL(/\/login\/?\?err=session/);

    const komunikat = forLocale({
      pl: /zaloguj się w tym oknie przeglądarki/i,
      en: /sign in from this browser window/i,
    });
    await expect(page.getByText(komunikat)).toBeVisible();
  });

  test("kreator nie pokazuje ani jednego kroku bez sesji", async ({ page }) => {
    const prefix = urlPrefix();

    await page.goto(`${prefix}/onboarding/`);
    await expect(page).toHaveURL(/\/login\/?\?err=session/);

    // Sedno regresji: pytania kreatora nie mogą się pojawić, bo każda
    // odpowiedź i tak skończyłaby się 401 przy zapisie.
    const pytanie = forLocale({
      pl: /Jak pracujesz\?/i,
      en: /How do you work\?/i,
    });
    await expect(page.getByText(pytanie)).toHaveCount(0);

    const pomin = forLocale({ pl: /^Pomiń$/i, en: /^Skip$/i });
    await expect(page.getByRole("button", { name: pomin })).toHaveCount(0);
  });

  test("żadne wywołanie RPC nie wychodzi bez nagłówka Authorization", async ({
    page,
  }) => {
    const prefix = urlPrefix();

    // Wywołania anonimowe są dozwolone przez backend (ListModalities,
    // CheckEmailExists), więc pilnujemy wyłącznie tych, które wymagają
    // tożsamości — to one wracały z 401 i psuły onboarding.
    const wymagajaceTokenu = ["UpdateProfile", "GetMyProfile"];
    const bezTokenu: string[] = [];

    page.on("request", (req) => {
      const url = req.url();
      if (!wymagajaceTokenu.some((m) => url.includes(m))) return;
      const naglowki = req.headers();
      if (!naglowki["authorization"]) bezTokenu.push(url);
    });

    await page.goto(`${prefix}/onboarding/`);
    await expect(page).toHaveURL(/\/login\/?\?err=session/);
    await page.waitForTimeout(1000);

    expect(bezTokenu).toEqual([]);
  });
});
