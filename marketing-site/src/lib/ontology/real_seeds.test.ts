import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it, expect } from "vitest";

import {
  docToString,
  parseDoc,
  readOntology,
  setConfusions,
  setConstructField,
  setConstructList,
  setMinEvidence,
  setValues,
} from "./model";

// Formularz musi działać na TREŚCI, KTÓRA ISTNIEJE — a nie tylko na
// przykładzie napisanym pod niego. Te trzy pliki są dziś draftami w
// bazie i to je otworzy ekspert pierwszego dnia.
//
// Test czyta je z repozytorium, więc rozjazd między metaschematem a
// modelem kreatora wychodzi tutaj, a nie na produkcji.
const SEEDS = ["ppt", "cbt", "gestalt"] as const;

function wczytaj(modalnosc: string): string {
  return readFileSync(
    join(process.cwd(), "..", "superwizor-backend", "ontology", modalnosc, "0.1.0.yaml"),
    "utf8",
  );
}

describe("prawdziwe szkice ontologii", () => {
  it.each(SEEDS)("%s daje się wczytać do formularza", (modalnosc) => {
    const v = readOntology(parseDoc(wczytaj(modalnosc)));
    expect(v.modality).toBe(modalnosc);
    expect(v.version).toBe("0.1.0");
    expect(v.constructs.length).toBeGreaterThan(0);
    // Każdy konstrukt ma nazwę — inaczej lista po lewej pokazałaby puste
    // pozycje i ekspert nie wiedziałby, w co klika.
    for (const c of v.constructs) {
      expect(c.labelPl, `${modalnosc}/${c.id}`).not.toBe("");
      expect(c.id).toMatch(/^[a-z][a-z0-9_]*$/);
    }
  });

  it.each(SEEDS)("%s przechodzi przez formularz bez utraty treści", (modalnosc) => {
    const zrodlo = wczytaj(modalnosc);
    const doc = parseDoc(zrodlo);
    const przed = readOntology(doc);

    // Edycja, którą ekspert wykona najpierw: poprawienie definicji
    // pierwszego konstruktu. Wszystko poza nią ma zostać nietknięte.
    const pierwszy = przed.constructs[0];
    setConstructField(doc, pierwszy.id, "definition", "Definicja po autoryzacji.");

    const po = readOntology(doc);
    expect(po.constructs.map((c) => c.id)).toEqual(przed.constructs.map((c) => c.id));
    expect(po.constructs[0].definition).toBe("Definicja po autoryzacji.");
    for (let i = 1; i < po.constructs.length; i++) {
      expect(po.constructs[i]).toEqual(przed.constructs[i]);
    }
  });

  it.each(SEEDS)("%s zachowuje adnotacje ekspertów po edycji", (modalnosc) => {
    const zrodlo = wczytaj(modalnosc);
    const doc = parseDoc(zrodlo);
    const pierwszy = readOntology(doc).constructs[0];
    setConstructField(doc, pierwszy.id, "label_pl", "Zmieniona nazwa");
    const po = docToString(doc);

    // Liczba komentarzy w pliku ma się nie zmniejszyć. To one niosą
    // `# ZWERYFIKOWAĆ` i `# PLACEHOLDER` — jedyny ślad tego, co jeszcze
    // wymaga decyzji eksperckiej.
    const komentarzyPrzed = (zrodlo.match(/(^|\s)#/gm) ?? []).length;
    const komentarzyPo = (po.match(/(^|\s)#/gm) ?? []).length;
    expect(komentarzyPo).toBeGreaterThanOrEqual(komentarzyPrzed);
  });

  it("granice w PPT wskazują istniejące konstrukty", () => {
    // Metaschemat tego wymaga, a ja sam się na tym przejechałem pisząc
    // ten plik: wpisałem w `is_not` opis zamiast identyfikatora. Picker
    // w formularzu czyni ten błąd niemożliwym, ale test pilnuje, że
    // ODCZYT też widzi identyfikatory, a nie tekst.
    const v = readOntology(parseDoc(wczytaj("ppt")));
    const idki = new Set(v.constructs.map((c) => c.id));
    for (const c of v.constructs) {
      for (const ref of [...c.isNot, ...c.requires]) {
        expect(idki, `${c.id} wskazuje ${ref}`).toContain(ref);
      }
    }
  });

  it("edycja katalogu i pomyłek na CBT nie rusza sąsiadów", () => {
    const doc = parseDoc(wczytaj("cbt"));
    const przed = readOntology(doc);
    const znieksztalcenie = przed.constructs.find((c) => c.id === "cognitive_distortion")!;
    expect(znieksztalcenie.multiLabel).toBe(true);
    expect(znieksztalcenie.values!.length).toBeGreaterThan(5);

    setValues(doc, "cognitive_distortion", [...znieksztalcenie.values!, "nowe"]);
    setConfusions(doc, "cognitive_distortion", [
      ...znieksztalcenie.confusions,
      { input: "test", correct: "poprawka" },
    ]);
    setMinEvidence(doc, "cognitive_distortion", { spans: 2 });
    setConstructList(doc, "cognitive_distortion", "is_not", []);

    const po = readOntology(doc);
    const zmieniony = po.constructs.find((c) => c.id === "cognitive_distortion")!;
    expect(zmieniony.values).toContain("nowe");
    expect(zmieniony.minEvidence).toEqual({ spans: 2 });
    // Wielokrotność zostaje — zmiana katalogu nie może jej po cichu zdjąć.
    expect(zmieniony.multiLabel).toBe(true);

    for (const c of po.constructs) {
      if (c.id === "cognitive_distortion") continue;
      expect(c).toEqual(przed.constructs.find((x) => x.id === c.id));
    }
  });
});
