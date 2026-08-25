package llmworker

import (
	"os"
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
	b := experimentalBanner("CBT", "0.1.0", "pl")
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

// TestZamowienieBezPublikacjiNieZostaje pilnuje kolejności, która
// realnie kosztowała użytkownika raport (2026-08-23).
//
// Wiersz zamówienia powstaje PRZED publikacją, bo komunikat musi nieść
// jego identyfikator. Gdy publikacja padnie — a padła, na braku
// uprawnienia do tematu — zostaje zamówienie, które zużyło limit i nie
// dało raportu. Przy limicie 5 wystarczy pięć takich awarii, żeby tryb
// zamilkł na dobę.
//
// Test czyta źródło, bo alternatywa wymaga Pub/Suba i bazy. Sprawdzana
// jest OBECNOŚĆ wycofania w gałęzi błędu, nie jego wynik.
func TestZamowienieBezPublikacjiNieZostaje(t *testing.T) {
	src, err := os.ReadFile("experimental.go")
	if err != nil {
		t.Fatalf("odczyt experimental.go: %v", err)
	}
	kod := string(src)

	iPublikacja := strings.Index(kod, `logger.Warn("dual-run: publikacja zamowienia"`)
	if iPublikacja < 0 {
		t.Fatal("brak obslugi bledu publikacji")
	}
	iUsun := strings.Index(kod, "DELETE FROM experimental_report_requests")
	if iUsun < 0 {
		t.Fatal("nieudana publikacja nie wycofuje zamowienia — zuzyje limit bez raportu")
	}
	if iUsun < iPublikacja {
		t.Error("wycofanie stoi poza galezia bledu publikacji")
	}
}

// Raport wychodzi w jezyku kartoteki — baner tez (2026-08-24).
func TestBanerEksperymentuPoAngielsku(t *testing.T) {
	b := experimentalBanner("CBT", "0.1.0", "en-US")
	for _, oczekiwane := range []string{"EXPERIMENT", "Not for clinical use", "0.1.0", "CBT"} {
		if !strings.Contains(b, oczekiwane) {
			t.Fatalf("baner EN bez %q: %s", oczekiwane, b)
		}
	}
	if strings.Contains(b, "EKSPERYMENT") {
		t.Fatalf("baner EN zawiera polski wariant: %s", b)
	}
}
