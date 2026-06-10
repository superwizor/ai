// /admin/prompts — Admin Prompt Studio (docs/31): versioned editing of
// the per-modality report prompts. AdminGuard wraps the layout, so by
// the time this renders the user is confirmed SUPERWIZOR_ADMIN.

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";

import { PromptStudio } from "@/components/admin/PromptStudio";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "admin.prompts" });
  return { title: t("metaTitle") };
}

export default async function AdminPromptsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <PromptStudio />;
}
