// Public plan catalog for the marketing pricing page.
//
// PRICING DECISION (2026-06-08, Maciek+Marcin):
//   Trial:      5 sessions / 30 days, free, no card
//   Równowaga:  179 zł BRUTTO /mo, 30 sessions. Coupon ROWNOWAGA20 = -20% = ~143 zł
//   Rozkwit:    299 zł BRUTTO /mo, 90 sessions. Coupon ROZKWIT30  = -30% = ~209 zł
//   Prices are BRUTTO (incl. 23% VAT). Stripe Tax handles the split.
//
// Source of truth: superwizor-backend/migrations/000029_billing_phase3_seed_plans.up.sql
// Drift check: when you bump prices here, bump the migration in the same PR.

export type PlanTier = "TRIAL" | "SOLO" | "PRO" | "CLINIC";
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
  /** Stripe Price ID (sandbox). null = no self-serve checkout. */
  stripePriceId: string | null;
  /** Stripe Payment Link URL (sandbox). null = no self-serve checkout. */
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
    tokensPerPeriod: 5,
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: null,
    stripePaymentLink: null,
  },
  {
    tier: "SOLO",
    cycle: "MONTHLY",
    priceGross: 179.0,           // brutto
    priceIntroGross: 143.0,      // ~179 * 0.80 (ROWNOWAGA20 = -20%)
    couponCode: "ROWNOWAGA20",
    currencyCode: "PLN",
    tokensPerPeriod: 30,
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: "price_1TgAk2E5jzWcAIgeQ572wpkE",  // Równowaga monthly 179 PLN brutto
    stripePaymentLink: null,  // Stripe Checkout via backend
  },
  {
    tier: "SOLO",
    cycle: "ANNUAL",
    priceGross: 1790.0,          // brutto (179 * 10 months effectively)
    priceIntroGross: 1432.0,     // ~1790 * 0.80
    couponCode: "ROWNOWAGA20",
    currencyCode: "PLN",
    tokensPerPeriod: 360,
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: "price_1TgAlxE5jzWcAIgedH5FM8No",  // Równowaga annual 1790 PLN brutto
    stripePaymentLink: null,
  },
  {
    tier: "PRO",
    cycle: "MONTHLY",
    priceGross: 299.0,           // brutto
    priceIntroGross: 209.0,      // ~299 * 0.70 (ROZKWIT30 = -30%)
    couponCode: "ROZKWIT30",
    currencyCode: "PLN",
    tokensPerPeriod: 90,          // was 120, confirmed 90
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: "price_1TgAnSE5jzWcAIgeshZ6TqG8",  // Rozkwit monthly 299 PLN brutto
    stripePaymentLink: null,
  },
  {
    tier: "PRO",
    cycle: "ANNUAL",
    priceGross: 2999.0,          // brutto (Stripe: 2999 PLN)
    priceIntroGross: 2099.0,     // ~2999 * 0.70
    couponCode: "ROZKWIT30",
    currencyCode: "PLN",
    tokensPerPeriod: 1080,        // 90 * 12
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: "price_1TgAo3E5jzWcAIge1Q6dMMwd",  // Rozkwit annual 2999 PLN brutto
    stripePaymentLink: null,
  },
  {
    tier: "CLINIC",
    cycle: "MONTHLY",
    priceGross: 999.0,
    currencyCode: "PLN",
    tokensPerPeriod: 150,
    licensesLimit: 5,
    hasB2BDashboard: true,
    stripePriceId: null,
    stripePaymentLink: null,
  },
  {
    tier: "CLINIC",
    cycle: "ANNUAL",
    priceGross: 9990.0,
    currencyCode: "PLN",
    tokensPerPeriod: 1800,
    licensesLimit: 5,
    hasB2BDashboard: true,
    stripePriceId: null,
    stripePaymentLink: null,
  },
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

