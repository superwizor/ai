// Locale dispatcher for Playwright specs. Each spec calls `forLocale(t)`
// where `t` is a tiny string map per locale, and gets back the value
// for the project currently running. Two complementary helpers:
//
//   urlPrefix(testInfo)  — "" for PL, "/en" for EN. Tests goto
//                          `${prefix}/register/therapist` etc.
//   forLocale(map)       — must be called from inside a test; reads
//                          test.info().project.name internally.
//
// The dual-locale fan-out lives in playwright.config.ts. Each test
// stays single-file; consumer specs branch on `forLocale({pl, en})`
// rather than duplicating spec bodies.

import { test } from "@playwright/test";

export type LocaleKey = "pl" | "en";

export function localeKey(): LocaleKey {
  const name = test.info().project.name;
  // chromium-en → "en"; chromium-pl → "pl"; anything else → "pl".
  if (name.endsWith("-en")) return "en";
  return "pl";
}

export function urlPrefix(): string {
  return localeKey() === "en" ? "/en" : "";
}

export function forLocale<T>(map: Record<LocaleKey, T>): T {
  return map[localeKey()];
}
