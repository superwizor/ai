// Nowy konstrukt z TRZECH PYTAŃ (dok. 17 §3.2).
//
// Ekspert nie widzi słów `multi_label`, `kind` ani `values`. Widzi
// pytania o swoją dziedzinę, a trzy odpowiedzi rozstrzygają cały kształt
// konstruktu. Formularz pól wymagałby od niego znajomości metaschematu —
// czyli dokładnie tego, czego kreator ma go oszczędzić.
//
// Identyfikator powstaje z nazwy i jest POKAZANY, nie ukryty: trafia do
// `is_not` i `requires` innych konstruktów, więc ekspert zobaczy go
// jeszcze wiele razy i lepiej, żeby go rozpoznał.

"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";

import { slugify, type NewConstructShape } from "@/lib/ontology/model";

export function NewConstructWizard({
  istniejaceId,
  onCancel,
  onCreate,
}: {
  istniejaceId: string[];
  onCancel: () => void;
  onCreate: (shape: NewConstructShape) => void;
}) {
  const t = useTranslations("admin.ontologyWizard");
  const [labelPl, setLabelPl] = useState("");
  const [definition, setDefinition] = useState("");
  const [hasCatalogue, setHasCatalogue] = useState<boolean | null>(null);
  const [multiLabel, setMultiLabel] = useState(false);
  const [composite, setComposite] = useState(false);
  const [idRecznie, setIdRecznie] = useState<string | null>(null);

  const id = idRecznie ?? slugify(labelPl);
  const kolizja = id !== "" && istniejaceId.includes(id);
  const idPoprawny = /^[a-z][a-z0-9_]*$/.test(id);
  const gotowe =
    labelPl.trim() !== "" && idPoprawny && !kolizja && (composite || hasCatalogue !== null);

  return (
    <div className="grid gap-5 border border-ember/40 p-5">
      <h3 className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember">
        {t("title")}
      </h3>

      <label className="grid gap-1">
        <span className="font-serif text-frost text-sm">{t("nameLabel")}</span>
        <input
          value={labelPl}
          onChange={(e) => setLabelPl(e.target.value)}
          placeholder={t("namePlaceholder")}
          className="bg-abyss border border-frost/20 text-frost px-3 py-2 font-serif"
          data-testid="wizard-name"
        />
        {id !== "" && (
          <span className="font-mono text-[10px] text-mist">
            {t("idPreview")} <span className="text-frost">{id}</span>
            {kolizja && <span className="text-magma"> — {t("idTaken")}</span>}
          </span>
        )}
      </label>

      <label className="grid gap-1">
        <span className="font-serif text-frost text-sm">{t("definitionLabel")}</span>
        <textarea
          value={definition}
          onChange={(e) => setDefinition(e.target.value)}
          rows={3}
          placeholder={t("definitionPlaceholder")}
          className="bg-abyss border border-frost/20 text-frost px-3 py-2 font-serif text-sm"
        />
      </label>

      {/* Pytanie 3 stoi przed 1 i 2, bo kompozyt czyni je bezprzedmiotowymi. */}
      <Pytanie
        tekst={t("q3")}
        pomoc={t("q3Help")}
        wybor={composite}
        onChange={setComposite}
        tak={t("q3Yes")}
        nie={t("q3No")}
      />

      {!composite && (
        <>
          <Pytanie
            tekst={t("q1")}
            pomoc={t("q1Help")}
            wybor={hasCatalogue}
            onChange={setHasCatalogue}
            tak={t("q1Yes")}
            nie={t("q1No")}
          />
          {hasCatalogue === true && (
            <Pytanie
              tekst={t("q2")}
              pomoc={t("q2Help")}
              wybor={multiLabel}
              onChange={setMultiLabel}
              tak={t("q2Yes")}
              nie={t("q2No")}
            />
          )}
        </>
      )}

      <details className="text-mist">
        <summary className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] cursor-pointer">
          {t("advancedId")}
        </summary>
        <input
          value={id}
          onChange={(e) => setIdRecznie(e.target.value)}
          className="mt-2 bg-abyss border border-frost/20 text-frost px-3 py-2 font-mono text-sm w-full"
          data-testid="wizard-id"
        />
        {!idPoprawny && id !== "" && (
          <p className="text-magma text-xs mt-1">{t("idInvalid")}</p>
        )}
      </details>

      <div className="flex gap-3">
        <button
          type="button"
          disabled={!gotowe}
          onClick={() =>
            onCreate({
              id,
              labelPl: labelPl.trim(),
              definition,
              hasCatalogue: hasCatalogue === true,
              multiLabel,
              composite,
            })
          }
          className="border border-ember text-ember px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:bg-ember/10 disabled:opacity-40"
          data-testid="wizard-create"
        >
          {t("create")}
        </button>
        <button
          type="button"
          onClick={onCancel}
          className="border border-frost/30 text-frost px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:bg-frost/10"
        >
          {t("cancel")}
        </button>
      </div>
    </div>
  );
}

/** Pytanie tak/nie. `wybor === null` = jeszcze nieodpowiedziane, co jest
 * czym innym niż „nie" — bez tego rozróżnienia przycisk tworzenia
 * odblokowałby się, zanim ekspert cokolwiek zdecydował. */
function Pytanie({
  tekst,
  pomoc,
  wybor,
  onChange,
  tak,
  nie,
}: {
  tekst: string;
  pomoc: string;
  wybor: boolean | null;
  onChange: (v: boolean) => void;
  tak: string;
  nie: string;
}) {
  return (
    <div className="grid gap-2">
      <p className="font-serif text-frost">{tekst}</p>
      <p className="font-serif text-mist text-xs">{pomoc}</p>
      <div className="flex gap-2">
        {[
          { v: true, label: tak },
          { v: false, label: nie },
        ].map((o) => (
          <button
            key={String(o.v)}
            type="button"
            onClick={() => onChange(o.v)}
            className={`px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] border ${
              wybor === o.v
                ? "border-ember text-ember bg-ember/10"
                : "border-frost/25 text-frost/70 hover:bg-frost/5"
            }`}
          >
            {o.label}
          </button>
        ))}
      </div>
    </div>
  );
}
