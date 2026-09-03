// /admin/discount-codes — discount-code campaigns (docs/70 §6.3).
//
// Table + create/edit/deactivate modals + per-code redemption log, all
// client-side against billing-svc's Admin*DiscountCode RPCs. The route
// itself is a thin server shell, same as /admin/orgs and /admin/users.

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";
import { DiscountCodesList } from "@/components/admin/DiscountCodesList";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "admin.discountCodes" });
  return { title: t("metaTitle") };
}

export default async function AdminDiscountCodesPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <DiscountCodesList />;
}
