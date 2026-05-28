// /register/organization/finish — post-Google-OAuth profile collection
// for the clinic-founder flow.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { OrganizationFinishForm } from "@/components/register/OrganizationFinishForm";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "register.organization" });
  return { title: t("finishMetaTitle") };
}

export default async function FinishOrganizationPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ email?: string; firstName?: string; lastName?: string }>;
}) {
  const { locale } = await params;
  const { email = "", firstName = "", lastName = "" } = await searchParams;
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
            {t("finishTitle")}
          </h1>
          <p className="font-serif text-mist text-center mt-4 max-w-lg mx-auto text-base leading-relaxed">
            {firstName
              ? t("finishSubhead", { firstName })
              : t("finishGenericSubhead")}
          </p>

          <div className="mt-10">
            <OrganizationFinishForm email={email} firstName={firstName} lastName={lastName} />
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
