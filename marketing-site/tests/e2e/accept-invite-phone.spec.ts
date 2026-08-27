// Playwright E2E: akceptacja zaproszenia zbiera numer telefonu.
//
// Skąd to się wzięło: ścieżka samodzielnej rejestracji terapeuty wymaga
// numeru i opisuje go jako „potrzebny ze względów bezpieczeństwa", a
// akceptacja zaproszenia nie pytała o niego wcale — mimo że ten sam ekran
// pozwala założyć konto przez Google/Apple. Terapeuta wchodzący z
// zaproszenia zakładał więc konto personelu bez numeru.
//
// ZAKRES: ten spec jeździ po ścieżce e-mailowej formularza. Popupu Google
// (`signInWithPopup`) Playwright nie przejedzie — okno idzie na
// accounts.google.com, którego nie da się przechwycić routingiem. Po
// zalogowaniu społecznościowym formularz jest jednak DOKŁADNIE TEN SAM
// (ustawia się tylko `socialUid`, znikają pola hasła), więc kontrakt
// telefonu weryfikujemy tu, a obecność wejścia społecznościowego —
// osobną asercją na przycisk.
//
// Pełne pokrycie popupu wymaga emulatora Firebase Auth: aplikacja już go
// wspiera przez NEXT_PUBLIC_FIREBASE_USE_EMULATOR=1
// (src/lib/firebase/init.ts), brakuje tylko wpięcia emulatora w
// `webServer` w playwright.config.ts.

import { test, expect } from "@playwright/test";
import { urlPrefix } from "./_locales";
import { mockFirebaseAuth } from "./fixtures/auth";
import {
  mockGetInvitationPreview,
  mockAcceptInvitation,
  mockListModalities,
} from "./fixtures/connect-rpc";

const TOKEN = "test-invite-token";

/** Wypełnia wszystko poza telefonem — ten dokłada dopiero test. */
async function fillStaffInvite(page: import("@playwright/test").Page) {
  await page.locator("#email").fill("zaproszony@example.com");
  await page.locator("#password").fill("Sup3rwizor!x");
  await page.locator("#firstName").fill("Jan");
  await page.locator("#lastName").fill("Zaproszony");
  await page.locator("#modality").selectOption({ index: 1 });
  await page.locator("#tos").check();
}

test.describe("Akceptacja zaproszenia — numer telefonu", () => {
  test.beforeEach(async ({ page }) => {
    await mockFirebaseAuth(page);
    await mockListModalities(page);
  });

  test("zaproszenie terapeuty: telefon jest wymagany i trafia do AcceptInvitation", async ({
    page,
  }) => {
    await mockGetInvitationPreview(page);
    const { getCaptured } = await mockAcceptInvitation(page);

    await page.goto(`${urlPrefix()}/accept-invite?token=${TOKEN}`);

    const phone = page.locator("#phoneNumber");
    await expect(phone).toBeVisible();

    await fillStaffInvite(page);

    // 1. Bez numeru nie wolno wyjść z formularza.
    await page.locator("form button[type='submit']").click();
    expect(getCaptured()).toBeNull();

    // 2. Z numerem — payload musi go nieść. Numer celowo nie jest
    //    sekwencyjny: walidator odrzuca ciągi w rodzaju 123456789 jako
    //    oczywiste fałszywki.
    await phone.fill("512837461");
    await page.locator("form button[type='submit']").click();

    // Dłuższy poll niż domyślny: przy --workers=2 (tak jeździ test:e2e)
    // pierwsze wejście na trasę bywa kompilowane przez dev server i
    // 5 s potrafi nie wystarczyć — jeden taki flak już tu wystąpił.
    await expect.poll(() => getCaptured(), { timeout: 15_000 }).not.toBeNull();
    const sent = getCaptured() as Record<string, unknown>;
    // PhoneInput wysyła numer sformatowany razem z kierunkowym
    // („+48 512-837-461"), więc porównujemy same cyfry — inaczej test
    // pilnowałby formatowania zamiast tego, czy numer w ogóle dociera.
    expect(String(sent.phoneNumber ?? "").replace(/\D/g, "")).toContain(
      "512837461",
    );
  });

  test("zaproszenie klienta: telefonu nie ma — konto jest pseudonimowe", async ({
    page,
  }) => {
    // docs/43 §4: e-mail jest jedynym identyfikatorem klienta, więc
    // numeru nie zbieramy i nie wolno go wymagać. Zaproszenie PATIENT
    // przekierowuje z /accept-invite na dedykowany onboarding klienta —
    // to też jest część kontraktu, więc sprawdzamy oba fakty.
    await mockGetInvitationPreview(page, { invitedRole: "USER_ROLE_PATIENT" });
    await page.goto(`${urlPrefix()}/accept-invite?token=${TOKEN}`);

    await expect(page).toHaveURL(/\/register\/client\//);
    await expect(page.locator("#phoneNumber")).toHaveCount(0);
  });

  test("zaproszenie terapeuty wystawia wejście przez Google", async ({ page }) => {
    // To jest wejście, które czyniło brak telefonu osiągalnym: konto
    // personelu dało się założyć bez wpisania czegokolwiek poza tym, co
    // przyszło od dostawcy tożsamości.
    await mockGetInvitationPreview(page);
    await page.goto(`${urlPrefix()}/accept-invite?token=${TOKEN}`);

    await expect(
      page.getByRole("button", { name: /Google/i }),
    ).toBeVisible();
  });
});
