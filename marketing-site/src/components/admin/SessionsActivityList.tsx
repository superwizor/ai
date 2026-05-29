// SessionsActivityList — /admin/sessions table.
//
// Cross-org therapist session activity for SUPERWIZOR_ADMIN. Filters:
//   - Date range (defaults to last 24h)
//   - Therapist name / email substring (debounced 300ms)
// Each row shows: created date + time, session_date (when the
// therapist held the session), duration, status, therapist name +
// email, organization. CSV export grabs up to 5000 rows in one shot
// via the AdminListSessions max page_size and serialises to a Blob
// download — no server-side CSV rendering needed.

"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { timestampDate, timestampFromDate } from "@bufbuild/protobuf/wkt";

import { clinicalClient } from "@/lib/connect/clients";
import {
  AdminListSessionsRequestSchema,
  type AdminSessionRow,
} from "@superwizor/proto-ts/clinical/v1/clinical_pb";
import { TableSkeleton } from "./TableSkeleton";

const PAGE_SIZE = 50;
const CSV_MAX_ROWS = 5000;

type LoadState = "idle" | "loading" | "ready" | "error";
type ExportState = "idle" | "loading" | "error";

// Sort keys must match the allowlist in clinical-svc's
// admin_sessions.go::adminSessionsSortAllowlist. The UI column-header
// click handler flips between desc → asc → (back to default) on
// repeated clicks of the same column.
type SortKey =
  | "created_at"
  | "session_date"
  | "duration_seconds"
  | "status"
  | "therapist"
  | "organization"
  | "plan_name"
  | "period_end"
  | "tokens_used";
type SortOrder = "asc" | "desc";

export function SessionsActivityList() {
  const t = useTranslations("admin.sessions");

  // Default window: last 24h. Date inputs use "YYYY-MM-DD" — interpret
  // the strings in the user's local timezone (a backend timestamptz
  // round-trip handles the actual UTC math).
  const [since, setSince] = useState<string>(() => isoDay(addDays(new Date(), -1)));
  const [until, setUntil] = useState<string>(() => isoDay(new Date()));

  // Therapist search — substring on first + last + email, server-side
  // case-insensitive. Debounced to one RPC per 300ms of typing.
  const [therapistFilter, setTherapistFilter] = useState("");
  const [therapistFilterDebounced, setTherapistFilterDebounced] = useState("");

  const [rows, setRows] = useState<AdminSessionRow[]>([]);
  const [state, setState] = useState<LoadState>("idle");
  const [exportState, setExportState] = useState<ExportState>("idle");
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [sortBy, setSortBy] = useState<SortKey>("created_at");
  const [sortOrder, setSortOrder] = useState<SortOrder>("desc");

  useEffect(() => {
    const handle = setTimeout(
      () => setTherapistFilterDebounced(therapistFilter.trim()),
      300,
    );
    return () => clearTimeout(handle);
  }, [therapistFilter]);

  // Reset to page 0 whenever filters OR sort changes.
  useEffect(() => {
    setPage(0);
  }, [therapistFilterDebounced, since, until, sortBy, sortOrder]);

  // Click on a column header: same column flips order asc↔desc; new
  // column starts at desc (the convention used elsewhere in /admin).
  const toggleSort = (key: SortKey) => {
    if (key === sortBy) {
      setSortOrder((o) => (o === "desc" ? "asc" : "desc"));
    } else {
      setSortBy(key);
      setSortOrder("desc");
    }
  };

  // Compose the request from the filter inputs. Memoized so fetchPage
  // can be called from both the auto-effect AND the CSV export with
  // identical shape (just different page_size).
  const buildRequest = useCallback(
    (pageSize: number, pageIdx: number) => {
      const req = create(AdminListSessionsRequestSchema, {
        pageSize,
        page: pageIdx,
        therapistFilter: therapistFilterDebounced,
        sortBy,
        sortOrder,
      });
      // Date inputs ship "YYYY-MM-DD". since = start-of-day local;
      // until = end-of-day local. Backend treats start_time inclusive,
      // end_time exclusive — passing end-of-day+1ms gives the
      // expected "include this date" UX.
      if (since) {
        const d = new Date(`${since}T00:00:00`);
        if (!Number.isNaN(d.getTime())) req.startTime = timestampFromDate(d);
      }
      if (until) {
        const d = new Date(`${until}T23:59:59.999`);
        if (!Number.isNaN(d.getTime())) req.endTime = timestampFromDate(d);
      }
      return req;
    },
    [since, until, therapistFilterDebounced, sortBy, sortOrder],
  );

  const fetchPage = useCallback(async () => {
    setState("loading");
    try {
      const resp = await clinicalClient.adminListSessions(
        buildRequest(PAGE_SIZE, page),
      );
      setRows(resp.sessions);
      setHasMore(resp.hasMore);
      setState("ready");
    } catch (e) {
      console.error("[admin/sessions] load failed", e);
      setState("error");
    }
  }, [buildRequest, page]);

  useEffect(() => {
    void fetchPage();
  }, [fetchPage]);

  // ── CSV export ────────────────────────────────────────────────
  //
  // Single shot — request CSV_MAX_ROWS in one call so we don't have to
  // implement paged export. If the user genuinely has > 5000 rows in
  // the window they need to narrow the date range first; we surface a
  // truncation notice if the response carries has_more=true.
  const onExportCsv = async () => {
    if (exportState === "loading") return;
    setExportState("loading");
    try {
      const resp = await clinicalClient.adminListSessions(
        buildRequest(CSV_MAX_ROWS, 0),
      );

      const header = [
        t("csv.createdAt"),
        t("csv.sessionDate"),
        t("csv.durationMinutes"),
        t("csv.status"),
        t("csv.therapistName"),
        t("csv.therapistEmail"),
        t("csv.organization"),
        t("csv.planName"),
        t("csv.periodEnd"),
        t("csv.tokensUsed"),
        t("csv.sessionId"),
      ];

      const lines = [header.map(csvCell).join(",")];
      for (const r of resp.sessions) {
        const createdAt = r.createdAt ? timestampDate(r.createdAt) : null;
        const sessionDate = r.sessionDate ? timestampDate(r.sessionDate) : null;
        const periodEnd = r.subscriptionPeriodEnd
          ? timestampDate(r.subscriptionPeriodEnd)
          : null;
        const fullName = `${r.therapistFirstName} ${r.therapistLastName}`.trim();
        const durationMin = r.durationSeconds > 0
          ? (r.durationSeconds / 60).toFixed(1)
          : "";
        lines.push(
          [
            createdAt ? createdAt.toISOString() : "",
            sessionDate ? sessionDate.toISOString().slice(0, 10) : "",
            durationMin,
            r.status,
            fullName,
            r.therapistEmail,
            r.organizationName,
            r.subscriptionPlanName,
            periodEnd ? periodEnd.toISOString().slice(0, 10) : "",
            r.subscriptionTokensUsed > 0 ? String(r.subscriptionTokensUsed) : "",
            r.sessionId,
          ].map(csvCell).join(","),
        );
      }
      const csv = lines.join("\n");

      const blob = new Blob([`﻿${csv}`], { type: "text/csv;charset=utf-8" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = csvFilename(since, until);
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      // If the response was capped, tell the user via a toast-style
      // notice — embedded next to the button so they can react.
      if (resp.hasMore) {
        // We surface via state, not alert(), so screen readers see it
        // in the document flow.
        setExportState("error");
        setTimeout(() => setExportState("idle"), 4000);
        return;
      }
      setExportState("idle");
    } catch (e) {
      console.error("[admin/sessions] csv export failed", e);
      setExportState("error");
      setTimeout(() => setExportState("idle"), 4000);
    }
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8 grid gap-6">
      <header className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
        <div>
          <h1 className="font-display text-frost text-3xl font-semibold tracking-[var(--tracking-display)]">
            {t("title")}
          </h1>
          <p className="font-serif text-sm text-mist mt-2">{t("intro")}</p>
        </div>
        <button
          type="button"
          onClick={onExportCsv}
          disabled={exportState === "loading"}
          className="inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-xs px-5 py-2.5 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-50 disabled:cursor-progress"
        >
          {exportState === "loading" ? t("export.busy") : t("export.button")}
        </button>
      </header>

      {/* Filters */}
      <div className="grid sm:grid-cols-3 gap-3">
        <Field label={t("filters.since")}>
          <input
            type="date"
            value={since}
            max={until || undefined}
            onChange={(e) => setSince(e.target.value)}
            className="w-full bg-evergreen/40 border border-frost/15 rounded-button px-3 py-2 font-mono text-sm text-frost focus:outline-none focus:border-ember"
          />
        </Field>
        <Field label={t("filters.until")}>
          <input
            type="date"
            value={until}
            min={since || undefined}
            onChange={(e) => setUntil(e.target.value)}
            className="w-full bg-evergreen/40 border border-frost/15 rounded-button px-3 py-2 font-mono text-sm text-frost focus:outline-none focus:border-ember"
          />
        </Field>
        <Field label={t("filters.therapist")}>
          <input
            type="search"
            placeholder={t("filters.therapistPlaceholder")}
            value={therapistFilter}
            onChange={(e) => setTherapistFilter(e.target.value)}
            className="w-full bg-evergreen/40 border border-frost/15 rounded-button px-3 py-2 font-serif text-sm text-frost placeholder:text-mist/50 focus:outline-none focus:border-ember"
          />
        </Field>
      </div>

      {exportState === "error" && (
        <p
          role="status"
          className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-serif text-sm text-frost"
        >
          {t("export.truncated", { max: CSV_MAX_ROWS })}
        </p>
      )}

      {/* Table */}
      {state === "loading" && rows.length === 0 ? (
        <TableSkeleton columns={9} rows={8} />
      ) : state === "error" ? (
        <p className="font-serif text-sm text-magma">{t("errors.loadFailed")}</p>
      ) : rows.length === 0 ? (
        <p className="font-serif text-sm text-mist">{t("empty")}</p>
      ) : (
        <div className="overflow-x-auto rounded-button border border-frost/10">
          <table className="w-full text-left">
            <thead className="bg-evergreen/40 text-mist">
              <tr>
                <SortableTh sortKey="created_at"       active={sortBy} order={sortOrder} onClick={toggleSort}>{t("table.createdAt")}</SortableTh>
                <SortableTh sortKey="session_date"     active={sortBy} order={sortOrder} onClick={toggleSort}>{t("table.sessionDate")}</SortableTh>
                <SortableTh sortKey="duration_seconds" active={sortBy} order={sortOrder} onClick={toggleSort}>{t("table.duration")}</SortableTh>
                <SortableTh sortKey="status"           active={sortBy} order={sortOrder} onClick={toggleSort}>{t("table.status")}</SortableTh>
                <SortableTh sortKey="therapist"        active={sortBy} order={sortOrder} onClick={toggleSort}>{t("table.therapist")}</SortableTh>
                <SortableTh sortKey="organization"     active={sortBy} order={sortOrder} onClick={toggleSort}>{t("table.organization")}</SortableTh>
                <SortableTh sortKey="plan_name"        active={sortBy} order={sortOrder} onClick={toggleSort}>{t("table.planName")}</SortableTh>
                <SortableTh sortKey="period_end"       active={sortBy} order={sortOrder} onClick={toggleSort}>{t("table.periodEnd")}</SortableTh>
                <SortableTh sortKey="tokens_used"      active={sortBy} order={sortOrder} onClick={toggleSort}>{t("table.tokensUsed")}</SortableTh>
              </tr>
            </thead>
            <tbody className="divide-y divide-frost/5">
              {rows.map((r) => (
                <Row key={r.sessionId} row={r} t={t} />
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Pagination */}
      {state === "ready" && (rows.length > 0 || page > 0) && (
        <div className="flex items-center justify-between font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist">
          <div>{t("pagination.page", { page: page + 1 })}</div>
          <div className="flex gap-2">
            <button
              type="button"
              disabled={page === 0}
              onClick={() => setPage((p) => Math.max(0, p - 1))}
              className="rounded-button border border-frost/15 px-3 py-1.5 text-frost disabled:opacity-40 hover:border-ember transition"
            >
              {t("pagination.prev")}
            </button>
            <button
              type="button"
              disabled={!hasMore}
              onClick={() => setPage((p) => p + 1)}
              className="rounded-button border border-frost/15 px-3 py-1.5 text-frost disabled:opacity-40 hover:border-ember transition"
            >
              {t("pagination.next")}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <span className="block font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/70 mb-1">
        {label}
      </span>
      {children}
    </label>
  );
}

function SortableTh({
  sortKey,
  active,
  order,
  onClick,
  children,
}: {
  sortKey: SortKey;
  active: SortKey;
  order: SortOrder;
  onClick: (k: SortKey) => void;
  children: React.ReactNode;
}) {
  const isActive = active === sortKey;
  // Visual indicator on the active column. Use an arrow character that
  // flips based on direction so screen-readers + sighted users both
  // see the same intent.
  const arrow = isActive ? (order === "desc" ? "↓" : "↑") : "";
  return (
    <th
      scope="col"
      aria-sort={isActive ? (order === "desc" ? "descending" : "ascending") : "none"}
      className="px-3 py-2 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] font-medium"
    >
      <button
        type="button"
        onClick={() => onClick(sortKey)}
        className={`inline-flex items-center gap-1 hover:text-frost transition ${
          isActive ? "text-frost" : ""
        }`}
      >
        <span>{children}</span>
        <span className="text-ember w-3 inline-block">{arrow}</span>
      </button>
    </th>
  );
}

function Row({
  row,
  t,
}: {
  row: AdminSessionRow;
  t: ReturnType<typeof useTranslations>;
}) {
  // Format datetime in browser-local zone for the UI; CSV path
  // serialises ISO 8601 UTC instead.
  const created = row.createdAt ? timestampDate(row.createdAt) : null;
  const sessionDate = row.sessionDate ? timestampDate(row.sessionDate) : null;
  const periodEnd = row.subscriptionPeriodEnd
    ? timestampDate(row.subscriptionPeriodEnd)
    : null;
  const dur = row.durationSeconds > 0
    ? formatDuration(row.durationSeconds)
    : t("table.durationMissing");
  const therapistName =
    `${row.therapistFirstName} ${row.therapistLastName}`.trim() ||
    row.therapistEmail;

  return (
    <tr className="text-frost">
      <td className="px-3 py-2 font-mono text-xs whitespace-nowrap">
        <div>{created ? created.toLocaleDateString() : "—"}</div>
        <div className="text-mist text-[10px]">
          {created ? created.toLocaleTimeString() : ""}
        </div>
      </td>
      <td className="px-3 py-2 font-mono text-xs whitespace-nowrap">
        {sessionDate ? sessionDate.toLocaleDateString() : "—"}
      </td>
      <td className="px-3 py-2 font-mono text-xs">{dur}</td>
      <td className="px-3 py-2 font-mono text-[10px] uppercase tracking-[var(--tracking-label)]">
        {row.status}
      </td>
      <td className="px-3 py-2 text-sm">
        <div className="font-display">{therapistName}</div>
        {row.therapistEmail && (
          <div className="text-mist font-mono text-[10px]">{row.therapistEmail}</div>
        )}
      </td>
      <td className="px-3 py-2 font-serif text-sm text-mist">
        {row.organizationName || "—"}
      </td>
      <td className="px-3 py-2 font-serif text-sm text-mist whitespace-nowrap">
        {row.subscriptionPlanName || "—"}
      </td>
      <td className="px-3 py-2 font-mono text-xs whitespace-nowrap">
        {periodEnd ? periodEnd.toLocaleDateString() : "—"}
      </td>
      <td className="px-3 py-2 font-mono text-xs text-right">
        {row.subscriptionTokensUsed > 0 ? row.subscriptionTokensUsed : "—"}
      </td>
    </tr>
  );
}

function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  const min = Math.floor(seconds / 60);
  const sec = seconds % 60;
  if (min < 60) return `${min}m ${sec.toString().padStart(2, "0")}s`;
  const hr = Math.floor(min / 60);
  const remMin = min % 60;
  return `${hr}h ${remMin.toString().padStart(2, "0")}m`;
}

function isoDay(d: Date): string {
  // Local-zone YYYY-MM-DD for HTML date inputs.
  const y = d.getFullYear();
  const m = (d.getMonth() + 1).toString().padStart(2, "0");
  const day = d.getDate().toString().padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function addDays(d: Date, n: number): Date {
  const out = new Date(d);
  out.setDate(out.getDate() + n);
  return out;
}

// RFC 4180-ish: double-quote anything containing comma, quote, CR, LF.
// Escape embedded quotes by doubling. Empty values pass through.
function csvCell(v: string | number): string {
  const s = String(v ?? "");
  if (/[",\r\n]/.test(s)) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function csvFilename(since: string, until: string): string {
  const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  return `superwizor-sessions_${since || "all"}_${until || "all"}_${stamp}.csv`;
}
