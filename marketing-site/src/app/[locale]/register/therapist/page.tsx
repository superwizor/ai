// /register/therapist — individual therapist signup.
//
// Server component shell: locale + metadata + modality catalog
// fetched at request time, passed to the client form component.
//
// Social path (Google OAuth) lives in Slice 3 feature 2; this page
// ships the email/password path. The "or" disclosure swap lands when
// feature 2 adds the OAuth buttons.

import { Suspense } from "react";
import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { TherapistEmailForm } from "@/components/register/TherapistEmailForm";
import { SocialButtons } from "@/components/register/SocialButtons";
import { TrialPitchBanner } from "@/components/register/TrialPitchBanner";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "register.therapist" });
  return { title: t("metaTitle") };
}

export default async function RegisterTherapistPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("register.therapist");

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-xl px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <p className="font-mono text-[10px] sm:text-xs uppercase text-mist tracking-[var(--tracking-overline)] mb-3 text-center">
            {t("overline")}
          </p>
          <h1 className="font-display text-frost text-center text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] leading-tight">
            {t("title")}
          </h1>
          <p className="font-serif text-mist text-center mt-4 max-w-md mx-auto text-base leading-relaxed">
            {t("subhead")}
          </p>

          {/* Trial/Plan pitch banner */}
          <div className="mt-8">
            <Suspense fallback={null}>
              <TrialPitchBanner />
            </Suspense>
          </div>

          <div className="mt-2">
            <SocialButtons flow="therapist" />
            <TherapistEmailForm />
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}

