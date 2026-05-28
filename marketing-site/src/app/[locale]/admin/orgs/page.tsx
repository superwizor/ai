// /admin/orgs — paginated, searchable orgs table.
//
// docs/18 §8.2 spec: "filterable table; columns: org name, plan,
// status, therapists count, tokens used / limit, last activity".
// MVP scope drops plan + tokens columns from the visible table (the
// detail page surfaces them); search filters by legal_name via the
// backend AdminListOrganizations.search field.

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";
import { OrgsList } from "@/components/admin/OrgsList";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "admin.orgs" });
  return { title: t("metaTitle") };
}

export default async function AdminOrgsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <OrgsList />;
}
