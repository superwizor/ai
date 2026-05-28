// /register/therapist/verify-email — post-signup interstitial.
//
// Feature 1 (this file) lands the static page rendering "we sent you
// an email" with the recipient address pulled from the ?email= query.
// Feature 5 (email-verification-gate) will:
//   - listen for the verification redirect coming back,
//   - poll auth.currentUser.reload() to detect emailVerified,
//   - redirect the user onwards to app.superwizor.ai.
// Until then the user can hit "Resend" to fire sendEmailVerification
// again. The Resend button is a tiny client island below.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";
import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { ResendVerificationButton } from "@/components/register/ResendVerificationButton";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "register.verifyEmail" });
  return { title: t("metaTitle") };
}

export default async function VerifyEmailPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ email?: string }>;
}) {
  const { locale } = await params;
  const { email } = await searchParams;
  setRequestLocale(locale);
  const t = await getTranslations("register.verifyEmail");
  const prefix = locale === "en" ? "/en" : "";

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-lg px-4 sm:px-6 lg:px-8 py-16 sm:py-24 text-center">
          <p className="font-mono text-[10px] uppercase text-ember tracking-[var(--tracking-overline)] mb-4">
            ✉
          </p>
          <h1 className="font-display text-frost text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] leading-tight">
            {t("title")}
          </h1>
          <p className="font-serif text-mist mt-4 leading-relaxed">
            {t("intro", { email: email ?? "" })}
          </p>
          <p className="font-serif text-mist/80 mt-6 text-sm leading-relaxed">
            {t("noEmail")}
          </p>

          <div className="mt-8 flex flex-col sm:flex-row gap-3 justify-center">
            <ResendVerificationButton />
            <a
              href={`${prefix}/`}
              className="inline-flex items-center justify-center rounded-button border border-frost/20 text-frost font-display text-sm px-6 py-3 hover:bg-frost/5 transition"
            >
              {t("backToLanding")}
            </a>
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
