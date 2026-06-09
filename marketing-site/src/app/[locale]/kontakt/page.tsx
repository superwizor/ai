// /kontakt — contact page with form.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { ContactForm } from "@/components/contact/ContactForm";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "contact" });
  return { title: t("metaTitle") };
}

export default async function ContactPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("contact");

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-lg px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
          <p className="font-sans text-[10px] sm:text-xs uppercase text-mist tracking-[var(--tracking-overline)] mb-3 text-center">
            {t("overline")}
          </p>
          <h1 className="font-display text-frost text-center text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] leading-tight">
            {t("heading")}
          </h1>
          <p className="font-sans text-mist text-center mt-4 max-w-md mx-auto text-base leading-relaxed">
            {t("subhead")}
          </p>

          <div className="mt-10">
            <ContactForm />
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
