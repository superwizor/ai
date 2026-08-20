// /admin/ai-chat — AI chat kill switch and configuration (ADR 62 §11,
// plan docs/63 F5). AdminGuard wraps the layout, so by the time this
// renders the caller is confirmed SUPERWIZOR_ADMIN.

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";

import { ChatControls } from "@/components/admin/ChatControls";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "admin.aiChat" });
  return { title: t("metaTitle") };
}

export default async function AdminAiChatPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <ChatControls />;
}
