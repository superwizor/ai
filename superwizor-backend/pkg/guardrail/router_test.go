package guardrail

import (
	"fmt"
	"testing"
)

const tau = 0.85

func full() Router      { return Router{Tau: tau, Mode: ModeFull} }
func defined() Router   { return Router{Tau: tau, Mode: ModeDefinedOps} }
func exhausted() Router { return Router{Tau: tau, Mode: ModeFull, QuotaExhausted: true} }

// ── The property that matters most ────────────────────────────────────

// A risk flag refuses at every intent, every confidence, every mode.
// This is the exhaustive form of "risk_flag honoured independently of
// intent and confidence" from ADR section 5.4 — not a spot check.
func TestRiskFlagRefusesEverywhere(t *testing.T) {
	confidences := []float64{0.0, 0.3, 0.5, 0.84, 0.85, 0.99, 1.0}
	routers := map[string]Router{"full": full(), "defined_ops": defined(), "quota": exhausted()}

	for _, intent := range AllIntents {
		for _, conf := range confidences {
			for name, r := range routers {
				t.Run(fmt.Sprintf("%s/conf=%.2f/%s", intent, conf, name), func(t *testing.T) {
					d := r.Route(Classification{Intent: intent, Confidence: conf, RiskFlag: true})
					if d.Action != ActionRefuse {
						t.Fatalf("risk_flag produced %s, want refuse (%s)", d.Action, d)
					}
					if !d.ShowCrisisInformation {
						t.Error("risk refusal must surface crisis information")
					}
				})
			}
		}
	}
}

// Low confidence must never turn a risk question into an answered one.
// This is the ordering bug the router's step order exists to prevent.
func TestLowConfidenceRiskStillRefuses(t *testing.T) {
	d := full().Route(Classification{Intent: A1Search, Confidence: 0.01, RiskFlag: true})
	if d.Action != ActionRefuse {
		t.Fatalf("got %s, want refuse", d)
	}
	if d.Reason != ReasonRiskFlag {
		t.Errorf("reason = %q, want %q", d.Reason, ReasonRiskFlag)
	}
}

// A benign-looking intent whose subject is risk must refuse: the flag is
// a separate signal precisely so a close intent call cannot lose it.
func TestBenignIntentWithRiskSubjectRefuses(t *testing.T) {
	for _, i := range []Intent{A1Search, A2Stats, A6Admin, A4Edu} {
		d := full().Route(Classification{Intent: i, Confidence: 0.99, RiskFlag: true})
		if d.Action != ActionRefuse {
			t.Errorf("%s with risk subject: got %s, want refuse", i, d.Action)
		}
	}
}

// ── Prohibited categories ─────────────────────────────────────────────

func TestProhibitedCategoriesRefuse(t *testing.T) {
	for _, i := range []Intent{P1Diag, P2Med, RRisk, XOther} {
		for _, conf := range []float64{0.1, 0.86, 1.0} {
			d := full().Route(Classification{Intent: i, Confidence: conf})
			if d.Action != ActionRefuse {
				t.Errorf("%s at conf %.2f: got %s, want refuse", i, conf, d.Action)
			}
			if d.OriginalIntent != i {
				t.Errorf("refusal lost the intent: %s", d.OriginalIntent)
			}
		}
	}
}

// P1 must offer conceptualization: the therapist asking for a diagnosis
// has a legitimate neighbouring operation, and a refusal with no door is
// a refusal people route around.
func TestP1OffersConceptualization(t *testing.T) {
	d := full().Route(Classification{Intent: P1Diag, Confidence: 0.95})
	var found bool
	for _, alt := range d.Alternatives {
		if alt.Intent == A8Concept {
			found = true
		}
	}
	if !found {
		t.Errorf("P1 refusal must offer A8_CONCEPT, got %+v", d.Alternatives)
	}
}

// A risk refusal must NOT offer another operation of the same system.
func TestRiskRefusalOffersNoInChatAlternative(t *testing.T) {
	d := full().Route(Classification{Intent: RRisk, Confidence: 0.99})
	for _, alt := range d.Alternatives {
		if alt.Intent != "" {
			t.Errorf("risk refusal offered in-chat intent %s; must redirect to a person", alt.Intent)
		}
	}
	if !d.ShowCrisisInformation {
		t.Error("risk refusal must surface crisis information")
	}
}

// A label the classifier invented must refuse, not fall through.
func TestUnknownIntentRefuses(t *testing.T) {
	for _, bogus := range []Intent{"", "A11_SOMETHING", "allowed", "A1"} {
		d := full().Route(Classification{Intent: bogus, Confidence: 1.0})
		if d.Action != ActionRefuse {
			t.Errorf("bogus label %q: got %s, want refuse", bogus, d.Action)
		}
		if d.Reason != ReasonUnknownIntent {
			t.Errorf("bogus label %q: reason %q, want %q", bogus, d.Reason, ReasonUnknownIntent)
		}
	}
}

// ── Degradation ───────────────────────────────────────────────────────

func TestDefinedOpsDegradesGenerativeIntents(t *testing.T) {
	want := map[Intent]Intent{A8Concept: A7Template, A9Progress: A2Stats, A10Intervention: A7Template}
	for from, to := range want {
		d := defined().Route(Classification{Intent: from, Confidence: 1.0})
		if d.Action != ActionDegrade {
			t.Errorf("%s in defined_ops: got %s, want degrade", from, d.Action)
		}
		if d.Intent != to {
			t.Errorf("%s degraded to %s, want %s", from, d.Intent, to)
		}
		if d.Reason != ReasonDefinedOps {
			t.Errorf("%s reason %q, want %q", from, d.Reason, ReasonDefinedOps)
		}
	}
}

// Extractive intents are untouched by defined_ops — that mode removes
// generation, it does not shut the chat down.
func TestDefinedOpsLeavesExtractiveIntentsAlone(t *testing.T) {
	for _, i := range []Intent{A1Search, A2Stats, A3Format, A4Edu, A5Prep, A6Admin, A7Template} {
		d := defined().Route(Classification{Intent: i, Confidence: 1.0})
		if d.Action != ActionAnswer {
			t.Errorf("%s in defined_ops: got %s, want answer", i, d.Action)
		}
		if d.Intent != i {
			t.Errorf("%s was rewritten to %s", i, d.Intent)
		}
	}
}

func TestExhaustedQuotaDegradesLikeDefinedOpsButSaysWhy(t *testing.T) {
	d := exhausted().Route(Classification{Intent: A8Concept, Confidence: 1.0})
	if d.Action != ActionDegrade || d.Intent != A7Template {
		t.Fatalf("got %s, want degrade to A7_TEMPLATE", d)
	}
	if d.Reason != ReasonQuota {
		t.Errorf("reason = %q, want %q — the therapist needs to know it was budget, not policy", d.Reason, ReasonQuota)
	}
}

func TestLowConfidenceDegradesGenerative(t *testing.T) {
	for from, to := range map[Intent]Intent{A8Concept: A7Template, A9Progress: A2Stats, A10Intervention: A7Template} {
		d := full().Route(Classification{Intent: from, Confidence: 0.84})
		if d.Action != ActionDegrade || d.Intent != to {
			t.Errorf("%s at conf 0.84: got %s, want degrade to %s", from, d, to)
		}
		if d.Reason != ReasonLowConfidence {
			t.Errorf("%s reason %q, want %q", from, d.Reason, ReasonLowConfidence)
		}
	}
}

// Exactly at tau the intent is served: the threshold is "below tau
// degrades", and an off-by-one here silently degrades a slice of traffic.
func TestConfidenceThresholdIsInclusiveAtTau(t *testing.T) {
	if d := full().Route(Classification{Intent: A8Concept, Confidence: tau}); d.Action != ActionAnswer {
		t.Errorf("conf == tau: got %s, want answer", d)
	}
	if d := full().Route(Classification{Intent: A8Concept, Confidence: tau - 0.0001}); d.Action != ActionDegrade {
		t.Errorf("conf just below tau: got %s, want degrade", d)
	}
}

// An uncertain extractive intent is still served — it adds no clinical
// claim — but the turn is marked degraded so telemetry sees the doubt.
func TestLowConfidenceExtractiveIsServedButMarked(t *testing.T) {
	d := full().Route(Classification{Intent: A1Search, Confidence: 0.5})
	if d.Action != ActionDegrade {
		t.Fatalf("got %s, want degrade (marked)", d)
	}
	if d.Intent != A1Search {
		t.Errorf("intent rewritten to %s; extractive intents keep their operation", d.Intent)
	}
	if d.Reason != ReasonLowConfidence {
		t.Errorf("reason = %q", d.Reason)
	}
}

// ── Happy path ────────────────────────────────────────────────────────

func TestConfidentAllowedIntentsAreAnswered(t *testing.T) {
	for _, i := range AllIntents {
		if !i.Allowed() {
			continue
		}
		d := full().Route(Classification{Intent: i, Confidence: 0.99})
		if d.Action != ActionAnswer {
			t.Errorf("%s: got %s, want answer", i, d.Action)
		}
	}
}

// ── Invariants over the whole table ───────────────────────────────────

// No input may ever produce an answer for a prohibited category. This is
// the invariant the entire package exists to hold, asserted over the
// full cross-product rather than trusted to the branch order.
func TestNoInputEverAnswersAProhibitedIntent(t *testing.T) {
	routers := []Router{full(), defined(), exhausted(), {Tau: 0, Mode: ModeFull}, {Tau: 1.0, Mode: ModeFull}}
	for _, i := range []Intent{P1Diag, P2Med, RRisk, XOther} {
		for _, conf := range []float64{-1, 0, 0.5, 0.85, 1.0, 2.0} {
			for _, risk := range []bool{false, true} {
				for ri, r := range routers {
					d := r.Route(Classification{Intent: i, Confidence: conf, RiskFlag: risk})
					if d.Action != ActionRefuse {
						t.Fatalf("router[%d] %s conf=%.2f risk=%v produced %s — prohibited intent served",
							ri, i, conf, risk, d.Action)
					}
				}
			}
		}
	}
}

// The router must never emit a decision whose effective intent is
// prohibited or generative-when-restricted.
func TestDecisionIntentIsNeverServableAndProhibited(t *testing.T) {
	routers := []Router{full(), defined(), exhausted()}
	for _, i := range AllIntents {
		for _, conf := range []float64{0, 0.5, 0.9, 1.0} {
			for _, risk := range []bool{false, true} {
				for _, r := range routers {
					d := r.Route(Classification{Intent: i, Confidence: conf, RiskFlag: risk})
					if d.Action == ActionRefuse {
						continue
					}
					if d.Intent.Prohibited() {
						t.Fatalf("%s served a prohibited effective intent %s", d.Action, d.Intent)
					}
					restricted := r.Mode == ModeDefinedOps || r.QuotaExhausted
					if restricted && d.Intent.Generative() {
						t.Fatalf("restricted router served generative intent %s", d.Intent)
					}
				}
			}
		}
	}
}

// Every generative intent needs a degradation target; without one the
// router's fallback refuses, silently removing a legitimate operation.
func TestEveryGenerativeIntentDegrades(t *testing.T) {
	for _, i := range AllIntents {
		if !i.Generative() {
			continue
		}
		target, ok := DegradeTarget(i)
		if !ok {
			t.Errorf("generative intent %s has no degradation target", i)
			continue
		}
		if target.Generative() {
			t.Errorf("%s degrades to %s, which is itself generative", i, target)
		}
		if !target.Allowed() {
			t.Errorf("%s degrades to non-allowed %s", i, target)
		}
	}
}

// Taxonomy partition: every intent is exactly one of allowed/prohibited.
func TestTaxonomyIsAPartition(t *testing.T) {
	for _, i := range AllIntents {
		if i.Allowed() == i.Prohibited() {
			t.Errorf("%s: Allowed=%v Prohibited=%v — must be exactly one", i, i.Allowed(), i.Prohibited())
		}
		if i.Generative() && !i.Allowed() {
			t.Errorf("%s is generative but not allowed", i)
		}
	}
	if len(AllIntents) != 14 {
		t.Errorf("taxonomy has %d intents, ADR section 5.4 defines 14", len(AllIntents))
	}
}

func TestBucket(t *testing.T) {
	cases := map[float64]string{
		-0.1: "invalid", 0: "very_low", 0.49: "very_low", 0.5: "low",
		0.69: "low", 0.7: "medium", 0.84: "medium", 0.85: "high",
		1.0: "high", 1.1: "invalid",
	}
	for in, want := range cases {
		if got := Bucket(in); got != want {
			t.Errorf("Bucket(%v) = %q, want %q", in, got, want)
		}
	}
}
