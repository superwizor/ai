package ontology

import (
	"fmt"
	"sort"
)

// Budowniczy schematu wyjscia dla etapu S2 (dok. 11, sekcja 4).
//
// To jest miejsce, w ktorym zasada "LLM proponuje, struktura rozporzadza"
// przestaje byc haslem. Katalog wartosci konstruktu wchodzi do JSON
// Schema jako `enum`, wiec model NIE MOZE zwrocic kategorii spoza
// taksonomii — nie dlatego, ze mu zabroniono w prompcie, tylko dlatego,
// ze structured output odrzuci taka odpowiedz zanim ktokolwiek ja
// zobaczy. Diagnoza z sekcji 2 dokumentu 11 (objaw 1: bledy kategorialne)
// jest adresowana wlasnie tutaj.
//
// Drugi filar to PROWENIENCJA: `quotes` ma minItems 1 na kazdym
// twierdzeniu z kategoria. Twierdzenie bez spanu zrodlowego nie moze
// powstac, wiec koszt dopowiedzenia przestaje byc zerowy (objaw 5).

// SchemaOptions steruje ksztaltem schematu per wywolanie S2.
type SchemaOptions struct {
	// MaxClaims ogranicza liczbe twierdzen w jednej odpowiedzi. 0 =
	// domyslne 3. Nie zero: pusta odpowiedz jest wyrazana przez
	// insufficient_data, nie przez brak pozycji.
	MaxClaims int
	// MaxQuotesPerClaim ogranicza liczbe cytatow. 0 = domyslne 3.
	MaxQuotesPerClaim int
}

const (
	defaultMaxClaims         = 3
	defaultMaxQuotesPerClaim = 3
	// maxProseChars ogranicza pola tekstowe. Kontrola rozmiaru wyjscia
	// nalezy do schematu, nie do promptu — pomiar 21.08 na czacie
	// pokazal, ze instrukcje dlugosciowe w prompcie sa szumem
	// (-10%, -16%, +15% w trzech przebiegach), a zacisk maxItems dziala.
	maxProseChars = 1200
)

// SchemaForConstruct buduje JSON Schema odpowiedzi S2 dla JEDNEGO
// konstruktu.
//
// Osobne wywolanie na typ konstruktu, nigdy "cala konceptualizacja
// naraz" (dok. 11, S2): schemat mieszajacy poziomy pojeciowe jest
// dokladnie tym, co produkuje objaw 2 — mieszanie potrzeby, zasobu i
// potencjalnosci w jednym worku.
func (o *Ontology) SchemaForConstruct(constructID string, opts SchemaOptions) (map[string]any, error) {
	c, ok := o.Constructs[constructID]
	if !ok || c == nil {
		return nil, fmt.Errorf("ontology: brak konstruktu %q w modalnosci %s", constructID, o.Modality)
	}
	maxClaims := opts.MaxClaims
	if maxClaims <= 0 {
		maxClaims = defaultMaxClaims
	}
	maxQuotes := opts.MaxQuotesPerClaim
	if maxQuotes <= 0 {
		maxQuotes = defaultMaxQuotesPerClaim
	}

	claim := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"category":         o.categoryField(c),
			"evidence":         quotesArray(maxQuotes, 1),
			"counter_evidence": quotesArray(maxQuotes, 0),
			"epistemic_status": map[string]any{
				"type": "string",
				"enum": o.statusEnum(c),
				"description": "Status epistemiczny twierdzenia. Obserwacja tylko dla tego, " +
					"co widac wprost w zapisie; interpretacja i hipoteza teoretyczna wymagaja " +
					"oznaczenia.",
			},
			// Bez granic liczbowych. Vertex buduje z ograniczen automat
			// stanow i przy wiekszym schemacie odrzuca cale zadanie
			// ("too many states for serving", 2026-08-23). Zakres pilnuje
			// wolajacy — sprowadzenie 1.7 do 1.0 nie zmienia sensu.
			"confidence": map[string]any{"type": "number"},
			"reasoning": map[string]any{
				"type": "string", "maxLength": int64(maxProseChars),
				"description": "Uzasadnienie oparte WYLACZNIE na wskazanych spanach.",
			},
		},
		"required": []any{"epistemic_status", "evidence", "reasoning"},
	}
	// Kategoria jest wymagana tylko tam, gdzie katalog istnieje. Przy
	// jego braku konstrukt opisuje zjawisko proza i pole nie ma sensu.
	if len(c.Values) > 0 {
		claim["required"] = []any{"category", "epistemic_status", "evidence", "reasoning"}
	}

	return map[string]any{
		"type": "object",
		"properties": map[string]any{
			"construct_id": map[string]any{"type": "string", "enum": []any{constructID}},
			"claims": map[string]any{
				"type": "array", "items": claim,
				"minItems": int64(0), "maxItems": int64(maxClaims),
			},
			// insufficient_data i no_fit sa POLAMI, nie brakiem odpowiedzi.
			// Model musi je zadeklarowac jawnie, bo pusta lista twierdzen
			// bez powodu jest nierozroznialna od milczenia z lenistwa.
			"insufficient_data": map[string]any{
				"type": "boolean",
				"description": "true = materialu nie starcza, by rozstrzygnac. " +
					"To PELNOPRAWNA odpowiedz, nie porazka.",
			},
			"no_fit": map[string]any{
				"type": "boolean",
				"description": "true = danych dosc, ale zjawisko nie miesci sie w zadnej " +
					"kategorii tej taksonomii. NIE wybieraj najblizszej kategorii na sile.",
			},
			"missing": map[string]any{
				"type": "string", "maxLength": int64(400),
				"description": "Czego brakuje, gdy insufficient_data albo no_fit.",
			},
		},
		"required": []any{"construct_id", "claims", "insufficient_data", "no_fit"},
	}, nil
}

// categoryField buduje pole kategorii z katalogu ontologii.
func (o *Ontology) categoryField(c *Construct) map[string]any {
	if len(c.Values) == 0 {
		// Konstrukt bez katalogu zamknietego: opis prozą zamiast enumu.
		return map[string]any{
			"type": "string", "maxLength": int64(200),
			"description": "Zjawisko opisane zwyklym jezykiem — ten konstrukt nie ma " +
				"katalogu zamknietego.",
		}
	}
	values := make([]any, 0, len(c.Values))
	for _, v := range c.Values {
		values = append(values, v)
	}
	field := map[string]any{
		"type": "string", "enum": values,
		"description": "Kategoria WYLACZNIE z tej listy.",
	}
	if c.MultiLabel {
		// M2: wyjscie jest lista etykiet, kazda z tego samego enumu.
		return map[string]any{
			"type":     "array",
			"items":    field,
			"minItems": int64(1),
			"maxItems": int64(len(values)),
		}
	}
	return field
}

// statusEnum zwraca dopuszczalne statusy dla konstruktu.
//
// forced_status zawezá enum do jednej wartosci. To jest rownica miedzy
// "prompt prosi, zeby traktowac przekonanie kluczowe jako hipoteze" a
// "schemat nie dopuszcza niczego innego" — pierwsze zawodzi, drugie nie.
func (o *Ontology) statusEnum(c *Construct) []any {
	if c.ForcedStatus != "" {
		return []any{string(c.ForcedStatus)}
	}
	out := make([]any, 0, len(o.EpistemicStatuses))
	for _, s := range o.EpistemicStatuses {
		// insufficient_data i no_fit sa polami obiektu, nie statusami
		// pojedynczego twierdzenia — twierdzenie, ktore istnieje, ma
		// status merytoryczny.
		if s == StatusInsufficientData || s == StatusNoFit {
			continue
		}
		out = append(out, string(s))
	}
	return out
}

// quotesArray buduje tablice odnosnikow dowodowych.
//
// minItems 1 na `evidence` to wymog proweniencji: twierdzenie bez spanu
// zrodlowego nie moze powstac. Weryfikator (S3/R4) sprawdza potem, czy
// cytat jest doslownym fragmentem — schemat pilnuje jedynie, ze cytat
// W OGOLE jest.
func quotesArray(maxItems, minItems int) map[string]any {
	return map[string]any{
		"type": "array",
		"items": map[string]any{
			"type": "object",
			"properties": map[string]any{
				"span_id": map[string]any{"type": "string"},
				"quote": map[string]any{
					"type": "string", "maxLength": int64(600),
					"description": "Kopiuj 1:1 z fragmentu, W ORYGINALNYM JEZYKU wypowiedzi.",
				},
			},
			"required": []any{"span_id", "quote"},
		},
		"minItems": int64(minItems),
		"maxItems": int64(maxItems),
	}
}

// ConstructsForStage zwraca posortowane identyfikatory konstruktow, dla
// ktorych warto wywolac S2.
//
// Kompozyty sa na razie pomijane: ich obsluga (M1, sloty typowane)
// wymaga innego ksztaltu schematu i wchodzi osobnym ticketem. Pominiecie
// jest JAWNE, zeby nie wygladalo na kompletne pokrycie taksonomii.
func (o *Ontology) ConstructsForStage() (categories []string, skippedComposites []string) {
	for _, id := range o.ConstructIDs() {
		c := o.Constructs[id]
		if c == nil {
			continue
		}
		if c.Kind == KindComposite {
			skippedComposites = append(skippedComposites, id)
			continue
		}
		categories = append(categories, id)
	}
	sort.Strings(categories)
	sort.Strings(skippedComposites)
	return categories, skippedComposites
}
