// resolveStripePriceId decyduje, którą ścieżką pójdzie użytkownik zaraz
// po założeniu konta: brak ceny (null) prowadzi na weryfikację e-maila,
// cena — na płatność w Stripe.
//
// Pomyłka tutaj nie wywala się głośno. Objawia się tym, że ktoś, kto
// wybrał plan płatny, trafia na ekran weryfikacji i nigdy nie płaci —
// albo odwrotnie, użytkownik triala ląduje w kasie. To także jedno z
// wywołań w bloku, który po incydencie z 2026-08-05 wydzieliliśmy z
// obsługi błędów rejestracji.

import { describe, expect, it } from "vitest";
import { resolveStripePriceId } from "./post-registration";

describe("resolveStripePriceId", () => {
  it("plany darmowe nie mają ceny — użytkownik idzie na weryfikację e-maila", () => {
    expect(resolveStripePriceId("trial")).toBeNull();
    expect(resolveStripePriceId("beta")).toBeNull();
  });

  it("brak wybranego planu też oznacza ścieżkę bez płatności", () => {
    expect(resolveStripePriceId(null)).toBeNull();
    expect(resolveStripePriceId("")).toBeNull();
  });

  it("wielkość liter w slugu nie zmienia wyniku", () => {
    // Slug bywa przekazywany w URL-u, gdzie regularnie trafia się
    // wersja z wielkich liter.
    expect(resolveStripePriceId("TRIAL")).toBeNull();
    expect(resolveStripePriceId("Trial")).toBeNull();
    expect(resolveStripePriceId("SOLO_MONTHLY")).toBe(
      resolveStripePriceId("solo_monthly"),
    );
  });

  it("nieznany slug nie udaje planu płatnego", () => {
    // Zwrócenie przypadkowej ceny dla literówki w linku obciążyłoby
    // klienta za coś, czego nie wybrał.
    expect(resolveStripePriceId("nie_istnieje")).toBeNull();
    expect(resolveStripePriceId("solo")).toBeNull();
    expect(resolveStripePriceId("pro_quarterly")).toBeNull();
  });

  // Asercje BEZWARUNKOWE i to jest tu cała rzecz. Pierwsza wersja tego
  // pliku miała je opakowane w `if (x !== null && y !== null)`, przez co
  // przechodziły trywialnie, gdyby wszystkie ceny były null — czyli
  // dokładnie w awarii, przed którą mają bronić. Strażnik zamieniał test
  // w atrapę.
  const PLATNE = ["solo_monthly", "solo_annual", "pro_monthly", "pro_annual"];

  it("każdy płatny plan MA identyfikator ceny Stripe", () => {
    for (const slug of PLATNE) {
      const id = resolveStripePriceId(slug);
      expect(id, `brak ceny dla ${slug} — płacący trafi na weryfikację e-maila zamiast do kasy`)
        .toMatch(/^price_/);
    }
  });

  it("cztery płatne plany mają cztery RÓŻNE ceny", () => {
    // Wspólny identyfikator znaczy, że ktoś zapłaci za inny plan, niż
    // wybrał — a nic w interfejsie tego nie pokaże.
    const ids = PLATNE.map((s) => resolveStripePriceId(s));
    expect(new Set(ids).size).toBe(PLATNE.length);
  });
});
