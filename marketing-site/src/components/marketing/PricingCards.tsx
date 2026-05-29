// Pricing cards with monthly/annual toggle.
//
// Client component (needs useState for the cycle toggle). Reads the
// plan catalog passed in by the server-rendered /pricing page. Each
// card resolves its current row from (tier, activeCycle) — Trial is
// always shown regardless of toggle.
//
// Feature copy comes from messages/{locale}.json. The card composition
// is shared visual language with the rest of the marketing surface:
// frost/05 surface, glass borders, Ember accent for the "popular" badge
// + primary CTA.

"use client";

import { useState } from "react";
import { useTranslations, useLocale } from "next-intl";

import type { BillingCycle, PlanRow } from "@/lib/billing/plans";
import { findPlan, formatPrice } from "@/lib/billing/plans";

type Tier = "trial" | "solo" | "pro" | "clinic";

export function PricingCards({ catalog }: { catalog: ReadonlyArray<PlanRow> }) {
  const [cycle, setCycle] = useState<BillingCycle>("MONTHLY");
  const t = useTranslations("pricing");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  return (
    <>
      <CycleToggle cycle={cycle} onChange={setCycle} />

      <div className="mt-10 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
        <TrialCard registerHref={`${prefix}/register/therapist`} />
        <PaidCard
          tier="solo"
          row={findPlan(catalog, "SOLO", cycle)!}
          cycle={cycle}
          locale={locale}
          registerHref={`${prefix}/register/therapist`}
        />
        <PaidCard
          tier="pro"
          row={findPlan(catalog, "PRO", cycle)!}
          cycle={cycle}
          locale={locale}
          registerHref={`${prefix}/register/therapist`}
          badge={t("tiers.pro.badge")}
        />
        <PaidCard
          tier="clinic"
          row={findPlan(catalog, "CLINIC", cycle)!}
          cycle={cycle}
          locale={locale}
          registerHref={`${prefix}/register/organization`}
        />
      </div>

      <p className="mt-10 text-center font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/70">
        {t("vatNote")}
      </p>
      <p className="mt-2 text-center font-serif text-sm text-mist/70 max-w-2xl mx-auto">
        {t("footnote")}
      </p>
    </>
  );
}

function CycleToggle({
  cycle,
  onChange,
}: {
  cycle: BillingCycle;
  onChange: (c: BillingCycle) => void;
}) {
  const t = useTranslations("pricing.cycle");

  const baseBtn =
    "px-4 sm:px-6 py-2 rounded-button font-mono uppercase tracking-[var(--tracking-label)] text-xs sm:text-sm transition";
  const activeCls = "bg-ember text-obsidian shadow-[var(--shadow-ember-glow)]";
  const inactiveCls = "text-mist hover:text-frost";

  return (
    <div className="flex items-center justify-center gap-3">
      <div
        role="tablist"
        aria-label="billing cycle"
        className="inline-flex items-center rounded-button border border-frost/15 bg-frost/5 p-1"
      >
        <button
          role="tab"
          aria-selected={cycle === "MONTHLY"}
          onClick={() => onChange("MONTHLY")}
          className={`${baseBtn} ${cycle === "MONTHLY" ? activeCls : inactiveCls}`}
        >
          {t("monthly")}
        </button>
        <button
          role="tab"
          aria-selected={cycle === "ANNUAL"}
          onClick={() => onChange("ANNUAL")}
          className={`${baseBtn} ${cycle === "ANNUAL" ? activeCls : inactiveCls}`}
        >
          {t("annual")}
        </button>
      </div>
      <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember">
        {t("annualNote")}
      </span>
    </div>
  );
}

function TrialCard({ registerHref }: { registerHref: string }) {
  const tt = useTranslations("pricing.tiers.trial");
  const t = useTranslations("pricing");

  const features = tt.raw("features") as string[];

  return (
    <article className="flex flex-col rounded-card bg-frost/[0.04] border border-frost/10 p-6 sm:p-7">
      <header>
        <h3 className="font-display text-frost text-xl font-semibold">
          {tt("name")}
        </h3>
        <p className="font-serif text-mist text-sm mt-1">{tt("tagline")}</p>
      </header>

      <div className="mt-6">
        <span className="font-display text-frost text-4xl font-semibold">
          {t("free")}
        </span>
      </div>
      <p className="font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist mt-2">
        3 {tt("tokensSuffix")}
      </p>

      <ul className="mt-6 space-y-2 flex-1">
        {features.map((f, i) => (
          <FeatureLine key={i}>{f}</FeatureLine>
        ))}
      </ul>

      <a
        href={registerHref}
        className="mt-6 inline-flex items-center justify-center rounded-button border border-frost/20 text-frost font-display text-sm px-4 py-3 hover:bg-frost/5 transition"
      >
        {tt("cta")}
      </a>
    </article>
  );
}

function PaidCard({
  tier,
  row,
  cycle,
  locale,
  registerHref,
  badge,
}: {
  tier: Tier;
  row: PlanRow;
  cycle: BillingCycle;
  locale: string;
  registerHref: string;
  badge?: string;
}) {
  const tt = useTranslations(`pricing.tiers.${tier}`);
  const t = useTranslations("pricing");
  const features = tt.raw("features") as string[];

  const isHighlighted = !!badge;
  const surface = isHighlighted
    ? "bg-frost/[0.07] border border-ember/40 shadow-[var(--shadow-ember-glow)]"
    : "bg-frost/[0.04] border border-frost/10";

  const tokensLabel =
    cycle === "MONTHLY"
      ? tt("tokensSuffixMonthly")
      : tt("tokensSuffixAnnual");
  const priceUnit = cycle === "MONTHLY" ? t("perMonth") : t("perYear");

  return (
    <article className={`flex flex-col rounded-card ${surface} p-6 sm:p-7 relative`}>
      {badge && (
        <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-button bg-ember text-obsidian font-mono uppercase text-[10px] tracking-[var(--tracking-label)] px-3 py-1 shadow-[var(--shadow-card)]">
          {badge}
        </span>
      )}

      <header>
        <h3 className="font-display text-frost text-xl font-semibold">
          {tt("name")}
        </h3>
        <p className="font-serif text-mist text-sm mt-1">{tt("tagline")}</p>
      </header>

      <div className="mt-6 flex items-baseline gap-2">
        <span className="font-display text-frost text-4xl font-semibold">
          {formatPrice(locale, row.priceGross)}
        </span>
        <span className="font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist">
          {priceUnit}
        </span>
      </div>
      <p className="font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist mt-2">
        {row.tokensPerPeriod} {tokensLabel}
      </p>

      <ul className="mt-6 space-y-2 flex-1">
        {features.map((f, i) => (
          <FeatureLine key={i}>{f}</FeatureLine>
        ))}
      </ul>

      <a
        href={registerHref}
        className={`mt-6 inline-flex items-center justify-center rounded-button font-mono uppercase tracking-[var(--tracking-label)] text-sm px-4 py-3 transition ${
          isHighlighted
            ? "bg-ember text-obsidian shadow-[var(--shadow-ember-glow)] hover:brightness-110"
            : "border border-frost/20 text-frost hover:bg-frost/5 font-display normal-case tracking-normal"
        }`}
      >
        {tt("cta")}
      </a>
    </article>
  );
}

function FeatureLine({ children }: { children: React.ReactNode }) {
  return (
    <li className="flex gap-2 items-start font-serif text-sm text-mist leading-relaxed">
      <span aria-hidden className="text-ember mt-0.5">✓</span>
      <span>{children}</span>
    </li>
  );
}
