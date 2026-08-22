// Ontology Studio — edycja ontologii modalnosci z cyklem zycia
// draft → ready_for_review → approved (plan 16 v1.2 §4.1).
//
// Ten ekran zastapil mechanizm PR + CODEOWNERS, wiec jego zadaniem jest
// NIE UKRYC tego, co tamten mechanizm wymuszal. Stad trzy decyzje
// projektowe widoczne w kodzie nizej:
//
//  1. Status i AKTYWNOSC sa pokazywane osobno. "Zatwierdzona" nie znaczy
//     "serwowana" — aktywacja to odrebna decyzja SUPERWIZOR_ADMIN.
//     Zlanie ich w jeden badge bylo by najkrotsza droga do wlaczenia
//     czegos na produkcji w przekonaniu, ze sie tylko zatwierdza.
//  2. Wersja `approved` nie ma edytora. Przycisk nazywa sie "Nowa wersja
//     z tej" i tworzy draft — niemutowalnosc zastapila niemutowalnosc
//     commita, wiec UI nie moze sugerowac, ze da sie inaczej.
//  3. Lint chodzi na zywo i pokazuje KOMPLET problemow. Autor ma widziec
//     cala liste przed zapisem, a nie odkrywac bledy pojedynczo.
//
// UI nie jest granica bezpieczenstwa: kazde RPC waliduje role i status
// serwerowo. Ukrywanie przyciskow to wygoda, nie kontrola.

"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { timestampDate } from "@bufbuild/protobuf/wkt";

import type {
  OntologyModalitySummary,
  OntologyVersion,
} from "@superwizor/proto-ts/clinical/v1/clinical_pb";
import { OntologyStatus } from "@superwizor/proto-ts/clinical/v1/clinical_pb";

import { clinicalClient } from "@/lib/connect/clients";
import { translateError } from "@/lib/errors/translate";
import { ActionDialog, type ActionResult } from "@/components/admin/ActionDialog";

// Minimalna dlugosc notatki (10 znakow) jest egzekwowana w dwoch
// miejscach: ActionDialog waliduje pole lokalnie, a serwer sprawdza ja
// ponownie (minOntologyNoteChars). Nie duplikujemy stalej tutaj.

type Props = { canActivate?: boolean };

export function OntologyStudio({ canActivate = true }: Props) {
  const t = useTranslations("admin.ontologies");
  const tErrors = useTranslations("errors");

  const [modalities, setModalities] = useState<OntologyModalitySummary[]>([]);
  const [selectedModality, setSelectedModality] = useState<string | null>(null);
  const [versions, setVersions] = useState<OntologyVersion[]>([]);
  const [selected, setSelected] = useState<OntologyVersion | null>(null);

  const [draft, setDraft] = useState("");
  const [problems, setProblems] = useState<string[]>([]);
  const [constructCount, setConstructCount] = useState(0);
  const [linting, setLinting] = useState(false);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [flash, setFlash] = useState<string | null>(null);
  const [dialog, setDialog] = useState<null | {
    kind: "submit" | "approve" | "reject" | "activate" | "save" | "branch";
  }>(null);

  // ── odczyt ──

  const loadModalities = useCallback(async () => {
    setLoading(true);
    try {
      const resp = await clinicalClient.ontologyListModalities({});
      setModalities(resp.modalities);
      setError(null);
      if (!selectedModality && resp.modalities.length > 0) {
        setSelectedModality(resp.modalities[0].modalityId);
      }
    } catch (err) {
      setError(translateError(err, tErrors));
    } finally {
      setLoading(false);
    }
  }, [selectedModality, tErrors]);

  const loadVersions = useCallback(
    async (modalityId: string) => {
      try {
        const resp = await clinicalClient.ontologyListVersions({ modalityId });
        setVersions(resp.versions);
        setSelected(resp.versions[0] ?? null);
        setDraft(resp.versions[0]?.contentYaml ?? "");
      } catch (err) {
        setError(translateError(err, tErrors));
      }
    },
    [tErrors],
  );

  useEffect(() => {
    void loadModalities();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (selectedModality) void loadVersions(selectedModality);
  }, [selectedModality, loadVersions]);

  // ── lint na zywo ──
  //
  // Debounce 500 ms: walidacja jest serwerowa (ta sama implementacja co
  // przy zapisie), wiec kazde nacisniecie klawisza nie moze isc po sieci.
  useEffect(() => {
    if (!draft) {
      setProblems([]);
      setConstructCount(0);
      return;
    }
    const id = setTimeout(async () => {
      setLinting(true);
      try {
        const resp = await clinicalClient.ontologyLint({ contentYaml: draft });
        setProblems(resp.problems);
        setConstructCount(resp.constructCount);
      } catch {
        // Blad sieci nie jest problemem TRESCI — nie wpisujemy go na
        // liste problemow metaschematu, zeby autor nie szukal go w YAML-u.
      } finally {
        setLinting(false);
      }
    }, 500);
    return () => clearTimeout(id);
  }, [draft]);

  const isDraft = selected?.status === OntologyStatus.DRAFT;
  const isReview = selected?.status === OntologyStatus.READY_FOR_REVIEW;
  const isApproved = selected?.status === OntologyStatus.APPROVED;
  const dirty = !!selected && draft !== selected.contentYaml;
  const blocked = problems.length > 0;

  const currentModality = useMemo(
    () => modalities.find((m) => m.modalityId === selectedModality) ?? null,
    [modalities, selectedModality],
  );

  // ── mutacje ──

  const runAction = useCallback(
    async (note: string): Promise<ActionResult> => {
      if (!selected || !dialog) return { error: "—" };
      try {
        switch (dialog.kind) {
          case "save":
            await clinicalClient.ontologyUpdateDraft({
              versionId: selected.id,
              contentYaml: draft,
              changeNote: note,
            });
            break;
          case "branch":
            // "Edytuj" wersji zatwierdzonej = nowy draft. Oryginal
            // zostaje nietkniety (niemutowalnosc).
            await clinicalClient.ontologyCreateDraft({
              modalityId: selected.modalityId,
              copyFromVersionId: selected.id,
              version: bumpPatch(selected.version),
              changeNote: note,
            });
            break;
          case "submit":
            await clinicalClient.ontologySubmitForReview({ versionId: selected.id, note });
            break;
          case "approve":
            await clinicalClient.ontologyApprove({ versionId: selected.id, note });
            break;
          case "reject":
            await clinicalClient.ontologyReject({ versionId: selected.id, note });
            break;
          case "activate":
            await clinicalClient.ontologyActivateVersion({ versionId: selected.id, note });
            break;
        }
        setFlash(t(`flash.${dialog.kind}`));
        setDialog(null);
        if (selectedModality) await loadVersions(selectedModality);
        await loadModalities();
        return "success";
      } catch (err) {
        return { error: translateError(err, tErrors) };
      }
    },
    [selected, dialog, draft, selectedModality, loadVersions, loadModalities, t, tErrors],
  );

  if (loading) return <p className="p-6 text-sm">{t("loading")}</p>;

  return (
    <div className="flex flex-col gap-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">{t("title")}</h1>
        <p className="mt-1 max-w-3xl text-sm opacity-80">{t("intro")}</p>
      </header>

      {error && <p className="rounded border border-red-400 p-3 text-sm">{error}</p>}
      {flash && <p className="rounded border border-green-500 p-3 text-sm">{flash}</p>}

      <div className="flex flex-col gap-6 lg:flex-row">
        {/* Lista modalnosci — aktywna wersja jest tu najwazniejsza
            informacja, bo to ona generuje raporty. */}
        <nav className="w-full lg:w-64" aria-label={t("modalitiesLabel")}>
          <ul className="flex flex-col gap-2">
            {modalities.map((m) => (
              <li key={m.modalityId}>
                <button
                  type="button"
                  onClick={() => setSelectedModality(m.modalityId)}
                  aria-current={m.modalityId === selectedModality}
                  className={`w-full rounded border p-3 text-left text-sm ${
                    m.modalityId === selectedModality ? "border-amber-400" : "border-white/15"
                  }`}
                >
                  <span className="font-mono text-xs opacity-70">{m.systemCode}</span>
                  <span className="block">{m.displayName}</span>
                  <span className="mt-1 block text-xs opacity-70">
                    {m.activeVersion
                      ? t("activeVersion", { version: m.activeVersion })
                      : t("noActiveVersion")}
                  </span>
                  {(m.draftCount > 0 || m.reviewCount > 0) && (
                    <span className="mt-1 block text-xs opacity-60">
                      {t("pendingCounts", { drafts: m.draftCount, reviews: m.reviewCount })}
                    </span>
                  )}
                </button>
              </li>
            ))}
          </ul>
        </nav>

        <section className="flex-1">
          {!selected ? (
            <p className="text-sm opacity-80">{t("noVersions")}</p>
          ) : (
            <>
              <div className="mb-3 flex flex-wrap items-center gap-3">
                <select
                  value={selected.id}
                  onChange={(e) => {
                    const v = versions.find((x) => x.id === e.target.value) ?? null;
                    setSelected(v);
                    setDraft(v?.contentYaml ?? "");
                  }}
                  aria-label={t("versionLabel")}
                  className="rounded border border-white/20 bg-transparent p-2 text-sm"
                >
                  {versions.map((v) => (
                    <option key={v.id} value={v.id}>
                      {v.version} · {statusLabel(v.status, t)}
                      {v.isActive ? ` · ${t("activeSuffix")}` : ""}
                    </option>
                  ))}
                </select>

                {/* Status i aktywnosc SA ROZDZIELONE — patrz naglowek pliku. */}
                <StatusBadge status={selected.status} t={t} />
                {selected.isActive && (
                  <span className="rounded bg-green-600/20 px-2 py-1 text-xs">
                    {t("badgeActive")}
                  </span>
                )}
                <span className="text-xs opacity-70">
                  {t("constructCount", { count: constructCount || selected.constructCount })}
                </span>
              </div>

              <p className="mb-3 text-xs opacity-70">
                {t("createdBy", {
                  email: selected.createdByEmail,
                  date: selected.createdAt
                    ? timestampDate(selected.createdAt).toLocaleString()
                    : "—",
                })}
                {selected.approvedByEmail
                  ? ` · ${t("approvedBy", { email: selected.approvedByEmail })}`
                  : ""}
              </p>

              <textarea
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                readOnly={!isDraft}
                spellCheck={false}
                rows={24}
                aria-label={t("editorLabel")}
                className="w-full rounded border border-white/20 bg-black/20 p-3 font-mono text-xs"
              />

              {!isDraft && (
                <p className="mt-2 text-xs opacity-70">
                  {isApproved ? t("readOnlyApproved") : t("readOnlyReview")}
                </p>
              )}

              {/* Komplet problemow, nie pierwszy. */}
              <div className="mt-3" aria-live="polite">
                {linting && <p className="text-xs opacity-60">{t("linting")}</p>}
                {problems.length > 0 && (
                  <ul className="rounded border border-red-400 p-3 text-xs">
                    {problems.map((p) => (
                      <li key={p} className="font-mono">
                        {p}
                      </li>
                    ))}
                  </ul>
                )}
                {!linting && problems.length === 0 && draft && (
                  <p className="text-xs text-green-400">{t("lintClean")}</p>
                )}
              </div>

              <div className="mt-4 flex flex-wrap gap-2">
                {isDraft && (
                  <>
                    <button
                      type="button"
                      disabled={!dirty || blocked}
                      onClick={() => setDialog({ kind: "save" })}
                      className="rounded bg-amber-400 px-4 py-2 text-sm text-black disabled:opacity-40"
                    >
                      {t("actions.save")}
                    </button>
                    <button
                      type="button"
                      disabled={dirty || blocked}
                      onClick={() => setDialog({ kind: "submit" })}
                      className="rounded border border-white/30 px-4 py-2 text-sm disabled:opacity-40"
                      title={dirty ? t("saveBeforeSubmit") : undefined}
                    >
                      {t("actions.submit")}
                    </button>
                  </>
                )}

                {isReview && (
                  <>
                    <button
                      type="button"
                      onClick={() => setDialog({ kind: "approve" })}
                      className="rounded bg-green-500 px-4 py-2 text-sm text-black"
                    >
                      {t("actions.approve")}
                    </button>
                    <button
                      type="button"
                      onClick={() => setDialog({ kind: "reject" })}
                      className="rounded border border-white/30 px-4 py-2 text-sm"
                    >
                      {t("actions.reject")}
                    </button>
                    <p className="w-full text-xs opacity-70">{t("fourEyesHint")}</p>
                  </>
                )}

                {isApproved && (
                  <>
                    <button
                      type="button"
                      onClick={() => setDialog({ kind: "branch" })}
                      className="rounded border border-white/30 px-4 py-2 text-sm"
                    >
                      {t("actions.branch")}
                    </button>
                    {canActivate && !selected.isActive && (
                      <button
                        type="button"
                        onClick={() => setDialog({ kind: "activate" })}
                        className="rounded bg-red-500 px-4 py-2 text-sm text-black"
                      >
                        {t("actions.activate")}
                      </button>
                    )}
                    {!canActivate && (
                      <p className="w-full text-xs opacity-70">{t("activateAdminOnly")}</p>
                    )}
                  </>
                )}
              </div>

              {isApproved && canActivate && !selected.isActive && (
                <p className="mt-2 max-w-2xl text-xs opacity-70">{t("activateWarning")}</p>
              )}
            </>
          )}
        </section>
      </div>

      {dialog && (
        <ActionDialog
          open
          title={t(`dialog.${dialog.kind}.title`)}
          body={t(`dialog.${dialog.kind}.body`, {
            modality: currentModality?.systemCode ?? "",
            version: selected?.version ?? "",
          })}
          onConfirm={runAction}
          onClose={() => setDialog(null)}
        />
      )}
    </div>
  );
}

function StatusBadge({
  status,
  t,
}: {
  status: OntologyStatus;
  t: ReturnType<typeof useTranslations>;
}) {
  const tone =
    status === OntologyStatus.APPROVED
      ? "bg-green-600/20"
      : status === OntologyStatus.READY_FOR_REVIEW
        ? "bg-amber-500/20"
        : "bg-white/10";
  return <span className={`rounded px-2 py-1 text-xs ${tone}`}>{statusLabel(status, t)}</span>;
}

function statusLabel(status: OntologyStatus, t: ReturnType<typeof useTranslations>): string {
  switch (status) {
    case OntologyStatus.DRAFT:
      return t("status.draft");
    case OntologyStatus.READY_FOR_REVIEW:
      return t("status.review");
    case OntologyStatus.APPROVED:
      return t("status.approved");
    default:
      return t("status.unknown");
  }
}

/**
 * Podbija PATCH w semver dla nowej wersji roboczej.
 *
 * Propozycja, nie regula: autor moze ja zmienic przed zapisem. Wybor
 * PATCH-a jest konserwatywny — rozgalezienie z zatwierdzonej wersji
 * czesciej jest poprawka niz zmiana taksonomii.
 */
export function bumpPatch(version: string): string {
  const m = /^(\d+)\.(\d+)\.(\d+)$/.exec(version.trim());
  if (!m) return version;
  return `${m[1]}.${m[2]}.${Number(m[3]) + 1}`;
}
