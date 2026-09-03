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

import { lookupPlan, type BillingCycle, type PlanTier } from "@/lib/billing/plans";
import { identityClient } from "@/lib/connect/clients";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";

/** Plan slugs the frontend uses in ?plan= query params. */
export type PlanSlug =
  | "trial"
  | "beta"
  | "solo_monthly"
  | "solo_annual"
  | "pro_monthly"
  | "pro_annual";

/** ?plan= slug → catalog coordinates. One map, two readers. */
const SLUG_TO_PLAN: Record<string, { tier: PlanTier; cycle: BillingCycle }> = {
  solo_monthly: { tier: "SOLO", cycle: "MONTHLY" },
  solo_annual: { tier: "SOLO", cycle: "ANNUAL" },
  pro_monthly: { tier: "PRO", cycle: "MONTHLY" },
  pro_annual: { tier: "PRO", cycle: "ANNUAL" },
};

/** Same shape the admin panel enforces (docs/70 §6.2, D9). */
const DISCOUNT_CODE_PATTERN = /^[A-Z0-9_]{3,32}$/;

/**
 * Which promo code goes to /api/checkout.
 *
 * Precedence, and the reasoning behind it:
 *   1. ?nopromo=1 / ?clean=1 — the existing "give me a bare checkout"
 *      escape hatch used for testing. Nothing overrides it.
 *   2. ?code=XYZ — a code the visitor typed and we validated on /pricing
 *      or /upgrade. Deliberate beats automatic, so it wins over the
 *      plan's own coupon. Re-validated server-side when the Checkout
 *      session is created; a junk value can only cost the discount.
 *   3. The plan's built-in coupon (ROWNOWAGA, ROZKWIT, …) — unchanged
 *      behaviour for everyone who never touches the code field.
 */
export function resolvePromoCode(
  planSlug: string | null,
  search: string,
): string | undefined {
  const params = new URLSearchParams(search);
  if (params.get("nopromo") === "1" || params.get("clean") === "1") {
    return undefined;
  }

  const typed = (params.get("code") ?? "").trim().toUpperCase();
  if (DISCOUNT_CODE_PATTERN.test(typed)) return typed;

  if (!planSlug) return undefined;
  const planKey = SLUG_TO_PLAN[planSlug.toLowerCase()];
  if (!planKey) return undefined;
  return lookupPlan(planKey.tier, planKey.cycle)?.couponCode;
}

/**
 * Resolve a ?plan= slug to a Stripe price ID.
 * Returns null for free plans (trial, beta) or unrecognized slugs.
 */
export function resolveStripePriceId(planSlug: string | null): string | null {
  if (!planSlug) return null;

  const slug = planSlug.toLowerCase();

  // Free plans — no Stripe checkout needed
  if (slug === "trial" || slug === "beta") return null;

  const planKey = SLUG_TO_PLAN[slug];
  if (!planKey) return null;

  const plan = lookupPlan(planKey.tier, planKey.cycle);
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
  phoneNumber?: string,
  name?: string,
): Promise<void> {
  const priceId = resolveStripePriceId(planSlug);

  if (!priceId) {
    // Free flow: trial or beta → verify email
    window.location.href = `${prefix}/register/therapist/verify-email?email=${encodeURIComponent(email)}`;
    return;
  }

  const promoCode = resolvePromoCode(
    planSlug,
    typeof window !== "undefined" ? window.location.search : "",
  );

  // Paid flow: create Stripe Checkout session
  try {
    let address: any = undefined;
    let taxId: string | undefined;
    let vatIdEu: string | undefined;
    try {
      const org = await identityClient.getMyOrganization(create(EmptySchema, {}));
      if (org) {
        if (org.legalName) {
          name = org.legalName;
        }
        taxId = org.taxId || undefined;
        vatIdEu = org.vatIdEu || undefined;

        if (org.headquartersAddress) {
          const street = org.headquartersAddress.streetLine || "";
          const bldg = org.headquartersAddress.buildingNumber || "";
          const unit = org.headquartersAddress.unitNumber || "";

          let line1 = `${street} ${bldg}`.trim();
          if (unit) {
            line1 = `${line1}/${unit}`;
          }

          address = {
            line1: line1 || undefined,
            line2: org.headquartersAddress.directions || undefined,
            city: org.headquartersAddress.city || undefined,
            postal_code: org.headquartersAddress.postalCode || undefined,
            state: org.headquartersAddress.region || undefined,
            country: org.headquartersAddress.countryCode || undefined,
          };
        }
      }
    } catch (err) {
      console.warn("[post-registration] Failed to fetch organization details for prefilling:", err);
    }

    const res = await fetch("/api/checkout", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ priceId, organizationId, email, phoneNumber, name, promoCode, address, taxId, vatIdEu }),
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
