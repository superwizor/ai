package chat

import "github.com/superwizor-ai/backend/pkg/guardrail"

// Starter prompts shown on first open and on an empty chat (ADR v1.3
// section 6).
//
// # Why a server-side registry
//
// The composition — which starters are on, and in what order — comes from
// app_config, so it changes without an app release. That lesson is
// expensive and recent: Google Play has been stuck on 1.0.3 since
// 2026-07-23, and anything that needs a release to change is effectively
// frozen for however long that takes.
//
// # Why they may skip the classifier
//
// An UNEDITED starter has a known intent from this registry and wording
// that was written and reviewed here. Classifying it spends a model call
// (~$0.0003 and 200-400 ms) to re-derive a constant. The moment the
// therapist edits the text, the registry no longer describes what was
// asked, and it is classified like anything else.
//
// The safety of that shortcut rests entirely on every entry below being
// an ALLOWED intent with risk_flag false by construction — asserted by
// TestStartersAreAllowedByConstruction.
//
// # Naming
//
// Deliberately NOT called "suggested questions": A5's
// suggested_questions are model-authored, grounded and verified.
// These are curated product copy. Confusing the two would put curated
// text through a grounding check it cannot pass, or model text through
// none at all.
type Starter struct {
	// ID is stable; it appears in the ai_chat_starter_used telemetry and
	// in the claims register.
	ID string
	// Intent this starter is known to be.
	Intent guardrail.Intent
	// LabelKey is the i18n key for the chip text. The text itself lives
	// in the .arb files, never here — the backend must not decide what
	// language a therapist reads.
	LabelKey string
	// PrefillKey is the i18n key for the editable text inserted into the
	// composer when the chip is tapped.
	PrefillKey string
}

// starters is the full registry. Every entry is an ALLOWED, non-risk
// intent; nothing here can classify to P1/P2/R because nothing here is
// routed through a classifier in the first place.
var starters = []Starter{
	{
		ID: "recent_themes", Intent: guardrail.A1Search,
		LabelKey: "chat.starter.recent_themes", PrefillKey: "chat.starter.recent_themes.prefill",
	},
	{
		ID: "session_prep", Intent: guardrail.A5Prep,
		LabelKey: "chat.starter.session_prep", PrefillKey: "chat.starter.session_prep.prefill",
	},
	{
		ID: "attendance", Intent: guardrail.A2Stats,
		LabelKey: "chat.starter.attendance", PrefillKey: "chat.starter.attendance.prefill",
	},
	{
		ID: "conceptualization", Intent: guardrail.A8Concept,
		LabelKey: "chat.starter.conceptualization", PrefillKey: "chat.starter.conceptualization.prefill",
	},
	{
		ID: "progress", Intent: guardrail.A9Progress,
		LabelKey: "chat.starter.progress", PrefillKey: "chat.starter.progress.prefill",
	},
	{
		ID: "directions", Intent: guardrail.A10Intervention,
		LabelKey: "chat.starter.directions", PrefillKey: "chat.starter.directions.prefill",
	},
}

// StarterByID looks up a starter. Returns false for an ID the client
// invented, which sends the text through the classifier — the safe
// branch, since an unknown ID means the shortcut's premise does not hold.
func StarterByID(id string) (Starter, bool) {
	for _, s := range starters {
		if s.ID == id {
			return s, true
		}
	}
	return Starter{}, false
}

// AllStarters returns the registry in declaration order.
func AllStarters() []Starter {
	out := make([]Starter, len(starters))
	copy(out, starters)
	return out
}
