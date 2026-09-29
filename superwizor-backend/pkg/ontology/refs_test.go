package ontology

import (
	"strings"
	"testing"
)

// Konstrukt bez katalogu, ktorego definicja kaze nazwac pozycje z
// katalogu INNEGO konstruktu, dostaje w S2 pole tekstowe i instrukcje
// "opisz zwyklym jezykiem" — nazwy spoza katalogu przechodza wtedy przez
// wszystkie bramki (PPT current_conflict, 0.1.x).
func TestOstrzezenieDefinicjaPrzywolujeCudzyKatalog(t *testing.T) {
	const tresc = `
modality: test
version: 0.1.0
constructs:
  konflikt:
    label_pl: "Konflikt"
    definition: "Sytuacja napiecia. Notacja: sytuacja + naruszone potencjalności wtórne."
  wlasny:
    label_pl: "Wlasny"
    definition: "Wskaz potencjalność wtórną, ktora dotyczy sytuacji."
    values: ["x", "y"]
  kompozyt:
    label_pl: "Kompozyt"
    kind: composite
    definition: "Potencjalność wtórna + stan + dowod."
    slots:
      capacity: {type: "enum_ref(wtorna)", required: true}
    min_complete_slots: 1
  wtorna:
    label_pl: "Potencjalność wtórna"
    aliases: ["reguła"]
    values: ["punktualność", "porządek"]
  opis:
    label_pl: "Opis"
    definition: "Wolny opis; zgodnie z regułą 2 promptu cytat dosłowny."
`
	o, err := Parse([]byte(tresc))
	if err != nil {
		t.Fatal(err)
	}
	var trafienia []string
	for _, w := range o.Warnings() {
		if strings.Contains(w, "katalog") && strings.Contains(w, "wtorna") {
			trafienia = append(trafienia, w)
		}
	}
	if len(trafienia) != 1 || !strings.HasPrefix(trafienia[0], "konflikt.definition") {
		t.Fatalf("oczekiwano jednego ostrzezenia dla konflikt.definition, jest: %q", trafienia)
	}
}
