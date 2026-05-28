// /admin/audit — global audit log placeholder.
//
// docs/18 §8.2 calls for a "global cross-org audit history
// (`audit_events` table); filterable by actor, action, date range".
// The identity-svc proto doesn't yet expose a ListAuditEvents RPC —
// audit data is currently scoped to one org and surfaced via
// AdminGetOrganization.recent_audit (Slice 4 feature 4).
//
// This page lands the navigation entry (sidebar item from feature 2
// already links here) with an honest "coming soon" placeholder.
// When the RPC ships, swap this for a real list page mirroring
// the OrgsList pattern.

import type { Metadata } from "next";
import { setRequestLocale, getTranslations } from "next-intl/server";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "admin.audit" });
  return { title: t("metaTitle") };
}

export default async function AdminAuditPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("admin.audit");
  const prefix = locale === "en" ? "/en" : "";

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8">
      <h1 className="font-display text-frost text-2xl sm:text-3xl font-semibold tracking-[var(--tracking-display)]">
        {t("title")}
      </h1>
      <p className="font-serif text-mist mt-1 text-sm">{t("subhead")}</p>

      <div className="mt-8 rounded-glass border border-glass-border/40 bg-frost/[0.04] p-6 max-w-2xl">
        <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember">
          {t("placeholderTitle")}
        </p>
        <p className="font-serif text-mist mt-3 text-sm leading-relaxed">
          {t("placeholderBody")}
        </p>
        <a
          href={`${prefix}/admin/orgs`}
          className="mt-5 inline-flex items-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-xs px-4 py-2 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition"
        >
          {t("goToOrgs")}
        </a>
      </div>
    </div>
  );
}
