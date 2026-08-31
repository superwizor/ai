// Formularz jednego konstruktu (dok. 17, K1 + K2).
//
// ══ Co tu jest NIEMOŻLIWE do zepsucia ══
//
// `is_not` i `requires` to PICKERY konstruktów, nigdy wolny tekst.
// Metaschemat wymaga tam identyfikatorów, a przy pisaniu szkicu PPT
// wpisałem w `is_not` opis („potrzeba", „zasób") przepisany z dokumentu
// 11 — złapał to dopiero lint, po zapisie, a błąd wyglądał na literówkę,
// nie na nieporozumienie co do typu pola. Ekspert kliniczny popełni go
// na pewno, jeśli dostanie tam pole tekstowe.
//
// Konstrukt jest wykluczony z własnego pickera: metaschemat odrzuca
// samo-referencję, więc nie ma czego oferować.
//
// ══ Dlaczego granice i pomyłki dostają własną sekcję ══
//
// To pola, które REALNIE WIDZI S2 przy mapowaniu — i najmocniej wpływają
// na jakość wyniku. Są też najmniej oczywiste, bo w podręczniku nie ma
// rozdziału „czym to nie jest". Pytania stawiamy więc w języku dziedziny,
// nie nazwami pól.

"use client";

import { useTranslations } from "next-intl";

import type { ConstructView, MinEvidence, SlotView } from "@/lib/ontology/model";
import { SlotEditor } from "@/components/admin/ontology/SlotEditor";

export interface ConstructEdits {
  labelPl: (v: string) => void;
  definition: (v: string) => void;
  values: (v: string[] | null) => void;
  valueGloss: (value: string, gloss: string) => void;
  multiLabel: (v: boolean) => void;
  minEvidence: (v: MinEvidence | null) => void;
  isNot: (v: string[]) => void;
  requires: (v: string[]) => void;
  confusions: (v: { input: string; correct: string; note?: string }[]) => void;
  slots: (v: SlotView[]) => void;
  minCompleteSlots: (v: number | null) => void;
  usun: () => void;
}

export function ConstructForm({
  konstrukt,
  wszystkieId,
  etykiety,
  edits,
}: {
  konstrukt: ConstructView;
  wszystkieId: string[];
  etykiety: Record<string, string>;
  edits: ConstructEdits;
}) {
  const t = useTranslations("admin.ontologyForm");
  const inne = wszystkieId.filter((id) => id !== konstrukt.id);

  return (
    <div className="grid gap-6">
      <Sekcja tytul={t("sectionBasics")}>
        <Pole etykieta={t("labelPl")}>
          <input
            value={konstrukt.labelPl}
            onChange={(e) => edits.labelPl(e.target.value)}
            className="bg-abyss border border-frost/20 text-frost px-3 py-2 font-serif w-full"
            data-testid="form-label"
          />
        </Pole>
        <Pole etykieta={t("definition")} pomoc={t("definitionHelp")}>
          <textarea
            value={konstrukt.definition}
            onChange={(e) => edits.definition(e.target.value)}
            rows={4}
            className="bg-abyss border border-frost/20 text-frost px-3 py-2 font-serif text-sm w-full"
          />
        </Pole>
      </Sekcja>

      {konstrukt.kind === "composite" ? (
        <Sekcja tytul={t("sectionComposite")} pomoc={t("compositeHelp")}>
          <SlotEditor
            sloty={konstrukt.slots}
            minComplete={konstrukt.minCompleteSlots}
            wlasnyId={konstrukt.id}
            wszystkieId={wszystkieId}
            etykiety={etykiety}
            onSlots={edits.slots}
            onMinComplete={edits.minCompleteSlots}
          />
        </Sekcja>
      ) : (
        <Sekcja tytul={t("sectionCatalogue")}>
          {konstrukt.values === null ? (
            <div className="grid gap-2">
              <p className="font-serif text-mist text-sm">{t("noCatalogue")}</p>
              <button
                type="button"
                onClick={() => edits.values([])}
                className="justify-self-start border border-frost/30 text-frost px-3 py-1.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] hover:bg-frost/10"
              >
                {t("addCatalogue")}
              </button>
            </div>
          ) : (
            <>
              <ListaWartosci
                wartosci={konstrukt.values}
                glosy={konstrukt.valueGlosses}
                onChange={edits.values}
                onGloss={edits.valueGloss}
                t={t}
              />
              <label className="flex items-center gap-2 mt-3">
                <input
                  type="checkbox"
                  checked={konstrukt.multiLabel}
                  onChange={(e) => edits.multiLabel(e.target.checked)}
                  data-testid="form-multilabel"
                />
                <span className="font-serif text-frost text-sm">{t("multiLabel")}</span>
              </label>
              <p className="font-serif text-mist text-xs mt-1">{t("multiLabelHelp")}</p>
            </>
          )}
        </Sekcja>
      )}

      <Sekcja tytul={t("sectionEvidence")} pomoc={t("evidenceHelp")}>
        <ProgDowodowy me={konstrukt.minEvidence} onChange={edits.minEvidence} t={t} />
      </Sekcja>

      {/* ── K2: granice i pomyłki ── */}
      <Sekcja tytul={t("sectionBoundaries")} pomoc={t("boundariesHelp")}>
        <Pole etykieta={t("isNot")} pomoc={t("isNotHelp")}>
          <PickerKonstruktow
            dostepne={inne}
            wybrane={konstrukt.isNot}
            etykiety={etykiety}
            onChange={edits.isNot}
            pusteInfo={t("noOtherConstructs")}
            testId="form-isnot"
          />
        </Pole>
        <Pole etykieta={t("requires")} pomoc={t("requiresHelp")}>
          <PickerKonstruktow
            dostepne={inne}
            wybrane={konstrukt.requires}
            etykiety={etykiety}
            onChange={edits.requires}
            pusteInfo={t("noOtherConstructs")}
            testId="form-requires"
          />
        </Pole>
      </Sekcja>

      <Sekcja tytul={t("sectionConfusions")} pomoc={t("confusionsHelp")}>
        <Pomylki lista={konstrukt.confusions} onChange={edits.confusions} t={t} />
      </Sekcja>

      <button
        type="button"
        onClick={edits.usun}
        className="justify-self-start border border-magma/50 text-magma px-3 py-1.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] hover:bg-magma/10"
      >
        {t("removeConstruct")}
      </button>
    </div>
  );
}

/** Picker konstruktów — kliknięcie przełącza.
 *
 * Nie multi-select ani wolny tekst: lista konstruktów jest krótka
 * (najdłuższa ontologia ma 15), a widok wszystkich naraz pokazuje
 * ekspertowi granice, o których myśli. */
function PickerKonstruktow({
  dostepne,
  wybrane,
  etykiety,
  onChange,
  pusteInfo,
  testId,
}: {
  dostepne: string[];
  wybrane: string[];
  etykiety: Record<string, string>;
  onChange: (v: string[]) => void;
  pusteInfo: string;
  testId: string;
}) {
  if (dostepne.length === 0) {
    return <p className="font-serif text-mist text-xs">{pusteInfo}</p>;
  }
  return (
    <div className="flex flex-wrap gap-2" data-testid={testId}>
      {dostepne.map((id) => {
        const on = wybrane.includes(id);
        return (
          <button
            key={id}
            type="button"
            onClick={() =>
              onChange(on ? wybrane.filter((x) => x !== id) : [...wybrane, id])
            }
            className={`px-3 py-1.5 border font-serif text-sm ${
              on
                ? "border-ember text-ember bg-ember/10"
                : "border-frost/25 text-frost/70 hover:bg-frost/5"
            }`}
            title={id}
          >
            {etykiety[id] ?? id}
          </button>
        );
      })}
    </div>
  );
}

function ListaWartosci({
  wartosci,
  glosy,
  onChange,
  onGloss,
  t,
}: {
  wartosci: string[];
  glosy: Record<string, string>;
  onChange: (v: string[]) => void;
  onGloss: (value: string, gloss: string) => void;
  t: (k: string) => string;
}) {
  return (
    <div className="grid gap-2" data-testid="form-values">
      {wartosci.map((w, i) => (
        <div key={i} className="grid gap-1">
          <div className="flex gap-2">
            <input
              value={w}
              onChange={(e) => {
                const next = [...wartosci];
                next[i] = e.target.value;
                onChange(next);
              }}
              className="bg-abyss border border-frost/20 text-frost px-3 py-2 font-serif text-sm flex-1"
            />
            <button
              type="button"
              onClick={() => onChange(wartosci.filter((_, j) => j !== i))}
              className="border border-frost/25 text-frost/70 px-3 font-mono text-xs hover:bg-frost/10"
              aria-label={t("removeValue")}
            >
              ×
            </button>
          </div>
          {/* Glosa: objaśnienie pozycji, nie definicja (limit 120 znaków —
              twardo pilnuje go walidacja serwera, G3). Pole tylko dla
              wartości już nazwanej: glosa pustej wartości nie ma sensu. */}
          {w.trim() !== "" && (
            <input
              value={glosy[w] ?? ""}
              onChange={(e) => onGloss(w, e.target.value)}
              maxLength={120}
              placeholder={t("glossPlaceholder")}
              aria-label={`${t("glossLabel")}: ${w}`}
              data-testid={`form-gloss-${i}`}
              className="bg-abyss border border-frost/10 text-mist px-3 py-1.5 font-serif text-xs ml-4"
            />
          )}
        </div>
      ))}
      <div className="flex gap-2">
        <button
          type="button"
          onClick={() => onChange([...wartosci, ""])}
          className="border border-frost/30 text-frost px-3 py-1.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] hover:bg-frost/10"
        >
          {t("addValue")}
        </button>
        <button
          type="button"
          onClick={() => onChange([])}
          className="border border-frost/20 text-mist px-3 py-1.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] hover:bg-frost/5"
        >
          {t("clearCatalogue")}
        </button>
      </div>
    </div>
  );
}

function ProgDowodowy({
  me,
  onChange,
  t,
}: {
  me: MinEvidence | null;
  onChange: (v: MinEvidence | null) => void;
  t: (k: string) => string;
}) {
  const biezace = me ?? { spans: 1 };
  return (
    <div className="flex flex-wrap gap-4 items-end" data-testid="form-evidence">
      <Licznik
        etykieta={t("evidenceSpans")}
        wartosc={biezace.spans}
        min={1}
        onChange={(v) => onChange({ ...biezace, spans: v })}
      />
      <Licznik
        etykieta={t("evidenceBehavioral")}
        wartosc={biezace.behavioral ?? 0}
        min={0}
        onChange={(v) => onChange({ ...biezace, behavioral: v })}
      />
      <Licznik
        etykieta={t("evidenceSessions")}
        wartosc={biezace.sessions ?? 1}
        min={1}
        onChange={(v) => onChange({ ...biezace, sessions: v })}
      />
    </div>
  );
}

function Licznik({
  etykieta,
  wartosc,
  min,
  onChange,
}: {
  etykieta: string;
  wartosc: number;
  min: number;
  onChange: (v: number) => void;
}) {
  return (
    <label className="grid gap-1">
      <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
        {etykieta}
      </span>
      <input
        type="number"
        min={min}
        value={wartosc}
        onChange={(e) => {
          const v = Number(e.target.value);
          if (Number.isFinite(v) && v >= min) onChange(v);
        }}
        className="bg-abyss border border-frost/20 text-frost px-3 py-2 w-20 font-mono text-sm"
      />
    </label>
  );
}

function Pomylki({
  lista,
  onChange,
  t,
}: {
  lista: { input: string; correct: string; note?: string }[];
  onChange: (v: { input: string; correct: string; note?: string }[]) => void;
  t: (k: string) => string;
}) {
  return (
    <div className="grid gap-3" data-testid="form-confusions">
      {lista.map((c, i) => (
        <div key={i} className="grid gap-2 border-l-2 border-ember/30 pl-3">
          <div className="grid gap-2 sm:grid-cols-2">
            <input
              value={c.input}
              placeholder={t("confusionInput")}
              onChange={(e) => {
                const next = [...lista];
                next[i] = { ...c, input: e.target.value };
                onChange(next);
              }}
              className="bg-abyss border border-frost/20 text-frost px-3 py-2 font-serif text-sm"
            />
            <input
              value={c.correct}
              placeholder={t("confusionCorrect")}
              onChange={(e) => {
                const next = [...lista];
                next[i] = { ...c, correct: e.target.value };
                onChange(next);
              }}
              className="bg-abyss border border-frost/20 text-frost px-3 py-2 font-serif text-sm"
            />
          </div>
          <div className="flex gap-2">
            <input
              value={c.note ?? ""}
              placeholder={t("confusionNote")}
              onChange={(e) => {
                const next = [...lista];
                next[i] = { ...c, note: e.target.value };
                onChange(next);
              }}
              className="bg-abyss border border-frost/20 text-frost px-3 py-2 font-serif text-sm flex-1"
            />
            <button
              type="button"
              onClick={() => onChange(lista.filter((_, j) => j !== i))}
              className="border border-frost/25 text-frost/70 px-3 font-mono text-xs hover:bg-frost/10"
              aria-label={t("removeConfusion")}
            >
              ×
            </button>
          </div>
        </div>
      ))}
      <button
        type="button"
        onClick={() => onChange([...lista, { input: "", correct: "" }])}
        className="justify-self-start border border-frost/30 text-frost px-3 py-1.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] hover:bg-frost/10"
      >
        {t("addConfusion")}
      </button>
    </div>
  );
}

function Sekcja({
  tytul,
  pomoc,
  children,
}: {
  tytul: string;
  pomoc?: string;
  children: React.ReactNode;
}) {
  return (
    <section className="grid gap-3">
      <h4 className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember">
        {tytul}
      </h4>
      {pomoc && <p className="font-serif text-mist text-xs -mt-2">{pomoc}</p>}
      {children}
    </section>
  );
}

function Pole({
  etykieta,
  pomoc,
  children,
}: {
  etykieta: string;
  pomoc?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="grid gap-1">
      <span className="font-serif text-frost text-sm">{etykieta}</span>
      {pomoc && <span className="font-serif text-mist text-xs">{pomoc}</span>}
      {children}
    </div>
  );
}
