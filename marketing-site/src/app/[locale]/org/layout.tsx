// /org shared layout — OrgGuardAndShell gates on role=ORG_ADMIN
// (docs/38 §6). Fails closed; backend re-validates every RPC.

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";

import { OrgGuardAndShell } from "@/components/org/OrgGuard";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "org" });
  return {
    title: t("metaTitle"),
    robots: { index: false, follow: false },
  };
}

export default async function OrgLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <OrgGuardAndShell>{children}</OrgGuardAndShell>;
}
