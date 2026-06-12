// Success page after Stripe Checkout completion.
//
// The user lands here after paying. At this point:
//   - Firebase account exists (created during registration)
//   - identity-svc user + org + TRIAL sub exist
//   - Stripe webhook is processing checkout.session.completed
//     which will upgrade the subscription to the paid plan
//
// This page shows a "setting up" message and then redirects to
// verify-email (they still need to verify their email before
// they can use the app).

import { setRequestLocale } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { SuccessContent } from "@/components/register/SuccessContent";

export const metadata: Metadata = {
  title: "Dziękujemy · Superwizor AI",
};

export default async function SuccessPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const heading =
    locale === "en"
      ? "Payment successful!"
      : "Płatność zakończona pomyślnie!";
  const subtext =
    locale === "en"
      ? "Your subscription is being activated. Please check your email to verify your account and start using Superwizor AI."
      : "Twoja subskrypcja jest aktywowana. Sprawdź swoją skrzynkę e-mail, aby zweryfikować konto i rozpocząć korzystanie z Superwizor AI.";
  const cta =
    locale === "en" ? "Verify your email" : "Zweryfikuj swój email";
  const prefix = locale === "en" ? "/en" : "";

  return (
    <>
      <Navbar variant="tunnel" />
      <main className="flex-1 flex flex-col justify-center items-center min-h-[60vh]">
        <SuccessContent
          locale={locale}
          heading={heading}
          subtext={subtext}
          cta={cta}
          prefix={prefix}
          ctaHref={`${prefix}/register/therapist/verify-email`}
        />
      </main>
      <Footer />
    </>
  );
}
