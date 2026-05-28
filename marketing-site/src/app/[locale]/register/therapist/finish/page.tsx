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
// If a user reloads this page without those params (or bookmarks it)
// the form still works — they just have to retype name + don't see
// the "Hi {firstName}" personalised subhead.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { TherapistFinishForm } from "@/components/register/TherapistFinishForm";
import { getModalityCatalog } from "@/lib/clinical/modalities";

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
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ email?: string; firstName?: string; lastName?: string }>;
}) {
  const { locale } = await params;
  const { email = "", firstName = "", lastName = "" } = await searchParams;
  setRequestLocale(locale);
  const t = await getTranslations("register.therapist");
  const modalities = await getModalityCatalog();

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-xl px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <p className="font-mono text-[10px] sm:text-xs uppercase text-mist tracking-[var(--tracking-overline)] mb-3 text-center">
            {t("overline")}
          </p>
          <h1 className="font-display text-frost text-center text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] leading-tight">
            {t("finishTitle")}
          </h1>
          <p className="font-serif text-mist text-center mt-4 max-w-md mx-auto text-base leading-relaxed">
            {firstName
              ? t("finishSubhead", { firstName })
              : t("finishGenericSubhead")}
          </p>

          <div className="mt-10">
            <TherapistFinishForm
              modalities={modalities}
              email={email}
              firstName={firstName}
              lastName={lastName}
            />
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
