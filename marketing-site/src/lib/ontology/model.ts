// Model ontologii dla kreatora (dok. 17, K1–K2).
//
// ══ Dlaczego edycje punktowe, a nie serializacja od nowa ══
//
// Komentarze w plikach ontologii są NOŚNE. Migracja 000092 zmieniła
// kolumnę z JSONB na TEXT właśnie dlatego, że konwersja YAML→JSON zjada
// adnotacje ekspertów — a `# ZWERYFIKOWAĆ (kanon 12 wg Beck/Burns)` przy
// liście zniekształceń niesie informację, której nie ma nigdzie indziej.
//
// Formularz nie może więc czytać YAML-a do struktury i zapisywać z
// powrotem: skasowałby wszystko, czego sam nie modeluje. Zamiast tego
// trzyma `Document` z pakietu `yaml` i nakłada zmiany na KONKRETNE węzły.
// Węzeł nietknięty zostaje bajt w bajt, razem z komentarzem.
//
// ══ Dlaczego jedna implementacja walidacji ══
//
// Tu NIE MA walidatora. Metaschemat ma jedną implementację (pkg/ontology
// w Go) i tak ma zostać — druga, w TypeScript, rozjechałaby się przy
// pierwszej zmianie, a rozjazd znaczyłby, że Studio przepuszcza treść,
// którą CI odrzuca, albo odwrotnie. Formularz zapobiega błędom KSZTAŁTEM,
// nie sprawdzaniem.

import { parseDocument, type Document } from "yaml";

export type ConstructKind = "category" | "composite";

export interface Confusion {
  input: string;
  correct: string;
  note?: string;
}

export interface MinEvidence {
  spans: number;
  behavioral?: number;
  sessions?: number;
}

/** Widok konstruktu dla formularza. Do ODCZYTU — zapis idzie przez
 * funkcje mutujące, które dotykają pojedynczych węzłów dokumentu. */
export interface ConstructView {
  id: string;
  labelPl: string;
  definition: string;
  kind: ConstructKind;
  /** null = brak katalogu zamkniętego (konstrukt opisowy). */
  values: string[] | null;
  multiLabel: boolean;
  minEvidence: MinEvidence | null;
  isNot: string[];
  requires: string[];
  confusions: Confusion[];
  aliases: string[];
  examples: string[];
  counterExamples: string[];
  forcedStatus: string;
  fallbackRendering: string;
  /** Ma sloty — kreator K1/K2 ich nie edytuje (K3), ale musi je
   * pokazywać jako obecne, żeby nikt nie uznał konstruktu za pusty. */
  hasSlots: boolean;
}

export interface OntologyView {
  modality: string;
  version: string;
  constructs: ConstructView[];
}

/** Sygnatura dokumentu — Document z `yaml`, opakowany, żeby wołający nie
 * musiał znać biblioteki. */
export type OntologyDoc = Document.Parsed;

export function parseDoc(yamlText: string): OntologyDoc {
  return parseDocument(yamlText);
}

export function docToString(doc: OntologyDoc): string {
  return String(doc);
}

function asString(v: unknown): string {
  return typeof v === "string" ? v : v == null ? "" : String(v);
}

function asStringList(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v.map(asString).filter((s) => s !== "");
}

/** Czyta dokument do widoku formularza.
 *
 * Kolejność konstruktów zachowana z pliku — to kolejność, w której
 * ekspert je pisał, i jedyna, która dla niego coś znaczy. Sortowanie
 * alfabetyczne przestawiłoby mu dokument pod palcami. */
export function readOntology(doc: OntologyDoc): OntologyView {
  const raw = doc.toJS({ maxAliasCount: -1 }) as Record<string, unknown> | null;
  const constructsRaw = (raw?.constructs ?? {}) as Record<string, Record<string, unknown>>;

  const constructs: ConstructView[] = Object.entries(constructsRaw).map(([id, c]) => {
    const values = c?.values;
    return {
      id,
      labelPl: asString(c?.label_pl),
      definition: asString(c?.definition),
      kind: c?.kind === "composite" ? "composite" : "category",
      values: values === null || values === undefined ? null : asStringList(values),
      multiLabel: c?.multi_label === true,
      minEvidence: readMinEvidence(c?.min_evidence),
      isNot: asStringList(c?.is_not),
      requires: asStringList(c?.requires),
      confusions: readConfusions(c?.common_confusions),
      aliases: asStringList(c?.aliases),
      examples: asStringList(c?.examples),
      counterExamples: asStringList(c?.counter_examples),
      forcedStatus: asString(c?.forced_status),
      fallbackRendering: asString(c?.fallback_rendering),
      hasSlots: c?.slots != null,
    };
  });

  return {
    modality: asString(raw?.modality),
    version: asString(raw?.version),
    constructs,
  };
}

function readMinEvidence(v: unknown): MinEvidence | null {
  if (v == null || typeof v !== "object") return null;
  const m = v as Record<string, unknown>;
  const spans = Number(m.spans);
  if (!Number.isFinite(spans)) return null;
  const out: MinEvidence = { spans };
  if (Number.isFinite(Number(m.behavioral))) out.behavioral = Number(m.behavioral);
  if (Number.isFinite(Number(m.sessions))) out.sessions = Number(m.sessions);
  return out;
}

function readConfusions(v: unknown): Confusion[] {
  if (!Array.isArray(v)) return [];
  return v
    .filter((e): e is Record<string, unknown> => e != null && typeof e === "object")
    .map((e) => ({
      input: asString(e.input),
      correct: asString(e.correct),
      note: asString(e.note) || undefined,
    }))
    .filter((c) => c.input !== "");
}

// ── mutacje ───────────────────────────────────────────────────────────
//
// Każda dotyka POJEDYNCZEGO węzła. Pusta wartość USUWA klucz zamiast
// wpisywać "" — pusty łańcuch w YAML-u przechodzi metaschemat inaczej niż
// brak klucza, a formularz z pustym polem znaczy „nie podano", nie
// „podano pustkę".

export function setConstructField(
  doc: OntologyDoc,
  id: string,
  field: string,
  value: string,
): void {
  const path = ["constructs", id, field];
  if (value.trim() === "") {
    doc.deleteIn(path);
    return;
  }
  doc.setIn(path, value);
}

export function setConstructList(
  doc: OntologyDoc,
  id: string,
  field: string,
  values: string[],
): void {
  const clean = values.map((v) => v.trim()).filter((v) => v !== "");
  const path = ["constructs", id, field];
  if (clean.length === 0) {
    doc.deleteIn(path);
    return;
  }
  doc.setIn(path, doc.createNode(clean));
}

/** `values: null` to NIE to samo co brak klucza.
 *
 * null znaczy „konstrukt świadomie bez katalogu zamkniętego" (treść jest
 * opisem, jak `automatic_thought` w CBT). Brak klucza znaczyłby to samo
 * dla parsera, ale nie dla czytelnika — a plik czyta ekspert. */
export function setValues(doc: OntologyDoc, id: string, values: string[] | null): void {
  const path = ["constructs", id, "values"];
  if (values === null) {
    doc.setIn(path, null);
    return;
  }
  const clean = values.map((v) => v.trim()).filter((v) => v !== "");
  doc.setIn(path, doc.createNode(clean));
}

export function setMultiLabel(doc: OntologyDoc, id: string, on: boolean): void {
  const path = ["constructs", id, "multi_label"];
  if (!on) {
    doc.deleteIn(path);
    return;
  }
  doc.setIn(path, true);
}

export function setMinEvidence(doc: OntologyDoc, id: string, me: MinEvidence | null): void {
  const path = ["constructs", id, "min_evidence"];
  if (me === null) {
    doc.deleteIn(path);
    return;
  }
  const out: Record<string, number> = { spans: me.spans };
  if (me.behavioral && me.behavioral > 0) out.behavioral = me.behavioral;
  if (me.sessions && me.sessions > 1) out.sessions = me.sessions;
  doc.setIn(path, doc.createNode(out));
}

export function setConfusions(doc: OntologyDoc, id: string, list: Confusion[]): void {
  const path = ["constructs", id, "common_confusions"];
  const clean = list
    .map((c) => ({
      input: c.input.trim(),
      correct: c.correct.trim(),
      note: c.note?.trim() ?? "",
    }))
    .filter((c) => c.input !== "" && c.correct !== "");
  if (clean.length === 0) {
    doc.deleteIn(path);
    return;
  }
  doc.setIn(
    path,
    doc.createNode(clean.map((c) => (c.note ? c : { input: c.input, correct: c.correct }))),
  );
}

/** Kształt nowego konstruktu — wynik trzech pytań kreatora. */
export interface NewConstructShape {
  id: string;
  labelPl: string;
  definition: string;
  hasCatalogue: boolean;
  multiLabel: boolean;
  composite: boolean;
}

export function addConstruct(doc: OntologyDoc, shape: NewConstructShape): void {
  const body: Record<string, unknown> = {
    label_pl: shape.labelPl,
  };
  if (shape.definition.trim() !== "") body.definition = shape.definition.trim();
  body.kind = shape.composite ? "composite" : "category";
  if (!shape.composite) {
    body.values = shape.hasCatalogue ? [] : null;
    if (shape.multiLabel) body.multi_label = true;
  }
  // Próg dowodowy zawsze obecny: konstrukt bez progu przyjmuje twierdzenie
  // na jeden span, co jest decyzją — a decyzja niepodjęta nie powinna
  // wyglądać jak decyzja podjęta.
  body.min_evidence = { spans: 1 };
  // createNode, nie surowy obiekt: `setIn` z gołym JS-em zapisuje
  // wartość, po której kolejna edycja nie potrafi zejść w głąb
  // ("Expected YAML collection at …"). Wyszło na teście ścieżki kreatora,
  // czyli tam, gdzie ekspert dodaje konstrukt i od razu wypełnia katalog.
  doc.setIn(["constructs", shape.id], doc.createNode(body));
}

export function removeConstruct(doc: OntologyDoc, id: string): void {
  doc.deleteIn(["constructs", id]);
}

/** Identyfikator z polskiej nazwy: [a-z][a-z0-9_]*.
 *
 * Metaschemat nie przyjmie niczego innego, a ekspert nie ma powodu znać
 * tego wyrażenia. Diakrytyki składane, spacje i myślniki na podkreślenia,
 * reszta odrzucana. */
const DIAKRYTYKI: Record<string, string> = {
  ą: "a", ć: "c", ę: "e", ł: "l", ń: "n", ó: "o", ś: "s", ź: "z", ż: "z",
};

export function slugify(label: string): string {
  const bez = label
    .toLowerCase()
    .replace(/[ąćęłńóśźż]/g, (c) => DIAKRYTYKI[c] ?? c)
    .replace(/[\s\-/]+/g, "_")
    .replace(/[^a-z0-9_]/g, "")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "");
  if (bez === "") return "";
  // Metaschemat wymaga litery na początku.
  return /^[a-z]/.test(bez) ? bez : `k_${bez}`;
}
