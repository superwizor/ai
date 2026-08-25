package llmworker

import (
	"os"
	"strings"
	"testing"
)

// Semantyka na powierzchni eksperymentalnej ma byc WLACZONA SAMA.
//
// Organizacja z raportami eksperymentalnymi zgodzila sie juz ogladac
// wyniki niezautoryzowanego wnioskowania — dolozenie tam
// niedeterministycznej selekcji nie zmienia charakteru tej zgody.
// Raport PRODUKCYJNY zostaje przy jawnej fladze, bo to material
// kliniczny.
//
// Test czyta zrodlo: uruchomienie tej sciezki wymaga bazy, Vertexa
// i konfiguracji, a sprawdzana jest STRUKTURA decyzji, nie jej wynik.
func TestSemantykaDomyslnaNaPowierzchniEksperymentalnej(t *testing.T) {
	src, err := os.ReadFile("semantic_context.go")
	if err != nil {
		t.Fatalf("odczyt: %v", err)
	}
	kod := string(src)

	i := strings.Index(kod, "func semantykaWlaczona(")
	if i < 0 {
		t.Fatal("brak funkcji rozstrzygajacej o wlaczeniu semantyki")
	}
	cialo := kod[i:]
	if j := strings.Index(cialo[1:], "\nfunc "); j > 0 {
		cialo = cialo[:j]
	}

	// Jawna flaga dziala zawsze.
	if !strings.Contains(cialo, "SemanticContextEnabled(ctx, org)") {
		t.Error("jawna flaga organizacji nie jest sprawdzana")
	}
	// Domyslka WYLACZNIE dla przebiegu eksperymentalnego — bez tego
	// warunku organizacja z eksperymentami dostalaby semantyke takze
	// w raportach klinicznych.
	if !strings.Contains(cialo, "eksperymentalny &&") {
		t.Error("domyslka nie jest ograniczona do przebiegu eksperymentalnego — " +
			"raport produkcyjny dostalby niedeterministyczna selekcje bez decyzji czlowieka")
	}
	if !strings.Contains(cialo, "ExperimentalReportsEnabled(ctx, org)") {
		t.Error("domyslka nie wynika z flagi raportow eksperymentalnych")
	}
}

// Obie galezie przekazuja swoja klase przebiegu — inaczej domyslka
// zadzialalaby po zlej stronie granicy.
func TestKlasaPrzebieguDociera(t *testing.T) {
	src, err := os.ReadFile("main.go")
	if err != nil {
		t.Fatalf("odczyt: %v", err)
	}
	kod := string(src)
	if !strings.Contains(kod, "PipelineExperimental, true)") {
		t.Error("galaz eksperymentalna nie oznacza sie jako eksperymentalna")
	}
	if !strings.Contains(kod, "appconfig.PipelineOntology, false)") {
		t.Error("galaz produkcyjna nie oznacza sie jako produkcyjna")
	}
}
