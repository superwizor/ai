package chat

import (
	"context"
	"strings"
	"testing"

	"github.com/superwizor-ai/backend/pkg/guardrail"
)

// ── Wykrywanie modalnosci w pytaniu ───────────────────────────────────

func TestDetectRequestedModality(t *testing.T) {
	cases := map[string]string{
		"jak konceptualizacja wygląda w podejściu CBT?":     "CBT",
		"ujęcie poznawczo-behawioralne tego materiału":      "CBT",
		"zastosuj model równowagi do analizy":               "PPT",
		"co powiedziałby Peseschkian?":                      "PPT",
		"spójrz na to przez pryzmat Gestalt":                "GESTALT",
		"perspektywa psychodynamiczna tej relacji":          "PSYCHO",
		"jak ująłby to terapeuta EFT?":                      "EFT",
		"w ujęciu systemowym, kto podtrzymuje ten wzorzec?": "SYS",
		"czy w terapii schematów to byłby tryb unikający?":  "ST",
		"potraktuj to coachingowo, modelem GROW":            "COACH",
	}
	for q, want := range cases {
		got, ok := DetectRequestedModality(q)
		if !ok || got != want {
			t.Errorf("%q -> (%q,%v), oczekiwano %q", q, got, ok, want)
		}
	}
}

// Konserwatywnosc aliasow: slownictwo szkol NIE przelacza soczewki.
// Falszywe dopasowanie podmienia rame analityczna po cichu — gorsze niz
// brak dopasowania, ktory tylko spada do modalnosci kartoteki.
func TestDetectDoesNotFireOnOrdinaryClinicalVocabulary(t *testing.T) {
	for _, q := range []string{
		"jakie schematy myślenia się powtarzają?",    // CBT-slownik, nie prosba o ST
		"klientka systematycznie unika konfrontacji", // nie SYS
		"pokaż pozytywne strony tej zmiany",          // nie PPT
		"jak wygląda schemat sesji?",                 // nie ST
		"czy widać wzorce w emocjach?",               // nie EFT
	} {
		if code, ok := DetectRequestedModality(q); ok {
			t.Errorf("%q niesłusznie wykryto jako %q", q, code)
		}
	}
}

// Przy dwoch modalnosciach wygrywa wymieniona najwczesniej — wynik ma
// byc deterministyczny, nie zalezny od kolejnosci iteracji po mapie.
func TestDetectPrefersEarliestMention(t *testing.T) {
	got, ok := DetectRequestedModality("porównaj ujęcie CBT z perspektywą Gestalt")
	if !ok || got != "CBT" {
		t.Errorf("got %q, oczekiwano CBT (wymienione pierwsze)", got)
	}
	got2, _ := DetectRequestedModality("porównaj Gestalt z ujęciem CBT")
	if got2 != "GESTALT" {
		t.Errorf("got %q, oczekiwano GESTALT (wymienione pierwsze)", got2)
	}
}

// ── Soczewka w potoku ─────────────────────────────────────────────────

func lensHarness(t *testing.T, responses []string) *harness {
	t.Helper()
	segs := sampleSegments()
	h := newHarness(t, enabledConfig(), responses, segs)
	h.pool.fileLens = &fakeLens{code: "PPT", name: "Pozytywny (PPT)",
		fragment: "POSITUM-MARKER: szukaj zasobow w trudnosci; Model Rownowagi."}
	h.pool.lensByCode = map[string]fakeLens{
		"CBT": {code: "CBT", name: "Poznawczo-Behawioralny (CBT)",
			fragment: "CBT-MARKER: sytuacja, mysl automatyczna, emocja, zachowanie."},
		"PPT": {code: "PPT", name: "Pozytywny (PPT)",
			fragment: "POSITUM-MARKER: szukaj zasobow w trudnosci; Model Rownowagi."},
	}
	return h
}

func a8Response(h *harness) string {
	segs := h.pool.segments
	return `{"hypotheses":[{"title":"H","body":"b","quotes":[{"session_id":"` +
		segs[0].SessionID.String() + `","segment_id":"` + segs[0].ID.String() +
		`","text":"W pracy czuję ciągłe napięcie"}]}]}`
}

// Kartoteka PPT + pytanie bez wzmianki o modalnosci -> soczewka PPT
// trafia do promptu SYSTEMOWEGO generatora.
func TestFileLensReachesTheGeneratorPrompt(t *testing.T) {
	h := lensHarness(t, []string{
		`{"intent":"A8_CONCEPT","confidence":0.95,"risk_flag":false}`, "", `{"violation":false,"code":"none"}`,
	})
	h.llm.responses[1] = a8Response(h)

	tq := turn()
	tq.Question = "Jak rozumieć jej napięcie w pracy?"
	out, err := h.svc.Ask(context.Background(), tq)
	if err != nil || out.Kind != OutcomeAnswered {
		t.Fatalf("Ask: %v kind=%v", err, out.Kind)
	}

	var genSys string
	for _, c := range h.llm.calls {
		if strings.Contains(c.UserContent, "FRAGMENTY TRANSKRYPCJI") {
			genSys = c.SystemPrompt
		}
	}
	if !strings.Contains(genSys, "POSITUM-MARKER") {
		t.Error("soczewka kartoteki (PPT) nie dotarla do promptu generatora")
	}
	if !strings.Contains(genSys, "nigdy zasady") {
		t.Error("brak kodowego ogona z inwariantami — Render() nie zadzialal")
	}
	// Zadanie intencji ma stac PRZED soczewka — to ono wygrywa.
	if strings.Index(genSys, "POSITUM-MARKER") < strings.Index(genSys, "hipotezy") &&
		strings.Index(genSys, "konceptualizacj") > strings.Index(genSys, "POSITUM-MARKER") {
		t.Error("soczewka wyprzedza prompt intencji")
	}
}

// Kartoteka PPT + pytanie "w podejsciu CBT" -> soczewka CBT, nie PPT.
// To jest wprost przypadek z wymagania: dociagniecie innej modalnosci.
func TestRequestedModalityOverridesFileModality(t *testing.T) {
	h := lensHarness(t, []string{
		`{"intent":"A8_CONCEPT","confidence":0.95,"risk_flag":false}`, "", `{"violation":false,"code":"none"}`,
	})
	h.llm.responses[1] = a8Response(h)

	tq := turn()
	tq.Question = "Jak konceptualizacja jej napięcia wyglądałaby w podejściu CBT?"
	out, err := h.svc.Ask(context.Background(), tq)
	if err != nil || out.Kind != OutcomeAnswered {
		t.Fatalf("Ask: %v kind=%v", err, out.Kind)
	}

	var genSys string
	for _, c := range h.llm.calls {
		if strings.Contains(c.UserContent, "FRAGMENTY TRANSKRYPCJI") {
			genSys = c.SystemPrompt
		}
	}
	if !strings.Contains(genSys, "CBT-MARKER") {
		t.Error("zadana modalnosc (CBT) nie dotarla do generatora")
	}
	if strings.Contains(genSys, "POSITUM-MARKER") {
		t.Error("soczewka kartoteki (PPT) nie ustapila zadanej (CBT)")
	}
}

// A4 z wymieniona modalnoscia dostaje soczewke; NIGDY nie odpytuje
// kartoteki — modalnosc prowadzonego procesu to informacja o kliencie.
func TestEducationGetsLensOnlyWhenExplicitlyRequested(t *testing.T) {
	h := lensHarness(t, []string{
		`{"intent":"A4_EDU","confidence":0.95,"risk_flag":false}`,
		`{"sections":[{"title":"Konceptualizacja w CBT","body":"Model poznawczy..."}]}`,
		`{"violation":false,"code":"none"}`,
	})
	tq := turn()
	tq.Question = "Jak konceptualizacja wygląda w podejściu CBT?"
	if _, err := h.svc.Ask(context.Background(), tq); err != nil {
		t.Fatalf("Ask: %v", err)
	}
	var eduSys string
	for _, c := range h.llm.calls {
		if strings.Contains(c.SystemPrompt, "OGOLNOZAWODOWE") || strings.Contains(c.SystemPrompt, "ogolnozawodowe") ||
			strings.Contains(c.SystemPrompt, "OGÓLNOZAWODOWE") {
			eduSys = c.SystemPrompt
		}
	}
	if eduSys == "" {
		t.Fatal("nie znaleziono wywolania A4")
	}
	if !strings.Contains(eduSys, "CBT-MARKER") {
		t.Error("A4 z jawna prosba o CBT nie dostal soczewki")
	}
	if h.pool.queried("FROM patient_files pf") {
		t.Error("A4 odpytal kartoteke o modalnosc — to informacja o kliencie")
	}

	// I odwrotnie: A4 bez wzmianki -> zero soczewki, zero zapytania.
	h2 := lensHarness(t, []string{
		`{"intent":"A4_EDU","confidence":0.95,"risk_flag":false}`,
		`{"sections":[{"title":"Ekspozycja","body":"..."}]}`,
		`{"violation":false,"code":"none"}`,
	})
	tq2 := turn()
	tq2.Question = "Czym różni się ekspozycja od desensytyzacji?"
	if _, err := h2.svc.Ask(context.Background(), tq2); err != nil {
		t.Fatalf("Ask: %v", err)
	}
	for _, c := range h2.llm.calls {
		if strings.Contains(c.SystemPrompt, "SOCZEWKA MODALNOSCI") {
			t.Error("A4 bez prosby o modalnosc dostal soczewke")
		}
	}
	if h2.pool.queried("FROM patient_files pf") {
		t.Error("A4 bez prosby odpytal kartoteke o modalnosc")
	}
}

// Brak fragmentu 'chat' w bazie = dzisiejsze zachowanie, bez soczewki i
// bez wywrotki.
func TestMissingFragmentDegradesToNoLens(t *testing.T) {
	segs := sampleSegments()
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A8_CONCEPT","confidence":0.95,"risk_flag":false}`, "", `{"violation":false,"code":"none"}`,
	}, segs)
	h.llm.responses[1] = a8Response(h)
	// fileLens zostaje nil — kartoteka bez klucza 'chat'.

	tq := turn()
	tq.Question = "Jak rozumieć jej napięcie w pracy?"
	out, err := h.svc.Ask(context.Background(), tq)
	if err != nil || out.Kind != OutcomeAnswered {
		t.Fatalf("Ask: %v kind=%v", err, out.Kind)
	}
	for _, c := range h.llm.calls {
		if strings.Contains(c.SystemPrompt, "SOCZEWKA MODALNOSCI") {
			t.Error("soczewka pojawila sie mimo braku fragmentu")
		}
	}
}

// resolveLens: prosba o modalnosc nieznana bazie spada do kartoteki.
func TestUnknownRequestedCodeFallsBackToFile(t *testing.T) {
	h := lensHarness(t, nil)
	delete(h.pool.lensByCode, "CBT")
	lens, ok := h.svc.resolveLens(context.Background(), Turn{
		PatientFileID: turn().PatientFileID,
		Question:      "ujęcie CBT proszę",
	}, guardrail.A8Concept)
	if !ok || lens.Code != "PPT" {
		t.Errorf("fallback nie zadzialal: (%+v, %v)", lens, ok)
	}
}
