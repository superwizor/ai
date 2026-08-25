package ontopipe

import (
	_ "embed"
	"fmt"
	"sort"
	"strings"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// Prompty zyja w plikach .txt, nie w stalych Go.
//
// Powod jest praktyczny: recenzuje je ekspert kliniczny, ktory nie czyta
// Go, a diff promptu ma byc czytelny w review bez przedzierania sie
// przez ucieczki znakow. Konwencja jest ta sama, co w
// services/ai-pipeline-svc/prompts/.
//
// Zmiana ktoregokolwiek z tych plikow WYMAGA podbicia PromptVersionS*
// w pipeline.go — inaczej raport sprzed zmiany i po zmianie sa
// nieodroznialne w audycie, a benchmark porownuje jablka z gruszkami.

//go:embed prompts/s1_ekstrakcja.txt
var promptS1 string

//go:embed prompts/s2_mapowanie.txt
var promptS2Base string

//go:embed prompts/s4_synteza.txt
var promptS4Base string

// schemaS1 opisuje wyjscie ekstrakcji.
//
// Schemat nie moze wymusic, ze cytat jest doslowny — to sprawdza
// weryfikacja mechaniczna w ExtractSpans. Wymusza natomiast, ze kazdy
// span ma komplet metadanych dowodowych, bo span bez `kind` albo bez
// `observed_by` nie da sie potem ocenic wzgledem progow R2 ani R10.
func schemaS1() map[string]any {
	return map[string]any{
		"type": "object",
		"properties": map[string]any{
			"spans": map[string]any{
				"type": "array",
				// BEZ maxItems. Vertex buduje z ograniczen automat stanow i
				// gorna granica dlugosci tablicy ZAGNIEZDZONYCH obiektow
				// mnozy go do odrzucenia calego zadania ("too many states
				// for serving", zaobserwowane 2026-08-23 na sesji z 382
				// chunkami). Rozmiar wyjscia S1 i tak ogranicza MaxTokens, a
				// tutaj chcemy DUZO spanow — zacisk mial sens dla S2, gdzie
				// twierdzen ma byc kilka, nie dla ekstrakcji.
				"items": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"span_id": map[string]any{"type": "string"},
						"quote_verbatim": map[string]any{
							"type": "string", "maxLength": int64(600),
							"description": "Kopiuj ZNAK W ZNAK z zapisu, w jezyku oryginalu.",
						},
						"speaker": map[string]any{"type": "string"},
						"kind": map[string]any{
							"type": "string",
							"enum": []any{string(ontology.SpanDeclarative), string(ontology.SpanBehavioral)},
						},
						"observed_by": map[string]any{
							"type": "string",
							"enum": []any{string(ontology.ObservedBySelf), string(ontology.ObservedByTherapist)},
						},
						"about_past": map[string]any{
							"type":        "boolean",
							"description": "true WYLACZNIE przy wprost wyrazonym odniesieniu do przeszlosci.",
						},
						"risk_content": map[string]any{
							"type":        "boolean",
							"description": "Prog NISKI — przy watpliwosci true.",
						},
						"topics": map[string]any{
							"type": "array", "maxItems": int64(3),
							"items": map[string]any{"type": "string", "maxLength": int64(40)},
						},
						// Bez "minimum": liczby z granicami tez powiekszaja
						// automat stanow, a ujemna cisza i tak nie ma sensu —
						// odsiewa ja kod, nie schemat.
						"silence_before_ms": map[string]any{"type": "integer"},
					},
					"required": []any{"span_id", "quote_verbatim", "speaker", "kind",
						"observed_by", "about_past", "risk_content", "topics"},
				},
			},
		},
		"required": []any{"spans"},
	}
}

// buildS2Prompt sklada prompt mapowania dla JEDNEGO konstruktu.
//
// Cala wiedza L1/L2 konstruktu ida do kontekstu STATYCZNIE, z ontologii.
// S2 NIE KONSUMUJE WYNIKOW RAG (dok. 11 sekcja 4): wyszukiwanie
// semantyczne po literaturze zwrocilo by fragmenty podobne leksykalnie,
// a nie wlasciwe teoretycznie — i to model, nie ekspert, decydowalby
// wtedy, ktora definicja obowiazuje. RAG jest wlasciwym narzedziem dla
// A4_EDU (tekst teorii), nie dla klasyfikacji.
func buildS2Prompt(o *ontology.Ontology, constructID string, past *PastContext) string {
	c := o.Constructs[constructID]
	if c == nil {
		// Nie panikujemy: wolajacy dostanie blad ze SchemaForConstruct,
		// ktory jest jedynym miejscem uprawnionym do tej decyzji.
		return promptS2Base
	}

	var b strings.Builder
	b.WriteString(promptS2Base)
	fmt.Fprintf(&b, "\n\nMODALNOSC: %s (ontologia %s)\n", o.Modality, o.Version)
	fmt.Fprintf(&b, "KONSTRUKT: %s — %s\n", constructID, c.LabelPL)

	if c.Definition != "" {
		fmt.Fprintf(&b, "\nDEFINICJA\n%s\n", c.Definition)
	}
	if c.Source != nil && c.Source.WorkID != "" {
		fmt.Fprintf(&b, "(za: %s %s, s. %s)\n", c.Source.WorkID, c.Source.Edition, c.Source.Pages)
	}
	if len(c.Aliases) > 0 {
		fmt.Fprintf(&b, "\nINNE NAZWY TEGO SAMEGO: %s\n", strings.Join(c.Aliases, ", "))
	}

	if len(c.Values) > 0 {
		b.WriteString("\nKATEGORIE (jedyne dopuszczalne)\n")
		for _, v := range c.Values {
			fmt.Fprintf(&b, "  - %s\n", v)
		}
		if c.MultiLabel {
			b.WriteString("Konstrukt wielokrotny: wolno wskazac wiecej niz jedna.\n")
		}
	} else {
		b.WriteString("\nTen konstrukt NIE MA katalogu zamknietego — opisz zjawisko zwyklym jezykiem.\n")
	}

	// is_not to najgestsza informacja w calej ontologii: granica
	// konstruktu jest tym, co go definiuje w praktyce klasyfikacji.
	if len(c.IsNot) > 0 {
		b.WriteString("\nTO NIE JEST (granice konstruktu — czytaj uwaznie)\n")
		for _, v := range c.IsNot {
			fmt.Fprintf(&b, "  - %s\n", v)
		}
	}
	// Rejestr antywzorcow jest ZYWY: zasilaja go bledy benchmarku i
	// feedback ekspertow, wiec kazda pozycja odpowiada pomylce, ktora
	// juz sie zdarzyla.
	if len(c.CommonConfusions) > 0 {
		b.WriteString("\nCZESTE POMYLKI\n")
		for _, cf := range c.CommonConfusions {
			fmt.Fprintf(&b, "  - %q to NIE %s, tylko %s", cf.Input, constructID, cf.Correct)
			if cf.Note != "" {
				fmt.Fprintf(&b, " (%s)", cf.Note)
			}
			b.WriteString("\n")
		}
	}
	if len(c.Examples) > 0 {
		b.WriteString("\nPRZYKLADY\n")
		for _, v := range c.Examples {
			fmt.Fprintf(&b, "  + %s\n", v)
		}
	}
	if len(c.CounterExamples) > 0 {
		b.WriteString("\nKONTRPRZYKLADY (to NIE kwalifikuje sie tutaj)\n")
		for _, v := range c.CounterExamples {
			fmt.Fprintf(&b, "  - %s\n", v)
		}
	}

	// Prog dowodowy trafia do promptu, choc egzekwuje go walidator.
	// Model, ktory zna prog, rzadziej produkuje twierdzenia skazane na
	// odrzucenie — a kazde odrzucone twierdzenie to zaplacone tokeny.
	if c.MinEvidence != nil {
		fmt.Fprintf(&b, "\nPROG DOWODOWY: co najmniej %d span(y)", c.MinEvidence.Spans)
		if c.MinEvidence.Behavioral != nil && *c.MinEvidence.Behavioral > 0 {
			fmt.Fprintf(&b, ", w tym %d behawioralny(ch)", *c.MinEvidence.Behavioral)
		}
		if c.MinEvidence.Sessions != nil && *c.MinEvidence.Sessions > 1 {
			fmt.Fprintf(&b, ", z %d roznych sesji", *c.MinEvidence.Sessions)
		}
		b.WriteString(".\nPonizej progu ustaw insufficient_data zamiast twierdzenia na wyrost.\n")
	}
	if len(c.Requires) > 0 {
		fmt.Fprintf(&b, "\nZALEZNOSCI: ten konstrukt ma sens wylacznie przy %s.\n",
			strings.Join(c.Requires, ", "))
	}
	if c.Quantities != nil && c.Quantities.Policy == "stated_only" {
		b.WriteString("\nLICZBY: wylacznie takie, ktore PADLY w cytowanym spanie. " +
			"Fabrykowana precyzja jest konfabulacja.\n")
	}
	if c.ForcedStatus != "" {
		fmt.Fprintf(&b, "\nSTATUS WYMUSZONY: %s — schemat nie dopuszcza innego.\n", c.ForcedStatus)
	}
	appendPastFindings(&b, past, constructID)
	return b.String()
}

// buildS4Prompt dokleja do bazowego promptu slownik konstruktow, zeby
// synteza nazywala je po ludzku, a nie identyfikatorem z bazy.
func buildS4Prompt(o *ontology.Ontology) string {
	var b strings.Builder
	b.WriteString(promptS4Base)
	// Ton per modalnosc (M5). Zmienia SZABLON JEZYKOWY, nigdy tresc
	// twierdzen — S5 weryfikuje wyjscie bez zmian. Tony spoza KnownTones
	// odrzuca metaschemat, wiec galaz default jest nieosiagalna dla
	// tresci, ktora przeszla walidacje.
	if o.ReportProfile != nil && o.ReportProfile.DefaultTone == "phenomenological" {
		b.WriteString("\n\nTON: fenomenologiczny. Opis przed oceną, obserwacja przed " +
			"interpretacją. Tam, gdzie wystarczy opis tego, co widać, nie klasyfikuj; " +
			"pytania formułuj jako zaproszenia do świadomości, nie tezy.\n")
	}
	fmt.Fprintf(&b, "\n\nMODALNOSC: %s (ontologia %s)\n", o.Modality, o.Version)
	b.WriteString("\nNAZWY KONSTRUKTOW\n")
	for _, id := range o.ConstructIDs() {
		fmt.Fprintf(&b, "  %s = %s\n", id, o.Constructs[id].LabelPL)
	}
	return b.String()
}

// appendGenerativeGuidance dokleja wytyczne sekcji generacyjnych.
//
// Wytyczne pochodza z ONTOLOGII (layout.guidance) — sa trescia ekspercka,
// wersjonowana i po four-eyes, a nie promptem w kodzie. Regula oparcia
// jest jednak nasza i niezbywalna: pole basis_construct wymusza ja
// schematem, a zdanie tutaj tlumaczy modelowi, PO CO ono jest.
func appendGenerativeGuidance(b *strings.Builder, in SynthesisInput) {
	// Jezyk raportu = jezyk KARTOTEKI, nie ontologii (2026-08-24,
	// kartoteka en z polskim szkicem CBT). Instrukcja pada zawsze, gdy
	// tag jest niepolski — takze dla jezykow, ktorych chrome renderera
	// nie tlumaczy: proza i tak ma wyjsc w jezyku terapeuty.
	if l := strings.ToLower(strings.TrimSpace(in.Language)); l != "" &&
		l != "pl" && !strings.HasPrefix(l, "pl-") {
		fmt.Fprintf(b, "\n\nJEZYK RAPORTU: %s. Caly tekst raportu (hipotezy, "+
			"pytania, wzmianki o wzorcach, propozycje) piszesz w tym jezyku. "+
			"Cytaty dowodowe zostaja w brzmieniu oryginalnym.\n", in.Language)
	}
	if in.WantSuggestions {
		b.WriteString("\n\nPROPOZYCJE MIEDZY SESJAMI (pole `suggestions`, 2-3 pozycje):\n" +
			"Kazda ROZWIJA zatwierdzone ustalenia — pole basis_construct wskazuje, " +
			"z ktorego konstruktu wynika. Nie wprowadzaj kierunkow bez oparcia.\n")
		if in.SuggestionsGuidance != "" {
			b.WriteString(in.SuggestionsGuidance + "\n")
		}
	}
	if in.WantInterventions {
		b.WriteString("\n\nPROPOZYCJE INTERWENCJI (pole `interventions`, 1-2 pozycje):\n" +
			"Propozycje WARUNKOWE, nie zalecenia. verify_first mowi, co terapeuta " +
			"ma sprawdzic, zanim zastosuje.\n")
		if in.InterventionsGuidance != "" {
			b.WriteString(in.InterventionsGuidance + "\n")
		}
	}
}

// appendPastFindings dokleja ustalenia TEGO konstruktu z wczesniejszych
// sesji (F7a-3, dok. 65 §4.3).
//
// ══ Po co model ma je widziec ══
//
// Bez nich prog `min_evidence.sessions` byl niespelnialny z definicji:
// jedna sesja to jedna sesja, wiec konstrukty wymagajace ciaglosci
// (np. `unfinished_business` w Gestalt) zawsze konczyly w
// `insufficient_data`. Z nimi model moze wskazac ten sam watek w dwoch
// sesjach i prog staje sie egzekwowalny.
//
// ══ Czego tu nie ma ══
//
// Prozy poprzednich raportow. Ustalenie jest podane jako KATEGORIA
// i ADRESY cytatow, nie jako gotowe zdanie do przepisania — inaczej
// model powtarzalby wlasna interpretacje sprzed tygodnia i z kazdym
// powtorzeniem brzmiala by pewniej (dok. 65 §N1).
func appendPastFindings(b *strings.Builder, past *PastContext, constructID string) {
	ustalenia := past.ClaimsForConstruct(constructID)
	if len(ustalenia) == 0 {
		return
	}
	b.WriteString("\n\nUSTALENIA Z POPRZEDNICH SESJI (ten sam konstrukt)\n")
	for _, u := range ustalenia {
		kat := strings.Join(u.Categories, ", ")
		if kat == "" {
			kat = "(bez kategorii)"
		}
		fmt.Fprintf(b, "  - %s: %s [%s, pewnosc %.0f%%] — cytaty: %s\n",
			u.SessionDate.Format("02.01"), kat, u.Status,
			u.Confidence*100, strings.Join(u.Evidence, ", "))
	}
	b.WriteString(
		"Te ustalenia sa TLEM, nie trescia do przepisania. Wolno powolac sie na " +
			"cytat historyczny (adres `sMMDD:sNN`) razem z cytatem z DZISIEJSZEJ " +
			"sesji, gdy watek faktycznie wraca — wtedy twierdzenie ma pokrycie w " +
			"dwoch sesjach.\n" +
			"KAZDE twierdzenie musi miec co najmniej jeden cytat z dzisiejszej " +
			"sesji: raport opisuje TE sesje, nie poprzednie.\n")
}

// schemaS4 buduje schemat raportu ZAWEZONY DO KONKRETNEGO PRZEBIEGU.
//
// Enumy nie sa tu ozdoba. `construct_id` ograniczony do konstruktow,
// ktore faktycznie cos zwrocily, i `supporting`/`contradicting`
// ograniczone do spanow niosacych zatwierdzone twierdzenia oznaczaja, ze
// S4 NIE MOZE wskazac spanu, ktorego nie ma, ani opisac konstruktu,
// ktorego nie bylo. To ta sama zasada, co enum kategorii w S2:
// egzekwowanie przez nieobecnosc, nie przez prosbe w prompcie.
func schemaS4(in SynthesisInput) map[string]any {
	spanIDs := allowedSpanIDs(in)
	spanEnum := make([]any, 0, len(spanIDs))
	for _, id := range spanIDs {
		spanEnum = append(spanEnum, id)
	}
	constructIDs := allowedConstructIDs(in)
	constructEnum := make([]any, 0, len(constructIDs))
	for _, id := range constructIDs {
		constructEnum = append(constructEnum, id)
	}

	spanRef := map[string]any{"type": "string"}
	if len(spanEnum) > 0 {
		spanRef["enum"] = spanEnum
	}

	statuses := statusesInPlay(in)

	// Sekcje generacyjne (uklad M5): pola pojawiaja sie w schemacie
	// WYLACZNIE, gdy uklad ich zazadal — model nieproszony nie ma jak ich
	// zwrocic. basis_construct to enum zatwierdzonych konstruktow:
	// propozycja bez oparcia w materiale nie moze POWSTAC, dokladnie tak
	// jak twierdzenie bez cytatu.
	suggestion := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"title": map[string]any{"type": "string", "maxLength": int64(120)},
			"basis_construct": map[string]any{"type": "string", "enum": constructEnum,
				"description": "Konstrukt, z ktorego ustalen ta propozycja WYNIKA."},
			"target": map[string]any{"type": "string", "maxLength": int64(160),
				"description": "Co ma byc wzmacniane albo obserwowane."},
			"instruction": map[string]any{"type": "string", "maxLength": int64(600),
				"description": "Niedyrektywne zaproszenie, jezyk przyjazny klientowi."},
		},
		"required": []any{"title", "basis_construct", "target", "instruction"},
	}
	intervention := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"name": map[string]any{"type": "string", "maxLength": int64(120)},
			"basis_construct": map[string]any{"type": "string", "enum": constructEnum,
				"description": "Hipoteza/konstrukt z TEGO raportu, na ktorym sie opiera."},
			"verify_first": map[string]any{"type": "string", "maxLength": int64(300),
				"description": "Co terapeuta ma zweryfikowac, ZANIM zastosuje."},
			"scenario": map[string]any{"type": "string", "maxLength": int64(900),
				"description": "Jak wprowadzic, z przykladowym sformulowaniem."},
		},
		"required": []any{"name", "basis_construct", "verify_first", "scenario"},
	}

	hypothesis := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"id": map[string]any{"type": "string", "maxLength": int64(4)},
			"claim": map[string]any{
				"type": "string", "maxLength": int64(700),
				"description": "Hipoteza jednym akapitem. Przy theoretical_hypothesis " +
					"jezyk MODALNY (mozliwe, ze / hipoteza robocza).",
			},
			// minItems 1 zostaje (wymog proweniencji), maxItems znika:
			// gorna granica NAD ENUMEM identyfikatorow spanow daje liczbe
			// kombinacji rosnaca wykladniczo z liczba spanow, a przy
			// dluzszej sesji to setki pozycji.
			"supporting": map[string]any{
				"type": "array", "items": spanRef, "minItems": int64(1),
			},
			"contradicting": map[string]any{
				"type": "array", "items": spanRef,
			},
			"epistemic_status": map[string]any{"type": "string", "enum": statuses},
			// Bez granic liczbowych — zakres pilnuje clampConfidence.
			// WYMAGANE z tego samego powodu co w S2: pole opcjonalne model
			// pomijal, a rendering pomija zero, wiec adnotacja o pewnosci
			// znikala z raportu bez sladu.
			"confidence": map[string]any{
				"type": "number",
				"description": "Pewnosc od 0 do 1. Podaj ZAWSZE. Przepisz ja z " +
					"twierdzenia zrodlowego — nie podnos.",
			},
		},
		"required": []any{"id", "claim", "supporting", "epistemic_status", "confidence"},
	}

	construct := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"construct_id": map[string]any{"type": "string", "enum": constructEnum},
			"hypotheses": map[string]any{
				"type": "array", "items": hypothesis, "maxItems": int64(4),
			},
			"unknown_yet": map[string]any{
				"type": "array", "maxItems": int64(4),
				"items": map[string]any{"type": "string", "maxLength": int64(300)},
			},
			"next_session_questions": map[string]any{
				"type": "array", "maxItems": int64(3),
				"items": map[string]any{"type": "string", "maxLength": int64(300)},
			},
			"pattern_notices": map[string]any{
				"type": "array", "maxItems": int64(4),
				"items": map[string]any{"type": "string", "maxLength": int64(300)},
			},
		},
		"required": []any{"construct_id", "hypotheses"},
	}

	// Liczbe konstruktow ogranicza juz enum construct_id — dodatkowy
	// maxItems nic nie wnosi, a powieksza automat stanow.
	props := map[string]any{
		"constructs": map[string]any{
			"type": "array", "items": construct,
		},
	}
	required := []any{"constructs"}
	if in.WantSuggestions {
		props["suggestions"] = map[string]any{"type": "array", "items": suggestion}
		required = append(required, "suggestions")
	}
	if in.WantInterventions {
		props["interventions"] = map[string]any{"type": "array", "items": intervention}
		required = append(required, "interventions")
	}
	return map[string]any{
		"type":       "object",
		"properties": props,
		"required":   required,
	}
}

// statusesInPlay zwraca statusy wystepujace w zatwierdzonych
// twierdzeniach tego przebiegu.
//
// Zawezenie enumu do nich jest strukturalnym odpowiednikiem reguly V4:
// skoro zaden konstrukt nie zostal zatwierdzony jako obserwacja, S4 nie
// ma z czego zrobic obserwacji w raporcie.
func statusesInPlay(in SynthesisInput) []any {
	set := map[string]bool{}
	for _, c := range in.Claims {
		if c.Status != "" {
			set[string(c.Status)] = true
		}
	}
	if len(set) == 0 {
		// Brak twierdzen: zostaja tylko pola bez danych, ale schemat
		// musi byc poprawny, wiec dopuszczamy pytanie otwarte.
		return []any{string(ontology.StatusOpenQuestion)}
	}
	out := make([]string, 0, len(set))
	for s := range set {
		out = append(out, s)
	}
	sort.Strings(out)
	res := make([]any, 0, len(out))
	for _, s := range out {
		res = append(res, s)
	}
	return res
}
