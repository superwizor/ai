// PricingCardsDetailed — Premium pricing redesign for Version B.
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
        {/* Symmetric Premium Discount Tag */}
        <div className="mb-4 relative">
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[10.5px] sm:text-xs font-bold bg-[#E6F2F0] text-[#004D54] border border-[#B2DFD8] shadow-[0_2px_10px_rgba(0,77,84,0.06)] whitespace-nowrap select-none tracking-wide">
            <span className="w-1.5 h-1.5 rounded-full bg-[#2F6B62] animate-pulse" />
            {locale === "en" ? "Yearly billing: 17% off · 2 months free" : "Płatność roczna: 17% taniej · 2 miesiące gratis"}
          </span>
          <div className="absolute top-full left-1/2 -translate-x-1/2 w-2 h-2 bg-[#E6F2F0] border-r border-b border-[#B2DFD8] rotate-45 -mt-[5px]" />
        </div>

        <div
          role="tablist"
          aria-label="billing cycle"
          className="relative inline-flex items-center rounded-full bg-[#F2F0EA] border border-[#E2DED5] p-1"
        >
          <div
            className={`absolute top-1 bottom-1 w-[calc(50%-4px)] rounded-full bg-[#004D54] shadow-lg transition-all duration-300 ease-out ${isAnnual ? "left-[calc(50%+2px)]" : "left-1"
              }`}
          />
          <button
            role="tab"
            aria-selected={!isAnnual}
            onClick={() => setCycle("MONTHLY")}
            className={`relative z-10 w-[130px] sm:w-[150px] py-2.5 rounded-full font-sans font-bold text-xs sm:text-sm uppercase tracking-wider transition-colors duration-300 cursor-pointer text-center ${!isAnnual ? "text-white" : "text-[#4E5A55] hover:text-[#1B2522]"
              }`}
          >
            {t("cycle.monthly")}
          </button>
          <button
            role="tab"
            aria-selected={isAnnual}
            onClick={() => setCycle("ANNUAL")}
            className={`relative z-10 w-[130px] sm:w-[150px] py-2.5 rounded-full font-sans font-bold text-xs sm:text-sm uppercase tracking-wider transition-colors duration-300 cursor-pointer text-center ${isAnnual ? "text-white" : "text-[#4E5A55] hover:text-[#1B2522]"
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

      {/* --- Split Grid Layout (Left: 2x2 cards, Right: Cozy Office + Review) --- */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        {/* Left Column: Pricing Cards Grid */}
        <div className="lg:col-span-8 grid grid-cols-1 sm:grid-cols-2 gap-6 items-stretch">
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

        {/* Right Column: Visual Therapy Office & Testimonial Showcase */}
        <div className="lg:col-span-4 lg:sticky lg:top-28 flex flex-col gap-6">
          <div className="rounded-[24px] border border-[#E2DED5] bg-white p-6 shadow-[0_4px_20px_rgba(0,0,0,0.02)] hover:shadow-[0_8px_30px_rgba(0,0,0,0.04)] transition-all duration-350">
            {/* Elegant Image Container */}
            <div className="relative aspect-[1.1] w-full overflow-hidden rounded-[16px] border border-[#E2DED5]/50 shadow-inner mb-5">
              <img
                src="/assets/therapy-cozy-office.png"
                alt={locale === "en" ? "Cozy therapy space" : "Gabinet terapeutyczny"}
                className="object-cover w-full h-full brightness-[0.98] contrast-[1.02]"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/10 to-transparent" />
            </div>

            {/* Testimonial Quote */}
            <div className="flex flex-col gap-4">
              {/* Star Rating */}
              <div className="flex gap-1">
                {[1, 2, 3, 4, 5].map((s) => (
                  <svg key={s} className="w-4.5 h-4.5 text-[#FCAE2F] fill-[#FCAE2F]" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                  </svg>
                ))}
              </div>

              <p className="font-serif text-[#1B2522] text-[13.5px] sm:text-[14px] italic leading-relaxed before:content-['„'] after:content-['”'] font-medium">
                {locale === "en"
                  ? "It prevents losing 30 to 40% of information that is normally lost when writing notes by hand."
                  : "Pozwala uniknąć utraty od 30 do 40% informacji, które tracę przy ręcznym przygotowywaniu notatek."}
              </p>

              {/* Author Info */}
              <div className="flex items-center gap-3 pt-4 border-t border-[#E2DED5]/60">
                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#004D54] to-[#002E32] flex items-center justify-center font-sans font-bold text-xs text-[#E6F2F0] shadow-md select-none shrink-0">
                  A
                </div>
                <div className="flex flex-col text-left overflow-hidden">
                  <span className="font-sans font-bold text-xs text-[#1B2522]">Agnieszka</span>
                  <span className="font-sans text-[10px] text-[#004D54] font-semibold flex items-center gap-1.5">
                    <span>{locale === "en" ? "psychotherapist" : "psychoterapeutka"}</span>
                    <span className="text-[#004D54]/20">•</span>
                    <span className="text-[#D84515] border border-[#D84515]/20 bg-[#D84515]/5 px-1.5 py-0.5 rounded-full text-[8.5px] font-bold shrink-0">
                      {locale === "en" ? "CBT approach" : "nurt CBT"}
                    </span>
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* --- Clean footnote --- */}
      <div className="mt-12 text-center space-y-2">
        <p className="font-sans text-sm text-[#004D54] font-bold tracking-wide">
          {locale === "en"
            ? "Start now."
            : "Zacznij teraz."}
        </p>
        <p className="font-mono text-[10px] uppercase tracking-widest text-[#4E5A55] font-semibold">
          {locale === "en"
            ? "Prices incl. 23% VAT · Secure payment via Stripe · Cancel anytime"
            : "Ceny brutto z VAT 23% · Bezpieczna płatność przez Stripe · Anuluj w dowolnym momencie"}
        </p>
      </div>

      <style dangerouslySetInnerHTML={{
        __html: `
        @keyframes fade-in { from { opacity: 0; transform: translateY(-4px); } to { opacity: 1; transform: translateY(0); } }
        .animate-fade-in { animation: fade-in 0.3s ease-out both; }
      `}} />
    </>
  );
}

/* ─── Trial ──────────────────────────────────────────────────────── */

function TrialCard({ registerHref, locale }: { registerHref: string; locale: string }) {
  return (
    <article className="flex flex-col rounded-[20px] bg-white border border-[#E2DED5] p-7 sm:p-8 justify-between h-full hover:border-[#004D54]/40 hover:shadow-[0_8px_30px_rgba(0,0,0,0.04)] transition-all duration-300">
      <div>
        <h3 className="font-display text-[#004D54] text-lg font-bold tracking-tight">
          {locale === "en" ? "Discovery" : "Poznanie"}
        </h3>
        <p className="font-sans text-[#4E5A55] text-sm mt-1.5 font-medium leading-relaxed">
          {locale === "en" ? "See if it's for you." : "Sprawdź, czy to dla Ciebie."}
        </p>

        <div className="mt-7">
          <span className="font-display text-[#1B2522] text-5xl font-bold tracking-tight">0</span>
          <span className="font-display text-[#1B2522] text-lg font-bold ml-1">zł</span>
        </div>

        <ul className="mt-7 space-y-3">
          <Feat>{locale === "en" ? "5 sessions for 30 days" : "5 sesji przez 30 dni"}</Feat>
          <Feat>{locale === "en" ? "Full access to all features" : "Pełen dostęp do aplikacji"}</Feat>
          <Feat>{locale === "en" ? "No credit card required" : "Bez karty kredytowej"}</Feat>
        </ul>
      </div>

      <a
        href={registerHref}
        className="mt-8 w-full inline-flex items-center justify-center rounded-[12px] bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs px-6 py-4 hover:brightness-110 hover:shadow-md transition-all duration-200 active:scale-[0.98] whitespace-nowrap shadow-sm"
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
    : (locale === "en" ? "Up to 90 sessions/month" : "Do 90 sesji miesięcznie");
  const cta = tier === "solo"
    ? (locale === "en" ? "Choose Balance" : "Wybieram Równowagę")
    : (locale === "en" ? "Choose Growth" : "Wybieram Rozkwit");

  const cardClasses = isHero
    ? "bg-gradient-to-b from-[#004D54] to-[#002E32] text-frost border-[#004D54] shadow-[0_4px_30px_rgba(252,174,47,0.12)] scale-[1.02] sm:scale-[1.03]"
    : "bg-white text-[#1B2522] border-[#E2DED5] hover:border-[#004D54]/40 hover:shadow-[0_8px_30px_rgba(0,0,0,0.04)]";

  const nameColor = isHero ? "text-ember" : "text-[#004D54]";
  const taglineColor = isHero ? "text-frost/85" : "text-[#4E5A55]";
  const priceColor = isHero ? "text-frost" : "text-[#1B2522]";
  const priceUnitColor = isHero ? "text-frost/80" : "text-[#1B2522]/85";
  const strikeColor = isHero ? "text-frost/60" : "text-[#4E5A55]/60";
  const subColor = isHero ? "text-ember font-bold" : "text-[#004D54] font-bold";
  const featColor = isHero ? "text-frost/90" : "text-[#4E5A55]";
  const featDotColor = isHero ? "bg-ember" : "bg-[#004D54]";

  const ctaClasses = isHero
    ? "bg-ember text-obsidian hover:brightness-110 hover:shadow-md shadow-sm"
    : "border border-[#E2DED5] text-[#1B2522] hover:bg-[#F2F0EA] hover:border-[#004D54]/40 hover:shadow-sm";

  return (
    <article className={`relative flex flex-col rounded-[20px] border p-7 sm:p-8 justify-between h-full transition-all duration-300 ${cardClasses}`}>
      {isHero && (
        <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-ember text-obsidian font-mono uppercase text-[10px] tracking-wider px-4 py-1 font-bold shadow-md whitespace-nowrap z-20">
          {locale === "en" ? "Most popular" : "Najczęściej wybierany"}
        </span>
      )}

      <div>
        <h3 className={`font-display text-lg font-bold tracking-tight ${nameColor}`}>
          {name}
        </h3>
        <p className={`font-sans text-sm mt-1.5 font-medium leading-relaxed ${taglineColor}`}>
          {tagline}
        </p>

        <div className="mt-7">
          {formattedIntro ? (
            <>
              <div className="flex items-baseline gap-1.5">
                <span className={`font-display text-5xl font-bold tracking-tight ${priceColor}`}>
                  {formattedIntro}
                </span>
                <span className={`font-sans text-sm font-bold ${priceUnitColor}`}>
                  {priceUnit}
                </span>
              </div>
              <div className="flex items-center gap-2 mt-1.5">
                <span className={`line-through text-sm font-medium ${strikeColor}`}>
                  {formattedBase} zł
                </span>
                <span className={`font-mono text-[10px] uppercase tracking-wider ${subColor}`}>
                  {row.couponCode
                    ? (locale === "en" ? `with code ${row.couponCode} · forever` : `z kodem ${row.couponCode} · na zawsze`)
                    : (locale === "en" ? "your price forever" : "Twoja cena na zawsze")
                  }
                </span>
              </div>
            </>
          ) : (
            <div className="flex items-baseline gap-1.5">
              <span className={`font-display text-5xl font-bold tracking-tight ${priceColor}`}>
                {formattedBase}
              </span>
              <span className={`font-sans text-sm font-bold ${priceUnitColor}`}>
                {priceUnit}
              </span>
            </div>
          )}
        </div>

        <ul className="mt-7 space-y-3">
          <FeatCustom dotColor={featDotColor} textColor={featColor}>{sessions}</FeatCustom>
          <FeatCustom dotColor={featDotColor} textColor={featColor}>
            {locale === "en" ? "Full access to all features" : "Pełen dostęp do aplikacji"}
          </FeatCustom>
        </ul>
      </div>

      {row.stripePriceId ? (
        <a
          href={`/${locale === "en" ? "en/" : ""}register/therapist?plan=${tier}_${cycle.toLowerCase()}`}
          className={`mt-8 w-full inline-flex items-center justify-center rounded-[12px] font-sans font-bold uppercase tracking-wider text-xs px-6 py-4 transition-all duration-200 active:scale-[0.98] cursor-pointer whitespace-nowrap ${ctaClasses}`}
        >
          {cta}
        </a>
      ) : (
        <span className="mt-8 w-full inline-flex items-center justify-center rounded-[12px] border border-[#E2DED5]/40 text-[#1B2522]/40 font-sans font-bold uppercase tracking-wider text-xs px-6 py-4 cursor-not-allowed whitespace-nowrap">
          {cta}
        </span>
      )}
    </article>
  );
}

/* ─── Clinic ─────────────────────────────────────────────────────── */

function ClinicCard({ locale }: { locale: string }) {
  return (
    <article className="flex flex-col rounded-[20px] bg-white border border-[#E2DED5] p-7 sm:p-8 justify-between h-full hover:border-[#004D54]/40 hover:shadow-[0_8px_30px_rgba(0,0,0,0.04)] transition-all duration-300">
      <div>
        <h3 className="font-display text-[#004D54] text-lg font-bold tracking-tight">
          {locale === "en" ? "Enterprise" : "Ewolucja"}
        </h3>
        <p className="font-sans text-[#4E5A55] text-sm mt-1.5 font-medium leading-relaxed">
          {locale === "en" ? "For clinics and teams." : "Dla poradni i zespołów."}
        </p>

        <div className="mt-7">
          <span className="font-display text-[#004D54] text-4xl font-bold tracking-tight">
            {locale === "en" ? "Custom" : "Wycena"}
          </span>
          <p className="font-mono text-[10px] uppercase tracking-wider text-[#4E5A55] font-semibold mt-1.5">
            {locale === "en" ? "tailored to your needs" : "indywidualne warunki"}
          </p>
        </div>

        <ul className="mt-7 space-y-3">
          <Feat>{locale === "en" ? "Flexible session limits" : "Elastyczny limit sesji"}</Feat>
          <Feat>{locale === "en" ? "Multi-account management" : "Obsługa wielu kont"}</Feat>
          <Feat>{locale === "en" ? "Onboarding support" : "Wsparcie wdrożenia"}</Feat>
        </ul>
      </div>

      <a
        href={`/${locale === "en" ? "en/" : ""}kontakt`}
        className="mt-8 w-full inline-flex items-center justify-center rounded-[12px] border border-[#E2DED5] text-[#1B2522] font-sans font-bold uppercase tracking-wider text-xs px-6 py-4 hover:bg-[#F2F0EA] hover:border-[#004D54]/40 hover:shadow-sm transition-all duration-200 active:scale-[0.98] whitespace-nowrap"
      >
        {locale === "en" ? "Let's talk" : "Porozmawiajmy"}
      </a>
    </article>
  );
}

/* ─── Feature line helpers ───────────────────────────────────────── */

function Feat({ children }: { children: React.ReactNode }) {
  return (
    <li className="flex items-center gap-2.5 font-sans text-sm text-[#4E5A55] leading-relaxed">
      <span className="w-1.5 h-1.5 rounded-full bg-[#004D54] shrink-0" />
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
