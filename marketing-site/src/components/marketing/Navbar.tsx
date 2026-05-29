// Top navigation for the marketing surfaces.
//
// Brand mark on the left, language switcher + "Log in" (origin-discipline
// link to app.superwizor.ai per docs/18 §5 R3) + "Sign up" CTA on the
// right. Sticky on scroll so the CTA is always one tap away.

import { useTranslations, useLocale } from "next-intl";
import { LocaleSwitcher } from "./LocaleSwitcher";

export function Navbar() {
  const t = useTranslations("nav");
  const locale = useLocale();

  // Marketing routes — PL has no prefix, EN gets /en
  const prefix = locale === "en" ? "/en" : "";

  return (
    <header className="sticky top-0 z-40 w-full border-b border-frost/10 bg-evergreen/80 backdrop-blur-md">
      <div className="mx-auto flex w-full max-w-6xl items-center justify-between px-4 sm:px-6 lg:px-8 py-3 sm:py-4">
        <a
          href={`${prefix}/`}
          className="font-display font-semibold text-frost tracking-[var(--tracking-display)] text-base sm:text-lg"
        >
          {t("brand")}
        </a>

        <nav className="flex items-center gap-2 sm:gap-3">
          <a
            href={`${prefix}/pricing`}
            className="hidden sm:inline font-display text-sm text-mist hover:text-frost transition px-3 py-2"
          >
            {t("pricing")}
          </a>
          <LocaleSwitcher />
          {/* Log-in lands on the marketing-site /login page (2026-05-29):
              the form there signs the user in on this origin, then
              routes by role — SUPERWIZOR_ADMIN to /admin/, everyone
              else to the Flutter app at superwizor-app.web.app. The
              old "cross-origin redirect to the app" CTA (§5 R3) is
              still respected for therapists; we just give them a
              landing page on the marketing origin first so admins
              have somewhere to sign in. */}
          <a
            href={`${prefix}/login`}
            className="hidden sm:inline font-display text-sm text-mist hover:text-frost transition px-3 py-2"
          >
            {t("login")}
          </a>
          <a
            href={`${prefix}/register/therapist`}
            className="inline-flex items-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-xs sm:text-sm px-3 sm:px-4 py-2 sm:py-2.5 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition"
          >
            {t("register")}
          </a>
        </nav>
      </div>
    </header>
  );
}
