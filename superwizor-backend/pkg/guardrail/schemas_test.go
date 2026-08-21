package guardrail

import "testing"

// TestHypothesesCapMatchesEpistemicRule pilnuje, ze limit hipotez nie
// zejdzie ponizej dwoch. Soczewki wymagaja DWOCH konkurencyjnych
// hipotez ("Hipoteza A / Hipoteza B, dane za, dane przeciw"); schemat,
// ktory dopuszcza tylko jedna, czyni te zasade niewykonalna — model nie
// moglby jej spelnic, nawet gdyby chcial.
func TestHypothesesCapMatchesEpistemicRule(t *testing.T) {
	for _, in := range []Intent{A8Concept, A9Progress, A10Intervention} {
		s, ok := SchemaFor(in)
		if !ok {
			t.Fatalf("%s: brak schematu", in)
		}
		props, _ := s["properties"].(map[string]any)
		h, hasH := props["hypotheses"].(map[string]any)
		if !hasH {
			t.Fatalf("%s: brak pola hypotheses", in)
		}
		maxItems, _ := h["maxItems"].(int64)
		if maxItems < 2 {
			t.Errorf("%s: maxItems=%d — soczewki wymagaja dwoch konkurencyjnych hipotez",
				in, maxItems)
		}
		minItems, _ := h["minItems"].(int64)
		if minItems < 1 {
			t.Errorf("%s: minItems=%d — odpowiedz bez hipotezy nie ma czego uziemiac", in, minItems)
		}
	}
}

// TestQuoteCapUntouchedByOutputTrimming to straznik intencji: zacisk
// wyjscia miał NIE dotykac cytatow. Zmierzone osobno 21.08 — caly zysk
// pochodzil z hipotez, wiec obcinanie uziemienia byloby kosztem bez
// korzysci, a grounding_quote_count jest monitorowana metryka (ADR 8.3).
func TestQuoteCapUntouchedByOutputTrimming(t *testing.T) {
	s, ok := SchemaFor(A8Concept)
	if !ok {
		t.Fatal("brak schematu A8Concept")
	}
	props, _ := s["properties"].(map[string]any)
	h, _ := props["hypotheses"].(map[string]any)
	items, _ := h["items"].(map[string]any)
	hp, _ := items["properties"].(map[string]any)
	q, hasQ := hp["quotes"].(map[string]any)
	if !hasQ {
		t.Fatal("brak pola quotes w hipotezie")
	}
	if got, _ := q["maxItems"].(int64); got != 3 {
		t.Errorf("quotes maxItems = %d, oczekiwano 3 (uziemienie nie jest miejscem na oszczednosci)", got)
	}
	if got, _ := q["minItems"].(int64); got != 1 {
		t.Errorf("quotes minItems = %d, oczekiwano 1 (wymog uziemienia)", got)
	}
}
