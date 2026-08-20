package guardrail

import "fmt"

// Output schemas, one per allowed intent.
//
// # These schemas ARE the guardrail
//
// The classifier decides which schema is used; the schema decides what
// can come back. Everything else — the prompt, the refusal text, the
// verifier — is defence in depth around this one mechanism.
//
// The rule that makes it work is enforcement by absence: a field the
// model must not fill DOES NOT EXIST in the schema handed to the model.
// Not "exists and is validated", not "exists with an instruction not to
// use it" — absent. A therapist's conclusion cannot be forged by a model
// that has no field to write it into, no matter how the question was
// phrased or what the prompt was talked into.
//
// The corollary is that user-only fields are added by the SERVER after
// validation, empty, for the therapist to fill. See UserOnlyFields.
//
// # Grounding
//
// Generative intents (A8-A10) require at least one verbatim quote per
// hypothesis, expressed as minItems: 1 on the quotes array. A hypothesis
// without evidence is not "discouraged" — it is structurally
// unrepresentable. The verifier then checks each quote is a literal
// substring of a real decrypted segment, so the constraint cannot be
// satisfied with a plausible-looking invention.

// quoteRefSchema is the model's view of a citation. The model supplies
// only pointers and the verbatim span; the server resolves speaker,
// timestamps and session date from the database. The model is therefore
// unable to fabricate metadata, only to be wrong about a segment ID —
// which the deterministic verifier catches immediately.
var quoteRefSchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"session_id": map[string]any{"type": "string"},
		"segment_id": map[string]any{"type": "string"},
		"text": map[string]any{
			"type":        "string",
			"description": "Dosłowny fragment segmentu, skopiowany znak w znak. Nie parafrazuj.",
		},
	},
	"required": []any{"session_id", "segment_id", "text"},
}

func quotesArray(min int64) map[string]any {
	m := map[string]any{
		"type":  "array",
		"items": quoteRefSchema,
		// Gorny limit to kontrola ROZMIARU wyjscia, nie kosmetyka.
		// 20.08.2026 dwie tury na produkcji (A8 17:42, A7 18:29) zostaly
		// zablokowane kodem 'schema': bez limitu model doklejal dlugie
		// cytaty, az odpowiedz przekroczyla MaxTokens i JSON zostal
		// uciety w polowie. Trzy dobre cytaty uzasadniaja hipoteze tak
		// samo jak siedem, a mieszcza sie w budzecie.
		"maxItems": int64(3),
	}
	if min > 0 {
		m["minItems"] = min
	}
	return m
}

// hypothesisSchema is the shape every generative intent produces. Note
// what is NOT here: no certainty score, no diagnosis field, no
// recommendation field, and no place for a conclusion. A hypothesis is a
// statement plus its evidence, and nothing else.
var hypothesisSchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		// maxLength na polach prozy to kontrola rozmiaru wyjscia, ta sama
		// klasa co maxItems na cytatach. 20.08.2026 19:01 tura A8 chciala
		// >4096 tokenow wyjscia (nieograniczone body x 5 hipotez, soczewka
		// PPT zapraszala do glebi) — nawet ponowienie z podwojonym
		// budzetem wyszlo uciete i tura skonczyla sie blokiem 'schema'.
		"title": map[string]any{"type": "string", "maxLength": int64(120)},
		"body": map[string]any{
			"type":        "string",
			"maxLength":   int64(900),
			"description": "Hipoteza sformułowana warunkowo, 3-6 zdań. Bez etykiet diagnostycznych, bez leków, bez oceny ryzyka.",
		},
		// minItems 1: this is the grounding requirement.
		"quotes": quotesArray(1),
	},
	"required": []any{"title", "body", "quotes"},
}

func sectionsSchema(minQuotesPerSection int64) map[string]any {
	return map[string]any{
		"type":     "array",
		"maxItems": int64(6),
		"items": map[string]any{
			"type": "object",
			"properties": map[string]any{
				"title":  map[string]any{"type": "string", "maxLength": int64(120)},
				"body":   map[string]any{"type": "string", "maxLength": int64(900)},
				"quotes": quotesArray(minQuotesPerSection),
			},
			"required": []any{"title", "body", "quotes"},
		},
	}
}

// schemas maps each servable intent to the schema handed to the model.
//
// A2_FACTS and A6_ADMIN are absent on purpose: they are answered from SQL
// with no model call at all. An intent with no schema and no executor
// must never silently fall through to a generic prose call, which is why
// SchemaFor reports absence rather than returning a permissive default.
var schemas = map[Intent]map[string]any{
	A1Search: {
		"type": "object",
		"properties": map[string]any{
			// Every A1 section must cite: a search result with no quote
			// is a claim about the transcript, not a finding in it.
			"sections": sectionsSchema(1),
		},
		"required": []any{"sections"},
	},

	A3Format: {
		"type": "object",
		"properties": map[string]any{
			"sections": sectionsSchema(0),
		},
		"required": []any{"sections"},
	},

	// A4_EDU is the one intent with no client material in its input, and
	// correspondingly the one with no quotes in its output: there is
	// nothing to cite, because nothing about the client was retrieved.
	A4Edu: {
		"type": "object",
		"properties": map[string]any{
			"sections": map[string]any{
				"type": "array",
				"items": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"title": map[string]any{"type": "string", "maxLength": int64(120)},
						"body":  map[string]any{"type": "string", "maxLength": int64(900)},
					},
					"required": []any{"title", "body"},
				},
				"maxItems": int64(6),
			},
		},
		"required": []any{"sections"},
	},

	// A5_SUPERVISION_PACK is where the authorship boundary was first widened
	// deliberately (ADR v1.2). suggested_questions is model-authored and
	// grounded; open_questions belongs to the therapist and is therefore
	// ABSENT here — the server appends it empty after validation.
	A5Prep: {
		"type": "object",
		"properties": map[string]any{
			"sections": sectionsSchema(0),
			"suggested_questions": map[string]any{
				"type": "array",
				"items": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"question": map[string]any{
							"type":        "string",
							"maxLength":   int64(200),
							"description": "Pytanie do rozważenia. Nie może zawierać etykiety diagnostycznej, leku ani oceny ryzyka.",
						},
						"quotes": quotesArray(1),
					},
					"required": []any{"question", "quotes"},
				},
				"maxItems": int64(3),
			},
		},
		"required": []any{"sections"},
	},

	A7Template: {
		"type": "object",
		"properties": map[string]any{
			"sections": sectionsSchema(1),
		},
		"required": []any{"sections"},
	},

	A8Concept: {
		"type": "object",
		"properties": map[string]any{
			"hypotheses": map[string]any{
				"type": "array", "items": hypothesisSchema, "minItems": int64(1), "maxItems": int64(3),
			},
		},
		"required": []any{"hypotheses"},
	},

	A9Progress: {
		"type": "object",
		"properties": map[string]any{
			"hypotheses": map[string]any{
				"type": "array", "items": hypothesisSchema, "minItems": int64(1), "maxItems": int64(3),
			},
			// Required, not optional: A9 is the intent most likely to be
			// read as a prediction, and the ADR requires forward-looking
			// statements to be conditional. Making the caveat mandatory
			// is cheaper than hoping the prose stays hedged.
			"caveats": map[string]any{
				"type":        "array",
				"items":       map[string]any{"type": "string", "maxLength": int64(200)},
				"minItems":    int64(1),
				"maxItems":    int64(4),
				"description": "Ograniczenia wnioskowania. Wymagane.",
			},
		},
		"required": []any{"hypotheses", "caveats"},
	},

	A10Intervention: {
		"type": "object",
		"properties": map[string]any{
			"hypotheses": map[string]any{
				"type": "array", "items": hypothesisSchema, "minItems": int64(1), "maxItems": int64(3),
			},
		},
		"required": []any{"hypotheses"},
	},
}

// SchemaFor returns the model schema for an intent, and reports whether
// one exists. Absence is meaningful: A2/A6 are answered without a model,
// and prohibited intents have no schema at all.
func SchemaFor(i Intent) (map[string]any, bool) {
	s, ok := schemas[i]
	return s, ok
}

// UserOnlyFields lists the fields the SERVER appends after validation,
// empty, for the therapist to own. None of them appear in the schema
// above — that is the entire mechanism.
//
// Keyed by intent so the executor knows what to append; the values are
// section titles rendered with kind USER_ONLY and user_authored = true.
var UserOnlyFields = map[Intent][]string{
	// The therapist's own reading of the material.
	A8Concept: {"conclusion"},
	// What the therapist decides to do; the model proposes, it does not
	// decide.
	A10Intervention: {"decision"},
	// The therapist's own questions, distinct from the model's
	// suggested_questions (ADR v1.2).
	A5Prep: {"open_questions"},
	// The therapist's assessment of progress.
	A9Progress: {"conclusion"},
	// A7 template mapping: the model fills categories, the therapist
	// writes the conclusion.
	A7Template: {"conclusion"},
}

// ProhibitedFieldNames are field names that must never appear in any
// model schema. Asserted by a test over every schema, so adding a
// well-meaning "diagnosis" or "recommended_medication" field to a schema
// fails CI rather than shipping.
var ProhibitedFieldNames = []string{
	"diagnosis", "diagnoza", "icd", "dsm",
	"medication", "lek", "leki", "dawka", "dosage",
	"risk_level", "ryzyko", "suicide", "suicidality",
	// Therapist-owned fields: present in the RESPONSE, never in the
	// schema the model sees.
	"conclusion", "decision", "open_questions",
}

// RequiresGrounding reports whether every generated unit for this intent
// must carry at least one quote. Used by the verifier as a cross-check
// against the schema, so a schema edit that dropped minItems would be
// caught by a second, independent rule rather than silently permitted.
func RequiresGrounding(i Intent) bool { return i.Generative() || i == A1Search || i == A7Template }

// ValidateSchemaShape checks a schema for the invariants this package
// depends on. Run over every registered schema by TestSchemaInvariants;
// exported so a future schema loaded from elsewhere gets the same check.
func ValidateSchemaShape(i Intent, schema map[string]any) error {
	var walk func(node map[string]any, path string) error
	walk = func(node map[string]any, path string) error {
		props, _ := node["properties"].(map[string]any)
		for name, raw := range props {
			for _, bad := range ProhibitedFieldNames {
				if equalFold(name, bad) {
					return fmt.Errorf("%s: schema exposes prohibited field %q at %s", i, name, path)
				}
			}
			sub, ok := raw.(map[string]any)
			if !ok {
				continue
			}
			if err := walk(sub, path+"."+name); err != nil {
				return err
			}
		}
		if items, ok := node["items"].(map[string]any); ok {
			if err := walk(items, path+"[]"); err != nil {
				return err
			}
		}
		return nil
	}
	return walk(schema, string(i))
}

func equalFold(a, b string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := 0; i < len(a); i++ {
		ca, cb := a[i], b[i]
		if 'A' <= ca && ca <= 'Z' {
			ca += 'a' - 'A'
		}
		if 'A' <= cb && cb <= 'Z' {
			cb += 'a' - 'A'
		}
		if ca != cb {
			return false
		}
	}
	return true
}
