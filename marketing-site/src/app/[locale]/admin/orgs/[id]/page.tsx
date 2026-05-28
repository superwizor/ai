// /admin/orgs/[id] — org detail page.
//
// docs/18 §8.2 spec: usage chart + therapist list + audit log. Usage
// chart deferred (no sessions-per-day RPC yet); the therapist list +
// audit log are surfaced via AdminGetOrganization → OrganizationDetails.

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";
import { OrgDetail } from "@/components/admin/OrgDetail";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "admin.orgDetail" });
  return { title: t("metaTitle") };
}

export default async function AdminOrgDetailPage({
  params,
}: {
  params: Promise<{ locale: string; id: string }>;
}) {
  const { locale, id } = await params;
  setRequestLocale(locale);
  return <OrgDetail orgId={id} />;
}
