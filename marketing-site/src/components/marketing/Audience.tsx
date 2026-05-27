// "Who it's for" — three cards covering individual therapists,
// supervisors, and clinics. Slightly different visual weight from the
// Features grid (glass surface with Aurora accent on the badge) so the
// page rhythm doesn't feel like one long list of the same card.

import { useTranslations } from "next-intl";

const audienceKeys = ["therapist", "supervisor", "clinic"] as const;

export function Audience() {
  const t = useTranslations("audience");
  const tItem = useTranslations("audience.items");

  return (
    <section className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8 py-20 sm:py-24">
      <p className="font-mono text-[10px] sm:text-xs uppercase text-aurora tracking-[var(--tracking-overline)] mb-3 text-center">
        {t("overline")}
      </p>
      <h2 className="font-display text-frost text-center text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] max-w-2xl mx-auto leading-tight">
        {t("heading")}
      </h2>

      <div className="mt-12 grid grid-cols-1 md:grid-cols-3 gap-4 sm:gap-6">
        {audienceKeys.map((k) => (
          <div
            key={k}
            className="rounded-glass bg-gradient-to-b from-frost/[0.06] to-frost/[0.02] border border-glass-border/40 p-6 sm:p-8"
          >
            <h3 className="font-display text-frost text-xl font-semibold">
              {tItem(`${k}.title`)}
            </h3>
            <p className="font-serif text-mist text-sm leading-relaxed mt-3">
              {tItem(`${k}.body`)}
            </p>
          </div>
        ))}
      </div>
    </section>
  );
}
