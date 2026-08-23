// Spina model YAML-a z formularzami (dok. 17, K1 + K2).
//
// Trzyma `Document` w referencji, a nie w stanie: każda edycja nakłada
// zmianę na węzeł i dopiero wynik serializacji trafia do góry jako tekst.
// Dzięki temu komentarze ekspertów przeżywają edycję — a to one niosą
// `# ZWERYFIKOWAĆ`, czyli jedyny ślad tego, co jeszcze wymaga decyzji.

"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";

import {
  addConstruct,
  docToString,
  parseDoc,
  readOntology,
  removeConstruct,
  setConfusions,
  setConstructField,
  setConstructList,
  setMinCompleteSlots,
  setMinEvidence,
  setMultiLabel,
  setSlots,
  setValues,
  type MinEvidence,
  type NewConstructShape,
} from "@/lib/ontology/model";
import { ConstructForm } from "@/components/admin/ontology/ConstructForm";
import { NewConstructWizard } from "@/components/admin/ontology/NewConstructWizard";

export function OntologyFormEditor({
  yamlText,
  readOnly,
  onChange,
}: {
  yamlText: string;
  readOnly: boolean;
  onChange: (yaml: string) => void;
}) {
  const t = useTranslations("admin.ontologyForm");
  const [wybrany, setWybrany] = useState<string | null>(null);
  const [kreator, setKreator] = useState(false);

  // Dokument wyprowadzony CZYSTO z tekstu, bez refów.
  //
  // Każda edycja kończy się `onChange` z nowym tekstem, więc dokument i
  // tak powstaje od nowa — trzymanie go w referencji i mutowanie podczas
  // renderu niczego nie oszczędzało, a łamało regułę Reacta (i lint to
  // wyłapał). Stan mieszka wyłącznie w YAML-u, co jest zresztą jedynym
  // źródłem prawdy, jakie ma serwer.
  const doc = useMemo(() => parseDoc(yamlText), [yamlText]);

  const widok = useMemo(() => {
    try {
      return readOntology(doc);
    } catch {
      return null;
    }
  }, [doc]);

  if (!widok) {
    // YAML, którego formularz nie potrafi wczytać. Nie udajemy, że da się
    // go edytować — odsyłamy do podglądu, gdzie widać, co jest nie tak.
    return <p className="text-magma text-sm">{t("unparseable")}</p>;
  }

  const zapisz = () => onChange(docToString(doc));

  const etykiety = Object.fromEntries(
    widok.constructs.map((c) => [c.id, c.labelPl || c.id]),
  );
  const aktywny = widok.constructs.find((c) => c.id === wybrany) ?? widok.constructs[0] ?? null;

  return (
    <div className="grid gap-4 lg:grid-cols-[260px_1fr]">
      <aside className="grid gap-2 content-start">
        <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember">
          {t("constructsHeading", { count: widok.constructs.length })}
        </p>
        {widok.constructs.map((c) => (
          <button
            key={c.id}
            type="button"
            onClick={() => {
              setWybrany(c.id);
              setKreator(false);
            }}
            className={`text-left px-3 py-2 border ${
              aktywny?.id === c.id
                ? "border-ember text-ember bg-ember/10"
                : "border-white/15 opacity-80 hover:bg-white/5"
            }`}
          >
            <span className="font-serif block">{c.labelPl || c.id}</span>
            <span className="font-mono text-[10px] opacity-60">{c.id}</span>
          </button>
        ))}
        {!readOnly && (
          <button
            type="button"
            onClick={() => setKreator(true)}
            className="border border-ember/60 text-ember px-3 py-2 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] hover:bg-ember/10"
            data-testid="studio-add-construct"
          >
            {t("addConstruct")}
          </button>
        )}
      </aside>

      <div>
        {kreator ? (
          <NewConstructWizard
            istniejaceId={widok.constructs.map((c) => c.id)}
            onCancel={() => setKreator(false)}
            onCreate={(shape: NewConstructShape) => {
              addConstruct(doc, shape);
              setKreator(false);
              setWybrany(shape.id);
              zapisz();
            }}
          />
        ) : aktywny ? (
          <fieldset disabled={readOnly} className={readOnly ? "opacity-70" : ""}>
            <ConstructForm
              konstrukt={aktywny}
              wszystkieId={widok.constructs.map((c) => c.id)}
              etykiety={etykiety}
              edits={{
                labelPl: (v) => {
                  setConstructField(doc, aktywny.id, "label_pl", v);
                  zapisz();
                },
                definition: (v) => {
                  setConstructField(doc, aktywny.id, "definition", v);
                  zapisz();
                },
                values: (v) => {
                  setValues(doc, aktywny.id, v);
                  zapisz();
                },
                multiLabel: (v) => {
                  setMultiLabel(doc, aktywny.id, v);
                  zapisz();
                },
                minEvidence: (v: MinEvidence | null) => {
                  setMinEvidence(doc, aktywny.id, v);
                  zapisz();
                },
                isNot: (v) => {
                  setConstructList(doc, aktywny.id, "is_not", v);
                  zapisz();
                },
                requires: (v) => {
                  setConstructList(doc, aktywny.id, "requires", v);
                  zapisz();
                },
                confusions: (v) => {
                  setConfusions(doc, aktywny.id, v);
                  zapisz();
                },
                slots: (v) => {
                  setSlots(doc, aktywny.id, v);
                  // min_complete_slots musi zmieścić się w NOWEJ liczbie
                  // slotów. Usunięcie slotu poniżej progu zostawiłoby
                  // wartość spoza zakresu, którą walidator odrzuci.
                  setMinCompleteSlots(doc, aktywny.id, aktywny.minCompleteSlots, v.length);
                  zapisz();
                },
                minCompleteSlots: (v) => {
                  setMinCompleteSlots(doc, aktywny.id, v, aktywny.slots.length);
                  zapisz();
                },
                usun: () => {
                  removeConstruct(doc, aktywny.id);
                  setWybrany(null);
                  zapisz();
                },
              }}
            />
          </fieldset>
        ) : (
          <p className="font-serif text-mist text-sm">{t("noConstructs")}</p>
        )}
      </div>
    </div>
  );
}
