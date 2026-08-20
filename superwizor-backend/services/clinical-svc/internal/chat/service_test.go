package chat

import (
	"context"
	"encoding/json"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/superwizor-ai/backend/pkg/appconfig"
	"github.com/superwizor-ai/backend/pkg/guardrail"
)

// ── scripted LLM ──────────────────────────────────────────────────────

type scriptedLLM struct {
	mu sync.Mutex
	// responses keyed by call ordinal.
	responses []string
	calls     []GenerateRequest
	embedVec  []float32
	embedErr  error
}

func (l *scriptedLLM) Generate(_ context.Context, req GenerateRequest) (GenerateResponse, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	idx := len(l.calls)
	l.calls = append(l.calls, req)
	text := `{}`
	if idx < len(l.responses) {
		text = l.responses[idx]
	}
	return GenerateResponse{Text: text, Model: req.Model,
		Usage: Usage{InputTokens: 500, OutputTokens: 100}}, nil
}

func (l *scriptedLLM) Embed(_ context.Context, _ string) ([]float32, Usage, error) {
	if l.embedErr != nil {
		return nil, Usage{}, l.embedErr
	}
	return l.embedVec, Usage{InputTokens: 10}, nil
}

func (l *scriptedLLM) allPrompts() string {
	l.mu.Lock()
	defer l.mu.Unlock()
	var b strings.Builder
	for _, c := range l.calls {
		b.WriteString(c.SystemPrompt)
		b.WriteString("\n")
		b.WriteString(c.UserContent)
		b.WriteString("\n")
	}
	return b.String()
}

// ── fake pool ─────────────────────────────────────────────────────────

type fakePool struct {
	segments []Segment
	stats    SessionStats
	queries  []string
	mu       sync.Mutex
}

func (p *fakePool) record(sql string) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.queries = append(p.queries, sql)
}

func (p *fakePool) queried(substr string) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	for _, q := range p.queries {
		if strings.Contains(q, substr) {
			return true
		}
	}
	return false
}

func (p *fakePool) Query(_ context.Context, sql string, _ ...any) (Rows, error) {
	p.record(sql)
	switch {
	case strings.Contains(sql, "FROM sessions s"):
		return &sessionRows{segs: p.segments}, nil
	case strings.Contains(sql, "FROM transcript_segments"):
		return &segIndexRows{segs: p.segments}, nil
	}
	return &emptyRows{}, nil
}

func (p *fakePool) QueryRow(_ context.Context, sql string, _ ...any) RowScanner {
	p.record(sql)
	if strings.Contains(sql, "count(*) FILTER") {
		st := p.stats
		return scanFunc(func(d ...any) error {
			*(d[0].(*int)) = st.SessionCount
			*(d[1].(**time.Time)) = &st.FirstSessionAt
			*(d[2].(**time.Time)) = &st.LastSessionAt
			*(d[3].(*int)) = st.CancelledCount
			*(d[4].(*int)) = st.TotalMinutes
			*(d[5].(*int)) = st.ReportsAvailable
			return nil
		})
	}
	return scanFunc(func(d ...any) error {
		if len(d) == 1 {
			if p, ok := d[0].(*int); ok {
				*p = 0
				return nil
			}
		}
		return nil
	})
}

// sessionRows yields one session carrying every segment as a blob.
type sessionRows struct {
	segs []Segment
	done bool
}

func (r *sessionRows) Next() bool { done := r.done; r.done = true; return !done && len(r.segs) > 0 }
func (r *sessionRows) Scan(dest ...any) error {
	lines := make([]blobLine, 0, len(r.segs))
	for _, s := range r.segs {
		lbl := s.Speaker
		lines = append(lines, blobLine{
			Text: s.Text, StartMS: int64(s.TsStartMs), EndMS: int64(s.TsEndMs), SpeakerLabel: &lbl,
		})
	}
	blob, _ := json.Marshal(lines)
	*(dest[0].(*uuid.UUID)) = r.segs[0].SessionID
	*(dest[1].(*time.Time)) = r.segs[0].SessionAt
	*(dest[2].(*uuid.UUID)) = uuid.New()
	*(dest[3].(*[]byte)) = blob
	*(dest[4].(*[]byte)) = []byte("dek")
	return nil
}
func (r *sessionRows) Err() error { return nil }
func (r *sessionRows) Close()     {}

type segIndexRows struct {
	segs []Segment
	i    int
}

func (r *segIndexRows) Next() bool { r.i++; return r.i <= len(r.segs) }
func (r *segIndexRows) Scan(dest ...any) error {
	s := r.segs[r.i-1]
	*(dest[0].(*uuid.UUID)) = s.ID
	*(dest[1].(*int32)) = s.TsStartMs
	*(dest[2].(*string)) = s.Speaker
	return nil
}
func (r *segIndexRows) Err() error { return nil }
func (r *segIndexRows) Close()     {}

type emptyRows struct{}

func (emptyRows) Next() bool        { return false }
func (emptyRows) Scan(...any) error { return nil }
func (emptyRows) Err() error        { return nil }
func (emptyRows) Close()            {}

// passthroughCrypto returns the ciphertext unchanged — the fake blob is
// already plaintext JSON.
type passthroughCrypto struct {
	calls int
	mu    sync.Mutex
}

func (c *passthroughCrypto) Decrypt(_ context.Context, ct, _ []byte) ([]byte, error) {
	c.mu.Lock()
	c.calls++
	c.mu.Unlock()
	return ct, nil
}

// ── harness ───────────────────────────────────────────────────────────

type harness struct {
	svc    Service
	llm    *scriptedLLM
	pool   *fakePool
	db     *fakeQuotaDB
	crypto *passthroughCrypto
	recs   *recordingLog
}

type recordingLog struct {
	mu   sync.Mutex
	rows []DecisionRecord
}

func (l *recordingLog) Record(_ context.Context, d DecisionRecord) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.rows = append(l.rows, d)
	return nil
}

func (l *recordingLog) last() DecisionRecord {
	l.mu.Lock()
	defer l.mu.Unlock()
	if len(l.rows) == 0 {
		return DecisionRecord{}
	}
	return l.rows[len(l.rows)-1]
}

func newHarness(t *testing.T, cfgRows []row, responses []string, segs []Segment) *harness {
	t.Helper()
	llm := &scriptedLLM{responses: responses}
	pool := &fakePool{segments: segs}
	crypto := &passthroughCrypto{}
	db := newFakeDB(1_500_000, fixedNow)
	recs := &recordingLog{}

	return &harness{
		llm: llm, pool: pool, db: db, crypto: crypto, recs: recs,
		svc: Service{
			LLM:       llm,
			Retriever: Retriever{Pool: pool, Crypto: crypto},
			Quota:     Quota{DB: db, Now: fixedNow},
			Config:    appconfig.NewReader(&cfgDB{rows: cfgRows}),
			Decisions: recs,
			Now:       fixedNow,
		},
	}
}

// cfgDB is a tiny appconfig.Querier.
type cfgDB struct{ rows []row }

type row struct {
	key, value string
	org        *uuid.UUID
}

func (c *cfgDB) Query(context.Context, string, ...any) (appconfig.Rows, error) {
	return &cfgRows{rows: c.rows}, nil
}

type cfgRows struct {
	rows []row
	i    int
}

func (r *cfgRows) Next() bool { r.i++; return r.i <= len(r.rows) }
func (r *cfgRows) Scan(dest ...any) error {
	cur := r.rows[r.i-1]
	*(dest[0].(*string)) = cur.key
	*(dest[1].(*string)) = cur.value
	*(dest[2].(**uuid.UUID)) = cur.org
	return nil
}
func (r *cfgRows) Err() error { return nil }
func (r *cfgRows) Close()     {}

func enabledConfig() []row {
	return []row{
		{key: appconfig.KeyAIChatEnabled, value: "true"},
		{key: appconfig.KeyAIChatMode, value: "full"},
		{key: appconfig.KeyAIChatClassifierTau, value: "0.85"},
		{key: appconfig.KeyAIChatQuotaMicroUSD, value: "1500000"},
	}
}

func sampleSegments() []Segment {
	sess := uuid.New()
	at := time.Date(2026, 8, 1, 10, 0, 0, 0, time.UTC)
	return []Segment{
		{ID: uuid.New(), SessionID: sess, Text: "W pracy czuję ciągłe napięcie i nie umiem odpuścić.",
			Speaker: "KLIENT", TsStartMs: 1000, TsEndMs: 5000, SessionAt: at},
		{ID: uuid.New(), SessionID: sess, Text: "Z matką rozmawiam rzadko, zwykle kończy się awanturą.",
			Speaker: "KLIENT", TsStartMs: 6000, TsEndMs: 9000, SessionAt: at},
	}
}

func turn() Turn {
	return Turn{
		TherapistID: uuid.New(), PatientFileID: uuid.New(),
		ConversationID: uuid.New(), Question: "Kiedy mówiła o pracy?", Platform: "web",
	}
}

// ── THE test ──────────────────────────────────────────────────────────

// A4_EDU must never receive client material. The ADR makes the ABSENCE of
// client context the defining property of the intent, and the plan (F3)
// requires this exact negative test.
//
// It checks two things, because either alone would be weak: that no
// retrieval query ran, and that nothing recognizable from the transcript
// appears in any prompt sent to the model.
func TestEducationNeverReceivesClientContext(t *testing.T) {
	segs := sampleSegments()
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A4_EDU","confidence":0.95,"risk_flag":false}`,
		`{"sections":[{"title":"Ekspozycja","body":"Ekspozycja to systematyczne konfrontowanie."}]}`,
		`{"violation":false,"code":"none"}`,
	}, segs)

	tr := turn()
	tr.Question = "Czym różni się ekspozycja od desensytyzacji?"
	out, err := h.svc.Ask(context.Background(), tr)
	if err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if out.Kind != OutcomeAnswered {
		t.Fatalf("outcome = %v, want answered", out.Kind)
	}

	// 1. No transcript was read.
	if h.pool.queried("transcript_ciphertext") {
		t.Error("A4_EDU loaded transcripts")
	}
	if h.crypto.calls != 0 {
		t.Errorf("A4_EDU performed %d decryptions", h.crypto.calls)
	}

	// 2. No client material reached any prompt.
	prompts := h.llm.allPrompts()
	for _, s := range segs {
		if strings.Contains(prompts, s.Text) {
			t.Errorf("client transcript text reached the model under A4_EDU: %q", s.Text)
		}
	}
	if strings.Contains(prompts, tr.PatientFileID.String()) {
		t.Error("patient file ID reached the model under A4_EDU")
	}
}

// ── Pipeline order ────────────────────────────────────────────────────

// A disabled chat must cost zero model calls.
func TestKillSwitchRefusesBeforeAnyModelCall(t *testing.T) {
	h := newHarness(t, []row{{key: appconfig.KeyAIChatEnabled, value: "false"}}, nil, sampleSegments())
	out, err := h.svc.Ask(context.Background(), turn())
	if err == nil {
		t.Fatal("want ErrChatDisabled")
	}
	if out.Kind != OutcomeUnavailable {
		t.Errorf("outcome = %v", out.Kind)
	}
	if len(h.llm.calls) != 0 {
		t.Errorf("%d model calls made while chat was disabled", len(h.llm.calls))
	}
}

// An exhausted quota must degrade, not lock the therapist out, and must
// not have spent a model call to discover the exhaustion.
func TestExhaustedQuotaDegradesToExtractive(t *testing.T) {
	segs := sampleSegments()
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A8_CONCEPT","confidence":0.95,"risk_flag":false}`,
		`{"sections":[{"title":"Materiał","body":"x","quotes":[{"session_id":"` + segs[0].SessionID.String() +
			`","segment_id":"` + segs[0].ID.String() + `","text":"W pracy czuję ciągłe napięcie"}]}]}`,
		`{"violation":false,"code":"none"}`,
	}, segs)
	// Drain the budget.
	h.db.used = h.db.limit

	out, err := h.svc.Ask(context.Background(), turn())
	if err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if out.Kind != OutcomeDegraded {
		t.Fatalf("outcome = %v, want degraded", out.Kind)
	}
	if out.Meta.DegradeReason != guardrail.ReasonQuota {
		t.Errorf("reason = %q, want %q", out.Meta.DegradeReason, guardrail.ReasonQuota)
	}
	if out.Meta.Intent == guardrail.A8Concept {
		t.Error("generative intent served on an exhausted quota")
	}
}

// A refusal must cost the therapist nothing.
func TestRefusalDoesNotChargeTheQuota(t *testing.T) {
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"P1_DIAG","confidence":0.97,"risk_flag":false}`,
	}, sampleSegments())

	out, err := h.svc.Ask(context.Background(), turn())
	if err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if out.Kind != OutcomeRefused {
		t.Fatalf("outcome = %v, want refused", out.Kind)
	}
	// The classifier call is charged; nothing else is.
	if len(h.llm.calls) != 1 {
		t.Errorf("%d model calls on a refusal, want 1 (classifier only)", len(h.llm.calls))
	}
	if h.db.reserved != 0 {
		t.Errorf("%d micro-USD left reserved after a refusal", h.db.reserved)
	}
}

// A risk question refuses and surfaces crisis information.
func TestRiskQuestionRefusesWithCrisisInformation(t *testing.T) {
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A1_SEARCH","confidence":0.99,"risk_flag":true}`,
	}, sampleSegments())

	out, err := h.svc.Ask(context.Background(), turn())
	if err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if out.Kind != OutcomeRefused {
		t.Fatalf("outcome = %v", out.Kind)
	}
	if !out.Refusal.ShowCrisisInformation {
		t.Error("risk refusal did not surface crisis information")
	}
	if h.recs.last().RiskFlag != true {
		t.Error("evidence row lost the risk flag")
	}
}

// ── Grounding and authorship ──────────────────────────────────────────

// A fabricated quote must block, and the block must be recorded.
func TestFabricatedQuoteBlocksTheAnswer(t *testing.T) {
	segs := sampleSegments()
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A8_CONCEPT","confidence":0.95,"risk_flag":false}`,
		`{"hypotheses":[{"title":"H","body":"b","quotes":[{"session_id":"` + segs[0].SessionID.String() +
			`","segment_id":"` + segs[0].ID.String() + `","text":"czuję się bezwartościowa"}]}]}`,
	}, segs)
	tr := turn()
	tr.Question = "Jak rozumieć jej napięcie w pracy?"

	out, err := h.svc.Ask(context.Background(), tr)
	if err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if out.Kind != OutcomeVerifierBlocked {
		t.Fatalf("outcome = %v, want verifier blocked", out.Kind)
	}
	rec := h.recs.last()
	if rec.VerifierResult != "block" || rec.BlockReason != guardrail.BlockFabricated {
		t.Errorf("evidence row: result=%q reason=%q", rec.VerifierResult, rec.BlockReason)
	}
}

// The therapist-owned fields must appear in the answer, empty and marked,
// having never existed in the schema the model saw.
func TestUserOnlyFieldsAreAppendedByTheServer(t *testing.T) {
	segs := sampleSegments()
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A8_CONCEPT","confidence":0.95,"risk_flag":false}`,
		`{"hypotheses":[{"title":"H","body":"b","quotes":[{"session_id":"` + segs[0].SessionID.String() +
			`","segment_id":"` + segs[0].ID.String() + `","text":"W pracy czuję ciągłe napięcie"}]}]}`,
		`{"violation":false,"code":"none"}`,
	}, segs)
	tr := turn()
	tr.Question = "Jak rozumieć jej napięcie w pracy?"

	out, err := h.svc.Ask(context.Background(), tr)
	if err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if out.Kind != OutcomeAnswered {
		t.Fatalf("outcome = %v, meta=%+v", out.Kind, out.Meta)
	}

	var found bool
	for _, s := range out.Answer.Sections {
		if s.Kind == "user_only" {
			found = true
			if !s.UserAuthored {
				t.Error("user_only section not marked as user-authored")
			}
			if s.Body != "" {
				t.Errorf("user_only section arrived pre-filled: %q", s.Body)
			}
		}
	}
	if !found {
		t.Error("A8 answer has no user_only section")
	}

	// The schema handed to the generator must not mention it.
	for _, c := range h.llm.calls {
		if c.ResponseSchema == nil {
			continue
		}
		props, _ := c.ResponseSchema["properties"].(map[string]any)
		if _, ok := props["conclusion"]; ok {
			t.Error("conclusion was present in the schema sent to the model")
		}
	}
}

// Quote metadata comes from the database, not from the model. The model's
// schema has fields for session_id, segment_id and text and nothing else,
// so speaker and timestamps are not something it could get wrong — it has
// nowhere to put them. This asserts the server actually fills them in.
func TestQuoteMetadataComesFromTheDatabase(t *testing.T) {
	segs := sampleSegments()
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A1_SEARCH","confidence":0.95,"risk_flag":false}`,
		`{"sections":[{"title":"Praca","body":"b","quotes":[{"session_id":"` + segs[0].SessionID.String() +
			`","segment_id":"` + segs[0].ID.String() + `","text":"W pracy czuję ciągłe napięcie"}]}]}`,
		`{"violation":false,"code":"none"}`,
	}, segs)

	out, err := h.svc.Ask(context.Background(), turn())
	if err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if out.Kind != OutcomeAnswered {
		t.Fatalf("outcome = %v", out.Kind)
	}
	q := out.Answer.Sections[0].Quotes[0]
	if q.Speaker != "KLIENT" || q.TsStartMs != 1000 || q.TsEndMs != 5000 {
		t.Errorf("speaker/ts not resolved from the database: %+v", q)
	}
	if q.SessionAt.IsZero() {
		t.Error("session date not resolved from the database")
	}

	// The model has no field for any of it.
	quoteProps := quoteSchemaProperties(t, h)
	for _, forbidden := range []string{"speaker", "ts_start_ms", "ts_end_ms", "session_at"} {
		if _, present := quoteProps[forbidden]; present {
			t.Errorf("quote schema exposes %q to the model", forbidden)
		}
	}
}

// quoteSchemaProperties digs the quote item properties out of whatever
// schema the generator was called with.
func quoteSchemaProperties(t *testing.T, h *harness) map[string]any {
	t.Helper()
	for _, c := range h.llm.calls {
		if c.ResponseSchema == nil {
			continue
		}
		props, _ := c.ResponseSchema["properties"].(map[string]any)
		for _, key := range []string{"sections", "hypotheses"} {
			arr, ok := props[key].(map[string]any)
			if !ok {
				continue
			}
			items, _ := arr["items"].(map[string]any)
			itemProps, _ := items["properties"].(map[string]any)
			quotes, ok := itemProps["quotes"].(map[string]any)
			if !ok {
				continue
			}
			qItems, _ := quotes["items"].(map[string]any)
			qProps, _ := qItems["properties"].(map[string]any)
			return qProps
		}
	}
	t.Fatal("no generator schema with a quotes array was used")
	return nil
}

// ── Starters ──────────────────────────────────────────────────────────

// An unedited starter skips the classifier; an edited one does not.
func TestUneditedStarterSkipsTheClassifier(t *testing.T) {
	segs := sampleSegments()
	responses := []string{
		`{"sections":[{"title":"Statystyki","body":"x"}]}`,
	}
	h := newHarness(t, enabledConfig(), responses, segs)
	tr := turn()
	tr.StarterID = "attendance"
	tr.StarterEdited = false

	if _, err := h.svc.Ask(context.Background(), tr); err != nil {
		t.Fatalf("Ask: %v", err)
	}
	// A2_STATS is SQL-only, so an unedited starter for it makes ZERO
	// model calls: no classifier, no generator, no verifier.
	if len(h.llm.calls) != 0 {
		t.Errorf("%d model calls for an unedited A2 starter, want 0", len(h.llm.calls))
	}

	h2 := newHarness(t, enabledConfig(), []string{
		`{"intent":"A2_STATS","confidence":0.9,"risk_flag":false}`,
	}, segs)
	tr2 := turn()
	tr2.StarterID = "attendance"
	tr2.StarterEdited = true
	if _, err := h2.svc.Ask(context.Background(), tr2); err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if len(h2.llm.calls) == 0 {
		t.Error("an EDITED starter skipped the classifier")
	}
}

// The shortcut is only safe if every starter is an allowed, non-risk
// intent by construction.
func TestStartersAreAllowedByConstruction(t *testing.T) {
	for _, s := range AllStarters() {
		if !s.Intent.Allowed() {
			t.Errorf("starter %q maps to non-allowed intent %s", s.ID, s.Intent)
		}
		if s.LabelKey == "" || s.PrefillKey == "" {
			t.Errorf("starter %q has no i18n keys; text must not live in the backend", s.ID)
		}
	}
	if n := len(AllStarters()); n < 4 || n > 6 {
		t.Errorf("%d starters; ADR v1.3 section 6 specifies 4-6", n)
	}
}

// An unknown starter ID must fall back to classification.
func TestUnknownStarterIDFallsBackToClassifier(t *testing.T) {
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A2_STATS","confidence":0.9,"risk_flag":false}`,
	}, sampleSegments())
	tr := turn()
	tr.StarterID = "invented_by_client"

	if _, err := h.svc.Ask(context.Background(), tr); err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if len(h.llm.calls) == 0 {
		t.Error("an unknown starter ID skipped the classifier")
	}
}

// ── Evidence log ──────────────────────────────────────────────────────

// The evidence row must carry the decision shape and NOT the content.
func TestEvidenceRowRecordsShapeNotContent(t *testing.T) {
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"P1_DIAG","confidence":0.97,"risk_flag":false,"rationale_short":"pyta czy klientka ma depresje"}`,
	}, sampleSegments())
	tr := turn()
	tr.Question = "Czy ona ma depresję?"

	if _, err := h.svc.Ask(context.Background(), tr); err != nil {
		t.Fatalf("Ask: %v", err)
	}
	rec := h.recs.last()

	if rec.Intent != string(guardrail.P1Diag) || rec.Decision != "refuse" {
		t.Errorf("shape not recorded: %+v", rec)
	}
	if rec.ClassifierPromptVersion == "" {
		t.Error("prompt version missing — the log cannot say what the system was")
	}
	// The whole record must not contain the question or the rationale.
	blob, _ := json.Marshal(rec)
	for _, leak := range []string{"depresję", "depresje", "pyta czy klientka"} {
		if strings.Contains(string(blob), leak) {
			t.Errorf("evidence row leaked conversation content: %q", leak)
		}
	}
	if strings.Contains(string(blob), tr.ConversationID.String()) {
		t.Error("evidence row carries the raw conversation ID; it must be hashed")
	}
}

// ── Retrieval cost ────────────────────────────────────────────────────

// Retrieval must cost one KMS decrypt per session, not one per segment.
// At ~200 segments per session and a KMS round trip each, the per-segment
// design would blow the 1.5 s p95 budget by two orders of magnitude.
func TestRetrievalDecryptsOncePerSessionNotPerSegment(t *testing.T) {
	segs := sampleSegments()
	for i := 0; i < 200; i++ {
		segs = append(segs, Segment{
			ID: uuid.New(), SessionID: segs[0].SessionID, Text: "wypełniacz",
			TsStartMs: int32(10000 + i*100), SessionAt: segs[0].SessionAt,
		})
	}
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A1_SEARCH","confidence":0.95,"risk_flag":false}`,
		`{"sections":[{"title":"P","body":"b","quotes":[{"session_id":"` + segs[0].SessionID.String() +
			`","segment_id":"` + segs[0].ID.String() + `","text":"W pracy czuję ciągłe napięcie"}]}]}`,
		`{"violation":false,"code":"none"}`,
	}, segs)

	if _, err := h.svc.Ask(context.Background(), turn()); err != nil {
		t.Fatalf("Ask: %v", err)
	}
	if h.crypto.calls > 2 {
		t.Errorf("%d KMS decrypts for 1 session of 202 segments — retrieval is per-segment", h.crypto.calls)
	}
}
