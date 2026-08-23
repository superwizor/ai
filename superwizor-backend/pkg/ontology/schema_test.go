package ontology

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func wczytajSeed(t *testing.T, modalnosc string) *Ontology {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("..", "..", "ontology", modalnosc, "0.1.0.yaml"))
	if err != nil {
		t.Skipf("brak seeda %s: %v", modalnosc, err)
	}
	o, err := Load(data)
	if err != nil {
		t.Fatalf("%s: %v", modalnosc, err)
	}
	return o
}

// pole wyciaga zagniezdzone pole schematu; upraszcza asercje.
func pole(t *testing.T, m map[string]any, sciezka ...string) any {
	t.Helper()
	var cur any = m
	for _, k := range sciezka {
		mm, ok := cur.(map[string]any)
		if !ok {
			t.Fatalf("sciezka %v: %q nie jest obiektem", sciezka, k)
		}
		cur, ok = mm[k]
		if !ok {
			t.Fatalf("sciezka %v: brak klucza %q", sciezka, k)
		}
	}
	return cur
}

// TestKatalogTrafiaDoEnumu to sedno architektury: model nie moze zwrocic
// kategorii spoza taksonomii, bo structured output ja odrzuci. Bez tego
// caly potok S1-S5 jest tylko dluzszym promptem.
func TestKatalogTrafiaDoEnumu(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	s, err := o.SchemaForConstruct("actual_capacity_secondary", SchemaOptions{})
	if err != nil {
		t.Fatal(err)
	}
	enum, ok := pole(t, s, "properties", "claims", "items", "properties", "category", "enum").([]any)
	if !ok {
		t.Fatal("category nie ma enumu — katalog nie jest egzekwowany")
	}
	if len(enum) != len(o.Constructs["actual_capacity_secondary"].Values) {
		t.Errorf("enum ma %d pozycji, katalog %d", len(enum), len(o.Constructs["actual_capacity_secondary"].Values))
	}
	// Wartosci z feedbacku, ktore NIE moga byc dopuszczalne.
	for _, zakazana := range []string{"spokój", "troska o siebie", "samoświadomość", "perfekcjonizm"} {
		for _, v := range enum {
			if v == zakazana {
				t.Errorf("enum dopuszcza %q — to jest bląd kategorialny z feedbacku", zakazana)
			}
		}
	}
}

// TestStatusyPierwszejKlasySaPolami — insufficient_data i no_fit musza
// byc jawnymi polami wymaganymi, nie brakiem odpowiedzi. Pusta lista
// twierdzen bez powodu jest nierozroznialna od milczenia z lenistwa.
func TestStatusyPierwszejKlasySaPolami(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	s, _ := o.SchemaForConstruct("current_conflict", SchemaOptions{})
	req, _ := s["required"].([]any)
	maForm := map[string]bool{}
	for _, r := range req {
		maForm[r.(string)] = true
	}
	for _, k := range []string{"insufficient_data", "no_fit", "claims", "construct_id"} {
		if !maForm[k] {
			t.Errorf("%q nie jest wymagane w schemacie", k)
		}
	}
}

// TestProweniencjaJestWymogiemSchematu — evidence ma minItems 1, wiec
// twierdzenie bez spanu zrodlowego nie moze powstac (objaw 5 z dok. 11).
func TestProweniencjaJestWymogiemSchematu(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	s, _ := o.SchemaForConstruct("positum", SchemaOptions{})
	min := pole(t, s, "properties", "claims", "items", "properties", "evidence", "minItems")
	if min != int64(1) {
		t.Errorf("evidence.minItems = %v, oczekiwano 1 — proweniencja przestaje byc wymogiem", min)
	}
	// counter_evidence celowo BEZ minimum: dane przeciw sa cenne, ale
	// ich brak nie jest bledem.
	minC := pole(t, s, "properties", "claims", "items", "properties", "counter_evidence", "minItems")
	if minC != int64(0) {
		t.Errorf("counter_evidence.minItems = %v, oczekiwano 0", minC)
	}
}

// TestForcedStatusZawezaEnum — roznica miedzy "prompt prosi" a "schemat
// nie dopuszcza". inner_conflict w PPT jest zawsze hipoteza teoretyczna.
func TestForcedStatusZawezaEnum(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	s, _ := o.SchemaForConstruct("inner_conflict", SchemaOptions{})
	enum, _ := pole(t, s, "properties", "claims", "items", "properties", "epistemic_status", "enum").([]any)
	if len(enum) != 1 || enum[0] != "theoretical_hypothesis" {
		t.Errorf("enum statusu = %v, oczekiwano wylacznie theoretical_hypothesis", enum)
	}
}

// TestStatusyObiektuNieSaStatusamiTwierdzenia — twierdzenie, ktore
// ISTNIEJE, ma status merytoryczny; insufficient_data opisuje brak
// twierdzenia, wiec nie moze byc jego statusem.
func TestStatusyObiektuNieSaStatusamiTwierdzenia(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	s, _ := o.SchemaForConstruct("current_conflict", SchemaOptions{})
	enum, _ := pole(t, s, "properties", "claims", "items", "properties", "epistemic_status", "enum").([]any)
	for _, v := range enum {
		if v == "insufficient_data" || v == "no_fit" {
			t.Errorf("status twierdzenia dopuszcza %q — to pole obiektu, nie status", v)
		}
	}
}

// TestMultiLabelDajeTablice — M2 z dok. 11: zniekształcenia CBT moga
// wystapic po kilka na jednym spanie.
func TestMultiLabelDajeTablice(t *testing.T) {
	o := wczytajSeed(t, "cbt")
	s, _ := o.SchemaForConstruct("cognitive_distortion", SchemaOptions{})
	typ := pole(t, s, "properties", "claims", "items", "properties", "category", "type")
	if typ != "array" {
		t.Errorf("multi_label dal typ %v, oczekiwano array", typ)
	}
}

// TestKompozytyPomijaneJawnie — M1 wymaga innego ksztaltu schematu;
// pominiecie ma byc widoczne, a nie wygladac na pelne pokrycie.
func TestKompozytyPomijaneJawnie(t *testing.T) {
	o := wczytajSeed(t, "cbt")
	kategorie, pominiete := o.ConstructsForStage()
	if len(pominiete) == 0 {
		t.Error("CBT ma kompozyt cbt_episode — powinien byc zgloszony jako pominiety")
	}
	for _, id := range kategorie {
		if o.Constructs[id].Kind == KindComposite {
			t.Errorf("%s to kompozyt, a trafil do listy kategorii", id)
		}
	}
}

// TestSchematJestPoprawnymJSON — Vertex dostaje go po serializacji.
func TestSchematJestPoprawnymJSON(t *testing.T) {
	for _, mod := range []string{"ppt", "cbt"} {
		o := wczytajSeed(t, mod)
		kategorie, _ := o.ConstructsForStage()
		for _, id := range kategorie {
			s, err := o.SchemaForConstruct(id, SchemaOptions{})
			if err != nil {
				t.Fatalf("%s/%s: %v", mod, id, err)
			}
			if _, err := json.Marshal(s); err != nil {
				t.Errorf("%s/%s: schemat nie serializuje sie: %v", mod, id, err)
			}
		}
	}
}

func TestNieznanyKonstruktJestBledem(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	if _, err := o.SchemaForConstruct("nie_istnieje", SchemaOptions{}); err == nil {
		t.Error("schemat dla nieistniejacego konstruktu powstal")
	}
}

// TestPewnoscJestWymagana — pole opcjonalne model po prostu pomijał, a
// Go zapisywało wtedy zero: nierozróżnialne od świadomego „nie jestem
// pewien". W raporcie znikała cała adnotacja, bo rendering pomija zero.
//
// Kanarek CBT (2026-08-23): dwa twierdzenia `emotion` weszły do bazy z
// pewnością 0, choć reszta miała 0,8–1,0.
func TestPewnoscJestWymagana(t *testing.T) {
	o := mustParse(t, okYAML)
	for _, id := range []string{"alpha", "beta"} {
		sch, err := o.SchemaForConstruct(id, SchemaOptions{})
		if err != nil {
			t.Fatalf("%s: %v", id, err)
		}
		claim := sch["properties"].(map[string]any)["claims"].(map[string]any)["items"].(map[string]any)
		req, _ := claim["required"].([]any)
		found := false
		for _, r := range req {
			if r == "confidence" {
				found = true
			}
		}
		if !found {
			t.Errorf("%s: confidence nie jest wymagane — model je pominie, a zero "+
				"jest nierozroznialne od swiadomej niskiej pewnosci (wymagane: %v)", id, req)
		}
		// Opis musi zostac: bez niego wymagane pole dostaje wartosc
		// przypadkowa zamiast przemyslanej.
		conf, _ := claim["properties"].(map[string]any)["confidence"].(map[string]any)
		if d, _ := conf["description"].(string); d == "" {
			t.Errorf("%s: confidence bez opisu", id)
		}
	}
}
