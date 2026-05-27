// Bottom-of-page CTA band. High-contrast Ember surface to drive
// signups after the user has read down the page.

import { useTranslations, useLocale } from "next-intl";

export function CtaBand() {
  const t = useTranslations("cta");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  return (
    <section className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8 py-20 sm:py-24">
      <div className="rounded-glass overflow-hidden border border-ember/40 bg-gradient-to-br from-ember/15 via-frost/[0.04] to-aurora/10 p-8 sm:p-14 text-center">
        <h2 className="font-display text-frost text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] max-w-xl mx-auto leading-tight">
          {t("heading")}
        </h2>
        <p className="font-serif text-mist text-base sm:text-lg leading-relaxed mt-4 max-w-xl mx-auto">
          {t("body")}
        </p>
        <div className="mt-8 flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center">
          <a
            href={`${prefix}/register/therapist`}
            className="inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition"
          >
            {t("primary")}
          </a>
          <a
            href={`${prefix}/pricing`}
            className="inline-flex items-center justify-center rounded-button border border-frost/20 text-frost font-display text-sm px-6 py-3 hover:bg-frost/5 transition"
          >
            {t("secondary")}
          </a>
        </div>
      </div>
    </section>
  );
}
