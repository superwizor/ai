// BetaSignupSection — the main content block for the /beta page.
//
// Shows the beta program offer (50 spots, 120 sessions/mo x 2 months)
// and links to the registration page with ?plan=beta query param.

"use client";

import { useState } from "react";
import { Testimonials } from "@/components/marketing/Testimonials";const CONTENT = {
  pl: {
    overline: "Program Beta",
    heading: "Zostań jednym z 50 pionierów",
    subhead:
      "Zapraszamy do zamkniętej grupy terapeutów, którzy jako pierwsi przetestują Superwizor AI w swojej praktyce.",
    badge: "Tylko 50 miejsc",
    features: [
      {
        icon: "🎯",
        tag: "LIMIT",
        title: "120 sesji co miesiąc",
        desc: "Pełny dostęp do transkrypcji i generowania ustrukturyzowanych raportów bez obaw o zużycie limitu.",
        detail: "120 sesji / mies. przez cały okres testów",
      },
      {
        icon: "📅",
        tag: "PROMOCJA",
        title: "2 miesiące za darmo",
        desc: "Dwa pełne okresy rozliczeniowe (60 dni) bez żadnych opłat i ukrytych kosztów. Bez konieczności podawania karty.",
        detail: "Wartość pakietu: ponad 600 PLN",
      },
      {
        icon: "🔒",
        tag: "DOSTĘP",
        title: "Wszystkie funkcje bez limitu",
        desc: "Otrzymujesz pełny dostęp do wszystkich funkcji systemu, w tym szablonów dopasowanych do nurtu (CBT, psychodynamiczny itp.).",
        detail: "Równoważnik planu Rozkwit (Growth)",
      },
      {
        icon: "💬",
        tag: "WSPÓŁPRACA",
        title: "Wpływ na rozwój produktu",
        desc: "Dedykowana linia kontaktu z założycielami i deweloperami Superwizora AI. Zgłaszaj pomysły i współtwórz z nami przyszłość terapii.",
        detail: "Priorytetowy feedback loop",
      },
    ],
    security: {
      tag: "BEZPIECZEŃSTWO",
      title: "Najwyższe standardy poufności danych",
      desc: "Jako platforma dla psychoterapeutów, bezpieczeństwo informacji stawiamy na pierwszym miejscu. Twoje nagrania i dane są w pełni chronione w oparciu o restrykcyjne standardy.",
      items: [
        "Szyfrowanie kopertowe (AES-256 + KMS) wrażliwych danych PHI",
        "Serwery w chmurze zlokalizowane wyłącznie w UE (zgodność z RODO)",
        "Automatyczne kasowanie nagrań audio bezpośrednio po przetworzeniu",
        "Możliwość podpisania umowy powierzenia przetwarzania danych (DPA)"
      ]
    },
    cta: "Dołącz do programu Beta",
    after:
      "Po wygaśnięciu okresu beta możesz kontynuować na wybranym planie płatnym lub zakończyć korzystanie.",
    faq: {
      heading: "Najczęściej zadawane pytania",
      items: [
        {
          q: "Co się stanie po 2 miesiącach?",
          a: "Po zakończeniu okresu beta Twoje konto pozostanie aktywne, ale nie będziesz mógł/mogła zlecać nowych transkrypcji. Możesz w każdej chwili wykupić plan płatny, by kontynuować korzystanie.",
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
      "Join a closed group of therapists who will be the first to test Superwizor AI in their daily practice.",
    badge: "Only 50 spots",
    features: [
      {
        icon: "🎯",
        tag: "LIMIT",
        title: "120 sessions every month",
        desc: "Full access to transcription and structured reports without worrying about usage limits.",
        detail: "120 sessions / mo throughout the test period",
      },
      {
        icon: "📅",
        tag: "PROMO",
        title: "2 months free of charge",
        desc: "Two full billing periods (60 days) completely free. No credit card required to sign up.",
        detail: "Package value: over €150",
      },
      {
        icon: "🔒",
        tag: "ACCESS",
        title: "All features without limits",
        desc: "Get full access to all features, including modality-adapted templates (CBT, psychodynamic, etc.).",
        detail: "Growth plan equivalent",
      },
      {
        icon: "💬",
        tag: "COLLABORATION",
        title: "Shape the product directly",
        desc: "A dedicated support line directly to the founders and developer team. Propose features and help build the future of therapy.",
        detail: "Priority feedback loop",
      },
    ],
    security: {
      tag: "SECURITY",
      title: "Highest data confidentiality standards",
      desc: "As a platform built for psychotherapists, data security and privacy is our absolute priority. Your files are fully protected.",
      items: [
        "Envelope encryption (AES-256 + KMS) for sensitive PHI fields",
        "Cloud servers located strictly in the EU (GDPR compliant)",
        "Automatic, permanent deletion of audio immediately after processing",
        "Option to sign a Data Processing Agreement (DPA)"
      ]
    },
    cta: "Join the Beta Program",
    after:
      "After the beta period expires, you can continue on a paid plan or stop using the app.",
    faq: {
      heading: "Frequently asked questions",
      items: [
        {
          q: "What happens after 2 months?",
          a: "After the beta period ends, your account will remain active, but you won't be able to request new transcriptions. You can purchase a paid plan at any time to continue.",
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
      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes fadeUpIn {
          from { opacity: 0; transform: translateY(20px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @keyframes floatBack {
          0%, 100% { transform: translateY(0) rotate(-6deg); }
          50% { transform: translateY(-8px) rotate(-4deg); }
        }
        @keyframes floatFront {
          0%, 100% { transform: translateY(0) rotate(3deg); }
          50% { transform: translateY(8px) rotate(5deg); }
        }
        .animate-fade-up-1 { animation: fadeUpIn 0.8s cubic-bezier(0.16, 1, 0.3, 1) 0.1s both; }
        .animate-fade-up-2 { animation: fadeUpIn 0.8s cubic-bezier(0.16, 1, 0.3, 1) 0.3s both; }
        .animate-fade-up-3 { animation: fadeUpIn 0.8s cubic-bezier(0.16, 1, 0.3, 1) 0.5s both; }
        .animate-fade-up-4 { animation: fadeUpIn 0.8s cubic-bezier(0.16, 1, 0.3, 1) 0.7s both; }
        .animate-float-back { animation: floatBack 6s ease-in-out infinite; }
        .animate-float-front { animation: floatFront 6s ease-in-out infinite 0.5s; }
      `}} />

      {/* Hero */}
      <section className="relative w-full bg-[#001114] text-frost overflow-hidden border-b border-frost/5 py-20 sm:py-28 lg:py-32">
        {/* Decorative backdrop glow */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[85vw] max-w-[900px] h-[500px] bg-gradient-to-b from-ember/[0.07] to-transparent blur-[140px] pointer-events-none rounded-full" />

        <div className="relative mx-auto w-full max-w-[1080px] px-6">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
            
            {/* Left Column: Content & Call to Actions */}
            <div className="lg:col-span-7 flex flex-col items-center lg:items-start text-center lg:text-left">
              {/* Glowing spots badge */}
              <span className="animate-fade-up-1 inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-ember/10 text-ember border border-ember/30 font-mono text-[10.5px] font-bold uppercase tracking-wider mb-6 backdrop-blur-sm shadow-ember-glow">
                <span className="w-2 h-2 rounded-full bg-ember animate-pulse" />
                {c.badge}
              </span>

              {/* Overline */}
              <p className="animate-fade-up-1 font-mono text-[10px] sm:text-xs uppercase text-mist tracking-[var(--tracking-overline)] mb-3">
                {c.overline}
              </p>

              {/* Main Heading */}
              <h1 className="animate-fade-up-2 font-display text-frost text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight leading-tight">
                {c.heading}
              </h1>

              {/* Subhead */}
              <p className="animate-fade-up-2 font-serif text-mist/80 text-base sm:text-lg lg:text-xl mt-6 max-w-xl leading-relaxed">
                {c.subhead}
              </p>

              {/* Primary Call to Action */}
              <div className="animate-fade-up-3 mt-10 flex flex-col sm:flex-row items-center gap-4 w-full sm:w-auto">
                <a
                  href={`${prefix}/register/therapist?plan=beta`}
                  className="group relative inline-flex items-center justify-center rounded-[5px] bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-10 py-4.5 transition-all duration-300 active:scale-[0.97] w-full sm:w-auto whitespace-nowrap overflow-hidden shadow-lg hover:brightness-110"
                >
                  <span className="absolute inset-0 rounded-[5px] bg-ember/40 blur-xl group-hover:blur-2xl transition-all duration-500 -z-10 scale-110" />
                  <span className="relative z-10 flex items-center gap-2">
                    {c.cta}
                    <span className="transition-transform duration-300 group-hover:translate-x-1">→</span>
                  </span>
                </a>
              </div>

              {/* Features bullet points under CTA */}
              <div className="animate-fade-up-4 mt-8 flex flex-wrap justify-center lg:justify-start gap-x-6 gap-y-2 text-[11px] sm:text-xs font-mono uppercase text-frost/80 font-bold">
                <span className="flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-ember" />
                  {locale === "en" ? "120 sessions / month" : "120 sesji / miesiąc"}
                </span>
                <span className="flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-[#5bf4bc]" />
                  {locale === "en" ? "2 months free" : "2 miesiące gratis"}
                </span>
                <span className="flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-mist" />
                  {locale === "en" ? "Full functionality" : "Pełna funkcjonalność"}
                </span>
              </div>
            </div>

            {/* Right Column: Layered Premium Screens Mockup */}
            <div className="animate-fade-up-3 lg:col-span-5 flex justify-center lg:justify-end relative">
              <div className="relative w-[320px] h-[360px] sm:w-[380px] sm:h-[420px] select-none">
                
                {/* Radial Glow light behind mockups */}
                <div className="absolute -inset-10 bg-[radial-gradient(circle_at_center,rgba(255,255,255,0.06),transparent_60%)] blur-[40px] pointer-events-none" />
                
                {/* Back Screen (Transcript View) */}
                <div className="absolute top-4 left-4 w-[210px] sm:w-[240px] rounded-[24px] border border-white/10 overflow-hidden bg-deep-teal shadow-large transform -rotate-6 transition-transform duration-500 hover:rotate-0 hover:scale-[1.03] z-10 animate-float-back">
                  <div className="bg-surface-teal/80 px-4 py-2 border-b border-glass-border flex items-center gap-1.5">
                    <span className="w-2 h-2 rounded-full bg-[#fa5555]" />
                    <span className="w-2 h-2 rounded-full bg-[#fcae2f]" />
                    <span className="w-2 h-2 rounded-full bg-[#5bf4bc]" />
                    <span className="text-[9px] font-mono text-mist/60 ml-2 uppercase tracking-wider">
                      {locale === "en" ? "Transcript" : "Transkrypcja"}
                    </span>
                  </div>
                  <img
                    src="/assets/mockup_transcript_green_real.webp"
                    alt="Verbatim Transcript"
                    className="w-full h-auto object-cover filter brightness-95"
                    loading="lazy"
                  />
                </div>

                {/* Front Screen (Clinical Report) */}
                <div className="absolute bottom-4 right-4 w-[210px] sm:w-[240px] rounded-[24px] border border-[#E2DED5]/20 overflow-hidden bg-[#FBFAF7] shadow-[0_24px_48px_-12px_rgba(0,0,0,0.5)] transform rotate-3 transition-transform duration-500 hover:rotate-0 hover:scale-[1.03] z-20 animate-float-front">
                  <div className="bg-[#E9EFEC] px-4 py-2 border-b border-[#E2DED5] flex items-center justify-between">
                    <div className="flex items-center gap-1.5">
                      <span className="w-2 h-2 rounded-full bg-[#004D54]" />
                      <span className="text-[9px] font-mono text-[#4E5A55] uppercase tracking-wider">
                        {locale === "en" ? "Analysis" : "Analiza"}
                      </span>
                    </div>
                    <span className="bg-[#5bf4bc]/20 text-[#004D54] font-bold text-[8px] px-1.5 py-0.5 rounded-full">
                      Gemini 2.5 Pro
                    </span>
                  </div>
                  <div className="relative">
                    <img
                      src="/assets/mockup_report_green.webp"
                      alt="Clinical Report"
                      className="w-full h-auto object-cover"
                      loading="lazy"
                    />
                    {/* Security Badge covering the HiTOP & CBT badge printed on the image */}
                    <div className="absolute top-[4.5%] right-[5%] bg-[#004D54] text-[#5bf4bc] border border-[#5bf4bc]/30 rounded-md px-1.5 py-0.5 shadow-md flex items-center gap-1 scale-[0.85] origin-top-right z-30">
                      <span className="w-1.5 h-1.5 rounded-full bg-[#5bf4bc] animate-pulse" />
                      <span className="font-mono text-[7.5px] font-bold tracking-wider uppercase">
                        {locale === "en" ? "E2E SECURED" : "SZYFROWANE E2E"}
                      </span>
                    </div>
                  </div>
                </div>
                
                {/* Decorative floating badges */}
                <div className="absolute top-[35%] -left-8 bg-white border border-[#E2DED5] rounded-xl px-2.5 py-1.5 shadow-medium flex items-center gap-1.5 z-30 animate-pulse-slow">
                  <svg className="w-3.5 h-3.5 text-[#004D54]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                  </svg>
                  <span className="font-sans text-[10px] font-bold text-[#1b2522]">
                    {locale === "en" ? "GDPR Compliant" : "Zgodność z RODO"}
                  </span>
                </div>
                <div className="absolute bottom-[25%] -right-4 bg-white border border-[#E2DED5] rounded-xl px-2.5 py-1.5 shadow-medium flex items-center gap-1.5 z-30 animate-pulse-slow">
                  <svg className="w-3.5 h-3.5 text-[#004D54]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                    <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                  </svg>
                  <span className="font-sans text-[10px] font-bold text-[#1b2522]">
                    {locale === "en" ? "100% Encrypted" : "Szyfrowanie E2E"}
                  </span>
                </div>

              </div>
            </div>

          </div>
        </div>
      </section>

      {/* Features grid */}
      <section className="py-24 bg-gradient-to-b from-[#FBFAF7] to-[#F2F0EA] border-y border-[#E2DED5]/60 relative overflow-hidden">
        {/* Subtle background grid pattern */}
        <div className="absolute inset-0 bg-[linear-gradient(to_right,rgba(0,0,0,0.015)_1px,transparent_1px),linear-gradient(to_bottom,rgba(0,0,0,0.015)_1px,transparent_1px)] bg-[size:3rem_3rem] pointer-events-none" />

        <div className="relative mx-auto w-full max-w-[1080px] px-6">
          {/* Section Header */}
          <div className="text-center mb-16">
            <span className="font-mono text-[10px] sm:text-xs uppercase text-[#004D54]/75 tracking-[3px] font-bold">
              {locale === "en" ? "Program Benefits" : "Warunki i korzyści"}
            </span>
            <h2 className="font-display text-[#004D54] text-3xl sm:text-4xl font-bold tracking-tight mt-3">
              {locale === "en" ? "Everything you need to test the future of therapy" : "Wszystko, czego potrzebujesz, by przetestować Superwizora"}
            </h2>
          </div>

          {/* Bento Grid */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {/* Card 1: 120 Sessions */}
            <div className="group relative rounded-[24px] border border-[#E2DED5] bg-white p-8 hover:border-[#004D54]/25 hover:shadow-large transition-all duration-300 transform hover:-translate-y-1 overflow-hidden flex flex-col justify-between min-h-[260px]">
              <div className="absolute top-0 right-0 w-32 h-32 bg-gradient-to-bl from-[#004D54]/[0.03] to-transparent rounded-bl-full pointer-events-none" />
              <div className="relative z-10">
                <div className="flex justify-between items-start">
                  <div className="w-12 h-12 rounded-xl bg-[#004D54]/5 group-hover:bg-[#004D54]/10 flex items-center justify-center text-[#004D54] transition-colors duration-300">
                    <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                      <circle cx="12" cy="12" r="10" />
                      <circle cx="12" cy="12" r="6" />
                      <circle cx="12" cy="12" r="2" />
                    </svg>
                  </div>
                  <span className="font-mono text-[9px] font-bold px-2 py-0.5 rounded bg-[#004D54]/5 text-[#004D54]/75">
                    {locale === "en" ? "LIMIT" : "LIMIT"}
                  </span>
                </div>
                <h3 className="font-display text-[#004D54] text-lg font-bold tracking-tight mt-6">
                  {c.features[0].title}
                </h3>
                <p className="font-sans text-[13.5px] text-[#4E5A55] mt-3 leading-relaxed">
                  {c.features[0].desc}
                </p>
              </div>
              <div className="relative z-10 border-t border-[#E2DED5]/60 pt-4 mt-6">
                <span className="font-sans text-[11px] font-bold text-[#004D54]/70">
                  {c.features[0].detail}
                </span>
              </div>
            </div>

            {/* Card 2: 2 Months Free */}
            <div className="group relative rounded-[24px] border border-[#E2DED5] bg-white p-8 hover:border-[#004D54]/25 hover:shadow-large transition-all duration-300 transform hover:-translate-y-1 overflow-hidden flex flex-col justify-between min-h-[260px]">
              <div className="absolute top-0 right-0 w-32 h-32 bg-gradient-to-bl from-ember/[0.08] to-transparent rounded-bl-full pointer-events-none animate-pulse" />
              <div className="relative z-10">
                <div className="flex justify-between items-start">
                  <div className="w-12 h-12 rounded-xl bg-ember/10 group-hover:bg-ember/20 flex items-center justify-center text-[#004D54] transition-colors duration-300">
                    <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                      <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
                      <line x1="16" y1="2" x2="16" y2="6" />
                      <line x1="8" y1="2" x2="8" y2="6" />
                      <line x1="3" y1="10" x2="21" y2="10" />
                    </svg>
                  </div>
                  <span className="font-mono text-[9px] font-bold px-2 py-0.5 rounded bg-ember/15 text-[#8B6914] border border-ember/20">
                    {locale === "en" ? "PROMO" : "PROMOCJA"}
                  </span>
                </div>
                <h3 className="font-display text-[#004D54] text-lg font-bold tracking-tight mt-6">
                  {c.features[1].title}
                </h3>
                <p className="font-sans text-[13.5px] text-[#4E5A55] mt-3 leading-relaxed">
                  {c.features[1].desc}
                </p>
              </div>
              <div className="relative z-10 border-t border-[#E2DED5]/60 pt-4 mt-6">
                <span className="font-sans text-[11px] font-bold text-[#8B6914]">
                  {c.features[1].detail}
                </span>
              </div>
            </div>

            {/* Card 4: Contact / Co-creation */}
            <div className="group relative rounded-[24px] border border-[#E2DED5] bg-white p-8 hover:border-[#004D54]/25 hover:shadow-large transition-all duration-300 transform hover:-translate-y-1 overflow-hidden flex flex-col justify-between min-h-[260px]">
              <div className="absolute top-0 right-0 w-32 h-32 bg-gradient-to-bl from-blue-500/[0.05] to-transparent rounded-bl-full pointer-events-none" />
              <div className="relative z-10">
                <div className="flex justify-between items-start">
                  <div className="w-12 h-12 rounded-xl bg-[#004D54]/5 group-hover:bg-[#004D54]/10 flex items-center justify-center text-[#004D54] transition-colors duration-300">
                    <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
                    </svg>
                  </div>
                  <span className="font-mono text-[9px] font-bold px-2 py-0.5 rounded bg-blue-500/10 text-blue-700">
                    {locale === "en" ? "VIP ACCESS" : "WSPÓŁPRACA"}
                  </span>
                </div>
                <h3 className="font-display text-[#004D54] text-lg font-bold tracking-tight mt-6">
                  {c.features[3].title}
                </h3>
                <p className="font-sans text-[13.5px] text-[#4E5A55] mt-3 leading-relaxed">
                  {c.features[3].desc}
                </p>
              </div>
              <div className="relative z-10 border-t border-[#E2DED5]/60 pt-4 mt-6">
                <span className="font-sans text-[11px] font-bold text-blue-700">
                  {c.features[3].detail}
                </span>
              </div>
            </div>

            {/* Card 3: Deep Security Showcase (Spans full width) */}
            <div className="md:col-span-3 group relative rounded-[28px] border border-white/[0.08] bg-gradient-to-br from-[#002326] to-[#001114] text-frost p-8 sm:p-10 hover:shadow-large transition-all duration-300 overflow-hidden">
              {/* Radial glow */}
              <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(91,244,188,0.04),transparent_60%)] pointer-events-none" />
              
              <div className="relative z-10 grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
                {/* Left side copy */}
                <div className="lg:col-span-6 text-left">
                  <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-mono text-[9px] font-bold uppercase tracking-wider mb-6">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                    {c.security.tag}
                  </span>
                  
                  <h3 className="font-display text-frost text-2xl sm:text-3xl font-bold tracking-tight leading-tight">
                    {c.security.title}
                  </h3>
                  
                  <p className="font-serif text-mist/70 text-[14px] sm:text-base mt-4 leading-relaxed max-w-xl">
                    {c.security.desc}
                  </p>
                </div>

                {/* Right side checklist grid */}
                <div className="lg:col-span-6 bg-white/[0.02] border border-white/5 rounded-2xl p-6 sm:p-8">
                  <ul className="space-y-4 text-left">
                    {c.security.items.map((item, idx) => (
                      <li key={idx} className="flex items-start gap-3.5">
                        <span className="flex items-center justify-center w-5 h-5 rounded-full bg-[#5bf4bc]/10 text-[#5bf4bc] text-[10px] shrink-0 font-bold mt-0.5">
                          ✓
                        </span>
                        <span className="font-sans text-[13.5px] sm:text-[14.5px] text-mist/90 leading-tight">
                          {item}
                        </span>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </div>

          </div>

          <p className="text-center font-sans text-xs text-[#4E5A55]/60 mt-12">
            {c.after}
          </p>
        </div>
      </section>

      {/* Testimonials Marquee Component */}
      <Testimonials />

      {/* FAQ */}
      <section className="py-20 sm:py-24 bg-[#FBFAF7]">
        <div className="mx-auto w-full max-w-2xl px-6">
          <h2 className="font-display text-[#004D54] text-2xl sm:text-3xl font-bold tracking-tight text-center mb-10">
            {c.faq.heading}
          </h2>

          <div className="space-y-3">
            {c.faq.items.map((item, i) => (
              <div
                key={i}
                className="rounded-[12px] border border-[#E2DED5]/60 bg-white overflow-hidden shadow-sm"
              >
                <button
                  type="button"
                  onClick={() => setOpenFaq(openFaq === i ? null : i)}
                  className="w-full flex items-center justify-between px-5 py-4 hover:bg-[#F2F0EA] transition-colors text-left"
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
      <section className="py-20 text-center bg-gradient-to-b from-[#001114] to-[#002E32] text-frost border-t border-frost/5">
        <div className="mx-auto w-full max-w-xl px-6">
          <h2 className="font-display text-frost text-2xl sm:text-3xl font-bold tracking-tight mb-4">
            {locale === "en" ? "Ready to become a pioneer?" : "Gotowy, aby zostać pionierem?"}
          </h2>
          <p className="font-serif text-mist/75 text-sm sm:text-base mb-8 max-w-md mx-auto">
            {locale === "en"
              ? "Join today and start transcribing your sessions with the power of AI."
              : "Dołącz już dziś i zacznij transkrybować swoje sesje z pomocą sztucznej inteligencji."}
          </p>
          <a
            href={`${prefix}/register/therapist?plan=beta`}
            className="group relative inline-flex items-center justify-center rounded-[5px] bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs px-10 py-4 transition-all duration-300 active:scale-[0.97] whitespace-nowrap overflow-hidden hover:brightness-110 shadow-lg"
          >
            <span className="absolute inset-0 rounded-[5px] bg-ember/40 blur-xl group-hover:blur-2xl transition-all duration-500 -z-10 scale-110" />
            <span className="relative z-10 flex items-center gap-2">
              {c.cta}
              <span className="transition-transform duration-300 group-hover:translate-x-1">→</span>
            </span>
          </a>
        </div>
      </section>
    </>
  );
}
