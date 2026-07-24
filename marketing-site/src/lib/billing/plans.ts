// Public plan catalog for the marketing pricing page.
//
// PRICING DECISION (2026-07-12, Maciek+Marcin — LIVE):
//   Trial:      10 sessions / 30 days, free, no card (bumped from 5→10 in 000079)
//   Równowaga:  149 zł BRUTTO /mo, 30 sessions. Coupon ROWNOWAGA = -50 zł = 99 zł
//   Rozkwit:    299 zł BRUTTO /mo, 90 sessions. Coupon ROZKWIT = -100 zł = 199 zł
//   Prices are BRUTTO (incl. 23% VAT). Stripe Tax handles the split.
//
// Source of truth: superwizor-backend/migrations/000029_billing_phase3_seed_plans.up.sql
// Drift check: when you bump prices here, bump the migration in the same PR.

export type PlanTier = "TRIAL" | "SOLO" | "PRO";
export type BillingCycle = "MONTHLY" | "ANNUAL";

export type PlanRow = {
  tier: PlanTier;
  cycle: BillingCycle;
  /** Gross price, in the unit the user sees (PLN). */
  priceGross: number;
  /** Introductory price with coupon applied. */
  priceIntroGross?: number;
  /** Associated Stripe coupon/promo code. */
  couponCode?: string;
  currencyCode: "PLN";
  tokensPerPeriod: number;
  licensesLimit: number;
  hasB2BDashboard: boolean;
  /** Stripe Price ID (live). null = no self-serve checkout. */
  stripePriceId: string | null;
  /** Stripe Payment Link URL. null = no self-serve checkout. */
  stripePaymentLink: string | null;
};

/**
 * Static catalog mirroring migration 000029. Trial is included as a
 * synthetic entry (it's not in subscription_plans — it's auto-provisioned
 * on signup — but the marketing page needs a card for it).
 */
const PLANS: ReadonlyArray<PlanRow> = [
  {
    tier: "TRIAL",
    cycle: "MONTHLY",
    priceGross: 0,
    currencyCode: "PLN",
    tokensPerPeriod: 10,
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: null,
    stripePaymentLink: null,
  },
  {
    tier: "SOLO",
    cycle: "MONTHLY",
    priceGross: 149.0,           // brutto
    priceIntroGross: 99.0,
    couponCode: "ROWNOWAGA",
    currencyCode: "PLN",
    tokensPerPeriod: 30,
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: "price_1TsUvXEA7Lw46kANXxzZZwTs",  // Równowaga monthly 149 PLN brutto (LIVE)
    stripePaymentLink: null,  // Stripe Checkout via backend
  },
  {
    tier: "SOLO",
    cycle: "ANNUAL",
    priceGross: 1490.0,          // brutto
    priceIntroGross: 990.0,
    couponCode: "ROWNOWAGA_ROK",
    currencyCode: "PLN",
    tokensPerPeriod: 360,
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: "price_1TsUvlEA7Lw46kANGuLjnoeD",  // Równowaga annual 1490 PLN brutto (LIVE)
    stripePaymentLink: null,
  },
  {
    tier: "PRO",
    cycle: "MONTHLY",
    priceGross: 299.0,           // brutto
    priceIntroGross: 199.0,
    couponCode: "ROZKWIT",
    currencyCode: "PLN",
    tokensPerPeriod: 90,          // was 120, confirmed 90
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: "price_1TsUwUEA7Lw46kANHgjOrNRy",  // Rozkwit monthly 299 PLN brutto (LIVE)
    stripePaymentLink: null,
  },
  {
    tier: "PRO",
    cycle: "ANNUAL",
    priceGross: 2990.0,          // brutto
    priceIntroGross: 1990.0,
    couponCode: "ROZKWIT_ROK",
    currencyCode: "PLN",
    tokensPerPeriod: 1080,        // 90 * 12
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: "price_1TsUwkEA7Lw46kAN76gYZGIQ",  // Rozkwit annual 2990 PLN brutto (LIVE)
    stripePaymentLink: null,
  },
  // CLINIC tier removed (2026-07-12) — not in Marcin's pricing.
];

export async function getPlanCatalog(): Promise<ReadonlyArray<PlanRow>> {
  // When ListSubscriptionPlans RPC lands:
  //   const resp = await billingClient.listSubscriptionPlans({});
  //   return resp.plans.map(...);
  return PLANS;
}

export function findPlan(
  catalog: ReadonlyArray<PlanRow>,
  tier: PlanTier,
  cycle: BillingCycle,
): PlanRow | undefined {
  return catalog.find((p) => p.tier === tier && p.cycle === cycle);
}

/** Formats a PLN price using the active locale's number-formatting rules. */
export function formatPrice(locale: string, value: number): string {
  return new Intl.NumberFormat(locale === "en" ? "en-GB" : "pl-PL", {
    maximumFractionDigits: 0,
  }).format(value);
}

/** Look up a plan by tier and cycle from the static catalog. */
export function lookupPlan(
  tier: PlanTier,
  cycle: BillingCycle,
): PlanRow | undefined {
  return PLANS.find((p) => p.tier === tier && p.cycle === cycle);
}

// ═══════════════════════════════════════════════════════════════════════
// 🚨 SINGLE SOURCE OF TRUTH — Marketing copy for plan numbers.
//
// AGENTS: NEVER hardcode session counts, trial durations, or plan prices
//         anywhere in JSX/TSX. Import from here instead:
//
//   import { TRIAL_COPY, planCopy } from "@/lib/billing/plans";
//
//   // In your component:
//   <span>{TRIAL_COPY[locale].pitch}</span>
//   <span>{planCopy("SOLO", "MONTHLY", locale).sessions}</span>
//
// When tokensPerPeriod changes in PLANS above, these strings update
// everywhere automatically. Zero grep, zero drift.
// ═══════════════════════════════════════════════════════════════════════

const _trial = PLANS.find((p) => p.tier === "TRIAL")!;
const _trialSessions = _trial.tokensPerPeriod;

/**
 * Pre-formatted marketing copy for the TRIAL plan.
 * 🚨 NEVER write "10 sesji" or "10 sessions" as a raw string.
 *    Always use TRIAL_COPY[locale].pitch / .sessions / etc.
 */
export const TRIAL_COPY = {
  pl: {
    sessions:  `${_trialSessions} sesji`,
    duration:  "30 dni",
    pitch:     `${_trialSessions} sesji przez 30 dni`,
    heading:   `Zacznij od ${_trialSessions} sesji za darmo`,
    feature:   `${_trialSessions} sesji terapeutycznych przez 30 dni`,
    micro:     `30 dni / ${_trialSessions} sesji. Bez karty kredytowej.`,
    ctaSub:    `Rozpocznij od ${_trialSessions} darmowych sesji.`,
  },
  en: {
    sessions:  `${_trialSessions} sessions`,
    duration:  "30 days",
    pitch:     `${_trialSessions} sessions for 30 days`,
    heading:   `Start with ${_trialSessions} free sessions`,
    feature:   `${_trialSessions} therapy sessions for 30 days`,
    micro:     `30 days / ${_trialSessions} sessions. No credit card required.`,
    ctaSub:    `Start with ${_trialSessions} free sessions.`,
  },
} as const;

/**
 * Get formatted session-count string for any plan.
 * 🚨 NEVER write "30 sesji" or "90 sessions" as a raw string.
 */
export function planCopy(
  tier: PlanTier,
  cycle: BillingCycle,
  locale: string,
): { sessions: string; sessionsMonth: string } {
  const plan = lookupPlan(tier, cycle);
  if (!plan) return { sessions: "—", sessionsMonth: "—" };
  const n = plan.tokensPerPeriod;
  const isPl = locale === "pl";
  const cycleSuffix = cycle === "ANNUAL"
    ? (isPl ? "rok" : "year")
    : (isPl ? "mies." : "month");
  return {
    sessions: isPl ? `${n} sesji` : `${n} sessions`,
    sessionsMonth: isPl ? `${n} sesji/${cycleSuffix}` : `${n} sessions/${cycleSuffix}`,
  };
}
