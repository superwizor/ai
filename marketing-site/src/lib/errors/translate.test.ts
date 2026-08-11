// Mapowanie błędów backendu na komunikaty dla użytkownika.
//
// Ryzyko jest tu specyficzne: dopasowanie idzie po FRAGMENCIE tekstu
// (`contains`), a lista jest przeglądana po kolei. Dwie konsekwencje,
// które łatwo przeoczyć przy edycji i które testujemy wprost:
//
//   1. Wzorzec ogólniejszy postawiony wyżej przesłania szczegółowy —
//      użytkownik dostaje wtedy komunikat mniej trafny niż mógłby.
//   2. Zmiana komunikatu po stronie Go cicho zrywa dopasowanie i
//      zostaje sam komunikat zapasowy. Nic się nie wywala; jakość
//      podpowiedzi po prostu spada i nikt tego nie zauważa.

import { describe, expect, it } from "vitest";
import { Code, ConnectError } from "@connectrpc/connect";
import { translateError } from "./translate";

/** Zwraca sam KLUCZ tłumaczenia — sprawdzamy dopasowanie, nie treść. */
const t = (key: string) => key;

describe("translateError", () => {
  it("rozpoznaje brak miejsca w planie (seat_allocation_required)", () => {
    // Ten wzorzec dodaliśmy po realnym zgłoszeniu: panel pokazywał
    // "Nieprawidłowe dane formularza" zamiast powodu odmowy.
    expect(
      translateError(
        new Error("rpc error: code = FailedPrecondition desc = seat_allocation_required"),
        t,
      ),
    ).toBe("backend.seatAllocationRequired");
  });

  it("rozpoznaje wyczerpany limit sesji", () => {
    expect(translateError(new Error("quota exceeded for period"), t)).toBe(
      "backend.quotaExceeded",
    );
  });

  it("rozpoznaje zbyt krótkie uzasadnienie akcji admina", () => {
    expect(
      translateError(new Error("reason must be >= 10 characters"), t),
    ).toBe("backend.reasonTooShort");
  });

  it("odróżnia wygasłe zaproszenie od już przyjętego", () => {
    expect(translateError(new Error("invitation expired"), t)).toBe(
      "backend.invitationExpired",
    );
    expect(translateError(new Error("invitation already accepted"), t)).toBe(
      "backend.invitationAccepted",
    );
  });

  // Konflikt NIP-u jest szczegółowym przypadkiem "already exists".
  // Gdyby ogólny wzorzec trafił wyżej na liście, ten komunikat by zniknął.
  it("konflikt NIP-u nie jest przesłonięty przez ogólne 'already exists'", () => {
    expect(
      translateError(new Error("organization with this tax_id already exists"), t),
    ).toBe("backend.taxIdConflict");
  });

  it("nieznany błąd dostaje komunikat zapasowy, nie surową treść z serwera", () => {
    const out = translateError(
      new Error("pq: deadlock detected on relation usage_counters"),
      t,
    );
    expect(out).not.toContain("usage_counters");
    expect(out).not.toContain("pq:");
  });

  // Gałąź ConnectError była dotąd niepokryta w całości. ConnectError
  // dziedziczy po Error, więc odwrócenie kolejności sprawdzeń
  // `instanceof` wycięłoby całe mapowanie kodów — wszystko spadłoby na
  // komunikat zapasowy, a kod dalej by się kompilował.
  it("mapuje kod ConnectError, gdy treść nie pasuje do żadnego wzorca", () => {
    expect(translateError(new ConnectError("boom", Code.PermissionDenied), t)).toBe(
      "code.permissionDenied",
    );
    expect(translateError(new ConnectError("boom", Code.Unauthenticated), t)).toBe(
      "code.unauthenticated",
    );
  });

  it("treść pasująca do wzorca wygrywa z ogólnym kodem", () => {
    // Konkretna podpowiedź jest dla użytkownika użyteczniejsza niż
    // "przekroczono zasób".
    expect(
      translateError(new ConnectError("quota exceeded", Code.ResourceExhausted), t),
    ).toBe("backend.quotaExceeded");
  });

  // Regresja 2026-08-07: reset tokenów w panelu admina odrzucony przez
  // regułę planu pokazywał "Nieprawidłowe dane formularza. Sprawdź
  // wprowadzone wartości." Dane BYŁY poprawne (0 / 30 / powód 14
  // znaków) — blokował limit planu. Admin próbował cztery razy.
  //
  // Kod TOKENS_LIMIT_BELOW_PLAN pochodzi z billing-svc admin.go i jest
  // częścią kontraktu; po stronie Go pilnuje go
  // TestAdminResetTokens_RejectsLimitBelowPlan.
  it("rozpoznaje odrzucenie limitu poniżej planu zamiast ogólnego kodu", () => {
    const blad = new ConnectError(
      "TOKENS_LIMIT_BELOW_PLAN: tokens_limit 30 jest poniżej limitu planu PRO (1080) — " +
        "zmień plan albo alokację miejsc zamiast zaniżać licznik",
      Code.InvalidArgument,
    );

    expect(translateError(blad, t)).toBe("backend.tokensLimitBelowPlan");
    // Sedno: NIE ogólny komunikat o błędnym formularzu.
    expect(translateError(blad, t)).not.toBe("code.invalidArgument");
  });

  it("dopasowanie kodu planu nie zależy od wielkości liter", () => {
    expect(
      translateError(
        new ConnectError("tokens_limit_below_plan: cokolwiek", Code.InvalidArgument),
        t,
      ),
    ).toBe("backend.tokensLimitBelowPlan");
  });

  it("nie wywraca się na wartościach, które nie są instancją Error", () => {
    expect(() => translateError("zwykły łańcuch", t)).not.toThrow();
    expect(() => translateError(null, t)).not.toThrow();
    expect(() => translateError(undefined, t)).not.toThrow();
    expect(() => translateError({ nieoczekiwany: "kształt" }, t)).not.toThrow();
  });
});
