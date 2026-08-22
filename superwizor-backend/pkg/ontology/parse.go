package ontology

import (
	"fmt"
	"sort"

	"gopkg.in/yaml.v3"
)

// sortStrings jest opakowaniem, zeby types.go nie musial importowac sort.
func sortStrings(s []string) { sort.Strings(s) }

// Parse czyta ontologie z YAML i NIE waliduje jej merytorycznie.
//
// Rozdzial parsowania od walidacji jest celowy: Studio musi umiec
// wczytac niepoprawna tresc, zeby pokazac autorowi liste bledow, a nie
// pusty ekran. Wolajacy, ktory chce gwarancji poprawnosci, uzywa Load.
func Parse(data []byte) (*Ontology, error) {
	var o Ontology
	dec := yaml.Unmarshal
	if err := dec(data, &o); err != nil {
		return nil, fmt.Errorf("ontology: parse yaml: %w", err)
	}
	o.applyDefaults()
	return &o, nil
}

// Load parsuje i waliduje. Zwraca ontologie tylko wtedy, gdy jest
// zdatna do uzycia — to jest wejscie dla runtime'u (S2/S3) i dla
// aktywacji wersji.
func Load(data []byte) (*Ontology, error) {
	o, err := Parse(data)
	if err != nil {
		return nil, err
	}
	if problems := o.Validate(); len(problems) > 0 {
		return nil, fmt.Errorf("ontology: %d problem(ow) walidacji, pierwszy: %s",
			len(problems), problems[0])
	}
	return o, nil
}

// applyDefaults uzupelnia wartosci domyslne z metaschematu.
//
// kind domyslnie category: metaschemat mowi "domyslnie category", a
// rozszerzenia v1.3 sa ADDYTYWNE — istniejace ontologie bez tego pola
// pozostaja wazne bez zmian (dok. 11, uwagi do rozszerzen v1.3).
func (o *Ontology) applyDefaults() {
	if len(o.EpistemicStatuses) == 0 {
		o.EpistemicStatuses = append([]EpistemicStatus(nil), AllStatuses...)
	}
	if len(o.RelationTypes) == 0 {
		o.RelationTypes = append([]RelationType(nil), AllRelationTypes...)
	}
	for _, c := range o.Constructs {
		if c != nil && c.Kind == "" {
			c.Kind = KindCategory
		}
	}
}

// Marshal serializuje ontologie z powrotem do YAML. Uzywane przez Studio
// (zapis wersji) i przez eksport seedow.
func (o *Ontology) Marshal() ([]byte, error) {
	b, err := yaml.Marshal(o)
	if err != nil {
		return nil, fmt.Errorf("ontology: marshal yaml: %w", err)
	}
	return b, nil
}
