package ontology

import (
	"fmt"
	"strings"
	"unicode"
)

// catalogReferenceWarnings wykrywa konstrukt BEZ katalogu, ktorego
// definicja przywoluje konstrukt Z katalogiem po jego etykiecie.
//
// Taki konstrukt dostaje w S2 pole tekstowe i instrukcje "opisz zwyklym
// jezykiem", a definicja kaze mu nazwac pozycje z cudzego katalogu —
// ktorego model w tym prompcie nie widzi. Nazwy spoza katalogu przechodza
// wtedy przez wszystkie bramki: R1/R6 sprawdzaja tylko wlasne values, V2
// porownuje tylko z wlasnym slownikiem. Tak powstaly "naruszone
// potencjalnosci" bedace potrzebami w PPT current_conflict (0.1.x,
// kanarek 2026-09-28: 15 z 15 twierdzen).
//
// Ostrzezenie, nie blad: rozstrzyga ekspert (katalog w konstrukcie,
// osobny konstrukt albo kompozyt). Kompozyty pomijamy — przywoluja inne
// katalogi slotami enum_ref, a tam katalog jest egzekwowany.
//
// Tylko label_pl, bez aliasow: aliasy bywaja zwyklymi slowami ("reguła"
// w CBT pada w definicjach w znaczeniu potocznym) i dawaly same falszywe
// ostrzezenia.
func (o *Ontology) catalogReferenceWarnings() []string {
	var w []string
	for _, id := range o.ConstructIDs() {
		c := o.Constructs[id]
		if c == nil || len(c.Values) > 0 || c.Kind == KindComposite || c.Definition == "" {
			continue
		}
		def := refTokens(c.Definition)
		for _, innyID := range o.ConstructIDs() {
			inny := o.Constructs[innyID]
			if innyID == id || inny == nil || len(inny.Values) == 0 {
				continue
			}
			if refPhrasePresent(def, refTokens(inny.LabelPL)) {
				w = append(w, fmt.Sprintf(
					"%s.definition: przywoluje katalog %s (%q), a konstrukt nie ma values — "+
						"S2 dostanie pole tekstowe bez tego katalogu; nadaj katalog, wydziel "+
						"konstrukt albo uzyj kompozytu z enum_ref",
					id, innyID, inny.LabelPL))
			}
		}
	}
	return w
}

var refZnaki = strings.NewReplacer(
	"ą", "a", "ć", "c", "ę", "e", "ł", "l", "ń", "n",
	"ó", "o", "ś", "s", "ź", "z", "ż", "z",
)

func refTokens(s string) []string {
	return strings.FieldsFunc(refZnaki.Replace(strings.ToLower(s)), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r)
	})
}

// refPhrasePresent: fraza jako ciag kolejnych slow; slowo >= 5 znakow
// dopasowane rdzeniem (bez dwoch ostatnich znakow — polska odmiana),
// krotsze w calosci. Ta sama heurystyka co znaczniki w weryfikatorze S5.
func refPhrasePresent(tokens, fraza []string) bool {
	if len(fraza) == 0 || len(fraza) > len(tokens) {
		return false
	}
	for i := 0; i+len(fraza) <= len(tokens); i++ {
		ok := true
		for j, slowo := range fraza {
			r := []rune(slowo)
			t := tokens[i+j]
			if len(r) < 5 {
				ok = t == slowo
			} else {
				ok = strings.HasPrefix(t, string(r[:len(r)-2]))
			}
			if !ok {
				break
			}
		}
		if ok {
			return true
		}
	}
	return false
}
