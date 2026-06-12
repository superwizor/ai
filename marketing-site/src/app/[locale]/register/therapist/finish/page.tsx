// /register/therapist/finish — post-social-OAuth profile collection.
//
// Lands here from SocialButtons when:
//   - user clicked "Continue with Google" on /register/therapist,
//   - Firebase popup succeeded,
//   - identityClient.getUserByFirebaseUID returned NotFound (no
//     existing Superwizor row).
//
// Query params (?email=&firstName=&lastName=) come from the Google
// profile so the form can pre-fill + render a personalised greeting.
// Static-export contract: those params are read in
// TherapistFinishSection via useSearchParams(); this page is the
// server component shell.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { TherapistFinishSection } from "@/components/register/TherapistFinishSection";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "register.therapist" });
  return { title: t("finishMetaTitle") };
}

export default async function FinishTherapistPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("register.therapist");

  return (
    <>
      <Navbar variant="auth" />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-xl px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <p className="font-mono text-[10px] sm:text-xs uppercase text-mist tracking-[var(--tracking-overline)] mb-3 text-center">
            {t("overline")}
          </p>
          <h1 className="font-display text-frost text-center text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] leading-tight">
            {t("finishTitle")}
          </h1>
          <TherapistFinishSection />
        </section>
      </main>
      <Footer />
    </>
  );
}
