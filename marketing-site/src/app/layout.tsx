// Root layout for the Superwizor marketing site.
//
// Default lang is Polish (pl) — primary locale per docs/18 §14. Slice 2
// feature 2 (`next-intl-pl-en`) will swap this for a locale-segmented
// layout under app/[locale]/. For now the scaffold ships with pl-PL so
// it's never the case that English ships by accident.
//
// Font stack matches EuphireColors / EuphireTheme from the Flutter app:
//   - Montserrat — display + body (headings, paragraphs, CTAs)
//   - Merriweather — long-form serif for marketing reading content
//   - Roboto Mono — technical labels, timestamps, overlines
// These map to the CSS variables --font-montserrat / -merriweather /
// -roboto-mono which globals.css aliases to --font-display, --font-body,
// --font-serif, --font-mono inside @theme.

import type { Metadata } from "next";
import { Montserrat, Merriweather, Roboto_Mono } from "next/font/google";
import "./globals.css";

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

export const metadata: Metadata = {
  title: {
    default: "Superwizor AI — drugi mózg superwizora",
    template: "%s · Superwizor AI",
  },
  description:
    "Polski co-pilot dla terapeutów i superwizorów. Nagraj sesję, otrzymaj transkrypcję, raport i wskazówki w kilka minut.",
  metadataBase: new URL("https://superwizor.ai"),
  openGraph: {
    type: "website",
    locale: "pl_PL",
    siteName: "Superwizor AI",
  },
  icons: { icon: "/favicon.ico" },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="pl"
      className={`${montserrat.variable} ${merriweather.variable} ${robotoMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
