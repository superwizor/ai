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
import { resolvePromoCode, resolveStripePriceId } from "./post-registration";

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

// resolvePromoCode decyduje, JAKI rabat trafi do sesji Stripe Checkout.
// Pomyłka tutaj też jest cicha: użytkownik po prostu płaci więcej (kod
// przepadł) albo mniej (kupon planu nadpisał świadomy wybór "bez
// promocji"). Kolejność pierwszeństwa jest tu całą regułą, więc każdy
// z trzech poziomów ma własny test.
describe("resolvePromoCode", () => {
  it("bez kodu w URL-u zostaje kupon planu — zachowanie sprzed docs/70", () => {
    expect(resolvePromoCode("solo_monthly", "?plan=solo_monthly")).toBe(
      "ROWNOWAGA",
    );
    expect(resolvePromoCode("pro_annual", "")).toBe("ROZKWIT_ROK");
  });

  it("kod z ?code= wygrywa z automatycznym kuponem planu", () => {
    // Wpisany ręcznie i zwalidowany na /pricing — świadomy wybór bije
    // domyślny kupon, inaczej kampania rabatowa nigdy by nie zadziałała.
    expect(resolvePromoCode("solo_monthly", "?plan=solo_monthly&code=WIOSNA25")).toBe(
      "WIOSNA25",
    );
  });

  it("normalizuje kod do wielkich liter, jak backend", () => {
    expect(resolvePromoCode("solo_monthly", "?code=wiosna25")).toBe("WIOSNA25");
  });

  it("kod o złym kształcie jest ignorowany, a nie przekazywany dalej", () => {
    // Backend i tak by go odrzucił; lokalna kontrola zostawia
    // użytkownikowi kupon planu zamiast checkoutu bez żadnej zniżki.
    expect(resolvePromoCode("solo_monthly", "?code=za")).toBe("ROWNOWAGA");
    expect(resolvePromoCode("solo_monthly", "?code=ma%20spacje")).toBe(
      "ROWNOWAGA",
    );
    expect(resolvePromoCode("solo_monthly", "?code=zły-znak")).toBe(
      "ROWNOWAGA",
    );
  });

  it("?nopromo=1 i ?clean=1 wyłączają WSZYSTKO, także kod z URL-a", () => {
    // Furtka do testów czystego checkoutu. Gdyby ?code= ją omijał,
    // przestałaby służyć do czegokolwiek.
    expect(resolvePromoCode("solo_monthly", "?nopromo=1&code=WIOSNA25")).toBeUndefined();
    expect(resolvePromoCode("solo_monthly", "?clean=1")).toBeUndefined();
  });

  it("nieznany plan bez kodu nie wymyśla kuponu", () => {
    expect(resolvePromoCode("nie_istnieje", "")).toBeUndefined();
    expect(resolvePromoCode(null, "")).toBeUndefined();
  });

  it("sam kod wystarczy — nawet gdy planu nie znamy", () => {
    expect(resolvePromoCode(null, "?code=PIONIER33")).toBe("PIONIER33");
  });
});
