// /dashboard — Post-login hub page.
//
// Plan: "dwa panele: apka + konto"
// Simple hub that lets the logged-in user choose:
//   1. Open the Flutter app (Kartoteki / sessions)
//   2. Go to /account (manage profile, org, subscription)
//
// This is the redirect target after successful registration/checkout.
// Uses client-side auth to show the user's name and guide them.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { DashboardHub } from "@/components/dashboard/DashboardHub";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "metadata.dashboard" });
  return {
    title: t("title"),
    description: t("description"),
    robots: {
      index: false,
      follow: false,
    },
  };
}

export default async function DashboardPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  return (
    <>
      <Navbar variant="app" />
      <main className="flex-1">
        <DashboardHub locale={locale} />
      </main>
      <Footer />
    </>
  );
}
