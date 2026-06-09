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
    locale === "en" ? "Go to login" : "Przejdź do logowania";
  const prefix = locale === "en" ? "/en" : "";

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-lg px-4 sm:px-6 lg:px-8 py-20 sm:py-28 text-center">
          <div className="w-16 h-16 rounded-full bg-[#2F6B62]/10 flex items-center justify-center mx-auto mb-6">
            <svg
              className="w-8 h-8 text-[#2F6B62]"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={2}
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M5 13l4 4L19 7"
              />
            </svg>
          </div>

          <h1 className="font-display text-frost text-3xl sm:text-4xl font-bold tracking-tight">
            {heading}
          </h1>

          <p className="font-sans text-mist mt-4 text-base leading-relaxed max-w-md mx-auto">
            {subtext}
          </p>

          <a
            href={`${prefix}/login`}
            className="inline-flex items-center justify-center rounded-[12px] bg-[#004D54] text-white font-sans font-bold uppercase tracking-wider text-xs px-8 py-4 mt-8 hover:bg-[#002E32] transition-all duration-200 active:scale-[0.97]"
          >
            {cta}
          </a>
        </section>
      </main>
      <Footer />
    </>
  );
}
