"use client";

import { useTranslations, useLocale } from "next-intl";

const stepKeys = ["record", "process", "report"] as const;
const stepImages = [
  "/assets/mockup_record_green_real.webp",
  "/assets/mockup_status_green_real.webp",
  "/assets/mockup_transcript_green_real.webp",
];

export function HowItWorks() {
  const t = useTranslations("b.how");
  const tStep = useTranslations("b.how.steps");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  return (
    <section id="jak" className="w-full bg-gradient-to-b from-[#FBFAF7] to-[#F2F0EA] text-[#1B2522] py-24 sm:py-32 border-y border-[#E2DED5]/60 relative overflow-hidden">
      <div className="mx-auto w-full max-w-[1080px] px-6 relative z-10">
        <div className="text-center mb-20">
          <p className="font-mono text-[10px] sm:text-xs uppercase text-[#004D54] tracking-[var(--tracking-overline)] mb-3 font-semibold">
            {t("overline")}
          </p>
          <h2 className="font-display text-[#004D54] text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight max-w-2xl mx-auto leading-tight">
            {t("heading")}
          </h2>
        </div>

        {/* Timeline container */}
        <div className="relative">
          {/* Vertical connector line — visible on lg only */}
          <div className="hidden lg:block absolute left-1/2 top-8 bottom-8 w-px -translate-x-1/2">
            <div className="w-full h-full bg-gradient-to-b from-[#004D54]/10 via-[#004D54]/20 to-[#004D54]/10" />
          </div>

          <div className="space-y-20 sm:space-y-28">
            {stepKeys.map((k, i) => {
              const isReversed = i % 2 !== 0;
              const stepNum = tStep(`${k}.tag`);

              return (
                <div key={k} className="relative grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-16 items-center">
                  {/* Step number node on the timeline — lg only */}
                  <div className="hidden lg:flex absolute left-1/2 -translate-x-1/2 w-12 h-12 rounded-full bg-[#004D54] border-4 border-[#FBFAF7] shadow-lg items-center justify-center z-20">
                    <span className="font-display text-frost text-sm font-bold">{stepNum}</span>
                  </div>

                  {/* Text side */}
                  <div className={`lg:col-span-5 flex flex-col items-start text-left ${isReversed ? "order-2 lg:order-2 lg:col-start-8 lg:pl-4" : "lg:pr-4"}`}>
                    {/* Mobile step indicator */}
                    <div className="lg:hidden flex items-center gap-3 mb-4">
                      <span className="w-9 h-9 rounded-full bg-[#004D54] flex items-center justify-center">
                        <span className="font-display text-frost text-xs font-bold">{stepNum}</span>
                      </span>
                      <span className="font-mono text-[10px] uppercase tracking-[2px] text-[#004D54]/50 font-semibold">
                        {locale === "en" ? "Step" : "Krok"} {stepNum}
                      </span>
                    </div>

                    <h3 className="font-display text-[#004D54] text-2xl sm:text-3xl font-semibold tracking-tight leading-snug">
                      {tStep(`${k}.title`)}
                    </h3>
                    <p className="font-serif text-[#4E5A55] text-base leading-relaxed mt-3">
                      {tStep(`${k}.body`)}
                    </p>
                  </div>

                  {/* Image side */}
                  <div className={`lg:col-span-5 flex justify-center relative ${isReversed ? "order-1 lg:order-1 lg:col-start-1" : "lg:col-start-8"}`}>
                    <div className="relative group max-w-[320px] w-full">
                      {/* Glow behind */}
                      <div className="absolute -inset-4 rounded-[32px] bg-[#004D54]/5 blur-xl group-hover:bg-[#004D54]/8 transition-all duration-500" />
                      <div className="relative rounded-[24px] border border-[#E2DED5] bg-gradient-to-b from-[#004D54] to-[#002E32] shadow-xl overflow-hidden select-none transition-transform duration-300 group-hover:scale-[1.02]">
                        <img
                          src={stepImages[i]}
                          alt={tStep(`${k}.title`)}
                          loading="lazy"
                          className="w-full h-auto object-cover"
                        />
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* CTA */}
        <div className="mt-20 flex flex-col items-center">
          <a
            href={`${prefix}/register/therapist`}
            className="group relative inline-flex items-center justify-center rounded-[12px] bg-[#004D54] text-frost font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 transition-all duration-300 hover:bg-[#002E32] active:scale-[0.97] whitespace-nowrap overflow-hidden"
          >
            <span className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-700" />
            <span className="relative">{t("cta")}</span>
          </a>
          <span className="mt-3 font-mono text-[10px] uppercase text-[#4E5A55] tracking-[2px]">
            {t("micro")}
          </span>
        </div>
      </div>
    </section>
  );
}
