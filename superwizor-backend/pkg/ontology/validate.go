package ontology

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
)

// Validate sprawdza ontologie wzgledem metaschematu (dok. 11 sekcja 3.2).
//
// Zwraca WSZYSTKIE problemy, nie pierwszy: autor w Ontology Studio ma
// zobaczyc pelna liste do poprawienia, a nie odkrywac bledy po jednym.
// Lista pusta = tresc zdatna do zapisu, zatwierdzenia i aktywacji.
//
// Walidator jest DZIEDZINOWO GLUCHY: nie ocenia, czy "sumiennosc" nalezy
// do potencjalnosci wtornych — to kompetencja ekspertow (D2). Sprawdza
// wylacznie spojnosc formalna, czyli to, czego ekspert nie ma obowiazku
// pilnowac w glowie.
func (o *Ontology) Validate() []string {
	var p []string
	p = append(p, o.validateHeader()...)
	p = append(p, o.validateConstructs()...)
	p = append(p, o.validatePolicies()...)
	p = append(p, o.validateReportProfile()...)
	sort.Strings(p)
	return p
}

// validateReportProfile pilnuje M5.
//
// Do 2026-08-24 profil byl niewalidowany, bo nic go nie czytalo. Od kiedy
// renderer komponuje wedlug niego sekcje, literowka w kluczu sekcji albo
// w wadze dzialalaby jak brak wpisu — czyli najgorszy rodzaj bledu:
// niewidoczny.
func (o *Ontology) validateReportProfile() []string {
	if o.ReportProfile == nil {
		return nil
	}
	var p []string
	znane := map[string]bool{}
	for _, s := range ReportSections {
		znane[s] = true
	}
	for key, sec := range o.ReportProfile.Sections {
		if !znane[key] {
			p = append(p, fmt.Sprintf("report_profile.sections.%s: nieznana sekcja (znane: %s)",
				key, strings.Join(ReportSections, ", ")))
		}
		switch sec.Weight {
		case WeightHigh, WeightNormal, WeightLow:
		default:
			p = append(p, fmt.Sprintf("report_profile.sections.%s: waga %q (high|normal|low)",
				key, sec.Weight))
		}
	}
	if len(o.ReportProfile.Layout) > 0 && len(o.ReportProfile.Sections) > 0 {
		p = append(p, "report_profile: layout i sections sa wzajemnie wykluczajace — "+
			"dwie rownolegle definicje kolejnosci nie maja rozstrzygniecia")
	}
	p = append(p, o.validateLayout()...)
	if t := o.ReportProfile.DefaultTone; t != "" {
		ok := false
		for _, znany := range KnownTones {
			if t == znany {
				ok = true
			}
		}
		if !ok {
			p = append(p, fmt.Sprintf("report_profile.default_tone %q: ton bez zdefiniowanego "+
				"szablonu S4 bylby po cichu ignorowany (znane: %s)",
				t, strings.Join(KnownTones, ", ")))
		}
	}
	return p
}

var (
	semverRe   = regexp.MustCompile(`^\d+\.\d+\.\d+$`)
	modalityRe = regexp.MustCompile(`^[a-z][a-z0-9_]*$`)
	idRe       = regexp.MustCompile(`^[a-z][a-z0-9_]*$`)
	// slotTypeRe pokrywa cztery formy z metaschematu: span_ref, entry_ref,
	// construct_ref(<id>), enum_ref(<id>).
	slotTypeRe = regexp.MustCompile(`^(span_ref|entry_ref|(construct_ref|enum_ref)\([a-z][a-z0-9_]*\))$`)
	refRe      = regexp.MustCompile(`^(construct_ref|enum_ref)\(([a-z][a-z0-9_]*)\)$`)
)

// validateLayout pilnuje ukladu sekcji (M5+).
//
// Najwazniejsze reguly to te, ktorych zlamanie byloby NIEWIDOCZNE w
// dzialaniu: konstrukt przypisany do dwoch sekcji renderowalby sie
// podwojnie, literowka w rodzaju dzialalaby jak brak sekcji, a guidance
// przy rodzaju nie-generacyjnym bylby po cichu ignorowany.
func (o *Ontology) validateLayout() []string {
	var p []string
	znaneKinds := map[string]bool{}
	for _, k := range LayoutKinds {
		znaneKinds[k] = true
	}
	widzianeID := map[string]bool{}
	widzianeKind := map[string]bool{}
	przypisane := map[string]string{}

	for _, sec := range o.ReportProfile.Layout {
		if !idRe.MatchString(sec.ID) {
			p = append(p, fmt.Sprintf("report_profile.layout.%s: id musi pasowac do [a-z][a-z0-9_]*", sec.ID))
		}
		if widzianeID[sec.ID] {
			p = append(p, fmt.Sprintf("report_profile.layout.%s: powtorzone id", sec.ID))
		}
		widzianeID[sec.ID] = true
		if strings.TrimSpace(sec.Title) == "" {
			p = append(p, fmt.Sprintf("report_profile.layout.%s: title jest wymagane — sekcja bez tytulu nie ma czym byc w raporcie", sec.ID))
		}
		if !znaneKinds[sec.Kind] {
			p = append(p, fmt.Sprintf("report_profile.layout.%s: nieznany rodzaj %q (znane: %s)",
				sec.ID, sec.Kind, strings.Join(LayoutKinds, ", ")))
			continue
		}
		if sec.Kind != LayoutConstructs && widzianeKind[sec.Kind] {
			p = append(p, fmt.Sprintf("report_profile.layout.%s: rodzaj %q wystapil drugi raz — tresc renderowalaby sie podwojnie", sec.ID, sec.Kind))
		}
		widzianeKind[sec.Kind] = true

		if sec.Kind == LayoutConstructs {
			if len(sec.Constructs) == 0 {
				p = append(p, fmt.Sprintf("report_profile.layout.%s: rodzaj constructs bez listy konstruktow", sec.ID))
			}
			for _, id := range sec.Constructs {
				if _, ok := o.Constructs[id]; !ok {
					p = append(p, fmt.Sprintf("report_profile.layout.%s: konstrukt %q nie istnieje", sec.ID, id))
				}
				if gdzie, ok := przypisane[id]; ok {
					p = append(p, fmt.Sprintf("report_profile.layout.%s: konstrukt %q juz przypisany do %s — renderowalby sie podwojnie", sec.ID, id, gdzie))
				}
				przypisane[id] = sec.ID
			}
		} else if len(sec.Constructs) > 0 {
			p = append(p, fmt.Sprintf("report_profile.layout.%s: constructs dopuszczalne wylacznie dla rodzaju constructs", sec.ID))
		}

		if sec.Guidance != "" && sec.Kind != LayoutSuggestions && sec.Kind != LayoutInterventions {
			p = append(p, fmt.Sprintf("report_profile.layout.%s: guidance dziala wylacznie dla suggestions/interventions — tutaj bylby po cichu ignorowany", sec.ID))
		}
	}
	return p
}

func (o *Ontology) validateHeader() []string {
	var p []string
	if !modalityRe.MatchString(o.Modality) {
		p = append(p, fmt.Sprintf("modality %q: oczekiwano identyfikatora [a-z][a-z0-9_]*", o.Modality))
	}
	if !semverRe.MatchString(o.Version) {
		p = append(p, fmt.Sprintf("version %q: oczekiwano semver MAJOR.MINOR.PATCH", o.Version))
	}
	if len(o.Constructs) == 0 {
		p = append(p, "constructs: ontologia bez konstruktow nie ma czego egzekwowac")
	}
	return p
}

func (o *Ontology) validatePolicies() []string {
	var p []string
	// Statusy: insufficient_data i no_fit MUSZA byc dostepne. Bez
	// pierwszego "brak danych" przestaje byc legalna odpowiedzia i wraca
	// nadmierne domykanie pol (objaw 4). Bez drugiego enum wymusza wybor
	// najblizszej kategorii — forced-choice bias (dok. 11 sekcja 3.2).
	have := map[EpistemicStatus]bool{}
	for _, s := range o.EpistemicStatuses {
		have[s] = true
	}
	for _, must := range []EpistemicStatus{StatusInsufficientData, StatusNoFit} {
		if !have[must] {
			p = append(p, fmt.Sprintf("epistemic_statuses: brak %q — status jest wartoscia pierwszej klasy, nie opcja", must))
		}
	}
	for _, s := range o.EpistemicStatuses {
		if !isKnownStatus(s) {
			p = append(p, fmt.Sprintf("epistemic_statuses: nieznany status %q", s))
		}
	}
	// Polityki bezpieczenstwa. "strict" jest jedyna dopuszczalna
	// wartoscia: etiologia bez spanu i inferencja o stanach terapeuty to
	// klasy bledow, ktore ta architektura ma likwidowac (R5, R10) —
	// ontologia nie moze ich wylaczyc deklaracja.
	if o.EtiologyPolicy != "strict" {
		p = append(p, fmt.Sprintf("etiology_policy %q: jedyna dopuszczalna wartosc to \"strict\" (R5)", o.EtiologyPolicy))
	}
	if o.TherapistBoundary != "strict" {
		p = append(p, fmt.Sprintf("therapist_boundary %q: jedyna dopuszczalna wartosc to \"strict\" (R10)", o.TherapistBoundary))
	}
	for _, rt := range o.RelationTypes {
		if !isKnownRelation(rt) {
			p = append(p, fmt.Sprintf("relation_types: nieznany typ %q", rt))
		}
	}
	return p
}

func (o *Ontology) validateConstructs() []string {
	var p []string
	for _, id := range o.ConstructIDs() {
		c := o.Constructs[id]
		if c == nil {
			p = append(p, fmt.Sprintf("%s: pusta definicja konstruktu", id))
			continue
		}
		if !idRe.MatchString(id) {
			p = append(p, fmt.Sprintf("%s: identyfikator musi pasowac do [a-z][a-z0-9_]*", id))
		}
		if strings.TrimSpace(c.LabelPL) == "" {
			p = append(p, fmt.Sprintf("%s: label_pl jest wymagane", id))
		}
		p = append(p, o.validateRefs(id, c)...)
		p = append(p, validateConstructShape(id, c)...)
	}
	return p
}

// validateRefs pilnuje, ze is_not i requires wskazuja na ISTNIEJACE
// konstrukty. Wisząca referencja jest grozniejsza, niz wyglada: R3
// degraduje konstrukt przy niespelnionym `requires`, wiec literowka w
// nazwie cicho zmienia zachowanie walidatora dziedzinowego.
func (o *Ontology) validateRefs(id string, c *Construct) []string {
	var p []string
	check := func(field string, refs []string) {
		for _, r := range refs {
			if _, ok := o.Constructs[r]; !ok {
				p = append(p, fmt.Sprintf("%s.%s: wskazuje na nieistniejacy konstrukt %q", id, field, r))
			}
			if r == id {
				p = append(p, fmt.Sprintf("%s.%s: konstrukt wskazuje sam na siebie", id, field))
			}
		}
	}
	check("is_not", c.IsNot)
	check("requires", c.Requires)

	for _, sid := range sortedSlotIDs(c.Slots) {
		s := c.Slots[sid]
		if s == nil {
			continue
		}
		m := refRe.FindStringSubmatch(s.Type)
		if m == nil {
			continue
		}
		target := m[2]
		if _, ok := o.Constructs[target]; !ok {
			p = append(p, fmt.Sprintf("%s.slots.%s: %s wskazuje na nieistniejacy konstrukt %q", id, sid, m[1], target))
		}
	}
	return p
}

func validateConstructShape(id string, c *Construct) []string {
	var p []string

	switch c.Kind {
	case KindCategory:
		if len(c.Slots) > 0 {
			p = append(p, fmt.Sprintf("%s: slots dopuszczalne wylacznie dla kind: composite", id))
		}
		if c.MinCompleteSlots != nil {
			p = append(p, fmt.Sprintf("%s: min_complete_slots dopuszczalne wylacznie dla kind: composite", id))
		}
	case KindComposite:
		if len(c.Slots) == 0 {
			p = append(p, fmt.Sprintf("%s: kind composite wymaga slotow", id))
		}
		if len(c.Values) > 0 {
			p = append(p, fmt.Sprintf("%s: kompozyt nie ma katalogu wartosci — values naleza do slotow", id))
		}
		if n := c.MinCompleteSlots; n != nil && (*n < 1 || *n > len(c.Slots)) {
			p = append(p, fmt.Sprintf("%s: min_complete_slots=%d poza zakresem 1..%d", id, *n, len(c.Slots)))
		}
	default:
		p = append(p, fmt.Sprintf("%s: nieznane kind %q (category|composite)", id, c.Kind))
	}

	for _, sid := range sortedSlotIDs(c.Slots) {
		s := c.Slots[sid]
		if s == nil {
			p = append(p, fmt.Sprintf("%s.slots.%s: pusta definicja slotu", id, sid))
			continue
		}
		if !slotTypeRe.MatchString(s.Type) {
			p = append(p, fmt.Sprintf("%s.slots.%s: nieznany type %q", id, sid, s.Type))
		}
		switch s.KindHint {
		case "", "behavioral", "declarative":
		default:
			p = append(p, fmt.Sprintf("%s.slots.%s: kind_hint %q (behavioral|declarative)", id, sid, s.KindHint))
		}
		// Slot ilosciowy bez polityki kwantyfikacji przepuscilby liczbe
		// bez reguly, ktora ja ogranicza — a R9 egzekwuje wlasnie polityke.
		if s.Quantity && c.Quantities == nil {
			p = append(p, fmt.Sprintf("%s.slots.%s: quantity: true wymaga quantities.policy na konstrukcie (R9)", id, sid))
		}
	}

	if q := c.Quantities; q != nil && q.Policy != "stated_only" {
		p = append(p, fmt.Sprintf("%s.quantities.policy %q: jedyna dopuszczalna wartosc to \"stated_only\" (M3/R9)", id, q.Policy))
	}

	// multi_label bez katalogu zamknietego nie ma czego zwielokrotniac —
	// a benchmark liczylby F1 per etykieta na zbiorze etykiet, ktorego nie ma.
	if c.MultiLabel && len(c.Values) == 0 {
		p = append(p, fmt.Sprintf("%s: multi_label wymaga niepustego values", id))
	}

	if c.ForcedStatus != "" && !isKnownStatus(c.ForcedStatus) {
		p = append(p, fmt.Sprintf("%s: nieznany forced_status %q", id, c.ForcedStatus))
	}

	if me := c.MinEvidence; me != nil {
		if me.Spans < 1 {
			p = append(p, fmt.Sprintf("%s.min_evidence.spans=%d: prog ponizej 1 znosi wymog proweniencji (R2)", id, me.Spans))
		}
		if me.Behavioral != nil && *me.Behavioral > me.Spans {
			p = append(p, fmt.Sprintf("%s.min_evidence: behavioral=%d > spans=%d — prog niespelnialny", id, *me.Behavioral, me.Spans))
		}
	}

	if len(c.Values) > 0 {
		seen := map[string]bool{}
		for _, v := range c.Values {
			if strings.TrimSpace(v) == "" {
				p = append(p, fmt.Sprintf("%s.values: pusta wartosc w katalogu", id))
				continue
			}
			if seen[v] {
				p = append(p, fmt.Sprintf("%s.values: duplikat %q", id, v))
			}
			seen[v] = true
		}
	}

	for i, cc := range c.CommonConfusions {
		if strings.TrimSpace(cc.Input) == "" || strings.TrimSpace(cc.Correct) == "" {
			p = append(p, fmt.Sprintf("%s.common_confusions[%d]: input i correct sa wymagane", id, i))
		}
	}
	return p
}

func sortedSlotIDs(m map[string]*Slot) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func isKnownStatus(s EpistemicStatus) bool {
	for _, k := range AllStatuses {
		if k == s {
			return true
		}
	}
	return false
}

func isKnownRelation(r RelationType) bool {
	for _, k := range AllRelationTypes {
		if k == r {
			return true
		}
	}
	return false
}
