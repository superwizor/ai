// UpgradeSection — the core UI for /upgrade.
//
// Plan: "bez opcji free, krótki pitch + 2 plany (Równowaga + Rozkwit)"
// Design: short motivational pitch + two large cards + promo codes.
// No trial card — they already had their trial.

"use client";

import { useState } from "react";
import type { BillingCycle, PlanRow } from "@/lib/billing/plans";
import { findPlan, formatPrice } from "@/lib/billing/plans";

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
              ? "Choose the plan that fits your practice. All your sessions, reports, and patient files stay exactly where you left them."
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

        {/* --- Promo codes --- */}
        <div className="mt-10 text-center">
          <p className="font-mono text-[10px] uppercase tracking-wider text-[#4E5A55] mb-3">
            {locale === "en" ? "Promotional codes" : "Kody promocyjne"}
          </p>
          <div className="flex flex-wrap justify-center gap-3">
            <PromoTag code="ROWNOWAGA20" label={locale === "en" ? "-20% Balance" : "-20% Równowaga"} />
            <PromoTag code="ROZKWIT30" label={locale === "en" ? "-30% Growth" : "-30% Rozkwit"} />
            <PromoTag code="PIONIER33" label={locale === "en" ? "~40% any plan" : "~40% każdy plan"} />
          </div>
          <p className="font-sans text-[11px] text-[#4E5A55]/60 mt-2">
            {locale === "en"
              ? "Enter the code during checkout. The discount locks in forever."
              : "Wpisz kod przy płatności. Rabat zostaje na zawsze."}
          </p>
        </div>

        {/* --- Footnote --- */}
        <div className="mt-8 text-center">
          <p className="font-mono text-[10px] uppercase tracking-wider text-[#4E5A55]">
            {locale === "en"
              ? "Prices incl. 23% VAT · Secure payment via Stripe · Cancel anytime"
              : "Ceny brutto z VAT 23% · Bezpieczna płatność przez Stripe · Anuluj w dowolnym momencie"}
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
            "Full clinical reports + HiTOP",
            "Unlimited patient files",
            "Encrypted local recording",
          ]
        : [
            "30 sesji z analizą AI/mies.",
            "Pełne raporty kliniczne + HiTOP",
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

  const planSlug = tier === "solo" ? "solo_monthly" : "pro_monthly";
  const checkoutHref = `${prefix}/register/therapist?plan=${planSlug}`;

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

      {/* CTA */}
      <a
        href={checkoutHref}
        className={`block w-full text-center py-3.5 rounded-xl font-sans font-bold text-sm uppercase tracking-wider transition-all duration-200 ${
          isHero
            ? "bg-[#F5A623] text-[#1B2522] hover:bg-[#E09500] shadow-lg shadow-[#F5A623]/30"
            : "bg-[#004D54] text-white hover:bg-[#003A40] shadow-md"
        }`}
      >
        {locale === "en" ? "Choose this plan" : "Wybierz ten plan"}
      </a>
    </div>
  );
}

/* ─── Promo Tag ──────────────────────────────────────────────── */

function PromoTag({ code, label }: { code: string; label: string }) {
  return (
    <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white border border-[#E2DED5] shadow-sm">
      <span className="font-mono text-xs font-bold text-[#004D54] tracking-wider">
        {code}
      </span>
      <span className="text-[10px] text-[#4E5A55]">{label}</span>
    </span>
  );
}
