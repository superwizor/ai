// /accept-invite — invitation acceptance page.
//
// Per docs/18 §9, the invitation email contains a link like
// `https://app.superwizor.ai/accept-invite?token=<base64url>`.
// This page is the Next.js stopgap until Slice 5 brings up the
// Flutter Web shell at app.superwizor.ai. Until then,
// notification-svc's email template can target either origin and
// this route serves the same UX.
//
// Server component shell: validates the presence of ?token=, then
// hands the raw token to the client form for AcceptInvitation
// submission. We do NOT verify the token server-side because there's
// no GetInvitationByToken RPC — submission is the verification.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { AcceptInviteForm } from "@/components/register/AcceptInviteForm";
import { getModalityCatalog } from "@/lib/clinical/modalities";

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
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ token?: string }>;
}) {
  const { locale } = await params;
  const { token } = await searchParams;
  setRequestLocale(locale);
  const t = await getTranslations("register.acceptInvite");
  const modalities = await getModalityCatalog();

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-xl px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <p className="font-mono text-[10px] sm:text-xs uppercase text-aurora tracking-[var(--tracking-overline)] mb-3 text-center">
            {t("overline")}
          </p>
          <h1 className="font-display text-frost text-center text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] leading-tight">
            {t("title")}
          </h1>
          <p className="font-serif text-mist text-center mt-4 max-w-md mx-auto text-base leading-relaxed">
            {t("subhead")}
          </p>

          <div className="mt-10">
            {token ? (
              <AcceptInviteForm token={token} modalities={modalities} />
            ) : (
              <p
                role="alert"
                className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-serif text-sm text-frost text-center"
              >
                {t("missingToken")}
              </p>
            )}
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
