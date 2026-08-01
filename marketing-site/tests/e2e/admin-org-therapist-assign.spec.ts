// Panel admina — przypisanie i odpięcie terapeuty w karcie organizacji.
//
// Sedno tego, co tu sprawdzamy, to DWUSTOPNIOWE potwierdzenie
// przeniesienia. Gdy terapeuta należy już do innej organizacji, backend
// NIC nie zapisuje i zwraca TRANSFER_CONFIRMATION_REQUIRED razem
// z liczbą sesji, które przenosiny zabiorą. Admin musi to zobaczyć,
// zanim potwierdzi po raz drugi — inaczej „dodanie po mailu" po cichu
// odbiera sesje innej organizacji.

import { test, expect, type Page } from "@playwright/test";

import { mockFirebaseAuth, ADMIN_USER } from "./fixtures/auth";
import { mockGetMyProfile } from "./fixtures/connect-rpc";
import { urlPrefix } from "./_locales";
import { AdminLoginPage } from "./pages/admin-login.page";

const ORG_ID = "fdb7f889-5f31-44a0-a804-6575c8649068";

/** Organizacja z jednym terapeutą i jednym managerem. */
async function mockOrgDetails(page: Page) {
  await page.route(
    /identity\.v1\.IdentityService\/AdminGetOrganization/,
    async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          organization: {
            id: ORG_ID,
            legalName: "FENIKS Pilotaz",
            type: "ORGANIZATION_TYPE_CLINIC",
            status: "ORGANIZATION_STATUS_ACTIVE",
            taxId: "648-254-46-11",
            vatIdEu: "PL6482544611",
            createdAt: "2026-07-28T10:40:00Z",
          },
          managers: [
            {
              id: "mgr-1",
              firstName: "Marek",
              lastName: "Zarzadca",
              email: "feniks@example.com",
            },
          ],
          therapists: [
            {
              id: "th-1",
              firstName: "Anna",
              lastName: "Kowalska",
              email: "anna@example.com",
            },
          ],
          recentAudit: [],
        }),
      });
    },
  );
}

/**
 * Rachunek miejsc. Domyślnie pusty; przy `many` zwraca DWA przydziały,
 * bo dopiero wtedy backend odmawia zgadywania (resolveSeatAllocation
 * w identity-svc: 0 → brak seatu, 1 → bierze automatycznie,
 * >1 → INVALID_ARGUMENT "SEAT_ALLOCATION_REQUIRED").
 */
async function mockSeatUsage(page: Page, many = false) {
  const allocations = many
    ? [
        {
          allocationId: "alloc-1",
          planTier: "PRO",
          planCycle: "MONTHLY",
          seats: 6,
          seatsAssigned: 2,
          seatsPending: 0,
        },
        {
          allocationId: "alloc-2",
          planTier: "CLINIC",
          planCycle: "ANNUAL",
          seats: 10,
          seatsAssigned: 1,
          seatsPending: 1,
        },
      ]
    : [];
  await page.route(/billing\.v1\.BillingService\/AdminGetOrgSeatUsage/, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ allocations }),
    });
  });
}

async function gotoOrgDetail(page: Page, manySeats = false) {
  await mockFirebaseAuth(page, ADMIN_USER);
  await mockGetMyProfile(page);
  await mockOrgDetails(page);
  await mockSeatUsage(page, manySeats);
  // Static-export: literalny segment [id] JEST strona; Firebase Hosting
  // przepisuje na nia prawdziwe identyfikatory, a OrgDetailClient czyta
  // useParams() w przegladarce. dynamicParams=false, wiec sciezka
  // z prawdziwym UUID daje 404 w dev — wchodzimy na zaslepke.
  await page.goto(`${urlPrefix()}/admin/orgs/%5Bid%5D/`);
  // AdminGuard nie ufa samemu mockowi — trzeba przejsc przez formularz,
  // ktory mock Firebase przechwytuje (tak samo robi admin-analytics).
  await new AdminLoginPage(page).signIn(
    "admin@superwizor.ai",
    "AdminPassword123!",
  );
  await expect(
    page.getByRole("heading", { name: "FENIKS Pilotaz" }),
  ).toBeVisible();
}

test.describe("admin — przypisanie terapeuty", () => {
  test("karta pokazuje przycisk przypisania i odpięcie przy terapeucie", async ({
    page,
  }) => {
    await gotoOrgDetail(page);

    await expect(
      page.getByRole("button", { name: "Przypisz terapeutę" }),
    ).toBeVisible();
    // Odpięcie wisi przy konkretnym terapeucie, nie w wierszu akcji —
    // żeby nie dało się odpiąć „kogoś" bez wskazania kogo.
    await expect(page.getByRole("button", { name: "Odepnij" })).toBeVisible();
  });

  test("terapeuta z innej organizacji wymaga potwierdzenia i pokazuje bilans sesji", async ({
    page,
  }) => {
    await gotoOrgDetail(page);

    // Backend odmawia i zwraca ostrzeżenie zamiast zapisywać.
    let seenConfirmTransfer: boolean | undefined;
    await page.route(
      /identity\.v1\.IdentityService\/AdminAssignTherapistToOrg/,
      async (route) => {
        const body = JSON.parse(route.request().postData() ?? "{}");
        seenConfirmTransfer = body.confirmTransfer;
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({
            status:
              "ADMIN_ASSIGN_THERAPIST_STATUS_TRANSFER_CONFIRMATION_REQUIRED",
            transferWarning: {
              currentOrganizationId: "other-org",
              currentOrganizationName: "Gabinet Poprzedni",
              totalSessions: 42,
              billableSessions: 37,
              tokensConsumed: 128400,
              holdsActiveSeat: true,
            },
          }),
        });
      },
    );

    await page.getByRole("button", { name: "Przypisz terapeutę" }).click();
    await page
      .getByLabel("E-mail terapeuty")
      .fill("przenoszony@example.com");
    await page
      .getByRole("textbox", { name: /powód|reason/i })
      .fill("Przeniesienie na wniosek organizacji");
    await page.getByRole("button", { name: /potwierdź|confirm/i }).click();

    // Pierwsze wywołanie NIE może nieść zgody na przeniesienie.
    expect(seenConfirmTransfer).toBeFalsy();

    // Ostrzeżenie musi pokazać, co przenosiny zabiorą.
    await expect(page.getByText("Gabinet Poprzedni")).toBeVisible();
    await expect(page.getByText(/42/)).toBeVisible();
    await expect(page.getByText(/37/)).toBeVisible();

    await page.screenshot({
      path: "test-results/admin-org-therapist-transfer-warning.png",
      fullPage: true,
    });
  });

  // Regresja z produkcji (2026-08-01): przypisanie do organizacji
  // z DWOMA przydzialami miejsc konczylo sie generycznym
  // "Nieprawidlowe dane formularza". Backend odmawial zgadywania
  // (SEAT_ALLOCATION_REQUIRED), a formularz nie mial czego poprawic —
  // pola wyboru po prostu nie bylo.
  test("przy wielu przydzialach miejsc admin musi wybrac plan", async ({
    page,
  }) => {
    await gotoOrgDetail(page, true);

    await page.getByRole("button", { name: "Przypisz terapeutę" }).click();
    const seat = page.getByLabel("Przydział miejsc");
    await expect(seat).toBeVisible();
    // Oba przydzialy z wykorzystaniem miejsc, zeby admin wiedzial,
    // ktory ma jeszcze wolne.
    await expect(seat).toContainText("2/6");
    await expect(seat).toContainText("2/10");

    await page.screenshot({
      path: "test-results/admin-org-therapist-seat-choice.png",
      fullPage: true,
    });
  });

  test("pojedynczy przydzial nie pyta o wybor", async ({ page }) => {
    await gotoOrgDetail(page);
    await page.getByRole("button", { name: "Przypisz terapeutę" }).click();
    await expect(page.getByLabel("Przydział miejsc")).toHaveCount(0);
  });
});
