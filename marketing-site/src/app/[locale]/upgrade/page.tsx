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

import { setRequestLocale, getTranslations } from "next-intl/server";
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
  const t = await getTranslations({ locale, namespace: "metadata.upgrade" });
  return {
    title: t("title"),
    description: t("description"),
    robots: {
      index: false,
      follow: false,
    },
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
      <Navbar variant="app" />
      <main className="flex-1">
        <UpgradeSection catalog={catalog} locale={locale} />
      </main>
      <Footer />
    </>
  );
}
