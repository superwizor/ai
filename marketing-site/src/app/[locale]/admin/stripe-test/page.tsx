import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";
import { StripeTestDashboard } from "@/components/admin/StripeTestDashboard";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  return {
    title: "Testy Stripe — Admin",
    robots: {
      index: false,
      follow: false,
    },
  };
}

export default async function AdminStripeTestPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <StripeTestDashboard />;
}
