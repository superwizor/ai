package chat

import (
	"context"
	"encoding/json"
	"strings"
	"sync"
	"testing"

	"github.com/google/uuid"
	"github.com/superwizor-ai/backend/pkg/appconfig"
)

type recordingTracker struct {
	mu     sync.Mutex
	events []TelemetryEvent
}

func (r *recordingTracker) Track(_ context.Context, e TelemetryEvent) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.events = append(r.events, e)
}

func (r *recordingTracker) names() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]string, 0, len(r.events))
	for _, e := range r.events {
		out = append(out, e.Name)
	}
	return out
}

func (r *recordingTracker) byName(n string) (TelemetryEvent, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, e := range r.events {
		if e.Name == n {
			return e, true
		}
	}
	return TelemetryEvent{}, false
}

func has(list []string, want string) bool {
	for _, s := range list {
		if s == want {
			return true
		}
	}
	return false
}

func withTracker(h *harness) *recordingTracker {
	tr := &recordingTracker{}
	h.svc.Telemetry = tr
	return tr
}

// The generative-usage event is what measures the drift the ADR names as
// residual risk. It must fire on A8 and carry the grounding count.
func TestClinicalGeneratedEventCarriesGroundingCount(t *testing.T) {
	segs := sampleSegments()
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A8_CONCEPT","confidence":0.95,"risk_flag":false}`,
		`{"hypotheses":[{"title":"H","body":"b","quotes":[{"session_id":"` + segs[0].SessionID.String() +
			`","segment_id":"` + segs[0].ID.String() + `","text":"W pracy czuję ciągłe napięcie"}]}]}`,
		`{"violation":false,"code":"none"}`,
	}, segs)
	tr := withTracker(h)

	turnReq := turn()
	turnReq.Question = "Jak rozumieć jej napięcie w pracy?"
	out, err := h.svc.Ask(context.Background(), turnReq)
	if err != nil || out.Kind != OutcomeAnswered {
		t.Fatalf("Ask: %v outcome=%v", err, out.Kind)
	}

	ev, ok := tr.byName(EventClinicalGenerated)
	if !ok {
		t.Fatalf("no %s event; got %v", EventClinicalGenerated, tr.names())
	}
	if n, _ := ev.Properties["grounding_quote_count"].(int); n != 1 {
		t.Errorf("grounding_quote_count = %v, want 1", ev.Properties["grounding_quote_count"])
	}
	if ev.Properties["verifier_result"] != "pass" {
		t.Errorf("verifier_result = %v", ev.Properties["verifier_result"])
	}
}

// A pure extract must NOT count as generated clinical content, or the
// 60% drift threshold measures the wrong thing.
func TestExtractiveAnswerDoesNotFireClinicalGenerated(t *testing.T) {
	segs := sampleSegments()
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A1_SEARCH","confidence":0.95,"risk_flag":false}`,
		`{"sections":[{"title":"Praca","body":"b","quotes":[{"session_id":"` + segs[0].SessionID.String() +
			`","segment_id":"` + segs[0].ID.String() + `","text":"W pracy czuję ciągłe napięcie"}]}]}`,
		`{"violation":false,"code":"none"}`,
	}, segs)
	tr := withTracker(h)

	if _, err := h.svc.Ask(context.Background(), turn()); err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if has(tr.names(), EventClinicalGenerated) {
		t.Error("an extractive A1 answer fired the generative-usage event")
	}
	if !has(tr.names(), EventQueryClassified) {
		t.Errorf("no classification event; got %v", tr.names())
	}
}

func TestRefusalAndBlockEmitTheirEvents(t *testing.T) {
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"P1_DIAG","confidence":0.97,"risk_flag":false}`,
	}, sampleSegments())
	tr := withTracker(h)
	if _, err := h.svc.Ask(context.Background(), turn()); err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if !has(tr.names(), EventRefused) {
		t.Errorf("no refusal event; got %v", tr.names())
	}

	segs := sampleSegments()
	h2 := newHarness(t, enabledConfig(), []string{
		`{"intent":"A8_CONCEPT","confidence":0.95,"risk_flag":false}`,
		`{"hypotheses":[{"title":"H","body":"b","quotes":[{"session_id":"` + segs[0].SessionID.String() +
			`","segment_id":"` + segs[0].ID.String() + `","text":"wymyślony cytat"}]}]}`,
	}, segs)
	tr2 := withTracker(h2)
	tq := turn()
	tq.Question = "Jak rozumieć jej napięcie w pracy?"
	if _, err := h2.svc.Ask(context.Background(), tq); err != nil {
		t.Fatalf("Ask: %v", err)
	}
	ev, ok := tr2.byName(EventVerifierBlock)
	if !ok {
		t.Fatalf("no verifier-block event; got %v", tr2.names())
	}
	if ev.Properties["block_reason"] != "fabricated" {
		t.Errorf("block_reason = %v", ev.Properties["block_reason"])
	}
}

func TestStarterUsedEventFires(t *testing.T) {
	h := newHarness(t, enabledConfig(), []string{
		`{"sections":[{"title":"S","body":"x"}]}`,
	}, sampleSegments())
	tr := withTracker(h)
	tq := turn()
	tq.StarterID = "attendance"

	if _, err := h.svc.Ask(context.Background(), tq); err != nil {
		t.Fatalf("Ask: %v", err)
	}
	ev, ok := tr.byName(EventStarterUsed)
	if !ok {
		t.Fatalf("no starter event; got %v", tr.names())
	}
	if ev.Properties["starter_id"] != "attendance" || ev.Properties["edited"] != false {
		t.Errorf("starter properties: %+v", ev.Properties)
	}
}

// Telemetry must carry codes and counts, never conversation content. The
// analytics pipeline has neither the retention rules nor the access
// controls for clinical material.
func TestTelemetryCarriesNoConversationContent(t *testing.T) {
	segs := sampleSegments()
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A8_CONCEPT","confidence":0.95,"risk_flag":false,"rationale_short":"prosi o konceptualizacje napiecia"}`,
		`{"hypotheses":[{"title":"Napięcie w pracy","body":"Możliwe, że napięcie chroni ją przed oceną.","quotes":[{"session_id":"` +
			segs[0].SessionID.String() + `","segment_id":"` + segs[0].ID.String() +
			`","text":"W pracy czuję ciągłe napięcie"}]}]}`,
		`{"violation":false,"code":"none"}`,
	}, segs)
	tr := withTracker(h)

	tq := turn()
	tq.Question = "Jak rozumieć jej napięcie w pracy?"
	if _, err := h.svc.Ask(context.Background(), tq); err != nil {
		t.Fatalf("Ask: %v", err)
	}

	blob, _ := json.Marshal(tr.events)
	for _, leak := range []string{
		tq.Question,
		"W pracy czuję ciągłe napięcie",
		"chroni ją przed oceną",
		"prosi o konceptualizacje",
		tq.PatientFileID.String(),
	} {
		if strings.Contains(string(blob), leak) {
			t.Errorf("telemetry leaked conversation content: %q", leak)
		}
	}
}

// A nil tracker must not panic — telemetry is optional configuration.
func TestNilTrackerIsSafe(t *testing.T) {
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"P1_DIAG","confidence":0.97,"risk_flag":false}`,
	}, sampleSegments())
	h.svc.Telemetry = nil
	if _, err := h.svc.Ask(context.Background(), turn()); err != nil {
		t.Fatalf("Ask: %v", err)
	}
}

// Every event name in the ADR's section 7.1 list must exist as a
// constant, or a dashboard panel silently watches nothing.
func TestEventNamesMatchTheADR(t *testing.T) {
	want := []string{
		"ai_chat_query_classified", "ai_chat_refused", "ai_chat_degraded",
		"ai_chat_clinical_generated", "ai_chat_verifier_block",
		"ai_chat_template_field_filled", "ai_chat_kill_switch_changed",
		"ai_chat_starter_used",
	}
	got := map[string]bool{
		EventQueryClassified: true, EventRefused: true, EventDegraded: true,
		EventClinicalGenerated: true, EventVerifierBlock: true,
		EventTemplateField: true, EventKillSwitchChanged: true, EventStarterUsed: true,
	}
	for _, w := range want {
		if !got[w] {
			t.Errorf("ADR section 7.1 names %q but no constant produces it", w)
		}
	}
}

// The kill switch must be readable per organization so one tenant can be
// restricted without touching the rest.
func TestKillSwitchIsPerOrganizationCapable(t *testing.T) {
	org := uuid.New()
	cfg := append(enabledConfig(), row{key: appconfig.KeyAIChatEnabled, value: "false", org: &org})
	h := newHarness(t, cfg, nil, sampleSegments())

	tq := turn()
	tq.OrganizationID = org
	if _, err := h.svc.Ask(context.Background(), tq); err == nil {
		t.Error("org override did not disable the chat for that org")
	}

	tq2 := turn()
	if _, err := h.svc.Ask(context.Background(), tq2); err == ErrChatDisabled {
		t.Error("org override leaked to a different caller")
	}
}
