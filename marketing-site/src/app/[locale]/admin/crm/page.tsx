import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";
import { CRMDashboard } from "@/components/admin/CRMDashboard";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "admin.crm" });
  return { title: t("metaTitle") };
}

export default async function AdminCRMPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <CRMDashboard />;
}
