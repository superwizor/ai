// /register/organization — clinic founder signup.
//
// Server component shell that hands off to the client form. Per
// docs/18 §13.3 the form submits to identity-svc.RegisterOrganization
// which creates the org, founder ORG_ADMIN user, Trial subscription,
// and headquarters address in one transaction.
//
// Social path (Google OAuth) lives in feature 4; this page ships the
// email/password path.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { OrganizationEmailForm } from "@/components/register/OrganizationEmailForm";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "register.organization" });
  return { title: t("metaTitle") };
}

export default async function RegisterOrganizationPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("register.organization");

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-2xl px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <p className="font-mono text-[10px] sm:text-xs uppercase text-aurora tracking-[var(--tracking-overline)] mb-3 text-center">
            {t("overline")}
          </p>
          <h1 className="font-display text-frost text-center text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] leading-tight">
            {t("title")}
          </h1>
          <p className="font-serif text-mist text-center mt-4 max-w-lg mx-auto text-base leading-relaxed">
            {t("subhead")}
          </p>

          <div className="mt-10">
            <OrganizationEmailForm />
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
