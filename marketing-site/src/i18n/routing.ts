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
});

export type Locale = (typeof routing.locales)[number];
