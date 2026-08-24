import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it, expect } from "vitest";

import { diffOntologii } from "./diff";
import {
  docToString,
  parseDoc,
  readOntology,
  setDefaultTone,
  setSectionWeight,
} from "./model";

function seed(m: string): string {
  return readFileSync(
    join(process.cwd(), "..", "superwizor-backend", "ontology", m, "0.1.0.yaml"),
    "utf8",
  );
}

describe("kompozycja raportu (M5)", () => {
  it("czyta profile wszystkich trzech modalności", () => {
    // Wszystkie trzy seedy mają teraz jawny profil — to jest uchwyt,
    // którym ekspert steruje kształtem raportu z poziomu Studia.
    for (const m of ["ppt", "cbt", "gestalt"] as const) {
      const v = readOntology(parseDoc(seed(m)));
      expect(v.reportProfile, m).not.toBeNull();
    }
    const gestalt = readOntology(parseDoc(seed("gestalt")));
    expect(gestalt.reportProfile!.sections.patterns_and_relations).toBe("high");
    expect(gestalt.reportProfile!.sections.interpretive_constructs).toBe("low");
    expect(gestalt.reportProfile!.defaultTone).toBe("phenomenological");
  });

  it("waga normal usuwa wpis — profil niesie wyłącznie odstępstwa", () => {
    // Inaczej każda ontologia dźwigałaby kopię domyślnej kompozycji, a
    // diff pokazywałby „zmiany" tam, gdzie nikt niczego nie zmienił.
    const doc = parseDoc(seed("gestalt"));
    setSectionWeight(doc, "patterns_and_relations", "normal");
    const out = docToString(doc);
    expect(out).not.toContain("patterns_and_relations");
    expect(out).toContain("open_questions");
  });

  it("zdjęcie wszystkich odstępstw usuwa cały blok profilu", () => {
    const doc = parseDoc(seed("cbt"));
    for (const sekcja of ["session_summary", "interpretive_constructs",
      "patterns_and_relations", "open_questions"] as const) {
      setSectionWeight(doc, sekcja, "normal");
    }
    expect(docToString(doc)).not.toContain("report_profile");
  });

  it("edycja wagi nie kasuje komentarzy seedu", () => {
    const zrodlo = seed("ppt");
    const doc = parseDoc(zrodlo);
    setSectionWeight(doc, "open_questions", "high");
    const po = docToString(doc);
    const przed = (zrodlo.match(/(^|\s)#/gm) ?? []).length;
    expect((po.match(/(^|\s)#/gm) ?? []).length).toBeGreaterThanOrEqual(przed);
  });

  it("diff pokazuje zmianę kompozycji recenzentowi", () => {
    // Kompozycja zmienia to, co terapeuta czyta i w jakiej kolejności —
    // podlega przeglądowi tak samo jak treść.
    const przed = readOntology(parseDoc(seed("ppt")));
    const doc = parseDoc(seed("ppt"));
    setSectionWeight(doc, "open_questions", "high");
    setDefaultTone(doc, "phenomenological");
    const z = diffOntologii(przed, readOntology(doc));
    expect(z).toContainEqual({
      rodzaj: "zmieniono", konstrukt: "", klucz: "sekcjaWaga",
      dane: { sekcja: "open_questions", z: "normal", na: "high" },
    });
    expect(z).toContainEqual({
      rodzaj: "zmieniono", konstrukt: "", klucz: "tonRaportu",
      dane: { z: "—", na: "phenomenological" },
    });
  });

  it("jawny normal i brak wpisu to ta sama kompozycja — diff milczy", () => {
    const przed = readOntology(parseDoc(seed("gestalt")));
    const doc = parseDoc(seed("gestalt"));
    // dopisanie session_summary: normal — skuteczna kompozycja bez zmian
    setSectionWeight(doc, "session_summary", "normal");
    expect(diffOntologii(przed, readOntology(doc))).toEqual([]);
  });
});
