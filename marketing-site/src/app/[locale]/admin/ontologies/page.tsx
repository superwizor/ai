// /admin/ontologies — Ontology Studio (plan 16 v1.2 §4.1).
//
// Dostep szerszy niz reszta /admin/*: AdminGuard przepuszcza tu takze
// role ONTOLOGY_EDITOR (wyjatek sekcyjny). Aktywacja wersji na
// produkcji pozostaje przy SUPERWIZOR_ADMIN i jest egzekwowana
// serwerowo — UI tylko chowa przycisk.

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";

import { OntologyStudio } from "@/components/admin/OntologyStudio";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "admin.ontologies" });
  return { title: t("metaTitle") };
}

export default async function AdminOntologiesPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <OntologyStudio />;
}
