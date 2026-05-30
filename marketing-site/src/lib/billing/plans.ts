// Public plan catalog for the marketing pricing page.
//
// docs/18 §8.1 says the pricing page should "read from subscription_plans"
// — long-term that means calling `billingClient.listSubscriptionPlans({})`
// (RPC not yet defined). For now this module mirrors the values from
// migration `000029_billing_phase3_seed_plans.up.sql` 1:1. When the
// ListSubscriptionPlans RPC lands in a follow-up backend slice, swap
// `getPlanCatalog()` to return the RPC response and delete this file.
//
// Source of truth: superwizor-backend/migrations/000029_billing_phase3_seed_plans.up.sql
// Drift check (manual until we have RPC): when you bump prices here,
// bump the migration in the same PR.

export type PlanTier = "TRIAL" | "SOLO" | "PRO" | "CLINIC";
export type BillingCycle = "MONTHLY" | "ANNUAL";

export type PlanRow = {
  tier: PlanTier;
  cycle: BillingCycle;
  /** Gross price, in the unit the user sees (PLN). */
  priceGross: number;
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
    tokensPerPeriod: 3,
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: null,
    stripePaymentLink: null,
  },
  {
    tier: "SOLO",
    cycle: "MONTHLY",
    priceGross: 149.0,
    currencyCode: "PLN",
    tokensPerPeriod: 20,
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: "price_1TclVgE5jzWcAIgeT6ec0HDh",
    stripePaymentLink: "https://buy.stripe.com/test_dRmbJ14s21tYfZ1fAF48000",
  },
  {
    tier: "SOLO",
    cycle: "ANNUAL",
    priceGross: 1490.0,
    currencyCode: "PLN",
    tokensPerPeriod: 240,
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: "price_1TclVhE5jzWcAIge7YjI49Hs",
    stripePaymentLink: "https://buy.stripe.com/test_4gM00j8Ii6Oi147gEJ48001",
  },
  {
    tier: "PRO",
    cycle: "MONTHLY",
    priceGross: 249.0,
    currencyCode: "PLN",
    tokensPerPeriod: 40,
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: "price_1TclVhE5jzWcAIgeMQTPps4i",
    stripePaymentLink: "https://buy.stripe.com/test_bJebJ12jUc8C5kn2NT48002",
  },
  {
    tier: "PRO",
    cycle: "ANNUAL",
    priceGross: 2490.0,
    currencyCode: "PLN",
    tokensPerPeriod: 480,
    licensesLimit: 1,
    hasB2BDashboard: false,
    stripePriceId: "price_1TclViE5jzWcAIgehEFNihUP",
    stripePaymentLink: "https://buy.stripe.com/test_fZueVd5w67SmeUXdsx48003",
  },
  {
    tier: "CLINIC",
    cycle: "MONTHLY",
    priceGross: 999.0,
    currencyCode: "PLN",
    tokensPerPeriod: 150,
    licensesLimit: 5,
    hasB2BDashboard: true,
    stripePriceId: null, // B2B — manual pricing
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
    stripePriceId: null, // B2B — manual pricing
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
