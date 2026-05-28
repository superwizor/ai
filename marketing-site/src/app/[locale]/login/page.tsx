// /login — universal sign-in page for the marketing-site origin.
//
// Replaces the previous "go to Flutter app to log in" redirect (see
// LoginForm header for the why). Routes by role after sign-in:
//   SUPERWIZOR_ADMIN → /admin/
//   anything else    → Flutter app (carrying email for prefill)
//
// Static-exportable: the form lives entirely in the client component;
// the server shell is just metadata + i18n copy.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { LoginForm } from "@/components/auth/LoginForm";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "login" });
  return { title: t("metaTitle") };
}

export default async function LoginPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("login");

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-xl px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <p className="font-mono text-[10px] sm:text-xs uppercase text-ember tracking-[var(--tracking-overline)] mb-3 text-center">
            {t("overline")}
          </p>
          <h1 className="font-display text-frost text-center text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] leading-tight">
            {t("title")}
          </h1>
          <p className="font-serif text-mist text-center mt-4 max-w-md mx-auto text-base leading-relaxed">
            {t("subhead")}
          </p>

          <div className="mt-10">
            <LoginForm />
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
