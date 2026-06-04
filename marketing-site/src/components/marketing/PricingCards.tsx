// PricingCards — Premium pricing redesign for Version B.
//
// Design principles:
// - Pro card is the HERO: dark background, stands out dramatically
// - No coupon codes visible (ugly) — just "Twoja cena" + strikethrough
// - Features are minimal and differentiated per tier
// - Large breathing space, clean typography hierarchy
// - Smooth toggle with integrated savings badge
// - One clean footnote line, not three

"use client";

import { useState } from "react";
import { useTranslations, useLocale } from "next-intl";

import type { BillingCycle, PlanRow } from "@/lib/billing/plans";
import { findPlan, formatPrice } from "@/lib/billing/plans";

export function PricingCards({ catalog }: { catalog: ReadonlyArray<PlanRow> }) {
  const [cycle, setCycle] = useState<BillingCycle>("MONTHLY");
  const t = useTranslations("pricing");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  const isAnnual = cycle === "ANNUAL";

  return (
    <>
      {/* --- Toggle --- */}
      <div className="flex flex-col items-center mb-14">
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
              !isAnnual ? "text-white" : "text-[#4E5A55] hover:text-[#1B2522]"
            }`}
          >
            {t("cycle.monthly")}
          </button>
          <button
            role="tab"
            aria-selected={isAnnual}
            onClick={() => setCycle("ANNUAL")}
            className={`relative z-10 w-[130px] sm:w-[150px] py-2.5 rounded-full font-sans font-bold text-xs sm:text-sm uppercase tracking-wider transition-colors duration-300 cursor-pointer text-center ${
              isAnnual ? "text-white" : "text-[#4E5A55] hover:text-[#1B2522]"
            }`}
          >
            {t("cycle.annual")}
          </button>
        </div>
        <div className="h-6 mt-2">
          {isAnnual && (
            <span className="inline-flex items-center gap-1.5 text-[#004D54] font-sans text-[11px] uppercase tracking-wider font-bold animate-fade-in">
              <span className="w-1.5 h-1.5 rounded-full bg-[#004D54] animate-pulse" />
              {locale === "en" ? "Annual billing — 17% off" : "Rozliczenie roczne — 17% taniej"}
            </span>
          )}
        </div>
      </div>

      {/* --- Cards Grid --- */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 items-stretch">
        {/* Trial */}
        <TrialCard registerHref={`${prefix}/register/therapist`} locale={locale} />

        {/* Solo */}
        <PaidCard
          tier="solo"
          row={findPlan(catalog, "SOLO", cycle)!}
          cycle={cycle}
          locale={locale}
          isHero={false}
        />

        {/* Pro — HERO card */}
        <PaidCard
          tier="pro"
          row={findPlan(catalog, "PRO", cycle)!}
          cycle={cycle}
          locale={locale}
          isHero={true}
        />

        {/* Clinic */}
        <ClinicCard locale={locale} />
      </div>

      {/* --- Clean footnote --- */}
      <div className="mt-10 text-center space-y-2">
        <p className="font-sans text-sm text-[#004D54] font-semibold">
          {locale === "en"
            ? "Start now. Lock in the lower price forever."
            : "Zacznij teraz. Zatrzymaj niższą cenę na zawsze."}
        </p>
        <p className="font-mono text-[10px] uppercase tracking-wider text-[#4E5A55]">
          {locale === "en"
            ? "Prices excl. VAT 23% · Secure payment via Stripe · Cancel anytime"
            : "Ceny netto + VAT 23% · Bezpieczna płatność przez Stripe · Anuluj w dowolnym momencie"}
        </p>
      </div>

      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes fade-in { from { opacity: 0; transform: translateY(-4px); } to { opacity: 1; transform: translateY(0); } }
        .animate-fade-in { animation: fade-in 0.3s ease-out both; }
      `}} />
    </>
  );
}

/* ─── Trial ──────────────────────────────────────────────────────── */

function TrialCard({ registerHref, locale }: { registerHref: string; locale: string }) {
  return (
    <article className="flex flex-col rounded-[20px] bg-white border border-[#E2DED5] p-7 sm:p-8 justify-between h-full hover:border-[#004D54]/20 hover:shadow-lg transition-all duration-300">
      <div>
        <h3 className="font-display text-[#004D54] text-lg font-bold tracking-tight">
          {locale === "en" ? "Trial" : "Poznanie"}
        </h3>
        <p className="font-sans text-[#4E5A55]/70 text-sm mt-1">
          {locale === "en" ? "See if it's for you." : "Sprawdź, czy to dla Ciebie."}
        </p>

        <div className="mt-7">
          <span className="font-display text-[#1B2522] text-5xl font-bold tracking-tight">0</span>
          <span className="font-display text-[#1B2522]/40 text-lg font-medium ml-1">zł</span>
        </div>

        <ul className="mt-7 space-y-2.5">
          <Feat>{locale === "en" ? "3 sessions in 14 days" : "3 sesje przez 14 dni"}</Feat>
          <Feat>{locale === "en" ? "Full access to all features" : "Pełen dostęp do aplikacji"}</Feat>
          <Feat>{locale === "en" ? "No credit card" : "Bez karty kredytowej"}</Feat>
        </ul>
      </div>

      <a
        href={registerHref}
        className="mt-8 w-full inline-flex items-center justify-center rounded-[12px] border border-[#E2DED5] text-[#1B2522] font-sans font-bold uppercase tracking-wider text-xs px-6 py-3.5 hover:bg-[#F2F0EA] hover:border-[#004D54]/20 transition-all duration-200 active:scale-[0.98] whitespace-nowrap"
      >
        {locale === "en" ? "Try for free" : "Wypróbuj za darmo"}
      </a>
    </article>
  );
}

/* ─── Paid (Solo / Pro) ──────────────────────────────────────────── */

function PaidCard({
  tier,
  row,
  cycle,
  locale,
  isHero,
}: {
  tier: "solo" | "pro";
  row: PlanRow;
  cycle: BillingCycle;
  locale: string;
  isHero: boolean;
}) {
  const priceUnit = cycle === "MONTHLY"
    ? (locale === "en" ? "/mo" : "/mies.")
    : (locale === "en" ? "/yr" : "/rok");

  const formattedIntro = row.priceIntroGross !== undefined
    ? formatPrice(locale, row.priceIntroGross)
    : null;
  const formattedBase = formatPrice(locale, row.priceGross);
  const checkoutHref = row.stripePaymentLink;

  // Tier-specific content
  const name = tier === "solo"
    ? (locale === "en" ? "Balance" : "Równowaga")
    : (locale === "en" ? "Growth" : "Rozkwit");
  const tagline = tier === "solo"
    ? (locale === "en" ? "For individual therapists." : "Dla terapeutów indywidualnych.")
    : (locale === "en" ? "For intensive practice." : "Dla intensywnej praktyki.");
  const sessions = tier === "solo"
    ? (locale === "en" ? "Up to 30 sessions/month" : "Do 30 sesji miesięcznie")
    : (locale === "en" ? "Up to 120 sessions/month" : "Do 120 sesji miesięcznie");
  const cta = tier === "solo"
    ? (locale === "en" ? "Choose Balance" : "Wybieram Równowagę")
    : (locale === "en" ? "Choose Growth" : "Wybieram Rozkwit");

  const cardClasses = isHero
    ? "bg-gradient-to-b from-[#004D54] to-[#002E32] text-frost border-[#004D54] shadow-xl scale-[1.02] sm:scale-105"
    : "bg-white text-[#1B2522] border-[#E2DED5] hover:border-[#004D54]/20 hover:shadow-lg";

  const nameColor = isHero ? "text-ember" : "text-[#004D54]";
  const taglineColor = isHero ? "text-frost/50" : "text-[#4E5A55]/70";
  const priceColor = isHero ? "text-frost" : "text-[#1B2522]";
  const priceUnitColor = isHero ? "text-frost/40" : "text-[#1B2522]/40";
  const strikeColor = isHero ? "text-frost/25" : "text-[#4E5A55]/30";
  const subColor = isHero ? "text-ember/60" : "text-[#004D54]/60";
  const featColor = isHero ? "text-frost/65" : "text-[#4E5A55]";
  const featDotColor = isHero ? "bg-ember/50" : "bg-[#004D54]/40";

  const ctaClasses = isHero
    ? "bg-ember text-obsidian hover:brightness-110 shadow-lg"
    : "border border-[#E2DED5] text-[#1B2522] hover:bg-[#F2F0EA] hover:border-[#004D54]/20";

  return (
    <article className={`relative flex flex-col rounded-[20px] border p-7 sm:p-8 justify-between h-full transition-all duration-300 ${cardClasses}`}>
      {isHero && (
        <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-ember text-obsidian font-mono uppercase text-[10px] tracking-wider px-4 py-1 font-bold shadow-sm whitespace-nowrap">
          {locale === "en" ? "Most popular" : "Najczęściej wybierany"}
        </span>
      )}

      <div>
        <h3 className={`font-display text-lg font-bold tracking-tight ${nameColor}`}>
          {name}
        </h3>
        <p className={`font-sans text-sm mt-1 ${taglineColor}`}>
          {tagline}
        </p>

        <div className="mt-7">
          {formattedIntro ? (
            <>
              <div className="flex items-baseline gap-1.5">
                <span className={`font-display text-5xl font-bold tracking-tight ${priceColor}`}>
                  {formattedIntro}
                </span>
                <span className={`font-sans text-sm font-medium ${priceUnitColor}`}>
                  {priceUnit}
                </span>
              </div>
              <div className="flex items-center gap-2 mt-1.5">
                <span className={`line-through text-sm ${strikeColor}`}>
                  {formattedBase} zł
                </span>
                <span className={`font-mono text-[10px] uppercase tracking-wider font-semibold ${subColor}`}>
                  {locale === "en" ? "your price forever" : "Twoja cena na zawsze"}
                </span>
              </div>
            </>
          ) : (
            <div className="flex items-baseline gap-1.5">
              <span className={`font-display text-5xl font-bold tracking-tight ${priceColor}`}>
                {formattedBase}
              </span>
              <span className={`font-sans text-sm font-medium ${priceUnitColor}`}>
                {priceUnit}
              </span>
            </div>
          )}
        </div>

        <ul className="mt-7 space-y-2.5">
          <FeatCustom dotColor={featDotColor} textColor={featColor}>{sessions}</FeatCustom>
          <FeatCustom dotColor={featDotColor} textColor={featColor}>
            {locale === "en" ? "Full access to all features" : "Pełen dostęp do aplikacji"}
          </FeatCustom>
        </ul>
      </div>

      {checkoutHref ? (
        <a
          href={checkoutHref}
          target="_blank"
          rel="noopener noreferrer"
          className={`mt-8 w-full inline-flex items-center justify-center rounded-[12px] font-sans font-bold uppercase tracking-wider text-xs px-6 py-3.5 transition-all duration-200 active:scale-[0.98] cursor-pointer whitespace-nowrap ${ctaClasses}`}
        >
          {cta}
        </a>
      ) : (
        <span className="mt-8 w-full inline-flex items-center justify-center rounded-[12px] border border-[#E2DED5]/40 text-[#1B2522]/40 font-sans font-bold uppercase tracking-wider text-xs px-6 py-3.5 cursor-not-allowed whitespace-nowrap">
          {cta}
        </span>
      )}
    </article>
  );
}

/* ─── Clinic ─────────────────────────────────────────────────────── */

function ClinicCard({ locale }: { locale: string }) {
  return (
    <article className="flex flex-col rounded-[20px] bg-white border border-[#E2DED5] p-7 sm:p-8 justify-between h-full hover:border-[#004D54]/20 hover:shadow-lg transition-all duration-300">
      <div>
        <h3 className="font-display text-[#004D54] text-lg font-bold tracking-tight">
          {locale === "en" ? "Enterprise" : "Ewolucja"}
        </h3>
        <p className="font-sans text-[#4E5A55]/70 text-sm mt-1">
          {locale === "en" ? "For clinics and teams." : "Dla poradni i zespołów."}
        </p>

        <div className="mt-7">
          <span className="font-display text-[#004D54] text-4xl font-bold tracking-tight">
            {locale === "en" ? "Custom" : "Wycena"}
          </span>
          <p className="font-mono text-[10px] uppercase tracking-wider text-[#4E5A55]/50 mt-1.5">
            {locale === "en" ? "tailored to your needs" : "indywidualne warunki"}
          </p>
        </div>

        <ul className="mt-7 space-y-2.5">
          <Feat>{locale === "en" ? "Flexible session limits" : "Elastyczny limit sesji"}</Feat>
          <Feat>{locale === "en" ? "Multi-account management" : "Obsługa wielu kont"}</Feat>
          <Feat>{locale === "en" ? "Onboarding support" : "Wsparcie wdrożenia"}</Feat>
        </ul>
      </div>

      <a
        href="mailto:kontakt@superwizor.ai?subject=Plan%20Ewolucja%20-%20wycena"
        className="mt-8 w-full inline-flex items-center justify-center rounded-[12px] border border-[#E2DED5] text-[#1B2522] font-sans font-bold uppercase tracking-wider text-xs px-6 py-3.5 hover:bg-[#F2F0EA] hover:border-[#004D54]/20 transition-all duration-200 active:scale-[0.98] whitespace-nowrap"
      >
        {locale === "en" ? "Let's talk" : "Porozmawiajmy"}
      </a>
    </article>
  );
}

/* ─── Feature line helpers ───────────────────────────────────────── */

function Feat({ children }: { children: React.ReactNode }) {
  return (
    <li className="flex items-center gap-2.5 font-sans text-sm text-[#4E5A55] leading-snug">
      <span className="w-1.5 h-1.5 rounded-full bg-[#004D54]/40 shrink-0" />
      <span>{children}</span>
    </li>
  );
}

function FeatCustom({ children, dotColor, textColor }: { children: React.ReactNode; dotColor: string; textColor: string }) {
  return (
    <li className={`flex items-center gap-2.5 font-sans text-sm leading-snug ${textColor}`}>
      <span className={`w-1.5 h-1.5 rounded-full shrink-0 ${dotColor}`} />
      <span>{children}</span>
    </li>
  );
}
