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
  /** Objaśnienia pojedynczych pozycji katalogu (plan value_glosses).
   * Klucz musi być wartością z `values` (reguła G1 lintera Go) —
   * formularz pokazuje pole glosy przy każdej wartości. */
  valueGlosses: Record<string, string>;
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
  /** Sloty kompozytu (K3). Puste dla konstruktów kategorialnych. */
  slots: SlotView[];
  /** Ile slotów musi być wypełnionych, żeby kompozyt w ogóle powstał.
   * null = domyślnie wszystkie wymagane. */
  minCompleteSlots: number | null;
  /** Polityka wartości liczbowych — slot z `quantity` jej wymaga (R9). */
  hasQuantitiesPolicy: boolean;
}

/** Jeden slot kompozytu.
 *
 * `type` ma cztery legalne formy metaschematu: `span_ref`, `entry_ref`,
 * `construct_ref(<id>)`, `enum_ref(<id>)`. Formularz składa je z wyboru
 * rodzaju i pickera konstruktu, więc wyrażenie regularne nie ma jak się
 * nie zgodzić. */
export interface SlotView {
  name: string;
  kind: SlotKind;
  /** Konstrukt wskazywany przez `construct_ref` / `enum_ref`. Puste dla
   * pozostałych rodzajów. */
  target: string;
  required: boolean;
  /** "" | "declarative" | "behavioral" — wymóg dowodowy dla tego slotu. */
  kindHint: string;
  quantity: boolean;
}

export type SlotKind = "span_ref" | "entry_ref" | "construct_ref" | "enum_ref";

export const SLOT_KINDS: SlotKind[] = ["span_ref", "entry_ref", "construct_ref", "enum_ref"];

/** Czy rodzaj slotu wskazuje na konstrukt. */
export function slotNeedsTarget(kind: SlotKind): boolean {
  return kind === "construct_ref" || kind === "enum_ref";
}

function parseSlotType(raw: string): { kind: SlotKind; target: string } {
  const m = /^(construct_ref|enum_ref)\(([a-z][a-z0-9_]*)\)$/.exec(raw);
  if (m) return { kind: m[1] as SlotKind, target: m[2] };
  if (raw === "entry_ref") return { kind: "entry_ref", target: "" };
  return { kind: "span_ref", target: "" };
}

export function slotTypeString(slot: SlotView): string {
  return slotNeedsTarget(slot.kind) ? `${slot.kind}(${slot.target})` : slot.kind;
}

export interface OntologyView {
  modality: string;
  version: string;
  constructs: ConstructView[];
  /** Kompozycja sekcji raportu (M5). null = profil domyślny. */
  reportProfile: ReportProfileView | null;
}

/** Sekcje raportu i ich wagi — lustro kanonicznej listy z pkg/ontology.
 * Kolejność jest częścią kontraktu: to porządek domyślny renderera. */
export const REPORT_SECTIONS = [
  "session_summary",
  "interpretive_constructs",
  "patterns_and_relations",
  "open_questions",
  "out_of_taxonomy",
] as const;

export type ReportSection = (typeof REPORT_SECTIONS)[number];
export type SectionWeight = "high" | "normal" | "low";

/** Tony o ZDEFINIOWANYM szablonie S4 — lustro KnownTones z pkg/ontology.
 * Metaschemat odrzuca inne, więc formularz nie może ich zaoferować. */
export const KNOWN_TONES = ["phenomenological"] as const;

export interface ReportProfileView {
  sections: Partial<Record<ReportSection, SectionWeight>>;
  defaultTone: string;
  /** Układ nazwanych sekcji (M5+). Niepusty = wagi nie obowiązują
   * (mechanizmy wzajemnie wykluczające po stronie metaschematu). */
  layout: LayoutSectionView[];
}

export interface LayoutSectionView {
  id: string;
  title: string;
  kind: string;
  constructs: string[];
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

function readGlosses(v: unknown): Record<string, string> {
  if (v === null || typeof v !== "object" || Array.isArray(v)) return {};
  const out: Record<string, string> = {};
  for (const [k, val] of Object.entries(v as Record<string, unknown>)) {
    const g = asString(val);
    if (k !== "" && g !== "") out[k] = g;
  }
  return out;
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
      valueGlosses: readGlosses(c?.value_glosses),
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
      slots: readSlots(c?.slots),
      minCompleteSlots: Number.isFinite(Number(c?.min_complete_slots))
        ? Number(c?.min_complete_slots)
        : null,
      hasQuantitiesPolicy: c?.quantities != null,
    };
  });

  return {
    modality: asString(raw?.modality),
    version: asString(raw?.version),
    constructs,
    reportProfile: readReportProfile(raw?.report_profile),
  };
}

function readReportProfile(v: unknown): ReportProfileView | null {
  if (v == null || typeof v !== "object") return null;
  const raw = v as Record<string, unknown>;
  const sections: Partial<Record<ReportSection, SectionWeight>> = {};
  const rawSections = (raw.sections ?? {}) as Record<string, unknown>;
  for (const key of REPORT_SECTIONS) {
    const sec = rawSections[key];
    if (sec != null && typeof sec === "object") {
      const w = asString((sec as Record<string, unknown>).weight);
      if (w === "high" || w === "normal" || w === "low") sections[key] = w;
    }
  }
  const layout: LayoutSectionView[] = Array.isArray(raw.layout)
    ? (raw.layout as unknown[])
        .filter((e): e is Record<string, unknown> => e != null && typeof e === "object")
        .map((e) => ({
          id: asString(e.id),
          title: asString(e.title),
          kind: asString(e.kind),
          constructs: asStringList(e.constructs),
        }))
    : [];
  return { sections, defaultTone: asString(raw.default_tone), layout };
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

/** Kolejność slotów zachowana z pliku — to kolejność, w której ekspert
 * je zapisał, i jedyna, która dla niego coś znaczy. */
function readSlots(v: unknown): SlotView[] {
  if (v == null || typeof v !== "object") return [];
  return Object.entries(v as Record<string, unknown>).map(([name, raw]) => {
    const s = (raw ?? {}) as Record<string, unknown>;
    const { kind, target } = parseSlotType(asString(s.type));
    return {
      name,
      kind,
      target,
      required: s.required === true,
      kindHint: asString(s.kind_hint),
      quantity: s.quantity === true,
    };
  });
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
  // Deduplikacja: powtórzony wpis w `is_not` albo `requires` nic nie
  // znaczy, a trafiłby do pliku i do diffu jako szum. Kolejność
  // pierwszego wystąpienia zostaje — jest deterministyczna.
  const clean = [...new Set(values.map((v) => v.trim()).filter((v) => v !== ""))];
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

/** Ustawia lub usuwa glosę jednej wartości katalogu.
 *
 * Pusta glosa = usunięcie wpisu (nie zapisujemy pustych stringów — YAML
 * czyta ekspert). Po usunięciu ostatniej glosy znika cały klucz
 * `value_glosses`, żeby plik nie nosił pustego obiektu. Klucz glosy
 * osierocony przez edycję `values` NIE jest tu czyszczony automatycznie:
 * wykryje go walidacja serwera (G1) — usunięcie treści eksperckiej po
 * cichu byłoby gorsze niż widoczny błąd. */
export function setValueGloss(doc: OntologyDoc, id: string, value: string, gloss: string): void {
  const path = ["constructs", id, "value_glosses", value];
  const clean = gloss.trim();
  if (clean === "") {
    doc.deleteIn(path);
    const rodzic = doc.getIn(["constructs", id, "value_glosses"]) as
      | { items?: unknown[] }
      | undefined;
    if (rodzic && Array.isArray(rodzic.items) && rodzic.items.length === 0) {
      doc.deleteIn(["constructs", id, "value_glosses"]);
    }
    return;
  }
  doc.setIn(path, clean);
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

/** Zapisuje sloty kompozytu.
 *
 * Slot bez nazwy albo bez celu (gdy rodzaj go wymaga) jest POMIJANY:
 * formularz może mieć wiersz w trakcie wypełniania, a niedokończony slot
 * nie ma prawa trafić do treści, którą zobaczy walidator. */
export function setSlots(doc: OntologyDoc, id: string, slots: SlotView[]): void {
  const path = ["constructs", id, "slots"];
  const out: Record<string, Record<string, unknown>> = {};
  for (const s of slots) {
    const nazwa = s.name.trim();
    if (nazwa === "") continue;
    if (slotNeedsTarget(s.kind) && s.target.trim() === "") continue;
    const body: Record<string, unknown> = { type: slotTypeString(s) };
    if (s.required) body.required = true;
    if (s.kindHint !== "") body.kind_hint = s.kindHint;
    if (s.quantity) body.quantity = true;
    out[nazwa] = body;
  }
  if (Object.keys(out).length === 0) {
    doc.deleteIn(path);
    return;
  }
  doc.setIn(path, doc.createNode(out));
}

/** Metaschemat dopuszcza `min_complete_slots` w zakresie 1..liczba slotów
 * i WYŁĄCZNIE dla kompozytu. Formularz ogranicza suwak, ale wołający i tak
 * przycina — wartość spoza zakresu nie ma jak trafić do pliku. */
export function setMinCompleteSlots(
  doc: OntologyDoc,
  id: string,
  n: number | null,
  liczbaSlotow: number,
): void {
  const path = ["constructs", id, "min_complete_slots"];
  if (n === null || liczbaSlotow === 0) {
    doc.deleteIn(path);
    return;
  }
  const przyciete = Math.min(Math.max(1, n), liczbaSlotow);
  doc.setIn(path, przyciete);
}

/** Ustawia wagę sekcji raportu (M5).
 *
 * "normal" USUWA wpis zamiast go zapisywać: normal jest wartością
 * domyślną, a profil ma nieść wyłącznie odstępstwa — inaczej każda
 * ontologia dźwigałaby pełną kopię domyślnej kompozycji, a diff przeglądu
 * pokazywałby "zmiany" tam, gdzie nikt niczego nie zmienił. */
export function setSectionWeight(
  doc: OntologyDoc,
  section: ReportSection,
  weight: SectionWeight,
): void {
  // Ontologia z ukladem nie ma wag (mechanizmy wzajemnie wykluczajace);
  // zapis wagi obok ukladu tworzylby dokument, ktorego walidacja nie
  // przyjmie. Panel tego nie oferuje, ale model tez nie moze.
  const uklad = doc.getIn(["report_profile", "layout"]);
  if (uklad != null) return;
  if (weight === "normal") {
    // deleteIn rzuca na brakujacym wezle posrednim — profil bez `sections`
    // (np. sam ton) to stan legalny, wiec brak wpisu to brak roboty.
    if (doc.getIn(["report_profile", "sections"]) != null) {
      doc.deleteIn(["report_profile", "sections", section]);
    }
    czyscPustyProfil(doc);
    return;
  }
  doc.setIn(["report_profile", "sections", section], doc.createNode({ weight }));
}

/** Ustawia ton językowy S4. Pusty = brak tonu (usuwa klucz). */
export function setDefaultTone(doc: OntologyDoc, tone: string): void {
  if (tone.trim() === "") {
    doc.deleteIn(["report_profile", "default_tone"]);
    czyscPustyProfil(doc);
    return;
  }
  doc.setIn(["report_profile", "default_tone"], tone.trim());
}

/** Profil bez odstępstw znika z pliku w całości — pusty blok
 * `report_profile: {}` sugerowałby decyzję, której nikt nie podjął. */
function czyscPustyProfil(doc: OntologyDoc): void {
  const raw = doc.getIn(["report_profile"]);
  const js =
    raw != null && typeof (raw as { toJSON?: unknown }).toJSON === "function"
      ? (raw as { toJSON: () => unknown }).toJSON()
      : raw;
  if (js == null || typeof js !== "object") return;
  const obj = js as Record<string, unknown>;
  const sekcje = obj.sections as Record<string, unknown> | undefined;
  const maSekcje = sekcje != null && Object.keys(sekcje).length > 0;
  const maTon = typeof obj.default_tone === "string" && obj.default_tone !== "";
  // Uklad to tez tresc profilu — bez tego zdjecie tonu z ontologii
  // z ukladem wycieloby caly report_profile razem z ukladem.
  const maUklad = Array.isArray(obj.layout) && obj.layout.length > 0;
  if (!maSekcje && !maTon && !maUklad) {
    doc.deleteIn(["report_profile"]);
  } else if (!maSekcje && sekcje != null) {
    doc.deleteIn(["report_profile", "sections"]);
  }
}
