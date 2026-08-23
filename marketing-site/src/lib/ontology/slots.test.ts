import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it, expect } from "vitest";

import {
  docToString,
  parseDoc,
  readOntology,
  setMinCompleteSlots,
  setSlots,
  slotNeedsTarget,
  slotTypeString,
  type SlotView,
} from "./model";

function seed(m: string): string {
  return readFileSync(
    join(process.cwd(), "..", "superwizor-backend", "ontology", m, "0.1.0.yaml"),
    "utf8",
  );
}

const SLOT = (over: Partial<SlotView> = {}): SlotView => ({
  name: "sytuacja",
  kind: "span_ref",
  target: "",
  required: true,
  kindHint: "",
  quantity: false,
  ...over,
});

describe("odczyt slotów z prawdziwych kompozytów", () => {
  it.each([
    ["ppt", 3],
    ["cbt", 3],
    ["gestalt", 2],
  ])("%s ma kompozyt z %i+ slotami", (modalnosc, minimum) => {
    const v = readOntology(parseDoc(seed(modalnosc)));
    const kompozyty = v.constructs.filter((c) => c.kind === "composite");
    expect(kompozyty).toHaveLength(1);
    expect(kompozyty[0].slots.length).toBeGreaterThanOrEqual(minimum);
    for (const s of kompozyty[0].slots) {
      expect(s.name).not.toBe("");
      // Cztery legalne formy metaschematu i nic poza nimi.
      expect(slotTypeString(s)).toMatch(
        /^(span_ref|entry_ref|(construct_ref|enum_ref)\([a-z][a-z0-9_]*\))$/,
      );
    }
  });

  it("gestalt niesie min_complete_slots", () => {
    const v = readOntology(parseDoc(seed("gestalt")));
    const polaryzacja = v.constructs.find((c) => c.id === "polarity")!;
    expect(polaryzacja.minCompleteSlots).toBe(2);
    expect(polaryzacja.slots.map((s) => s.name)).toEqual(["pole_a", "pole_b"]);
  });

  it("PPT wskazuje konstrukty przez enum_ref, nie tekstem", () => {
    // Ta sama klasa błędu co w `is_not`: metaschemat wymaga
    // identyfikatora w nawiasie, nie opisu. Picker w formularzu czyni ją
    // niemożliwą, a test pilnuje, że ODCZYT też widzi identyfikator.
    const v = readOntology(parseDoc(seed("ppt")));
    const kompozyt = v.constructs.find((c) => c.kind === "composite")!;
    const idki = new Set(v.constructs.map((c) => c.id));
    for (const s of kompozyt.slots) {
      if (slotNeedsTarget(s.kind)) {
        expect(idki, `${s.name} -> ${s.target}`).toContain(s.target);
      }
    }
  });
});

describe("zapis slotów", () => {
  const PUSTY = `modality: test
version: 0.1.0
approved_by: []
constructs:
  epizod:
    label_pl: "Epizod"
    kind: composite
epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
relation_types: [wspolwystepowanie]
`;

  it("składa cztery formy typu bez udziału użytkownika", () => {
    const doc = parseDoc(PUSTY);
    setSlots(doc, "epizod", [
      SLOT({ name: "sytuacja", kind: "span_ref" }),
      SLOT({ name: "wpis", kind: "entry_ref", required: false }),
      SLOT({ name: "kategoria", kind: "enum_ref", target: "emocja" }),
      SLOT({ name: "powiazanie", kind: "construct_ref", target: "mysl" }),
    ]);
    const s = readOntology(doc).constructs[0].slots;
    expect(s.map(slotTypeString)).toEqual([
      "span_ref",
      "entry_ref",
      "enum_ref(emocja)",
      "construct_ref(mysl)",
    ]);
  });

  it("slot bez celu jest pomijany, gdy rodzaj go wymaga", () => {
    // Formularz może mieć wiersz w trakcie wypełniania. Niedokończony
    // slot nie ma prawa trafić do treści, którą zobaczy walidator —
    // `enum_ref()` bez identyfikatora nie przechodzi metaschematu.
    const doc = parseDoc(PUSTY);
    setSlots(doc, "epizod", [
      SLOT({ name: "gotowy", kind: "span_ref" }),
      SLOT({ name: "wtrakcie", kind: "enum_ref", target: "" }),
    ]);
    expect(readOntology(doc).constructs[0].slots.map((s) => s.name)).toEqual(["gotowy"]);
  });

  it("slot bez nazwy jest pomijany", () => {
    const doc = parseDoc(PUSTY);
    setSlots(doc, "epizod", [SLOT({ name: "  " })]);
    expect(readOntology(doc).constructs[0].slots).toEqual([]);
    expect(docToString(doc)).not.toContain("slots:");
  });

  it("wartości domyślne nie zaśmiecają pliku", () => {
    const doc = parseDoc(PUSTY);
    setSlots(doc, "epizod", [SLOT({ required: false, kindHint: "", quantity: false })]);
    const out = docToString(doc);
    expect(out).toContain("type: span_ref");
    expect(out).not.toContain("required:");
    expect(out).not.toContain("kind_hint:");
    expect(out).not.toContain("quantity:");
  });

  it("min_complete_slots przycięte do liczby slotów", () => {
    // Metaschemat odrzuca wartość spoza 1..liczba slotów. Suwak w
    // formularzu jest ograniczony, ale przycięcie tutaj znaczy, że
    // wartość spoza zakresu nie ma JAK trafić do pliku.
    const doc = parseDoc(PUSTY);
    setSlots(doc, "epizod", [SLOT({ name: "a" }), SLOT({ name: "b" })]);
    setMinCompleteSlots(doc, "epizod", 9, 2);
    expect(readOntology(doc).constructs[0].minCompleteSlots).toBe(2);
    setMinCompleteSlots(doc, "epizod", 0, 2);
    expect(readOntology(doc).constructs[0].minCompleteSlots).toBe(1);
  });

  it("brak slotów usuwa min_complete_slots", () => {
    const doc = parseDoc(PUSTY);
    setMinCompleteSlots(doc, "epizod", 2, 0);
    expect(docToString(doc)).not.toContain("min_complete_slots");
  });

  it("edycja slotów nie rusza reszty kompozytu ani sąsiadów", () => {
    const doc = parseDoc(seed("cbt"));
    const przed = readOntology(doc);
    const kompozyt = przed.constructs.find((c) => c.kind === "composite")!;
    setSlots(doc, kompozyt.id, [...kompozyt.slots, SLOT({ name: "nowy" })]);
    const po = readOntology(doc);
    for (const c of po.constructs) {
      if (c.id === kompozyt.id) continue;
      expect(c).toEqual(przed.constructs.find((x) => x.id === c.id));
    }
    expect(po.constructs.find((c) => c.id === kompozyt.id)!.labelPl).toBe(kompozyt.labelPl);
  });
});
