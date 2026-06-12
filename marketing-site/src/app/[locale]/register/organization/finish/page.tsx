// /register/organization/finish — post-Google-OAuth profile collection
// for the clinic-founder flow.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { OrganizationFinishSection } from "@/components/register/OrganizationFinishSection";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "register.organization" });
  return { title: t("finishMetaTitle") };
}

// Static-export contract: see /register/therapist/finish/page.tsx
// for the rationale. Dynamic personalisation moved client-side.
export default async function FinishOrganizationPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("register.organization");

  return (
    <>
      <Navbar variant="auth" />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-2xl px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <p className="font-mono text-[10px] sm:text-xs uppercase text-aurora tracking-[var(--tracking-overline)] mb-3 text-center">
            {t("overline")}
          </p>
          <h1 className="font-display text-frost text-center text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] leading-tight">
            {t("finishTitle")}
          </h1>
          <OrganizationFinishSection />
        </section>
      </main>
      <Footer />
    </>
  );
}
