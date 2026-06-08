// /upgrade — Post-registration upgrade page for existing users.
//
// Plan says: "Osobna /upgrade (bez opcji free, krótki pitch + 2 plany)"
// This page is linked from:
//   1. Trial-exhausted email drip (notification-svc)
//   2. Admin panel's "trial expired" flag for Marcin
//   3. /beta users who want to continue after beta ends
//
// Apple compliance: this page lives on the WEB only,
// never linked from inside the iOS app.

import { setRequestLocale } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { UpgradeSection } from "@/components/upgrade/UpgradeSection";
import { getPlanCatalog } from "@/lib/billing/plans";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  return {
    title:
      locale === "en"
        ? "Upgrade your plan · Superwizor AI"
        : "Rozszerz swój plan · Superwizor AI",
    description:
      locale === "en"
        ? "Choose the plan that fits your practice. Continue your work with Superwizor AI."
        : "Wybierz plan dopasowany do Twojej praktyki. Kontynuuj pracę z Superwizor AI.",
  };
}

export default async function UpgradePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const catalog = await getPlanCatalog();

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <UpgradeSection catalog={catalog} locale={locale} />
      </main>
      <Footer />
    </>
  );
}
