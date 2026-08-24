package ontopipe

import (
	"context"
	"reflect"
	"strings"
	"testing"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// ── Niezmiennik architektoniczny ──

// TestS4NieMaDostepuDoTranskrypcji pilnuje inwersji antykonfabulacyjnej.
//
// Test jest po REFLEKSJI, a nie po zachowaniu, bo chroni przed zmiana,
// ktora nic nie zepsuje w czasie dzialania: pole "transcript" dodane do
// SynthesisInput "dla kontekstu stylistycznego" skompiluje sie, przejdzie
// wszystkie inne testy i po cichu cofnie najwazniejsza gwarancje calej
// architektury. Jesli ten test pada, to nie jest usterka testu — to jest
// decyzja do podjecia swiadomie.
func TestS4NieMaDostepuDoTranskrypcji(t *testing.T) {
	// Kazda pozycja tej listy to SWIADOMA decyzja, ze pole nie wnosi
	// materialu zrodlowego. PastSpanIDs doszlo 2026-08-23: niesie sam
	// podzbior identyfikatorow, ktore i tak sa juz w Claims, i istnieje
	// po to, zeby S4 mogl SPELNIC regule V3 zamiast byc nia zaskakiwany.
	// Kazda pozycja to SWIADOMA decyzja, ze pole nie wnosi materialu
	// zrodlowego. Want*/Guidance* (2026-08-24): flagi ukladu M5 i wytyczne
	// EKSPERCKIE z ontologii — wersjonowane, po four-eyes, zero tresci
	// sesji.
	dozwolone := map[string]bool{
		"Claims": true, "Patterns": true, "Degraded": true,
		"Insufficient": true, "NoFit": true, "Corrections": true,
		"PastSpanIDs":     true,
		"Language":              true, // tag jezykowy raportu — zero materialu sesji
		"WantSuggestions": true, "WantInterventions": true,
		"SuggestionsGuidance": true, "InterventionsGuidance": true,
	}
	ty := reflect.TypeOf(SynthesisInput{})
	for i := 0; i < ty.NumField(); i++ {
		f := ty.Field(i)
		if !dozwolone[f.Name] {
			t.Fatalf("SynthesisInput zyskal pole %q (%s). S4 ma widziec WYLACZNIE "+
				"zatwierdzone byty — kazde nowe pole wymaga sprawdzenia, czy nie "+
				"wnosi materialu zrodlowego", f.Name, f.Type)
		}
	}

	// Sygnatura Synthesize nie moze przyjmowac Input (niesie transkrypcje).
	fn := reflect.TypeOf(Synthesize)
	for i := 0; i < fn.NumIn(); i++ {
		if fn.In(i) == reflect.TypeOf(Input{}) {
			t.Fatal("Synthesize przyjmuje Input — to daje S4 transkrypcje")
		}
	}
}

func TestS4NieDostajeTranskrypcjiWTresci(t *testing.T) {
	f := domyslnaAtrapa(t)
	_, err := Run(context.Background(), f, Input{
		SessionID: "sess-1", Transcript: testTranskrypcja, Ontology: testO(t),
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	// Zdanie terapeuty NIE jest cytowane w zadnym twierdzeniu, wiec nie
	// ma prawa pojawic sie w materiale S4. Gdyby wyciekla transkrypcja,
	// wyciekloby razem z nia.
	const tylkoWTranskrypcji = "Co się dzieje, kiedy czuje pan to duszenie?"
	for _, req := range f.Zapytal {
		if req.Model != ModelSynthesis {
			continue
		}
		if strings.Contains(req.UserContent, tylkoWTranskrypcji) {
			t.Fatal("material S4 zawiera fragment transkrypcji spoza zatwierdzonych cytatow")
		}
	}
}

// ── Przebieg calego potoku ──

func TestRunCalyPotok(t *testing.T) {
	f := domyslnaAtrapa(t)
	res, err := Run(context.Background(), f, Input{
		SessionID: "sess-1", Transcript: testTranskrypcja, Ontology: testO(t),
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if len(res.Spans) != 3 {
		t.Fatalf("spanow %d, oczekiwano 3 (%v)", len(res.Spans), res.S1Rejected)
	}
	if len(res.Approved) != 2 {
		t.Fatalf("zatwierdzonych twierdzen %d, oczekiwano 2: %+v", len(res.Approved), res.Rejected)
	}
	if res.Extractive {
		t.Fatalf("tryb ekstraktywny przy poprawnym przebiegu: %v", res.Violations)
	}
	if len(res.Report.Constructs) == 0 {
		t.Fatal("pusty raport przy zatwierdzonych twierdzeniach")
	}
	if res.Usage.Calls != 5 { // S1 + 3x S2 + S4
		t.Fatalf("wywolan modelu %d, oczekiwano 5", res.Usage.Calls)
	}
}

// TestS1OdsiewaCytatNieistniejacy: span z cytatem, ktorego nie ma w
// zapisie, NIE MOZE opuscic S1.
func TestS1OdsiewaCytatNieistniejacy(t *testing.T) {
	f := domyslnaAtrapa(t)
	bazowy := f.handler
	f.handler = func(req LLMRequest) (string, error) {
		if req.Model == ModelExtraction {
			return `{"spans":[{"span_id":"s01","quote_verbatim":"Nigdy tego nie powiedziałem, a jednak tu jest.","speaker":"Klient","kind":"declarative","observed_by":"self","about_past":false,"risk_content":false,"topics":["x"]}]}`, nil
		}
		return bazowy(req)
	}
	spans, odrzucone, err := ExtractSpans(context.Background(), f, Input{
		SessionID: "s", Transcript: testTranskrypcja, Ontology: testO(t),
	}, &Usage{})
	if err != nil {
		t.Fatalf("ExtractSpans: %v", err)
	}
	if len(spans) != 0 {
		t.Fatalf("zmyslony cytat przeszedl weryfikacje mechaniczna: %+v", spans)
	}
	if len(odrzucone) != 1 || odrzucone[0] != "s01" {
		t.Fatalf("odrzucone = %v, oczekiwano [s01]", odrzucone)
	}
}

// TestS2NieWidziSpanowRyzyka: T22 — spany ryzyka sa odsiewane PRZED
// wyslaniem, nie dopiero w walidatorze.
func TestS2NieWidziSpanowRyzyka(t *testing.T) {
	const trescRyzyka = "Czasem myślę, żeby to wszystko zakończyć."
	f := domyslnaAtrapa(t)
	spans := []ontology.TopicSpan{
		{Span: ontology.Span{ID: "s01", QuoteVerbatim: "zwykla wypowiedz", Speaker: "Klient"}},
		{Span: ontology.Span{ID: "s99", QuoteVerbatim: trescRyzyka, Speaker: "Klient",
			RiskContent: true}},
	}
	if _, err := MapConstruct(context.Background(), f, testO(t), "konflikt", spans, &Usage{}); err != nil {
		t.Fatalf("MapConstruct: %v", err)
	}
	for _, req := range f.Zapytal {
		if strings.Contains(req.UserContent, trescRyzyka) {
			t.Fatal("tresc ryzyka trafila do kontekstu S2 — model dostal ja do przeczytania")
		}
	}
}

// TestKolejnoscZaleznosci: `zasob` wymaga `konflikt`, wiec musi byc
// walidowany PO nim. Alfabetycznie jest odwrotnie — i wlasnie dlatego
// ten test istnieje.
func TestKolejnoscZaleznosci(t *testing.T) {
	o := testO(t)
	kategorie, _ := o.ConstructsForStage()
	kolejnosc := orderByRequires(o, kategorie)

	pozycja := map[string]int{}
	for i, id := range kolejnosc {
		pozycja[id] = i
	}
	if pozycja["konflikt"] > pozycja["zasob"] {
		t.Fatalf("zasob przed konfliktem: %v — R3 zdegradowalaby go bez powodu", kolejnosc)
	}
}

func TestZasobDegradowanyGdyKonfliktOdpadl(t *testing.T) {
	f := domyslnaAtrapa(t)
	bazowy := f.handler
	f.handler = func(req LLMRequest) (string, error) {
		if req.Model == ModelMapping && konstruktZPromptu(req.SystemPrompt) == "konflikt" {
			return `{"construct_id":"konflikt","claims":[],"insufficient_data":true,"no_fit":false}`, nil
		}
		return bazowy(req)
	}
	res, err := Run(context.Background(), f, Input{
		SessionID: "s", Transcript: testTranskrypcja, Ontology: testO(t),
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if len(res.Degraded) != 1 || res.Degraded[0].ConstructID != "zasob" {
		t.Fatalf("zdegradowane = %+v, oczekiwano zasob (brak zatwierdzonego konfliktu)", res.Degraded)
	}
	// R3 DEGRADUJE, nie usuwa — konstrukt nie moze zniknac.
	for _, r := range res.Rejected {
		if r.ConstructID == "zasob" && r.Reason == ontology.ReasonRequires {
			t.Fatal("zasob zostal odrzucony zamiast zdegradowany")
		}
	}
}
