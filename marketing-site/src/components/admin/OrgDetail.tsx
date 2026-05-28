// Admin org detail — AdminGetOrganization → renders the org card,
// therapists list, and recent-audit panel side-by-side.
//
// docs/18 §8.2 spec section that this maps to:
//   "Org detail — usage history chart (sessions/day, tokens/period),
//    therapist list, audit log for this org."
//
// Usage chart is deferred to a follow-up (needs sessions-per-day RPC
// the proto doesn't surface yet). Therapist list + audit panel are
// the two halves of the live data we DO have via OrganizationDetails.

"use client";

import { useEffect, useState } from "react";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { timestampDate } from "@bufbuild/protobuf/wkt";

import { identityClient } from "@/lib/connect/clients";
import {
  AdminGetOrganizationRequestSchema,
  type OrganizationDetails,
} from "@superwizor/proto-ts/identity/v1/identity_pb";

type LoadState = "loading" | "ready" | "not-found" | "error";

export function OrgDetail({ orgId }: { orgId: string }) {
  const t = useTranslations("admin.orgDetail");
  const tOrgs = useTranslations("admin.orgs");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  const [state, setState] = useState<LoadState>("loading");
  const [details, setDetails] = useState<OrganizationDetails | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setState("loading");
      try {
        const resp = await identityClient.adminGetOrganization(
          create(AdminGetOrganizationRequestSchema, { organizationId: orgId }),
        );
        if (cancelled) return;
        setDetails(resp);
        setState("ready");
      } catch {
        if (!cancelled) setState("not-found");
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [orgId]);

  const fmtDate = (ts: Parameters<typeof timestampDate>[0] | undefined) => {
    if (!ts) return "—";
    const d = timestampDate(ts);
    return new Intl.DateTimeFormat(locale === "en" ? "en-GB" : "pl-PL", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }).format(d);
  };

  if (state === "loading") {
    return (
      <p className="px-4 sm:px-6 lg:px-8 py-12 font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/70 text-center">
        {t("loading")}
      </p>
    );
  }

  if (state === "not-found" || state === "error" || !details?.organization) {
    return (
      <div className="px-4 sm:px-6 lg:px-8 py-12 text-center">
        <p className="font-serif text-mist">{t("notFound")}</p>
        <a
          href={`${prefix}/admin/orgs`}
          className="mt-4 inline-flex items-center rounded-button border border-frost/20 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-frost hover:bg-frost/5"
        >
          {t("backToList")}
        </a>
      </div>
    );
  }

  const org = details.organization;

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8 grid gap-6">
      <header className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
        <div>
          <a
            href={`${prefix}/admin/orgs`}
            className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist hover:text-frost transition"
          >
            ← {t("backToList")}
          </a>
          <h1 className="font-display text-frost text-3xl font-semibold tracking-[var(--tracking-display)] mt-2">
            {org.legalName}
          </h1>
        </div>
        <span
          className={`inline-flex items-center rounded-button px-3 py-1 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] ${
            org.isBlocked ? "bg-magma/20 text-magma" : "bg-ember/15 text-ember"
          }`}
        >
          {org.isBlocked ? tOrgs("status.blocked") : tOrgs("status.active")}
        </span>
      </header>

      <section className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card title={t("sectionDetails")}>
          <DefRow label="ID" value={org.id} mono />
          <DefRow label="NIP" value={org.taxId || "—"} mono />
          <DefRow label="VAT-EU" value={org.vatIdEu || "—"} mono />
          {org.headquartersAddress && (
            <DefRow
              label="Adres"
              value={`${org.headquartersAddress.streetLine} ${org.headquartersAddress.buildingNumber}, ${org.headquartersAddress.postalCode} ${org.headquartersAddress.city}, ${org.headquartersAddress.countryCode}`}
            />
          )}
          <DefRow
            label="Utworzone"
            value={fmtDate(org.createdAt)}
            mono
          />
        </Card>

        <Card title={t("sectionTherapists")}>
          {details.therapists.length === 0 ? (
            <p className="font-serif text-mist text-sm">
              {t("noTherapists")}
            </p>
          ) : (
            <ul className="grid gap-2">
              {details.therapists.map((u) => (
                <li
                  key={u.id}
                  className="flex justify-between gap-3 font-serif text-sm"
                >
                  <span className="text-frost">
                    {u.firstName} {u.lastName}
                  </span>
                  <span className="text-mist truncate">{u.email}</span>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card title={t("sectionAudit")}>
          {details.recentAudit.length === 0 ? (
            <p className="font-serif text-mist text-sm">{t("noAudit")}</p>
          ) : (
            <ul className="grid gap-3">
              {details.recentAudit.map((a) => (
                <li
                  key={a.id}
                  className="border-l-2 border-ember/40 pl-3 text-sm"
                >
                  <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {a.action}
                  </p>
                  <p className="font-serif text-frost">{a.actorEmail}</p>
                  <p className="font-mono text-[10px] text-mist/70">
                    {fmtDate(a.occurredAt)}
                  </p>
                  {a.reason && (
                    <p className="font-serif text-mist text-xs mt-1">
                      {a.reason}
                    </p>
                  )}
                </li>
              ))}
            </ul>
          )}
        </Card>
      </section>
    </div>
  );
}

function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-card border border-frost/10 bg-frost/[0.04] p-5">
      <h2 className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-3">
        {title}
      </h2>
      <div className="grid gap-2">{children}</div>
    </div>
  );
}

function DefRow({
  label,
  value,
  mono = false,
}: {
  label: string;
  value: string;
  mono?: boolean;
}) {
  return (
    <div className="grid grid-cols-3 gap-2 text-sm">
      <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist self-center col-span-1">
        {label}
      </span>
      <span
        className={`text-frost col-span-2 ${mono ? "font-mono text-xs break-all" : "font-serif"}`}
      >
        {value}
      </span>
    </div>
  );
}
