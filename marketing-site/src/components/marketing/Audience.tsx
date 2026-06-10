"use client";

import { useTranslations } from "next-intl";

export function Audience() {
  const t = useTranslations("b.audience");
  const tItem = useTranslations("b.audience.items");
  const tHero = useTranslations("hero");

  const personas = [
    {
      key: "therapist" as const,
      num: "01",
      icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5">
          <circle cx="12" cy="7" r="4" />
          <path d="M5.5 21c0-4.1 2.9-7.5 6.5-7.5s6.5 3.4 6.5 7.5" />
        </svg>
      ),
    },
    {
      key: "supervisor" as const,
      num: "02",
      icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5">
          <circle cx="12" cy="5" r="3" />
          <circle cx="6" cy="19" r="2.5" />
          <circle cx="18" cy="19" r="2.5" />
          <line x1="12" y1="8" x2="12" y2="13" />
          <path d="M12 13l-6 3.5M12 13l6 3.5" />
        </svg>
      ),
    },
    {
      key: "clinic" as const,
      num: "03",
      icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5">
          <path d="M12 2v6M9 5h6" />
          <rect x="3" y="8" width="18" height="14" rx="2" />
          <path d="M3 12h18" />
          <rect x="8" y="16" width="3" height="4" rx="0.5" />
          <rect x="13" y="16" width="3" height="4" rx="0.5" />
        </svg>
      ),
    },
  ];

  return (
    <section className="relative w-full bg-[#FBFAF7] text-[#1B2522] py-16 sm:py-20 lg:py-24 overflow-hidden border-y border-[#E2DED5]/60">
      <div className="mx-auto w-full max-w-[1120px] px-6">
        {/* Heading */}
        <div className="text-center mb-14">
          <span className="font-sans text-[10px] uppercase tracking-[3px] text-[#004D54]/50 font-bold mb-3 block">
            {t("heading")}
          </span>
          <div className="w-12 h-px bg-gradient-to-r from-transparent via-[#004D54]/30 to-transparent mx-auto" />
        </div>

        {/* Two-column: image left, personas right */}
        <div className="flex flex-col lg:flex-row gap-8 lg:gap-12 items-stretch">
          {/* LEFT — Rounded image */}
          <div className="w-full lg:w-[42%] shrink-0">
            <div className="relative rounded-[24px] overflow-hidden aspect-[4/5] lg:aspect-auto lg:h-full">
              <img
                src="/assets/therapy-office.webp"
                alt=""
                className="absolute inset-0 w-full h-full object-cover"
                loading="lazy"
              />
              {/* Subtle warm overlay */}
              <div className="absolute inset-0 bg-[#004D54]/[0.06] mix-blend-multiply rounded-[24px]" />
            </div>
          </div>

          {/* RIGHT — Personas */}
          <div className="flex-1 flex flex-col justify-center py-4">
            <div className="space-y-10">
              {personas.map((p) => (
                <div key={p.key} className="group flex items-start gap-5 sm:gap-6">
                  {/* Number + icon */}
                  <div className="flex flex-col items-center gap-2 shrink-0 pt-0.5">
                    <span className="font-sans text-[10px] text-[#004D54]/30 font-bold tracking-wider">{p.num}</span>
                    <div className="w-10 h-10 rounded-full bg-[#004D54]/[0.06] border border-[#004D54]/[0.1] flex items-center justify-center text-[#004D54] group-hover:bg-[#004D54]/[0.12] group-hover:border-[#004D54]/[0.2] transition-all duration-300">
                      {p.icon}
                    </div>
                    {p.key !== "clinic" && (
                      <div className="w-px h-6 bg-gradient-to-b from-[#004D54]/15 to-transparent" />
                    )}
                  </div>
                  {/* Text */}
                  <div className="pt-5">
                    <h3 className="font-display text-[#1B2522] text-lg sm:text-xl font-bold tracking-tight leading-tight mb-1.5">
                      {tItem(`${p.key}.title`)}
                    </h3>
                    <p className="font-sans text-[#4E5A55] text-sm sm:text-base leading-relaxed max-w-md">
                      {tItem(`${p.key}.body`)}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* CTA Button */}
        <div className="mt-16 flex flex-col items-center">
          <a
            href="#cennik"
            className="group relative inline-flex items-center justify-center rounded-[12px] bg-[#004D54] text-frost font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 transition-all duration-300 hover:bg-[#002E32] active:scale-[0.97] whitespace-nowrap overflow-hidden"
          >
            <span className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-700" />
            <span className="relative">
              {tHero("ctaPrimary")}
            </span>
          </a>
        </div>

      </div>
    </section>
  );
}
