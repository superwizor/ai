import { describe, it, expect } from "vitest";

import {
  addConstruct,
  docToString,
  parseDoc,
  readOntology,
  setConfusions,
  setConstructList,
  setValues,
  slugify,
} from "./model";

// Przebieg, który ekspert wykona pierwszego dnia: pusta ontologia →
// konstrukt z katalogiem → granice → pomyłka. Sprawdza, że kroki składają
// się w treść, którą metaschemat przyjmie — a nie tylko każdy z osobna.
describe("ścieżka kreatora", () => {
  const PUSTA = `modality: gestalt
version: 0.1.0
approved_by: []
constructs: {}
epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
relation_types: [wspolwystepowanie]
`;

  it("od pustej ontologii do konstruktu z granicami", () => {
    const doc = parseDoc(PUSTA);

    const id1 = slugify("Przerwanie kontaktu");
    addConstruct(doc, {
      id: id1,
      labelPl: "Przerwanie kontaktu",
      definition: "Sposób przerwania cyklu kontaktu.",
      hasCatalogue: true,
      multiLabel: false,
      composite: false,
    });
    setValues(doc, id1, ["konfluencja", "introjekcja", "projekcja"]);

    const id2 = slugify("Strefa świadomości");
    addConstruct(doc, {
      id: id2,
      labelPl: "Strefa świadomości",
      definition: "",
      hasCatalogue: true,
      multiLabel: false,
      composite: false,
    });
    setValues(doc, id2, ["wewnętrzna", "zewnętrzna"]);

    // K2: granica wskazuje IDENTYFIKATOR, nie opis. To jest błąd, który
    // popełniłem przy szkicu PPT — wpisałem tam tekst przepisany z
    // dokumentu 11 i złapał to dopiero lint po zapisie.
    setConstructList(doc, id1, "is_not", [id2]);
    setConfusions(doc, id1, [
      { input: "mechanizm obronny", correct: "przerwanie opisuje proces tu i teraz" },
    ]);

    const v = readOntology(doc);
    expect(v.constructs.map((c) => c.id)).toEqual([
      "przerwanie_kontaktu",
      "strefa_swiadomosci",
    ]);

    const przerwanie = v.constructs[0];
    expect(przerwanie.values).toEqual(["konfluencja", "introjekcja", "projekcja"]);
    // Granica wskazuje ISTNIEJĄCY konstrukt — picker nie da wybrać innego.
    expect(przerwanie.isNot).toEqual(["strefa_swiadomosci"]);
    expect(v.constructs.map((c) => c.id)).toContain(przerwanie.isNot[0]);
    expect(przerwanie.confusions[0].input).toBe("mechanizm obronny");
  });

  it("nagłówek i polityki zostają nietknięte", () => {
    // Kreator nie edytuje polityk — mają jedną legalną wartość, więc
    // formularz w ogóle ich nie pokazuje. Muszą przetrwać dodanie
    // konstruktu bez zmiany.
    const doc = parseDoc(PUSTA);
    addConstruct(doc, {
      id: "x", labelPl: "X", definition: "",
      hasCatalogue: false, multiLabel: false, composite: false,
    });
    const out = docToString(doc);
    expect(out).toContain("etiology_policy: strict");
    expect(out).toContain("therapist_boundary: strict");
    expect(out).toContain("insufficient_data");
    expect(out).toContain("no_fit");
  });
});
