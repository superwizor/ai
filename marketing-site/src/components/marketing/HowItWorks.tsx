"use client";

import { useTranslations, useLocale } from "next-intl";
import { useState, useEffect, useRef } from "react";

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

  const containerRef = useRef<HTMLDivElement>(null);
  const [maxProgress, setMaxProgress] = useState(0);

  useEffect(() => {
    const handleScroll = () => {
      const container = containerRef.current;
      if (!container) return;

      const rect = container.getBoundingClientRect();
      const windowHeight = window.innerHeight;

      // The eye-level trigger point: 60% of the viewport height
      const triggerPoint = windowHeight * 0.60;

      // Calculate progress of the timeline connector line
      const containerTop = rect.top;
      const containerHeight = rect.height;

      const scrolledDistance = triggerPoint - containerTop;
      let pct = (scrolledDistance / containerHeight) * 100;
      pct = Math.max(0, Math.min(100, pct));

      // Lock progress to go forward only (one-way progress)
      setMaxProgress((prevMax) => Math.max(prevMax, pct));
    };

    window.addEventListener("scroll", handleScroll, { passive: true });
    window.addEventListener("resize", handleScroll);
    handleScroll();

    return () => {
      window.removeEventListener("scroll", handleScroll);
      window.removeEventListener("resize", handleScroll);
    };
  }, []);

  // Sync step activation strictly with the progress line reaching the circle nodes
  const activeSteps = [
    maxProgress >= 2,      // Step 1: Top of timeline
    maxProgress >= 50,     // Step 2: Middle of timeline
    maxProgress >= 95,     // Step 3: Bottom of timeline
  ];

  return (
    <section id="jak" className="w-full bg-gradient-to-b from-[#FBFAF7] to-[#F2F0EA] text-[#1B2522] py-24 sm:py-32 border-y border-[#E2DED5]/60 relative overflow-hidden">
      {/* Dynamic Senior UI animations injected locally */}
       <style dangerouslySetInnerHTML={{ __html: `
        @keyframes popCircle {
          0% {
            scale: 0.95;
            box-shadow: 0 0 0 0 rgba(252, 174, 47, 0);
          }
          100% {
            scale: 1.12;
            box-shadow: 0 0 18px 4px rgba(252, 174, 47, 0.4);
          }
        }
        @keyframes rippleOuter {
          0% {
            scale: 0.9;
            opacity: 0.87;
          }
          100% {
            scale: 2.9;
            opacity: 0;
          }
        }
        .animate-pop-circle {
          animation: popCircle 1.1s cubic-bezier(0.25, 1, 0.5, 1) forwards;
        }
        .animate-ripple-1 {
          animation: rippleOuter 1.9s cubic-bezier(0.1, 0.8, 0.3, 1) forwards;
          filter: blur(1.0px);
        }
        .animate-ripple-2 {
          animation: rippleOuter 2.4s cubic-bezier(0.1, 0.8, 0.3, 1) 0.4s forwards;
          filter: blur(2.0px);
        }
      `}} />

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
        <div ref={containerRef} className="relative">
          {/* Vertical connector line — visible on lg only */}
          <div className="hidden lg:block absolute left-1/2 top-8 bottom-8 w-[2px] -translate-x-1/2 bg-[#004D54]/10">
            {/* Dynamic progress fill (Thicker, brand-colored green line) */}
            <div 
              className="absolute top-0 left-0 w-[4px] -translate-x-[1px] bg-[#004D54] rounded-full transition-all duration-300 ease-out" 
              style={{ height: `${maxProgress}%` }}
            />
          </div>

          <div className="space-y-20 sm:space-y-28">
            {stepKeys.map((k, i) => {
              const isReversed = i % 2 !== 0;
              const stepNum = tStep(`${k}.tag`);

              return (
                <div 
                  key={k} 
                  className="relative grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-16 items-center"
                >
                  {/* Step number node on the timeline — lg only */}
                  <div 
                    className={`hidden lg:flex absolute left-1/2 -translate-x-1/2 w-12 h-12 rounded-full items-center justify-center z-20 border-4 transition-all duration-500 ${
                      activeSteps[i]
                        ? "bg-[#ffb12c] border-[#FBFAF7] text-[#06383e] animate-pop-circle"
                        : "bg-[#004D54] border-[#FBFAF7] text-frost shadow-md"
                    }`}
                  >
                    <span className="font-display text-sm font-bold">{stepNum}</span>
                    {activeSteps[i] && (
                      <>
                        <span className="absolute -inset-1.5 rounded-full border-2 border-[#ffb12c]/55 animate-ripple-1 pointer-events-none" />
                        <span className="absolute -inset-3 rounded-full border-[3px] border-[#ffb12c]/25 animate-ripple-2 pointer-events-none" />
                      </>
                    )}
                  </div>

                  {/* Text side */}
                  <div className={`lg:col-span-5 flex flex-col items-start text-left ${isReversed ? "order-1 lg:order-2 lg:col-start-8 lg:pl-4" : "order-1 lg:order-1 lg:pr-4"}`}>
                    {/* Mobile step indicator */}
                    <div className="lg:hidden flex items-center gap-3 mb-4">
                      <span 
                        className={`w-9 h-9 rounded-full flex items-center justify-center relative border-2 transition-all duration-500 ${
                          activeSteps[i]
                            ? "bg-[#ffb12c] border-[#FBFAF7] text-[#06383e] animate-pop-circle"
                            : "bg-[#004D54] border-[#FBFAF7] text-frost shadow-sm"
                        }`}
                      >
                        <span className="font-display text-xs font-bold">{stepNum}</span>
                        {activeSteps[i] && (
                          <>
                            <span className="absolute -inset-1 rounded-full border-2 border-[#ffb12c]/55 animate-ripple-1 pointer-events-none" />
                            <span className="absolute -inset-2.5 rounded-full border-[3px] border-[#ffb12c]/25 animate-ripple-2 pointer-events-none" />
                          </>
                        )}
                      </span>
                      <span className="font-mono text-[10px] uppercase tracking-[2px] text-[#004D54]/60 font-semibold">
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
                  <div className={`lg:col-span-5 flex justify-center relative ${isReversed ? "order-2 lg:order-1 lg:col-start-1" : "order-2 lg:order-2 lg:col-start-8"}`}>
                    <div className="relative group max-w-[320px] w-full">
                      {/* Glow behind */}
                      <div className="absolute -inset-4 rounded-[32px] bg-[#004D54]/5 blur-xl group-hover:bg-[#004D54]/8 transition-all duration-500" />
                      <div className="relative rounded-[24px] border border-[#E2DED5] bg-gradient-to-b from-[#004D54] to-[#002E32] shadow-xl overflow-hidden select-none transition-transform duration-300 group-hover:scale-[1.02]">
                        <img
                          src={stepImages[i]}
                          alt={tStep(`${k}.title`)}
                          loading="lazy"
                          width={640}
                          height={480}
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
