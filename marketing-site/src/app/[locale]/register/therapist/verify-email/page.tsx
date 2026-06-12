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
import { VerifyEmailIntro } from "@/components/register/VerifyEmailIntro";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "register.verifyEmail" });
  return { title: t("metaTitle") };
}

// Static-export contract: see /register/therapist/finish/page.tsx
// for the rationale. The ?email= read moved to VerifyEmailIntro
// (a client component) so this shell can prerender per locale.
export default async function VerifyEmailPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("register.verifyEmail");
  const prefix = locale === "en" ? "/en" : "";

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-[1440px] px-4 sm:px-6 lg:px-12 xl:px-16 py-12 sm:py-16">
          <div className="mx-auto w-full grid grid-cols-1 lg:grid-cols-12 gap-8 items-start text-left">
            {/* Left Spacer to center the card on desktop */}
            <div className="hidden lg:block lg:col-span-3" />

            {/* Left Column: Form/Card */}
            <div className="col-span-12 lg:col-span-6 w-full max-w-[480px] lg:justify-self-center mx-auto rounded-[20px] border border-frost/10 bg-frost/5 backdrop-blur-md p-6 sm:p-10 shadow-[0_8px_32px_rgba(0,0,0,0.25)] flex flex-col gap-6 text-center">
              {/* Mail Icon */}
              <div className="mx-auto w-12 h-12 rounded-full bg-ember/15 flex items-center justify-center text-ember border border-ember/25 shadow-[0_0_15px_rgba(252,174,47,0.15)] mb-2">
                <svg className="w-6 h-6 animate-pulse" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
              </div>

              <h1 className="font-display text-frost text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] leading-tight">
                {t("title")}
              </h1>
              
              <VerifyEmailIntro />

              <p className="font-sans text-mist/80 mt-2 text-sm leading-relaxed">
                {t("noEmail")}
              </p>

              <div className="mt-4 flex flex-col sm:flex-row gap-3 justify-center">
                <ResendVerificationButton />
                <a
                  href={`${prefix}/`}
                  className="inline-flex items-center justify-center rounded-button border border-frost/20 text-frost font-display text-sm px-6 py-3 hover:bg-frost/5 transition"
                >
                  {t("backToLanding")}
                </a>
              </div>
            </div>

            {/* Right Column: Photo & Quote outside card container */}
            <div className="col-span-12 lg:col-span-3 flex flex-col gap-5 w-full lg:items-end lg:justify-self-end mt-8 lg:mt-0">
              {/* Photo */}
              <div className="relative aspect-[4/3] md:aspect-[1.15] w-full max-w-[360px] overflow-hidden rounded-tl-[80px] rounded-br-[20px] rounded-tr-[20px] rounded-bl-[20px] border border-frost/10 shadow-[0_8px_24px_rgba(0,0,0,0.3)]">
                <img
                  src="/assets/therapy-banana.png"
                  alt="Therapy session setup"
                  className="object-cover w-full h-full brightness-90 contrast-[1.05]"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-obsidian/40 to-transparent" />
              </div>

              {/* Testimonial Card */}
              <div className="bg-frost/[0.03] border border-frost/10 p-5 rounded-[20px] flex flex-col gap-3.5 shadow-md w-full max-w-[360px]">
                {/* Stars */}
                <div className="flex gap-1">
                  {[1, 2, 3, 4, 5].map((s) => (
                    <svg key={s} className="w-4 h-4 text-ember fill-ember" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                    </svg>
                  ))}
                </div>

                <p className="font-sans text-xs sm:text-[13px] text-frost/90 italic leading-relaxed text-left before:content-['„'] after:content-['”']">
                  {locale === "pl"
                    ? "Proces rejestracji i weryfikacji trwał mniej niż minutę. Czysta przyjemność z użytkowania od samego początku!"
                    : "The sign-up and verification process took less than a minute. Clean and delightful user experience right from the start!"}
                </p>

                <div className="flex items-center gap-3 pt-3 border-t border-frost/5">
                  <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#1b3d36] to-[#0e2722] flex items-center justify-center font-sans font-bold text-xs text-[#fcbf49] shadow-inner select-none shrink-0">
                    M
                  </div>
                  <div className="flex flex-col text-left overflow-hidden">
                    <span className="font-sans font-bold text-xs text-white">Marcin</span>
                    <span className="font-sans text-[10px] text-[#fcbf49] font-semibold">
                      {locale === "pl" ? "psychoterapeuta poznawczo-behawioralny" : "cognitive behavioral psychotherapist"}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
