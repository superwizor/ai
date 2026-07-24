// StripeTestDashboard.tsx — Dev & Admin panel for testing Stripe Checkout flows.
//
// Features:
// 1. Live status of the current logged-in user's subscription (tier, period, status).
// 2. Full-price Checkout triggers for Równowaga (149 zł/mo, 1490 zł/yr) & Rozkwit (299 zł/mo, 2990 zł/yr).
// 3. Intro-price Checkout triggers (with ROWNOWAGA/ROZKWIT coupons).
// 4. Custom Promo Code tester (e.g. for testing 0 zł coupons or 1 zł coupons created in Stripe).
// 5. Direct instructions for Stripe Dashboard configuration.

"use client";

import { useState, useEffect, useCallback } from "react";
import { getAuth } from "firebase/auth";
import { getPlanCatalog, PlanRow } from "@/lib/billing/plans";
import { identityClient, billingClient } from "@/lib/connect/clients";
import { GetSubscriptionRequestSchema } from "@superwizor/proto-ts/billing/v1/billing_pb";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";

export function StripeTestDashboard() {
  const [catalog, setCatalog] = useState<ReadonlyArray<PlanRow>>([]);
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [orgId, setOrgId] = useState<string | null>(null);
  const [currentSub, setCurrentSub] = useState<any | null>(null);
  const [subLoading, setSubLoading] = useState(true);

  // Custom checkout form state
  const [customTier, setCustomTier] = useState<"SOLO" | "PRO">("SOLO");
  const [customCycle, setCustomCycle] = useState<"MONTHLY" | "ANNUAL">("MONTHLY");
  const [customPromo, setCustomPromo] = useState<string>("");
  const [noPromo, setNoPromo] = useState<boolean>(false);
  const [checkoutLoading, setCheckoutLoading] = useState<string | null>(null);
  const [checkoutError, setCheckoutError] = useState<string | null>(null);

  useEffect(() => {
    getPlanCatalog().then(setCatalog);
  }, []);

  const refreshSubState = useCallback(async () => {
    setSubLoading(true);
    try {
      const auth = getAuth();
      const user = auth.currentUser;
      if (!user) {
        setSubLoading(false);
        return;
      }
      setUserEmail(user.email);

      const token = await user.getIdToken();
      const ctx = await identityClient.validateToken({ firebaseIdToken: token });
      if (ctx.organizationId) {
        setOrgId(ctx.organizationId);
        const sub = await billingClient.getSubscription(
          create(GetSubscriptionRequestSchema, { organizationId: ctx.organizationId })
        );
        setCurrentSub(sub);
      }
    } catch (err) {
      console.warn("[StripeTestDashboard] Error fetching sub state:", err);
    } finally {
      setSubLoading(false);
    }
  }, []);

  useEffect(() => {
    refreshSubState();
  }, [refreshSubState]);

  const triggerCheckout = async (
    stripePriceId: string,
    promoCodeToUse?: string,
    buttonId: string = "action"
  ) => {
    setCheckoutError(null);
    setCheckoutLoading(buttonId);

    try {
      const auth = getAuth();
      const user = auth.currentUser;
      if (!user) throw new Error("Musisz być zalogowany, aby rozpocząć płatność.");

      const token = await user.getIdToken();
      const ctx = await identityClient.validateToken({ firebaseIdToken: token });
      const organizationId = ctx.organizationId;
      if (!organizationId) throw new Error("Brak przypisanej organizacji do użytkownika.");

      let phoneNumber: string | undefined;
      let name: string | undefined;
      try {
        const profile = await identityClient.getMyProfile(create(EmptySchema, {}));
        if (profile) {
          phoneNumber = profile.phoneNumber || undefined;
          name = `${profile.firstName || ""} ${profile.lastName || ""}`.trim() || undefined;
        }
      } catch (e) {
        console.warn("Could not prefill profile details", e);
      }

      let address: any = undefined;
      let taxId: string | undefined;
      let vatIdEu: string | undefined;
      try {
        const org = await identityClient.getMyOrganization(create(EmptySchema, {}));
        if (org) {
          if (org.legalName) name = org.legalName;
          taxId = org.taxId || undefined;
          vatIdEu = org.vatIdEu || undefined;
          if (org.headquartersAddress) {
            const street = org.headquartersAddress.streetLine || "";
            const bldg = org.headquartersAddress.buildingNumber || "";
            const unit = org.headquartersAddress.unitNumber || "";
            let line1 = `${street} ${bldg}`.trim();
            if (unit) line1 = `${line1}/${unit}`;

            address = {
              line1: line1 || undefined,
              line2: org.headquartersAddress.directions || undefined,
              city: org.headquartersAddress.city || undefined,
              postal_code: org.headquartersAddress.postalCode || undefined,
              state: org.headquartersAddress.region || undefined,
              country: org.headquartersAddress.countryCode || undefined,
            };
          }
        }
      } catch (e) {
        console.warn("Could not prefill org details", e);
      }

      const returnUrl = "/admin/stripe-test";

      const resp = await fetch("/api/checkout", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          priceId: stripePriceId,
          organizationId,
          email: user.email ?? undefined,
          phoneNumber,
          name,
          taxId,
          vatIdEu,
          address,
          promoCode: promoCodeToUse ? promoCodeToUse.trim() : undefined,
          returnUrl,
        }),
      });

      if (!resp.ok) {
        const body = await resp.json().catch(() => ({}));
        throw new Error(body.error || `Checkout HTTP error (${resp.status})`);
      }

      const { url } = await resp.json();
      if (url) {
        window.location.href = url;
      } else {
        throw new Error("Stripe API nie zwróciło URL przekierowania.");
      }
    } catch (err: any) {
      console.error("[StripeTest] Checkout error:", err);
      setCheckoutError(err.message || "Wystąpił błąd podczas inicjacji płatności Stripe.");
    } finally {
      setCheckoutLoading(null);
    }
  };

  const selectedPlanRow = catalog.find(
    (p) => p.tier === customTier && p.cycle === customCycle
  );

  return (
    <div className="space-y-8 p-6 max-w-6xl mx-auto">
      {/* Header */}
      <div className="border-b border-white/10 pb-6 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#004D54]/20 border border-[#004D54]/40 text-[#4ADE80] text-xs font-mono mb-2">
            <span>🧪 DEVELOPS / TEST PANEL</span>
          </div>
          <h1 className="text-2xl font-bold text-white tracking-tight">
            Stripe Checkout & Subscription Tester
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Przetestuj pełne płatności, kody promocyjne (0 zł, 1 zł) oraz działanie webhooków Stripe na żywej bazodanowej subskrypcji.
          </p>
        </div>

        <button
          onClick={refreshSubState}
          disabled={subLoading}
          className="px-4 py-2 text-xs font-medium rounded-lg bg-white/5 hover:bg-white/10 text-white border border-white/10 transition-colors flex items-center gap-2"
        >
          <svg
            className={`w-3.5 h-3.5 ${subLoading ? "animate-spin text-teal-400" : "text-slate-400"}`}
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
            />
          </svg>
          Odśwież stan subskrypcji
        </button>
      </div>

      {/* Sub Status Inspector */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-slate-900/80 border border-slate-800 rounded-xl p-4">
          <div className="text-xs font-mono text-slate-500 uppercase tracking-wider">Zalogowany Użytkownik</div>
          <div className="text-sm font-semibold text-white mt-1 truncate">
            {userEmail || "Brak (zaloguj się)"}
          </div>
          <div className="text-xs text-slate-400 mt-0.5 truncate">Org ID: {orgId || "—"}</div>
        </div>

        <div className="bg-slate-900/80 border border-slate-800 rounded-xl p-4">
          <div className="text-xs font-mono text-slate-500 uppercase tracking-wider">Aktywny Tier w DB</div>
          <div className="text-lg font-bold text-teal-400 mt-1">
            {currentSub?.planTier ? currentSub.planTier.toUpperCase() : "TRIAL / NIEZNANY"}
          </div>
          <div className="text-xs text-slate-400 mt-0.5">
            Status: <span className="font-semibold text-slate-200">{currentSub?.status || "BRAK"}</span>
          </div>
        </div>

        <div className="bg-slate-900/80 border border-slate-800 rounded-xl p-4">
          <div className="text-xs font-mono text-slate-500 uppercase tracking-wider">Sesje / Okres</div>
          <div className="text-sm font-semibold text-white mt-1">
            Limit: {currentSub?.tokensPerPeriod ?? "—"} sesji
          </div>
          <div className="text-xs text-slate-400 mt-0.5">
            Koniec okresu: {currentSub?.currentPeriodEnd ? new Date(Number(currentSub.currentPeriodEnd) * 1000).toLocaleDateString("pl-PL") : "—"}
          </div>
        </div>
      </div>

      {checkoutError && (
        <div className="p-4 rounded-xl bg-red-950/50 border border-red-800 text-red-300 text-sm flex items-start gap-3">
          <span className="text-red-400 font-bold text-base">⚠️</span>
          <div className="flex-1">
            <div className="font-semibold">Błąd podczas tworzenia sesji Checkout:</div>
            <div className="mt-0.5 font-mono text-xs">{checkoutError}</div>
          </div>
        </div>
      )}

      {/* Grid of Tests */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        
        {/* Box 1: Quick Full Price Checkout Buttons */}
        <div className="bg-slate-900/60 border border-slate-800 rounded-2xl p-6 flex flex-col justify-between">
          <div>
            <div className="flex items-center gap-2 mb-2">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-500"></span>
              <h2 className="text-lg font-bold text-white">1. Szybki Checkout w Pełnych Cenach</h2>
            </div>
            <p className="text-xs text-slate-400 mb-6">
              Inicjuje Stripe Checkout z bazową cenie bez automatycznego nakładania domyślnego kuponu rabatowego. Możesz wpisać dowolny promo kod ręcznie w Stripe.
            </p>

            <div className="space-y-3">
              {/* Równowaga Monthly (149 zł) */}
              <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex items-center justify-between">
                <div>
                  <div className="text-sm font-semibold text-white">🌿 Równowaga Miesięcznie</div>
                  <div className="text-xs text-slate-400">149 zł brutto / mies. · Price: <code className="text-[#4ADE80]">price_1TsUvXEA7Lw46kANXxzZZwTs</code></div>
                </div>
                <button
                  onClick={() => triggerCheckout("price_1TsUvXEA7Lw46kANXxzZZwTs", undefined, "rownowaga_full_m")}
                  disabled={checkoutLoading === "rownowaga_full_m"}
                  className="px-4 py-2 text-xs font-semibold rounded-lg bg-teal-600 hover:bg-teal-500 text-white transition-colors disabled:opacity-50"
                >
                  {checkoutLoading === "rownowaga_full_m" ? "Ładowanie..." : "Kup (149 zł)"}
                </button>
              </div>

              {/* Równowaga Annual (1490 zł) */}
              <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex items-center justify-between">
                <div>
                  <div className="text-sm font-semibold text-white">🌿 Równowaga Rocznie</div>
                  <div className="text-xs text-slate-400">1 490 zł brutto / rok · Price: <code className="text-[#4ADE80]">price_1TsUvlEA7Lw46kANGuLjnoeD</code></div>
                </div>
                <button
                  onClick={() => triggerCheckout("price_1TsUvlEA7Lw46kANGuLjnoeD", undefined, "rownowaga_full_a")}
                  disabled={checkoutLoading === "rownowaga_full_a"}
                  className="px-4 py-2 text-xs font-semibold rounded-lg bg-teal-600 hover:bg-teal-500 text-white transition-colors disabled:opacity-50"
                >
                  {checkoutLoading === "rownowaga_full_a" ? "Ładowanie..." : "Kup (1490 zł)"}
                </button>
              </div>

              {/* Rozkwit Monthly (299 zł) */}
              <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex items-center justify-between">
                <div>
                  <div className="text-sm font-semibold text-white">🌸 Rozkwit Miesięcznie</div>
                  <div className="text-xs text-slate-400">299 zł brutto / mies. · Price: <code className="text-[#4ADE80]">price_1TsUwUEA7Lw46kANHgjOrNRy</code></div>
                </div>
                <button
                  onClick={() => triggerCheckout("price_1TsUwUEA7Lw46kANHgjOrNRy", undefined, "rozkwit_full_m")}
                  disabled={checkoutLoading === "rozkwit_full_m"}
                  className="px-4 py-2 text-xs font-semibold rounded-lg bg-[#004D54] hover:bg-[#006068] text-white transition-colors disabled:opacity-50"
                >
                  {checkoutLoading === "rozkwit_full_m" ? "Ładowanie..." : "Kup (299 zł)"}
                </button>
              </div>

              {/* Rozkwit Annual (2990 zł) */}
              <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 flex items-center justify-between">
                <div>
                  <div className="text-sm font-semibold text-white">🌸 Rozkwit Rocznie</div>
                  <div className="text-xs text-slate-400">2 990 zł brutto / rok · Price: <code className="text-[#4ADE80]">price_1TsUwkEA7Lw46kAN76gYZGIQ</code></div>
                </div>
                <button
                  onClick={() => triggerCheckout("price_1TsUwkEA7Lw46kAN76gYZGIQ", undefined, "rozkwit_full_a")}
                  disabled={checkoutLoading === "rozkwit_full_a"}
                  className="px-4 py-2 text-xs font-semibold rounded-lg bg-[#004D54] hover:bg-[#006068] text-white transition-colors disabled:opacity-50"
                >
                  {checkoutLoading === "rozkwit_full_a" ? "Ładowanie..." : "Kup (2990 zł)"}
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Box 2: Custom Promo Code & Test Generator (0 zł / 1 zł / Custom) */}
        <div className="bg-slate-900/60 border border-slate-800 rounded-2xl p-6 flex flex-col justify-between">
          <div>
            <div className="flex items-center gap-2 mb-2">
              <span className="w-2.5 h-2.5 rounded-full bg-amber-500"></span>
              <h2 className="text-lg font-bold text-white">2. Test z Własnym Kodem (np. 0 zł / 1 zł)</h2>
            </div>
            <p className="text-xs text-slate-400 mb-6">
              Skonfiguruj dowolną kombinację planu i wpisz własny kod rabatowy utworzony w panelu Stripe (np. <code className="text-amber-300">TEST0</code> dla 0 zł lub <code className="text-amber-300">TEST1</code> dla 1 zł).
            </p>

            <div className="space-y-4">
              {/* Select Tier */}
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">Wybierz Plan</label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setCustomTier("SOLO")}
                    className={`py-2 px-3 rounded-lg text-xs font-semibold border transition-all ${
                      customTier === "SOLO"
                        ? "bg-teal-950/80 border-teal-500 text-teal-300"
                        : "bg-slate-950 border-slate-800 text-slate-400 hover:border-slate-700"
                    }`}
                  >
                    🌿 Równowaga
                  </button>
                  <button
                    type="button"
                    onClick={() => setCustomTier("PRO")}
                    className={`py-2 px-3 rounded-lg text-xs font-semibold border transition-all ${
                      customTier === "PRO"
                        ? "bg-teal-950/80 border-teal-500 text-teal-300"
                        : "bg-slate-950 border-slate-800 text-slate-400 hover:border-slate-700"
                    }`}
                  >
                    🌸 Rozkwit
                  </button>
                </div>
              </div>

              {/* Select Cycle */}
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">Okres Rozliczeniowy</label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setCustomCycle("MONTHLY")}
                    className={`py-2 px-3 rounded-lg text-xs font-semibold border transition-all ${
                      customCycle === "MONTHLY"
                        ? "bg-indigo-950/80 border-indigo-500 text-indigo-300"
                        : "bg-slate-950 border-slate-800 text-slate-400 hover:border-slate-700"
                    }`}
                  >
                    Miesięcznie
                  </button>
                  <button
                    type="button"
                    onClick={() => setCustomCycle("ANNUAL")}
                    className={`py-2 px-3 rounded-lg text-xs font-semibold border transition-all ${
                      customCycle === "ANNUAL"
                        ? "bg-indigo-950/80 border-indigo-500 text-indigo-300"
                        : "bg-slate-950 border-slate-800 text-slate-400 hover:border-slate-700"
                    }`}
                  >
                    Rocznie
                  </button>
                </div>
              </div>

              {/* Custom Promo Code Input */}
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Kod promocyjny / kupon (opcjonalny)
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    placeholder="np. TEST0, TEST1, ROWNOWAGA"
                    value={customPromo}
                    onChange={(e) => setCustomPromo(e.target.value.toUpperCase())}
                    className="flex-1 bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-xs font-mono text-white placeholder-slate-600 focus:outline-none focus:border-teal-500"
                  />
                  {customPromo && (
                    <button
                      type="button"
                      onClick={() => setCustomPromo("")}
                      className="px-2 py-2 text-xs text-slate-400 hover:text-white"
                    >
                      Wyczyść
                    </button>
                  )}
                </div>
                <div className="mt-1 flex gap-2">
                  <button
                    type="button"
                    onClick={() => setCustomPromo("TEST0")}
                    className="text-[10px] font-mono text-amber-400 hover:underline"
                  >
                    + Użyj TEST0 (0 zł)
                  </button>
                  <button
                    type="button"
                    onClick={() => setCustomPromo("TEST1")}
                    className="text-[10px] font-mono text-amber-400 hover:underline"
                  >
                    + Użyj TEST1 (1 zł)
                  </button>
                  <button
                    type="button"
                    onClick={() => setCustomPromo("ROWNOWAGA")}
                    className="text-[10px] font-mono text-teal-400 hover:underline"
                  >
                    + ROWNOWAGA (99 zł)
                  </button>
                </div>
              </div>

              {/* Selected Price Info */}
              <div className="p-3 rounded-lg bg-slate-950/80 border border-slate-800 text-xs text-slate-300">
                Wybrany Price ID: <code className="text-[#4ADE80] font-mono">{selectedPlanRow?.stripePriceId || "Brak"}</code>
                <br />
                Cena bazowa: <span className="font-semibold text-white">{selectedPlanRow?.priceGross} zł brutto</span>
              </div>
            </div>
          </div>

          <button
            onClick={() => {
              if (selectedPlanRow?.stripePriceId) {
                triggerCheckout(selectedPlanRow.stripePriceId, customPromo || undefined, "custom_action");
              }
            }}
            disabled={!selectedPlanRow?.stripePriceId || checkoutLoading === "custom_action"}
            className="w-full mt-6 py-3 px-4 rounded-xl bg-amber-600 hover:bg-amber-500 text-white font-semibold text-sm transition-colors flex items-center justify-center gap-2 disabled:opacity-50"
          >
            {checkoutLoading === "custom_action" ? (
              "Inicjowanie Stripe Checkout..."
            ) : (
              <>
                <span>Przejdź do Płatności Stripe</span>
                <span className="text-xs opacity-80">({customPromo ? `Kod: ${customPromo}` : "Bez kodu"})</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* Instructions for Stripe Dashboard setup */}
      <div className="bg-slate-900/40 border border-slate-800 rounded-2xl p-6 space-y-4">
        <h3 className="text-base font-bold text-white flex items-center gap-2">
          <span>🛠️ Instrukcja Wyklikania Kuponów 0 zł i 1 zł w Panelu Stripe</span>
        </h3>
        
        <div className="text-xs text-slate-300 space-y-3 leading-relaxed">
          <p>
            Stripe umożliwia bezproblemowe dodawanie kuponów rabatowych bez konieczności jakichkolwiek zmian w kodzie aplikacji.
          </p>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2">
            <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 space-y-2">
              <div className="font-bold text-teal-300 text-sm">Jak utworzyć kupon na 0 zł (100% zniżki):</div>
              <ol className="list-decimal list-inside space-y-1 text-slate-400">
                <li>Wejdź na dashboard.stripe.com → <strong>Katalog produktów</strong> (Product Catalog) → <strong>Kupony</strong> (Coupons).</li>
                <li>Kliknij <strong>+ Utwórz kupon</strong> (+ Add Coupon).</li>
                <li><strong>Nazwa:</strong> np. <code className="text-white">Test 0 PLN</code>.</li>
                <li><strong>Typ rabatu:</strong> Procentowy → <code className="text-white">100%</code>.</li>
                <li><strong>Czas trwania:</strong> Jednorazowo (Once) lub Na zawsze (Forever).</li>
                <li>Zaznacz opcję <strong>Włącz kod promocyjny widoczny dla klienta</strong> (Allow customer promo codes).</li>
                <li>Wpisz kod: np. <code className="text-amber-400 font-bold">TEST0</code>. Zapisz.</li>
              </ol>
            </div>

            <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 space-y-2">
              <div className="font-bold text-[#4ADE80] text-sm">Jak utworzyć kupon na 1 zł:</div>
              <ol className="list-decimal list-inside space-y-1 text-slate-400">
                <li>Wejdź na dashboard.stripe.com → <strong>Coupons</strong> → <strong>+ Add Coupon</strong>.</li>
                <li><strong>Nazwa:</strong> np. <code className="text-white">Test 1 PLN</code>.</li>
                <li><strong>Typ rabatu:</strong> Kwotowy (Fixed amount) → <code className="text-white">148.00 PLN</code> dla Równowagi (149-148 = 1 zł) lub <code className="text-white">298.00 PLN</code> dla Rozkwitu.</li>
                <li>Zaznacz opcję <strong>Włącz kod promocyjny widoczny dla klienta</strong>.</li>
                <li>Wpisz kod: np. <code className="text-amber-400 font-bold">TEST1</code>. Zapisz.</li>
              </ol>
            </div>
          </div>

          <div className="p-3 rounded-lg bg-teal-950/40 border border-teal-800/60 text-teal-200 text-xs">
            💡 <strong>Jak testować:</strong> Kliknij przycisk płatności wyżej, a na oficjalnej stronie Stripe Checkout kliknij <strong>"Dodaj kod promocyjny"</strong> i wpisz utworzony kod (<code className="text-amber-300">TEST0</code> lub <code className="text-amber-300">TEST1</code>). Stripe przeliczy kwotę i pozwoli zakończyć transakcję. Po powrocie na tę stronę odśwież stan subskrypcji powyżej, aby sprawdzić czy webhook poprawnie odnotował upgrade!
          </div>
        </div>
      </div>
    </div>
  );
}
