package llmworker

import (
	"testing"

	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/ontopipe"
)

// TestBudzetMysleniaPerModel: Flash dopuszcza zero, Pro nie — ustawienie
// zera dla Pro odrzuca CAŁE żądanie (zaobserwowane na produkcji
// 2026-08-23, S2 padło na wszystkich konstruktach).
func TestBudzetMysleniaPerModel(t *testing.T) {
	if got := thinkingBudgetFor(ontopipe.ModelExtraction); got != 0 {
		t.Errorf("Flash: budzet = %d, oczekiwano 0 (tokeny myslenia zjadaja MaxOutputTokens)", got)
	}
	for _, m := range []string{ontopipe.ModelMapping, ontopipe.ModelSynthesis} {
		if got := thinkingBudgetFor(m); got == 0 {
			t.Errorf("Pro (%s): budzet = 0, a model tego nie dopuszcza", m)
		}
	}
}

// TestLustroModeluFlashSieNieRozjezdza — dobór budżetu opiera się na
// osobnej stałej, więc zmiana modelu w ontopipe bez zmiany tutaj cicho
// wyłączyłaby optymalizację.
func TestLustroModeluFlashSieNieRozjezdza(t *testing.T) {
	if ModelExtractionFlash != ontopipe.ModelExtraction {
		t.Fatalf("lustro rozjechalo sie: %q vs %q — Flash dostanie budzet Pro",
			ModelExtractionFlash, ontopipe.ModelExtraction)
	}
}
