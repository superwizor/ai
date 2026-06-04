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
  // Strip the active locale's prefix regardless of whether it's the
  // default locale. Static export emits every page under /<locale>/
  // (the as-needed prefix-strip middleware doesn't run in static
  // mode), so on a /pl/pricing/ page the locale is "pl" and the
  // path literally starts with /pl/. The earlier "return path early
  // when default locale" check produced /en/pl/pricing/ hrefs on the
  // EN button — which then 404'd because /en/pl/* paths don't exist.
  // (2026-05-28 crawl regression.)
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
    <div className="flex items-center gap-1 rounded-button border border-[#E2DED5] bg-[#F2F0EA] p-0.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)]">
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
              document.cookie =
                `NEXT_LOCALE=${l}; Path=/; Max-Age=31536000; SameSite=lax`;
            }}
            className={`px-2 py-1 rounded-[3px] font-bold transition ${
              isCurrent
                ? "bg-[#004D54] text-white shadow-sm"
                : "text-[#4E5A55] hover:text-[#1B2522]"
            }`}
          >
            {l.toUpperCase()}
          </a>
        );
      })}
    </div>
  );
}
