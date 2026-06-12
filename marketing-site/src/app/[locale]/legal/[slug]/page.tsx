// /legal/[slug] — Terms, Privacy, DPA pages.
//
// docs/18 §8.1: "Static legal pages — terms / privacy / DPA — Markdown
// rendered". Content lives under src/content/legal/{locale}/{slug}.md.
//
// 3 slugs × 2 locales = 6 routes, all pre-rendered as SSG via
// generateStaticParams.

import { setRequestLocale, getTranslations } from "next-intl/server";
import { notFound } from "next/navigation";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { LegalDraftBanner } from "@/components/marketing/LegalDraftBanner";
import { MarkdownRenderer } from "@/components/marketing/MarkdownRenderer";
import { routing } from "@/i18n/routing";

const SLUGS = ["terms", "privacy", "dpa"] as const;
type Slug = (typeof SLUGS)[number];

function isSlug(s: string): s is Slug {
  return (SLUGS as readonly string[]).includes(s);
}

async function loadContent(locale: string, slug: Slug): Promise<string> {
  const path = join(
    process.cwd(),
    "src",
    "content",
    "legal",
    locale,
    `${slug}.md`,
  );
  return await readFile(path, "utf8");
}

export async function generateStaticParams() {
  const out: { locale: string; slug: string }[] = [];
  for (const locale of routing.locales) {
    for (const slug of SLUGS) out.push({ locale, slug });
  }
  return out;
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string; slug: string }>;
}): Promise<Metadata> {
  const { locale, slug } = await params;
  if (!isSlug(slug)) return {};
  const t = await getTranslations({ locale, namespace: `legal.pages.${slug}` });
  return { title: t("metaTitle") };
}

export default async function LegalPage({
  params,
}: {
  params: Promise<{ locale: string; slug: string }>;
}) {
  const { locale, slug } = await params;
  if (!isSlug(slug)) notFound();
  setRequestLocale(locale);

  const t = await getTranslations("legal");
  const tPage = await getTranslations(`legal.pages.${slug}`);
  const source = await loadContent(locale, slug);

  // Date formatted with the active locale per docs/18 §14.6.
  const lastUpdated = new Intl.DateTimeFormat(
    locale === "en" ? "en-GB" : "pl-PL",
    { year: "numeric", month: "long", day: "numeric" },
  ).format(new Date("2026-06-12"));

  return (
    <>
      <Navbar />
      <LegalDraftBanner />
      <main className="flex-1">
        <article className="mx-auto w-full max-w-3xl px-4 sm:px-6 lg:px-8 py-16 sm:py-20">
          <h1 className="font-display text-frost text-4xl sm:text-5xl font-semibold tracking-[var(--tracking-display)] leading-tight">
            {tPage("title")}
          </h1>
          <p className="font-serif text-mist mt-4 text-base sm:text-lg leading-relaxed">
            {tPage("intro")}
          </p>
          <p className="mt-2 font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/60">
            {t("lastUpdated")} {lastUpdated}
          </p>

          <hr className="my-10 border-frost/10" />

          <MarkdownRenderer source={source} />
        </article>
      </main>
      <Footer />
    </>
  );
}
