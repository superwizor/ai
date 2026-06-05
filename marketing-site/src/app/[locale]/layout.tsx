// Locale-scoped root layout for the Superwizor marketing site.
//
// Route segment is `[locale]`; the middleware (src/middleware.ts) handles
// resolving the incoming URL to a supported locale. This layout:
//   - validates the param against `routing.locales` and 404s otherwise;
//   - emits `<html lang={locale}>` so screen readers + search engines see
//     the correct language attribute;
//   - wires <NextIntlClientProvider> so client components in this tree
//     can call useTranslations();
//   - feeds hreflang alternates into the page <head> so Google indexes
//     /pricing and /en/pricing as language variants of the same page.
//
// Metadata strings come from messages/{locale}.json — never hard-code
// here (docs/18 §14.5).

import type { Metadata } from "next";
import { NextIntlClientProvider, hasLocale } from "next-intl";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { notFound } from "next/navigation";
import { Montserrat, Merriweather, Roboto_Mono } from "next/font/google";
import "../globals.css";
import { routing } from "@/i18n/routing";
import { LazyAuthProvider } from "@/lib/firebase/LazyAuthProvider";
import { LazyAuthStatusBadge } from "@/lib/firebase/LazyAuthStatusBadge";

const montserrat = Montserrat({
  variable: "--font-montserrat",
  subsets: ["latin", "latin-ext"],
  display: "swap",
});

const merriweather = Merriweather({
  variable: "--font-merriweather",
  weight: ["400", "700"],
  subsets: ["latin", "latin-ext"],
  display: "swap",
});

const robotoMono = Roboto_Mono({
  variable: "--font-roboto-mono",
  subsets: ["latin", "latin-ext"],
  display: "swap",
});

// Pre-render both locale shells at build time. `setRequestLocale` (called
// in the component body) is the supported way to opt static pages into
// per-request locale resolution in Next.js 16 App Router.
export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "metadata" });

  // hreflang alternates: every page gets a canonical + one alt per
  // supported locale. PL is the default (no prefix); EN lives under /en.
  const languages: Record<string, string> = {};
  for (const l of routing.locales) {
    languages[l] = l === routing.defaultLocale ? "/" : `/${l}`;
  }

  return {
    // Template uses Next.js's "%s" placeholder, not next-intl interpolation
    // — `t()` would try to resolve {page} as an ICU MessageFormat argument
    // and throw FORMATTING_ERROR. The template is structural, not copy.
    title: { default: t("title"), template: "%s · Superwizor AI" },
    description: t("description"),
    metadataBase: new URL("https://superwizor.ai"),
    openGraph: {
      type: "website",
      locale: locale === "en" ? "en_US" : "pl_PL",
      siteName: t("ogSiteName"),
    },
    alternates: { languages },
    icons: {
      icon: [
        { url: "/favicon.ico", sizes: "32x32" },
        { url: "/favicon-192.png", sizes: "192x192", type: "image/png" },
        { url: "/favicon-512.png", sizes: "512x512", type: "image/png" },
      ],
      apple: "/apple-touch-icon.png",
    },
  };
}

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!hasLocale(routing.locales, locale)) notFound();
  setRequestLocale(locale);

  return (
    <html
      lang={locale}
      className={`${montserrat.variable} ${merriweather.variable} ${robotoMono.variable} h-full antialiased`}
    >
      <head>
        {/* Preconnect to Firebase Auth + Google API origins so that when
            the lazy-loaded AuthProvider finally requests them, the TLS
            handshake is already done. Saves ~300-400ms per origin. */}
        <link rel="preconnect" href="https://superwizor-ai-25ecd.firebaseapp.com" />
        <link rel="preconnect" href="https://apis.google.com" />
        <link rel="preconnect" href="https://www.googleapis.com" />
      </head>
      <body className="min-h-full flex flex-col">
        <NextIntlClientProvider>
          <LazyAuthProvider>
            {children}
            <LazyAuthStatusBadge />
          </LazyAuthProvider>
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
