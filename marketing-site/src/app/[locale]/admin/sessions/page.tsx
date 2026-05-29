// /admin/sessions — recent therapist session activity (docs/20 §11
// addition; spec from the 2026-05-29 request).
//
// Single client component. AdminGuard wraps the layout so by the time
// we render the user is confirmed SUPERWIZOR_ADMIN.

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";

import { SessionsActivityList } from "@/components/admin/SessionsActivityList";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "admin.sessions" });
  return { title: t("metaTitle") };
}

export default async function AdminSessionsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <SessionsActivityList />;
}
