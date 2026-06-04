// Public landing page for Superwizor AI.
//
// All copy comes from messages/{locale}.json.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";
import { getPlanCatalog } from "@/lib/billing/plans";

import { TopBar } from "@/components/marketing/TopBar";
import { Navbar } from "@/components/marketing/Navbar";
import { Hero } from "@/components/marketing/Hero";
import { BrandStatement } from "@/components/marketing/BrandStatement";
import { Problem } from "@/components/marketing/Problem";
import { HowItWorks } from "@/components/marketing/HowItWorks";
// import { Differentiator } from "@/components/marketing/Differentiator";
import { Features } from "@/components/marketing/Features";
// import { ScreenshotGallery } from "@/components/marketing/ScreenshotGallery";
import { Security } from "@/components/marketing/Security";
import { CtaMid } from "@/components/marketing/CtaMid";
import { Audience } from "@/components/marketing/Audience";
import { PricingCards } from "@/components/marketing/PricingCards";
import { Faq } from "@/components/marketing/Faq";
import { CtaBand } from "@/components/marketing/CtaBand";
import { Footer } from "@/components/marketing/Footer";

import { AiSecurityBand } from "@/components/marketing/AiSecurityBand";
import { AiValue } from "@/components/marketing/AiValue";
import { ScrollEffects } from "@/components/marketing/ScrollEffects";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;

  const title =
    locale === "en"
      ? "Superwizor AI — AI copilot for psychotherapy"
      : "Superwizor AI — AI copilot dla psychoterapii";
  const description =
    locale === "en"
      ? "Record your therapy session, get a clinical report in minutes. A tool built for psychotherapy — designed with care and attention to your needs. EU servers, GDPR compliant."
      : "Nagraj sesję terapeutyczną, otrzymaj raport kliniczny w kilka minut. Narzędzie stworzone dla psychoterapii. Z uwagą i starannością na Twoje potrzeby. Serwery w UE, zgodność z RODO.";

  return {
    title,
    description,
    openGraph: {
      title,
      description,
      type: "website",
      locale: locale === "en" ? "en_US" : "pl_PL",
      siteName: "Superwizor AI",
      images: [
        {
          url: "/og-image.png",
          width: 1200,
          height: 630,
          alt: "Superwizor AI",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: ["/og-image.png"],
    },
  };
}

export default async function Home({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const catalog = await getPlanCatalog();
  const tb = await getTranslations("b.pricing");

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "SoftwareApplication",
            name: "Superwizor AI",
            applicationCategory: "HealthApplication",
            operatingSystem: "iOS, Web",
            url: "https://superwizor.ai",
            description:
              locale === "en"
                ? "AI copilot for psychotherapy. Record sessions, get clinical reports in minutes."
                : "AI copilot dla psychoterapii. Nagraj sesję, otrzymaj raport kliniczny w kilka minut.",
            offers: {
              "@type": "Offer",
              price: "0",
              priceCurrency: "PLN",
              description: locale === "en" ? "Free tier available" : "Darmowy plan dostępny",
            },
            publisher: {
              "@type": "Organization",
              name: "Euphire",
              url: "https://euphire.pl",
              sameAs: [
                "https://www.facebook.com/EUPHIRE/",
                "https://www.instagram.com/euphire_pl/",
                "https://www.youtube.com/euphire",
                "https://www.tiktok.com/@euphire7",
              ],
            },
          }),
        }}
      />
      <TopBar />
      <Navbar />
      <main className="flex-1">
        <ScrollEffects />
        {/* DARK */}
        <Hero />
        {/* LIGHT */}
        <Features />
        {/* DARK — AI Security */}
        <AiSecurityBand />
        {/* LIGHT */}
        <HowItWorks />
        {/* DARK */}
        <Problem />
        {/* LIGHT */}
        <BrandStatement />
        {/* DARK — security pipeline */}
        <Security />
        {/* LIGHT — audience cards */}
        <Audience />
        {/* DARK — AI value proposition */}
        <AiValue />
        {/* LIGHT — Pricing */}
        <section id="cennik" className="w-full py-24 sm:py-28 bg-gradient-to-b from-[#FBFAF7] to-[#F2F0EA] text-[#1B2522] border-y border-[#E2DED5]/60">
          <div className="mx-auto w-full max-w-[1120px] px-6">
            <h2 className="font-display text-[#004D54] text-center text-3xl sm:text-4xl font-bold tracking-tight leading-tight max-w-2xl mx-auto mb-3">
              {tb("heading")}
            </h2>
            <div className="mt-10">
              <PricingCards catalog={catalog} />
            </div>
          </div>
        </section>
        {/* LIGHT */}
        <Faq />
        {/* DARK — Final CTA with breathing rings (from Version A) */}
        <CtaBand />
      </main>
      <Footer />
    </>
  );
}
