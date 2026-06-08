// BetaSignupSection — the main content block for the /beta page.
//
// Shows the beta program offer (50 spots, 120 sessions/mo x 2 months)
// and links to the registration page with ?plan=beta query param.

"use client";

import { useState } from "react";

const CONTENT = {
  pl: {
    overline: "Program Beta",
    heading: "Zostań jednym z 50 pionierów",
    subhead:
      "Zapraszamy do zamkniętej grupy terapeutów, którzy jako pierwsi przetestują Superwizor AI w praktyce klinicznej.",
    badge: "Tylko 50 miejsc",
    features: [
      {
        icon: "🎯",
        title: "120 sesji miesięcznie",
        desc: "Pełny dostęp do transkrypcji, raportów klinicznych i ciągłości między sesjami.",
      },
      {
        icon: "📅",
        title: "2 miesiące za darmo",
        desc: "Dwa pełne okresy rozliczeniowe (2 × 30 dni × 120 sesji). Bez ukrytych kosztów.",
      },
      {
        icon: "🔒",
        title: "Pełna funkcjonalność",
        desc: "Wszystkie funkcje jak w planie Rozkwit. Bez ograniczeń.",
      },
      {
        icon: "💬",
        title: "Bezpośredni kontakt z zespołem",
        desc: "Priorytetowe wsparcie i możliwość wpływu na rozwój produktu.",
      },
    ],
    cta: "Dołącz do programu Beta",
    after:
      "Po wygaśnięciu okresu beta możesz kontynuować na wybranym planie płatnym lub zakończyć korzystanie.",
    faq: {
      heading: "Najczęściej zadawane pytania",
      items: [
        {
          q: "Co się stanie po 2 miesiącach?",
          a: "Twoje konto przejdzie na plan darmowy (5 sesji / 30 dni). Możesz w każdej chwili przejść na plan płatny, by zachować pełny dostęp.",
        },
        {
          q: "Czy moje dane będą bezpieczne?",
          a: "Tak. Stosujemy te same zabezpieczenia co w wersji produkcyjnej: szyfrowanie end-to-end, serwery w EU, RODO.",
        },
        {
          q: "Czy mogę zrezygnować w trakcie?",
          a: "Oczywiście. Możesz zamknąć konto w dowolnym momencie. Twoje nagrania są usuwane zaraz po transkrypcji.",
        },
      ],
    },
  },
  en: {
    overline: "Beta Program",
    heading: "Be one of 50 pioneers",
    subhead:
      "Join a closed group of therapists who will be the first to test Superwizor AI in clinical practice.",
    badge: "Only 50 spots",
    features: [
      {
        icon: "🎯",
        title: "120 sessions / month",
        desc: "Full access to transcriptions, clinical reports, and session-to-session continuity.",
      },
      {
        icon: "📅",
        title: "2 months free",
        desc: "Two full billing periods (2 × 30 days × 120 sessions). No hidden costs.",
      },
      {
        icon: "🔒",
        title: "Full functionality",
        desc: "All features as in the Growth plan. No limitations.",
      },
      {
        icon: "💬",
        title: "Direct contact with the team",
        desc: "Priority support and the ability to influence product development.",
      },
    ],
    cta: "Join the Beta Program",
    after:
      "After the beta period expires, you can continue on a paid plan or stop using the app.",
    faq: {
      heading: "Frequently asked questions",
      items: [
        {
          q: "What happens after 2 months?",
          a: "Your account will switch to the free plan (5 sessions / 30 days). You can upgrade to a paid plan at any time to keep full access.",
        },
        {
          q: "Is my data safe?",
          a: "Yes. We use the same security measures as in the production version: end-to-end encryption, EU servers, GDPR compliance.",
        },
        {
          q: "Can I cancel during the beta?",
          a: "Of course. You can close your account at any time. Your recordings are deleted immediately after transcription.",
        },
      ],
    },
  },
};

export function BetaSignupSection({ locale }: { locale: string }) {
  const c = CONTENT[locale === "en" ? "en" : "pl"];
  const prefix = locale === "en" ? "/en" : "";
  const [openFaq, setOpenFaq] = useState<number | null>(null);

  return (
    <>
      {/* Hero */}
      <section className="relative overflow-hidden py-20 sm:py-28">
        {/* Subtle gradient bg */}
        <div className="absolute inset-0 bg-gradient-to-b from-[#004D54]/5 via-transparent to-transparent pointer-events-none" />

        <div className="relative mx-auto w-full max-w-2xl px-6 text-center">
          <span className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-ember/15 text-[#8B6914] border border-ember/25 font-mono text-[10px] font-bold uppercase tracking-wider mb-6">
            <span className="w-2 h-2 rounded-full bg-ember animate-pulse" />
            {c.badge}
          </span>

          <p className="font-mono text-[10px] sm:text-xs uppercase text-mist tracking-[var(--tracking-overline)] mb-3">
            {c.overline}
          </p>

          <h1 className="font-display text-frost text-4xl sm:text-5xl font-bold tracking-tight leading-tight">
            {c.heading}
          </h1>

          <p className="font-serif text-mist text-lg mt-6 max-w-xl mx-auto leading-relaxed">
            {c.subhead}
          </p>

          <a
            href={`${prefix}/register/therapist?plan=beta`}
            className="group relative inline-flex items-center justify-center rounded-[12px] bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-sm px-10 py-4 mt-10 transition-all duration-300 active:scale-[0.97] whitespace-nowrap overflow-hidden hover:brightness-110 shadow-lg"
          >
            <span className="absolute inset-0 rounded-[12px] bg-ember/40 blur-xl group-hover:blur-2xl transition-all duration-500 -z-10 scale-110" />
            {c.cta}
            <span className="ml-2">→</span>
          </a>
        </div>
      </section>

      {/* Features grid */}
      <section className="py-16 sm:py-20 bg-gradient-to-b from-[#FBFAF7] to-[#F2F0EA] border-y border-[#E2DED5]/60">
        <div className="mx-auto w-full max-w-3xl px-6">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
            {c.features.map((feat, i) => (
              <div
                key={i}
                className="rounded-[16px] border border-[#E2DED5] bg-white p-6 hover:border-[#004D54]/20 hover:shadow-md transition-all duration-300"
              >
                <span className="text-2xl mb-3 block">{feat.icon}</span>
                <h3 className="font-display text-[#004D54] text-base font-bold tracking-tight">
                  {feat.title}
                </h3>
                <p className="font-sans text-sm text-[#4E5A55] mt-2 leading-relaxed">
                  {feat.desc}
                </p>
              </div>
            ))}
          </div>

          <p className="text-center font-sans text-xs text-[#4E5A55]/60 mt-8">
            {c.after}
          </p>
        </div>
      </section>

      {/* FAQ */}
      <section className="py-16 sm:py-20">
        <div className="mx-auto w-full max-w-xl px-6">
          <h2 className="font-display text-frost text-2xl font-bold tracking-tight text-center mb-8">
            {c.faq.heading}
          </h2>

          <div className="space-y-3">
            {c.faq.items.map((item, i) => (
              <div
                key={i}
                className="rounded-[12px] border border-[#E2DED5]/60 overflow-hidden"
              >
                <button
                  type="button"
                  onClick={() => setOpenFaq(openFaq === i ? null : i)}
                  className="w-full flex items-center justify-between px-5 py-4 bg-[#FBFAF7] hover:bg-[#F2F0EA] transition-colors text-left"
                >
                  <span className="font-sans text-sm font-semibold text-[#1B2522]">
                    {item.q}
                  </span>
                  <span
                    className={`text-[#4E5A55] transition-transform duration-200 ${
                      openFaq === i ? "rotate-180" : ""
                    }`}
                  >
                    ▾
                  </span>
                </button>
                {openFaq === i && (
                  <div className="px-5 py-4 bg-white border-t border-[#E2DED5]/40">
                    <p className="font-sans text-sm text-[#4E5A55] leading-relaxed">
                      {item.a}
                    </p>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="py-16 text-center">
        <a
          href={`${prefix}/register/therapist?plan=beta`}
          className="inline-flex items-center justify-center rounded-[12px] bg-[#004D54] text-white font-sans font-bold uppercase tracking-wider text-xs px-8 py-4 hover:bg-[#002E32] transition-all duration-200 active:scale-[0.97] whitespace-nowrap"
        >
          {c.cta}
          <span className="ml-2">→</span>
        </a>
      </section>
    </>
  );
}
