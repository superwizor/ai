package guardrail

import (
	"fmt"
	"strings"
)

// Therapist-authored document templates (plan F10, decision D7).
//
// # A template composes sections; it does not save a prompt
//
// The request this answers is "let me save how I like my documents and
// reuse it across clients". The obvious implementation — store the prompt,
// replay it — was rejected, and the reason is the same one the rest of
// this package rests on: a prompt is negotiable and a schema is not.
//
// A saved prompt would:
//
//   - bypass the schema layer, which is what actually stops a prohibited
//     answer (section 4.1);
//   - create a generative surface the classifier never inspects, because
//     the prompt reaches the model through a path that was never
//     classified;
//   - propagate whatever it encodes between therapists once shared,
//     making one clinician's shortcut the manufacturer's liability.
//
// So a template is a list of TYPED sections. Each type maps onto an
// executor the guardrail already governs, and there is no section type
// that produces a diagnosis, a medication statement or a risk assessment.
// The prohibited categories are not blocked here; they are unreachable.
//
// # instructions is a focus hint, not an instruction channel
//
// A generative section may carry up to 500 characters of `instructions`.
// It reaches the model as USER CONTENT, never as a system prompt:
// freedom about WHAT to look at, none about which rules apply. The schema
// still requires a quote per hypothesis, and the verifier still runs.
//
// # Validation happens at save time
//
// A template that could request a prohibited operation is refused when it
// is written, while its author is present to be told why — not silently
// at run time, months later, to a different clinician who forked it.

// SectionType is one composable unit of a template.
type SectionType string

const (
	// SectionExtract finds and quotes material on a topic (A1).
	SectionExtract SectionType = "extract"
	// SectionQuotes maps quotes onto named categories (A7).
	SectionQuotes SectionType = "quotes"
	// SectionSummary summarizes session material (A5).
	SectionSummary SectionType = "summary"
	// SectionStats computes numbers from SQL (A2). No model call.
	SectionStats SectionType = "stats"
	// SectionUserOnly is a field the therapist fills. It is absent from
	// every schema handed to the model.
	SectionUserOnly SectionType = "user_only"
	// SectionGenerativeGrounded produces grounded hypotheses (A8-A10).
	SectionGenerativeGrounded SectionType = "generative_grounded"
)

// sectionIntent maps a section type onto the intent that executes it.
// Every value is ALLOWED — that is the invariant that makes prohibited
// operations unreachable through a template, and it is asserted by
// TestEverySectionTypeMapsToAnAllowedIntent.
var sectionIntent = map[SectionType]Intent{
	SectionExtract:            A1Search,
	SectionQuotes:             A7Template,
	SectionSummary:            A5Prep,
	SectionStats:              A2Stats,
	SectionGenerativeGrounded: A8Concept,
	// SectionUserOnly has no intent: nothing runs, the server emits an
	// empty field.
}

// IntentFor returns the executor for a section type.
func IntentFor(t SectionType) (Intent, bool) {
	i, ok := sectionIntent[t]
	return i, ok
}

// TemplateSection is one section of a template as authored.
type TemplateSection struct {
	Type  SectionType `json:"type"`
	Title string      `json:"title"`
	// Instructions is the focus hint. Permitted only on
	// SectionGenerativeGrounded: on an extractive section there is
	// nothing for it to steer, and accepting it there would create the
	// impression that free text influences those paths.
	Instructions string `json:"instructions,omitempty"`
}

// Limits on authored content.
const (
	MaxTemplateSections   = 12
	MaxTemplateTitleChars = 120
	MaxInstructionChars   = 500
	MaxTemplateNameChars  = 80
)

// ValidateTemplateSections checks a template at SAVE time.
//
// It performs the structural checks only. The semantic check — whether an
// `instructions` string is asking for a diagnosis in prose — is a
// classifier call, made by the caller, because this package holds no
// model client. Both are required: this one cannot read Polish, and the
// classifier cannot see that a section type is missing.
func ValidateTemplateSections(sections []TemplateSection) error {
	if len(sections) == 0 {
		return fmt.Errorf("template: needs at least one section")
	}
	if len(sections) > MaxTemplateSections {
		return fmt.Errorf("template: %d sections, maximum is %d", len(sections), MaxTemplateSections)
	}

	var producesSomething bool
	for i, s := range sections {
		if _, known := sectionIntent[s.Type]; !known && s.Type != SectionUserOnly {
			return fmt.Errorf("template: section %d has unknown type %q", i, s.Type)
		}
		if strings.TrimSpace(s.Title) == "" {
			return fmt.Errorf("template: section %d has no title", i)
		}
		if len(s.Title) > MaxTemplateTitleChars {
			return fmt.Errorf("template: section %d title is %d chars, maximum is %d",
				i, len(s.Title), MaxTemplateTitleChars)
		}
		if s.Type != SectionUserOnly {
			producesSomething = true
		}

		if s.Instructions != "" {
			if s.Type != SectionGenerativeGrounded {
				return fmt.Errorf(
					"template: section %d of type %q carries instructions; only %q accepts them",
					i, s.Type, SectionGenerativeGrounded)
			}
			if len(s.Instructions) > MaxInstructionChars {
				return fmt.Errorf("template: section %d instructions are %d chars, maximum is %d",
					i, len(s.Instructions), MaxInstructionChars)
			}
		}
	}

	// A template of nothing but user_only fields is a form, not a
	// document the system produces. Allowing it would let the feature be
	// used as a generic note editor with none of the provenance the
	// version pinning exists to provide.
	if !producesSomething {
		return fmt.Errorf("template: needs at least one section the system produces")
	}
	return nil
}

// TemplateClassificationTargets returns the strings a caller must put
// through the classifier before accepting a template.
//
// Only the free text is returned. Titles are not classified: they are
// labels the therapist reads, they never reach the model, and running
// them through a classifier would produce refusals on section names like
// "Ryzyko nawrotu" that describe a heading rather than request an
// assessment.
func TemplateClassificationTargets(sections []TemplateSection) []string {
	var out []string
	for _, s := range sections {
		if t := strings.TrimSpace(s.Instructions); t != "" {
			out = append(out, t)
		}
	}
	return out
}

// TemplateSectionRejected reports that a section was refused at save time.
type TemplateSectionRejected struct {
	SectionIndex int
	Intent       Intent
	RiskFlag     bool
}

func (e TemplateSectionRejected) Error() string {
	if e.RiskFlag {
		return fmt.Sprintf("template: section %d asks for a risk assessment", e.SectionIndex)
	}
	switch e.Intent {
	case P1Diag:
		return fmt.Sprintf("template: section %d asks for a nosological diagnosis", e.SectionIndex)
	case P2Med:
		return fmt.Sprintf("template: section %d asks about pharmacotherapy", e.SectionIndex)
	case RRisk:
		return fmt.Sprintf("template: section %d asks for a risk assessment", e.SectionIndex)
	}
	return fmt.Sprintf("template: section %d requests an operation outside the template's scope", e.SectionIndex)
}

// CheckTemplateInstruction decides whether one classified instruction may
// be saved.
//
// The bar is HIGHER than for a chat turn. A chat question is asked once
// by the person who wrote it; a template runs repeatedly, across clients,
// and can be shared. So a prohibited classification is refused regardless
// of confidence — there is no degradation path, because there is no user
// waiting for an answer to degrade.
func CheckTemplateInstruction(index int, c Classification) error {
	if c.RiskFlag {
		return TemplateSectionRejected{SectionIndex: index, RiskFlag: true}
	}
	if c.Intent.Prohibited() {
		return TemplateSectionRejected{SectionIndex: index, Intent: c.Intent}
	}
	// An unrecognized label is refused too: an instruction the classifier
	// could not interpret must not become a permanent, shareable artefact.
	if !Valid(string(c.Intent)) {
		return TemplateSectionRejected{SectionIndex: index, Intent: XOther}
	}
	return nil
}
