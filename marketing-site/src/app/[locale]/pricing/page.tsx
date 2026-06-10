// /pricing — public pricing page.
//
// docs/18 §8.1: "Trial (free, 3 tokens) / SOLO / PRO / CLINIC (read from
// subscription_plans)". We fetch the plan catalog server-side via
// `getPlanCatalog()` which today returns a static catalog mirroring
// migration 000029 — the same function will be swapped to call
// `billingClient.listSubscriptionPlans({})` once that RPC ships.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { PricingCards } from "@/components/marketing/PricingCardsDetailed";
import { getPlanCatalog } from "@/lib/billing/plans";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "pricing" });
  return { title: t("metaTitle") };
}

export default async function PricingPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("pricing");
  const catalog = await getPlanCatalog();

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
          <p className="font-mono text-[10px] sm:text-xs uppercase text-mist tracking-[var(--tracking-overline)] mb-3 text-center">
            {t("overline")}
          </p>
          <h1 className="font-display text-frost text-center text-4xl sm:text-5xl font-semibold tracking-[var(--tracking-display)] max-w-2xl mx-auto leading-tight">
            {t("heading")}
          </h1>
          <p className="font-serif text-mist text-center mt-5 max-w-2xl mx-auto text-base sm:text-lg leading-relaxed">
            {t("subhead")}
          </p>

          <div className="mt-12">
            <PricingCards catalog={catalog} />
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
