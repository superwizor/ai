// StripeTestDashboard.tsx — Dev & Admin panel for testing Stripe Checkout flows.
//
// Features:
// 1. Live status of the current logged-in user's subscription (tier, period, status).
// 2. Custom Email override (so tests don't have to be performed on Darek's admin email).
// 3. Full-price Checkout triggers for Równowaga & Rozkwit.
// 4. Custom Promo Code tester pre-filled with Darek's exact test coupons.
// 5. Direct links for testing full new user signup from scratch (with clean promo code field).

"use client";

import { useState, useEffect, useCallback } from "react";
import { getAuth } from "firebase/auth";
import { getPlanCatalog, PlanRow } from "@/lib/billing/plans";
import { identityClient, billingClient } from "@/lib/connect/clients";
import { GetSubscriptionRequestSchema } from "@superwizor/proto-ts/billing/v1/billing_pb";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";

const CODE_ZERO = "TEST0BlueBallshejohejo1920";
const CODE_99 = "TEST0Blue99Ballshejohejo99";

export function StripeTestDashboard() {
  const [catalog, setCatalog] = useState<ReadonlyArray<PlanRow>>([]);
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [orgId, setOrgId] = useState<string | null>(null);
  const [currentSub, setCurrentSub] = useState<any | null>(null);
  const [subLoading, setSubLoading] = useState(true);

  // Custom checkout form state
  const [customEmail, setCustomEmail] = useState<string>("");
  const [customTier, setCustomTier] = useState<"SOLO" | "PRO">("SOLO");
  const [customCycle, setCustomCycle] = useState<"MONTHLY" | "ANNUAL">("MONTHLY");
  const [customPromo, setCustomPromo] = useState<string>("");
  const [checkoutLoading, setCheckoutLoading] = useState<string | null>(null);
  const [checkoutError, setCheckoutError] = useState<string | null>(null);
  const [copiedCode, setCopiedCode] = useState<string | null>(null);

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

  const copyToClipboard = (code: string) => {
    navigator.clipboard.writeText(code);
    setCopiedCode(code);
    setTimeout(() => setCopiedCode(null), 2000);
  };

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
      const targetEmail = customEmail.trim() || user.email || undefined;

      const resp = await fetch("/api/checkout", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          priceId: stripePriceId,
          organizationId,
          email: targetEmail,
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
            <span>🧪 STRIPE TEST PANEL</span>
          </div>
          <h1 className="text-2xl font-bold text-white tracking-tight">
            Stripe Checkout & Subscription Tester
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Testuj płatności dla dowolnego e-maila testowego, wyzwalaj czysty checkout bez narzuconych kodów oraz testuj pełną rejestrację od A do Z.
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

      {/* Sub Status Inspector & Email Override */}
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

      {/* Custom Email Input Bar */}
      <div className="p-4 rounded-xl bg-indigo-950/40 border border-indigo-800/60 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div>
          <label className="block text-xs font-bold uppercase font-mono text-indigo-300 tracking-wider">
            📧 Własny Testowy E-mail Płatności (Opcjonalnie)
          </label>
          <p className="text-xs text-slate-400 mt-0.5">
            Wpisz tutaj dowolny testowy e-mail (np. <code className="text-indigo-200">testowy.klient@gmail.com</code>), aby na stronie Stripe Checkout NIE pojawiał się e-mail Darka.
          </p>
        </div>
        <div className="w-full md:w-80 flex items-center gap-2">
          <input
            type="email"
            placeholder={userEmail ? `Domyślnie: ${userEmail}` : "np. jan.kowalski@gmail.com"}
            value={customEmail}
            onChange={(e) => setCustomEmail(e.target.value)}
            className="w-full bg-slate-950 border border-indigo-700/60 rounded-lg px-3 py-2 text-xs font-mono text-white placeholder-slate-500 focus:outline-none focus:border-indigo-400"
          />
          {customEmail && (
            <button
              onClick={() => setCustomEmail("")}
              className="text-xs text-slate-400 hover:text-white px-2 py-1"
            >
              Wyczyść
            </button>
          )}
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
              <h2 className="text-lg font-bold text-white">1. Czysty Checkout w Pełnych Cenach</h2>
            </div>
            <p className="text-xs text-slate-400 mb-6">
              Otwiera bezpośredni Stripe Checkout z bazową ceną (bez automatycznie narzuconego kuponu). Pozwala na wpisanie dowolnego własnego promo kodu na ekranie Stripe.
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

        {/* Box 2: Custom Promo Code & Test Generator */}
        <div className="bg-slate-900/60 border border-slate-800 rounded-2xl p-6 flex flex-col justify-between">
          <div>
            <div className="flex items-center gap-2 mb-2">
              <span className="w-2.5 h-2.5 rounded-full bg-amber-500"></span>
              <h2 className="text-lg font-bold text-white">2. Test z Domyślnie Wstrzykniętym Kodem</h2>
            </div>
            <p className="text-xs text-slate-400 mb-6">
              Wybierz plan oraz kliknij w jeden z poniższych gotowych kodów rabatowych, aby wstępnie zaaplikować go przy starcie płatności.
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

              {/* Custom Promo Code Input & Quick Select */}
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Kod promocyjny / kupon (wpisz lub wybierz z listy)
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    placeholder="Wpisz kod..."
                    value={customPromo}
                    onChange={(e) => setCustomPromo(e.target.value)}
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

                {/* Quick Fill Buttons */}
                <div className="mt-2 flex flex-col gap-1.5">
                  <button
                    type="button"
                    onClick={() => setCustomPromo(CODE_ZERO)}
                    className="text-left text-[11px] font-mono px-2.5 py-1.5 rounded-lg bg-emerald-950/60 border border-emerald-800/60 text-emerald-300 hover:bg-emerald-900/60 transition-colors flex items-center justify-between"
                  >
                    <span>🎁 Użyj: <strong>{CODE_ZERO}</strong> (0 zł)</span>
                    <span className="text-[10px] uppercase font-bold text-emerald-400">0 PLN</span>
                  </button>
                  
                  <button
                    type="button"
                    onClick={() => setCustomPromo(CODE_99)}
                    className="text-left text-[11px] font-mono px-2.5 py-1.5 rounded-lg bg-indigo-950/60 border border-indigo-800/60 text-indigo-300 hover:bg-indigo-900/60 transition-colors flex items-center justify-between"
                  >
                    <span>🔥 Użyj: <strong>{CODE_99}</strong> (-99%)</span>
                    <span className="text-[10px] uppercase font-bold text-indigo-400">-99%</span>
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

      {/* Section 3: Full Signup Test from Scratch */}
      <div className="bg-slate-900/60 border border-[#004D54]/50 rounded-2xl p-6 space-y-4">
        <div className="flex items-center gap-2">
          <span className="w-2.5 h-2.5 rounded-full bg-teal-400"></span>
          <h3 className="text-lg font-bold text-white">
            3. Testuj Pełną Ścieżkę Rejestracji Nowego Konta (Od A do Z)
          </h3>
        </div>
        <p className="text-xs text-slate-300 leading-relaxed">
          Poniższe linki kierują do formularza rejestracji nowego terapeuty <strong>z aktywnym polem wpisywania własnego kodu promocyjnego</strong> (domyślny kod rabatowy <code>ROWNOWAGA</code> został odpięty w tym trybie, aby Stripe Checkout nie blikował pola wpisywania kodu).
        </p>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2">
          <a
            href="/pl/register/therapist?plan=solo_monthly&nopromo=1"
            target="_blank"
            rel="noopener noreferrer"
            className="p-4 rounded-xl bg-slate-950 border border-teal-800/80 hover:border-teal-400 transition-all flex flex-col justify-between group"
          >
            <div>
              <div className="text-sm font-bold text-teal-300 flex items-center justify-between">
                <span>🌿 Nowe Konto — Plan Równowaga</span>
                <span className="text-xs text-slate-400 group-hover:text-white">Otwórz ↗</span>
              </div>
              <p className="text-xs text-slate-400 mt-1">
                Rejestracja od zera dla nowego e-maila + przejście do Stripe Checkout z otwartym wpisywaniem kodu <code>TEST0...</code>.
              </p>
            </div>
          </a>

          <a
            href="/pl/register/therapist?plan=pro_monthly&nopromo=1"
            target="_blank"
            rel="noopener noreferrer"
            className="p-4 rounded-xl bg-slate-950 border border-teal-800/80 hover:border-teal-400 transition-all flex flex-col justify-between group"
          >
            <div>
              <div className="text-sm font-bold text-teal-300 flex items-center justify-between">
                <span>🌸 Nowe Konto — Plan Rozkwit</span>
                <span className="text-xs text-slate-400 group-hover:text-white">Otwórz ↗</span>
              </div>
              <p className="text-xs text-slate-400 mt-1">
                Rejestracja nowego terapeuty dla planu Rozkwit (299 zł) z możliwością podania własnego kuponu w Stripe.
              </p>
            </div>
          </a>
        </div>
      </div>

      {/* Copyable Test Codes Cards */}
      <div className="bg-slate-900/40 border border-slate-800 rounded-2xl p-6 space-y-4">
        <h3 className="text-base font-bold text-white flex items-center gap-2">
          <span>📋 Gotowe Kody Testowe Stripe (Kliknij, aby skopiować)</span>
        </h3>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-1">
          {/* Card 1: 0 zł */}
          <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 flex flex-col justify-between space-y-3">
            <div>
              <div className="flex items-center justify-between mb-1">
                <span className="font-bold text-emerald-400 text-sm">Kupon na 0 zł (100% zniżki)</span>
                <span className="px-2 py-0.5 rounded bg-emerald-950 text-emerald-300 text-[10px] font-mono font-bold">0 PLN</span>
              </div>
              <p className="text-xs text-slate-400">
                Po wpisaniu w Stripe Checkout kwota zamienia się w 0,00 zł. Idealny do szybkiego testowania bez użycia karty.
              </p>
            </div>

            <div className="flex items-center gap-2 pt-1">
              <code className="flex-1 bg-slate-900 border border-slate-800 px-3 py-2 rounded-lg text-xs font-mono text-white truncate">
                {CODE_ZERO}
              </code>
              <button
                type="button"
                onClick={() => copyToClipboard(CODE_ZERO)}
                className="px-3 py-2 text-xs font-semibold rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white transition-colors flex-shrink-0"
              >
                {copiedCode === CODE_ZERO ? "Skopiowano! ✓" : "Kopiuj"}
              </button>
            </div>
          </div>

          {/* Card 2: -99% */}
          <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 flex flex-col justify-between space-y-3">
            <div>
              <div className="flex items-center justify-between mb-1">
                <span className="font-bold text-indigo-400 text-sm">Kupon na -99% zniżki</span>
                <span className="px-2 py-0.5 rounded bg-indigo-950 text-indigo-300 text-[10px] font-mono font-bold">-99%</span>
              </div>
              <p className="text-xs text-slate-400">
                Obniża kwotę o 99%. Pozwala przetestować prawdziwą transakcję za grosze (np. 1,49 zł za Równowagę).
              </p>
            </div>

            <div className="flex items-center gap-2 pt-1">
              <code className="flex-1 bg-slate-900 border border-slate-800 px-3 py-2 rounded-lg text-xs font-mono text-white truncate">
                {CODE_99}
              </code>
              <button
                type="button"
                onClick={() => copyToClipboard(CODE_99)}
                className="px-3 py-2 text-xs font-semibold rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white transition-colors flex-shrink-0"
              >
                {copiedCode === CODE_99 ? "Skopiowano! ✓" : "Kopiuj"}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
