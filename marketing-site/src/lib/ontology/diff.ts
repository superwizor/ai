// Diff semantyczny ontologii (dok. 17, K4).
//
// ══ Po co ══
//
// Ścieżka `draft → ready_for_review → approved` wymaga DRUGIEGO eksperta
// (four-eyes, egzekwowane w trzech warstwach: kod, `WHERE created_by <>`,
// CHECK w schemacie). Dziś ten ekspert dostaje dwa bloki YAML i ma
// wypatrzeć różnicę okiem — przy PPT to 300 linii. W praktyce
// zatwierdzenie jest więc pieczątką: nikt realnie nie porówna dwóch
// takich plików.
//
// ══ Dlaczego semantyczny, a nie tekstowy ══
//
// Przestawienie kolejności kluczy w YAML-u NIE jest zmianą ontologii.
// Przesunięcie progu dowodowego JEST. Diff tekstowy zalałby recenzenta
// szumem z formatera i ukrył tę jedną linię, która ma znaczenie —
// zwłaszcza że kreator przepisuje węzły, których dotknął.
//
// Komentarze celowo poza zakresem: `# ZWERYFIKOWAĆ` bywa przenoszony
// razem z polem, a zgłaszanie tego jako zmiany dałoby dokładnie ten szum,
// którego ta funkcja ma nie produkować.

import {
  REPORT_SECTIONS,
  type ConstructView,
  type OntologyView,
  type SlotView,
} from "./model";

export type ZmianaRodzaj = "dodano" | "usunieto" | "zmieniono";

export interface Zmiana {
  rodzaj: ZmianaRodzaj;
  /** Konstrukt, którego dotyczy. Puste = nagłówek ontologii. */
  konstrukt: string;
  /** Klucz komunikatu — tłumaczony po stronie UI, żeby ta funkcja
   * pozostała czysta i testowalna bez i18n. */
  klucz: string;
  /** Wartości do wstawienia w komunikat. */
  dane?: Record<string, string | number>;
}

export function diffOntologii(przed: OntologyView, po: OntologyView): Zmiana[] {
  const out: Zmiana[] = [];

  if (przed.version !== po.version) {
    out.push({
      rodzaj: "zmieniono",
      konstrukt: "",
      klucz: "wersja",
      dane: { z: przed.version, na: po.version },
    });
  }

  const mapaPrzed = new Map(przed.constructs.map((c) => [c.id, c]));
  const mapaPo = new Map(po.constructs.map((c) => [c.id, c]));

  for (const c of po.constructs) {
    if (!mapaPrzed.has(c.id)) {
      out.push({
        rodzaj: "dodano",
        konstrukt: c.id,
        klucz: "konstruktDodany",
        dane: { nazwa: c.labelPl || c.id },
      });
    }
  }
  for (const c of przed.constructs) {
    if (!mapaPo.has(c.id)) {
      out.push({
        rodzaj: "usunieto",
        konstrukt: c.id,
        klucz: "konstruktUsuniety",
        dane: { nazwa: c.labelPl || c.id },
      });
    }
  }

  // Kolejność wg pliku PO zmianie — recenzent czyta dokument, który ma
  // przed sobą, a nie ten sprzed tygodnia.
  for (const c of po.constructs) {
    const stary = mapaPrzed.get(c.id);
    if (stary) out.push(...diffKonstruktu(stary, c));
  }

  out.push(...diffProfilu(przed, po));

  return out;
}

// diffProfilu pokazuje zmiany KOMPOZYCJI raportu (M5).
//
// Kompozycja zmienia to, co terapeuta czyta i w jakiej kolejności — więc
// podlega przeglądowi tak samo jak treść. Waga „normal" i brak wpisu to
// ta sama kompozycja, dlatego porównujemy wartości SKUTECZNE, nie
// obecność kluczy: dopisanie jawnego `normal` nie jest zmianą.
function diffProfilu(a: OntologyView, b: OntologyView): Zmiana[] {
  const out: Zmiana[] = [];
  const waga = (v: OntologyView, s: (typeof REPORT_SECTIONS)[number]) =>
    v.reportProfile?.sections[s] ?? "normal";

  for (const sekcja of REPORT_SECTIONS) {
    const z = waga(a, sekcja);
    const na = waga(b, sekcja);
    if (z !== na) {
      out.push({
        rodzaj: "zmieniono",
        konstrukt: "",
        klucz: "sekcjaWaga",
        dane: { sekcja, z, na },
      });
    }
  }

  const tonA = a.reportProfile?.defaultTone ?? "";
  const tonB = b.reportProfile?.defaultTone ?? "";
  if (tonA !== tonB) {
    out.push({
      rodzaj: "zmieniono",
      konstrukt: "",
      klucz: "tonRaportu",
      dane: { z: tonA || "—", na: tonB || "—" },
    });
  }
  return out;
}

function diffKonstruktu(a: ConstructView, b: ConstructView): Zmiana[] {
  const out: Zmiana[] = [];
  const zmiana = (klucz: string, dane?: Record<string, string | number>) =>
    out.push({ rodzaj: "zmieniono", konstrukt: b.id, klucz, dane });

  if (a.labelPl !== b.labelPl) zmiana("nazwa", { z: a.labelPl, na: b.labelPl });
  if (a.definition !== b.definition) zmiana("definicja");
  if (a.kind !== b.kind) zmiana("rodzaj", { z: a.kind, na: b.kind });
  if (a.multiLabel !== b.multiLabel) {
    zmiana(b.multiLabel ? "wielokrotnoscWlaczona" : "wielokrotnoscWylaczona");
  }
  if (a.forcedStatus !== b.forcedStatus) {
    zmiana("statusWymuszony", { z: a.forcedStatus || "—", na: b.forcedStatus || "—" });
  }

  // Katalog: null i [] to CO INNEGO. Pierwsze znaczy „konstrukt opisowy",
  // drugie „katalog istnieje, ale jest pusty" — a to drugie recenzent ma
  // zobaczyć, bo ontologia z pustym enumem nic nie egzekwuje.
  if ((a.values === null) !== (b.values === null)) {
    zmiana(b.values === null ? "katalogUsuniety" : "katalogDodany");
  } else if (a.values && b.values) {
    // dodano/usunieto, nie "zmieniono": dopisanie kategorii do
    // taksonomii jest DODANIEM i recenzent ma je zobaczyć jako takie —
    // inaczej wszystko zlewa się w jedną kategorię „coś ruszono".
    for (const v of b.values) {
      if (!a.values.includes(v)) {
        out.push({ rodzaj: "dodano", konstrukt: b.id, klucz: "wartoscDodana", dane: { v } });
      }
    }
    for (const v of a.values) {
      if (!b.values.includes(v)) {
        out.push({ rodzaj: "usunieto", konstrukt: b.id, klucz: "wartoscUsunieta", dane: { v } });
      }
    }
  }

  out.push(...diffProgu(a, b));
  out.push(...diffListy(a.isNot, b.isNot, b.id, "granica"));
  out.push(...diffListy(a.requires, b.requires, b.id, "zaleznosc"));
  out.push(...diffPomylek(a, b));
  out.push(...diffSlotow(a, b));

  return out;
}

function diffProgu(a: ConstructView, b: ConstructView): Zmiana[] {
  const out: Zmiana[] = [];
  const push = (klucz: string, dane: Record<string, string | number>) =>
    out.push({ rodzaj: "zmieniono", konstrukt: b.id, klucz, dane });

  const pa = a.minEvidence;
  const pb = b.minEvidence;
  if (!pa && !pb) return out;
  if (!pa && pb) return [{ rodzaj: "dodano", konstrukt: b.id, klucz: "progDodany", dane: { spans: pb.spans } }];
  if (pa && !pb) return [{ rodzaj: "usunieto", konstrukt: b.id, klucz: "progUsuniety", dane: {} }];
  if (pa && pb) {
    if (pa.spans !== pb.spans) push("progSpanow", { z: pa.spans, na: pb.spans });
    if ((pa.behavioral ?? 0) !== (pb.behavioral ?? 0)) {
      push("progBehawioralnych", { z: pa.behavioral ?? 0, na: pb.behavioral ?? 0 });
    }
    if ((pa.sessions ?? 1) !== (pb.sessions ?? 1)) {
      push("progSesji", { z: pa.sessions ?? 1, na: pb.sessions ?? 1 });
    }
  }
  return out;
}

function diffListy(a: string[], b: string[], id: string, klucz: string): Zmiana[] {
  const out: Zmiana[] = [];
  for (const v of b) if (!a.includes(v)) out.push({ rodzaj: "dodano", konstrukt: id, klucz: `${klucz}Dodana`, dane: { v } });
  for (const v of a) if (!b.includes(v)) out.push({ rodzaj: "usunieto", konstrukt: id, klucz: `${klucz}Usunieta`, dane: { v } });
  return out;
}

function diffPomylek(a: ConstructView, b: ConstructView): Zmiana[] {
  // Rejestr pomyłek jest ŻYWY — rośnie z tego, co model faktycznie
  // pomylił. Recenzent ma zobaczyć liczbę i nowe wpisy, bo to one mówią,
  // czego autor się nauczył od poprzedniej wersji.
  const klucz = (c: { input: string; correct: string }) => `${c.input}→${c.correct}`;
  const przed = new Set(a.confusions.map(klucz));
  const po = new Set(b.confusions.map(klucz));
  const out: Zmiana[] = [];
  for (const c of b.confusions) {
    if (!przed.has(klucz(c))) {
      out.push({ rodzaj: "dodano", konstrukt: b.id, klucz: "pomylkaDodana", dane: { wejscie: c.input } });
    }
  }
  for (const c of a.confusions) {
    if (!po.has(klucz(c))) {
      out.push({ rodzaj: "usunieto", konstrukt: b.id, klucz: "pomylkaUsunieta", dane: { wejscie: c.input } });
    }
  }
  return out;
}

function diffSlotow(a: ConstructView, b: ConstructView): Zmiana[] {
  const out: Zmiana[] = [];
  const opis = (s: SlotView) =>
    `${s.kind}${s.target ? `(${s.target})` : ""}${s.required ? "!" : ""}${s.kindHint ? `:${s.kindHint}` : ""}`;
  const przed = new Map(a.slots.map((s) => [s.name, s]));
  const po = new Map(b.slots.map((s) => [s.name, s]));

  for (const s of b.slots) {
    if (!przed.has(s.name)) {
      out.push({ rodzaj: "dodano", konstrukt: b.id, klucz: "slotDodany", dane: { nazwa: s.name } });
    } else if (opis(przed.get(s.name)!) !== opis(s)) {
      out.push({ rodzaj: "zmieniono", konstrukt: b.id, klucz: "slotZmieniony", dane: { nazwa: s.name } });
    }
  }
  for (const s of a.slots) {
    if (!po.has(s.name)) {
      out.push({ rodzaj: "usunieto", konstrukt: b.id, klucz: "slotUsuniety", dane: { nazwa: s.name } });
    }
  }
  if (a.minCompleteSlots !== b.minCompleteSlots) {
    out.push({
      rodzaj: "zmieniono",
      konstrukt: b.id,
      klucz: "minSlotow",
      dane: { z: a.minCompleteSlots ?? 0, na: b.minCompleteSlots ?? 0 },
    });
  }
  return out;
}
