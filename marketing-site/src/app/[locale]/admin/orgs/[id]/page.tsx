// /admin/orgs/[id] — org detail page.
//
// docs/18 §8.2 spec: usage chart + therapist list + audit log. Usage
// chart deferred (no sessions-per-day RPC yet); the therapist list +
// audit log are surfaced via AdminGetOrganization → OrganizationDetails.
//
// Static-export contract (2026-05-28):
//   generateStaticParams returns a single placeholder `[id]` page per
//   locale. Firebase Hosting rewrites every /admin/orgs/<real-id>
//   path to this page (see firebase.json hosting rewrites), and the
//   OrgDetailClient component reads useParams() at runtime to fetch
//   the matching org. The literal `[id]` directory survives in
//   marketing-site/out/admin/orgs/[id]/index.html — Hosting URL-
//   encodes the brackets when serving.

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";
import { OrgDetailClient } from "@/components/admin/OrgDetailClient";
import { routing } from "@/i18n/routing";

export const dynamicParams = false;

export async function generateStaticParams() {
  // One template per locale; the literal "[id]" segment is the
  // wildcard target Firebase rewrites to.
  return routing.locales.map((locale) => ({ locale, id: "[id]" }));
}

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
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <OrgDetailClient />;
}
