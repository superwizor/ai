// TrialPitchBanner — visual pitch block shown at the top of /register/therapist.
//
// Shows what the user gets with the free trial (5 sessions, 30 days, full access).
// When ?plan=solo_monthly or ?plan=pro_monthly is in the URL, shows the paid plan
// pitch instead with a note that registration comes first.

"use client";

import { useSearchParams } from "next/navigation";
import { useLocale } from "next-intl";

type PitchVariant = "trial" | "solo" | "pro" | "beta";

function resolvePitch(plan: string | null): PitchVariant {
  if (!plan) return "trial";
  const lower = plan.toLowerCase();
  if (lower.startsWith("solo")) return "solo";
  if (lower.startsWith("pro")) return "pro";
  if (lower === "beta") return "beta";
  return "trial";
}

const CONTENT: Record<PitchVariant, { pl: ContentBlock; en: ContentBlock }> = {
  trial: {
    pl: {
      badge: "Darmowy start",
      heading: "Zacznij od 5 sesji za darmo",
      features: [
        "5 sesji terapeutycznych przez 30 dni",
        "Pe\u0142ny dost\u0119p do wszystkich funkcji",
        "Bez karty kredytowej",
        "Anuluj w dowolnym momencie",
      ],
      footnote: "Po zarejestrowaniu otrzymasz natychmiast dost\u0119p do aplikacji.",
    },
    en: {
      badge: "Free start",
      heading: "Start with 5 free sessions",
      features: [
        "5 therapy sessions for 30 days",
        "Full access to all features",
        "No credit card required",
        "Cancel anytime",
      ],
      footnote: "After signing up you\u2019ll get immediate access to the app.",
    },
  },
  solo: {
    pl: {
      badge: "Plan R\u00f3wnowaga",
      heading: "30 sesji / miesi\u0105c \u00b7 179 z\u0142 brutto",
      features: [
        "Pe\u0142ny dost\u0119p do wszystkich funkcji",
        "Raport w Twoim nurcie terapeutycznym",
        "Ci\u0105g\u0142o\u015b\u0107 mi\u0119dzy sesjami",
      ],
      footnote:
        "Najpierw za\u0142\u00f3\u017c konto \u2014 po rejestracji przekierujemy Ci\u0119 do bezpiecznej p\u0142atno\u015bci.",
    },
    en: {
      badge: "Balance plan",
      heading: "30 sessions / month \u00b7 179 PLN",
      features: [
        "Full access to all features",
        "Reports in your therapeutic modality",
        "Session-to-session continuity",
      ],
      footnote:
        "Create your account first \u2014 after signup we\u2019ll redirect you to secure checkout.",
    },
  },
  pro: {
    pl: {
      badge: "Plan Rozkwit \u00b7 Najcz\u0119\u015bciej wybierany",
      heading: "90 sesji / miesi\u0105c \u00b7 299 z\u0142 brutto",
      features: [
        "Pe\u0142ny dost\u0119p do wszystkich funkcji",
        "Raport w Twoim nurcie terapeutycznym",
        "Ci\u0105g\u0142o\u015b\u0107 mi\u0119dzy sesjami",
        "Idealny przy pe\u0142nym grafiku",
      ],
      footnote:
        "Najpierw za\u0142\u00f3\u017c konto \u2014 po rejestracji przekierujemy Ci\u0119 do bezpiecznej p\u0142atno\u015bci.",
    },
    en: {
      badge: "Growth plan \u00b7 Most popular",
      heading: "90 sessions / month \u00b7 299 PLN",
      features: [
        "Full access to all features",
        "Reports in your therapeutic modality",
        "Session-to-session continuity",
        "Perfect for a full schedule",
      ],
      footnote:
        "Create your account first \u2014 after signup we\u2019ll redirect you to secure checkout.",
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
        {content.heading}
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
