import { describe, it, expect } from "vitest";

import {
  addConstruct,
  docToString,
  parseDoc,
  readOntology,
  removeConstruct,
  setConfusions,
  setConstructField,
  setConstructList,
  setMinEvidence,
  setMultiLabel,
  setValues,
  slugify,
} from "./model";

const PRZYKLAD = `# Ontologia testowa — SZKIC.
modality: test
version: 0.1.0
approved_by: []

constructs:

  konflikt:
    label_pl: "Konflikt wewnętrzny"
    definition: >
      Napięcie między dwiema dążnościami. PLACEHOLDER (L1).
    kind: category
    values: ["blizkosc-autonomia", "osiagniecia-odpoczynek"]   # ZWERYFIKOWAĆ (kanon)
    min_evidence: {spans: 2, behavioral: 1}
    is_not: [zasob]
    common_confusions:
      - {input: "ambiwalencja", correct: "konflikt wymaga dwóch nazwanych dążności"}

  zasob:
    label_pl: "Zasób"
    values: null                # treść jest opisem, nie etykietą
    min_evidence: {spans: 1}

epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
relation_types: [wspolwystepowanie, napiecie]
`;

describe("odczyt", () => {
  it("czyta konstrukty w kolejności z pliku", () => {
    const v = readOntology(parseDoc(PRZYKLAD));
    expect(v.modality).toBe("test");
    expect(v.version).toBe("0.1.0");
    expect(v.constructs.map((c) => c.id)).toEqual(["konflikt", "zasob"]);
  });

  it("odróżnia brak katalogu od katalogu pustego", () => {
    const v = readOntology(parseDoc(PRZYKLAD));
    // `values: null` to świadoma decyzja „konstrukt opisowy", nie brak
    // wypełnienia — formularz musi je rozróżnić, bo znaczą co innego.
    expect(v.constructs.find((c) => c.id === "zasob")!.values).toBeNull();
    expect(v.constructs.find((c) => c.id === "konflikt")!.values).toHaveLength(2);
  });

  it("czyta próg dowodowy i granice", () => {
    const k = readOntology(parseDoc(PRZYKLAD)).constructs[0];
    expect(k.minEvidence).toEqual({ spans: 2, behavioral: 1 });
    expect(k.isNot).toEqual(["zasob"]);
    expect(k.confusions).toHaveLength(1);
    expect(k.confusions[0].input).toBe("ambiwalencja");
  });
});

describe("komentarze przeżywają edycję", () => {
  // To jest powód, dla którego kreator w ogóle trzyma Document zamiast
  // czytać do struktury i zapisywać z powrotem. `# ZWERYFIKOWAĆ` przy
  // liście wartości niesie informację, której nie ma nigdzie indziej —
  // migracja 000092 zmieniła kolumnę z JSONB na TEXT dokładnie po to.
  it("zmiana etykiety nie kasuje komentarza przy innym polu", () => {
    const doc = parseDoc(PRZYKLAD);
    setConstructField(doc, "konflikt", "label_pl", "Konflikt aktualny");
    const out = docToString(doc);
    expect(out).toContain("ZWERYFIKOWAĆ (kanon)");
    expect(out).toContain("Konflikt aktualny");
  });

  it("komentarz nagłówka pliku zostaje", () => {
    const doc = parseDoc(PRZYKLAD);
    setConstructField(doc, "zasob", "definition", "Cokolwiek");
    expect(docToString(doc)).toContain("# Ontologia testowa — SZKIC.");
  });

  it("komentarz przy sąsiednim konstrukcie zostaje po usunięciu innego", () => {
    const doc = parseDoc(PRZYKLAD);
    removeConstruct(doc, "zasob");
    const out = docToString(doc);
    expect(out).toContain("ZWERYFIKOWAĆ (kanon)");
    expect(out).not.toContain("Zasób");
  });
});

describe("mutacje", () => {
  it("puste pole USUWA klucz, nie wpisuje pustki", () => {
    // Pusty łańcuch i brak klucza to dla metaschematu co innego, a puste
    // pole formularza znaczy „nie podano", nie „podano pustkę".
    const doc = parseDoc(PRZYKLAD);
    setConstructField(doc, "konflikt", "definition", "   ");
    expect(docToString(doc)).not.toContain("definition:");
  });

  it("pusta lista usuwa klucz", () => {
    const doc = parseDoc(PRZYKLAD);
    setConstructList(doc, "konflikt", "is_not", []);
    expect(readOntology(doc).constructs[0].isNot).toEqual([]);
    expect(docToString(doc)).not.toContain("is_not:");
  });

  it("values null zostaje nullem, nie znika", () => {
    const doc = parseDoc(PRZYKLAD);
    setValues(doc, "konflikt", null);
    expect(docToString(doc)).toMatch(/values:\s*null/);
    expect(readOntology(doc).constructs[0].values).toBeNull();
  });

  it("multi_label wyłączone usuwa klucz zamiast pisać false", () => {
    const doc = parseDoc(PRZYKLAD);
    setMultiLabel(doc, "konflikt", true);
    expect(docToString(doc)).toContain("multi_label: true");
    setMultiLabel(doc, "konflikt", false);
    expect(docToString(doc)).not.toContain("multi_label");
  });

  it("próg pomija sessions równe 1 — to wartość domyślna", () => {
    const doc = parseDoc(PRZYKLAD);
    setMinEvidence(doc, "konflikt", { spans: 2, sessions: 1 });
    const out = docToString(doc);
    expect(out).toContain("spans: 2");
    expect(out).not.toContain("sessions");
  });

  it("pomyłka bez notatki nie zapisuje pustego pola", () => {
    const doc = parseDoc(PRZYKLAD);
    setConfusions(doc, "zasob", [{ input: "a", correct: "b", note: "" }]);
    const zapis = docToString(doc);
    expect(zapis).toContain("input: a");
    expect(zapis).not.toContain("note:");
  });

  it("pomyłka bez korekty jest odrzucana — wpis bez niej nie uczy niczego", () => {
    const doc = parseDoc(PRZYKLAD);
    setConfusions(doc, "zasob", [{ input: "a", correct: "" }]);
    expect(readOntology(doc).constructs[1].confusions).toEqual([]);
  });
});

describe("nowy konstrukt", () => {
  it("katalog zamknięty daje pustą listę, brak katalogu daje null", () => {
    const doc = parseDoc(PRZYKLAD);
    addConstruct(doc, {
      id: "nowy",
      labelPl: "Nowy",
      definition: "",
      hasCatalogue: true,
      multiLabel: false,
      composite: false,
    });
    addConstruct(doc, {
      id: "opisowy",
      labelPl: "Opisowy",
      definition: "",
      hasCatalogue: false,
      multiLabel: false,
      composite: false,
    });
    const v = readOntology(doc);
    expect(v.constructs.find((c) => c.id === "nowy")!.values).toEqual([]);
    expect(v.constructs.find((c) => c.id === "opisowy")!.values).toBeNull();
  });

  it("każdy nowy konstrukt dostaje próg dowodowy", () => {
    // Konstrukt bez progu przyjmuje twierdzenie na jeden span — to jest
    // decyzja, a decyzja niepodjęta nie powinna wyglądać jak podjęta.
    const doc = parseDoc(PRZYKLAD);
    addConstruct(doc, {
      id: "nowy", labelPl: "Nowy", definition: "",
      hasCatalogue: true, multiLabel: false, composite: false,
    });
    expect(readOntology(doc).constructs.find((c) => c.id === "nowy")!.minEvidence)
      .toEqual({ spans: 1 });
  });

  it("kompozyt nie dostaje values ani multi_label", () => {
    const doc = parseDoc(PRZYKLAD);
    addConstruct(doc, {
      id: "kompozyt", labelPl: "Kompozyt", definition: "",
      hasCatalogue: true, multiLabel: true, composite: true,
    });
    const c = readOntology(doc).constructs.find((x) => x.id === "kompozyt")!;
    expect(c.kind).toBe("composite");
    expect(c.values).toBeNull();
    expect(c.multiLabel).toBe(false);
  });
});

describe("identyfikator z nazwy", () => {
  it("składa diakrytyki i spacje", () => {
    expect(slugify("Konflikt wewnętrzny")).toBe("konflikt_wewnetrzny");
    expect(slugify("Zdolność aktualna / wtórna")).toBe("zdolnosc_aktualna_wtorna");
    expect(slugify("Myśl automatyczna")).toBe("mysl_automatyczna");
  });

  it("wynik zawsze pasuje do metaschematu albo jest pusty", () => {
    for (const wejscie of ["Ćwiczenie", "123 test", "!!!", "  ", "Ą"]) {
      const s = slugify(wejscie);
      if (s !== "") expect(s).toMatch(/^[a-z][a-z0-9_]*$/);
    }
  });

  it("nazwa zaczynająca się od cyfry dostaje prefiks, nie zostaje odrzucona", () => {
    expect(slugify("3 pytania")).toBe("k_3_pytania");
  });
});
