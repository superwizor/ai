"use client";

// Top navigation for the marketing surfaces.
//
// Accepts a `variant` prop that controls which links are shown:
//   - "marketing" (default): full nav — How it works, Pricing, Security, Log in, CTA
//   - "auth": simplified for login/register — logo + locale + Pricing link
//   - "tunnel": minimal for post-registration steps — logo + locale only
//   - "app": authenticated user nav — Dashboard, Account, Open App, Log out
//
// Brand mark on the left, contextual links + language switcher on the right.
// Sticky on scroll so the CTA is always one tap away.

import { useState, useEffect } from "react";
import { useTranslations, useLocale } from "next-intl";
import { usePathname } from "next/navigation";
import { LocaleSwitcher } from "./LocaleSwitcher";

export type NavbarVariant = "marketing" | "auth" | "tunnel" | "app";

export function Navbar({ variant = "marketing" }: { variant?: NavbarVariant }) {
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

  // Logo link: in app variant, go to dashboard; otherwise go to home
  const logoHref = variant === "app" ? `${prefix}/dashboard` : `${prefix}/`;

  // In tunnel mode, logo is non-clickable (no href) to prevent user from leaving
  const logoIsLink = variant !== "tunnel";

  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [showFloating, setShowFloating] = useState(false);

  useEffect(() => {
    if (variant !== "marketing") return;
    const handleScroll = () => {
      const cennikEl = document.getElementById("cennik");
      let isOverCennik = false;
      if (cennikEl) {
        const rect = cennikEl.getBoundingClientRect();
        isOverCennik = rect.top < window.innerHeight - 100 && rect.bottom > 100;
      }

      const threshold = document.documentElement.scrollHeight - window.innerHeight - 250;
      const isNearBottom = window.scrollY > threshold;

      setShowFloating(window.scrollY > 400 && !isOverCennik && !isNearBottom && !isMobileMenuOpen);
    };
    window.addEventListener("scroll", handleScroll, { passive: true });
    handleScroll();
    return () => window.removeEventListener("scroll", handleScroll);
  }, [variant, isMobileMenuOpen]);

  return (
    <>
      <header className="sticky top-0 z-40 w-full border-b border-[#E2DED5]/60 bg-[#FBFAF7]/85 backdrop-blur-md">
      <div className="mx-auto flex w-full max-w-[1080px] items-center justify-between px-3 sm:px-6 lg:px-8 py-2.5 sm:py-4">
        {/* ── Logo ──────────────────────────────────────────── */}
        {logoIsLink ? (
          <a
            href={logoHref}
            className="flex items-center shrink-0 transition-transform duration-200 active:scale-[0.98] group"
          >
            <span className="font-display text-base sm:text-lg md:text-xl tracking-tight select-none whitespace-nowrap flex items-center gap-1 sm:gap-1.5">
              <span className="bg-gradient-to-b from-[#1B2522] to-[#1B2522]/60 bg-clip-text text-transparent font-semibold">
                Superwizor
              </span>
              <span className="bg-[#004D54] text-white text-[9.5px] sm:text-[10.5px] md:text-[11px] font-semibold px-2 sm:px-2.5 py-0.5 sm:py-1 rounded-[5px] shadow-sm tracking-widest leading-none transition-all duration-300 group-hover:shadow-[0_2px_8px_rgba(0,77,84,0.35)] group-hover:brightness-110 uppercase flex items-center gap-1 relative -top-[3px] sm:-top-[4px] shrink-0">
                <span>AI</span>
                <svg className="w-2.5 h-2.5 text-[#fcae2f] fill-current shrink-0" viewBox="0 0 24 24">
                  <path d="M12 2 L14.8 9.2 L22 12 L14.8 14.8 L12 22 L9.2 14.8 L2 12 L9.2 9.2 Z" />
                </svg>
              </span>
            </span>
          </a>
        ) : (
          <span className="flex items-center shrink-0">
            <span className="font-display text-base sm:text-lg md:text-xl tracking-tight select-none whitespace-nowrap flex items-center gap-1 sm:gap-1.5">
              <span className="bg-gradient-to-b from-[#1B2522] to-[#1B2522]/60 bg-clip-text text-transparent font-semibold">
                Superwizor
              </span>
              <span className="bg-[#004D54] text-white text-[9.5px] sm:text-[10.5px] md:text-[11px] font-semibold px-2 sm:px-2.5 py-0.5 sm:py-1 rounded-[5px] shadow-sm tracking-widest leading-none uppercase flex items-center gap-1 relative -top-[3px] sm:-top-[4px] shrink-0">
                <span>AI</span>
                <svg className="w-2.5 h-2.5 text-[#fcae2f] fill-current shrink-0" viewBox="0 0 24 24">
                  <path d="M12 2 L14.8 9.2 L22 12 L14.8 14.8 L12 22 L9.2 14.8 L2 12 L9.2 9.2 Z" />
                </svg>
              </span>
            </span>
          </span>
        )}

        {/* ── Navigation links ──────────────────────────────── */}
        <nav className="flex items-center gap-1.5 sm:gap-3">

          {/* ─── MARKETING variant: full navigation ─── */}
          {variant === "marketing" && (
            <>
              <a
                href={jakHref}
                className="hidden md:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2 whitespace-nowrap"
              >
                {locale === "en" ? "How it works" : "Jak to działa"}
              </a>
              <a
                href={cennikHref}
                className="hidden md:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2 whitespace-nowrap"
              >
                {t("pricing")}
              </a>
              <a
                href={`${prefix}/kontakt`}
                className="hidden md:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2 whitespace-nowrap"
              >
                {t("contact")}
              </a>
            </>
          )}

          {/* ─── AUTH variant: Pricing + Contact ─── */}
          {variant === "auth" && (
            <>
              <a
                href={`${prefix}/pricing`}
                className="hidden md:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2 whitespace-nowrap"
              >
                {t("pricing")}
              </a>
              <a
                href={`${prefix}/kontakt`}
                className="hidden md:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2 whitespace-nowrap"
              >
                {t("contact")}
              </a>
            </>
          )}

          {/* ─── APP variant: Dashboard, Account, Open App ─── */}
          {variant === "app" && (
            <>
              <a
                href={`${prefix}/dashboard`}
                className="hidden md:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2 whitespace-nowrap"
              >
                {t("dashboard")}
              </a>
              <a
                href={`${prefix}/account`}
                className="hidden md:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2 whitespace-nowrap"
              >
                {t("account")}
              </a>
              <a
                href={`${prefix}/kontakt`}
                className="hidden md:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2 whitespace-nowrap"
              >
                {t("contact")}
              </a>
            </>
          )}

          {/* ─── Locale switcher: always present ─── */}
          <LocaleSwitcher />

          {/* ─── Hamburger Menu Button (mobile only) ─── */}
          {variant === "marketing" && (
            <button
              onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
              className="md:hidden p-2 text-[#4E5A55] hover:text-[#1B2522] focus:outline-none transition active:scale-95"
              aria-label="Toggle menu"
            >
              {isMobileMenuOpen ? (
                <svg className="w-5.5 h-5.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              ) : (
                <svg className="w-5.5 h-5.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4 8h16M4 16h16" />
                </svg>
              )}
            </button>
          )}

          {/* ─── MARKETING variant: Log in + CTA ─── */}
          {variant === "marketing" && (
            <>
              {/* Log-in lands on the marketing-site /login page (2026-05-29) */}
              <a
                href={`${prefix}/login`}
                className="hidden md:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2 whitespace-nowrap"
              >
                {t("login")}
              </a>
              <a
                href={cennikHref}
                className="hidden md:inline-flex items-center rounded-[5px] bg-ember text-obsidian hover:brightness-110 font-sans uppercase tracking-[var(--tracking-label)] text-xs sm:text-sm px-3 sm:px-4 py-2 sm:py-2.5 transition active:scale-[0.98] font-bold whitespace-nowrap"
              >
                {t("register")}
              </a>
            </>
          )}

          {/* ─── APP variant: Open App CTA + Log out ─── */}
          {variant === "app" && (
            <>
              <a
                href="https://app.superwizor.ai"
                className="inline-flex items-center rounded-[5px] bg-ember text-obsidian hover:brightness-110 font-sans uppercase tracking-[var(--tracking-label)] text-xs sm:text-sm px-3 sm:px-4 py-2 sm:py-2.5 transition active:scale-[0.98] font-bold whitespace-nowrap"
              >
                {t("openApp")}
              </a>
              <LogoutButton label={t("logout")} />
            </>
          )}
        </nav>
      </div>

      {/* ── Mobile menu dropdown ──────────────────────────── */}
      {variant === "marketing" && isMobileMenuOpen && (
        <div className="absolute top-full left-0 right-0 bg-[#FBFAF7] border-b border-[#E2DED5]/60 shadow-xl px-6 py-6 md:hidden flex flex-col gap-5 z-30">
          <a
            href={jakHref}
            onClick={() => setIsMobileMenuOpen(false)}
            className="font-display text-base font-semibold text-[#4E5A55] hover:text-[#1B2522] transition py-2 border-b border-[#E2DED5]/30"
          >
            {locale === "en" ? "How it works" : "Jak to działa"}
          </a>
          <a
            href={cennikHref}
            onClick={() => setIsMobileMenuOpen(false)}
            className="font-display text-base font-semibold text-[#4E5A55] hover:text-[#1B2522] transition py-2 border-b border-[#E2DED5]/30"
          >
            {t("pricing")}
          </a>
          <a
            href={`${prefix}/kontakt`}
            onClick={() => setIsMobileMenuOpen(false)}
            className="font-display text-base font-semibold text-[#4E5A55] hover:text-[#1B2522] transition py-2 border-b border-[#E2DED5]/30"
          >
            {t("contact")}
          </a>
          <a
            href={`${prefix}/login`}
            onClick={() => setIsMobileMenuOpen(false)}
            className="font-display text-base font-semibold text-[#4E5A55] hover:text-[#1B2522] transition py-2 border-b border-[#E2DED5]/30"
          >
            {t("login")}
          </a>
          <a
            href={cennikHref}
            onClick={() => setIsMobileMenuOpen(false)}
            className="mt-2 w-full text-center py-3 rounded-[5px] bg-ember text-obsidian hover:brightness-110 font-sans uppercase tracking-[var(--tracking-label)] text-sm font-bold shadow-sm transition active:scale-[0.98]"
          >
            {t("register")}
          </a>
        </div>
      )}
    </header>

    {/* ── Floating Mobile CTA ────────────────────────────── */}
    {variant === "marketing" && (
      <div
        className={`fixed bottom-5 left-4 right-4 z-50 md:hidden transition-all duration-300 transform ${
          showFloating
            ? "opacity-100 translate-y-0 pointer-events-auto"
            : "opacity-0 translate-y-4 pointer-events-none"
        }`}
      >
        <a
          href={cennikHref}
          className="w-full inline-flex items-center justify-center rounded-[5px] bg-ember text-obsidian hover:brightness-110 font-sans uppercase tracking-[var(--tracking-label)] text-sm font-bold py-3.5 shadow-[0_8px_30px_rgba(252,174,47,0.35)] active:scale-[0.98] transition"
        >
          {t("register")}
        </a>
      </div>
    )}
    </>
  );
}

// ── Logout button (client-side, lazy-loads Firebase) ────────────
function LogoutButton({ label }: { label: string }) {
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  const handleLogout = async () => {
    try {
      const { getAuth, signOut } = await import("firebase/auth");
      const auth = getAuth();
      await signOut(auth);
    } catch {
      // Silently handle — user may not have Firebase loaded
    }
    window.location.href = `${prefix}/`;
  };

  return (
    <button
      type="button"
      onClick={handleLogout}
      className="hidden md:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2"
    >
      {label}
    </button>
  );
}
