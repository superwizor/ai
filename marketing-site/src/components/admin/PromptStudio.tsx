// /admin/prompts — Admin Prompt Studio (docs/31).
//
// Versioned editor for the per-modality report prompts
// (modalities.therapist_ai_general_prompt["system"]). llm-worker reads
// that column fresh on EVERY report, so a successful save changes the
// next generated report for every therapist of that modality — no
// deploys. Every save appends a snapshot to modality_prompt_versions;
// restore = re-applying an old snapshot as a new version through the
// same save path.
//
// Layout: left rail = modality list (version badge, dirty dot); main =
// monospace editor + char counter + diff-vs-saved + read-only call-2
// context accordion; below = version history (view / compare / restore).
// Save goes through the shared ActionDialog (mandatory reason ≥10 chars
// → change_note), with expected_version as the optimistic lock.

"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { timestampDate } from "@bufbuild/protobuf/wkt";

import type {
  AdminModalityPrompt,
  AdminModalityPromptVersion,
} from "@superwizor/proto-ts/clinical/v1/clinical_pb";
import { clinicalClient } from "@/lib/connect/clients";
import { translateError } from "@/lib/errors/translate";
import { ActionDialog, type ActionResult } from "@/components/admin/ActionDialog";
import { diffLines, type DiffOp } from "@/lib/diff";

const MAX_PROMPT_CHARS = 20000; // mirrors clinical-svc maxPromptChars

// The fixed call-2 scaffold surrounding the editable prompt, shown
// read-only so admins see what they do / don't control. Static copy of
// the prompt shape in ai-pipeline-svc/cmd/llm-worker/main.go
// (generateReportBody) — SYNC NOTE: if the scaffold changes materially,
// update this sketch. It is deliberately a sketch, not the verbatim
// prompt (which embeds per-session content).
const CALL2_CONTEXT_SKETCH = `┌─ PROMPT CALL-2 (raport) ──────────────────────────────┐
│ ▶▶ TWÓJ PROMPT MODALNOŚCI (edytowalny tutaj) ◀◀       │
│                                                        │
│ TARGET LANGUAGE FOR THE REPORT: <język raportu>        │
│ <reguły językowe i cytowania — stałe>                  │
│ <preferencje terapeuty: długość/akcenty raportu>       │
│ CZEGO NIE PISZ: <stałe reguły>                         │
│ ZASADY ZWIĘZŁOŚCI: <stałe reguły>                      │
│ KONTEKST POPRZEDNICH SESJI: <RAG — wątki z historii>   │
│ TRANSKRYPT BIEŻĄCEJ SESJI: <transkrypt>                │
└────────────────────────────────────────────────────────┘`;

function fmtDate(p?: { seconds: bigint; nanos: number }): string {
  if (!p) return "—";
  try {
    // timestampDate accepts the generated Timestamp message shape.
    return timestampDate(p as Parameters<typeof timestampDate>[0]).toLocaleString("pl-PL", {
      dateStyle: "medium",
      timeStyle: "short",
    });
  } catch {
    return "—";
  }
}

function DiffView({ ops }: { ops: DiffOp[] }) {
  return (
    <pre className="font-mono text-xs leading-relaxed whitespace-pre-wrap max-h-[55vh] overflow-y-auto rounded-button bg-obsidian/40 border border-frost/10 p-4">
      {ops.map((op, i) => (
        <div
          key={i}
          className={
            op.kind === "add"
              ? "bg-aurora/15 text-frost"
              : op.kind === "del"
                ? "bg-magma/15 text-mist line-through decoration-magma/60"
                : "text-mist/70"
          }
        >
          <span className="select-none mr-2 text-mist/40">
            {op.kind === "add" ? "+" : op.kind === "del" ? "−" : " "}
          </span>
          {op.text || " "}
        </div>
      ))}
    </pre>
  );
}

// Centred modal shell shared by the view/compare overlays.
function Overlay({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
}) {
  return (
    <div
      role="dialog"
      aria-modal="true"
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm px-4"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="w-full max-w-3xl rounded-glass border border-glass-border/60 bg-evergreen px-6 py-6 shadow-[var(--shadow-large)]">
        <div className="flex items-center justify-between mb-4">
          <h2 className="font-display text-frost text-lg font-semibold">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="close"
            className="rounded-button border border-frost/15 px-3 py-1.5 font-mono text-xs text-mist hover:text-frost hover:border-frost/30 transition"
          >
            ✕
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

export function PromptStudio() {
  const t = useTranslations("admin.prompts");
  const tErrors = useTranslations("errors");

  const [prompts, setPrompts] = useState<AdminModalityPrompt[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [draft, setDraft] = useState("");

  const [history, setHistory] = useState<AdminModalityPromptVersion[]>([]);
  const [historyHasMore, setHistoryHasMore] = useState(false);
  const [historyLoading, setHistoryLoading] = useState(false);

  const [saveOpen, setSaveOpen] = useState(false);
  const [saveIsRestore, setSaveIsRestore] = useState<number | null>(null); // version being restored
  const [diffOpen, setDiffOpen] = useState(false);
  const [viewVersion, setViewVersion] = useState<AdminModalityPromptVersion | null>(null);
  const [compareVersion, setCompareVersion] = useState<AdminModalityPromptVersion | null>(null);
  const [savedFlash, setSavedFlash] = useState(false);

  const selected = prompts.find((p) => p.modalityId === selectedId) ?? null;
  const dirty = !!selected && draft !== selected.systemPrompt;
  const overLimit = draft.length > MAX_PROMPT_CHARS;

  const load = useCallback(async () => {
    setLoading(true);
    setLoadError(null);
    try {
      const resp = await clinicalClient.adminListModalityPrompts({});
      setPrompts(resp.prompts);
      // Keep / initialise the selection.
      setSelectedId((cur) => {
        const still = resp.prompts.find((p) => p.modalityId === cur);
        const pick = still ?? resp.prompts[0];
        return pick ? pick.modalityId : null;
      });
    } catch (e) {
      setLoadError(translateError(e, tErrors));
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const loadHistory = useCallback(async (modalityId: string) => {
    setHistoryLoading(true);
    try {
      const resp = await clinicalClient.adminGetModalityPromptHistory({
        modalityId,
        pageSize: 20,
        pageOffset: 0,
      });
      setHistory(resp.versions);
      setHistoryHasMore(resp.hasMore);
    } catch {
      // History is auxiliary — the editor stays usable without it.
      setHistory([]);
      setHistoryHasMore(false);
    } finally {
      setHistoryLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  // Seed the editor + history whenever the selection resolves.
  useEffect(() => {
    if (selected) {
      setDraft(selected.systemPrompt);
      void loadHistory(selected.modalityId);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedId, loading]);

  const selectModality = (id: string) => {
    if (id === selectedId) return;
    if (dirty && !window.confirm(t("discardConfirm"))) return;
    setSelectedId(id);
  };

  const onSave = async (reason: string): Promise<ActionResult> => {
    if (!selected) return { error: t("nothingSelected") };
    try {
      const resp = await clinicalClient.adminUpdateModalityPrompt({
        modalityId: selected.modalityId,
        systemPrompt: draft,
        changeNote: reason,
        expectedVersion: selected.version,
      });
      const updated = resp.prompt;
      if (updated) {
        setPrompts((cur) =>
          cur.map((p) => (p.modalityId === updated.modalityId ? updated : p)),
        );
        setDraft(updated.systemPrompt);
      }
      void loadHistory(selected.modalityId);
      setSavedFlash(true);
      window.setTimeout(() => setSavedFlash(false), 4000);
      return "success";
    } catch (e) {
      return { error: translateError(e, tErrors) };
    }
  };

  const startRestore = (v: AdminModalityPromptVersion) => {
    setDraft(v.systemPrompt);
    setSaveIsRestore(v.version);
    setViewVersion(null);
    setCompareVersion(null);
    setSaveOpen(true);
  };

  if (loading) {
    return (
      <div className="px-4 sm:px-6 lg:px-8 py-10">
        <p className="font-serif text-mist text-sm">{t("loading")}</p>
      </div>
    );
  }
  if (loadError) {
    return (
      <div className="px-4 sm:px-6 lg:px-8 py-10">
        <p role="alert" className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-serif text-sm text-frost">
          {loadError}
        </p>
      </div>
    );
  }

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8 max-w-7xl mx-auto">
      <h1 className="font-display text-frost text-2xl sm:text-3xl font-semibold tracking-tight">
        {t("title")}
      </h1>
      <p className="font-serif text-mist text-sm mt-2 mb-6 max-w-3xl leading-relaxed">
        {t("banner")}
      </p>

      <div className="grid grid-cols-1 lg:grid-cols-[260px_1fr] gap-6">
        {/* ── Left rail: modality list ───────────────────────────── */}
        <nav aria-label={t("listLabel")} className="flex flex-col gap-1.5">
          {prompts.map((p) => {
            const active = p.modalityId === selectedId;
            const isDirty = active && dirty;
            return (
              <button
                key={p.modalityId}
                type="button"
                onClick={() => selectModality(p.modalityId)}
                className={`text-left rounded-button border px-3.5 py-2.5 transition ${
                  active
                    ? "border-ember/50 bg-ember/10"
                    : "border-frost/10 hover:border-frost/25"
                }`}
              >
                <div className="flex items-center justify-between gap-2">
                  <span className="font-mono text-xs uppercase tracking-[var(--tracking-label)] text-frost">
                    {p.systemCode}
                  </span>
                  <span className="font-mono text-[10px] text-mist">
                    v{p.version}
                    {isDirty && <span aria-label={t("unsaved")} className="text-ember ml-1">●</span>}
                  </span>
                </div>
                <div className="font-serif text-xs text-mist mt-0.5 truncate">
                  {p.displayName}
                  {!p.isSupported && (
                    <span className="ml-1.5 text-mist/50">({t("unsupported")})</span>
                  )}
                </div>
              </button>
            );
          })}
        </nav>

        {/* ── Main: editor + history ─────────────────────────────── */}
        {selected ? (
          <div className="min-w-0">
            <div className="rounded-glass border border-glass-border/60 bg-evergreen/60 p-5">
              <div className="flex flex-wrap items-baseline justify-between gap-2 mb-4">
                <div>
                  <h2 className="font-display text-frost text-lg font-semibold">
                    {selected.displayName}{" "}
                    <span className="font-mono text-xs text-mist">({selected.systemCode} · {selected.modalityType})</span>
                  </h2>
                  <p className="font-mono text-[11px] text-mist mt-1">
                    {t("versionMeta", {
                      version: selected.version,
                      author: selected.updatedByEmail || "—",
                      date: fmtDate(selected.updatedAt),
                    })}
                  </p>
                </div>
                {savedFlash && (
                  <span role="status" className="rounded-button border border-aurora/40 bg-aurora/10 px-3 py-1 font-mono text-[11px] text-frost">
                    {t("saved")}
                  </span>
                )}
              </div>

              <textarea
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                spellCheck={false}
                aria-label={t("editorLabel")}
                className="w-full min-h-[50vh] rounded-button bg-obsidian/40 border border-frost/15 text-frost px-4 py-3 font-mono text-[13px] leading-relaxed focus:outline-none focus:border-ember transition resize-vertical"
              />

              <div className="flex flex-wrap items-center justify-between gap-3 mt-3">
                <span className={`font-mono text-[11px] ${overLimit ? "text-magma" : "text-mist"}`}>
                  {draft.length.toLocaleString("pl-PL")} / {MAX_PROMPT_CHARS.toLocaleString("pl-PL")}
                </span>
                <div className="flex gap-2">
                  <button
                    type="button"
                    disabled={!dirty}
                    onClick={() => setDiffOpen(true)}
                    className="rounded-button border border-frost/15 px-3.5 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost hover:border-frost/30 transition disabled:opacity-40"
                  >
                    {t("showDiff")}
                  </button>
                  <button
                    type="button"
                    disabled={!dirty}
                    onClick={() => setDraft(selected.systemPrompt)}
                    className="rounded-button border border-frost/15 px-3.5 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost hover:border-frost/30 transition disabled:opacity-40"
                  >
                    {t("discard")}
                  </button>
                  <button
                    type="button"
                    disabled={!dirty || overLimit || draft.trim().length === 0}
                    onClick={() => {
                      setSaveIsRestore(null);
                      setSaveOpen(true);
                    }}
                    className="rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-xs px-4 py-2 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {t("save")}
                  </button>
                </div>
              </div>

              <details className="mt-5 group">
                <summary className="cursor-pointer font-mono text-[11px] uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost transition">
                  {t("contextTitle")}
                </summary>
                <p className="font-serif text-xs text-mist mt-2 leading-relaxed">{t("contextBody")}</p>
                <pre className="mt-3 rounded-button bg-obsidian/40 border border-frost/10 p-4 font-mono text-[11px] text-mist/80 whitespace-pre overflow-x-auto">
                  {CALL2_CONTEXT_SKETCH}
                </pre>
              </details>
            </div>

            {/* ── History ──────────────────────────────────────── */}
            <div className="rounded-glass border border-glass-border/60 bg-evergreen/60 p-5 mt-6">
              <h3 className="font-display text-frost text-base font-semibold mb-3">{t("historyTitle")}</h3>
              {historyLoading ? (
                <p className="font-serif text-mist text-sm">{t("loading")}</p>
              ) : history.length === 0 ? (
                <p className="font-serif text-mist text-sm">{t("historyEmpty")}</p>
              ) : (
                <ul className="divide-y divide-frost/10">
                  {history.map((v) => (
                    <li key={v.id} className="py-3 flex flex-wrap items-center justify-between gap-3">
                      <div className="min-w-0">
                        <span className="font-mono text-xs text-frost">v{v.version}</span>
                        <span className="font-mono text-[11px] text-mist ml-3">{fmtDate(v.createdAt)}</span>
                        <span className="font-mono text-[11px] text-mist ml-3">{v.createdByEmail || "—"}</span>
                        <p className="font-serif text-xs text-mist mt-1 truncate max-w-xl">„{v.changeNote}”</p>
                      </div>
                      <div className="flex gap-2 shrink-0">
                        <button
                          type="button"
                          onClick={() => setViewVersion(v)}
                          className="rounded-button border border-frost/15 px-3 py-1.5 font-mono text-[11px] text-mist hover:text-frost hover:border-frost/30 transition"
                        >
                          {t("view")}
                        </button>
                        <button
                          type="button"
                          disabled={v.version === selected.version}
                          onClick={() => setCompareVersion(v)}
                          className="rounded-button border border-frost/15 px-3 py-1.5 font-mono text-[11px] text-mist hover:text-frost hover:border-frost/30 transition disabled:opacity-40"
                        >
                          {t("compare")}
                        </button>
                        <button
                          type="button"
                          disabled={v.version === selected.version}
                          onClick={() => startRestore(v)}
                          className="rounded-button border border-ember/40 px-3 py-1.5 font-mono text-[11px] text-ember hover:bg-ember/10 transition disabled:opacity-40"
                        >
                          {t("restore")}
                        </button>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
              {historyHasMore && (
                <p className="font-mono text-[11px] text-mist mt-3">{t("historyMore")}</p>
              )}
            </div>
          </div>
        ) : (
          <p className="font-serif text-mist text-sm">{t("nothingSelected")}</p>
        )}
      </div>

      {/* ── Modals ───────────────────────────────────────────────── */}
      {selected && (
        <ActionDialog
          open={saveOpen}
          title={saveIsRestore !== null ? t("restoreDialogTitle", { version: saveIsRestore }) : t("saveDialogTitle")}
          body={
            saveIsRestore !== null
              ? t("restoreDialogBody", { version: saveIsRestore, code: selected.systemCode })
              : t("saveDialogBody", { code: selected.systemCode })
          }
          onClose={() => setSaveOpen(false)}
          onConfirm={onSave}
        />
      )}

      {diffOpen && selected && (
        <Overlay title={t("diffTitle", { version: selected.version })} onClose={() => setDiffOpen(false)}>
          <DiffView ops={diffLines(selected.systemPrompt, draft)} />
        </Overlay>
      )}

      {viewVersion && (
        <Overlay title={t("viewTitle", { version: viewVersion.version })} onClose={() => setViewVersion(null)}>
          <pre className="font-mono text-xs leading-relaxed whitespace-pre-wrap max-h-[55vh] overflow-y-auto rounded-button bg-obsidian/40 border border-frost/10 p-4 text-mist">
            {viewVersion.systemPrompt}
          </pre>
        </Overlay>
      )}

      {compareVersion && selected && (
        <Overlay
          title={t("compareTitle", { from: compareVersion.version, to: selected.version })}
          onClose={() => setCompareVersion(null)}
        >
          <DiffView ops={diffLines(compareVersion.systemPrompt, selected.systemPrompt)} />
        </Overlay>
      )}
    </div>
  );
}
