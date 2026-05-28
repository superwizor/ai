// /admin/users — global users list per docs/18 §13.8.

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";
import { UsersList } from "@/components/admin/UsersList";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "admin.users" });
  return { title: t("metaTitle") };
}

export default async function AdminUsersPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <UsersList />;
}
