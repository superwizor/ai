import { setRequestLocale } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { PatientLanding } from "@/components/patient/PatientLanding";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  return {
    title:
      locale === "en"
        ? "Personal Therapy Assistant · Superwizor AI"
        : "Osobisty Asystent Terapii · Superwizor AI",
    description:
      locale === "en"
        ? "Organize your therapy insights, track patterns, and prepare for sessions securely with AI built for privacy."
        : "Uporządkuj swoje wnioski z sesji, śledź wzorce i przygotuj się do spotkań z bezpiecznym asystentem AI.",
  };
}

export default async function PatientPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  return (
    <>
      <Navbar />
      <main className="flex-1">
        <PatientLanding locale={locale} />
      </main>
      <Footer />
    </>
  );
}
