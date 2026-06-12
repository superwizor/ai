// /accept-invite — invitation acceptance page.
//
// Per docs/18 §9, the invitation email contains a link like
// `https://app.superwizor.ai/accept-invite?token=<base64url>`.
// This page is the Next.js stopgap until Slice 5 brings up the
// Flutter Web shell at app.superwizor.ai. Until then,
// notification-svc's email template can target either origin and
// this route serves the same UX.
//
// Static-export contract (2026-05-28): the token used to be read
// server-side via `searchParams`, which forces dynamic rendering.
// To make the route exportable, the token now comes from
// useSearchParams() inside AcceptInviteSection (a "use client"
// component). The shell stays as a server component so the
// translated copy is still SSG-prerendered.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { AcceptInviteSection } from "@/components/register/AcceptInviteSection";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "register.acceptInvite" });
  return { title: t("metaTitle") };
}

export default async function AcceptInvitePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("register.acceptInvite");

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-xl px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <p className="font-sans text-[10px] sm:text-xs uppercase text-aurora tracking-[var(--tracking-overline)] mb-3 text-center">
            {t("overline")}
          </p>
          <h1 className="font-display text-frost text-center text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] leading-tight">
            {t("title")}
          </h1>
          <p className="font-sans text-mist text-center mt-4 max-w-md mx-auto text-base leading-relaxed">
            {t("subhead")}
          </p>

          <div className="mt-10">
            <AcceptInviteSection missingTokenMessage={t("missingToken")} />
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
