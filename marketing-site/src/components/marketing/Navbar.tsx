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

  return (
    <header className="sticky top-0 z-40 w-full border-b border-[#E2DED5]/60 bg-[#FBFAF7]/85 backdrop-blur-md">
      <div className="mx-auto flex w-full max-w-[1080px] items-center justify-between px-4 sm:px-6 lg:px-8 py-3 sm:py-4">
        {/* ── Logo ──────────────────────────────────────────── */}
        {logoIsLink ? (
          <a
            href={logoHref}
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
        ) : (
          <span className="flex items-center">
            <img
              src="/assets/logo_black.svg"
              alt="Euphire"
              width={140}
              height={28}
              className="h-6 sm:h-7 w-auto"
              fetchPriority="high"
            />
          </span>
        )}

        {/* ── Navigation links ──────────────────────────────── */}
        <nav className="flex items-center gap-2 sm:gap-3">

          {/* ─── MARKETING variant: full navigation ─── */}
          {variant === "marketing" && (
            <>
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
              <a
                href={`${prefix}/kontakt`}
                className="hidden sm:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2"
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
                className="hidden sm:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2"
              >
                {t("pricing")}
              </a>
              <a
                href={`${prefix}/kontakt`}
                className="hidden sm:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2"
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
                className="hidden sm:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2"
              >
                {t("dashboard")}
              </a>
              <a
                href={`${prefix}/account`}
                className="hidden sm:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2"
              >
                {t("account")}
              </a>
              <a
                href={`${prefix}/kontakt`}
                className="hidden sm:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2"
              >
                {t("contact")}
              </a>
            </>
          )}

          {/* ─── Locale switcher: always present ─── */}
          <LocaleSwitcher />

          {/* ─── MARKETING variant: Log in + CTA ─── */}
          {variant === "marketing" && (
            <>
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
            </>
          )}

          {/* ─── APP variant: Open App CTA + Log out ─── */}
          {variant === "app" && (
            <>
              <a
                href="https://app.superwizor.ai"
                className="inline-flex items-center rounded-button bg-ember text-obsidian hover:brightness-110 font-sans uppercase tracking-[var(--tracking-label)] text-xs sm:text-sm px-3 sm:px-4 py-2 sm:py-2.5 transition active:scale-[0.98] font-bold"
              >
                {t("openApp")}
              </a>
              <LogoutButton label={t("logout")} />
            </>
          )}
        </nav>
      </div>
    </header>
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
      className="hidden sm:inline font-display text-sm font-semibold text-[#4E5A55] hover:text-[#1B2522] transition px-3 py-2"
    >
      {label}
    </button>
  );
}
