package ontology

import (
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"testing"
)

// Etykieta wersji nie identyfikuje tresci — szkic nadpisany w miejscu
// zostaje "0.1.1". Skrot musi sie zmienic przy KAZDEJ zmianie tresci,
// takze takiej, ktora nie rusza etykiety (tu: prog min_evidence).
func TestSkrotTresciOdrozniaEdycjeTejSamejWersji(t *testing.T) {
	const tresc = `
modality: test
version: 0.1.1
constructs:
  k:
    label_pl: "K"
    values: ["a", "b"]
    min_evidence: {spans: 2}
`
	a, err := Parse([]byte(tresc))
	if err != nil {
		t.Fatal(err)
	}
	b, err := Parse([]byte(strings.Replace(tresc, "spans: 2", "spans: 1", 1)))
	if err != nil {
		t.Fatal(err)
	}
	if a.Version != b.Version {
		t.Fatalf("test zaklada te sama etykiete wersji: %q vs %q", a.Version, b.Version)
	}
	if a.ContentSHA256 == b.ContentSHA256 {
		t.Fatal("dwie rozne tresci wersji 0.1.1 dostaly ten sam skrot")
	}
	// Ten sam algorytm co trigger audytu w bazie (sha256 bajtow UTF-8).
	suma := sha256.Sum256([]byte(tresc))
	if a.ContentSHA256 != hex.EncodeToString(suma[:]) {
		t.Fatalf("skrot %q nie jest sha256 bajtow tresci", a.ContentSHA256)
	}
}
