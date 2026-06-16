// POST /api/checkout — creates a Stripe Checkout Session.
//
// Called after registration when the user selected a paid plan.
// Body: { priceId: string, organizationId: string, email?: string }
//
// The organization_id is passed as Stripe metadata so the webhook
// (billing-svc stripe_handler.go) can link checkout.session.completed
// to the correct org.
//
// Auth: requires a valid Firebase ID token in the Authorization header.
// The marketing-site doesn't do server-side Firebase verification today
// (Connect-Web calls go direct to backend), so for now we trust the
// client-provided organizationId and validate it will be a UUID.
// TODO: verify Firebase token server-side when identity-svc exposes
// a lightweight validate endpoint over REST.

import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2026-05-27.dahlia",
});

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { priceId, organizationId, email, phoneNumber, name, promoCode, returnUrl, address, taxId, vatIdEu } = body as {
      priceId: string;
      organizationId: string;
      email?: string;
      phoneNumber?: string;
      name?: string;
      promoCode?: string;
      returnUrl?: string;
      taxId?: string;
      vatIdEu?: string;
      address?: {
        line1?: string;
        line2?: string;
        city?: string;
        postal_code?: string;
        state?: string;
        country?: string;
      };
    };

    if (!priceId || typeof priceId !== "string") {
      return NextResponse.json(
        { error: "priceId is required" },
        { status: 400 },
      );
    }

    if (!organizationId || !UUID_RE.test(organizationId)) {
      return NextResponse.json(
        { error: "valid organizationId is required" },
        { status: 400 },
      );
    }

    // Determine success/cancel URLs. If a returnUrl is provided
    // (e.g. from the /account upgrade flow), use it so the user
    // lands back on their account page. Otherwise fall back to the
    // registration success page for new sign-ups.
    const origin = request.nextUrl.origin;
    const successUrl = returnUrl
      ? `${origin}${returnUrl}?session_id={CHECKOUT_SESSION_ID}&upgraded=1`
      : `${origin}/register/therapist/success?session_id={CHECKOUT_SESSION_ID}`;
    const cancelUrl = returnUrl
      ? `${origin}${returnUrl}?plan=cancelled`
      : `${origin}/register/therapist?plan=cancelled`;

    let resolvedPromoCodeId: string | undefined;
    if (promoCode && typeof promoCode === "string") {
      try {
        const promoCodes = await stripe.promotionCodes.list({
          code: promoCode,
          active: true,
          limit: 1,
        });
        if (promoCodes.data.length > 0) {
          resolvedPromoCodeId = promoCodes.data[0].id;
        }
      } catch (err) {
        console.warn("[api/checkout] Error looking up promo code in Stripe:", err);
      }
    }

    const sessionParams: Stripe.Checkout.SessionCreateParams = {
      mode: "subscription",
      line_items: [{ price: priceId, quantity: 1 }],
      metadata: {
        organization_id: organizationId,
      },
      subscription_data: {
        metadata: {
          organization_id: organizationId,
        },
      },
      success_url: successUrl,
      cancel_url: cancelUrl,
      // Allow promotion codes so users can apply ROWNOWAGA20 / ROZKWIT30
      ...(resolvedPromoCodeId
        ? { discounts: [{ promotion_code: resolvedPromoCodeId }] }
        : { allow_promotion_codes: true }
      ),
      // Collect phone number (anti-abuse + Marcin's contact base for follow-ups)
      phone_number_collection: { enabled: true },
      // "Chcę fakturę VAT" — required NIP/tax ID collection for B2B
      tax_id_collection: { enabled: true },
      // Collect billing address — required for proper Polish VAT invoices
      billing_address_collection: "required",
      // EU VAT compliance — Stripe Tax handles rate calculation
      automatic_tax: { enabled: true },
      // Polish locale
      locale: "pl",
    };

    const addTaxIdToCustomer = async (custID: string, taxVal?: string, vatVal?: string) => {
      try {
        if (vatVal) {
          const cleanVat = vatVal.replace(/[^A-Z0-9]/gi, "").toUpperCase();
          if (cleanVat.startsWith("PL") && cleanVat.length === 12) {
            await stripe.customers.createTaxId(custID, { type: "eu_vat", value: cleanVat });
          }
        } else if (taxVal) {
          const cleanTax = taxVal.replace(/[^0-9]/g, "");
          if (cleanTax.length === 10) {
            await stripe.customers.createTaxId(custID, { type: "pl_nip", value: cleanTax });
          }
        }
      } catch (err) {
        console.warn("[api/checkout] Failed to assign Tax ID to customer:", err);
      }
    };

    // Pre-fill customer info using Stripe Customer resource (required for phone number prefill)
    let customerId: string | undefined;
    if (email && typeof email === "string") {
      try {
        const customers = await stripe.customers.list({ email, limit: 1 });
        if (customers.data.length > 0) {
          const existingCustomer = customers.data[0];
          customerId = existingCustomer.id;

          // Check if customer already has an active subscription.
          // If so, redirect them to the billing portal instead of checkout.
          const subs = await stripe.subscriptions.list({
            customer: existingCustomer.id,
            status: "active",
            limit: 1,
          });
          if (subs.data.length > 0) {
            const portalSession = await stripe.billingPortal.sessions.create({
              customer: existingCustomer.id,
              return_url: returnUrl ? `${origin}${returnUrl}` : `${origin}/account`,
              locale: "pl",
            });
            return NextResponse.json({ url: portalSession.url });
          }

          // Sync name/phone/address if they differ or are missing on file in Stripe
          const phoneChanged = phoneNumber && existingCustomer.phone !== phoneNumber;
          const nameChanged = name && existingCustomer.name !== name;
          const addressMissing = address && !existingCustomer.address;
          if (phoneChanged || nameChanged || addressMissing) {
            await stripe.customers.update(existingCustomer.id, {
              ...(phoneChanged ? { phone: phoneNumber } : {}),
              ...(nameChanged ? { name } : {}),
              ...(addressMissing ? { address } : {}),
            });
          }

          if (taxId || vatIdEu) {
            await addTaxIdToCustomer(existingCustomer.id, taxId, vatIdEu);
          }
        }
      } catch (err) {
        console.warn("[api/checkout] Error looking up/updating existing customer:", err);
      }
    }

    // Create a customer if one doesn't exist
    if (!customerId && email) {
      try {
        const newCustomer = await stripe.customers.create({
          email,
          ...(phoneNumber ? { phone: phoneNumber } : {}),
          ...(name ? { name } : {}),
          ...(address ? { address } : {}),
          metadata: {
            organization_id: organizationId,
          },
        });
        customerId = newCustomer.id;

        if (taxId || vatIdEu) {
          await addTaxIdToCustomer(newCustomer.id, taxId, vatIdEu);
        }
      } catch (err) {
        console.warn("[api/checkout] Error creating customer in Stripe:", err);
      }
    }

    if (customerId) {
      sessionParams.customer = customerId;
      sessionParams.customer_update = {
        name: "auto",
        address: "auto",
      };
    } else if (email && typeof email === "string") {
      sessionParams.customer_email = email;
    }

    const session = await stripe.checkout.sessions.create(sessionParams);

    return NextResponse.json({ url: session.url });
  } catch (err) {
    console.error("[api/checkout] Error creating checkout session:", err);

    if (err instanceof Stripe.errors.StripeError) {
      return NextResponse.json(
        { error: err.message },
        { status: err.statusCode ?? 500 },
      );
    }

    return NextResponse.json(
      { error: "Failed to create checkout session" },
      { status: 500 },
    );
  }
}

