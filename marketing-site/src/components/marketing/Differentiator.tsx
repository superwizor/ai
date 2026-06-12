"use client";

import { useTranslations, useLocale } from "next-intl";
import { useRef, useState, useEffect } from "react";

/* ────────────────────────────────────────────────────────────── */
/*  Differentiator – "Transformation Journey" PRZED → PO       */
/* ────────────────────────────────────────────────────────────── */

export function Differentiator() {
  const t = useTranslations("b.differentiator");
  const locale = useLocale();
  const isPl = locale === "pl";

  const sectionRef = useRef<HTMLElement>(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) setIsVisible(true); },
      { threshold: 0.15 }
    );
    if (sectionRef.current) observer.observe(sectionRef.current);
    return () => observer.disconnect();
  }, []);

  const painItems = isPl
    ? [
        { icon: "📓", label: "Notatki rozsypane po zeszytach", detail: "Godziny szukania dawnych zapisków" },
        { icon: "🧠", label: "Kluczowe wątki gubione między sesjami", detail: "Klient wspomina — Ty nie pamiętasz" },
        { icon: "🌙", label: "Wieczór spędzony na dokumentacji", detail: "Zamiast z rodziną, z notatkami" },
        { icon: "😶", label: "Przygotowanie z pamięci przed spotkaniem", detail: "Niepełny obraz, luki i wątpliwości" },
      ]
    : [
        { icon: "📓", label: "Notes scattered across notebooks", detail: "Hours searching for old records" },
        { icon: "🧠", label: "Key threads lost between sessions", detail: "Client remembers — you don't" },
        { icon: "🌙", label: "Evening spent writing up documentation", detail: "Instead of family, with notes" },
        { icon: "😶", label: "Preparation from memory before the meeting", detail: "Incomplete picture, gaps and doubts" },
      ];

  const solutionItems = isPl
    ? [
        { icon: "🔍", label: "Wszystko przeszukiwalne w jednym miejscu", metric: "0 sec", metricLabel: "szukania" },
        { icon: "🤖", label: "AI pamięta wątki przez wszystkie sesje", metric: "100%", metricLabel: "ciągłości" },
        { icon: "⚡", label: "Raport kliniczny gotowy w minuty", metric: "3 min", metricLabel: "zamiast godziny" },
        { icon: "📋", label: "Pełny obraz klienta zanim zaczniesz", metric: "360°", metricLabel: "perspektywy" },
      ]
    : [
        { icon: "🔍", label: "Everything searchable in one place", metric: "0 sec", metricLabel: "searching" },
        { icon: "🤖", label: "AI remembers threads across all sessions", metric: "100%", metricLabel: "continuity" },
        { icon: "⚡", label: "Clinical report ready in minutes", metric: "3 min", metricLabel: "instead of hours" },
        { icon: "📋", label: "Full client picture before you begin", metric: "360°", metricLabel: "perspective" },
      ];

  return (
    <section
      ref={sectionRef}
      className="relative w-full bg-[#FBFAF7] text-[#1B2522] py-24 sm:py-32 border-y border-[#E2DED5]/60 overflow-hidden"
    >
      {/* ── Ambient light effects ─────────────────────────────── */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] rounded-full blur-3xl pointer-events-none" style={{ background: "radial-gradient(ellipse at center, rgba(252,174,47,0.05) 0%, transparent 70%)" }} />
      <div className="absolute bottom-0 left-1/4 w-[600px] h-[300px] rounded-full blur-3xl pointer-events-none" style={{ background: "radial-gradient(ellipse at center, rgba(0,77,84,0.03) 0%, transparent 70%)" }} />

      <div className="relative mx-auto w-full max-w-[1120px] px-6">
        {/* ── Section Header ──────────────────────────────────── */}
        <div className={`text-center mb-16 sm:mb-20 transition-all duration-700 ${isVisible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"}`}>
          <span className="inline-block font-sans text-xs uppercase tracking-[3px] text-[#004D54] font-bold mb-4">
            {isPl ? "Dlaczego Superwizor AI" : "Why Superwizor AI"}
          </span>
          <h2 className="font-display text-[#004D54] text-2xl sm:text-3xl lg:text-[2.75rem] font-bold tracking-tight leading-tight max-w-3xl mx-auto">
            {t("title")}
          </h2>
        </div>

        {/* ── Main Transformation Grid ────────────────────────── */}
        <div className="grid grid-cols-1 lg:grid-cols-[1fr_auto_1fr] gap-0 max-w-[1000px] mx-auto items-stretch">

          {/* ─── LEFT COLUMN: Pain / Without ─────────────────── */}
          <div className={`relative transition-all duration-700 delay-200 ${isVisible ? "opacity-100 translate-x-0" : "opacity-0 -translate-x-12"}`}>
            {/* Header badge */}
            <div className="flex items-center gap-2.5 mb-6">
              <span className="flex items-center justify-center w-6 h-6 rounded-full bg-[#1B2522]/[0.03] border border-[#1B2522]/[0.08]">
                <svg className="w-3.5 h-3.5 text-[#1B2522]/35" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M4 12L12 4M4 4l8 8" strokeLinecap="round" />
                </svg>
              </span>
              <span className="font-sans text-xs uppercase tracking-[2.5px] text-[#1B2522]/40 font-bold">
                {isPl ? "Bez" : "Without"} Superwizor AI
              </span>
            </div>

            {/* Pain cards */}
            <div className="space-y-3">
              {painItems.map((item, i) => (
                <div
                  key={i}
                  className="group relative rounded-xl p-4 sm:p-5 bg-white/[0.6] border border-[#E2DED5]/85 hover:bg-[#EDEAE3]/40 hover:border-[#E2DED5]/95 transition-all duration-300"
                  style={{ transitionDelay: isVisible ? `${300 + i * 100}ms` : "0ms" }}
                >
                  <div className="flex items-start gap-3.5">
                    <span className="text-lg grayscale opacity-60 select-none mt-0.5 shrink-0">{item.icon}</span>
                    <div className="min-w-0">
                      <p className="font-sans text-sm text-[#1B2522]/85 leading-snug line-through decoration-[#1B2522]/20 decoration-1">
                        {item.label}
                      </p>
                      <p className="font-sans text-xs text-[#4E5A55]/75 mt-1 leading-relaxed">
                        {item.detail}
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* ─── CENTER: Transformation Divider ─────────────── */}
          <div className={`hidden lg:flex flex-col items-center justify-center px-6 sm:px-10 transition-all duration-700 delay-500 ${isVisible ? "opacity-100 scale-100" : "opacity-0 scale-75"}`}>
            {/* Vertical line */}
            <div className="w-px flex-1 bg-gradient-to-b from-transparent via-[#E2DED5]/40 to-transparent" />

            {/* Arrow circle */}
            <div className="relative my-4">
              <div className="absolute inset-0 rounded-full bg-ember/20 blur-xl animate-pulse" />
              <div className="relative w-14 h-14 rounded-full bg-gradient-to-br from-ember to-[#E09520] flex items-center justify-center shadow-[0_0_30px_rgba(252,174,47,0.3)]">
                <svg className="w-6 h-6 text-[#1a1a1a]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                  <path d="M5 12h14M13 6l6 6-6 6" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </div>
            </div>

            {/* Vertical line */}
            <div className="w-px flex-1 bg-gradient-to-b from-transparent via-[#E2DED5]/40 to-transparent" />
          </div>

          {/* Mobile divider */}
          <div className={`flex lg:hidden items-center justify-center py-8 transition-all duration-500 delay-500 ${isVisible ? "opacity-100" : "opacity-0"}`}>
            <div className="flex-1 h-px bg-gradient-to-r from-transparent via-[#E2DED5]/40 to-transparent" />
            <div className="relative mx-4">
              <div className="absolute inset-0 rounded-full bg-ember/20 blur-xl animate-pulse" />
              <div className="relative w-12 h-12 rounded-full bg-gradient-to-br from-ember to-[#E09520] flex items-center justify-center shadow-[0_0_30px_rgba(252,174,47,0.3)]">
                <svg className="w-5 h-5 text-[#1a1a1a]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                  <path d="M12 5v14M6 13l6 6 6-6" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </div>
            </div>
            <div className="flex-1 h-px bg-gradient-to-r from-transparent via-[#E2DED5]/40 to-transparent" />
          </div>

          {/* ─── RIGHT COLUMN: Solution / With ───────────────── */}
          <div className={`relative transition-all duration-700 delay-200 ${isVisible ? "opacity-100 translate-x-0" : "opacity-0 translate-x-12"}`}>
            {/* Header badge */}
            <div className="flex items-center gap-2.5 mb-6">
              <span className="relative flex h-2.5 w-2.5">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-ember opacity-60" />
                <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-ember" />
              </span>
              <span className="font-sans text-xs uppercase tracking-[2.5px] text-[#004D54] font-bold">
                {isPl ? "Z" : "With"} Superwizor AI
              </span>
            </div>

            {/* Solution cards */}
            <div className="space-y-3">
              {solutionItems.map((item, i) => (
                <div
                  key={i}
                  className="group relative rounded-xl p-4 sm:p-5 bg-gradient-to-br from-[#004D54] to-[#002E32] text-frost border border-white/5 shadow-[0_12px_32px_-12px_rgba(0,77,84,0.25)] hover:shadow-[0_16px_40px_-12px_rgba(0,77,84,0.35)] hover:from-[#005c64] hover:to-[#00373c] transition-all duration-300"
                  style={{ transitionDelay: isVisible ? `${300 + i * 100}ms` : "0ms" }}
                >
                  <div className="relative flex items-start gap-3.5">
                    <span className="text-lg select-none mt-0.5 shrink-0">{item.icon}</span>
                    <div className="min-w-0 flex-1">
                      <p className="font-sans text-sm text-frost/95 leading-snug font-semibold">
                        {item.label}
                      </p>
                    </div>
                    {/* Micro-metric badge */}
                    <div className="shrink-0 text-right">
                      <span className="font-display text-lg font-bold text-ember leading-none">{item.metric}</span>
                      <p className="font-sans text-[10px] text-frost/50 mt-0.5">{item.metricLabel}</p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* ── Bottom Stats Bar ─────────────────────────────────── */}
        <div className={`mt-16 sm:mt-20 transition-all duration-700 delay-700 ${isVisible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-6"}`}>
          <div className="relative max-w-[700px] mx-auto rounded-2xl bg-white border border-[#E2DED5]/85 shadow-[0_8px_30px_rgba(27,37,34,0.04)] p-6 sm:p-8 text-[#1B2522]">
            {/* Glow behind */}
            <div className="absolute -inset-1 rounded-2xl bg-gradient-to-r from-ember/5 via-transparent to-ember/5 blur-2xl pointer-events-none" />

            <div className="relative grid grid-cols-3 gap-4 sm:gap-8 text-center">
              <div>
                <span className="font-display text-2xl sm:text-3xl font-bold text-[#004D54]">30–40%</span>
                <p className="font-sans text-[11px] sm:text-xs text-[#4E5A55]/85 mt-1">
                  {isPl ? "mniej utraconych informacji" : "less information lost"}
                </p>
              </div>
              <div className="border-x border-[#E2DED5]/60">
                <span className="font-display text-2xl sm:text-3xl font-bold text-[#004D54]">3 min</span>
                <p className="font-sans text-[11px] sm:text-xs text-[#4E5A55]/85 mt-1">
                  {isPl ? "zamiast godziny notatek" : "instead of an hour of notes"}
                </p>
              </div>
              <div>
                <span className="font-display text-2xl sm:text-3xl font-bold text-[#004D54]">100%</span>
                <p className="font-sans text-[11px] sm:text-xs text-[#4E5A55]/85 mt-1">
                  {isPl ? "ciągłość między sesjami" : "continuity between sessions"}
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* ── Quote ────────────────────────────────────────────── */}
        <div className={`mt-12 text-center max-w-xl mx-auto transition-all duration-700 delay-[800ms] ${isVisible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"}`}>
          <p className="font-serif text-base sm:text-lg text-[#4E5A55]/95 italic leading-relaxed">
            &ldquo;{t("quote")}&rdquo;
          </p>
          <footer className="mt-3 font-sans text-xs uppercase tracking-wider text-[#004D54] font-semibold">
            {t("cite")}
          </footer>
        </div>
      </div>
    </section>
  );
}
