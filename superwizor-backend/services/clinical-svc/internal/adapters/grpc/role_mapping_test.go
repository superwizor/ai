package grpc

import (
	"testing"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

// TestMapowanieRolJestKompletne pilnuje luki, która realnie zablokowała
// użytkownika na produkcji (2026-08-22 → 08-23).
//
// `protoRoleName` zwraca dla nieznanej roli PUSTY napis, a pusta rola
// znaczy dla bramek autoryzacji „brak uwierzytelnienia" — nie „brak
// uprawnień". Rola dodana do proto, ale nie tutaj, zostaje więc odcięta
// od całego serwisu i objawia się w UI jako problem z logowaniem: panel
// Ontology Studio pokazywał „Musisz być zalogowana/y" komuś, kto widział
// własny e-mail w nagłówku.
//
// Test jedzie po WYGENEROWANEJ mapie enumu, nie po ręcznej liście — inaczej
// dzieliłby ślepotę z kodem, który sprawdza.
func TestMapowanieRolJestKompletne(t *testing.T) {
	for wartosc, nazwa := range identityv1.UserRole_name {
		if nazwa == "USER_ROLE_UNSPECIFIED" {
			continue // brak roli to legalny stan, mapuje sie na ""
		}
		if got := protoRoleName(identityv1.UserRole(wartosc)); got == "" {
			t.Errorf("%s nie ma odpowiednika w protoRoleName — ta rola zostanie "+
				"odcieta od serwisu i zobaczy komunikat o niezalogowaniu", nazwa)
		}
	}
}
