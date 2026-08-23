package grpc

import (
	"strings"
	"testing"
)

// TestIsActiveJestOdporneNaNull pilnuje błędu, który wywalał panel
// dokładnie w stanie początkowym (2026-08-23).
//
// `m.active_ontology_version_id = ov.id` daje w SQL NULL, a nie FALSE,
// gdy lewa strona jest NULL-em — czyli dopóki żadna wersja nie została
// aktywowana. Skan takiej kolumny do *bool kończy się błędem, a użytkownik
// widzi „Błąd serwera". Trafia to w jedyną osobę, która może być na tym
// etapie: eksperta zaczynającego pracę nad pierwszą ontologią.
//
// Test czyta SQL, bo atrapa puli nie odtwarza semantyki NULL-i — a to
// właśnie ona była tu problemem, nie kod Go.
func TestIsActiveJestOdporneNaNull(t *testing.T) {
	linia := ""
	for _, l := range strings.Split(ontologyVersionColumns, "\n") {
		if strings.Contains(l, "is_active") {
			linia = l
			break
		}
	}
	if linia == "" {
		t.Fatal("kolumna is_active zniknela z zapytania")
	}
	if !strings.Contains(linia, "COALESCE") &&
		!strings.Contains(linia, "IS NOT DISTINCT FROM") {
		t.Errorf("is_active nie jest odporne na NULL: %s\n\n"+
			"Porownanie z NULL-em daje NULL, wiec kolumna wraca jako NULL, "+
			"dopoki zadna wersja nie jest aktywna — a skan do *bool sie na tym "+
			"wywraca.", strings.TrimSpace(linia))
	}
}
