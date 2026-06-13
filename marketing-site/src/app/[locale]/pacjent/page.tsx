import { setRequestLocale, getTranslations } from "next-intl/server";
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
  const t = await getTranslations({ locale, namespace: "metadata.pacjent" });

  const title = t("title");
  const description = t("description");
  const keywords = t("keywords");

  return {
    title,
    description,
    keywords,
    openGraph: {
      title,
      description,
      type: "website",
      locale: locale === "en" ? "en_US" : "pl_PL",
      siteName: "Superwizor AI",
      images: [
        {
          url: "/og-image.png",
          width: 1200,
          height: 630,
          alt: "Superwizor AI",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: ["/og-image.png"],
    },
    other: {
      "geo.region": "PL-MZ",
      "geo.placename": "Warszawa",
      "geo.position": "52.2297;21.0122",
      "ICBM": "52.2297, 21.0122",
    },
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
