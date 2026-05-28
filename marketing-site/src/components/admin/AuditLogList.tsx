// Global audit log viewer — AdminListAuditEvents with actor/action/
// since/until filters. Cursor-paginated, debounced search inputs.
//
// docs/18 §8.2: "global cross-org audit history (`audit_events` table);
// filterable by actor, action, date range".

"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { timestampDate, timestampFromDate } from "@bufbuild/protobuf/wkt";

import { identityClient } from "@/lib/connect/clients";
import {
  AdminListAuditEventsRequestSchema,
  type AuditEntry,
} from "@superwizor/proto-ts/identity/v1/identity_pb";

const PAGE_SIZE = 50;

// A short curated list of admin action codes — the audit_events.action
// column is free-form on the backend but every SUPERWIZOR_ADMIN
// mutation we ship picks from this set. New actions added in code
// won't appear here until they're added — by design, the dropdown is
// a hint, not a constraint; the wire field is still a plain string so
// "Other" filters work via the actor/date axes.
const KNOWN_ACTIONS = [
  "organization.set_status",
  "organization.update",
  "user.admin_update",
  "user.admin_delete",
  "billing.reset_tokens",
  "billing.change_plan",
] as const;

type LoadState = "idle" | "loading" | "ready" | "error";

export function AuditLogList() {
  const t = useTranslations("admin.audit");
  const locale = useLocale();

  // Filter state — each axis is independent.
  const [actorEmail, setActorEmail] = useState("");
  const [actorEmailDebounced, setActorEmailDebounced] = useState("");
  const [action, setAction] = useState("");
  const [since, setSince] = useState(""); // "YYYY-MM-DD"
  const [until, setUntil] = useState("");

  const [events, setEvents] = useState<AuditEntry[]>([]);
  const [state, setState] = useState<LoadState>("idle");
  const [nextPageToken, setNextPageToken] = useState("");
  const [pageStack, setPageStack] = useState<string[]>([""]);

  // Debounce the email-search so we don't fire an RPC per keystroke.
  useEffect(() => {
    const handle = setTimeout(() => setActorEmailDebounced(actorEmail), 300);
    return () => clearTimeout(handle);
  }, [actorEmail]);

  // Reset to page 1 whenever filters change.
  useEffect(() => {
    setPageStack([""]);
  }, [actorEmailDebounced, action, since, until]);

  const fetchPage = useCallback(
    async (pageToken: string) => {
      setState("loading");
      try {
        const req = create(AdminListAuditEventsRequestSchema, {
          pageSize: PAGE_SIZE,
          pageToken,
          actorEmail: actorEmailDebounced,
          action,
        });
        // Date inputs ship "YYYY-MM-DD" — interpret as start-of-day for
        // since and end-of-day for until in the browser's local zone.
        // The backend column is timestamptz so comparison is timezone-
        // aware; we send the absolute instant of the local midnight.
        if (since) {
          const sinceDate = new Date(`${since}T00:00:00`);
          if (!Number.isNaN(sinceDate.getTime())) {
            req.since = timestampFromDate(sinceDate);
          }
        }
        if (until) {
          const untilDate = new Date(`${until}T23:59:59.999`);
          if (!Number.isNaN(untilDate.getTime())) {
            req.until = timestampFromDate(untilDate);
          }
        }
        const resp = await identityClient.adminListAuditEvents(req);
        setEvents(resp.events);
        setNextPageToken(resp.nextPageToken);
        setState("ready");
      } catch {
        setState("error");
      }
    },
    [actorEmailDebounced, action, since, until],
  );

  useEffect(() => {
    const currentToken = pageStack[pageStack.length - 1] ?? "";
    void fetchPage(currentToken);
  }, [pageStack, fetchPage]);

  const reload = () => fetchPage(pageStack[pageStack.length - 1] ?? "");

  const fmt = useMemo(
    () =>
      new Intl.DateTimeFormat(locale === "en" ? "en-GB" : "pl-PL", {
        year: "numeric",
        month: "short",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      }),
    [locale],
  );

  const fmtDate = (ts: AuditEntry["occurredAt"]) => {
    if (!ts) return "—";
    return fmt.format(timestampDate(ts));
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8">
      <header className="mb-6">
        <h1 className="font-display text-frost text-2xl sm:text-3xl font-semibold tracking-[var(--tracking-display)]">
          {t("title")}
        </h1>
        <p className="font-serif text-mist mt-1 text-sm">{t("subhead")}</p>
      </header>

      {/* Filters bar — actor / action / date range. All optional; backend
          AND-s when set. */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 mb-6">
        <FilterInput
          id="audit-actor"
          label={t("actorEmailLabel")}
          value={actorEmail}
          onChange={setActorEmail}
          placeholder="admin@example.com"
          type="search"
        />
        <FilterSelect
          id="audit-action"
          label={t("actionLabel")}
          value={action}
          onChange={setAction}
          options={[
            { value: "", label: t("anyAction") },
            ...KNOWN_ACTIONS.map((a) => ({ value: a, label: a })),
          ]}
        />
        <FilterInput
          id="audit-since"
          label={t("sinceLabel")}
          value={since}
          onChange={setSince}
          type="date"
        />
        <FilterInput
          id="audit-until"
          label={t("untilLabel")}
          value={until}
          onChange={setUntil}
          type="date"
        />
      </div>

      {state === "loading" && (
        <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/70 py-12 text-center">
          {t("loading")}
        </p>
      )}

      {state === "error" && (
        <div className="rounded-card border border-magma/40 bg-magma/10 px-4 py-6 text-center">
          <p className="font-serif text-frost text-sm">{t("error")}</p>
          <button
            onClick={reload}
            className="mt-3 inline-flex items-center rounded-button border border-frost/20 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-frost hover:bg-frost/5"
          >
            {t("retry")}
          </button>
        </div>
      )}

      {state === "ready" && events.length === 0 && (
        <p className="font-serif text-mist text-center py-12">{t("empty")}</p>
      )}

      {state === "ready" && events.length > 0 && (
        <>
          <div className="overflow-x-auto rounded-card border border-frost/10 bg-frost/[0.03]">
            <table className="w-full text-sm">
              <thead className="bg-frost/5">
                <tr>
                  <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {t("col.occurred")}
                  </th>
                  <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {t("col.actor")}
                  </th>
                  <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {t("col.action")}
                  </th>
                  <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {t("col.resource")}
                  </th>
                  <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {t("col.reason")}
                  </th>
                </tr>
              </thead>
              <tbody>
                {events.map((e) => (
                  <tr key={e.id} className="border-t border-frost/5 align-top">
                    <td className="px-4 py-3 font-mono text-xs text-mist whitespace-nowrap">
                      {fmtDate(e.occurredAt)}
                    </td>
                    <td className="px-4 py-3 font-serif text-frost break-all">
                      {e.actorEmail || "—"}
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-ember">
                      {e.action}
                    </td>
                    <td className="px-4 py-3 font-mono text-[10px] text-mist/80 break-all">
                      <div>{e.resourceType}</div>
                      {e.resourceId && (
                        <div className="text-mist/60">{e.resourceId}</div>
                      )}
                    </td>
                    <td className="px-4 py-3 font-serif text-sm text-mist max-w-md">
                      {e.reason || "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="mt-6 flex items-center justify-end gap-3">
            <button
              onClick={() => setPageStack((s) => s.slice(0, -1))}
              disabled={pageStack.length <= 1}
              className="rounded-button border border-frost/15 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost hover:border-frost/30 transition disabled:opacity-40 disabled:cursor-not-allowed"
            >
              {t("prev")}
            </button>
            <button
              onClick={() =>
                nextPageToken && setPageStack((s) => [...s, nextPageToken])
              }
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

function FilterInput({
  id,
  label,
  value,
  onChange,
  placeholder,
  type = "text",
}: {
  id: string;
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  type?: string;
}) {
  return (
    <div className="flex flex-col">
      <label
        htmlFor={id}
        className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
      >
        {label}
      </label>
      <input
        id={id}
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2 font-display text-sm focus:outline-none focus:border-ember focus:bg-frost/[0.07] placeholder:text-mist/40 transition"
      />
    </div>
  );
}

function FilterSelect({
  id,
  label,
  value,
  onChange,
  options,
}: {
  id: string;
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
}) {
  return (
    <div className="flex flex-col">
      <label
        htmlFor={id}
        className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
      >
        {label}
      </label>
      <select
        id={id}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2 font-display text-sm focus:outline-none focus:border-ember focus:bg-frost/[0.07] transition appearance-none cursor-pointer"
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </div>
  );
}
