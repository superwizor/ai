// Public landing page for Superwizor AI.
//
// All copy comes from messages/{locale}.json (`hero`, `how`, `features`,
// `audience`, `cta`, `footer` namespaces — see docs/18 §14.5).
//
// Composition top-to-bottom: sticky Navbar → Hero → HowItWorks →
// Features → Audience → CtaBand → Footer. Each section is its own
// component so the Pricing page (feature 6) and registration pages
// (Slice 3) can reuse Navbar/Footer without duplication.

import { setRequestLocale } from "next-intl/server";

import { Navbar } from "@/components/marketing/Navbar";
import { Hero } from "@/components/marketing/Hero";
import { HowItWorks } from "@/components/marketing/HowItWorks";
import { Features } from "@/components/marketing/Features";
import { Audience } from "@/components/marketing/Audience";
import { CtaBand } from "@/components/marketing/CtaBand";
import { Footer } from "@/components/marketing/Footer";

export default async function Home({
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
        <Hero />
        <HowItWorks />
        <Features />
        <Audience />
        <CtaBand />
      </main>
      <Footer />
    </>
  );
}
