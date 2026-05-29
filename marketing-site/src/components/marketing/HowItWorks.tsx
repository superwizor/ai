// "How it works" — three sequential cards walking through Record →
// AI → Report. Each card has a Roboto-Mono numbered tag (the same
// overline/label treatment used across the app) so the section reads
// as a process, not a feature list.

import { useTranslations } from "next-intl";

const stepKeys = ["record", "process", "report"] as const;

export function HowItWorks() {
  const t = useTranslations("how");
  const tStep = useTranslations("how.steps");

  return (
    <section id="how" className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8 py-20 sm:py-24">
      <p className="font-mono text-[10px] sm:text-xs uppercase text-mist tracking-[var(--tracking-overline)] mb-3 text-center">
        {t("overline")}
      </p>
      <h2 className="font-display text-frost text-center text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] max-w-2xl mx-auto leading-tight">
        {t("heading")}
      </h2>

      <ol className="mt-12 grid grid-cols-1 md:grid-cols-3 gap-4 sm:gap-6">
        {stepKeys.map((k) => (
          <li
            key={k}
            className="relative rounded-card bg-frost/5 border border-frost/10 p-6 sm:p-8 hover:border-ember/30 transition"
          >
            <span className="font-mono text-xs uppercase tracking-[var(--tracking-label)] text-ember">
              {tStep(`${k}.tag`)}
            </span>
            <h3 className="font-display text-frost text-xl sm:text-2xl font-semibold mt-3">
              {tStep(`${k}.title`)}
            </h3>
            <p className="font-serif text-mist text-sm sm:text-base leading-relaxed mt-3">
              {tStep(`${k}.body`)}
            </p>
          </li>
        ))}
      </ol>
    </section>
  );
}
