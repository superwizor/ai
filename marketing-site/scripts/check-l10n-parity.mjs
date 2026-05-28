#!/usr/bin/env node
// scripts/check-l10n-parity.mjs
//
// Locale parity check (docs/18 §13.11). Walks messages/pl.json and
// messages/en.json, flattens both into dotted-key sets, and reports
// any keys present in one locale but missing from the other.
//
// Exits 0 on parity, 1 on drift — wire into CI and pre-commit. The
// report lists each diverging key with its locale so authors can
// localize the missing entry (or remove the now-orphaned one)
// without grep-hunting.
//
// Why not jq: nested keys + key ordering would force ugly recursive
// jq scripts. A 60-line Node walker is clearer and zero-dep.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const messagesDir = resolve(here, "..", "messages");

// Flatten a nested object to dotted keys. ICU plural / select strings
// look like normal string values to next-intl's loader; we treat
// every primitive (string, number, boolean) as a leaf.
function flatten(obj, prefix = "", out = new Map()) {
  for (const [k, v] of Object.entries(obj)) {
    const key = prefix ? `${prefix}.${k}` : k;
    if (v !== null && typeof v === "object" && !Array.isArray(v)) {
      flatten(v, key, out);
    } else {
      out.set(key, v);
    }
  }
  return out;
}

function loadLocale(locale) {
  const path = resolve(messagesDir, `${locale}.json`);
  const data = JSON.parse(readFileSync(path, "utf8"));
  return flatten(data);
}

const pl = loadLocale("pl");
const en = loadLocale("en");

const plKeys = new Set(pl.keys());
const enKeys = new Set(en.keys());

const missingInEN = [...plKeys].filter((k) => !enKeys.has(k)).sort();
const missingInPL = [...enKeys].filter((k) => !plKeys.has(k)).sort();

// Identical-value warning: spot keys that are byte-for-byte the same
// in both locales. Often a sign the author copy-pasted the EN string
// and forgot to translate it (or, for proper nouns / numbers, it's
// intentional). Report as a warning, not a failure.
const identical = [...plKeys].filter(
  (k) => enKeys.has(k) && pl.get(k) === en.get(k) && typeof pl.get(k) === "string",
);
// Strip obvious shared values (brand name, numbers, single chars) so
// the warning stays useful. Author can extend the allowlist when a
// new value is intentionally shared across locales. Entries here
// document the rationale.
const SHARED_VALUE_ALLOWLIST = new Set([
  // Brand + locale chrome.
  "Superwizor AI",
  "Polski",
  "English",
  // Polish tax-system shorthand has no English equivalent.
  "NIP",
  "EU VAT ID",
  "—",
  "PL",
  // Plan-tier names are international product nouns.
  "Solo",
  "Trial",
  // UI labels short enough that EN and PL coincide.
  "Tier",
  "Status",
  // Verbatim placeholders / examples that aren't text users should
  // re-translate (phone format, postal code format, VAT-EU example).
  "+48 123 456 789",
  "00-000",
  "PL0000000000",
  // Copyright line carries a brand-only payload.
  "© 2026 Superwizor AI",
]);
const identicalSuspect = identical
  .filter((k) => !SHARED_VALUE_ALLOWLIST.has(pl.get(k)))
  .filter((k) => {
    const v = pl.get(k);
    // Tolerate values shorter than 4 chars or numeric — likely shared
    // codes / formatting that don't need translation.
    if (typeof v !== "string") return false;
    if (v.length < 4) return false;
    if (/^[0-9.,\s%]+$/.test(v)) return false;
    return true;
  })
  .sort();

let hasError = false;
if (missingInEN.length > 0) {
  hasError = true;
  console.error(`\nMissing in en.json (${missingInEN.length}):`);
  for (const k of missingInEN) console.error(`  - ${k}`);
}
if (missingInPL.length > 0) {
  hasError = true;
  console.error(`\nMissing in pl.json (${missingInPL.length}):`);
  for (const k of missingInPL) console.error(`  - ${k}`);
}

if (identicalSuspect.length > 0) {
  console.warn(
    `\nSuspect: identical strings in both locales (${identicalSuspect.length}). ` +
      `Verify these aren't accidental copy-paste:`,
  );
  for (const k of identicalSuspect) {
    console.warn(`  - ${k} = ${JSON.stringify(pl.get(k))}`);
  }
}

if (hasError) {
  console.error("\nl10n parity check FAILED.");
  console.error(`pl.json keys: ${plKeys.size}  en.json keys: ${enKeys.size}`);
  process.exit(1);
}

console.log(
  `l10n parity OK — ${plKeys.size} keys per locale${
    identicalSuspect.length > 0 ? ` (${identicalSuspect.length} suspect identical, see above)` : ""
  }.`,
);
