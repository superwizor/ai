// Landing-page hero. Same Euphire-themed composition as the scaffold
// placeholder, expanded with overline + tighter responsive tuning.

import { useTranslations, useLocale } from "next-intl";

export function Hero() {
  const t = useTranslations("hero");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  return (
    <section className="relative flex flex-col items-center justify-center px-4 sm:px-6 lg:px-8 py-20 sm:py-28 lg:py-36">
      <p className="font-mono text-[10px] sm:text-xs uppercase text-mist tracking-[var(--tracking-overline)] mb-4 sm:mb-6 text-center max-w-2xl">
        {t("overline")}
      </p>

      <h1 className="font-display text-frost text-center text-4xl sm:text-6xl md:text-7xl font-semibold tracking-[var(--tracking-display)] max-w-full sm:max-w-3xl leading-[1.1] px-2">
        {t("headingPrefix")}{" "}
        <span className="text-ember">{t("headingAccent")}</span>
        {t("headingPunctuation")}
      </h1>

      <div className="mt-8 sm:mt-10 flex flex-col sm:flex-row gap-3 sm:gap-4 w-full sm:w-auto px-2 sm:px-0">
        <a
          href={`${prefix}/register/therapist`}
          className="inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition"
        >
          {t("ctaPrimary")}
        </a>
        <a
          href="#how"
          className="inline-flex items-center justify-center rounded-button border border-frost/20 text-frost font-display text-sm px-6 py-3 hover:bg-frost/5 transition"
        >
          {t("ctaSecondary")}
        </a>
      </div>

      <p className="font-serif text-mist text-center mt-8 sm:mt-10 max-w-full sm:max-w-xl text-base sm:text-lg leading-relaxed px-2">
        {t("subhead")}
      </p>
    </section>
  );
}
