package guardrail

import "fmt"

// Mode mirrors appconfig's chat modes. Duplicated as a local type rather
// than imported so this package stays dependency-free and unit-testable
// without a database.
type Mode string

const (
	ModeFull       Mode = "full"
	ModeDefinedOps Mode = "defined_ops"
)

// Action is what the router decided to do.
type Action int

const (
	// ActionAnswer serves the classified intent as asked.
	ActionAnswer Action = iota
	// ActionDegrade serves a reduced operation instead. Decision.Intent
	// holds what will actually run.
	ActionDegrade
	// ActionRefuse serves no operation. Decision.Refusal explains why.
	ActionRefuse
)

func (a Action) String() string {
	switch a {
	case ActionAnswer:
		return "answer"
	case ActionDegrade:
		return "degrade"
	case ActionRefuse:
		return "refuse"
	}
	return "unknown"
}

// Reason codes. These are logged and appear on telemetry, so they are
// stable strings rather than a bare enum.
const (
	ReasonLowConfidence = "low_conf"
	ReasonDefinedOps    = "defined_ops"
	ReasonQuota         = "quota"
	ReasonRiskFlag      = "risk_flag"
	ReasonProhibited    = "prohibited"
	ReasonOutOfScope    = "out_of_scope"
	ReasonUnknownIntent = "unknown_intent"
)

// Classification is the classifier's verdict on one question.
type Classification struct {
	Intent     Intent
	Confidence float64

	// RiskFlag marks the question as touching risk, crisis, suicidality,
	// self-harm or danger to others — INDEPENDENTLY of Intent. A question
	// can be a perfectly ordinary A1 search whose subject is risk, and
	// that combination must refuse. This is a separate signal precisely
	// so it cannot be lost in a close call between two intent labels.
	RiskFlag bool

	// RationaleShort is the classifier's one-line justification. It is
	// kept for evaluation and debugging and is NEVER written to
	// production logs or to guardrail_decisions: it paraphrases the
	// therapist's question, which would turn an evidence log into a
	// shadow copy of the conversation.
	RationaleShort string
}

// Decision is the router's output.
type Decision struct {
	Action Action
	// Intent is the operation that will actually run. For ActionAnswer
	// it equals the classified intent; for ActionDegrade it is the
	// stand-in; for ActionRefuse it is the classified intent, so the
	// refusal can name what was refused.
	Intent Intent
	// OriginalIntent is always what the classifier said.
	OriginalIntent Intent
	// Reason is set for degradations and refusals.
	Reason string
	// Alternatives are the constructive offers shown with a refusal.
	Alternatives []Alternative
	// ShowCrisisInformation is set only for risk refusals.
	ShowCrisisInformation bool
	// ConfidenceBucket is the coarse confidence for telemetry.
	ConfidenceBucket string
}

// Alternative is one offered next step on a refusal.
type Alternative struct {
	// Intent the alternative would run as. Empty for offers that leave
	// the chat entirely (for example, consulting a supervisor).
	Intent Intent
	// LabelKey is an i18n key, not display text — this package must not
	// decide what language the therapist reads.
	LabelKey string
	// PrefillKey is the i18n key for the pre-filled composer text.
	PrefillKey string
}

// Router applies the decision table. It holds no state beyond its
// configuration and is safe to construct per request.
type Router struct {
	// Tau is the confidence threshold below which the router degrades.
	// Read from app_config so it can be recalibrated without a deploy
	// (F8 calibrates it on a precision/recall curve).
	Tau float64
	// Mode is the effective chat mode for this caller.
	Mode Mode
	// QuotaExhausted forces the same restriction as defined_ops. Passed
	// in rather than looked up so the router stays free of I/O.
	QuotaExhausted bool
}

// Route decides what to do with a classification.
//
// The order of the checks IS the policy, and it is not arbitrary:
//
//  1. Unknown label — a classifier that returned something we cannot
//     interpret is a failure, and a failure must not fall through into
//     an allowed branch.
//  2. Risk flag — before anything else that could serve an answer,
//     independent of intent and of confidence. There is no confidence
//     high enough, and no intent benign enough, to answer a question
//     about risk.
//  3. Prohibited category — refuse with a redirect.
//  4. Restriction (defined_ops or exhausted quota) — degrade generative
//     intents.
//  5. Low confidence — degrade.
//  6. Otherwise answer.
//
// Putting confidence last matters: a LOW-confidence R_RISK still
// refuses, because step 2 already ran. Reversing 2 and 5 would let an
// uncertain risk question degrade into an answered one, which is the
// single worst failure this system could have.
func (r Router) Route(c Classification) Decision {
	d := Decision{
		OriginalIntent:   c.Intent,
		Intent:           c.Intent,
		ConfidenceBucket: Bucket(c.Confidence),
	}

	// 1. Unrecognized label: refuse, do not guess.
	if !Valid(string(c.Intent)) {
		d.Action = ActionRefuse
		d.Intent = XOther
		d.OriginalIntent = XOther
		d.Reason = ReasonUnknownIntent
		d.Alternatives = alternativesFor(XOther)
		return d
	}

	// 2. Risk flag beats everything.
	if c.RiskFlag {
		d.Action = ActionRefuse
		d.Reason = ReasonRiskFlag
		d.ShowCrisisInformation = true
		d.Alternatives = alternativesFor(RRisk)
		return d
	}

	// 3. Prohibited categories.
	if c.Intent.Prohibited() {
		d.Action = ActionRefuse
		switch c.Intent {
		case RRisk:
			d.Reason = ReasonRiskFlag
			d.ShowCrisisInformation = true
		case XOther:
			d.Reason = ReasonOutOfScope
		default:
			d.Reason = ReasonProhibited
		}
		d.Alternatives = alternativesFor(c.Intent)
		return d
	}

	// 4. Restricted mode: no generation.
	restricted := r.Mode == ModeDefinedOps || r.QuotaExhausted
	if restricted && c.Intent.Generative() {
		target, ok := DegradeTarget(c.Intent)
		if !ok {
			// Unreachable while degradeTo covers every generative
			// intent, and asserted by TestEveryGenerativeIntentDegrades.
			// Refusing rather than answering is the safe branch if that
			// ever stops being true.
			d.Action = ActionRefuse
			d.Reason = ReasonDefinedOps
			return d
		}
		d.Action = ActionDegrade
		d.Intent = target
		d.Reason = ReasonDefinedOps
		if r.QuotaExhausted {
			d.Reason = ReasonQuota
		}
		return d
	}

	// 5. Low confidence.
	if c.Confidence < r.Tau {
		if target, ok := DegradeTarget(c.Intent); ok {
			d.Action = ActionDegrade
			d.Intent = target
			d.Reason = ReasonLowConfidence
			return d
		}
		// Already extractive: serve it, but mark the turn degraded so
		// the telemetry shows how often the classifier is unsure. The
		// operation itself adds no clinical claim, so restricting it
		// further would cost the therapist an answer and buy nothing.
		d.Action = ActionDegrade
		d.Reason = ReasonLowConfidence
		return d
	}

	// 6. Serve it.
	d.Action = ActionAnswer
	return d
}

// alternativesFor returns the constructive offers for a refusal.
//
// A refusal that only says no gets routed around. P1 in particular has a
// legitimate neighbour: the therapist who asked for a diagnosis can be
// offered a conceptualization, which is the operation they are actually
// permitted to have. That redirect is measured (ADR section 8.3 targets
// 30% acceptance).
func alternativesFor(i Intent) []Alternative {
	switch i {
	case P1Diag:
		return []Alternative{
			{Intent: A8Concept, LabelKey: "chat.alt.conceptualization", PrefillKey: "chat.prefill.conceptualization"},
			{Intent: A1Search, LabelKey: "chat.alt.find_quotes", PrefillKey: "chat.prefill.find_quotes"},
		}
	case P2Med:
		return []Alternative{
			{Intent: A1Search, LabelKey: "chat.alt.find_quotes", PrefillKey: "chat.prefill.find_quotes"},
			{LabelKey: "chat.alt.consult_physician"},
		}
	case RRisk:
		// Deliberately NOT offering an in-chat alternative. A risk
		// question is redirected to a person and to crisis resources,
		// never to another operation of the same system.
		return []Alternative{
			{LabelKey: "chat.alt.crisis_resources"},
			{LabelKey: "chat.alt.consult_supervisor"},
		}
	case XOther:
		return []Alternative{
			{LabelKey: "chat.alt.scope_explainer"},
		}
	}
	return nil
}

// Bucket coarsens a confidence score for telemetry and for the evidence
// log. The raw score is a model artefact whose third decimal invites
// over-reading; buckets keep the log honest about how much it knows.
func Bucket(c float64) string {
	switch {
	case c < 0:
		return "invalid"
	case c < 0.5:
		return "very_low"
	case c < 0.7:
		return "low"
	case c < 0.85:
		return "medium"
	case c <= 1.0:
		return "high"
	default:
		return "invalid"
	}
}

// String renders a decision for debugging. Carries no question content.
func (d Decision) String() string {
	return fmt.Sprintf("%s intent=%s original=%s reason=%s bucket=%s",
		d.Action, d.Intent, d.OriginalIntent, d.Reason, d.ConfidenceBucket)
}
