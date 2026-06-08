// Post-registration redirect logic.
//
// After a therapist registers (email or social), this function decides
// where to send them:
//
//   - No plan / plan=trial / plan=beta → verify-email (free flow)
//   - plan=solo_monthly / pro_monthly etc → Stripe Checkout (paid flow)
//
// For the paid flow, it calls /api/checkout to get a Stripe Checkout URL
// and redirects there. The Stripe webhook on the backend will provision
// the paid subscription when checkout completes.

import { lookupPlan } from "@/lib/billing/plans";

/** Plan slugs the frontend uses in ?plan= query params. */
export type PlanSlug =
  | "trial"
  | "beta"
  | "solo_monthly"
  | "solo_annual"
  | "pro_monthly"
  | "pro_annual";

/**
 * Resolve a ?plan= slug to a Stripe price ID.
 * Returns null for free plans (trial, beta) or unrecognized slugs.
 */
export function resolveStripePriceId(planSlug: string | null): string | null {
  if (!planSlug) return null;

  const slug = planSlug.toLowerCase();

  // Free plans — no Stripe checkout needed
  if (slug === "trial" || slug === "beta") return null;

  // Map slug to tier+cycle
  const mapping: Record<string, { tier: string; cycle: string }> = {
    solo_monthly: { tier: "SOLO", cycle: "MONTHLY" },
    solo_annual: { tier: "SOLO", cycle: "ANNUAL" },
    pro_monthly: { tier: "PRO", cycle: "MONTHLY" },
    pro_annual: { tier: "PRO", cycle: "ANNUAL" },
  };

  const planKey = mapping[slug];
  if (!planKey) return null;

  const plan = lookupPlan(planKey.tier as any, planKey.cycle as any);
  return plan?.stripePriceId ?? null;
}

/**
 * Redirect the user after successful registration.
 *
 * @param organizationId - The org ID from identity-svc CreateUser response
 * @param planSlug - The ?plan= query param value
 * @param prefix - Locale prefix ("" or "/en")
 * @param email - User's email (for verify-email page)
 */
export async function handlePostRegistrationRedirect(
  organizationId: string,
  planSlug: string | null,
  prefix: string,
  email: string,
): Promise<void> {
  const priceId = resolveStripePriceId(planSlug);

  if (!priceId) {
    // Free flow: trial or beta → verify email
    window.location.href = `${prefix}/register/therapist/verify-email?email=${encodeURIComponent(email)}`;
    return;
  }

  // Paid flow: create Stripe Checkout session
  try {
    const res = await fetch("/api/checkout", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ priceId, organizationId, email }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: "unknown" }));
      console.error("[post-registration] Checkout creation failed:", err);
      // Fall back to verify-email — user can upgrade later from account page
      window.location.href = `${prefix}/register/therapist/verify-email?email=${encodeURIComponent(email)}`;
      return;
    }

    const { url } = await res.json();
    if (url) {
      window.location.href = url;
    } else {
      // Fallback
      window.location.href = `${prefix}/register/therapist/verify-email?email=${encodeURIComponent(email)}`;
    }
  } catch (err) {
    console.error("[post-registration] Checkout redirect failed:", err);
    // Graceful degradation — verify email first, upgrade later
    window.location.href = `${prefix}/register/therapist/verify-email?email=${encodeURIComponent(email)}`;
  }
}
