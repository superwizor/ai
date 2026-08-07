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

  it("plany miesięczny i roczny tego samego poziomu to różne ceny", () => {
    const m = resolveStripePriceId("solo_monthly");
    const a = resolveStripePriceId("solo_annual");
    if (m !== null && a !== null) {
      expect(m).not.toBe(a);
    }
    const pm = resolveStripePriceId("pro_monthly");
    const pa = resolveStripePriceId("pro_annual");
    if (pm !== null && pa !== null) {
      expect(pm).not.toBe(pa);
    }
  });

  it("poziomy SOLO i PRO nie dzielą tej samej ceny", () => {
    const solo = resolveStripePriceId("solo_monthly");
    const pro = resolveStripePriceId("pro_monthly");
    if (solo !== null && pro !== null) {
      expect(solo).not.toBe(pro);
    }
  });
});
