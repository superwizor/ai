// Locale routing for the Superwizor marketing site.
//
// Contract anchored in docs/18 §14:
//   - PL primary (no prefix: `/`, `/pricing`)
//   - EN secondary (prefixed: `/en`, `/en/pricing`)
//   - "as-needed" routing mode
//
// The `locales` array MUST stay in lockstep with files under
// `marketing-site/messages/*.json` and the Flutter ARB files in
// `flutter-app/superwizor/lib/l10n/`. Adding a new locale = add a
// JSON file + add a code here; no other code change.

import { defineRouting } from "next-intl/routing";

export const routing = defineRouting({
  locales: ["pl", "en"],
  defaultLocale: "pl",
  localePrefix: "as-needed",
  // Why localeDetection is disabled:
  //
  // With it enabled (the next-intl default), the middleware redirects
  // bare paths to the locale chosen by Accept-Language. That sounds
  // helpful but it traps users whose browser language disagrees with
  // the URL — e.g. an English-speaking visitor on /en clicks the PL
  // switcher (href="/"), middleware sees Accept-Language=en and 307s
  // them straight back to /en. The PL button reads as broken.
  //
  // Our product is Polish-first; "/" always serves PL by design, and
  // EN visitors opt in via the /en prefix or the locale switcher. The
  // explicit URL choice should win over the browser's language list.
  // See docs/18 §14 for the localization contract.
  localeDetection: false,
});

export type Locale = (typeof routing.locales)[number];
