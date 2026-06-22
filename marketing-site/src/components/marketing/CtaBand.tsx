"use client";

import { useTranslations, useLocale } from "next-intl";

export function CtaBand() {
  const t = useTranslations("cta");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  return (
    <section className="relative w-full bg-[#001114] text-frost py-32 sm:py-40 lg:py-48 overflow-hidden">
      {/* Inline keyframes for this section only */}
      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes breathe {
          0%, 100% { transform: scale(1); opacity: 0.18; }
          50% { transform: scale(1.08); opacity: 0.32; }
        }
        @keyframes breathe-delayed {
          0%, 100% { transform: scale(1); opacity: 0.12; }
          50% { transform: scale(1.06); opacity: 0.22; }
        }
        @keyframes ripple-1 {
          0% { transform: scale(0.8); opacity: 0.15; }
          100% { transform: scale(2.5); opacity: 0; }
        }
        @keyframes ripple-2 {
          0% { transform: scale(0.8); opacity: 0.12; }
          100% { transform: scale(2.2); opacity: 0; }
        }
        @keyframes ripple-3 {
          0% { transform: scale(0.8); opacity: 0.09; }
          100% { transform: scale(1.9); opacity: 0; }
        }
        @keyframes fade-up-in {
          from { opacity: 0; transform: translateY(24px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @keyframes horizon-glow {
          0%, 100% { opacity: 0.4; }
          50% { opacity: 0.7; }
        }
        .cta-breathe-ring {
          animation: breathe 6s ease-in-out infinite;
        }
        .cta-breathe-ring-2 {
          animation: breathe-delayed 6s ease-in-out infinite 1.5s;
        }
        .cta-ripple-1 {
          animation: ripple-1 8s ease-out infinite;
        }
        .cta-ripple-2 {
          animation: ripple-2 8s ease-out infinite 2.5s;
        }
        .cta-ripple-3 {
          animation: ripple-3 8s ease-out infinite 5s;
        }
        .cta-fade-in-1 { animation: fade-up-in 1s ease-out 0.2s both; }
        .cta-fade-in-2 { animation: fade-up-in 1s ease-out 0.5s both; }
        .cta-fade-in-3 { animation: fade-up-in 1s ease-out 0.8s both; }
        .cta-fade-in-4 { animation: fade-up-in 1s ease-out 1.1s both; }
        .cta-horizon {
          animation: horizon-glow 6s ease-in-out infinite 3s;
        }
      `}} />

      {/* Deep space background texture — very subtle radial lines */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_80%_50%_at_50%_50%,rgba(0,77,84,0.08),transparent_70%)] pointer-events-none" />

      {/* Water ripple circles — emanating from center */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 pointer-events-none">
        <div className="cta-ripple-1 absolute -inset-0 w-[300px] h-[300px] sm:w-[400px] sm:h-[400px] rounded-full border border-frost/[0.06]" style={{ marginLeft: '-150px', marginTop: '-150px' }} />
        <div className="cta-ripple-2 absolute -inset-0 w-[300px] h-[300px] sm:w-[400px] sm:h-[400px] rounded-full border border-frost/[0.05]" style={{ marginLeft: '-150px', marginTop: '-150px' }} />
        <div className="cta-ripple-3 absolute -inset-0 w-[300px] h-[300px] sm:w-[400px] sm:h-[400px] rounded-full border border-frost/[0.04]" style={{ marginLeft: '-150px', marginTop: '-150px' }} />
      </div>

      {/* Breathing meditation ring — outer */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 pointer-events-none">
        <svg className="cta-breathe-ring w-[525px] h-[525px] sm:w-[700px] sm:h-[700px] lg:w-[850px] lg:h-[850px]" viewBox="0 0 200 200" fill="none">
          <circle cx="100" cy="100" r="90" stroke="url(#ring-grad)" strokeWidth="0.8" strokeDasharray="4 6" />
          <circle cx="100" cy="100" r="87" stroke="url(#ring-grad)" strokeWidth="0.4" strokeDasharray="2 4" />
          <defs>
            <linearGradient id="ring-grad" x1="0" y1="0" x2="200" y2="200">
              <stop offset="0%" stopColor="#FCAE2F" stopOpacity="0.5" />
              <stop offset="50%" stopColor="#FAFAFA" stopOpacity="0.2" />
              <stop offset="100%" stopColor="#6759FF" stopOpacity="0.4" />
            </linearGradient>
          </defs>
        </svg>
      </div>

      {/* Breathing meditation ring — inner */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 pointer-events-none">
        <svg className="cta-breathe-ring-2 w-[400px] h-[400px] sm:w-[550px] sm:h-[550px] lg:w-[675px] lg:h-[675px]" viewBox="0 0 200 200" fill="none">
          <circle cx="100" cy="100" r="85" stroke="url(#ring-grad-2)" strokeWidth="0.6" strokeDasharray="2 8" />
          <circle cx="100" cy="100" r="82" stroke="url(#ring-grad-2)" strokeWidth="0.3" strokeDasharray="3 5" />
          <defs>
            <linearGradient id="ring-grad-2" x1="200" y1="0" x2="0" y2="200">
              <stop offset="0%" stopColor="#B2CACC" stopOpacity="0.35" />
              <stop offset="100%" stopColor="#FCAE2F" stopOpacity="0.2" />
            </linearGradient>
          </defs>
        </svg>
      </div>

      {/* Horizon glow — warm ember sunrise at bottom */}
      <div className="cta-horizon absolute bottom-0 left-1/2 -translate-x-1/2 w-[120%] max-w-[1400px] h-[180px] bg-[radial-gradient(ellipse_at_center,rgba(252,174,47,0.08),rgba(252,174,47,0.03)_40%,transparent_70%)] pointer-events-none rounded-full" />

      {/* Very subtle top-edge frost line */}
      <div className="absolute top-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-frost/[0.06] to-transparent" />

      {/* Content */}
      <div className="relative mx-auto w-full max-w-[1080px] px-6 text-center flex flex-col items-center z-10">
        {/* Mindfulness overline */}
        <div className="cta-fade-in-1 inline-flex items-center gap-3 mb-8">
          <span className="w-8 h-px bg-gradient-to-r from-transparent to-ember/40" />
          <span className="font-mono text-[10px] sm:text-[11px] uppercase tracking-[3px] text-ember/70 font-medium">
            {t("overline")}
          </span>
          <span className="w-8 h-px bg-gradient-to-l from-transparent to-ember/40" />
        </div>

        {/* Heading with gradient text */}
        <h2 className="cta-fade-in-2 font-display text-3xl sm:text-4xl md:text-5xl lg:text-[3.5rem] font-bold tracking-tight leading-[1.15] max-w-3xl bg-gradient-to-b from-frost via-frost to-mist/70 bg-clip-text text-transparent">
          {t("heading")}
        </h2>

        {/* Body text */}
        <p className="cta-fade-in-2 font-serif text-mist/80 text-base sm:text-lg leading-relaxed mt-5 max-w-xl mx-auto">
          {t("body")}
        </p>

        {/* CTA buttons */}
        <div className="cta-fade-in-3 mt-10 flex flex-col items-center gap-4">
          <div className="flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center w-full sm:w-auto">
            {/* Primary CTA — glowing ember button */}
            <a
              href="#cennik"
              className="group relative inline-flex items-center justify-center rounded-[5px] bg-gradient-to-r from-[#FCAE2F] to-[#F97316] text-obsidian font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 transition-all duration-300 active:scale-[0.97] w-full sm:w-auto whitespace-nowrap overflow-hidden"
            >
              {/* Glow behind button */}
              <span className="absolute inset-0 rounded-[5px] bg-gradient-to-r from-[#FCAE2F]/40 to-[#F97316]/40 blur-xl group-hover:blur-2xl transition-all duration-500 -z-10 scale-110" />
              <span className="relative z-10 flex items-center gap-2">
                {t("primary")}
                <span className="transition-transform duration-300 group-hover:translate-x-1">→</span>
              </span>
            </a>

            {/* Secondary CTA — glass button */}
            <a
              href="#cennik"
              className="inline-flex items-center justify-center rounded-[5px] border border-frost/15 text-frost/90 font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 hover:bg-frost/[0.04] hover:border-frost/25 transition-all duration-300 active:scale-[0.97] w-full sm:w-auto whitespace-nowrap backdrop-blur-sm"
            >
              {t("secondary")}
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}
