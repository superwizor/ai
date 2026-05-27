// Scaffold placeholder for the public landing page (i18n-aware).
//
// Pulls every string from messages/{locale}.json via useTranslations.
// The Polish locale ships at `/`, English at `/en`. Full landing
// composition lands in Slice 2 feature 5 (`landing-page`); this is the
// minimal proof that i18n is wired correctly across the brand-token
// pipeline.

import { setRequestLocale, getTranslations } from "next-intl/server";

export default async function Home({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("scaffold");

  return (
    <main className="flex flex-1 flex-col items-center justify-center px-4 sm:px-6 py-16 sm:py-24 w-full overflow-x-hidden">
      <p className="font-mono text-[10px] sm:text-xs uppercase text-mist tracking-[var(--tracking-overline)] mb-4 sm:mb-6 text-center">
        {t("overline")}
      </p>

      <h1 className="font-display text-frost text-center text-3xl sm:text-5xl md:text-6xl font-semibold tracking-[var(--tracking-display)] max-w-full sm:max-w-2xl leading-tight px-2 break-words">
        {t("headingPrefix")} <span className="text-ember">{t("headingAccent")}</span>
        {t("headingPunctuation")}
      </h1>

      <p className="font-serif text-mist text-center mt-4 sm:mt-6 max-w-full sm:max-w-xl text-base sm:text-lg leading-relaxed px-2">
        {t("subhead")}
      </p>

      <div className="mt-8 sm:mt-10 flex flex-col sm:flex-row gap-3 sm:gap-4 w-full sm:w-auto px-4 sm:px-0">
        <a
          href="/register/therapist"
          className="inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition"
        >
          {t("ctaPrimary")}
        </a>
        <a
          href="/pricing"
          className="inline-flex items-center justify-center rounded-button border border-frost/20 text-frost font-display text-sm px-6 py-3 hover:bg-frost/5 transition"
        >
          {t("ctaSecondary")}
        </a>
      </div>

      <p
        className="mt-12 sm:mt-16 font-mono text-[9px] sm:text-[10px] text-mist/60 tracking-[var(--tracking-overline)] uppercase text-center px-4"
        data-testid="brand-token-marker"
      >
        {t("tokensMarker")}
      </p>
    </main>
  );
}
