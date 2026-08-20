package chat

import (
	"context"
	"encoding/json"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
)

// ── atrapa szyfrowania ────────────────────────────────────────────────

type fakeCrypto struct{}

func (c *fakeCrypto) Encrypt(_ context.Context, p []byte) ([]byte, []byte, error) {
	return append([]byte("enc:"), p...), []byte("dek"), nil
}

func (c *fakeCrypto) Decrypt(_ context.Context, ct, _ []byte) ([]byte, error) {
	return ct[len("enc:"):], nil
}

// historyDB zbiera zapisane wiersze i oddaje je przy odczycie.
type historyDB struct {
	mu    sync.Mutex
	saved []savedRow
}

type savedRow struct {
	conv    uuid.UUID
	kind    string
	payload []byte
	at      time.Time
}

func (d *historyDB) Exec(_ context.Context, sql string, args ...any) (int64, error) {
	if !strings.Contains(sql, "INSERT INTO chat_interactions") {
		return 0, nil
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	d.saved = append(d.saved, savedRow{
		conv:    args[2].(uuid.UUID),
		kind:    args[3].(string),
		payload: args[4].([]byte),
		at:      time.Now().Add(time.Duration(len(d.saved)) * time.Second),
	})
	return 1, nil
}

func (d *historyDB) QueryRow(context.Context, string, ...any) RowScanner {
	return scanFunc(func(...any) error { return nil })
}

// Query odwzorowuje sqlLoadHistory wiernie: filtruje po conversation_id
// ORAZ interaction_type, sortuje malejaco i respektuje LIMIT.
//
// Atrapa, ktora ignoruje warunki prawdziwego zapytania, testuje kod,
// ktorego nie ma w produkcji — i to wlasnie taka rozbieznosc wypuscila
// 20.08.2026 bledna nazwe kolumny przy stu procentach zielonych testow.
func (d *historyDB) Query(_ context.Context, sql string, args ...any) (Rows, error) {
	d.mu.Lock()
	defer d.mu.Unlock()

	conv, _ := args[0].(uuid.UUID)
	want, _ := args[1].(string)
	limit, _ := args[2].(int)

	var out []savedRow
	for _, r := range d.saved {
		if r.conv == conv && r.kind == want {
			out = append(out, r)
		}
	}
	// ORDER BY created_at DESC
	for i, j := 0, len(out)-1; i < j; i, j = i+1, j-1 {
		out[i], out[j] = out[j], out[i]
	}
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return &historyRows{rows: out}, nil
}

type historyRows struct {
	rows []savedRow
	i    int
}

func (r *historyRows) Next() bool { r.i++; return r.i <= len(r.rows) }
func (r *historyRows) Scan(dest ...any) error {
	cur := r.rows[r.i-1]
	*(dest[0].(*[]byte)) = append([]byte("enc:"), cur.payload[len("enc:"):]...)
	*(dest[1].(*[]byte)) = []byte("dek")
	*(dest[2].(*time.Time)) = cur.at
	return nil
}
func (r *historyRows) Err() error { return nil }
func (r *historyRows) Close()     {}

func newHistory() (HistoryStore, *historyDB) {
	db := &historyDB{}
	return HistoryStore{DB: db, Pool: db, Crypto: &fakeCrypto{}}, db
}

// ── TEN test jest najważniejszy ───────────────────────────────────────

// Historia zasila klasyfikator i wyszukiwanie, ale NIE trafia do
// generatora. Gdyby wcześniejsze odpowiedzi wracały do modelu, hipoteza
// z tury pierwszej byłaby wejściem tury drugiej — a model traktuje
// wejście jako ustalone. Po kilku turach domysł staje się przesłanką i
// nikt już nie widzi, że u źródła stał domysł.
func TestGeneratorNeverSeesPreviousAnswers(t *testing.T) {
	const wymyslona = "wycofanie chroni ja przed ocena partnera"
	segs := sampleSegments()
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"A8_CONCEPT","confidence":0.95,"risk_flag":false}`,
		`{"hypotheses":[{"title":"Hipoteza","body":"` + wymyslona + `","quotes":[{"session_id":"` +
			segs[0].SessionID.String() + `","segment_id":"` + segs[0].ID.String() +
			`","text":"W pracy czuję ciągłe napięcie"}]}]}`,
		`{"violation":false,"code":"none"}`,
		// tura druga
		`{"intent":"A8_CONCEPT","confidence":0.95,"risk_flag":false}`,
		`{"hypotheses":[{"title":"H2","body":"b","quotes":[{"session_id":"` +
			segs[0].SessionID.String() + `","segment_id":"` + segs[0].ID.String() +
			`","text":"W pracy czuję ciągłe napięcie"}]}]}`,
		`{"violation":false,"code":"none"}`,
	}, segs)
	hist, _ := newHistory()
	h.svc.History = hist

	conv := uuid.New()
	t1 := turn()
	t1.ConversationID = conv
	t1.Question = "Jak rozumieć jej napięcie w pracy?"
	if _, err := h.svc.Ask(context.Background(), t1); err != nil {
		t.Fatalf("tura 1: %v", err)
	}

	before := len(h.llm.calls)
	t2 := turn()
	t2.ConversationID = conv
	t2.PatientFileID = t1.PatientFileID
	t2.Question = "A co z jej relacją z matką?"
	if _, err := h.svc.Ask(context.Background(), t2); err != nil {
		t.Fatalf("tura 2: %v", err)
	}

	// Wygenerowana hipoteza z tury 1 nie moze pojawic sie w ZADNYM
	// promptcie tury 2 — ani generatora, ani weryfikatora.
	for i, c := range h.llm.calls[before:] {
		if strings.Contains(c.SystemPrompt+c.UserContent, wymyslona) {
			t.Fatalf("wywolanie %d tury 2 niesie hipoteze z tury 1 — model karmi sie wlasnym domyslem", i)
		}
	}
}

// Klasyfikator ma widziec wczesniejsze PYTANIA — bez nich "na ten temat"
// nie ma do czego sie odniesc.
func TestClassifierSeesPreviousQuestions(t *testing.T) {
	segs := sampleSegments()
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"P2_MED","confidence":0.97,"risk_flag":false}`,
		`{"intent":"A1_SEARCH","confidence":0.9,"risk_flag":false}`,
		`{"sections":[{"title":"S","body":"b","quotes":[{"session_id":"` +
			segs[0].SessionID.String() + `","segment_id":"` + segs[0].ID.String() +
			`","text":"W pracy czuję ciągłe napięcie"}]}]}`,
		`{"violation":false,"code":"none"}`,
	}, segs)
	hist, _ := newHistory()
	h.svc.History = hist

	conv := uuid.New()
	t1 := turn()
	t1.ConversationID = conv
	t1.Question = "jakie leki byś proponował dla alkoholika?"
	if _, err := h.svc.Ask(context.Background(), t1); err != nil {
		t.Fatalf("tura 1: %v", err)
	}

	before := len(h.llm.calls)
	t2 := turn()
	t2.ConversationID = conv
	t2.PatientFileID = t1.PatientFileID
	t2.Question = "Pokaż cytaty na ten temat"
	if _, err := h.svc.Ask(context.Background(), t2); err != nil {
		t.Fatalf("tura 2: %v", err)
	}

	classifierCall := h.llm.calls[before]
	if !strings.Contains(classifierCall.UserContent, "alkoholika") {
		t.Errorf("klasyfikator nie dostal wczesniejszego pytania:\n%s", classifierCall.UserContent)
	}
	if !strings.Contains(classifierCall.UserContent, "refused") {
		t.Error("klasyfikator nie wie, ze poprzednia tura byla odmowa")
	}
}

// Regresja "ten Janko": po odmowie i klikniecu alternatywy temat ma sie
// odziedziczyc, a nie zamienic w wyszukiwanie slowa "ten".
func TestTopicIsInheritedAfterRefusal(t *testing.T) {
	segs := sampleSegments()
	segs = append(segs, Segment{
		ID: uuid.New(), SessionID: segs[0].SessionID,
		Text: "jeszcze raz ten Janko jaki ten?", Speaker: "KLIENT",
		TsStartMs: 99000, SessionAt: segs[0].SessionAt,
	})
	h := newHarness(t, enabledConfig(), []string{
		`{"intent":"P2_MED","confidence":0.97,"risk_flag":false}`,
		`{"intent":"A1_SEARCH","confidence":0.9,"risk_flag":false}`,
		`{"sections":[{"title":"Praca","body":"b","quotes":[{"session_id":"` +
			segs[0].SessionID.String() + `","segment_id":"` + segs[0].ID.String() +
			`","text":"W pracy czuję ciągłe napięcie"}]}]}`,
		`{"violation":false,"code":"none"}`,
	}, segs)
	hist, _ := newHistory()
	h.svc.History = hist

	conv := uuid.New()
	t1 := turn()
	t1.ConversationID = conv
	t1.Question = "Czy powinna brać leki na napięcie w pracy?"
	if _, err := h.svc.Ask(context.Background(), t1); err != nil {
		t.Fatalf("tura 1: %v", err)
	}

	before := len(h.llm.calls)
	t2 := turn()
	t2.ConversationID = conv
	t2.PatientFileID = t1.PatientFileID
	t2.Question = "Pokaż cytaty na ten temat"
	out, err := h.svc.Ask(context.Background(), t2)
	if err != nil {
		t.Fatalf("tura 2: %v", err)
	}
	if out.Answer == nil || len(out.Answer.Sections) == 0 {
		t.Fatal("brak odpowiedzi")
	}
	if strings.Contains(out.Answer.Sections[0].Title, "Doprecyzuj") {
		t.Error("temat sie nie odziedziczyl — mimo historii poproszono o doprecyzowanie")
	}
	// Kontekst przekazany generatorowi ma zawierac segment o pracy, a nie
	// przypadkowy segment z "ten".
	var genCtx string
	for _, c := range h.llm.calls[before:] {
		if strings.Contains(c.UserContent, "FRAGMENTY TRANSKRYPCJI") {
			genCtx = c.UserContent
		}
	}
	if genCtx == "" {
		t.Fatal("generator nie dostal kontekstu")
	}
	if strings.Contains(genCtx, "Janko") && !strings.Contains(genCtx, "pracy") {
		t.Error("kontekst zdominowany przez przypadkowy segment")
	}
}

// ── Zapis i odczyt ────────────────────────────────────────────────────

func TestBothSidesAreStoredButOnlyQuestionsAreRead(t *testing.T) {
	hist, db := newHistory()
	conv := uuid.New()
	tr := Turn{TherapistID: uuid.New(), PatientFileID: uuid.New(), ConversationID: conv,
		Question: "Kiedy mówiła o pracy?"}
	out := Outcome{Kind: OutcomeAnswered, Answer: &Answer{
		Sections: []Section{{Title: "Praca", Body: "tresc odpowiedzi", Kind: "extract"}}}}

	if err := hist.Save(context.Background(), tr, out, DecisionRecord{Intent: "A1_SEARCH"}, Usage{}); err != nil {
		t.Fatalf("Save: %v", err)
	}
	db.mu.Lock()
	kinds := map[string]int{}
	for _, r := range db.saved {
		kinds[r.kind]++
	}
	db.mu.Unlock()
	if kinds["question"] != 1 || kinds["answer"] != 1 {
		t.Errorf("zapisano %v, oczekiwano po jednym pytaniu i odpowiedzi", kinds)
	}

	loaded := hist.Load(context.Background(), conv)
	if len(loaded) != 1 {
		t.Fatalf("wczytano %d tur, oczekiwano 1", len(loaded))
	}
	if loaded[0].Question != tr.Question {
		t.Errorf("pytanie = %q", loaded[0].Question)
	}
	// Tresc odpowiedzi nie moze wrocic przez Load.
	blob, _ := json.Marshal(loaded)
	if strings.Contains(string(blob), "tresc odpowiedzi") {
		t.Error("Load zwrocil tresc odpowiedzi — historia ma oddawac tylko pytania")
	}
}

func TestHistoryIsBoundedByTurnsAndChars(t *testing.T) {
	hist, _ := newHistory()
	conv := uuid.New()
	tr := Turn{TherapistID: uuid.New(), PatientFileID: uuid.New(), ConversationID: conv}
	for i := 0; i < maxHistoryTurns*3; i++ {
		tr.Question = "pytanie o prace numer " + strings.Repeat("x", 10)
		if err := hist.Save(context.Background(), tr, Outcome{Kind: OutcomeAnswered},
			DecisionRecord{}, Usage{}); err != nil {
			t.Fatalf("Save: %v", err)
		}
	}
	loaded := hist.Load(context.Background(), conv)
	if len(loaded) > maxHistoryTurns {
		t.Errorf("wczytano %d tur, limit to %d", len(loaded), maxHistoryTurns)
	}
	total := 0
	for _, l := range loaded {
		total += len(l.Question)
	}
	if total > maxHistoryChars {
		t.Errorf("historia ma %d znakow, limit to %d", total, maxHistoryChars)
	}
}

// Rozmowy nie moga sie mieszac.
func TestHistoryIsScopedToConversation(t *testing.T) {
	hist, _ := newHistory()
	a, b := uuid.New(), uuid.New()
	base := Turn{TherapistID: uuid.New(), PatientFileID: uuid.New()}

	ta := base
	ta.ConversationID = a
	ta.Question = "pytanie o prace"
	_ = hist.Save(context.Background(), ta, Outcome{Kind: OutcomeAnswered}, DecisionRecord{}, Usage{})

	tb := base
	tb.ConversationID = b
	tb.Question = "pytanie o matke"
	_ = hist.Save(context.Background(), tb, Outcome{Kind: OutcomeAnswered}, DecisionRecord{}, Usage{})

	for _, l := range hist.Load(context.Background(), a) {
		if strings.Contains(l.Question, "matke") {
			t.Error("historia rozmowy A niesie pytanie z rozmowy B")
		}
	}
}

// Pusta HistoryStore nie moze wywracac tury — pamiec jest opcjonalna.
func TestZeroHistoryStoreIsSafe(t *testing.T) {
	var hist HistoryStore
	if got := hist.Load(context.Background(), uuid.New()); got != nil {
		t.Errorf("Load na pustym store zwrocil %v", got)
	}
	if err := hist.Save(context.Background(), Turn{}, Outcome{}, DecisionRecord{}, Usage{}); err != nil {
		t.Errorf("Save na pustym store: %v", err)
	}
}

func TestInheritedTopicSkipsTopiclessQuestions(t *testing.T) {
	turns := []HistoryTurn{
		{Question: "Kiedy mówiła o pracy?"},
		{Question: "Pokaż cytaty na ten temat"},
		{Question: "A to?"},
	}
	got, ok := InheritedTopic(turns)
	if !ok {
		t.Fatal("nie odziedziczono tematu")
	}
	if !strings.Contains(got, "pracy") {
		t.Errorf("odziedziczono %q, oczekiwano pytania o prace", got)
	}
}
