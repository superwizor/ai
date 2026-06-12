"use client";

// Top navigation for the marketing surfaces.
//
// Brand mark on the left, language switcher + "Log in" (origin-discipline
// link to app.superwizor.ai per docs/18 §5 R3) + "Sign up" CTA on the
// right. Sticky on scroll so the CTA is always one tap away.

import { useTranslations, useLocale } from "next-intl";
import { usePathname } from "next/navigation";
import { LocaleSwitcher } from "./LocaleSwitcher";

export function Navbar() {
  const t = useTranslations("nav");
  const locale = useLocale();
  const pathname = usePathname() ?? "";

  // Marketing routes — PL has no prefix, EN gets /en
  const prefix = locale === "en" ? "/en" : "";

  // Check if we are on the homepage to keep relative anchor links for Playwright E2E tests
  const isHome =
    pathname === "/" ||
    pathname === "/pl" ||
    pathname === "/en" ||
    pathname === "/pl/" ||
    pathname === "/en/";

  const cennikHref = isHome ? "#cennik" : `${prefix}/#cennik`;
  const jakHref = isHome ? "#jak" : `${prefix}/#jak`;
  const bezpieczenstwoHref = isHome ? "#bezpieczenstwo" : `${prefix}/#bezpieczenstwo`;

  return (
    <header className="sticky top-0 z-40 w-full border-b border-[#E2DED5]/60 bg-[#FBFAF7]/85 backdrop-blur-md">
      <div className="mx-auto flex w-full max-w-[1080px] items-center justify-between px-4 sm:px-6 lg:px-8 py-3 sm:py-4">
        <a
          href={`${prefix}/`}
          className="flex items-center"
        >
          <img
            src="/assets/logo_black.svg"
            alt="Euphire"
            width={140}
            height={28}
            className="h-6 sm:h-7 w-auto"
            fetchPriority="high"
          />
        </a>

        <nav className="flex items-center gap-2 sm:gap-3">
          <a
            href={jakHref}
            className="hidden sm:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2"
          >
            {locale === "en" ? "How it works" : "Jak to działa"}
          </a>
          <a
            href={cennikHref}
            className="hidden sm:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2"
          >
            {t("pricing")}
          </a>
          <a
            href={bezpieczenstwoHref}
            className="hidden sm:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2"
          >
            {t("security")}
          </a>
          <LocaleSwitcher />
          {/* Log-in lands on the marketing-site /login page (2026-05-29) */}
          <a
            href={`${prefix}/login`}
            className="hidden sm:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2"
          >
            {t("login")}
          </a>
          <a
            href={cennikHref}
            className="inline-flex items-center rounded-button bg-ember text-obsidian hover:brightness-110 font-sans uppercase tracking-[var(--tracking-label)] text-xs sm:text-sm px-3 sm:px-4 py-2 sm:py-2.5 transition active:scale-[0.98] font-bold"
          >
            {t("register")}
          </a>
        </nav>
      </div>
    </header>
  );
}
