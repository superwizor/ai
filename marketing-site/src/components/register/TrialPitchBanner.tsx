// TrialPitchBanner — visual pitch block shown at the top of /register/therapist.
//
// Shows what the user gets with the free trial (10 sessions, 30 days, full access).
// When ?plan=solo_monthly or ?plan=pro_monthly is in the URL, shows the paid plan
// pitch instead with a note that registration comes first.

"use client";

import { useSearchParams } from "next/navigation";
import { useLocale } from "next-intl";
import { lookupPlan, formatPrice, TRIAL_COPY } from "@/lib/billing/plans";
import type { PlanTier, BillingCycle } from "@/lib/billing/plans";

type PitchVariant = "trial" | "solo" | "pro" | "beta";

function resolvePitch(plan: string | null): PitchVariant {
  if (!plan) return "trial";
  const lower = plan.toLowerCase();
  if (lower.startsWith("solo")) return "solo";
  if (lower.startsWith("pro")) return "pro";
  if (lower === "beta") return "beta";
  return "trial";
}

function renderPitchHeading(
  planSlug: string | null,
  variant: PitchVariant,
  locale: string,
  fallbackHeading: string,
  isForm: boolean = false
) {
  if (variant !== "solo" && variant !== "pro") {
    return fallbackHeading;
  }

  const isAnnual = planSlug ? planSlug.toLowerCase().endsWith("annual") : false;
  const cycle: BillingCycle = isAnnual ? "ANNUAL" : "MONTHLY";
  const tier: PlanTier = variant === "solo" ? "SOLO" : "PRO";
  const planRow = lookupPlan(tier, cycle);

  if (!planRow) {
    return fallbackHeading;
  }

  const formattedBase = formatPrice(locale, planRow.priceGross);
  const formattedIntro = planRow.priceIntroGross !== undefined
    ? formatPrice(locale, planRow.priceIntroGross)
    : null;

  let sessionText = "";
  if (locale === "en") {
    const cycleText = cycle === "ANNUAL" ? "year" : "month";
    sessionText = `${planRow.tokensPerPeriod} sessions / ${cycleText} · `;
  } else {
    const cycleText = cycle === "ANNUAL" ? "rok" : "miesiąc";
    sessionText = `${planRow.tokensPerPeriod} sesji / ${cycleText} · `;
  }

  const priceSuffix = locale === "en" ? " PLN" : " zł brutto";
  const strikeTextColor = isForm ? "text-frost/40" : "text-[#1B2522]/40";
  const activeTextColor = isForm ? "text-frost" : "text-[#1B2522]";

  if (formattedIntro) {
    return (
      <span className="flex items-center justify-center flex-wrap gap-x-1.5 leading-tight">
        <span>{sessionText}</span>
        <span className="whitespace-nowrap inline-flex items-center gap-x-1.5">
          <span className={`relative inline-block font-medium ${strikeTextColor}`}>
            <span className="opacity-70">{formattedBase}</span>
            <span className="absolute left-0 right-0 top-[52%] h-[2px] bg-[#fcae2f] -translate-y-1/2 rounded-full shadow-[0_0_3px_rgba(252,174,47,0.35)]" />
          </span>
          <span className={`font-extrabold ${activeTextColor}`}>
            {formattedIntro}
          </span>
          <span>{priceSuffix}</span>
        </span>
      </span>
    );
  }

  return (
    <span>
      {sessionText}
      {formattedBase}
      {priceSuffix}
    </span>
  );
}

// 🚨 Session counts come from TRIAL_COPY (src/lib/billing/plans.ts).
//    NEVER hardcode session numbers here — change tokensPerPeriod in plans.ts.
const CONTENT: Record<PitchVariant, { pl: ContentBlock; en: ContentBlock }> = {
  trial: {
    pl: {
      badge: "Darmowy start",
      heading: TRIAL_COPY.pl.heading,
      features: [
        TRIAL_COPY.pl.feature,
        "Pełny dostęp do wszystkich funkcji",
        "Bez karty kredytowej",
        "Anuluj w dowolnym momencie",
      ],
      footnote: "Po zarejestrowaniu otrzymasz natychmiast dostęp do aplikacji.",
    },
    en: {
      badge: "Free start",
      heading: TRIAL_COPY.en.heading,
      features: [
        TRIAL_COPY.en.feature,
        "Full access to all features",
        "No credit card required",
        "Cancel anytime",
      ],
      footnote: "After signing up you'll get immediate access to the app.",
    },
  },
  solo: {
    pl: {
      badge: "Plan Równowaga",
      heading: "30 sesji / miesiąc · 149 zł brutto",
      features: [
        "Pełny dostęp do wszystkich funkcji",
        "Raport w Twoim nurcie terapeutycznym",
        "Ciągłość między sesjami",
      ],
      footnote:
        "Najpierw załóż konto — po rejestracji przekierujemy Cię do bezpiecznej płatności.",
    },
    en: {
      badge: "Balance plan",
      heading: "30 sessions / month · 149 PLN",
      features: [
        "Full access to all features",
        "Reports in your therapeutic modality",
        "Session-to-session continuity",
      ],
      footnote:
        "Create your account first — after signup we’ll redirect you to secure checkout.",
    },
  },
  pro: {
    pl: {
      badge: "Plan Rozkwit · Najczęściej wybierany",
      heading: "90 sesji / miesiąc · 299 zł brutto",
      features: [
        "Pełny dostęp do wszystkich funkcji",
        "Raport w Twoim nurcie terapeutycznym",
        "Ciągłość między sesjami",
        "Idealny przy pełnym grafiku",
      ],
      footnote:
        "Najpierw załóż konto — po rejestracji przekierujemy Cię do bezpiecznej płatności.",
    },
    en: {
      badge: "Growth plan · Most popular",
      heading: "90 sessions / month · 299 PLN",
      features: [
        "Full access to all features",
        "Reports in your therapeutic modality",
        "Session-to-session continuity",
        "Perfect for a full schedule",
      ],
      footnote:
        "Create your account first — after signup we’ll redirect you to secure checkout.",
    },
  },
  beta: {
    pl: {
      badge: "Program Beta · Darmowy dostęp",
      heading: "120 sesji / miesiąc przez 2 miesiące",
      features: [
        "120 sesji terapeutycznych miesięcznie",
        "Pełny dostęp do wszystkich funkcji",
        "2 miesiące za darmo",
        "Priorytetowe wsparcie zespołu",
      ],
      footnote: "Załóż konto — dostęp do programu beta zostanie aktywowany automatycznie.",
    },
    en: {
      badge: "Beta Program · Free access",
      heading: "120 sessions / month for 2 months",
      features: [
        "120 therapy sessions per month",
        "Full access to all features",
        "2 months completely free",
        "Priority team support",
      ],
      footnote: "Create your account — beta access will be activated automatically.",
    },
  },
};

type ContentBlock = {
  badge: string;
  heading: string;
  features: string[];
  footnote: string;
};

export function TrialPitchBanner() {
  const searchParams = useSearchParams();
  const locale = useLocale();
  const plan = searchParams.get("plan");
  const variant = resolvePitch(plan);
  const content = CONTENT[variant][locale === "en" ? "en" : "pl"];
  const isTrial = variant === "trial";

  return (
    <div
      className={`rounded-[16px] border p-6 sm:p-8 mb-8 ${
        isTrial
          ? "bg-gradient-to-br from-[#E6F2F0] to-[#F2F0EA] border-[#B2DFD8]"
          : "bg-gradient-to-br from-[#004D54]/5 to-[#F2F0EA] border-[#004D54]/15"
      }`}
    >
      {/* Badge */}
      <span
        className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider mb-4 ${
          isTrial
            ? "bg-ember/15 text-[#8B6914] border border-ember/25"
            : "bg-[#004D54]/10 text-[#004D54] border border-[#004D54]/20"
        }`}
      >
        <span
          className={`w-1.5 h-1.5 rounded-full ${
            isTrial ? "bg-ember animate-pulse" : "bg-[#004D54]"
          }`}
        />
        {content.badge}
      </span>

      {/* Heading */}
      <h2 className="font-display text-[#1B2522] text-xl sm:text-2xl font-bold tracking-tight mt-2">
        {renderPitchHeading(plan, variant, locale, content.heading, false)}
      </h2>

      {/* Features */}
      <ul className="mt-4 space-y-2">
        {content.features.map((feat, i) => (
          <li
            key={i}
            className="flex items-center gap-2.5 font-sans text-sm text-[#4E5A55]"
          >
            <svg
              className="w-4 h-4 text-[#2F6B62] shrink-0"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={2.5}
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M5 13l4 4L19 7"
              />
            </svg>
            {feat}
          </li>
        ))}
      </ul>

      {/* Footnote */}
      <p className="mt-4 font-sans text-[11px] text-[#4E5A55]/60">
        {content.footnote}
      </p>
    </div>
  );
}
