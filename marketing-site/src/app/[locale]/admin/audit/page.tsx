// /admin/audit — global cross-org audit log (docs/18 §8.2).
//
// Previously this was a placeholder pending the AdminListAuditEvents
// RPC. That RPC ships on identity-svc now; we render the real list
// via AuditLogList.

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";

import { AuditLogList } from "@/components/admin/AuditLogList";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "admin.audit" });
  return { title: t("metaTitle") };
}

export default async function AdminAuditPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <AuditLogList />;
}
