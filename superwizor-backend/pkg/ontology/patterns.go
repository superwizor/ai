package ontology

import (
	"fmt"
	"sort"
	"strings"
)

// S1.5 — dowody wzorcowe (dok. 11 sekcja 4; specyfikacja: dok. 13 §3).
//
// DETERMINISTYCZNE, ZERO LLM. To jest sedno: meta-obserwacja "trzeci raz
// powtarza sie ten temat" jest albo POLICZONA, albo zmyslona. Policzona
// staje sie legalnym dowodem, ktory hipoteza moze cytowac na rowni ze
// spanem; zmyslona jest dokladnie ta klasa bledu, ktora ta architektura
// likwiduje.
//
// ZASADA GLEBI (dok. 11 v1.2): glebia wewnatrz szyn, nie zamiast szyn.
// Wzorce nie tworza nowych bytow — operuja wylacznie na spanach, ktore
// przeszly weryfikacje mechaniczna S1.
//
// WZORZEC NIGDY NIE JEST TEZA. Renderowanie "widac wzorzec unikania" na
// podstawie samego zliczenia bylo by interpretacja przebrana za pomiar.
// Wzorzec moze wystapic w raporcie WYLACZNIE jako dowod pod
// twierdzeniem, ktore przeszlo S2 i S3.

// PatternType to rodzaj wzorca.
type PatternType string

const (
	// PatternRecurrence: ten sam temat wraca w N spanach.
	PatternRecurrence PatternType = "recurrence"
	// PatternCoOccurrence: dwa tematy wystepuja razem.
	PatternCoOccurrence PatternType = "co_occurrence"
	// PatternSequence: temat A poprzedza temat B, powtarzalnie.
	PatternSequence PatternType = "sequence"
	// PatternLatency: pauzy przed tematem lub po nim (v1.4, dok. 15 §2.2-d).
	PatternLatency PatternType = "latency"
)

// MethodVersion stempluje wzorzec wersja algorytmu.
//
// Bez tego nie da sie odtworzyc, dlaczego raport sprzed miesiaca widzial
// wzorzec, ktorego dzisiejszy nie widzi. Zmiana progow to zmiana tej
// wartosci.
const MethodVersion = "s1.5/1.0.0"

// Pattern to policzony wzorzec — DOWOD, nie twierdzenie.
type Pattern struct {
	ID     string
	Type   PatternType
	Topics []string
	// SpanIDs to pelna proweniencja do spanow bazowych. Kazdy wzorzec
	// musi dac sie rozlozyc z powrotem na cytaty.
	SpanIDs []string
	// Method opisuje, jak wzorzec policzono — czytelne dla czlowieka,
	// zeby ekspert w benchmarku wiedzial, co ocenia.
	Method        string
	MethodVersion string
	// Sessions to liczba roznych sesji objetych wzorcem. Wzorzec w
	// jednej sesji i wzorzec w pieciu to nie to samo zjawisko.
	Sessions int
}

// TopicSpan to span z przypisanymi tematami. Tematy pochodza z S1
// (pole topics[]), nie z tego etapu — S1.5 liczy, nie interpretuje.
type TopicSpan struct {
	Span
	Topics []string
	// SilenceBeforeMs to dlugosc ciszy przed spanem, ze znacznikow
	// chunkera 600 ms. Zero = brak znacznika (nie: brak ciszy).
	SilenceBeforeMs int
}

// PatternOptions steruje progami.
//
// Progi sa KONSERWATYWNE celowo. Falszywy wzorzec jest grozniejszy niz
// przeoczony: przeoczony zostawia raport ubozszym, falszywy daje
// terapeucie liczbe, ktorej nie ma w materiale, a liczba przekonuje
// mocniej niz proza.
type PatternOptions struct {
	// MinRecurrence to minimalna liczba spanow, by uznac powtarzalnosc.
	// 0 = domyslne 3. Dwa wystapienia to zbieg, nie wzorzec.
	MinRecurrence int
	// MinCoOccurrence to minimalna liczba wspolnych wystapien. 0 = 2.
	MinCoOccurrence int
	// MinSequence to minimalna liczba powtorzen kolejnosci. 0 = 2.
	MinSequence int
	// LatencyThresholdMs to prog ciszy uznawanej za znaczaca. 0 = 2000.
	LatencyThresholdMs int
	// MinLatencyCases to liczba przypadkow ciszy przy tym samym temacie.
	// 0 = 2 — pojedyncza pauza nie jest wzorcem, tylko pauza.
	MinLatencyCases int
}

func (o PatternOptions) withDefaults() PatternOptions {
	if o.MinRecurrence == 0 {
		o.MinRecurrence = 3
	}
	if o.MinCoOccurrence == 0 {
		o.MinCoOccurrence = 2
	}
	if o.MinSequence == 0 {
		o.MinSequence = 2
	}
	if o.LatencyThresholdMs == 0 {
		o.LatencyThresholdMs = 2000
	}
	if o.MinLatencyCases == 0 {
		o.MinLatencyCases = 2
	}
	return o
}

// DetectPatterns liczy wzorce na zweryfikowanych spanach.
//
// SPANY RYZYKA SA ODSIEWANE NA WEJSCIU (T22, dok. 14 §7). Nie tylko z
// wnioskowania, ale i ze STATYSTYK: "temat X wraca trzeci raz" policzone
// na wypowiedziach o mysli samobojczej bylo by miekka ocena ryzyka, a ta
// jest klasa IIb i pozostaje poza zakresem produktu.
func DetectPatterns(spans []TopicSpan, opts PatternOptions) []Pattern {
	opts = opts.withDefaults()

	clean := make([]TopicSpan, 0, len(spans))
	for _, s := range spans {
		if s.RiskContent {
			continue
		}
		clean = append(clean, s)
	}
	// Kolejnosc chronologiczna jest warunkiem sensownosci sekwencji.
	sort.SliceStable(clean, func(i, j int) bool {
		if !clean[i].SessionAt.Equal(clean[j].SessionAt) {
			return clean[i].SessionAt.Before(clean[j].SessionAt)
		}
		return clean[i].ID < clean[j].ID
	})

	var out []Pattern
	out = append(out, detectRecurrence(clean, opts)...)
	out = append(out, detectCoOccurrence(clean, opts)...)
	out = append(out, detectSequence(clean, opts)...)
	out = append(out, detectLatency(clean, opts)...)
	sort.SliceStable(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}

func detectRecurrence(spans []TopicSpan, opts PatternOptions) []Pattern {
	byTopic := map[string][]TopicSpan{}
	for _, s := range spans {
		for _, t := range s.Topics {
			byTopic[t] = append(byTopic[t], s)
		}
	}
	var out []Pattern
	for _, topic := range sortedKeys(byTopic) {
		group := byTopic[topic]
		if len(group) < opts.MinRecurrence {
			continue
		}
		out = append(out, Pattern{
			ID:      fmt.Sprintf("pat-recurrence-%s", slug(topic)),
			Type:    PatternRecurrence,
			Topics:  []string{topic},
			SpanIDs: spanIDsOf(group),
			Method: fmt.Sprintf("temat wystapil w %d spanach (prog %d)",
				len(group), opts.MinRecurrence),
			MethodVersion: MethodVersion,
			Sessions:      countSessions(group),
		})
	}
	return out
}

func detectCoOccurrence(spans []TopicSpan, opts PatternOptions) []Pattern {
	// Para tematow liczona w obrebie JEDNEGO spanu: wspolwystepowanie w
	// tej samej wypowiedzi jest obserwowalne, a "w tej samej sesji" juz
	// nie — sesja trwa godzine i laczy wszystko ze wszystkim.
	type para struct{ a, b string }
	byPair := map[para][]TopicSpan{}
	for _, s := range spans {
		ts := append([]string(nil), s.Topics...)
		sort.Strings(ts)
		for i := 0; i < len(ts); i++ {
			for j := i + 1; j < len(ts); j++ {
				p := para{ts[i], ts[j]}
				byPair[p] = append(byPair[p], s)
			}
		}
	}
	var out []Pattern
	keys := make([]para, 0, len(byPair))
	for k := range byPair {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool {
		if keys[i].a != keys[j].a {
			return keys[i].a < keys[j].a
		}
		return keys[i].b < keys[j].b
	})
	for _, k := range keys {
		group := byPair[k]
		if len(group) < opts.MinCoOccurrence {
			continue
		}
		out = append(out, Pattern{
			ID:      fmt.Sprintf("pat-cooc-%s-%s", slug(k.a), slug(k.b)),
			Type:    PatternCoOccurrence,
			Topics:  []string{k.a, k.b},
			SpanIDs: spanIDsOf(group),
			Method: fmt.Sprintf("tematy wystapily razem w %d spanach (prog %d)",
				len(group), opts.MinCoOccurrence),
			MethodVersion: MethodVersion,
			Sessions:      countSessions(group),
		})
	}
	return out
}

func detectSequence(spans []TopicSpan, opts PatternOptions) []Pattern {
	// Sekwencja: temat A w spanie, temat B w NASTEPNYM spanie tej samej
	// sesji. Sasiedztwo, nie dowolny dystans — "kiedys pozniej" nie jest
	// sekwencja, tylko wspolwystepowaniem w czasie.
	type para struct{ a, b string }
	counts := map[para][]TopicSpan{}
	for i := 0; i+1 < len(spans); i++ {
		cur, next := spans[i], spans[i+1]
		if cur.SessionID != next.SessionID {
			continue
		}
		for _, a := range cur.Topics {
			for _, b := range next.Topics {
				if a == b {
					continue // powtorzenie tematu to recurrence, nie sekwencja
				}
				p := para{a, b}
				counts[p] = append(counts[p], cur, next)
			}
		}
	}
	var out []Pattern
	keys := make([]para, 0, len(counts))
	for k := range counts {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool {
		if keys[i].a != keys[j].a {
			return keys[i].a < keys[j].a
		}
		return keys[i].b < keys[j].b
	})
	for _, k := range keys {
		group := counts[k]
		// Kazde wystapienie wnosi 2 spany, wiec liczba powtorzen to
		// polowa dlugosci grupy.
		repeats := len(group) / 2
		if repeats < opts.MinSequence {
			continue
		}
		out = append(out, Pattern{
			ID:      fmt.Sprintf("pat-seq-%s-%s", slug(k.a), slug(k.b)),
			Type:    PatternSequence,
			Topics:  []string{k.a, k.b},
			SpanIDs: spanIDsOf(group),
			Method: fmt.Sprintf("temat %q poprzedzal %q w %d przypadkach (prog %d)",
				k.a, k.b, repeats, opts.MinSequence),
			MethodVersion: MethodVersion,
			Sessions:      countSessions(group),
		})
	}
	return out
}

func detectLatency(spans []TopicSpan, opts PatternOptions) []Pattern {
	// Cisza przed tematem, ze znacznikow istniejacego chunkera 600 ms —
	// zero nowej infrastruktury (dok. 15 §2.2-d).
	byTopic := map[string][]TopicSpan{}
	for _, s := range spans {
		if s.SilenceBeforeMs < opts.LatencyThresholdMs {
			continue
		}
		for _, t := range s.Topics {
			byTopic[t] = append(byTopic[t], s)
		}
	}
	var out []Pattern
	for _, topic := range sortedKeys(byTopic) {
		group := byTopic[topic]
		if len(group) < opts.MinLatencyCases {
			continue
		}
		out = append(out, Pattern{
			ID:      fmt.Sprintf("pat-latency-%s", slug(topic)),
			Type:    PatternLatency,
			Topics:  []string{topic},
			SpanIDs: spanIDsOf(group),
			Method: fmt.Sprintf("pauza >= %d ms przed tematem w %d przypadkach (prog %d)",
				opts.LatencyThresholdMs, len(group), opts.MinLatencyCases),
			MethodVersion: MethodVersion,
			Sessions:      countSessions(group),
		})
	}
	return out
}

func spanIDsOf(spans []TopicSpan) []string {
	seen := map[string]bool{}
	var out []string
	for _, s := range spans {
		if seen[s.ID] {
			continue
		}
		seen[s.ID] = true
		out = append(out, s.ID)
	}
	sort.Strings(out)
	return out
}

func countSessions(spans []TopicSpan) int {
	seen := map[string]bool{}
	for _, s := range spans {
		seen[s.SessionID] = true
	}
	return len(seen)
}

func sortedKeys[V any](m map[string]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

// slug tworzy stabilny identyfikator wzorca z tematu.
//
// Stabilny, bo identyfikator wzorca trafia do proweniencji twierdzenia:
// zmiana sposobu generowania zerwalaby odnosniki w juz zapisanych
// raportach.
func slug(s string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(s) {
		switch {
		case r >= 'a' && r <= 'z', r >= '0' && r <= '9':
			b.WriteRune(r)
		default:
			b.WriteByte('_')
		}
	}
	return strings.Trim(b.String(), "_")
}
