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

  it("nie wywraca się na wartościach, które nie są instancją Error", () => {
    expect(() => translateError("zwykły łańcuch", t)).not.toThrow();
    expect(() => translateError(null, t)).not.toThrow();
    expect(() => translateError(undefined, t)).not.toThrow();
    expect(() => translateError({ nieoczekiwany: "kształt" }, t)).not.toThrow();
  });
});
