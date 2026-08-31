package ontology

// Fakty sesyjne (E4/T42a, docs/67 §3).
//
// Fakt jest twierdzeniem-obserwacja zbudowanym przez KOD z jednego
// spanu o niepustym fact_kind. Dlaczego twierdzeniem, a nie osobnym
// bytem: sekcje layoutu, okno miedzysesyjne F7a, indeks F7b i
// proweniencja dzialaja na twierdzeniach — fakt jako twierdzenie
// dziedziczy cala te infrastrukture; osobny byt musialby ja zdublowac.

import (
	"fmt"
	"sort"
	"strings"
)

// validateFactKindMap egzekwuje F1-F5 dla jednego konstruktu.
//
//	F1  klucz mapy musi byc z katalogu FactKinds
//	F2  kategoria musi istniec w values (pusta przy values: null)
//	F3  (na poziomie ontologii) jeden konstrukt na fact_kind
//	F4  konstrukt faktowy wymaga forced_status: observation — fakt nie
//	    moze wyjsc z potoku jako interpretacja
//	F5  tylko kind: category — fakt jest plaski, kompozyt to nie fakt
func validateFactKindMap(id string, c *Construct) []string {
	if len(c.FactKindMap) == 0 {
		return nil
	}
	var p []string
	znane := map[string]bool{}
	for _, k := range FactKinds {
		znane[k] = true
	}
	wValues := map[string]bool{}
	for _, v := range c.Values {
		wValues[v] = true
	}
	klucze := make([]string, 0, len(c.FactKindMap))
	for k := range c.FactKindMap {
		klucze = append(klucze, k)
	}
	sort.Strings(klucze)
	for _, k := range klucze {
		if !znane[k] {
			p = append(p, fmt.Sprintf("%s.fact_kind_map[%q]: nieznany fact_kind (katalog: %s) (F1)",
				id, k, strings.Join(FactKinds, ", ")))
		}
		kat := c.FactKindMap[k]
		switch {
		case len(c.Values) == 0 && kat != "":
			p = append(p, fmt.Sprintf("%s.fact_kind_map[%q]: kategoria %q przy values: null — fakt bez katalogu mapuje sie na pusta kategorie (F2)", id, k, kat))
		case len(c.Values) > 0 && !wValues[kat]:
			p = append(p, fmt.Sprintf("%s.fact_kind_map[%q]: kategoria %q nie istnieje w values (F2)", id, k, kat))
		}
	}
	if c.ForcedStatus != StatusObservation {
		p = append(p, fmt.Sprintf("%s: fact_kind_map wymaga forced_status: observation — fakt nie moze byc interpretacja (F4)", id))
	}
	if c.Kind == KindComposite {
		p = append(p, fmt.Sprintf("%s: fact_kind_map niedozwolone na kompozycie (F5)", id))
	}
	return p
}

// validateFactRouting egzekwuje F3: fact_kind prowadzi do DOKLADNIE
// jednego konstruktu. Dwa konstrukty na ten sam fakt = mapowanie
// przestaje byc deterministyczne, czyli przestaje byc faktem.
func (o *Ontology) validateFactRouting() []string {
	trasa := map[string][]string{}
	for _, id := range o.ConstructIDs() {
		c := o.Constructs[id]
		if c == nil {
			continue
		}
		for k := range c.FactKindMap {
			trasa[k] = append(trasa[k], id)
		}
	}
	var p []string
	klucze := make([]string, 0, len(trasa))
	for k := range trasa {
		klucze = append(klucze, k)
	}
	sort.Strings(klucze)
	for _, k := range klucze {
		if len(trasa[k]) > 1 {
			p = append(p, fmt.Sprintf("fact_kind %q mapowany przez %s — dozwolony JEDEN konstrukt (F3)",
				k, strings.Join(trasa[k], ", ")))
		}
	}
	return p
}

// MapFacts buduje twierdzenia faktowe ze spanow — deterministycznie.
//
// Zwraca StageResult per konstrukt faktowy (kolejnosc: ConstructIDs),
// gotowe do Validate3 ta sama sciezka co wyniki S2 — fakt przechodzi
// przez S3 jak kazde twierdzenie, wiec prog dowodowy, granica
// terapeuty i rejestr odrzucen obowiazuja bez wyjatkow.
func (o *Ontology) MapFacts(spans []TopicSpan) []StageResult {
	var out []StageResult
	for _, id := range o.ConstructIDs() {
		c := o.Constructs[id]
		if c == nil || len(c.FactKindMap) == 0 {
			continue
		}
		sr := StageResult{ConstructID: id}
		for _, sp := range spans {
			kat, ok := c.FactKindMap[sp.FactKind]
			if !ok || sp.FactKind == "" {
				continue
			}
			var kategorie []string
			if kat != "" {
				kategorie = []string{kat}
			}
			sr.Claims = append(sr.Claims, Claim{
				ConstructID: id,
				Categories:  kategorie,
				Status:      StatusObservation,
				// Pewnosc 1.0 jest uczciwa: to nie os4d modelu, tylko
				// przepisanie faktu, ktory ma cytat zweryfikowany
				// mechanicznie. Niepewnosc faktu wyraza sie odrzuceniem
				// spanu w S1, nie ulamkiem tutaj.
				Confidence: 1.0,
				Reasoning:  "fakt sesyjny (fact_kind=" + sp.FactKind + ") — mapowanie deterministyczne, bez S2",
				Evidence:   []QuoteRef{{SpanID: sp.ID, Quote: sp.QuoteVerbatim}},
			})
		}
		if len(sr.Claims) > 0 {
			out = append(out, sr)
		}
	}
	return out
}
