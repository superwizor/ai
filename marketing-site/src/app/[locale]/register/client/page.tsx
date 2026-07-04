// /register/client — the client (patient) magic-link onboarding page
// (docs/39). Dedicated landing for invited_role=PATIENT invitations:
// social login or e-mail+password, then straight into the client panel
// on the app origin. The generic /accept-invite page keeps serving
// therapist/manager invitations.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { ClientOnboardingSection } from "@/components/register/ClientOnboardingSection";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({
    locale,
    namespace: "register.clientOnboarding",
  });
  return {
    title: t("metaTitle"),
    robots: {
      index: false,
      follow: false,
    },
  };
}

export default async function ClientOnboardingPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("register.clientOnboarding");

  return (
    <>
      <Navbar variant="auth" />
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
            <ClientOnboardingSection missingTokenMessage={t("missingToken")} />
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
