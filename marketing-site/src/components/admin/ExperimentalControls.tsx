// Tryb eksperymentalny per organizacja (plan 16 §2.5).
//
// Mieszka na stronie ORGANIZACJI, nie na osobnym ekranie ustawień: to
// decyzja o konkretnej organizacji, podejmowana obok pozostałych decyzji
// o niej. Osobny ekran wymagałby wybrania organizacji z listy jeszcze
// raz — czyli powtórzenia kroku, który admin właśnie zrobił.
//
// Notatka jest wymagana, bo raport eksperymentalny powstaje na ontologii
// BEZ autoryzacji ekspertów. Pytanie „kto i kiedy włączył to tej
// organizacji" jest pytaniem zgodnościowym, nie operacyjnym, a wpis
// audytowy bez powodu nie odpowiada na nie w żadnym stopniu.

"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";

import type { AdminExperimentalControls } from "@superwizor/proto-ts/clinical/v1/clinical_pb";
import { clinicalClient } from "@/lib/connect/clients";
import { translateError } from "@/lib/errors/translate";
import { ActionDialog, type ActionResult } from "@/components/admin/ActionDialog";

type PendingChange =
  | { kind: "enable" }
  | { kind: "disable" }
  | { kind: "limit"; value: number };

export function ExperimentalControls({ orgId }: { orgId: string }) {
  const t = useTranslations("admin.experimental");
  const tErrors = useTranslations("errors");
  const [controls, setControls] = useState<AdminExperimentalControls | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [pending, setPending] = useState<PendingChange | null>(null);
  const [limitDraft, setLimitDraft] = useState("");

  const load = useCallback(async () => {
    try {
      const res = await clinicalClient.adminGetExperimentalControls({
        organizationId: orgId,
      });
      setControls(res);
      setLimitDraft(String(res.dailyLimit));
      setLoadError(null);
    } catch (e) {
      setLoadError(translateError(e, tErrors));
    }
  }, [orgId, tErrors]);

  useEffect(() => {
    void load();
  }, [load]);

  const apply = useCallback(
    async (change: PendingChange, reason: string): Promise<ActionResult> => {
      try {
        // Wysyłane jest WYŁĄCZNIE zmieniane pole. Pola `optional` w
        // żądaniu istnieją właśnie po to: bez nich zmiana limitu
        // przesyłałaby też `enabled` i po cichu przestawiała flagę.
        const res = await clinicalClient.adminSetExperimentalControls({
          organizationId: orgId,
          note: reason,
          ...(change.kind === "enable" ? { enabled: true } : {}),
          ...(change.kind === "disable" ? { enabled: false } : {}),
          ...(change.kind === "limit" ? { dailyLimit: BigInt(change.value) } : {}),
        });
        setControls(res);
        setLimitDraft(String(res.dailyLimit));
        return "success";
      } catch (e) {
        return { error: translateError(e, tErrors) };
      }
    },
    [orgId, tErrors],
  );

  if (loadError) return <p className="text-magma text-sm">{loadError}</p>;
  if (!controls) return <p className="text-frost/60 text-sm">{t("loading")}</p>;

  const wlaczony = controls.enabled;

  return (
    <div className="grid gap-4">
      <p className="font-serif text-mist text-sm">{t("description")}</p>

      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div>
          <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
            {t("statusLabel")}
          </p>
          <p
            className={`font-serif text-lg ${wlaczony ? "text-ember" : "text-frost"}`}
            data-testid="experimental-status"
          >
            {wlaczony ? t("statusOn") : t("statusOff")}
          </p>
        </div>
        <button
          type="button"
          onClick={() => setPending(wlaczony ? { kind: "disable" } : { kind: "enable" })}
          className="border border-ember/60 text-ember px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:bg-ember/10"
        >
          {wlaczony ? t("actionDisable") : t("actionEnable")}
        </button>
      </div>

      <div className="flex items-end gap-3 flex-wrap">
        <label className="grid gap-1">
          <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
            {t("limitLabel")}
          </span>
          <input
            type="number"
            min={0}
            max={50}
            value={limitDraft}
            onChange={(e) => setLimitDraft(e.target.value)}
            className="bg-abyss border border-frost/20 text-frost px-3 py-2 w-28 font-mono text-sm"
            data-testid="experimental-limit"
          />
        </label>
        <button
          type="button"
          disabled={limitDraft === String(controls.dailyLimit) || limitDraft === ""}
          onClick={() => setPending({ kind: "limit", value: Number(limitDraft) })}
          className="border border-frost/30 text-frost px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:bg-frost/10 disabled:opacity-40"
        >
          {t("actionSaveLimit")}
        </button>
      </div>

      <p className="font-serif text-mist/70 text-xs">{t("limitHint")}</p>

      <ActionDialog
        open={pending !== null}
        title={
          pending?.kind === "enable"
            ? t("confirmEnableTitle")
            : pending?.kind === "disable"
              ? t("confirmDisableTitle")
              : t("confirmLimitTitle")
        }
        body={
          pending?.kind === "enable"
            ? t("confirmEnableBody")
            : pending?.kind === "disable"
              ? t("confirmDisableBody")
              : t("confirmLimitBody", { value: pending?.value ?? 0 })
        }
        onConfirm={(reason) =>
          pending ? apply(pending, reason) : Promise.resolve("success" as const)
        }
        onClose={() => setPending(null)}
      />
    </div>
  );
}
