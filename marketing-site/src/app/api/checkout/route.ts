// POST /api/checkout — creates a Stripe Checkout Session.
//
// Called after registration when the user selected a paid plan.
// Body: { priceId: string, organizationId: string }
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
    const { priceId, organizationId } = body as {
      priceId: string;
      organizationId: string;
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

    // Determine success/cancel URLs. The success page will show
    // a "setting up your account" spinner while the Stripe webhook
    // provisions the subscription on the backend.
    const origin = request.nextUrl.origin;
    const successUrl = `${origin}/register/therapist/success?session_id={CHECKOUT_SESSION_ID}`;
    const cancelUrl = `${origin}/register/therapist?plan=cancelled`;

    const session = await stripe.checkout.sessions.create({
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
      allow_promotion_codes: true,
      // Collect phone number (anti-abuse + Marcin's contact base for follow-ups)
      phone_number_collection: { enabled: true },
      // "Chcę fakturę VAT" — optional NIP/tax ID collection
      tax_id_collection: { enabled: true },
      // Polish locale
      locale: "pl",
    });

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
