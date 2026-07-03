// /admin/orgs/new — org provisioning wizard (docs/38 §5.1).

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";
import { OrgCreateWizard } from "@/components/admin/OrgCreateWizard";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "admin.orgCreate" });
  return { title: t("metaTitle") };
}

export default async function AdminOrgCreatePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <OrgCreateWizard />;
}
