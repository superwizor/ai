"use client";

import { useTranslations } from "next-intl";

export function BrandStatement() {
  const t = useTranslations("b.brandStatement");

  return (
    <section className="relative w-full bg-[#FBFAF7] text-[#1B2522] py-18 sm:py-24 border-y border-[#E2DED5]/60 overflow-hidden">
      {/* Background Image - higher visibility with radial mask to fade in the center */}
      <div className="absolute inset-0 w-full h-full z-0 pointer-events-none select-none">
        <img
          src="/assets/brand_statement_bg.webp"
          alt=""
          className="w-full h-full object-cover filter grayscale opacity-[0.28] contrast-[1.08] brightness-[0.98]"
        />
        {/* Radial gradient overlay that fades the image to solid section background in the center for max readability */}
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,#FBFAF7_20%,transparent_75%)]" />
      </div>

      <div className="relative mx-auto w-full max-w-[760px] px-6 text-center z-10">
        <div className="flex items-center justify-center gap-4 mb-6">
          <span className="flex-1 max-w-[60px] h-px bg-gradient-to-r from-transparent to-[#2f6b62]/30" />
          <span className="w-2 h-2 rounded-full bg-[#2f6b62]/40" />
          <span className="flex-1 max-w-[60px] h-px bg-gradient-to-l from-transparent to-[#2f6b62]/30" />
        </div>
        <p className="font-serif text-xl sm:text-2xl md:text-[1.6rem] text-[#1B2522]/90 leading-relaxed tracking-tight">
          {t.rich("body", {
            highlight: (chunks) => (
              <span className="text-[#004D54] font-bold italic underline decoration-ember/40 decoration-2 underline-offset-4">
                {chunks}
              </span>
            )
          })}
        </p>
      </div>
    </section>
  );
}
