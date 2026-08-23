package ontology

import (
	"testing"
	"time"
)

func ts(dzien int) time.Time {
	return time.Date(2026, 6, dzien, 10, 0, 0, 0, time.UTC)
}

func tspan(id, sesja string, dzien int, tematy ...string) TopicSpan {
	return TopicSpan{
		Span:   Span{ID: id, SessionID: sesja, SessionAt: ts(dzien), QuoteVerbatim: "x"},
		Topics: tematy,
	}
}

func znajdz(ps []Pattern, typ PatternType) []Pattern {
	var out []Pattern
	for _, p := range ps {
		if p.Type == typ {
			out = append(out, p)
		}
	}
	return out
}

// ── recurrence ──

func TestPowtarzalnoscPonizejProguNieJestWzorcem(t *testing.T) {
	// Dwa wystapienia to zbieg, nie wzorzec. Prog konserwatywny celowo:
	// falszywy wzorzec daje terapeucie liczbe, ktorej nie ma w materiale.
	ps := DetectPatterns([]TopicSpan{
		tspan("s1", "a", 1, "praca"),
		tspan("s2", "a", 1, "praca"),
	}, PatternOptions{})
	if len(znajdz(ps, PatternRecurrence)) != 0 {
		t.Errorf("dwa wystapienia uznane za wzorzec: %v", ps)
	}
}

func TestPowtarzalnoscPowyzejProguJestWzorcem(t *testing.T) {
	ps := DetectPatterns([]TopicSpan{
		tspan("s1", "a", 1, "praca"),
		tspan("s2", "a", 1, "praca"),
		tspan("s3", "b", 8, "praca"),
	}, PatternOptions{})
	rec := znajdz(ps, PatternRecurrence)
	if len(rec) != 1 {
		t.Fatalf("wzorcow = %d, oczekiwano 1", len(rec))
	}
	if len(rec[0].SpanIDs) != 3 {
		t.Errorf("spanow w proweniencji = %d, oczekiwano 3", len(rec[0].SpanIDs))
	}
	if rec[0].Sessions != 2 {
		t.Errorf("sesji = %d, oczekiwano 2", rec[0].Sessions)
	}
	if rec[0].MethodVersion != MethodVersion {
		t.Error("brak stempla wersji algorytmu — raport nie bedzie odtwarzalny")
	}
}

// TestT22_SpanyRyzykaNieZasilajaStatystyk to najwazniejszy test w tym
// pliku. "Temat wraca trzeci raz" policzone na wypowiedziach o mysli
// samobojczej byloby miekka ocena ryzyka — klasa IIb, poza zakresem
// produktu (dok. 14 §7).
func TestT22_SpanyRyzykaNieZasilajaStatystyk(t *testing.T) {
	ryzykowny := tspan("s3", "b", 8, "praca")
	ryzykowny.RiskContent = true

	ps := DetectPatterns([]TopicSpan{
		tspan("s1", "a", 1, "praca"),
		tspan("s2", "a", 1, "praca"),
		ryzykowny,
	}, PatternOptions{})

	if len(znajdz(ps, PatternRecurrence)) != 0 {
		t.Error("span ryzyka dopelnil prog wzorca — statystyka objela tresc ryzyka")
	}
	for _, p := range ps {
		for _, id := range p.SpanIDs {
			if id == "s3" {
				t.Errorf("span ryzyka trafil do proweniencji wzorca %s", p.ID)
			}
		}
	}
}

// ── co-occurrence ──

func TestWspolwystepowanieLiczoneWObrebieSpanu(t *testing.T) {
	ps := DetectPatterns([]TopicSpan{
		tspan("s1", "a", 1, "praca", "lęk"),
		tspan("s2", "a", 1, "praca", "lęk"),
	}, PatternOptions{})
	if len(znajdz(ps, PatternCoOccurrence)) != 1 {
		t.Errorf("wspolwystepowanie nie wykryte: %v", ps)
	}
}

// TestTematyWRoznychSpanachNieWspolwystepuja — sesja trwa godzine i
// laczy wszystko ze wszystkim; wspolwystepowanie musi byc obserwowalne
// w jednej wypowiedzi.
func TestTematyWRoznychSpanachNieWspolwystepuja(t *testing.T) {
	ps := DetectPatterns([]TopicSpan{
		tspan("s1", "a", 1, "praca"),
		tspan("s2", "a", 1, "lęk"),
		tspan("s3", "a", 1, "praca"),
		tspan("s4", "a", 1, "lęk"),
	}, PatternOptions{})
	if len(znajdz(ps, PatternCoOccurrence)) != 0 {
		t.Error("tematy z roznych spanow uznane za wspolwystepujace")
	}
}

// ── sequence ──

func TestSekwencjaWymagaSasiedztwaISesji(t *testing.T) {
	ps := DetectPatterns([]TopicSpan{
		tspan("s1", "a", 1, "praca"),
		tspan("s2", "a", 1, "lęk"),
		tspan("s3", "a", 1, "praca"),
		tspan("s4", "a", 1, "lęk"),
	}, PatternOptions{})
	seq := znajdz(ps, PatternSequence)
	if len(seq) == 0 {
		t.Fatal("sekwencja praca -> lęk nie wykryta")
	}
	if seq[0].Topics[0] != "praca" || seq[0].Topics[1] != "lęk" {
		t.Errorf("kolejnosc tematow = %v", seq[0].Topics)
	}
}

func TestSekwencjaNiePrzekraczaGranicySesji(t *testing.T) {
	// Ostatni span sesji A i pierwszy sesji B nie sasiaduja — dzieli je
	// tydzien.
	ps := DetectPatterns([]TopicSpan{
		tspan("s1", "a", 1, "praca"),
		tspan("s2", "b", 8, "lęk"),
		tspan("s3", "c", 15, "praca"),
		tspan("s4", "d", 22, "lęk"),
	}, PatternOptions{})
	if len(znajdz(ps, PatternSequence)) != 0 {
		t.Error("sekwencja przekroczyla granice sesji")
	}
}

// ── latency ──

func TestCiszaPonizejProguNieJestWzorcem(t *testing.T) {
	a := tspan("s1", "a", 1, "ojciec")
	a.SilenceBeforeMs = 500
	b := tspan("s2", "a", 1, "ojciec")
	b.SilenceBeforeMs = 800
	if len(znajdz(DetectPatterns([]TopicSpan{a, b}, PatternOptions{}), PatternLatency)) != 0 {
		t.Error("krotkie pauzy uznane za wzorzec")
	}
}

func TestPojedynczaPauzaNieJestWzorcem(t *testing.T) {
	// Jedna pauza to pauza, nie wzorzec.
	a := tspan("s1", "a", 1, "ojciec")
	a.SilenceBeforeMs = 4000
	if len(znajdz(DetectPatterns([]TopicSpan{a}, PatternOptions{}), PatternLatency)) != 0 {
		t.Error("pojedyncza pauza uznana za wzorzec")
	}
}

func TestPowtarzalnaCiszaPrzyTemacieJestWzorcem(t *testing.T) {
	a := tspan("s1", "a", 1, "ojciec")
	a.SilenceBeforeMs = 3000
	b := tspan("s2", "b", 8, "ojciec")
	b.SilenceBeforeMs = 5000
	lat := znajdz(DetectPatterns([]TopicSpan{a, b}, PatternOptions{}), PatternLatency)
	if len(lat) != 1 {
		t.Fatalf("wzorcow latency = %d, oczekiwano 1", len(lat))
	}
	if lat[0].Sessions != 2 {
		t.Errorf("sesji = %d, oczekiwano 2", lat[0].Sessions)
	}
}

// ── proweniencja i determinizm ──

func TestKazdyWzorzecMaProweniencjeIMetode(t *testing.T) {
	ps := DetectPatterns([]TopicSpan{
		tspan("s1", "a", 1, "praca", "lęk"),
		tspan("s2", "a", 1, "praca", "lęk"),
		tspan("s3", "b", 8, "praca"),
	}, PatternOptions{})
	if len(ps) == 0 {
		t.Fatal("brak wzorcow")
	}
	for _, p := range ps {
		if len(p.SpanIDs) == 0 {
			t.Errorf("%s: wzorzec bez proweniencji — nie da sie rozlozyc na cytaty", p.ID)
		}
		if p.Method == "" {
			t.Errorf("%s: brak opisu metody — ekspert w benchmarku nie wie, co ocenia", p.ID)
		}
		if p.MethodVersion == "" {
			t.Errorf("%s: brak wersji algorytmu", p.ID)
		}
	}
}

// TestWynikJestDeterministyczny — ten sam material musi dac ten sam
// wynik, inaczej benchmark porownuje szum.
func TestWynikJestDeterministyczny(t *testing.T) {
	in := []TopicSpan{
		tspan("s3", "b", 8, "praca"),
		tspan("s1", "a", 1, "praca", "lęk"),
		tspan("s2", "a", 1, "lęk", "praca"),
	}
	a := DetectPatterns(in, PatternOptions{})
	b := DetectPatterns(in, PatternOptions{})
	if len(a) != len(b) {
		t.Fatalf("rozne liczby wzorcow: %d vs %d", len(a), len(b))
	}
	for i := range a {
		if a[i].ID != b[i].ID {
			t.Errorf("pozycja %d: %s vs %s", i, a[i].ID, b[i].ID)
		}
	}
}

func TestPustyMaterialDajeZeroWzorcow(t *testing.T) {
	if ps := DetectPatterns(nil, PatternOptions{}); len(ps) != 0 {
		t.Errorf("wzorce z pustego materialu: %v", ps)
	}
}
