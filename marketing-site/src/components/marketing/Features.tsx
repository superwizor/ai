// Features grid. Six cards laid out on a 1/2/3 responsive grid:
// transcription, report, supervision pointers, RODO, org mode, platforms.

import { useTranslations } from "next-intl";

const featureKeys = [
  "transcript",
  "report",
  "supervisor",
  "rodo",
  "team",
  "supports",
] as const;

export function Features() {
  const t = useTranslations("features");
  const tItem = useTranslations("features.items");

  return (
    <section className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8 py-20 sm:py-24">
      <p className="font-mono text-[10px] sm:text-xs uppercase text-mist tracking-[var(--tracking-overline)] mb-3 text-center">
        {t("overline")}
      </p>
      <h2 className="font-display text-frost text-center text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] max-w-2xl mx-auto leading-tight">
        {t("heading")}
      </h2>

      <div className="mt-12 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
        {featureKeys.map((k) => (
          <div
            key={k}
            className="rounded-card bg-frost/[0.04] border border-frost/10 p-6 hover:bg-frost/[0.06] hover:border-frost/20 transition"
          >
            <h3 className="font-display text-frost text-lg sm:text-xl font-semibold">
              {tItem(`${k}.title`)}
            </h3>
            <p className="font-serif text-mist text-sm leading-relaxed mt-2">
              {tItem(`${k}.body`)}
            </p>
          </div>
        ))}
      </div>
    </section>
  );
}
