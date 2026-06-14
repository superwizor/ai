// /account — therapist/org-admin account management.
//
// Landing destination after marketing-site login for any non-admin
// role. SUPERWIZOR_ADMIN keeps going to /admin/.
//
// Static-export friendly: the page shell is a server component;
// AccountSections does the auth + data work client-side. AccountGuard
// bounces unauthenticated visitors to /login.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { AccountGuard } from "@/components/account/AccountGuard";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "metadata.account" });
  return {
    title: t("title"),
    description: t("description"),
    robots: {
      index: false,
      follow: false,
    },
  };
}

export default async function AccountPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("account");

  return (
    <>
      <Navbar variant="app" />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-2xl px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <h1 className="font-sans text-[#F2F0EA] text-3xl sm:text-4xl font-bold tracking-tight leading-tight">
            {t("title")}
          </h1>
          <p className="font-sans text-[#8FA5A0] mt-3 text-base leading-relaxed">
            {t("subhead")}
          </p>
          <div className="mt-10">
            <AccountGuard />
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
