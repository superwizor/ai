// /auth/action — custom action handler for Firebase Auth (email verification, password reset)
//
// Replaces Firebase's default, unstyled handler. This is a locale-aware page
// that mounts the AuthActionContent client component, ensuring the user gets
// a premium, branded experience.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";
import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { AuthActionContent } from "@/components/auth/AuthActionContent";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "authAction" });
  return { title: t("metaTitle") };
}

export default async function AuthActionPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  return (
    <>
      <Navbar variant="auth" />
      <main className="flex-1 flex flex-col justify-center items-center py-12 sm:py-16 min-h-[70vh]">
        <AuthActionContent />
      </main>
      <Footer />
    </>
  );
}
