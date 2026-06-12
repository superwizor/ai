// /beta — Beta tester signup landing page.
//
// 50 spots, 120 sessions/mo x 2 months, free.
// Users create an account the same way as trial, but with beta plan.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { BetaSignupSection } from "@/components/beta/BetaSignupSection";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  return {
    title:
      locale === "en"
        ? "Beta Program · Superwizor AI"
        : "Program Beta · Superwizor AI",
    description:
      locale === "en"
        ? "Join our exclusive beta program. 120 sessions/month for 2 months, free."
        : "Dołącz do programu beta. 120 sesji miesięcznie przez 2 miesiące, za darmo.",
  };
}

export default async function BetaPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <BetaSignupSection locale={locale} />
      </main>
      <Footer />
    </>
  );
}
