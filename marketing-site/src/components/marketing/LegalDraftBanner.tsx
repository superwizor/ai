// High-visibility "this is a draft" banner shown above every legal
// page, just below the Navbar. Server component — no JS needed.
//
// Why navbar-adjacent rather than article-internal: a reader who lands
// on /legal/dpa from a Google result must see the draft warning before
// they read any of the text. Putting it inside <article> (next to the
// H1) is fine but easy to miss when scanning; this banner sits in the
// global chrome row, the same place legal-tracker apps and CMS systems
// usually put environmental warnings.

import { getTranslations } from "next-intl/server";

export async function LegalDraftBanner() {
  const t = await getTranslations("legal");
  return (
    <div
      role="alert"
      className="w-full border-b border-ember/30 bg-gradient-to-r from-ember/15 via-ember/10 to-aurora/10"
    >
      <div className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8 py-2 sm:py-2.5 text-center">
        <span className="font-mono text-[10px] sm:text-xs uppercase tracking-[var(--tracking-overline)] text-ember">
          ⚠ {t("draftBadge")}
        </span>
      </div>
    </div>
  );
}
