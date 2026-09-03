// Admin discount codes — docs/70 §6.3.
//
// One table of `discount_codes` plus the four admin RPCs that keep it
// honest: AdminListDiscountCodes (table), AdminCreateDiscountCode
// (modal), AdminUpdateDiscountCode (rename / re-date / re-limit /
// activate / deactivate) and AdminGetDiscountCode (the per-code
// redemption log, expanded inline under the row).
//
// Shape copied from OrgsList (table + TableSkeleton) and OrgCreateWizard
// (row-per-field form), with every mutation funnelled through
// ActionDialog so the mandatory ≥10-char audit reason is captured in
// exactly one place — same contract as every other SUPERWIZOR_ADMIN RPC.
//
// Two contract details worth remembering:
//   1. `set_active` is an int32, not a bool: -1 = leave alone,
//      0 = deactivate, 1 = activate. proto3 can't tell false from
//      "unset", hence the tri-state.
//   2. `redemptions_count` is a MIRROR of Stripe, not the authority.
//      Stripe enforces max_redemptions atomically at checkout; we show
//      "≈ N left". Don't turn this column into a gate.

"use client";

import { Fragment, useCallback, useEffect, useState } from "react";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { timestampDate, timestampFromDate } from "@bufbuild/protobuf/wkt";

import { billingClient } from "@/lib/connect/clients";
import {
  AdminCreateDiscountCodeRequestSchema,
  AdminGetDiscountCodeRequestSchema,
  AdminListDiscountCodesRequestSchema,
  AdminUpdateDiscountCodeRequestSchema,
  type DiscountCode,
  type DiscountCodeDetails,
} from "@superwizor/proto-ts/billing/v1/billing_pb";
import { translateError } from "@/lib/errors/translate";
import { usePlanName } from "@/lib/plans";
import { ActionDialog, type ActionResult } from "./ActionDialog";
import { TableSkeleton } from "./TableSkeleton";

type LoadState = "idle" | "loading" | "ready" | "error";

const CODE_PATTERN = /^[A-Z0-9_]{3,32}$/;
const TIERS = ["SOLO", "PRO"] as const;
const CYCLES = ["MONTHLY", "ANNUAL"] as const;
const CHANNELS = ["WEB", "APPLE", "GOOGLE"] as const;
const DURATIONS = ["ONCE", "REPEATING", "FOREVER"] as const;

type Dialog = "create" | "edit" | "activate" | "deactivate";

// Empty create-form draft. Kept outside the component so "cancel then
// reopen" resets to the same baseline every time.
const emptyDraft = {
  code: "",
  name: "",
  percentOff: "",
  validUntil: "",
  maxRedemptions: "",
  duration: "FOREVER" as (typeof DURATIONS)[number],
  durationPeriods: "3",
  tiers: [] as string[],
  cycles: [] as string[],
  channels: ["WEB"] as string[],
  newCustomersOnly: false,
};

export function DiscountCodesList() {
  const t = useTranslations("admin.discountCodes");
  const tCol = useTranslations("admin.discountCodes.columns");
  const tStatus = useTranslations("admin.discountCodes.status");
  const tCreate = useTranslations("admin.discountCodes.create");
  const tEdit = useTranslations("admin.discountCodes.edit");
  const tErrors = useTranslations("errors");
  const locale = useLocale();
  const planName = usePlanName();

  const [includeInactive, setIncludeInactive] = useState(false);
  const [codes, setCodes] = useState<DiscountCode[]>([]);
  const [state, setState] = useState<LoadState>("idle");

  const [dialog, setDialog] = useState<Dialog | null>(null);
  const [target, setTarget] = useState<DiscountCode | null>(null);

  const [draft, setDraft] = useState(emptyDraft);
  const [editDraft, setEditDraft] = useState({
    name: "",
    validUntil: "",
    maxRedemptions: "",
  });

  // Expanded row → AdminGetDiscountCode. Only one code at a time; the
  // redemption log is a support tool, not a dashboard.
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [details, setDetails] = useState<DiscountCodeDetails | null>(null);
  const [detailsState, setDetailsState] = useState<LoadState>("idle");

  const fetchCodes = useCallback(async () => {
    setState("loading");
    try {
      const resp = await billingClient.adminListDiscountCodes(
        create(AdminListDiscountCodesRequestSchema, { includeInactive }),
      );
      setCodes(resp.codes);
      setState("ready");
    } catch {
      setState("error");
    }
  }, [includeInactive]);

  useEffect(() => {
    void fetchCodes();
  }, [fetchCodes]);

  const fmtDate = (ts: Parameters<typeof timestampDate>[0] | undefined) => {
    if (!ts) return "—";
    return new Intl.DateTimeFormat(locale === "en" ? "en-GB" : "pl-PL", {
      year: "numeric",
      month: "short",
      day: "numeric",
    }).format(timestampDate(ts));
  };

  const fmtDateTime = (ts: Parameters<typeof timestampDate>[0] | undefined) => {
    if (!ts) return "—";
    return new Intl.DateTimeFormat(locale === "en" ? "en-GB" : "pl-PL", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }).format(timestampDate(ts));
  };

  const openDetails = async (code: DiscountCode) => {
    if (expandedId === code.id) {
      setExpandedId(null);
      return;
    }
    setExpandedId(code.id);
    setDetails(null);
    setDetailsState("loading");
    try {
      const resp = await billingClient.adminGetDiscountCode(
        create(AdminGetDiscountCodeRequestSchema, { id: code.id }),
      );
      setDetails(resp);
      setDetailsState("ready");
    } catch {
      setDetailsState("error");
    }
  };

  // ── Create ────────────────────────────────────────────────────────
  const percentValue = Number(draft.percentOff.replace(",", "."));
  const isFullDiscount = Number.isFinite(percentValue) && percentValue === 100;

  const onCreate = async (reason: string): Promise<ActionResult> => {
    const code = draft.code.trim().toUpperCase();
    if (!CODE_PATTERN.test(code)) return { error: tCreate("invalidCode") };
    if (!draft.name.trim()) return { error: tCreate("invalidName") };
    if (!Number.isFinite(percentValue) || percentValue <= 0 || percentValue > 100) {
      return { error: tCreate("invalidPercent") };
    }
    const until = parseDateInput(draft.validUntil);
    if (!until || until.getTime() <= Date.now()) {
      return { error: tCreate("invalidValidUntil") };
    }
    const maxRedemptions = Number(draft.maxRedemptions);
    if (!Number.isInteger(maxRedemptions) || maxRedemptions <= 0) {
      return { error: tCreate("invalidMaxRedemptions") };
    }
    const periods = Number(draft.durationPeriods);
    if (draft.duration === "REPEATING" && (!Number.isInteger(periods) || periods <= 0)) {
      return { error: tCreate("invalidDurationPeriods") };
    }

    try {
      await billingClient.adminCreateDiscountCode(
        create(AdminCreateDiscountCodeRequestSchema, {
          code,
          name: draft.name.trim(),
          percentOff: String(percentValue),
          duration: draft.duration,
          durationPeriods: draft.duration === "REPEATING" ? periods : 0,
          validUntil: timestampFromDate(until),
          maxRedemptions,
          appliesToTiers: draft.tiers,
          appliesToCycles: draft.cycles,
          newCustomersOnly: draft.newCustomersOnly,
          channels: draft.channels.length > 0 ? draft.channels : ["WEB"],
          reason,
          idempotencyKey: newIdempotencyKey(),
        }),
      );
      setDraft(emptyDraft);
      await fetchCodes();
      return "success";
    } catch (e) {
      return { error: translateError(e, tErrors) };
    }
  };

  // ── Update (edit / activate / deactivate) ─────────────────────────
  const onEdit = async (reason: string): Promise<ActionResult> => {
    if (!target) return { error: tErrors("generic") };
    let validUntil = undefined;
    if (editDraft.validUntil) {
      const parsed = parseDateInput(editDraft.validUntil);
      if (!parsed) return { error: tCreate("invalidValidUntil") };
      validUntil = timestampFromDate(parsed);
    }
    let maxRedemptions = 0; // 0 = no change
    if (editDraft.maxRedemptions.trim()) {
      const n = Number(editDraft.maxRedemptions);
      if (!Number.isInteger(n) || n <= 0) {
        return { error: tCreate("invalidMaxRedemptions") };
      }
      maxRedemptions = n;
    }
    try {
      await billingClient.adminUpdateDiscountCode(
        create(AdminUpdateDiscountCodeRequestSchema, {
          id: target.id,
          name: editDraft.name.trim(),
          validUntil,
          maxRedemptions,
          setActive: -1, // -1 = leave activity untouched
          reason,
          idempotencyKey: newIdempotencyKey(),
        }),
      );
      await fetchCodes();
      return "success";
    } catch (e) {
      return { error: translateError(e, tErrors) };
    }
  };

  const onSetActive = (active: boolean) => async (reason: string): Promise<ActionResult> => {
    if (!target) return { error: tErrors("generic") };
    try {
      await billingClient.adminUpdateDiscountCode(
        create(AdminUpdateDiscountCodeRequestSchema, {
          id: target.id,
          setActive: active ? 1 : 0,
          reason,
          idempotencyKey: newIdempotencyKey(),
        }),
      );
      await fetchCodes();
      return "success";
    } catch (e) {
      return { error: translateError(e, tErrors) };
    }
  };

  const closeDialog = () => {
    setDialog(null);
    setTarget(null);
  };

  const scopeLabel = (c: DiscountCode) => {
    const tiers =
      c.appliesToTiers.length > 0
        ? c.appliesToTiers.map((x) => planName(x)).join(", ")
        : t("allTiers");
    const cycles =
      c.appliesToCycles.length > 0
        ? c.appliesToCycles.map((x) => cycleName(x)).join(", ")
        : t("allCycles");
    return `${tiers} · ${cycles}`;
  };

  const cycleName = (raw: string) =>
    raw === "MONTHLY" || raw === "ANNUAL" ? t(`cycleLabel.${raw}`) : raw;

  const channelName = (raw: string) =>
    raw === "WEB" || raw === "APPLE" || raw === "GOOGLE"
      ? t(`channelLabel.${raw}`)
      : raw;

  const durationLabel = (c: { duration: string; durationPeriods: number }) => {
    if (c.duration === "REPEATING") {
      return t("duration.REPEATING", { count: c.durationPeriods });
    }
    if (c.duration === "ONCE") return t("duration.ONCE");
    return t("duration.FOREVER");
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8">
      <header className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 mb-6">
        <div>
          <h1 className="font-display text-frost text-2xl sm:text-3xl font-semibold tracking-[var(--tracking-display)]">
            {t("title")}
          </h1>
          <p className="font-serif text-mist mt-1 text-sm max-w-2xl">{t("subhead")}</p>
        </div>
        <div className="flex items-center gap-4">
          <label className="flex items-center gap-2 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist cursor-pointer">
            <input
              type="checkbox"
              checked={includeInactive}
              onChange={(e) => setIncludeInactive(e.target.checked)}
              className="h-4 w-4 accent-[var(--color-ember,#F5A623)] cursor-pointer"
            />
            {t("showInactive")}
          </label>
          <button
            type="button"
            onClick={() => {
              setTarget(null);
              setDialog("create");
            }}
            className="whitespace-nowrap rounded-button bg-ember text-obsidian px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:bg-ember/90 transition"
          >
            {t("createCta")}
          </button>
        </div>
      </header>

      {state === "loading" && (
        <>
          <span className="sr-only" role="status" aria-live="polite">
            {t("loading")}
          </span>
          <TableSkeleton columns={8} />
        </>
      )}

      {state === "error" && (
        <div className="rounded-card border border-magma/40 bg-magma/10 px-4 py-6 text-center">
          <p className="font-serif text-frost text-sm">{t("error")}</p>
          <button
            onClick={() => void fetchCodes()}
            className="mt-3 inline-flex items-center rounded-button border border-frost/20 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-frost hover:bg-frost/5"
          >
            {t("retry")}
          </button>
        </div>
      )}

      {state === "ready" && codes.length === 0 && (
        <p className="font-serif text-mist text-center py-12">{t("empty")}</p>
      )}

      {state === "ready" && codes.length > 0 && (
        <div className="overflow-x-auto rounded-card border border-frost/10 bg-frost/[0.03]">
          <table className="w-full text-sm">
            <thead className="bg-frost/5">
              <tr>
                <Th>{tCol("code")}</Th>
                <Th>{tCol("name")}</Th>
                <Th align="right">{tCol("percent")}</Th>
                <Th>{tCol("validUntil")}</Th>
                <Th align="right">{tCol("redemptions")}</Th>
                <Th>{tCol("channels")}</Th>
                <Th>{tCol("status")}</Th>
                <Th align="right">{tCol("actions")}</Th>
              </tr>
            </thead>
            <tbody>
              {codes.map((c) => {
                const status = codeStatus(c);
                const expanded = expandedId === c.id;
                return (
                  <Fragment key={c.id}>
                    <tr className="border-t border-frost/5 hover:bg-frost/[0.04] transition">
                      <td className="px-4 py-3 font-mono text-frost text-xs">
                        {c.code}
                        {c.newCustomersOnly && (
                          <span className="ml-2 inline-flex items-center rounded-button bg-frost/10 px-1.5 py-0.5 font-mono text-[9px] uppercase tracking-[var(--tracking-label)] text-mist">
                            {t("newCustomersOnlyBadge")}
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3 font-display text-frost">
                        {c.name}
                        <span className="block font-serif text-[11px] text-mist/70">
                          {scopeLabel(c)}
                        </span>
                      </td>
                      <td className="px-4 py-3 font-mono text-frost text-right">
                        {formatPercent(locale, c.percentOff)}
                        <span className="block font-serif text-[11px] text-mist/70">
                          {durationLabel(c)}
                        </span>
                      </td>
                      <td className="px-4 py-3 font-mono text-mist">
                        {fmtDate(c.validUntil)}
                      </td>
                      <td className="px-4 py-3 font-mono text-mist text-right">
                        {c.redemptionsCount}/{c.maxRedemptions}
                      </td>
                      <td className="px-4 py-3 font-serif text-mist text-xs">
                        {c.channels.map(channelName).join(", ")}
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className={`inline-flex items-center rounded-button px-2 py-0.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] ${
                            status === "active"
                              ? "bg-ember/15 text-ember"
                              : status === "expired"
                                ? "bg-frost/10 text-mist"
                                : "bg-magma/20 text-magma"
                          }`}
                        >
                          {tStatus(status)}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-right whitespace-nowrap">
                        <RowBtn onClick={() => void openDetails(c)}>
                          {expanded ? t("hideCta") : t("viewCta")}
                        </RowBtn>
                        <RowBtn
                          onClick={() => {
                            setTarget(c);
                            setEditDraft({
                              name: c.name,
                              validUntil: toDateInput(c.validUntil),
                              maxRedemptions: "",
                            });
                            setDialog("edit");
                          }}
                        >
                          {t("editCta")}
                        </RowBtn>
                        <RowBtn
                          onClick={() => {
                            setTarget(c);
                            setDialog(c.isActive ? "deactivate" : "activate");
                          }}
                          danger={c.isActive}
                        >
                          {c.isActive ? t("deactivateCta") : t("activateCta")}
                        </RowBtn>
                      </td>
                    </tr>

                    {expanded && (
                      <tr className="border-t border-frost/5 bg-obsidian/40">
                        <td colSpan={8} className="px-4 py-4">
                          <h3 className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-3">
                            {t("details.title")}
                          </h3>
                          {detailsState === "loading" && (
                            <p className="font-serif text-mist text-sm">
                              {t("details.loading")}
                            </p>
                          )}
                          {detailsState === "error" && (
                            <p className="font-serif text-mist text-sm">
                              {t("details.error")}
                            </p>
                          )}
                          {detailsState === "ready" &&
                            (details?.redemptions.length ?? 0) === 0 && (
                              <p className="font-serif text-mist text-sm">
                                {t("details.empty")}
                              </p>
                            )}
                          {detailsState === "ready" &&
                            (details?.redemptions.length ?? 0) > 0 && (
                              <div className="overflow-x-auto rounded-card border border-frost/10">
                                <table className="w-full text-sm">
                                  <thead className="bg-frost/5">
                                    <tr>
                                      <Th>{t("details.columns.organization")}</Th>
                                      <Th>{t("details.columns.channel")}</Th>
                                      <Th>{t("details.columns.status")}</Th>
                                      <Th>{t("details.columns.reservedAt")}</Th>
                                      <Th>{t("details.columns.committedAt")}</Th>
                                    </tr>
                                  </thead>
                                  <tbody>
                                    {details!.redemptions.map((r, i) => (
                                      <tr
                                        key={`${r.organizationId}-${i}`}
                                        className="border-t border-frost/5"
                                      >
                                        <td className="px-4 py-2.5 font-serif text-frost">
                                          {r.organizationName || r.organizationId}
                                        </td>
                                        <td className="px-4 py-2.5 font-serif text-mist">
                                          {channelName(r.channel)}
                                        </td>
                                        <td className="px-4 py-2.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                                          {redemptionStatus(t, r.status)}
                                        </td>
                                        <td className="px-4 py-2.5 font-mono text-mist text-xs">
                                          {fmtDateTime(r.reservedAt)}
                                        </td>
                                        <td className="px-4 py-2.5 font-mono text-mist text-xs">
                                          {fmtDateTime(r.committedAt)}
                                        </td>
                                      </tr>
                                    ))}
                                  </tbody>
                                </table>
                              </div>
                            )}
                        </td>
                      </tr>
                    )}
                  </Fragment>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* ── Create dialog ─────────────────────────────────────────── */}
      <ActionDialog
        open={dialog === "create"}
        title={tCreate("title")}
        body={tCreate("body")}
        onClose={closeDialog}
        onConfirm={onCreate}
        confirmDisabled={
          !draft.code.trim() ||
          !draft.name.trim() ||
          !draft.percentOff.trim() ||
          !draft.validUntil ||
          !draft.maxRedemptions.trim()
        }
      >
        <TextField
          id="dc-code"
          label={tCreate("codeLabel")}
          placeholder={tCreate("codePlaceholder")}
          hint={tCreate("codeHint")}
          value={draft.code}
          mono
          onChange={(v) =>
            // Auto-uppercase as the admin types: the backend normalises
            // anyway (docs/70 D9), but seeing the stored form while
            // typing avoids "why did my code change?" after saving.
            setDraft((d) => ({ ...d, code: v.toUpperCase().replace(/\s+/g, "") }))
          }
        />
        <TextField
          id="dc-name"
          label={tCreate("nameLabel")}
          placeholder={tCreate("namePlaceholder")}
          value={draft.name}
          onChange={(v) => setDraft((d) => ({ ...d, name: v }))}
        />
        <div className="grid grid-cols-2 gap-4">
          <NumField
            id="dc-percent"
            label={tCreate("percentLabel")}
            value={draft.percentOff}
            onChange={(v) => setDraft((d) => ({ ...d, percentOff: v }))}
          />
          <NumField
            id="dc-max"
            label={tCreate("maxRedemptionsLabel")}
            value={draft.maxRedemptions}
            onChange={(v) => setDraft((d) => ({ ...d, maxRedemptions: v }))}
          />
        </div>

        {isFullDiscount && (
          <p
            role="alert"
            className="rounded-button border border-ember/40 bg-ember/10 px-3 py-2 font-serif text-xs text-frost"
          >
            {tCreate("fullDiscountWarning")}
          </p>
        )}

        <DateField
          id="dc-until"
          label={tCreate("validUntilLabel")}
          value={draft.validUntil}
          onChange={(v) => setDraft((d) => ({ ...d, validUntil: v }))}
        />

        <div className="grid grid-cols-2 gap-4">
          <SelField
            id="dc-duration"
            label={tCreate("durationLabel")}
            value={draft.duration}
            onChange={(v) =>
              setDraft((d) => ({ ...d, duration: v as (typeof DURATIONS)[number] }))
            }
            options={DURATIONS.map((d) => ({
              value: d,
              label: t(`durationOption.${d}`),
            }))}
          />
          {draft.duration === "REPEATING" && (
            <NumField
              id="dc-periods"
              label={tCreate("durationPeriodsLabel")}
              value={draft.durationPeriods}
              onChange={(v) => setDraft((d) => ({ ...d, durationPeriods: v }))}
            />
          )}
        </div>

        <CheckGroup
          label={tCreate("tiersLabel")}
          hint={tCreate("tiersHint")}
          options={TIERS.map((x) => ({ value: x, label: planName(x) }))}
          selected={draft.tiers}
          onToggle={(v) =>
            setDraft((d) => ({ ...d, tiers: toggle(d.tiers, v) }))
          }
        />
        <CheckGroup
          label={tCreate("cyclesLabel")}
          hint={tCreate("cyclesHint")}
          options={CYCLES.map((x) => ({ value: x, label: cycleName(x) }))}
          selected={draft.cycles}
          onToggle={(v) =>
            setDraft((d) => ({ ...d, cycles: toggle(d.cycles, v) }))
          }
        />
        <CheckGroup
          label={tCreate("channelsLabel")}
          hint={tCreate("channelsHint")}
          options={CHANNELS.map((x) => ({ value: x, label: channelName(x) }))}
          selected={draft.channels}
          onToggle={(v) =>
            setDraft((d) => ({ ...d, channels: toggle(d.channels, v) }))
          }
        />

        <label className="flex items-center gap-2 font-serif text-sm text-frost cursor-pointer">
          <input
            type="checkbox"
            checked={draft.newCustomersOnly}
            onChange={(e) =>
              setDraft((d) => ({ ...d, newCustomersOnly: e.target.checked }))
            }
            className="h-4 w-4 accent-[var(--color-ember,#F5A623)] cursor-pointer"
          />
          {tCreate("newCustomersOnlyLabel")}
        </label>
      </ActionDialog>

      {/* ── Edit dialog ───────────────────────────────────────────── */}
      <ActionDialog
        open={dialog === "edit"}
        title={`${tEdit("title")} ${target?.code ?? ""}`}
        body={tEdit("body")}
        onClose={closeDialog}
        onConfirm={onEdit}
      >
        <TextField
          id="dc-edit-name"
          label={tEdit("nameLabel")}
          value={editDraft.name}
          onChange={(v) => setEditDraft((d) => ({ ...d, name: v }))}
        />
        <DateField
          id="dc-edit-until"
          label={tEdit("validUntilLabel")}
          value={editDraft.validUntil}
          onChange={(v) => setEditDraft((d) => ({ ...d, validUntil: v }))}
        />
        <NumField
          id="dc-edit-max"
          label={tEdit("maxRedemptionsLabel")}
          hint={tEdit("unchangedHint")}
          value={editDraft.maxRedemptions}
          onChange={(v) => setEditDraft((d) => ({ ...d, maxRedemptions: v }))}
        />
      </ActionDialog>

      {/* ── Activate / deactivate ─────────────────────────────────── */}
      <ActionDialog
        open={dialog === "deactivate"}
        title={`${t("deactivate.title")} ${target?.code ?? ""}`}
        body={t("deactivate.body")}
        onClose={closeDialog}
        onConfirm={onSetActive(false)}
      />
      <ActionDialog
        open={dialog === "activate"}
        title={`${t("activate.title")} ${target?.code ?? ""}`}
        body={t("activate.body")}
        onClose={closeDialog}
        onConfirm={onSetActive(true)}
      />
    </div>
  );
}

/* ── helpers ─────────────────────────────────────────────────────── */

function codeStatus(c: DiscountCode): "active" | "inactive" | "expired" {
  if (!c.isActive) return "inactive";
  if (c.validUntil && timestampDate(c.validUntil).getTime() < Date.now()) {
    return "expired";
  }
  return "active";
}

function redemptionStatus(
  t: ReturnType<typeof useTranslations>,
  raw: string,
): string {
  if (raw === "RESERVED" || raw === "COMMITTED" || raw === "RELEASED") {
    return t(`details.status.${raw}`);
  }
  return raw || "—";
}

// percent_off arrives as a decimal string ("33.00") so the wire never
// rounds it through a double. Render it without the noise zeros.
export function formatPercent(locale: string, raw: string): string {
  const n = Number(raw);
  if (!Number.isFinite(n)) return raw ? `${raw}%` : "—";
  return `${new Intl.NumberFormat(locale === "en" ? "en-GB" : "pl-PL", {
    maximumFractionDigits: 2,
  }).format(n)}%`;
}

// <input type="date"> hands back "YYYY-MM-DD". Codes should stay usable
// through the whole of their last day, so anchor to the end of it.
function parseDateInput(value: string): Date | null {
  if (!value) return null;
  const d = new Date(`${value}T23:59:59`);
  return Number.isNaN(d.getTime()) ? null : d;
}

function toDateInput(ts: Parameters<typeof timestampDate>[0] | undefined): string {
  if (!ts) return "";
  const d = timestampDate(ts);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function toggle(list: string[], value: string): string[] {
  return list.includes(value)
    ? list.filter((x) => x !== value)
    : [...list, value];
}

function newIdempotencyKey(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return `dc-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

/* ── presentational bits ─────────────────────────────────────────── */

function Th({
  children,
  align = "left",
}: {
  children: React.ReactNode;
  align?: "left" | "right";
}) {
  return (
    <th
      className={`px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist ${
        align === "right" ? "text-right" : "text-left"
      }`}
    >
      {children}
    </th>
  );
}

function RowBtn({
  children,
  onClick,
  danger = false,
}: {
  children: React.ReactNode;
  onClick: () => void;
  danger?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`ml-3 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:underline ${
        danger ? "text-magma" : "text-ember"
      }`}
    >
      {children}
    </button>
  );
}

function FieldShell({
  id,
  label,
  hint,
  children,
}: {
  id: string;
  label: string;
  hint?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex flex-col">
      <label
        htmlFor={id}
        className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
      >
        {label}
      </label>
      {children}
      {hint && (
        <p className="mt-1.5 font-serif text-[11px] text-mist/70">{hint}</p>
      )}
    </div>
  );
}

const inputClass =
  "rounded-button bg-obsidian border border-frost/25 text-frost px-3.5 py-2.5 font-display text-base focus:outline-none focus:border-ember transition";

function TextField({
  id,
  label,
  value,
  onChange,
  placeholder,
  hint,
  mono = false,
}: {
  id: string;
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  hint?: string;
  mono?: boolean;
}) {
  return (
    <FieldShell id={id} label={label} hint={hint}>
      <input
        id={id}
        type="text"
        value={value}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        className={`${inputClass} ${mono ? "font-mono tracking-widest" : ""} placeholder:text-mist/50`}
      />
    </FieldShell>
  );
}

function NumField({
  id,
  label,
  value,
  onChange,
  hint,
}: {
  id: string;
  label: string;
  value: string;
  onChange: (v: string) => void;
  hint?: string;
}) {
  return (
    <FieldShell id={id} label={label} hint={hint}>
      <input
        id={id}
        type="number"
        inputMode="numeric"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={inputClass}
      />
    </FieldShell>
  );
}

function DateField({
  id,
  label,
  value,
  onChange,
  hint,
}: {
  id: string;
  label: string;
  value: string;
  onChange: (v: string) => void;
  hint?: string;
}) {
  return (
    <FieldShell id={id} label={label} hint={hint}>
      <input
        id={id}
        type="date"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={inputClass}
      />
    </FieldShell>
  );
}

function SelField({
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
    <FieldShell id={id} label={label}>
      <select
        id={id}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={`${inputClass} appearance-none cursor-pointer`}
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </FieldShell>
  );
}

function CheckGroup({
  label,
  hint,
  options,
  selected,
  onToggle,
}: {
  label: string;
  hint?: string;
  options: { value: string; label: string }[];
  selected: string[];
  onToggle: (value: string) => void;
}) {
  return (
    <fieldset className="flex flex-col">
      <legend className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2">
        {label}
      </legend>
      <div className="flex flex-wrap gap-x-5 gap-y-2">
        {options.map((o) => (
          <label
            key={o.value}
            className="flex items-center gap-2 font-serif text-sm text-frost cursor-pointer"
          >
            <input
              type="checkbox"
              checked={selected.includes(o.value)}
              onChange={() => onToggle(o.value)}
              className="h-4 w-4 accent-[var(--color-ember,#F5A623)] cursor-pointer"
            />
            {o.label}
          </label>
        ))}
      </div>
      {hint && <p className="mt-1.5 font-serif text-[11px] text-mist/70">{hint}</p>}
    </fieldset>
  );
}
