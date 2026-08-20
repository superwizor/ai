// Package guardrail implements the three-layer control described in ADR
// docs/kronikarz/62 (v1.3): an intent classifier, a router that decides
// what the system is permitted to do with that intent, and a verifier
// that inspects the finished response before it is shown.
//
// # Why a package and not a service
//
// The ADR budgets p95 <= 1.5 s for a complete turn, which already spends
// up to three model calls. A network hop to a separate guardrail service
// does not fit in what is left. This runs in-process in clinical-svc.
//
// # The control is structural, not instructional
//
// The layer that actually stops a prohibited answer is not the prompt. It
// is the schema: a field the model has no way to emit cannot be emitted,
// however the question was phrased. Prompts drift, get argued with, and
// lose to a sufficiently determined rephrasing. The classifier and the
// router decide WHICH schema is used; that decision is what this package
// exists to make correctly.
package guardrail

// Intent is the classification taxonomy from ADR section 5.4 (v1.1).
//
// The string values are stable identifiers: they appear in the eval
// datasets (guardrail-evals/), in guardrail_decisions rows kept for 24
// months as the MDR article 94 evidence pack, and in telemetry. Renaming
// one silently invalidates the historical record, so they are frozen.
type Intent string

const (
	// ── ALLOWED, extractive ──────────────────────────────────────
	// These reproduce, count, or reorganize material that already
	// exists. They add no new clinical claim about the client.

	// A1Search finds where a topic was discussed and quotes it.
	A1Search Intent = "A1_SEARCH"
	// A2Stats answers with computed numbers: session counts,
	// attendance, gaps. Served from SQL with no model call at all.
	A2Stats Intent = "A2_FACTS"
	// A3Format renders existing material into a document shape.
	A3Format Intent = "A3_FORMAT"
	// A4Edu answers a general professional question. The defining
	// property is the ABSENCE of client context: no patient material
	// is retrieved or sent, which is enforced in code and covered by
	// a negative test. A question about a specific client is A8, not
	// A4, however educationally it is phrased.
	A4Edu Intent = "A4_EDU"
	// A5Prep prepares for an upcoming session.
	A5Prep Intent = "A5_SUPERVISION_PACK"
	// A6Admin covers administrative lookups.
	A6Admin Intent = "A6_ADMIN"
	// A7Template maps existing material onto a named model or template.
	A7Template Intent = "A7_TEMPLATE_MAP"

	// ── ALLOWED, generative and grounded (decision D1) ────────────
	// These DO produce new clinical information about a specific
	// client. That was decided deliberately on 2026-08-20 and named
	// as residual risk in ADR section 9. Every one of them is
	// constrained the same way: hypotheses only, each carrying at
	// least one verbatim quote, marked as AI-generated in the UI.

	// A8Concept is case conceptualization: how the material might be
	// understood. Distinguished from P1Diag by the KIND of statement,
	// not the topic — a model of what maintains a difficulty is A8; a
	// nosological label for it is P1.
	A8Concept Intent = "A8_CONCEPT"
	// A9Progress assesses change over time. Any forward-looking
	// statement must be conditional; the schema requires caveats.
	A9Progress Intent = "A9_PROGRESS"
	// A10Intervention proposes therapeutic directions to consider.
	A10Intervention Intent = "A10_TREAT"

	// ── PROHIBITED ────────────────────────────────────────────────

	// P1Diag is a nosological diagnosis: assigning or confirming a
	// classification (ICD/DSM), or answering "does the client have X".
	P1Diag Intent = "P1_DIAG"
	// P2Med is pharmacotherapy: recommending, adjusting, or assessing
	// medication.
	P2Med Intent = "P2_MED"
	// RRisk is risk or crisis assessment: suicidality, self-harm,
	// danger to others, decompensation. Never answered, at any
	// confidence, under any framing.
	RRisk Intent = "R_RISK"
	// XOther is outside the product's scope entirely.
	XOther Intent = "X_OTHER"
)

// AllIntents is every label, in taxonomy order. Used by the eval runner
// and by exhaustiveness tests.
var AllIntents = []Intent{
	A1Search, A2Stats, A3Format, A4Edu, A5Prep, A6Admin, A7Template,
	A8Concept, A9Progress, A10Intervention,
	P1Diag, P2Med, RRisk, XOther,
}

// Allowed reports whether the intent may be served at all.
func (i Intent) Allowed() bool {
	switch i {
	case A1Search, A2Stats, A3Format, A4Edu, A5Prep, A6Admin, A7Template,
		A8Concept, A9Progress, A10Intervention:
		return true
	}
	return false
}

// Generative reports whether serving this intent produces new clinical
// information about the client, as opposed to reproducing existing
// material. These are the intents that carry the MDR exposure named in
// ADR section 9, and the ones defined_ops mode removes.
func (i Intent) Generative() bool {
	switch i {
	case A8Concept, A9Progress, A10Intervention:
		return true
	}
	return false
}

// Prohibited reports whether the intent is refused on category grounds.
func (i Intent) Prohibited() bool {
	switch i {
	case P1Diag, P2Med, RRisk, XOther:
		return true
	}
	return false
}

// Valid reports whether s is a known label — used when parsing classifier
// output, where an unrecognized string must be handled, not trusted.
func Valid(s string) bool {
	for _, i := range AllIntents {
		if string(i) == s {
			return true
		}
	}
	return false
}

// degradeTo maps a generative intent to the extractive operation that
// replaces it when the system will not generate: low classifier
// confidence, defined_ops mode, or an exhausted quota.
//
// The replacement is never "nothing". A therapist who asked for a
// conceptualization and gets the relevant quotes instead has been given
// less, but has not been stonewalled — which is the difference between a
// safety measure people work with and one they work around.
var degradeTo = map[Intent]Intent{
	A8Concept:       A7Template, // model-mapped material instead of a new model
	A9Progress:      A2Stats,    // the numbers instead of an interpretation
	A10Intervention: A7Template, // what the material already contains
}

// DegradeTarget returns the extractive stand-in for a generative intent,
// and reports whether one exists. Non-generative intents have no target:
// they are already extractive and are served unchanged.
func DegradeTarget(i Intent) (Intent, bool) {
	t, ok := degradeTo[i]
	return t, ok
}
