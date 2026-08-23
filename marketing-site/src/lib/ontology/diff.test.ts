import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it, expect } from "vitest";

import { diffOntologii } from "./diff";
import {
  parseDoc,
  readOntology,
  setConfusions,
  setConstructField,
  setConstructList,
  setMinEvidence,
  setSlots,
  setValues,
  addConstruct,
  removeConstruct,
} from "./model";

function seed(m: string): string {
  return readFileSync(
    join(process.cwd(), "..", "superwizor-backend", "ontology", m, "0.1.0.yaml"),
    "utf8",
  );
}

function po(zrodlo: string, edycja: (doc: ReturnType<typeof parseDoc>) => void) {
  const doc = parseDoc(zrodlo);
  edycja(doc);
  return readOntology(doc);
}

describe("diff semantyczny", () => {
  const PPT = seed("ppt");
  const przed = readOntology(parseDoc(PPT));

  it("identyczna treść nie daje żadnej zmiany", () => {
    // Podstawa użyteczności: recenzent otwierający wersję bez zmian ma
    // zobaczyć pustkę, a nie listę „różnic" wynikających z formatowania.
    expect(diffOntologii(przed, readOntology(parseDoc(PPT)))).toEqual([]);
  });

  it("przeformatowanie pliku nie jest zmianą ontologii", () => {
    // Kreator przepisuje węzły, których dotknął. Gdyby diff był tekstowy,
    // każda edycja jednego pola zalewałaby recenzenta szumem.
    const doc = parseDoc(PPT);
    setConstructField(doc, przed.constructs[0].id, "label_pl", przed.constructs[0].labelPl);
    expect(diffOntologii(przed, readOntology(doc))).toEqual([]);
  });

  it("nazywa dodanie i usunięcie wartości katalogu", () => {
    const cel = przed.constructs.find((c) => c.values && c.values.length > 1)!;
    const nowe = po(PPT, (d) => setValues(d, cel.id, [...cel.values!.slice(1), "nowa"]));
    const z = diffOntologii(przed, nowe);
    expect(z).toContainEqual({
      rodzaj: "dodano", konstrukt: cel.id, klucz: "wartoscDodana", dane: { v: "nowa" },
    });
    expect(z).toContainEqual({
      rodzaj: "usunieto", konstrukt: cel.id, klucz: "wartoscUsunieta",
      dane: { v: cel.values![0] },
    });
  });

  it("pokazuje przesunięcie progu z wartościami", () => {
    // To jest ta jedna linia, którą diff tekstowy by ukrył, a która
    // zmienia zachowanie walidatora dla całego konstruktu.
    const cel = przed.constructs.find((c) => c.minEvidence)!;
    const nowe = po(PPT, (d) => setMinEvidence(d, cel.id, { spans: cel.minEvidence!.spans + 2 }));
    expect(diffOntologii(przed, nowe)).toContainEqual({
      rodzaj: "zmieniono", konstrukt: cel.id, klucz: "progSpanow",
      dane: { z: cel.minEvidence!.spans, na: cel.minEvidence!.spans + 2 },
    });
  });

  it("odróżnia usunięcie katalogu od jego opróżnienia", () => {
    // `values: null` = konstrukt opisowy. `values: []` = katalog istnieje,
    // ale pusty — i wtedy enum nic nie egzekwuje. Recenzent musi widzieć
    // różnicę, bo druga wersja jest cicho zepsuta.
    const cel = przed.constructs.find((c) => c.values && c.values.length > 0)!;
    const usuniety = po(PPT, (d) => setValues(d, cel.id, null));
    const oprozniony = po(PPT, (d) => setValues(d, cel.id, []));

    expect(diffOntologii(przed, usuniety)).toContainEqual(
      expect.objectContaining({ klucz: "katalogUsuniety", konstrukt: cel.id }),
    );
    const zOproznionego = diffOntologii(przed, oprozniony);
    expect(zOproznionego.every((z) => z.klucz !== "katalogUsuniety")).toBe(true);
    expect(zOproznionego.filter((z) => z.klucz === "wartoscUsunieta")).toHaveLength(
      cel.values!.length,
    );
  });

  it("nazywa granice i zależności po identyfikatorze", () => {
    const cel = przed.constructs[0];
    // Konstrukt, którego jeszcze NIE MA na liście granic — inaczej test
    // dopisywałby duplikat i słusznie nie widziałby zmiany.
    const inny = przed.constructs.find((c) => c.id !== cel.id && !cel.isNot.includes(c.id))!.id;
    const nowe = po(PPT, (d) => setConstructList(d, cel.id, "is_not", [...cel.isNot, inny]));
    expect(diffOntologii(przed, nowe)).toContainEqual({
      rodzaj: "dodano", konstrukt: cel.id, klucz: "granicaDodana", dane: { v: inny },
    });
  });

  it("pokazuje nową pomyłkę — to ona mówi, czego autor się nauczył", () => {
    const cel = przed.constructs.find((c) => c.confusions.length > 0)!;
    const nowe = po(PPT, (d) =>
      setConfusions(d, cel.id, [...cel.confusions, { input: "świeża", correct: "poprawka" }]),
    );
    expect(diffOntologii(przed, nowe)).toContainEqual({
      rodzaj: "dodano", konstrukt: cel.id, klucz: "pomylkaDodana", dane: { wejscie: "świeża" },
    });
  });

  it("widzi zmiany slotów kompozytu", () => {
    const kompozyt = przed.constructs.find((c) => c.kind === "composite")!;
    const nowe = po(PPT, (d) =>
      setSlots(d, kompozyt.id, [
        ...kompozyt.slots.slice(1),
        { name: "nowy", kind: "span_ref", target: "", required: true, kindHint: "", quantity: false },
      ]),
    );
    const z = diffOntologii(przed, nowe);
    expect(z).toContainEqual(expect.objectContaining({ klucz: "slotDodany", dane: { nazwa: "nowy" } }));
    expect(z).toContainEqual(
      expect.objectContaining({ klucz: "slotUsuniety", dane: { nazwa: kompozyt.slots[0].name } }),
    );
  });

  it("dodanie i usunięcie konstruktu", () => {
    const zDodanym = po(PPT, (d) =>
      addConstruct(d, {
        id: "swiezy", labelPl: "Świeży", definition: "",
        hasCatalogue: true, multiLabel: false, composite: false,
      }),
    );
    expect(diffOntologii(przed, zDodanym)).toContainEqual({
      rodzaj: "dodano", konstrukt: "swiezy", klucz: "konstruktDodany", dane: { nazwa: "Świeży" },
    });

    const usuwany = przed.constructs[przed.constructs.length - 1];
    const zUsunietym = po(PPT, (d) => removeConstruct(d, usuwany.id));
    expect(diffOntologii(przed, zUsunietym)).toContainEqual({
      rodzaj: "usunieto", konstrukt: usuwany.id, klucz: "konstruktUsuniety",
      dane: { nazwa: usuwany.labelPl },
    });
  });

  it("porównanie dwóch RÓŻNYCH modalności nie wybucha", () => {
    // Nie jest to scenariusz z UI, ale funkcja czysta powinna znosić
    // dowolne wejście — a recenzent może otworzyć wersję po zmianie
    // modalności w innej zakładce.
    const z = diffOntologii(przed, readOntology(parseDoc(seed("cbt"))));
    expect(z.length).toBeGreaterThan(0);
    expect(z.some((x) => x.klucz === "konstruktDodany")).toBe(true);
    expect(z.some((x) => x.klucz === "konstruktUsuniety")).toBe(true);
  });

  it("powtórzony wpis granicy nie jest zmianą", () => {
    // Duplikat w `is_not` nic nie znaczy. Gdyby model go zapisywał,
    // recenzent zobaczyłby „dodano granicę", której nikt nie dodał.
    const cel = przed.constructs.find((c) => c.isNot.length > 0)!;
    const nowe = po(PPT, (d) =>
      setConstructList(d, cel.id, "is_not", [...cel.isNot, cel.isNot[0]]),
    );
    expect(diffOntologii(przed, nowe)).toEqual([]);
  });
});
