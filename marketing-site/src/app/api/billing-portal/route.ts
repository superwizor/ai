import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2026-05-27.dahlia",
});

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { email, returnUrl } = body as {
      email: string;
      returnUrl?: string;
    };

    if (!email || typeof email !== "string") {
      return NextResponse.json(
        { error: "email is required" },
        { status: 400 },
      );
    }

    // Look up the Stripe Customer ID by email
    const customers = await stripe.customers.list({ email: email, limit: 1 });
    if (customers.data.length === 0) {
      return NextResponse.json(
        { error: "No Stripe customer found for this email. Please complete a payment first." },
        { status: 404 },
      );
    }

    const customerId = customers.data[0].id;
    const origin = request.nextUrl.origin;
    
    // Create the hosted Stripe Billing Portal session
    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: returnUrl ? `${origin}${returnUrl}` : `${origin}/account`,
      locale: "pl",
    });

    return NextResponse.json({ url: session.url });
  } catch (err) {
    console.error("[api/billing-portal] Error creating billing portal session:", err);
    if (err instanceof Stripe.errors.StripeError) {
      return NextResponse.json(
        { error: err.message },
        { status: err.statusCode ?? 500 },
      );
    }
    return NextResponse.json(
      { error: "Failed to create billing portal session" },
      { status: 500 },
    );
  }
}
