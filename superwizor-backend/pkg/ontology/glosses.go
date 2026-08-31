package ontology

// Glosy wartosci katalogu (plan value_glosses v1.0).
//
// ══ Zasada niezmiennicza ══
//
// Wartosc enumu jest IDENTYFIKATOREM, glosa jest OBJASNIENIEM.
// Identyfikator przechodzi przez JSON Schema, R1, telemetrie, benchmark
// i UI — i nigdy nie zawiera tresci objasniajacej. Glosa odpowiada na
// pytanie "ktora to pozycja?", nie "co o niej wiadomo" — pelna
// definicja kanoniczna mieszka w L1, nie tutaj.
//
// Reguly G1-G6 (klasa ERROR poza G5, ktore jest ostrzezeniem):
//   G1  klucz glosy musi istniec w values (dopasowanie doslowne)
//   G2  glosy przy values pustym/null sa niedozwolone
//   G3  glosa: niepusta, <= 120 znakow, bez nowej linii i formatowania
//   G4  glosa nie moze byc identyczna z kluczem ani z inna wartoscia
//   G5  klucz glosy nie moze byc aliasem INNEGO konstruktu (ostrzezenie)
//   G6  para wartosci w relacji podlancucha musi miec glosy OBU stron
//
// G6 istnieje dla dokladnie jednego rodzaju wypadku: "pewnosc" obok
// "pewnosc siebie" w jednym katalogu. Model (i czlowiek w pickerze)
// rozroznia je tylko wtedy, gdy obie pozycje niosa objasnienie.

import (
	"fmt"
	"sort"
	"strings"
	"unicode/utf8"
)

// maxGlossRunes to twardy limit dlugosci glosy (G3). Limit jest czescia
// kontraktu: glosa ponad nim przestaje byc podpisem, a zaczyna byc
// definicja — czyli obchodzi L1.
const maxGlossRunes = 120

// SubstringValuePairs zwraca pary wartosci katalogu, w ktorych jedna
// jest podlancuchem drugiej (porownanie bez wielkosci liter). Kolejnosc
// w parze: [krotsza, dluzsza]; lista posortowana deterministycznie.
//
// Funkcja jest WSPOLNA dla walidatora (G6) i renderera promptu S2
// (automatyczny dopisek "NIE mylic z ..."): obie strony musza widziec
// te same pary, inaczej linter wymuszalby glosy, ktorych renderer nie
// wyroznia — albo odwrotnie.
func SubstringValuePairs(values []string) [][2]string {
	var pary [][2]string
	for i, a := range values {
		la := strings.ToLower(strings.TrimSpace(a))
		if la == "" {
			continue
		}
		for j, b := range values {
			if i == j {
				continue
			}
			lb := strings.ToLower(strings.TrimSpace(b))
			if la == lb {
				// Duplikat wartosci to inny blad, nie para podlancuchowa.
				continue
			}
			if strings.Contains(lb, la) {
				pary = append(pary, [2]string{a, b})
			}
		}
	}
	sort.Slice(pary, func(i, j int) bool {
		if pary[i][0] != pary[j][0] {
			return pary[i][0] < pary[j][0]
		}
		return pary[i][1] < pary[j][1]
	})
	return pary
}

// validateGlosses egzekwuje G1-G4 i G6 dla jednego konstruktu.
//
// ══ Zakres G6 — swiadome odstepstwo od planu ══
//
// Plan deklaruje G6 jako ERROR bezwarunkowy i ROWNOCZESNIE wymaga w
// Definition of Done, zeby ppt/0.1.0 (bez glos, z para "pewnosc" /
// "pewnosc siebie") przechodzil lint bez zmian. Obu naraz nie da sie
// spelnic doslownie. Rozstrzygniecie: G6 jest bledem dla konstruktu,
// ktory JUZ uzywa glos (przyjal mechanizm, wiec ma go domknac), a dla
// konstruktu bez glos ta sama detekcja par trafia do Warnings() — jest
// widoczna, ale nie wywraca istniejacych seedow. Odnotowane w
// changelogu planu (v1.1).
func validateGlosses(id string, c *Construct) []string {
	var p []string
	if len(c.ValueGlosses) == 0 {
		return nil
	}

	if len(c.Values) == 0 {
		p = append(p, fmt.Sprintf(
			"%s.value_glosses: glosy przy pustym katalogu values sa niedozwolone (G2)", id))
		return p
	}

	wValues := map[string]bool{}
	wValuesLower := map[string]bool{}
	for _, v := range c.Values {
		wValues[v] = true
		wValuesLower[strings.ToLower(strings.TrimSpace(v))] = true
	}

	klucze := make([]string, 0, len(c.ValueGlosses))
	for k := range c.ValueGlosses {
		klucze = append(klucze, k)
	}
	sort.Strings(klucze)

	for _, k := range klucze {
		g := c.ValueGlosses[k]
		// G1: dopasowanie DOSLOWNE, bez normalizacji — glosujemy kanon,
		// wiec literowka (takze w diakrytyku) ma byc bledem, nie cichym
		// "prawie trafieniem".
		if !wValues[k] {
			p = append(p, fmt.Sprintf(
				"%s.value_glosses[%q]: klucz nie wystepuje w values (G1)", id, k))
			continue
		}
		trimmed := strings.TrimSpace(g)
		switch {
		case trimmed == "":
			p = append(p, fmt.Sprintf("%s.value_glosses[%q]: glosa pusta (G3)", id, k))
		case utf8.RuneCountInString(trimmed) > maxGlossRunes:
			p = append(p, fmt.Sprintf(
				"%s.value_glosses[%q]: glosa ma %d znakow, limit %d (G3)",
				id, k, utf8.RuneCountInString(trimmed), maxGlossRunes))
		case strings.ContainsAny(g, "\n\r"):
			p = append(p, fmt.Sprintf("%s.value_glosses[%q]: glosa wieloliniowa (G3)", id, k))
		case strings.ContainsAny(g, "`*#") || strings.Contains(g, "]("):
			p = append(p, fmt.Sprintf(
				"%s.value_glosses[%q]: glosa zawiera formatowanie — czysty tekst (G3)", id, k))
		}
		// G4: glosa rowna kluczowi albo INNEJ wartosci enumu jest zrodlem
		// pomylek, nie objasnieniem.
		if wValuesLower[strings.ToLower(trimmed)] {
			p = append(p, fmt.Sprintf(
				"%s.value_glosses[%q]: glosa jest identyczna z wartoscia katalogu (G4)", id, k))
		}
	}

	for _, para := range SubstringValuePairs(c.Values) {
		if _, ok := c.ValueGlosses[para[0]]; !ok {
			p = append(p, fmt.Sprintf(
				"%s.value_glosses: %q tworzy pare podlancucha z %q i musi miec glose (G6)",
				id, para[0], para[1]))
		}
		if _, ok := c.ValueGlosses[para[1]]; !ok {
			p = append(p, fmt.Sprintf(
				"%s.value_glosses: %q tworzy pare podlancucha z %q i musi miec glose (G6)",
				id, para[1], para[0]))
		}
	}
	return p
}

// Warnings zwraca problemy klasy OSTRZEZENIE — rzeczy warte pokazania
// autorowi, ktore nie blokuja zapisu ani importu.
//
// Osobny kanal jest celowy: doklejenie ostrzezen do Validate()
// zablokowaloby build na regule, ktora z definicji dopuszcza wyjatki
// (G5: alias moze byc uzasadniony — rozstrzyga ekspert, nie linter).
func (o *Ontology) Warnings() []string {
	var w []string
	// G6 w wersji ostrzegawczej: para podlancuchowa w konstrukcie, ktory
	// glos jeszcze nie uzywa. Sygnal dla autora, ze katalog zawiera
	// dwuznacznosc, ktora czeka na objasnienia — bez wywracania seedow
	// sprzed istnienia pola.
	for _, id := range o.ConstructIDs() {
		c := o.Constructs[id]
		if c == nil || len(c.ValueGlosses) > 0 {
			continue
		}
		for _, para := range SubstringValuePairs(c.Values) {
			w = append(w, fmt.Sprintf(
				"%s.values: para %q / %q w relacji podlancucha — rozwaz value_glosses dla obu (G6)",
				id, para[0], para[1]))
		}
	}
	// G5: klucz glosy bedacy aliasem INNEGO konstruktu myli — glosujemy
	// kanon tego katalogu, a nazwa wariantowa cudzego konstruktu w roli
	// klucza sugeruje, ze glosa dotyczy tamtego pojecia.
	for _, id := range o.ConstructIDs() {
		c := o.Constructs[id]
		if c == nil || len(c.ValueGlosses) == 0 {
			continue
		}
		klucze := make([]string, 0, len(c.ValueGlosses))
		for k := range c.ValueGlosses {
			klucze = append(klucze, k)
		}
		sort.Strings(klucze)
		for _, k := range klucze {
			kl := strings.ToLower(strings.TrimSpace(k))
			for _, innyID := range o.ConstructIDs() {
				if innyID == id {
					continue
				}
				inny := o.Constructs[innyID]
				if inny == nil {
					continue
				}
				for _, alias := range inny.Aliases {
					if strings.ToLower(strings.TrimSpace(alias)) == kl {
						w = append(w, fmt.Sprintf(
							"%s.value_glosses[%q]: klucz jest aliasem konstruktu %s (G5)",
							id, k, innyID))
					}
				}
			}
		}
	}
	sort.Strings(w)
	return w
}
