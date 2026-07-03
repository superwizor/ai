// /org — organization manager panel (docs/38 §5.4, §6).
//
// Tabs:
//   Team    — therapists + pending invites, seat occupancy per plan,
//             invite (seat-pinned), deactivate / reactivate.
//   Org     — company data (read-only; edited via /account).
//   Billing — allocations + per-therapist token usage this period.
//
// Analytics tab lands with PR7 (GetOrgTherapistMetrics).

"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { EmptySchema, timestampDate } from "@bufbuild/protobuf/wkt";

import { identityClient, billingClient, clinicalClient } from "@/lib/connect/clients";
import {
  InviteTherapistRequestSchema,
  SetTherapistStatusRequestSchema,
  type Organization,
  type TherapistEntry,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import type { OrgSeatSummary } from "@superwizor/proto-ts/billing/v1/billing_pb";
import {
  GetOrgTherapistMetricsRequestSchema,
  type OrgTherapistMetricsResponse,
} from "@superwizor/proto-ts/clinical/v1/clinical_pb";
import { translateError } from "@/lib/errors/translate";
import { usePlanName } from "@/lib/plans";

type Tab = "team" | "analytics" | "organization" | "billing";

const inputCls =
  "rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2 font-display text-sm focus:outline-none focus:border-ember focus:bg-frost/[0.07] placeholder:text-mist/40 transition w-full";
const btnPrimary =
  "rounded-button bg-ember text-abyss px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:bg-ember/90 transition disabled:opacity-40 disabled:cursor-not-allowed";
const btnGhost =
  "rounded-button border border-frost/15 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost hover:border-frost/30 transition disabled:opacity-40";
const thCls =
  "text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist";

export function OrgPanel() {
  const t = useTranslations("org.panel");
  const planName = usePlanName();
  const tErrors = useTranslations("errors");
  const locale = useLocale();

  const [tab, setTab] = useState<Tab>("team");
  const [entries, setEntries] = useState<TherapistEntry[]>([]);
  const [seatUsage, setSeatUsage] = useState<OrgSeatSummary | null>(null);
  const [org, setOrg] = useState<Organization | null>(null);
  const [loading, setLoading] = useState(true);
  const [flash, setFlash] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [team, usage, myOrg] = await Promise.all([
        identityClient.listTherapistsInMyOrg(create(EmptySchema, {})),
        billingClient.getMyOrgSeatUsage(create(EmptySchema, {})).catch(() => null),
        identityClient.getMyOrganization(create(EmptySchema, {})).catch(() => null),
      ]);
      setEntries(team.therapists);
      setSeatUsage(usage);
      setOrg(myOrg);
    } catch (err) {
      setError(translateError(err, tErrors));
    } finally {
      setLoading(false);
    }
  }, [tErrors]);

  useEffect(() => {
    void reload();
  }, [reload]);

  // ── analytics tab state ──
  const [periodDays, setPeriodDays] = useState<7 | 30 | 90>(30);
  const [metrics, setMetrics] = useState<OrgTherapistMetricsResponse | null>(null);
  const [metricsLoading, setMetricsLoading] = useState(false);

  useEffect(() => {
    if (tab !== "analytics") return;
    let cancelled = false;
    setMetricsLoading(true);
    clinicalClient
      .getOrgTherapistMetrics(
        create(GetOrgTherapistMetricsRequestSchema, { periodDays }),
      )
      .then((resp) => {
        if (!cancelled) setMetrics(resp);
      })
      .catch((err) => {
        if (!cancelled) setError(translateError(err, tErrors));
      })
      .finally(() => {
        if (!cancelled) setMetricsLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [tab, periodDays, tErrors]);

  // ── invite modal state ──
  const [inviteOpen, setInviteOpen] = useState(false);
  const [invEmail, setInvEmail] = useState("");
  const [invFirst, setInvFirst] = useState("");
  const [invLast, setInvLast] = useState("");
  const [invAllocation, setInvAllocation] = useState("");
  const [invBusy, setInvBusy] = useState(false);
  const [invError, setInvError] = useState<string | null>(null);

  const allocations = useMemo(() => seatUsage?.allocations ?? [], [seatUsage]);

  const sendInvite = async () => {
    setInvBusy(true);
    setInvError(null);
    try {
      await identityClient.inviteTherapist(
        create(InviteTherapistRequestSchema, {
          email: invEmail.trim(),
          firstName: invFirst.trim(),
          lastName: invLast.trim(),
          allocationId: invAllocation,
        }),
      );
      setInviteOpen(false);
      setInvEmail("");
      setInvFirst("");
      setInvLast("");
      setFlash(t("inviteSent"));
      await reload();
    } catch (err) {
      setInvError(seatsError(err) ?? translateError(err, tErrors));
    } finally {
      setInvBusy(false);
    }
  };

  const toggleStatus = async (userId: string, isActive: boolean) => {
    setError(null);
    try {
      await identityClient.setTherapistStatus(
        create(SetTherapistStatusRequestSchema, { userId, isActive }),
      );
      setFlash(isActive ? t("reactivated") : t("deactivated"));
      await reload();
    } catch (err) {
      setError(seatsError(err) ?? translateError(err, tErrors));
    }
  };

  // SEATS_EXHAUSTED gets a dedicated, human message.
  const seatsError = (err: unknown): string | null => {
    const msg = err instanceof Error ? err.message : String(err);
    return msg.includes("SEATS_EXHAUSTED") ? t("seatsExhausted") : null;
  };

  const fmtDate = (d: Date) =>
    new Intl.DateTimeFormat(locale === "en" ? "en-GB" : "pl-PL", {
      year: "numeric",
      month: "short",
      day: "numeric",
    }).format(d);

  const tabs: { key: Tab; label: string }[] = [
    { key: "team", label: t("tabTeam") },
    { key: "analytics", label: t("tabAnalytics") },
    { key: "organization", label: t("tabOrganization") },
    { key: "billing", label: t("tabBilling") },
  ];

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8 max-w-5xl mx-auto">
      <h1 className="font-display text-frost text-2xl sm:text-3xl font-semibold tracking-[var(--tracking-display)]">
        {org?.legalName ?? t("title")}
      </h1>
      <p className="font-serif text-mist mt-1 text-sm">{t("subhead")}</p>

      <nav className="mt-6 flex gap-2 border-b border-frost/10">
        {tabs.map(({ key, label }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`px-4 py-2.5 font-mono text-xs uppercase tracking-[var(--tracking-label)] border-b-2 -mb-px transition ${
              tab === key
                ? "border-ember text-ember"
                : "border-transparent text-mist hover:text-frost"
            }`}
          >
            {label}
          </button>
        ))}
      </nav>

      {flash && (
        <p
          className="mt-4 rounded-card border border-ember/40 bg-ember/10 px-4 py-3 font-serif text-frost text-sm cursor-pointer"
          onClick={() => setFlash(null)}
        >
          {flash}
        </p>
      )}
      {error && (
        <p className="mt-4 rounded-card border border-magma/40 bg-magma/10 px-4 py-3 font-serif text-frost text-sm">
          {error}
        </p>
      )}

      {loading && (
        <p className="py-12 text-center font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/70">
          {t("loading")}
        </p>
      )}

      {!loading && tab === "team" && (
        <section className="mt-6 grid gap-6">
          {allocations.length > 0 && (
            <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {allocations.map((a) => {
                const used = a.seatsAssigned + a.seatsPending;
                const pct = a.seats > 0 ? Math.min(100, (used / a.seats) * 100) : 0;
                return (
                  <div
                    key={a.allocationId}
                    className="rounded-card border border-frost/10 bg-frost/[0.03] p-4"
                  >
                    <div className="flex items-baseline justify-between">
                      <span className="font-display text-frost text-sm">{planName(a.planTier)}</span>
                      <span className="font-mono text-xs text-mist">
                        {used}/{a.seats} {t("seatsUnit")}
                      </span>
                    </div>
                    <div className="mt-2 h-1.5 rounded-full bg-frost/10 overflow-hidden">
                      <div
                        className={`h-full ${pct >= 100 ? "bg-magma" : "bg-ember"}`}
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                    {a.seatsPending > 0 && (
                      <p className="mt-1.5 font-serif text-mist text-xs">
                        {t("pendingSeats", { count: a.seatsPending })}
                      </p>
                    )}
                  </div>
                );
              })}
            </div>
          )}

          <div className="flex justify-end">
            <button className={btnPrimary} onClick={() => setInviteOpen(true)}>
              {t("inviteCta")}
            </button>
          </div>

          <div className="overflow-x-auto rounded-card border border-frost/10 bg-frost/[0.03]">
            <table className="w-full text-sm">
              <thead className="bg-frost/5">
                <tr>
                  <th className={thCls}>{t("colName")}</th>
                  <th className={thCls}>{t("colEmail")}</th>
                  <th className={thCls}>{t("colStatus")}</th>
                  <th className={`${thCls} text-right`}>{t("colActions")}</th>
                </tr>
              </thead>
              <tbody>
                {entries.map((e, i) => {
                  if (e.user) {
                    const u = e.user;
                    return (
                      <tr key={u.id} className="border-t border-frost/5">
                        <td className="px-4 py-3 font-display text-frost">
                          {u.firstName} {u.lastName}
                        </td>
                        <td className="px-4 py-3 font-mono text-mist text-xs">{u.email}</td>
                        <td className="px-4 py-3">
                          <span
                            className={`inline-flex rounded-button px-2 py-0.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] ${
                              u.isActive ? "bg-ember/15 text-ember" : "bg-frost/10 text-mist"
                            }`}
                          >
                            {u.isActive ? t("statusActive") : t("statusInactive")}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-right">
                          <button
                            className="font-mono text-xs uppercase tracking-[var(--tracking-label)] text-ember hover:underline"
                            onClick={() => void toggleStatus(u.id, !u.isActive)}
                          >
                            {u.isActive ? t("deactivateCta") : t("reactivateCta")}
                          </button>
                        </td>
                      </tr>
                    );
                  }
                  const inv = e.pendingInvitation;
                  if (!inv) return null;
                  const expires = inv.expiresAt ? timestampDate(inv.expiresAt) : null;
                  return (
                    <tr key={`inv-${inv.id ?? i}`} className="border-t border-frost/5 opacity-70">
                      <td className="px-4 py-3 font-display text-mist">
                        {inv.firstName || inv.lastName
                          ? `${inv.firstName} ${inv.lastName}`.trim()
                          : "—"}
                      </td>
                      <td className="px-4 py-3 font-mono text-mist text-xs">{inv.email}</td>
                      <td className="px-4 py-3">
                        <span className="inline-flex rounded-button bg-frost/10 px-2 py-0.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                          {t("statusPending")}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-right font-serif text-mist text-xs">
                        {expires ? t("expires", { date: fmtDate(expires) }) : ""}
                      </td>
                    </tr>
                  );
                })}
                {entries.length === 0 && (
                  <tr>
                    <td colSpan={4} className="px-4 py-8 text-center font-serif text-mist">
                      {t("teamEmpty")}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      )}

      {!loading && tab === "analytics" && (
        <section className="mt-6 grid gap-4">
          <div className="flex items-center gap-2">
            {[7, 30, 90].map((d) => (
              <button
                key={d}
                onClick={() => setPeriodDays(d as 7 | 30 | 90)}
                className={`rounded-button px-3 py-1.5 font-mono text-xs uppercase tracking-[var(--tracking-label)] border transition ${
                  periodDays === d
                    ? "border-ember text-ember"
                    : "border-frost/15 text-mist hover:text-frost"
                }`}
              >
                {t("periodDays", { count: d })}
              </button>
            ))}
          </div>
          {metricsLoading && (
            <p className="py-8 text-center font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/70">
              {t("loading")}
            </p>
          )}
          {!metricsLoading && metrics && (
            <div className="overflow-x-auto rounded-card border border-frost/10 bg-frost/[0.03]">
              <table className="w-full text-sm">
                <thead className="bg-frost/5">
                  <tr>
                    <th className={thCls}>{t("colTherapist")}</th>
                    <th className={`${thCls} text-right`}>{t("mSessions")}</th>
                    <th className={`${thCls} text-right`}>{t("mFailed")}</th>
                    <th className={`${thCls} text-right`}>{t("mAvgDuration")}</th>
                    <th className={`${thCls} text-right`}>{t("mActivePatients")}</th>
                    <th className={`${thCls} text-right`}>{t("mNewPatients")}</th>
                    <th className={`${thCls} text-right`}>{t("mReportViewed")}</th>
                    <th className={`${thCls} text-right`}>{t("mRatings")}</th>
                    <th className={thCls}>{t("mLastSession")}</th>
                  </tr>
                </thead>
                <tbody>
                  {metrics.therapists.map((m) => (
                    <tr key={m.therapistId} className="border-t border-frost/5">
                      <td className="px-4 py-3 font-display text-frost">
                        {m.firstName} {m.lastName}
                        {!m.isActive && (
                          <span className="ml-2 font-mono text-[10px] uppercase text-mist">
                            ({t("statusInactive")})
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3 font-mono text-mist text-right">{m.sessionsCompleted}</td>
                      <td className="px-4 py-3 font-mono text-mist text-right">
                        {m.sessionsFailed + m.sessionsCancelled}
                      </td>
                      <td className="px-4 py-3 font-mono text-mist text-right">
                        {m.avgDurationSeconds > 0 ? `${Math.round(m.avgDurationSeconds / 60)} min` : "—"}
                      </td>
                      <td className="px-4 py-3 font-mono text-mist text-right">{m.activePatients}</td>
                      <td className="px-4 py-3 font-mono text-mist text-right">{m.newPatients}</td>
                      <td className="px-4 py-3 font-mono text-mist text-right">
                        {m.sessionsCompleted > 0
                          ? `${Math.round((m.sessionsReportViewed / m.sessionsCompleted) * 100)}%`
                          : "—"}
                      </td>
                      <td className="px-4 py-3 font-mono text-mist text-right">
                        <span className="text-ember">+{m.ratingsPositive}</span>{" "}
                        <span className="text-magma">−{m.ratingsNegative}</span>
                      </td>
                      <td className="px-4 py-3 font-mono text-mist text-xs">{m.lastSessionDate || "—"}</td>
                    </tr>
                  ))}
                  {metrics.totals && metrics.therapists.length > 0 && (
                    <tr className="border-t border-frost/10 bg-frost/[0.04]">
                      <td className="px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                        {t("mTotals")}
                      </td>
                      <td className="px-4 py-3 font-mono text-frost text-right">{metrics.totals.sessionsCompleted}</td>
                      <td className="px-4 py-3 font-mono text-frost text-right">
                        {metrics.totals.sessionsFailed + metrics.totals.sessionsCancelled}
                      </td>
                      <td className="px-4 py-3 font-mono text-frost text-right">
                        {metrics.totals.avgDurationSeconds > 0
                          ? `${Math.round(metrics.totals.avgDurationSeconds / 60)} min`
                          : "—"}
                      </td>
                      <td className="px-4 py-3 font-mono text-frost text-right">{metrics.totals.activePatients}</td>
                      <td className="px-4 py-3 font-mono text-frost text-right">{metrics.totals.newPatients}</td>
                      <td className="px-4 py-3" colSpan={3} />
                    </tr>
                  )}
                  {metrics.therapists.length === 0 && (
                    <tr>
                      <td colSpan={9} className="px-4 py-8 text-center font-serif text-mist">
                        {t("analyticsEmpty")}
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          )}
          <p className="font-serif text-mist text-xs">{t("analyticsPrivacyNote")}</p>
        </section>
      )}

      {!loading && tab === "organization" && (
        <section className="mt-6 rounded-card border border-frost/10 bg-frost/[0.03] p-6 grid gap-3 max-w-lg">
          {[
            [t("orgLegalName"), org?.legalName],
            [t("orgTaxId"), org?.taxId],
            [t("orgVatIdEu"), org?.vatIdEu],
          ].map(([label, value]) => (
            <div key={label as string} className="grid grid-cols-[10rem_1fr] gap-3">
              <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist pt-0.5">
                {label}
              </span>
              <span className="font-display text-frost text-sm">{value || "—"}</span>
            </div>
          ))}
          <p className="font-serif text-mist text-xs mt-2">{t("orgEditHint")}</p>
        </section>
      )}

      {!loading && tab === "billing" && (
        <section className="mt-6 grid gap-6">
          {seatUsage?.periodEnd && (
            <p className="font-serif text-mist text-sm">
              {t("period", {
                start: seatUsage.periodStart ? fmtDate(timestampDate(seatUsage.periodStart)) : "…",
                end: fmtDate(timestampDate(seatUsage.periodEnd)),
              })}{" "}
              · {seatUsage.subscriptionStatus}
            </p>
          )}
          <div className="overflow-x-auto rounded-card border border-frost/10 bg-frost/[0.03]">
            <table className="w-full text-sm">
              <thead className="bg-frost/5">
                <tr>
                  <th className={thCls}>{t("colTherapist")}</th>
                  <th className={thCls}>{t("colPlan")}</th>
                  <th className={`${thCls} text-right`}>{t("colTokens")}</th>
                  <th className={thCls}>{t("colUsage")}</th>
                </tr>
              </thead>
              <tbody>
                {(seatUsage?.therapistUsage ?? []).map((u) => {
                  const consumed = u.tokensUsed + u.tokensReserved;
                  const pct =
                    u.tokensLimit > 0 ? Math.min(100, (consumed / u.tokensLimit) * 100) : 0;
                  return (
                    <tr key={u.therapistId} className="border-t border-frost/5">
                      <td className="px-4 py-3 font-display text-frost">
                        {u.firstName} {u.lastName}
                        {!u.isActive && (
                          <span className="ml-2 font-mono text-[10px] uppercase text-mist">
                            ({t("statusInactive")})
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3 font-mono text-mist text-xs">{planName(u.planTier) || "—"}</td>
                      <td className="px-4 py-3 font-mono text-mist text-right">
                        {consumed}/{u.tokensLimit}
                      </td>
                      <td className="px-4 py-3 w-40">
                        <div className="h-1.5 rounded-full bg-frost/10 overflow-hidden">
                          <div
                            className={`h-full ${pct >= 95 ? "bg-magma" : "bg-ember"}`}
                            style={{ width: `${pct}%` }}
                          />
                        </div>
                      </td>
                    </tr>
                  );
                })}
                {(seatUsage?.therapistUsage ?? []).length === 0 && (
                  <tr>
                    <td colSpan={4} className="px-4 py-8 text-center font-serif text-mist">
                      {t("billingEmpty")}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      )}

      {inviteOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-abyss/80 px-4">
          <div className="w-full max-w-md rounded-card border border-frost/15 bg-abyss p-6 grid gap-4">
            <h2 className="font-display text-frost text-lg font-semibold">{t("inviteTitle")}</h2>
            <input
              className={inputCls}
              type="email"
              placeholder={t("inviteEmail")}
              value={invEmail}
              onChange={(e) => setInvEmail(e.target.value)}
            />
            <div className="grid grid-cols-2 gap-3">
              <input
                className={inputCls}
                placeholder={t("inviteFirstName")}
                value={invFirst}
                onChange={(e) => setInvFirst(e.target.value)}
              />
              <input
                className={inputCls}
                placeholder={t("inviteLastName")}
                value={invLast}
                onChange={(e) => setInvLast(e.target.value)}
              />
            </div>
            {allocations.length > 0 && (
              <select
                className={inputCls}
                value={invAllocation}
                onChange={(e) => setInvAllocation(e.target.value)}
              >
                <option value="">{t("invitePickPlan")}</option>
                {allocations.map((a) => {
                  const free = a.seats - a.seatsAssigned - a.seatsPending;
                  return (
                    <option key={a.allocationId} value={a.allocationId} disabled={free <= 0}>
                      {planName(a.planTier)} — {t("freeSeats", { count: Math.max(0, free) })}
                    </option>
                  );
                })}
              </select>
            )}
            {invError && <p className="font-serif text-magma text-sm">{invError}</p>}
            <div className="flex justify-end gap-3">
              <button className={btnGhost} onClick={() => setInviteOpen(false)} disabled={invBusy}>
                {t("cancel")}
              </button>
              <button
                className={btnPrimary}
                disabled={invBusy || !invEmail.includes("@") || (allocations.length > 0 && !invAllocation)}
                onClick={() => void sendInvite()}
              >
                {invBusy ? t("inviteSending") : t("inviteSend")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
