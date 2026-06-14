// UpgradeSection — the core UI for /upgrade.
//
// Plan: "bez opcji free, krótki pitch + 2 plany (Równowaga + Rozkwit)"
// Design: short motivational pitch + two large cards + promo codes.
// No trial card — they already had their trial.
//
// Auth-aware: if user is logged in, CTA calls /api/checkout directly
// with their organizationId. If not logged in, falls back to registration.

"use client";

import { useState, useCallback } from "react";
import { getAuth } from "firebase/auth";
import type { BillingCycle, PlanRow } from "@/lib/billing/plans";
import { findPlan, formatPrice } from "@/lib/billing/plans";
import { identityClient } from "@/lib/connect/clients";

export function UpgradeSection({
  catalog,
  locale,
}: {
  catalog: ReadonlyArray<PlanRow>;
  locale: string;
}) {
  const [cycle, setCycle] = useState<BillingCycle>("MONTHLY");
  const prefix = locale === "en" ? "/en" : "";
  const isAnnual = cycle === "ANNUAL";

  const solo = findPlan(catalog, "SOLO", cycle);
  const pro = findPlan(catalog, "PRO", cycle);

  return (
    <section className="relative overflow-hidden bg-gradient-to-b from-[#F8F6F1] to-[#ECE8DF] pt-28 pb-20 sm:pt-36 sm:pb-28">
      {/* Decorative background elements */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[900px] h-[900px] bg-[radial-gradient(ellipse_at_center,_rgba(0,77,84,0.04)_0%,_transparent_70%)] pointer-events-none" />

      <div className="relative mx-auto max-w-3xl px-5">
        {/* --- Pitch --- */}
        <div className="text-center mb-14">
          <span className="inline-flex items-center gap-2 px-3.5 py-1.5 mb-5 rounded-full bg-[#004D54]/10 text-[#004D54] text-[11px] font-mono uppercase tracking-wider font-bold">
            <span className="w-1.5 h-1.5 rounded-full bg-[#004D54] animate-pulse" />
            {locale === "en"
              ? "Continue your practice"
              : "Kontynuuj swoją praktykę"}
          </span>

          <h1 className="font-serif text-3xl sm:text-4xl font-bold text-[#1B2522] leading-tight mb-4">
            {locale === "en"
              ? "Your trial has ended.\nYour insights don't have to."
              : "Twój okres próbny się skończył.\nTwoje wnioski nie muszą."}
          </h1>

          <p className="font-sans text-base sm:text-lg text-[#4E5A55] leading-relaxed max-w-xl mx-auto">
            {locale === "en"
              ? "Choose the plan that fits your practice. All your sessions, reports, and client files stay exactly where you left them."
              : "Wybierz plan dopasowany do Twojej praktyki. Wszystkie Twoje sesje, raporty i kartoteki czekają na Ciebie dokładnie tam, gdzie je zostawiłeś."}
          </p>
        </div>

        {/* --- Cycle Toggle --- */}
        <div className="flex flex-col items-center mb-10">
          <div
            role="tablist"
            aria-label="billing cycle"
            className="relative inline-flex items-center rounded-full bg-[#F2F0EA] border border-[#E2DED5] p-1"
          >
            <div
              className={`absolute top-1 bottom-1 w-[calc(50%-4px)] rounded-full bg-[#004D54] shadow-lg transition-all duration-300 ease-out ${
                isAnnual ? "left-[calc(50%+2px)]" : "left-1"
              }`}
            />
            <button
              role="tab"
              aria-selected={!isAnnual}
              onClick={() => setCycle("MONTHLY")}
              className={`relative z-10 w-[130px] sm:w-[150px] py-2.5 rounded-full font-sans font-bold text-xs sm:text-sm uppercase tracking-wider transition-colors duration-300 cursor-pointer text-center ${
                !isAnnual
                  ? "text-white"
                  : "text-[#4E5A55] hover:text-[#1B2522]"
              }`}
            >
              {locale === "en" ? "Monthly" : "Miesięcznie"}
            </button>
            <button
              role="tab"
              aria-selected={isAnnual}
              onClick={() => setCycle("ANNUAL")}
              className={`relative z-10 w-[130px] sm:w-[150px] py-2.5 rounded-full font-sans font-bold text-xs sm:text-sm uppercase tracking-wider transition-colors duration-300 cursor-pointer text-center ${
                isAnnual
                  ? "text-white"
                  : "text-[#4E5A55] hover:text-[#1B2522]"
              }`}
            >
              {locale === "en" ? "Annually" : "Rocznie"}
            </button>
          </div>
          {isAnnual && (
            <span className="mt-2 inline-flex items-center gap-1.5 text-[#004D54] font-sans text-[11px] uppercase tracking-wider font-bold">
              <span className="w-1.5 h-1.5 rounded-full bg-[#004D54] animate-pulse" />
              {locale === "en"
                ? "Annual billing — 17% off"
                : "Rozliczenie roczne — 17% taniej"}
            </span>
          )}
        </div>

        {/* --- Two Plan Cards --- */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
          {solo && (
            <UpgradeCard
              tier="solo"
              tierName={locale === "en" ? "Balance" : "Równowaga"}
              row={solo}
              cycle={cycle}
              locale={locale}
              prefix={prefix}
              isHero={false}
            />
          )}
          {pro && (
            <UpgradeCard
              tier="pro"
              tierName={locale === "en" ? "Growth" : "Rozkwit"}
              row={pro}
              cycle={cycle}
              locale={locale}
              prefix={prefix}
              isHero={true}
            />
          )}
        </div>

        {/* --- Footnote --- */}
        <div className="mt-8 text-center">
          <p className="font-mono text-[10px] uppercase tracking-wider text-[#4E5A55]">
            {locale === "en"
              ? "Prices incl. 23% VAT · Secure payment via Stripe · Cancel anytime"
              : "Ceny zawierają VAT · Bezpieczna płatność przez Stripe · Anuluj w dowolnym momencie"}
          </p>
        </div>
      </div>
    </section>
  );
}

/* ─── Plan Card ──────────────────────────────────────────────── */

function UpgradeCard({
  tier,
  tierName,
  row,
  cycle,
  locale,
  prefix,
  isHero,
}: {
  tier: string;
  tierName: string;
  row: PlanRow;
  cycle: BillingCycle;
  locale: string;
  prefix: string;
  isHero: boolean;
}) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const monthlyPrice =
    cycle === "ANNUAL" ? Math.round(row.priceGross / 12) : row.priceGross;
  const introMonthlyPrice = row.priceIntroGross
    ? cycle === "ANNUAL"
      ? Math.round(row.priceIntroGross / 12)
      : row.priceIntroGross
    : null;
  const sessionsLabel =
    locale === "en"
      ? `${row.tokensPerPeriod} sessions/${cycle === "ANNUAL" ? "year" : "month"}`
      : `${row.tokensPerPeriod} sesji/${cycle === "ANNUAL" ? "rok" : "mies."}`;

  const features =
    tier === "solo"
      ? locale === "en"
        ? [
            "30 AI-analyzed sessions/month",
            "Full reports + HiTOP",
            "Unlimited client files",
            "Encrypted local recording",
          ]
        : [
            "30 sesji z analizą AI/mies.",
            "Pełne raporty + HiTOP",
            "Nieograniczone kartoteki",
            "Szyfrowane nagrywanie lokalne",
          ]
      : locale === "en"
        ? [
            "90 AI-analyzed sessions/month",
            "Everything in Balance, plus:",
            "Priority processing queue",
            "Extended report customization",
          ]
        : [
            "90 sesji z analizą AI/mies.",
            "Wszystko z Równowagi, plus:",
            "Priorytetowa kolejka przetwarzania",
            "Rozszerzona personalizacja raportów",
          ];

  // Build the correct planSlug reflecting the selected cycle
  const cycleSuffix = cycle === "ANNUAL" ? "annual" : "monthly";
  const planSlug = `${tier}_${cycleSuffix}`;
  const registerHref = `${prefix}/register/therapist?plan=${planSlug}`;

  // Checkout handler: if logged in → /api/checkout direct; else → registration
  const handleCheckout = useCallback(async () => {
    if (!row.stripePriceId) {
      // No Stripe price configured (e.g. CLINIC tier) — go to contact
      window.location.href = `${prefix}/kontakt`;
      return;
    }

    setError(null);
    setLoading(true);

    try {
      const auth = getAuth();
      const user = auth.currentUser;

      if (!user) {
        // Not logged in — redirect to registration with plan pre-selected
        window.location.href = registerHref;
        return;
      }

      // Logged in: resolve organizationId via identity-svc
      const token = await user.getIdToken();
      const ctx = await identityClient.validateToken(
        { firebaseIdToken: token },
      );
      const organizationId = ctx.organizationId;

      if (!organizationId) {
        // User exists but no org (edge case) — fallback to registration
        console.warn("[UpgradeCard] No organizationId, falling back to register");
        window.location.href = registerHref;
        return;
      }

      // Call /api/checkout with the user's org and email
      const resp = await fetch("/api/checkout", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`,
        },
        body: JSON.stringify({
          priceId: row.stripePriceId,
          organizationId,
          email: user.email ?? undefined,
        }),
      });

      if (!resp.ok) {
        const body = await resp.json().catch(() => ({}));
        throw new Error(body.error || `Checkout failed (${resp.status})`);
      }

      const { url } = await resp.json();
      if (url) {
        window.location.href = url;
      } else {
        throw new Error("No checkout URL returned");
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Unexpected error";
      console.error("[UpgradeCard] checkout error:", err);
      setError(
        locale === "en"
          ? `Error: ${msg}`
          : `Błąd: ${msg}`,
      );
    } finally {
      setLoading(false);
    }
  }, [row.stripePriceId, prefix, registerHref, locale]);

  return (
    <div
      className={`relative rounded-2xl p-6 sm:p-8 flex flex-col transition-all duration-300 ${
        isHero
          ? "bg-[#004D54] text-white shadow-xl shadow-[#004D54]/20 ring-2 ring-[#2F6B62]"
          : "bg-white text-[#1B2522] shadow-lg border border-[#E2DED5]"
      }`}
    >
      {/* Popular badge */}
      {isHero && (
        <span className="absolute -top-3 left-1/2 -translate-x-1/2 inline-flex items-center gap-1 px-3 py-1 rounded-full bg-[#F5A623] text-[#1B2522] text-[10px] font-mono uppercase tracking-wider font-bold shadow-md">
          {locale === "en" ? "Most popular" : "Najpopularniejszy"}
        </span>
      )}

      {/* Tier name */}
      <h3
        className={`font-serif text-lg font-bold mb-1 ${
          isHero ? "text-[#F5A623]" : "text-[#004D54]"
        }`}
      >
        {tierName}
      </h3>

      {/* Sessions badge */}
      <span
        className={`inline-flex self-start items-center px-2 py-0.5 rounded-full text-[10px] font-mono uppercase tracking-wider font-bold mb-4 ${
          isHero
            ? "bg-white/10 text-white/80"
            : "bg-[#004D54]/5 text-[#004D54]"
        }`}
      >
        {sessionsLabel}
      </span>

      {/* Price */}
      <div className="mb-5">
        {introMonthlyPrice && (
          <div className="flex items-baseline gap-2 mb-1">
            <span
              className={`text-sm line-through ${
                isHero ? "text-white/40" : "text-[#4E5A55]/40"
              }`}
            >
              {formatPrice(locale, monthlyPrice)} zł
            </span>
            {row.couponCode && (
              <span
                className={`text-[10px] font-mono uppercase tracking-wider ${
                  isHero ? "text-[#F5A623]" : "text-[#2F6B62]"
                }`}
              >
                {row.couponCode}
              </span>
            )}
          </div>
        )}
        <div className="flex items-baseline gap-1">
          <span className="text-4xl sm:text-5xl font-bold font-sans tabular-nums">
            {formatPrice(locale, introMonthlyPrice ?? monthlyPrice)}
          </span>
          <span
            className={`text-base font-sans ${
              isHero ? "text-white/60" : "text-[#4E5A55]"
            }`}
          >
            zł
            <span className="text-xs">
              /{locale === "en" ? "mo" : "mies."}
            </span>
          </span>
        </div>
        {cycle === "ANNUAL" && (
          <p
            className={`text-[11px] mt-1 ${
              isHero ? "text-white/50" : "text-[#4E5A55]/50"
            }`}
          >
            {locale === "en"
              ? `Billed ${formatPrice(locale, row.priceIntroGross ?? row.priceGross)} zł/year`
              : `Rozliczenie ${formatPrice(locale, row.priceIntroGross ?? row.priceGross)} zł/rok`}
          </p>
        )}
      </div>

      {/* Features */}
      <ul className="space-y-2.5 mb-6 flex-1">
        {features.map((f) => (
          <li key={f} className="flex items-start gap-2 text-sm font-sans">
            <span
              className={`mt-0.5 text-xs ${
                isHero ? "text-[#F5A623]" : "text-[#2F6B62]"
              }`}
            >
              ✓
            </span>
            <span className={isHero ? "text-white/90" : "text-[#4E5A55]"}>
              {f}
            </span>
          </li>
        ))}
      </ul>

      {/* Error message */}
      {error && (
        <p className={`text-xs font-sans mb-3 ${
          isHero ? "text-red-300" : "text-red-600"
        }`}>
          {error}
        </p>
      )}

      {/* CTA */}
      <button
        onClick={handleCheckout}
        disabled={loading}
        className={`block w-full text-center py-3.5 rounded-full font-sans font-bold text-sm uppercase tracking-wider transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed ${
          isHero
            ? "bg-gradient-to-r from-[#FCAE2F] to-[#F97316] text-obsidian hover:brightness-110 shadow-lg shadow-[#FCAE2F]/20"
            : "bg-[#004D54] text-white hover:bg-[#003A40] shadow-md"
        }`}
      >
        {loading
          ? (locale === "en" ? "Redirecting…" : "Przekierowuję…")
          : (locale === "en" ? "Choose this plan" : "Wybierz ten plan")}
      </button>
    </div>
  );
}

