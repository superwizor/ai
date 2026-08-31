package ontopipe

// Snapshoty promptu S2 dla glos (plan value_glosses, sekcja 6.3).
//
// Golden-file, nie asercje na podlancuchach: format promptu JEST
// kontraktem (separator, naglowek, dopisek), a zmiana kontraktu ma byc
// widoczna w diffie PR jako zmiana pliku golden — czyli decyzja, nie
// przypadek. Regeneracja: AKTUALIZUJ_SNAPSHOTY=1 go test -run TestSnapshotPromptS2.

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

func ontologiaTestowa(glosses map[string]string, values []string) *ontology.Ontology {
	return &ontology.Ontology{
		Modality: "ppt", Version: "0.0.1",
		Constructs: map[string]*ontology.Construct{
			"kat": {LabelPL: "Potencjalnosc testowa", Kind: ontology.KindCategory,
				Definition: "Definicja testowa.", Values: values, ValueGlosses: glosses},
		},
	}
}

func TestSnapshotPromptS2(t *testing.T) {
	przypadki := []struct {
		nazwa   string
		values  []string
		glosses map[string]string
	}{
		{"bez_glos", []string{"miłość", "zaufanie"}, nil},
		{"z_glosami", []string{"miłość", "jedność"},
			map[string]string{"jedność": "integrowanie"}},
		{"z_para_podlancuchowa", []string{"miłość", "pewność siebie", "pewność"},
			map[string]string{
				"pewność":        "decyzyjność (zdolność podejmowania decyzji)",
				"pewność siebie": "ufność we własne siły",
			}},
	}
	for _, tc := range przypadki {
		t.Run(tc.nazwa, func(t *testing.T) {
			o := ontologiaTestowa(tc.glosses, tc.values)
			prompt := buildS2Prompt(o, "kat", nil)
			// Snapshot obejmuje wylacznie blok kategorii: baza promptu
			// (promptS2Base) ma wlasny cykl wersjonowania i zmienia sie
			// czesciej, niz format glos — pelny snapshot wywracalby sie
			// przy kazdej zmianie tresci bazowej, uczac wszystkich
			// zatwierdzania diffow bez czytania.
			idx := strings.Index(prompt, "KATEGORIE")
			if idx < 0 {
				t.Fatalf("prompt bez bloku KATEGORIE:\n%s", prompt)
			}
			blok := prompt[idx:]
			if koniec := strings.Index(blok, "\n\n"); koniec > 0 {
				blok = blok[:koniec+1]
			}
			sciezka := filepath.Join("testdata", "prompty", "s2_"+tc.nazwa+".golden")
			if os.Getenv("AKTUALIZUJ_SNAPSHOTY") == "1" {
				if err := os.WriteFile(sciezka, []byte(blok), 0o644); err != nil {
					t.Fatal(err)
				}
			}
			chcemy, err := os.ReadFile(sciezka)
			if err != nil {
				t.Fatalf("brak golden (uruchom z AKTUALIZUJ_SNAPSHOTY=1): %v", err)
			}
			if string(chcemy) != blok {
				t.Fatalf("snapshot rozjechany.\n== GOLDEN ==\n%s\n== TERAZ ==\n%s", chcemy, blok)
			}
		})
	}
}

// TestSnapshotHomonimMiedzykonstruktowy — dopisek "(tu: <etykieta>)"
// (nota E7): wartosc obecna w katalogach dwoch konstruktow renderuje sie
// z jawnym wskazaniem, o ktory konstrukt chodzi — po OBU stronach.
func TestSnapshotHomonimMiedzykonstruktowy(t *testing.T) {
	o := &ontology.Ontology{
		Modality: "ppt", Version: "0.0.1",
		Constructs: map[string]*ontology.Construct{
			"sfera": {LabelPL: "Sfera zycia", Kind: ontology.KindCategory,
				Values:       []string{"kontakt", "cialo"},
				ValueGlosses: map[string]string{"kontakt": "sfera relacji i wiezi"}},
			"potenc": {LabelPL: "Potencjalnosc pierwotna", Kind: ontology.KindCategory,
				Values:       []string{"kontakt", "milosc"},
				ValueGlosses: map[string]string{"kontakt": "zdolnosc nawiazywania wiezi"}},
		},
	}
	prompt := buildS2Prompt(o, "sfera", nil)
	if !strings.Contains(prompt, "- kontakt (tu: Sfera zycia) — sfera relacji i wiezi") {
		t.Fatalf("brak dopisku homonimu w prompcie sfery:\n%s", prompt)
	}
	prompt2 := buildS2Prompt(o, "potenc", nil)
	if !strings.Contains(prompt2, "- kontakt (tu: Potencjalnosc pierwotna) — zdolnosc nawiazywania wiezi") {
		t.Fatalf("brak dopisku homonimu w prompcie potencjalnosci:\n%s", prompt2)
	}
	// Wartosc bez homonimu — bez dopisku.
	if strings.Contains(prompt, "cialo (tu:") {
		t.Fatalf("dopisek na wartosci bez homonimu:\n%s", prompt)
	}
}

// TestPromptBezGlosNieZmieniony: konstrukt bez glos renderuje sie
// IDENTYCZNIE jak przed wprowadzeniem pola — bez naglowka o myslniku,
// bez dopiskow. To jest obietnica z planu ("nie zasmiecamy promptow
// konstruktow bez glos") wyrazona jako asercja.
func TestPromptBezGlosNieZmieniony(t *testing.T) {
	o := ontologiaTestowa(nil, []string{"pewność", "pewność siebie"})
	prompt := buildS2Prompt(o, "kat", nil)
	idx := strings.Index(prompt, "KATEGORIE")
	if idx < 0 {
		t.Fatalf("prompt bez bloku KATEGORIE:\n%s", prompt)
	}
	blok := prompt[idx:]
	if koniec := strings.Index(blok, "\n\n"); koniec > 0 {
		blok = blok[:koniec+1]
	}
	// Asercja celowo na BLOKU kategorii, nie calym prompcie: naglowek
	// "KONSTRUKT: id — etykieta" uzywa tego samego separatora od zawsze.
	for _, zakazane := range []string{"myslnika", "NIE mylic z", " — "} {
		if strings.Contains(blok, zakazane) {
			t.Fatalf("blok kategorii konstruktu bez glos zawiera %q:\n%s", zakazane, blok)
		}
	}
}
