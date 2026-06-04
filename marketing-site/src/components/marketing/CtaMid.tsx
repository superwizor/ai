"use client";

import { useTranslations, useLocale } from "next-intl";

export function CtaMid() {
  const t = useTranslations("b.ctamid");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  return (
    <section className="relative w-full bg-gradient-to-b from-[#002E32] to-[#001A1D] text-frost py-20 sm:py-24 overflow-hidden border-y border-frost/5">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_50%_50%_at_50%_50%,rgba(252,174,47,0.05),transparent)] pointer-events-none" />
      <div className="relative mx-auto w-full max-w-[760px] px-6 text-center">
        <h2 className="font-display text-2xl sm:text-3xl md:text-4xl font-bold tracking-tight leading-tight text-frost mb-4">
          {t("title")}
        </h2>
        <p className="font-sans text-base sm:text-lg text-frost/50 leading-relaxed max-w-xl mx-auto mb-8">
          {t("body")}
        </p>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
          <a
            href={`${prefix}/register/therapist`}
            className="group relative inline-flex items-center justify-center rounded-[12px] bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 transition-all duration-300 active:scale-[0.97] whitespace-nowrap overflow-hidden"
          >
            <span className="absolute inset-0 rounded-[12px] bg-ember/40 blur-xl group-hover:blur-2xl transition-all duration-500 -z-10 scale-110" />
            <span className="relative z-10">{t("cta")}</span>
            <span className="relative z-10 ml-2">→</span>
          </a>
          <a
            href="#cennik"
            className="inline-flex items-center justify-center rounded-[12px] border border-frost/15 text-frost/70 font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 hover:bg-frost/5 hover:border-frost/25 transition-all duration-300 active:scale-[0.97] whitespace-nowrap"
          >
            {t("cta2")}
          </a>
        </div>

        <p className="mt-4 font-sans text-[11px] uppercase text-frost/30 tracking-[2px]">
          {t("micro")}
        </p>
      </div>
    </section>
  );
}
