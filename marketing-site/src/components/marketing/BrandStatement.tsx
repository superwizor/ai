"use client";

import { useTranslations } from "next-intl";

export function BrandStatement() {
  const t = useTranslations("b.brandStatement");
  const tHero = useTranslations("hero");

  return (
    <section className="relative w-full bg-gradient-to-b from-[#004D54] to-[#002E32] text-frost py-18 sm:py-24 border-y border-white/[0.04] overflow-hidden">
      {/* Background Image - higher visibility with radial mask to fade in the center */}
      <div className="absolute inset-0 w-full h-full z-0 pointer-events-none select-none">
        <img
          src="/assets/brand_statement_bg.webp"
          alt=""
          className="w-full h-full object-cover filter grayscale opacity-[0.12] contrast-[1.2]"
        />
        {/* Radial gradient overlay that fades the image to solid section background in the center for max readability */}
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,#003d42_15%,transparent_80%)]" />
      </div>

      <div className="relative mx-auto w-full max-w-[760px] px-6 text-center z-10">
        <div className="flex items-center justify-center gap-4 mb-6">
          <span className="flex-1 max-w-[60px] h-px bg-gradient-to-r from-transparent to-ember/30" />
          <span className="w-2 h-2 rounded-full bg-ember/40" />
          <span className="flex-1 max-w-[60px] h-px bg-gradient-to-l from-transparent to-ember/30" />
        </div>
        <p className="font-serif text-xl sm:text-2xl md:text-[1.6rem] text-frost/95 leading-relaxed tracking-tight">
          {t.rich("body", {
            highlight: (chunks) => (
              <span className="text-frost font-bold italic underline decoration-ember/50 decoration-2 underline-offset-4">
                {chunks}
              </span>
            )
          })}
        </p>
        <div className="mt-8 flex justify-center">
          <a
            href="#cennik"
            className="group relative inline-flex items-center justify-center rounded-[12px] bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 transition-all duration-300 hover:brightness-110 active:scale-[0.97] whitespace-nowrap overflow-hidden"
          >
            <span className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-700" />
            <span className="relative">{tHero("ctaPrimary")}</span>
          </a>
        </div>
      </div>
    </section>
  );
}
