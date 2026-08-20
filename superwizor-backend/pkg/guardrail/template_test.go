package guardrail

import (
	"strings"
	"testing"
)

func validTemplate() []TemplateSection {
	return []TemplateSection{
		{Type: SectionSummary, Title: "Przebieg"},
		{Type: SectionExtract, Title: "Kluczowe wątki"},
		{Type: SectionGenerativeGrounded, Title: "Rozumienie przypadku",
			Instructions: "Skup się na tym, co podtrzymuje trudność w relacjach zawodowych."},
		{Type: SectionUserOnly, Title: "Mój wniosek"},
	}
}

// ── The invariant that makes templates safe ───────────────────────────

// Every section type must map onto an ALLOWED intent. This is what makes
// prohibited operations unreachable through a template rather than merely
// blocked: there is no composition of sections that produces one.
func TestEverySectionTypeMapsToAnAllowedIntent(t *testing.T) {
	for st, intent := range sectionIntent {
		if !intent.Allowed() {
			t.Errorf("section type %q maps to non-allowed intent %s", st, intent)
		}
		if intent.Prohibited() {
			t.Errorf("section type %q maps to PROHIBITED intent %s", st, intent)
		}
	}
	// user_only must map to nothing: it runs no operation at all.
	if _, ok := sectionIntent[SectionUserOnly]; ok {
		t.Error("user_only maps to an intent; it must execute nothing")
	}
}

func TestValidTemplateIsAccepted(t *testing.T) {
	if err := ValidateTemplateSections(validTemplate()); err != nil {
		t.Fatalf("valid template rejected: %v", err)
	}
}

// ── Structural refusals ───────────────────────────────────────────────

// An extractive section must not carry free text. Accepting it would
// suggest the text steers those paths, which it does not.
func TestInstructionsOnlyOnGenerativeSections(t *testing.T) {
	for _, st := range []SectionType{SectionExtract, SectionQuotes, SectionSummary, SectionStats, SectionUserOnly} {
		err := ValidateTemplateSections([]TemplateSection{
			{Type: SectionGenerativeGrounded, Title: "OK", Instructions: "cokolwiek"},
			{Type: st, Title: "X", Instructions: "przemycona instrukcja"},
		})
		if err == nil {
			t.Errorf("section type %q accepted instructions", st)
		}
	}
}

func TestOverlongInstructionsRejected(t *testing.T) {
	err := ValidateTemplateSections([]TemplateSection{
		{Type: SectionGenerativeGrounded, Title: "T",
			Instructions: strings.Repeat("a", MaxInstructionChars+1)},
	})
	if err == nil {
		t.Fatal("over-long instructions accepted")
	}
}

func TestUnknownSectionTypeRejected(t *testing.T) {
	err := ValidateTemplateSections([]TemplateSection{
		{Type: "diagnosis", Title: "Rozpoznanie"},
	})
	if err == nil {
		t.Fatal("unknown section type accepted")
	}
}

// A template of nothing but therapist fields is a form, not a document
// the system produces — and would use the provenance machinery for
// something that has no provenance.
func TestTemplateOfOnlyUserFieldsRejected(t *testing.T) {
	err := ValidateTemplateSections([]TemplateSection{
		{Type: SectionUserOnly, Title: "A"},
		{Type: SectionUserOnly, Title: "B"},
	})
	if err == nil {
		t.Fatal("all-user_only template accepted")
	}
}

func TestEmptyAndOversizedTemplatesRejected(t *testing.T) {
	if err := ValidateTemplateSections(nil); err == nil {
		t.Error("empty template accepted")
	}
	var many []TemplateSection
	for i := 0; i <= MaxTemplateSections; i++ {
		many = append(many, TemplateSection{Type: SectionSummary, Title: "S"})
	}
	if err := ValidateTemplateSections(many); err == nil {
		t.Error("oversized template accepted")
	}
}

func TestSectionNeedsATitle(t *testing.T) {
	if err := ValidateTemplateSections([]TemplateSection{{Type: SectionSummary, Title: "   "}}); err == nil {
		t.Error("untitled section accepted")
	}
}

// ── Semantic refusals ─────────────────────────────────────────────────

// Only the free text is classified. Titles are labels the therapist
// reads; they never reach the model, and classifying them would refuse
// perfectly ordinary headings.
func TestOnlyInstructionsAreClassified(t *testing.T) {
	targets := TemplateClassificationTargets([]TemplateSection{
		{Type: SectionExtract, Title: "Ryzyko nawrotu"},
		{Type: SectionGenerativeGrounded, Title: "Rozumienie", Instructions: "co podtrzymuje unikanie"},
	})
	if len(targets) != 1 || targets[0] != "co podtrzymuje unikanie" {
		t.Fatalf("classification targets = %v; only instructions should be classified", targets)
	}
}

// The bar for a template is higher than for a chat turn: it runs
// repeatedly, across clients, and can be shared. So a prohibited
// classification is refused at ANY confidence — there is no user waiting
// for an answer, so there is nothing to degrade.
func TestProhibitedInstructionRefusedAtEveryConfidence(t *testing.T) {
	for _, intent := range []Intent{P1Diag, P2Med, RRisk, XOther} {
		for _, conf := range []float64{0.0, 0.5, 0.86, 1.0} {
			err := CheckTemplateInstruction(2, Classification{Intent: intent, Confidence: conf})
			if err == nil {
				t.Errorf("%s at confidence %.2f accepted into a template", intent, conf)
			}
		}
	}
}

func TestRiskFlaggedInstructionRefusedWhateverTheIntent(t *testing.T) {
	for _, intent := range AllIntents {
		err := CheckTemplateInstruction(0, Classification{Intent: intent, Confidence: 1.0, RiskFlag: true})
		if err == nil {
			t.Errorf("risk-flagged instruction accepted under intent %s", intent)
		}
	}
}

// An instruction the classifier could not interpret must not become a
// permanent, shareable artefact.
func TestUnrecognizedInstructionRefused(t *testing.T) {
	if err := CheckTemplateInstruction(0, Classification{Intent: "SOMETHING", Confidence: 1.0}); err == nil {
		t.Error("unrecognized classification accepted into a template")
	}
}

func TestAllowedInstructionAccepted(t *testing.T) {
	for _, intent := range []Intent{A1Search, A5Prep, A8Concept, A9Progress, A10Intervention} {
		if err := CheckTemplateInstruction(0, Classification{Intent: intent, Confidence: 0.9}); err != nil {
			t.Errorf("allowed intent %s refused: %v", intent, err)
		}
	}
}

// The refusal must say WHICH section and WHY — a template editor that
// reports "invalid" leaves the author guessing which of twelve sections
// to change.
func TestRefusalNamesTheSectionAndTheReason(t *testing.T) {
	err := CheckTemplateInstruction(3, Classification{Intent: P1Diag, Confidence: 0.9})
	if err == nil {
		t.Fatal("want refusal")
	}
	msg := err.Error()
	if !strings.Contains(msg, "3") {
		t.Errorf("refusal does not name the section: %q", msg)
	}
	if !strings.Contains(msg, "diagnosis") {
		t.Errorf("refusal does not name the reason: %q", msg)
	}
}

// A generative section in a template gets the same schema — and
// therefore the same grounding requirement — as the chat path. Templates
// must not be a second-class route to the same executors.
func TestGenerativeSectionUsesTheGuardedSchema(t *testing.T) {
	intent, ok := IntentFor(SectionGenerativeGrounded)
	if !ok {
		t.Fatal("generative section has no intent")
	}
	if !intent.Generative() {
		t.Fatalf("generative section maps to %s, which is not generative", intent)
	}
	schema, ok := SchemaFor(intent)
	if !ok {
		t.Fatal("no schema for the generative section's intent")
	}
	hyp := schema["properties"].(map[string]any)["hypotheses"].(map[string]any)
	quotes := hyp["items"].(map[string]any)["properties"].(map[string]any)["quotes"].(map[string]any)
	if min, _ := quotes["minItems"].(int64); min < 1 {
		t.Error("a template's generative section could produce an ungrounded hypothesis")
	}
}
