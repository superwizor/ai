// Locale switcher dropdown for the marketing surfaces.
//
// Plain server-rendered <a> tags pointing at the matched-path on the
// other locale — no client JS until the user actually clicks. Matches
// the next-intl `as-needed` routing (PL no prefix, EN under /en).
//
// For now this is a simple two-button toggle; once we add DE/FR we'll
// switch to a real <select> with a popover.

"use client";

import { useLocale } from "next-intl";
import { usePathname } from "next/navigation";
import { routing } from "@/i18n/routing";

function stripLocalePrefix(path: string, locale: string): string {
  if (locale === routing.defaultLocale) return path; // already prefix-less
  // /en/foo → /foo, /en → /
  const prefix = `/${locale}`;
  if (path === prefix) return "/";
  if (path.startsWith(`${prefix}/`)) return path.slice(prefix.length);
  return path;
}

function buildLocaleHref(targetLocale: string, currentPathNoLocale: string): string {
  if (targetLocale === routing.defaultLocale) return currentPathNoLocale;
  if (currentPathNoLocale === "/") return `/${targetLocale}`;
  return `/${targetLocale}${currentPathNoLocale}`;
}

export function LocaleSwitcher() {
  const locale = useLocale();
  const rawPath = usePathname() ?? "/";
  const pathWithoutLocale = stripLocalePrefix(rawPath, locale);

  return (
    <div className="flex items-center gap-1 rounded-button border border-frost/15 bg-frost/5 p-0.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)]">
      {routing.locales.map((l) => {
        const isCurrent = l === locale;
        const href = buildLocaleHref(l, pathWithoutLocale);
        return (
          <a
            key={l}
            href={href}
            aria-current={isCurrent ? "page" : undefined}
            onClick={() => {
              // Persist the explicit choice so a future visit to "/"
              // (or any path) reads it as the user's preference. With
              // routing.localeDetection=false the middleware no longer
              // auto-redirects on browser language, but it still honours
              // NEXT_LOCALE for the in-product Link components used in
              // future surfaces. 1-year lifetime mirrors next-intl's
              // own default.
              document.cookie =
                `NEXT_LOCALE=${l}; Path=/; Max-Age=31536000; SameSite=lax`;
            }}
            className={`px-2 py-1 rounded-[3px] transition ${
              isCurrent
                ? "bg-ember text-obsidian"
                : "text-mist hover:text-frost"
            }`}
          >
            {l.toUpperCase()}
          </a>
        );
      })}
    </div>
  );
}
