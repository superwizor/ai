// Admin orgs list — fetches via identityClient.adminListOrganizations,
// renders a paginated, filterable table.
//
// Why a hand-rolled table instead of TanStack here: there's exactly
// one sort/filter axis at MVP (search by legal_name) and the backend
// paginates. The 6-column table is straightforward; TanStack would be
// unnecessary complexity. When sort-by-column or multi-filter ships
// (Slice 6 or beyond), swap to TanStack.

"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { timestampDate } from "@bufbuild/protobuf/wkt";

import { identityClient } from "@/lib/connect/clients";
import {
  AdminListOrganizationsRequestSchema,
  type OrganizationSummary,
  OrganizationType,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import { TableSkeleton } from "./TableSkeleton";

const PAGE_SIZE = 25;

type LoadState = "idle" | "loading" | "ready" | "error";

export function OrgsList() {
  const t = useTranslations("admin.orgs");
  const tCol = useTranslations("admin.orgs.columns");
  const tStatus = useTranslations("admin.orgs.status");
  const tType = useTranslations("admin.orgs.typeLabel");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  const [search, setSearch] = useState("");
  const [searchDebounced, setSearchDebounced] = useState("");
  // Type filter — defaults to CLINIC: B2B clinics are the admin's
  // day-to-day; solo bootstrap orgs are noise in this table.
  const [typeFilter, setTypeFilter] = useState<"ALL" | "SOLO" | "CLINIC" | "ENTERPRISE">("CLINIC");
  const [orgs, setOrgs] = useState<OrganizationSummary[]>([]);
  const [state, setState] = useState<LoadState>("idle");
  const [nextPageToken, setNextPageToken] = useState<string>("");
  const [pageStack, setPageStack] = useState<string[]>([""]); // empty = first page

  // Debounce the search input so each keystroke doesn't fire an RPC.
  useEffect(() => {
    const handle = setTimeout(() => setSearchDebounced(search), 300);
    return () => clearTimeout(handle);
  }, [search]);

  // Reset pagination when the search query or type filter changes.
  useEffect(() => {
    setPageStack([""]);
  }, [searchDebounced, typeFilter]);

  const fetchPage = useCallback(
    async (pageToken: string) => {
      setState("loading");
      try {
        const resp = await identityClient.adminListOrganizations(
          create(AdminListOrganizationsRequestSchema, {
            pageSize: PAGE_SIZE,
            pageToken,
            search: searchDebounced,
            type:
              typeFilter === "SOLO"
                ? OrganizationType.SOLO
                : typeFilter === "CLINIC"
                  ? OrganizationType.CLINIC
                  : typeFilter === "ENTERPRISE"
                    ? OrganizationType.ENTERPRISE
                    : OrganizationType.UNSPECIFIED,
          }),
        );
        setOrgs(resp.organizations);
        setNextPageToken(resp.nextPageToken);
        setState("ready");
      } catch {
        setState("error");
      }
    },
    [searchDebounced, typeFilter],
  );

  // Load whenever the (search, page) pair changes.
  useEffect(() => {
    const currentToken = pageStack[pageStack.length - 1] ?? "";
    void fetchPage(currentToken);
  }, [pageStack, fetchPage]);

  const onPrev = () => {
    if (pageStack.length <= 1) return;
    setPageStack((s) => s.slice(0, -1));
  };
  const onNext = () => {
    if (!nextPageToken) return;
    setPageStack((s) => [...s, nextPageToken]);
  };

  const orgTypeName = (t: OrganizationType): "SOLO" | "CLINIC" | "ENTERPRISE" | null => {
    // Connect-Web JSON wire format gives us either numeric or string;
    // tolerant lookup keeps the table working under either shape.
    const v = t as unknown;
    if (v === OrganizationType.SOLO || v === "ORGANIZATION_TYPE_SOLO") return "SOLO";
    if (v === OrganizationType.CLINIC || v === "ORGANIZATION_TYPE_CLINIC") return "CLINIC";
    if (v === OrganizationType.ENTERPRISE || v === "ORGANIZATION_TYPE_ENTERPRISE") return "ENTERPRISE";
    return null;
  };

  const fmtDate = (ts?: ReturnType<typeof timestampDate> | string | null) => {
    if (!ts) return t("noLastActivity");
    const d = ts instanceof Date ? ts : new Date(ts);
    if (Number.isNaN(d.getTime())) return t("noLastActivity");
    return new Intl.DateTimeFormat(locale === "en" ? "en-GB" : "pl-PL", {
      year: "numeric",
      month: "short",
      day: "numeric",
    }).format(d);
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8">
      <header className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 mb-6">
        <div>
          <h1 className="font-display text-frost text-2xl sm:text-3xl font-semibold tracking-[var(--tracking-display)]">
            {t("title")}
          </h1>
          <p className="font-serif text-mist mt-1 text-sm">{t("subhead")}</p>
        </div>
        <div className="flex items-center gap-3">
          <select
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value as typeof typeFilter)}
            aria-label={tCol("type")}
            className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3 py-2 font-display text-sm focus:outline-none focus:border-ember transition appearance-none cursor-pointer"
          >
            <option value="CLINIC">{tType("CLINIC")}</option>
            <option value="SOLO">{tType("SOLO")}</option>
            <option value="ENTERPRISE">{tType("ENTERPRISE")}</option>
            <option value="ALL">{t("typeAll")}</option>
          </select>
          <input
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t("searchPlaceholder")}
            className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2 font-display text-sm focus:outline-none focus:border-ember focus:bg-frost/[0.07] placeholder:text-mist/40 transition w-full sm:w-72"
          />
          <a
            href={`${prefix}/admin/orgs/new`}
            className="whitespace-nowrap rounded-button bg-ember text-abyss px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:bg-ember/90 transition"
          >
            {t("createCta")}
          </a>
        </div>
      </header>

      {state === "loading" && (
        <>
          <span className="sr-only" role="status" aria-live="polite">
            {t("loading")}
          </span>
          <TableSkeleton columns={6} />
        </>
      )}

      {state === "error" && (
        <div className="rounded-card border border-magma/40 bg-magma/10 px-4 py-6 text-center">
          <p className="font-serif text-frost text-sm">{t("error")}</p>
          <button
            onClick={() => fetchPage(pageStack[pageStack.length - 1] ?? "")}
            className="mt-3 inline-flex items-center rounded-button border border-frost/20 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-frost hover:bg-frost/5"
          >
            {t("retry")}
          </button>
        </div>
      )}

      {state === "ready" && orgs.length === 0 && (
        <p className="font-serif text-mist text-center py-12">{t("empty")}</p>
      )}

      {state === "ready" && orgs.length > 0 && (
        <>
          <div className="overflow-x-auto rounded-card border border-frost/10 bg-frost/[0.03]">
            <table className="w-full text-sm">
              <thead className="bg-frost/5">
                <tr>
                  <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {tCol("legalName")}
                  </th>
                  <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {tCol("type")}
                  </th>
                  <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {tCol("status")}
                  </th>
                  <th className="text-right px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {tCol("therapists")}
                  </th>
                  <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {tCol("lastActivity")}
                  </th>
                  <th className="text-right px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {tCol("actions")}
                  </th>
                </tr>
              </thead>
              <tbody>
                {orgs.map((row) => {
                  const org = row.organization!;
                  const typeKey = orgTypeName(org.type);
                  const lastDate = row.lastSessionAt
                    ? timestampDate(row.lastSessionAt)
                    : null;
                  return (
                    <tr
                      key={org.id}
                      className="border-t border-frost/5 hover:bg-frost/[0.04] transition"
                    >
                      <td className="px-4 py-3 font-display text-frost">
                        {org.legalName}
                      </td>
                      <td className="px-4 py-3 font-serif text-mist">
                        {typeKey ? tType(typeKey) : "—"}
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className={`inline-flex items-center rounded-button px-2 py-0.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] ${
                            org.isBlocked
                              ? "bg-magma/20 text-magma"
                              : "bg-ember/15 text-ember"
                          }`}
                        >
                          {org.isBlocked ? tStatus("blocked") : tStatus("active")}
                        </span>
                      </td>
                      <td className="px-4 py-3 font-mono text-mist text-right">
                        {row.therapistsCount}
                      </td>
                      <td className="px-4 py-3 font-mono text-mist">
                        {fmtDate(lastDate)}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <a
                          href={`${prefix}/admin/orgs/${org.id}`}
                          className="font-mono text-xs uppercase tracking-[var(--tracking-label)] text-ember hover:underline"
                        >
                          {t("view")}
                        </a>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          <div className="mt-6 flex items-center justify-end gap-3">
            <button
              onClick={onPrev}
              disabled={pageStack.length <= 1}
              className="rounded-button border border-frost/15 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost hover:border-frost/30 transition disabled:opacity-40 disabled:cursor-not-allowed"
            >
              {t("prev")}
            </button>
            <button
              onClick={onNext}
              disabled={!nextPageToken}
              className="rounded-button border border-frost/15 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost hover:border-frost/30 transition disabled:opacity-40 disabled:cursor-not-allowed"
            >
              {t("next")}
            </button>
          </div>
        </>
      )}
    </div>
  );
}
