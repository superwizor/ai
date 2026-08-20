// /admin/ai-chat — the AI chat kill switch and its threshold dashboard
// (ADR docs/kronikarz/62 sections 8.3 and 11, plan docs/63 F5/F7).
//
// Two things live on this page, and the order is deliberate: the switch
// first, the numbers second. Someone arriving here during an incident
// needs to turn something off, not to read a chart.
//
// The runbook (docs/64) also documents a direct SQL path. That one works
// when this page does not — which is exactly when it is needed — but it
// writes no audit row. This page is the normal route because it does, and
// that is why the reason field is mandatory: an audit entry saying only
// that someone disabled the chat answers none of the questions that will
// be asked afterwards.

"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";

import type { AdminChatControls } from "@superwizor/proto-ts/clinical/v1/clinical_pb";
import { clinicalClient } from "@/lib/connect/clients";
import { translateError } from "@/lib/errors/translate";
import { ActionDialog, type ActionResult } from "@/components/admin/ActionDialog";

/** Pending change, described so the confirmation dialog can state what
 * is about to happen in words rather than as a diff of field names. */
type PendingChange =
  | { kind: "disable" }
  | { kind: "enable" }
  | { kind: "mode"; mode: "full" | "defined_ops" };

export function ChatControls() {
  const t = useTranslations("admin.aiChat");
  const tErrors = useTranslations("errors");
  const [controls, setControls] = useState<AdminChatControls | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [pending, setPending] = useState<PendingChange | null>(null);

  const load = useCallback(async () => {
    try {
      const res = await clinicalClient.adminGetChatControls({ organizationId: "" });
      setControls(res);
      setLoadError(null);
    } catch (e) {
      setLoadError(translateError(e, tErrors));
    }
  }, [tErrors]);

  useEffect(() => {
    void load();
  }, [load]);

  const apply = useCallback(
    async (change: PendingChange, reason: string): Promise<ActionResult> => {
      try {
        // Only the field being changed is sent. The request's optional
        // fields exist precisely so a mode change does not also
        // re-transmit `enabled` and silently switch a chat back on that
        // someone had just switched off.
        const res = await clinicalClient.adminSetChatControls({
          organizationId: "",
          note: reason,
          ...(change.kind === "disable" ? { enabled: false } : {}),
          ...(change.kind === "enable" ? { enabled: true } : {}),
          ...(change.kind === "mode" ? { mode: change.mode } : {}),
        });
        setControls(res);
        return "success";
      } catch (e) {
        return { error: translateError(e, tErrors) };
      }
    },
    [tErrors],
  );

  if (loadError) {
    return <p className="text-magma text-sm">{loadError}</p>;
  }
  if (!controls) {
    return <p className="text-frost/60 text-sm">{t("loading")}</p>;
  }

  const enabled = controls.enabled;
  const restricted = controls.mode === "defined_ops";

  return (
    <div className="flex flex-col gap-8">
      <section className="rounded-xl border border-frost/10 bg-evergreen/30 p-5">
        <h2 className="font-display text-frost text-lg mb-1">{t("switchTitle")}</h2>
        <p className="text-frost/60 text-sm mb-5">{t("switchBody")}</p>

        <div className="flex flex-wrap items-center gap-3">
          <StatusPill
            label={enabled ? t("stateOn") : t("stateOff")}
            tone={enabled ? "ok" : "off"}
          />
          <StatusPill
            label={restricted ? t("modeDefinedOps") : t("modeFull")}
            tone={restricted ? "warn" : "ok"}
          />
        </div>

        <div className="mt-5 flex flex-wrap gap-3">
          {enabled ? (
            <button
              type="button"
              onClick={() => setPending({ kind: "disable" })}
              className="rounded-lg bg-magma/80 px-4 py-2 text-sm font-semibold text-frost hover:bg-magma"
            >
              {t("btnDisable")}
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setPending({ kind: "enable" })}
              className="rounded-lg bg-ember/80 px-4 py-2 text-sm font-semibold text-evergreen hover:bg-ember"
            >
              {t("btnEnable")}
            </button>
          )}

          {restricted ? (
            <button
              type="button"
              onClick={() => setPending({ kind: "mode", mode: "full" })}
              className="rounded-lg border border-frost/20 px-4 py-2 text-sm font-semibold text-frost hover:bg-frost/5"
            >
              {t("btnModeFull")}
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setPending({ kind: "mode", mode: "defined_ops" })}
              className="rounded-lg border border-frost/20 px-4 py-2 text-sm font-semibold text-frost hover:bg-frost/5"
            >
              {t("btnModeDefinedOps")}
            </button>
          )}
        </div>

        {/* Restricting is cheaper than switching off, and an operator
            under pressure should not have to work that out for
            themselves. */}
        <p className="mt-4 text-xs leading-relaxed text-frost/50">{t("guidance")}</p>
      </section>

      <section className="rounded-xl border border-frost/10 bg-evergreen/30 p-5">
        <h2 className="font-display text-frost text-lg mb-1">{t("configTitle")}</h2>
        <dl className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
          <ConfigRow label={t("labelTau")} value={controls.classifierTau.toFixed(2)} />
          <ConfigRow
            label={t("labelQuota")}
            value={`$${(Number(controls.quotaMicroUsd) / 1_000_000).toFixed(2)} / ${t("perMonth")}`}
          />
        </dl>
        <p className="mt-4 text-xs leading-relaxed text-frost/50">{t("tauNote")}</p>
      </section>

      <ActionDialog
        open={pending !== null}
        title={pending ? dialogTitle(t, pending) : ""}
        body={pending ? dialogBody(t, pending) : ""}
        onClose={() => setPending(null)}
        onConfirm={async (reason) => {
          if (!pending) return "success";
          const result = await apply(pending, reason);
          if (result === "success") setPending(null);
          return result;
        }}
      />
    </div>
  );
}

function dialogTitle(t: (k: string) => string, c: PendingChange): string {
  if (c.kind === "disable") return t("confirmDisableTitle");
  if (c.kind === "enable") return t("confirmEnableTitle");
  return c.mode === "defined_ops" ? t("confirmRestrictTitle") : t("confirmUnrestrictTitle");
}

function dialogBody(t: (k: string) => string, c: PendingChange): string {
  if (c.kind === "disable") return t("confirmDisableBody");
  if (c.kind === "enable") return t("confirmEnableBody");
  return c.mode === "defined_ops" ? t("confirmRestrictBody") : t("confirmUnrestrictBody");
}

function StatusPill({ label, tone }: { label: string; tone: "ok" | "warn" | "off" }) {
  const cls =
    tone === "ok"
      ? "border-ember/50 bg-ember/10 text-ember"
      : tone === "warn"
        ? "border-frost/30 bg-frost/5 text-frost/80"
        : "border-magma/50 bg-magma/10 text-magma";
  return (
    <span className={`rounded-full border px-3 py-1 text-xs font-semibold ${cls}`}>{label}</span>
  );
}

function ConfigRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-frost/10 bg-nocturne/40 px-4 py-3">
      <dt className="text-xs uppercase tracking-wide text-frost/45">{label}</dt>
      <dd className="mt-1 font-mono text-sm text-frost">{value}</dd>
    </div>
  );
}
