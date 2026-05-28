// /admin/* shared layout: hands children to <AdminGuardAndShell>, a
// client component that handles auth gating + chrome together.
//
// We can't split the guard and the shell into two client components
// the layout wraps separately if the guard wants to inject the User
// into the shell — function children don't cross server→client. So
// the combined wrapper is the simplest reliable shape.
//
// docs/18 §7 single-role enforcement: this layer fails closed —
// non-SUPERWIZOR_ADMIN users get a 403 panel even though the route
// matches. Backend re-validates every RPC.

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";

import { AdminGuardAndShell } from "@/components/admin/AdminGuard";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "admin" });
  return { title: t("metaTitle") };
}

export default async function AdminLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <AdminGuardAndShell>{children}</AdminGuardAndShell>;
}
