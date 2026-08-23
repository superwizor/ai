package notificationworker

import (
	"strings"
	"testing"
)

// TestPominiecieMowiDlaczego — cisza po włączeniu przełącznika, który
// obiecuje raport przy KAŻDEJ nowej sesji, jest nierozróżnialna od
// awarii. Tak została odczytana przy pierwszym użyciu na produkcji
// (2026-08-23): sesja dała jeden raport, a właściciel konta uznał, że to
// ten nowy, i pytał, czy ma wgrać nagranie ponownie.
//
// „Nie udało się" byłoby gorsze niż cisza: sugerowałoby awarię, podczas
// gdy obie przyczyny są decyzjami konfiguracji, na które terapeuta może
// zareagować.
func TestPominiecieMowiDlaczego(t *testing.T) {
	for _, tc := range []struct {
		powod, limit string
		musiZawierac []string
	}{
		{"daily_limit", "5", []string{"5", "jutro", "produkcyjny"}},
		{"org_disabled", "0", []string{"organizacji", "administrator"}},
	} {
		title, body := localizeExperimentalSkipped("pl", tc.powod, tc.limit)
		if title == "" {
			t.Fatalf("%s: pusty tytul", tc.powod)
		}
		for _, oczekiwane := range tc.musiZawierac {
			if !strings.Contains(body, oczekiwane) {
				t.Errorf("%s: tresc nie zawiera %q:\n%s", tc.powod, oczekiwane, body)
			}
		}
		// Terapeuta ma wiedziec, ze raport PRODUKCYJNY jest w porzadku —
		// inaczej pominiecie czyta sie jak utrata sesji.
		if tc.powod == "daily_limit" && !strings.Contains(body, "normalnie") {
			t.Errorf("%s: nie uspokaja co do raportu produkcyjnego", tc.powod)
		}
	}
}

func TestPominiecieMaWersjeAngielska(t *testing.T) {
	_, pl := localizeExperimentalSkipped("pl", "daily_limit", "5")
	_, en := localizeExperimentalSkipped("en", "daily_limit", "5")
	if pl == en {
		t.Fatal("wersja angielska identyczna z polska")
	}
	if !strings.Contains(en, "tomorrow") {
		t.Errorf("wersja angielska nie mowi, kiedy wroci: %s", en)
	}
}

// TestNieznanyPowodNieZostawiaPustki — powód spoza listy nadal musi dać
// czytelną wiadomość, bo pusty dokument inbox jest gorszy niż jego brak.
func TestNieznanyPowodNieZostawiaPustki(t *testing.T) {
	title, body := localizeExperimentalSkipped("pl", "cos_nowego", "")
	if title == "" || body == "" {
		t.Fatalf("nieznany powod dal pustke: %q / %q", title, body)
	}
}
