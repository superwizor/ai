package ontology

// Parser typow slotow (nota E5 / ticket T37).
//
// Gramatyka jest wlasnoscia TEGO pliku: walidator, przyszly runtime
// kompozytow i metaschemat maja czytac typ slotu wylacznie przez
// ParseSlotType. Drugi parser (albo regex obok) to gwarantowany rozjazd
// w dniu, w ktorym gramatyka sie poszerzy.

import (
	"fmt"
	"regexp"
	"strings"
)

// SlotAtom to jeden czlon unii typu slotu.
type SlotAtom struct {
	// Kind: "span_ref" | "entry_ref" | "construct_ref" | "enum_ref".
	Kind string
	// Refs to cele referencji (>=1 dla construct_ref/enum_ref; puste
	// dla span_ref/entry_ref).
	Refs []string
}

var slotIDRe = regexp.MustCompile(`^[a-z][a-z0-9_]*$`)

// ParseSlotType rozklada typ slotu na atomy unii.
//
// Rozdzielanie po `|` odbywa sie WYLACZNIE poza nawiasami — wewnatrz
// nawiasu `|` rozdziela cele referencji: `construct_ref(a|b)` to jeden
// atom o dwoch celach, `span_ref|entry_ref` to dwa atomy.
func ParseSlotType(t string) ([]SlotAtom, error) {
	t = strings.TrimSpace(t)
	if t == "" {
		return nil, fmt.Errorf("pusty typ slotu")
	}
	var czlony []string
	glebokosc, start := 0, 0
	for i, r := range t {
		switch r {
		case '(':
			glebokosc++
		case ')':
			glebokosc--
			if glebokosc < 0 {
				return nil, fmt.Errorf("niesparowany nawias w %q", t)
			}
		case '|':
			if glebokosc == 0 {
				czlony = append(czlony, t[start:i])
				start = i + 1
			}
		}
	}
	if glebokosc != 0 {
		return nil, fmt.Errorf("niesparowany nawias w %q", t)
	}
	czlony = append(czlony, t[start:])

	var out []SlotAtom
	for _, cz := range czlony {
		cz = strings.TrimSpace(cz)
		switch {
		case cz == "span_ref" || cz == "entry_ref":
			out = append(out, SlotAtom{Kind: cz})
		case strings.HasPrefix(cz, "construct_ref(") || strings.HasPrefix(cz, "enum_ref("):
			if !strings.HasSuffix(cz, ")") {
				return nil, fmt.Errorf("atom %q bez zamkniecia nawiasu", cz)
			}
			kind := cz[:strings.Index(cz, "(")]
			srodek := cz[len(kind)+1 : len(cz)-1]
			var refs []string
			for _, ref := range strings.Split(srodek, "|") {
				ref = strings.TrimSpace(ref)
				if !slotIDRe.MatchString(ref) {
					return nil, fmt.Errorf("atom %q: cel %q nie jest identyfikatorem konstruktu", cz, ref)
				}
				refs = append(refs, ref)
			}
			out = append(out, SlotAtom{Kind: kind, Refs: refs})
		default:
			return nil, fmt.Errorf("nieznany atom typu slotu %q (span_ref|entry_ref|construct_ref(id)|enum_ref(id))", cz)
		}
	}
	return out, nil
}
