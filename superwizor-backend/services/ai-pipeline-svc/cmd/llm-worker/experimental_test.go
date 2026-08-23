package llmworker

import (
	"strings"
	"testing"
)

// TestRozpoznanieEksperymentuPoJednymAtrybucie: czesciowo wypelniony
// komunikat NIE MOZE wpasc w tryb eksperymentalny. Rozpoznanie po sumie
// atrybutow ("jest modality_override, wiec pewnie eksperyment") tworzy
// sciezke, w ktorej literowka w producencie omija bramke aktywnej wersji.
func TestRozpoznanieEksperymentuPoJednymAtrybucie(t *testing.T) {
	if experimentalFromAttributes(nil) != nil {
		t.Error("brak atrybutow rozpoznany jako eksperyment")
	}
	if experimentalFromAttributes(map[string]string{"modality_override": "CBT"}) != nil {
		t.Error("sam modality_override rozpoznany jako eksperyment")
	}
	if experimentalFromAttributes(map[string]string{"pipeline": "ontology"}) != nil {
		t.Error("pipeline=ontology rozpoznany jako eksperyment")
	}
	got := experimentalFromAttributes(map[string]string{"pipeline": "experimental"})
	if got == nil {
		t.Fatal("pipeline=experimental nie rozpoznany")
	}
}

func TestKodModalnosciNormalizowany(t *testing.T) {
	got := experimentalFromAttributes(map[string]string{
		"pipeline": "experimental", "modality_override": " cbt ",
	})
	if got.ModalityOverride != "CBT" {
		t.Fatalf("kod modalnosci = %q, oczekiwano CBT", got.ModalityOverride)
	}
}

// TestBanerNiesieWersjeIZakaz: baner jest częścią artefaktu, więc musi
// nieść wszystko, co czytelnik zobaczy poza aplikacją — na czym powstał
// i że nie służy do pracy klinicznej.
func TestBanerNiesieWersjeIZakaz(t *testing.T) {
	b := experimentalBanner("CBT", "0.1.0")
	for _, oczekiwane := range []string{"EKSPERYMENT", "0.1.0", "CBT",
		"Nie służy do pracy klinicznej", "art. 50"} {
		if !strings.Contains(b, oczekiwane) {
			t.Errorf("baner nie zawiera %q:\n%s", oczekiwane, b)
		}
	}
}

// TestRaportEksperymentalnyMaOsobnyStempel: filtr statystyk idzie po
// pipeline_version, więc wartość musi być rozróżnialna od produkcyjnej.
func TestRaportEksperymentalnyMaOsobnyStempel(t *testing.T) {
	if PipelineExperimental == "ontology_s1s5" || PipelineExperimental == "legacy" {
		t.Fatal("stempel eksperymentu nierozroznialny od produkcyjnego")
	}
	if !strings.HasPrefix(PipelineExperimental, "ontology_s1s5") {
		t.Fatal("stempel eksperymentu nie mowi, ze to potok ontologiczny")
	}
}
