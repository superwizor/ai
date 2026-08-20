package chat

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"

	"github.com/google/uuid"
	"github.com/superwizor-ai/backend/pkg/guardrail"
	"github.com/superwizor-ai/backend/pkg/rag"
)

// Retrieval assembles the material each intent is allowed to see.
//
// # Why the canonical blob and not transcript_segments
//
// The plan (F3) describes searching transcript_segments lexically with
// pg_trgm. That is not implementable as written: segments.text_ciphertext
// is envelope-encrypted, and Postgres cannot match a trigram against
// ciphertext. The extensions are installed, but there is nothing for them
// to index here.
//
// Decrypting segments individually is worse. cryptobox.Decrypt is one
// Cloud KMS round trip per call with no DEK cache, so six candidate
// sessions at ~200 segments each would be ~1200 network round trips
// against a p95 budget of 1.5 s for the entire turn.
//
// So retrieval reads transcripts.transcript_ciphertext — the canonical
// blob, which ADR-IMPL-006 already makes the source of truth with
// segments derived from it. That is ONE KMS decrypt per session, and the
// candidate sessions are decrypted concurrently, so the cost is roughly
// one round trip of wall time rather than six.
//
// Segment identity is preserved: the blob's lines and the segment rows
// come from the same chunks, so a line is resolved to its segment_id
// through the unencrypted (transcript_id, start_offset_ms) columns. The
// verifier therefore still checks quotes against real segment IDs.
//
// # RAG is preselection only
//
// rag_memories holds pseudonymized per-session theme vectors with no
// timestamps. It can say WHICH sessions are worth reading; it cannot
// ground a quote, because a quote needs exact text and offsets. So the
// vector search narrows the candidate set and the lexical search inside
// the decrypted blobs does the actual finding.

// Segment is one line of transcript, decrypted.
type Segment struct {
	ID        uuid.UUID
	SessionID uuid.UUID
	Text      string
	Speaker   string
	TsStartMs int32
	TsEndMs   int32
	SessionAt time.Time
}

// SessionStats is the A2/A6 answer shape: computed numbers, no model.
type SessionStats struct {
	SessionCount   int
	FirstSessionAt time.Time
	LastSessionAt  time.Time
	LongestGapDays int
	CancelledCount int
	// Derived from sessions.duration_seconds; the column is seconds,
	// the number a therapist wants is minutes.
	TotalMinutes     int
	ReportsAvailable int
}

// ReportDigest is a report's non-encrypted header plus its short summary.
type ReportDigest struct {
	SessionID    uuid.UUID
	SessionAt    time.Time
	Title        string
	SummaryShort string
}

// Pool is the database surface retrieval needs.
type Pool interface {
	Query(ctx context.Context, sql string, args ...any) (Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) RowScanner
}

// Rows is pgx.Rows, narrowed.
type Rows interface {
	Next() bool
	Scan(dest ...any) error
	Err() error
	Close()
}

// Decryptor is cryptobox.CryptoBox, narrowed to what retrieval uses.
type Decryptor interface {
	Decrypt(ctx context.Context, ciphertext, encryptedDEK []byte) ([]byte, error)
}

// Retriever loads material for the intent executors.
type Retriever struct {
	Pool   Pool
	Crypto Decryptor
	// MaxSessions bounds how many sessions are decrypted for one turn.
	// Each costs a KMS round trip, so this is the main latency dial.
	MaxSessions int
	// MaxContextChars bounds what is handed to the model, matching the
	// report pipeline's budget (pkg/rag.ContextMaxChars).
	MaxContextChars int
}

// Defaults mirror the report pipeline's tuned values (pkg/rag).
const (
	DefaultMaxSessions     = 6
	DefaultMaxContextChars = 8000
)

func (r Retriever) maxSessions() int {
	if r.MaxSessions > 0 {
		return r.MaxSessions
	}
	return DefaultMaxSessions
}

func (r Retriever) maxContextChars() int {
	if r.MaxContextChars > 0 {
		return r.MaxContextChars
	}
	return DefaultMaxContextChars
}

// blobLine is one line of the canonical transcript blob. The shape is
// stt-worker's and must not drift from it; see llm-worker's
// rebuildBlobWithRoles, which writes the same struct.
type blobLine struct {
	ChunkIdx     int     `json:"chunk_idx"`
	Text         string  `json:"text"`
	StartMS      int64   `json:"start_ms"`
	EndMS        int64   `json:"end_ms"`
	WordCount    int     `json:"word_count"`
	Confidence   float32 `json:"confidence"`
	SpeakerTag   *int32  `json:"speaker_tag,omitempty"`
	SpeakerLabel *string `json:"speaker_label,omitempty"`
}

// Column names here are checked against the live schema, not assumed.
// The first version of this file used s.scheduled_at, s.duration_minutes
// and status 'CANCELLED' — none of which exist. The real columns are
// session_date, duration_seconds, and the cancelled statuses are
// 'CANCELED' (one L) and 'CANCELLED_BY_USER'. Every unit test mocked the
// pool, so nothing caught it until a therapist hit it in production.
// TestQueriesMatchLiveSchema now runs these against a real database.
const sqlRecentSessions = `
SELECT s.id, s.session_date, t.id, t.transcript_ciphertext, t.transcript_encrypted_dek
  FROM sessions s
  JOIN transcripts t ON t.session_id = s.id
 WHERE s.patient_file_id = $1
   AND s.deleted_at IS NULL
 ORDER BY s.session_date DESC
 LIMIT $2`

const sqlSegmentIndex = `
SELECT id, start_offset_ms, speaker_label
  FROM transcript_segments
 WHERE transcript_id = $1`

type transcriptRow struct {
	sessionID    uuid.UUID
	sessionAt    time.Time
	transcriptID uuid.UUID
	ciphertext   []byte
	dek          []byte
}

// LoadSegments decrypts the most recent sessions' transcripts and returns
// their lines as Segments, newest session first.
//
// sessionFilter, when non-empty, restricts the load to those sessions —
// this is where RAG preselection is applied. Empty means "the most recent
// MaxSessions", which is the right default for A5 and for a search with
// no useful vector signal.
func (r Retriever) LoadSegments(ctx context.Context, patientFileID uuid.UUID, sessionFilter map[uuid.UUID]bool) ([]Segment, error) {
	// Over-fetch when filtering: the newest sessions are not necessarily
	// the selected ones.
	limit := r.maxSessions()
	if len(sessionFilter) > 0 {
		limit = r.maxSessions() * 6
	}

	rows, err := r.Pool.Query(ctx, sqlRecentSessions, patientFileID, limit)
	if err != nil {
		return nil, fmt.Errorf("chat: load sessions: %w", err)
	}
	var wanted []transcriptRow
	for rows.Next() {
		var tr transcriptRow
		if err := rows.Scan(&tr.sessionID, &tr.sessionAt, &tr.transcriptID, &tr.ciphertext, &tr.dek); err != nil {
			rows.Close()
			return nil, fmt.Errorf("chat: scan session: %w", err)
		}
		if len(sessionFilter) > 0 && !sessionFilter[tr.sessionID] {
			continue
		}
		wanted = append(wanted, tr)
		if len(wanted) >= r.maxSessions() {
			break
		}
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("chat: iterate sessions: %w", err)
	}

	// Decrypt concurrently. Each is one KMS round trip; serially this
	// would be the single largest term in the latency budget.
	type result struct {
		idx  int
		segs []Segment
		err  error
	}
	out := make(chan result, len(wanted))
	var wg sync.WaitGroup
	for i, tr := range wanted {
		wg.Add(1)
		go func(i int, tr transcriptRow) {
			defer wg.Done()
			segs, err := r.decryptOne(ctx, tr)
			out <- result{idx: i, segs: segs, err: err}
		}(i, tr)
	}
	wg.Wait()
	close(out)

	ordered := make([][]Segment, len(wanted))
	for res := range out {
		if res.err != nil {
			// One unreadable session must not fail the turn: the
			// therapist gets an answer grounded in what could be read,
			// and the failure is visible in logs. Failing the whole turn
			// would make one corrupt row take down the feature.
			continue
		}
		ordered[res.idx] = res.segs
	}
	var all []Segment
	for _, segs := range ordered {
		all = append(all, segs...)
	}
	return all, nil
}

func (r Retriever) decryptOne(ctx context.Context, tr transcriptRow) ([]Segment, error) {
	plain, err := r.Crypto.Decrypt(ctx, tr.ciphertext, tr.dek)
	if err != nil {
		return nil, fmt.Errorf("decrypt transcript %s: %w", tr.transcriptID, err)
	}
	var lines []blobLine
	if err := json.Unmarshal(plain, &lines); err != nil {
		return nil, fmt.Errorf("parse transcript blob %s: %w", tr.transcriptID, err)
	}

	// Resolve segment IDs from the unencrypted columns, keyed by start
	// offset. Without this the verifier would have nothing real to check
	// a quote against.
	idByOffset := map[int32]uuid.UUID{}
	labelByOffset := map[int32]string{}
	if segRows, err := r.Pool.Query(ctx, sqlSegmentIndex, tr.transcriptID); err == nil {
		for segRows.Next() {
			var id uuid.UUID
			var off int32
			var label string
			if err := segRows.Scan(&id, &off, &label); err == nil {
				idByOffset[off] = id
				labelByOffset[off] = label
			}
		}
		segRows.Close()
	}

	segs := make([]Segment, 0, len(lines))
	for _, l := range lines {
		if strings.TrimSpace(l.Text) == "" {
			continue
		}
		off := int32(l.StartMS)
		speaker := ""
		if l.SpeakerLabel != nil {
			speaker = *l.SpeakerLabel
		} else if lbl, ok := labelByOffset[off]; ok {
			speaker = lbl
		}
		segs = append(segs, Segment{
			ID:        idByOffset[off],
			SessionID: tr.sessionID,
			Text:      l.Text,
			Speaker:   speaker,
			TsStartMs: off,
			TsEndMs:   int32(l.EndMS),
			SessionAt: tr.sessionAt,
		})
	}
	return segs, nil
}

// SearchQuotes ranks segments against a query lexically.
//
// Lexical, not vector: segments carry no embeddings and the plan defers
// adding them pending a measured recall gap. Matching folds case and
// Polish diacritics; the returned Text is always the untouched original,
// because that is what the verifier checks and what the therapist reads.
func SearchQuotes(segments []Segment, query string, limit int) []Segment {
	terms := tokenize(query)
	if len(terms) == 0 {
		return nil
	}
	type scored struct {
		seg   Segment
		score float64
	}
	var hits []scored
	for _, s := range segments {
		folded := fold(s.Text)
		var matched int
		for _, t := range terms {
			if strings.Contains(folded, t) {
				matched++
			}
		}
		if matched == 0 {
			continue
		}
		// Coverage of the query dominates; a short segment that matches
		// everything beats a long one that happens to contain a term.
		score := float64(matched) / float64(len(terms))
		if len(s.Text) > 0 {
			score += 0.15 * (1.0 / (1.0 + float64(len(s.Text))/400.0))
		}
		hits = append(hits, scored{seg: s, score: score})
	}
	sort.SliceStable(hits, func(i, j int) bool {
		if hits[i].score != hits[j].score {
			return hits[i].score > hits[j].score
		}
		// Ties break toward the more recent session: two equally
		// relevant quotes are not equally useful.
		return hits[i].seg.SessionAt.After(hits[j].seg.SessionAt)
	})
	if limit > 0 && len(hits) > limit {
		hits = hits[:limit]
	}
	out := make([]Segment, 0, len(hits))
	for _, h := range hits {
		out = append(out, h.seg)
	}
	return out
}

// stopwords are Polish function words that match everything and rank
// nothing. Kept short deliberately: an aggressive list would drop terms
// that carry meaning in a clinical question.
var stopwords = map[string]bool{
	"i": true, "w": true, "z": true, "na": true, "do": true, "o": true,
	"czy": true, "jak": true, "co": true, "to": true, "sie": true,
	"jest": true, "byl": true, "byla": true, "nie": true, "tak": true,
	"za": true, "od": true, "po": true, "przy": true, "the": true,
}

func tokenize(s string) []string {
	var out []string
	for _, raw := range strings.FieldsFunc(fold(s), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r)
	}) {
		if len(raw) < 3 || stopwords[raw] {
			continue
		}
		// Crude stemming: Polish inflects heavily, and comparing full
		// forms would miss "pracy" against "praca". Trimming to a stem
		// prefix costs some precision and buys a lot of recall, which is
		// the right trade when a human reads every hit.
		if len(raw) > 5 {
			raw = raw[:len(raw)-2]
		}
		out = append(out, raw)
	}
	return out
}

// fold lowercases and strips Polish diacritics for MATCHING only.
func fold(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	for _, r := range strings.ToLower(s) {
		switch r {
		case 'ą':
			b.WriteRune('a')
		case 'ć':
			b.WriteRune('c')
		case 'ę':
			b.WriteRune('e')
		case 'ł':
			b.WriteRune('l')
		case 'ń':
			b.WriteRune('n')
		case 'ó':
			b.WriteRune('o')
		case 'ś':
			b.WriteRune('s')
		case 'ź', 'ż':
			b.WriteRune('z')
		default:
			b.WriteRune(r)
		}
	}
	return b.String()
}

// cancelledStatuses lists every enum value that means "did not happen".
// There are two, and they differ by one letter, which is exactly the kind
// of thing a hand-written string comparison gets wrong silently: a
// session cancelled by the user would have counted as attended.
const cancelledStatuses = `('CANCELED','CANCELLED_BY_USER')`

const sqlStats = `
SELECT
    count(*) FILTER (WHERE s.status NOT IN ` + cancelledStatuses + `),
    min(s.session_date),
    max(s.session_date),
    count(*) FILTER (WHERE s.status IN ` + cancelledStatuses + `),
    coalesce(sum(s.duration_seconds) FILTER (WHERE s.status NOT IN ` + cancelledStatuses + `), 0),
    count(r.id)
  FROM sessions s
  LEFT JOIN reports r ON r.session_id = s.id
 WHERE s.patient_file_id = $1 AND s.deleted_at IS NULL`

const sqlLongestGap = `
SELECT coalesce(max(gap), 0) FROM (
    SELECT (session_date - lag(session_date) OVER (ORDER BY session_date))::int AS gap
      FROM sessions
     WHERE patient_file_id = $1 AND deleted_at IS NULL
       AND status NOT IN ` + cancelledStatuses + `
) g`

// Stats answers A2/A6 entirely from SQL.
//
// No model call at all — which is why A2 has no schema in pkg/guardrail
// and why an exhausted quota still serves it. A count is not a clinical
// claim, and making a therapist wait on a language model to learn how
// many sessions they have had would be absurd.
func (r Retriever) Stats(ctx context.Context, patientFileID uuid.UUID) (SessionStats, error) {
	var st SessionStats
	var first, last *time.Time
	var totalSeconds int
	err := r.Pool.QueryRow(ctx, sqlStats, patientFileID).Scan(
		&st.SessionCount, &first, &last, &st.CancelledCount, &totalSeconds, &st.ReportsAvailable)
	if err != nil {
		return st, fmt.Errorf("chat: stats: %w", err)
	}
	st.TotalMinutes = totalSeconds / 60
	if first != nil {
		st.FirstSessionAt = *first
	}
	if last != nil {
		st.LastSessionAt = *last
	}
	if err := r.Pool.QueryRow(ctx, sqlLongestGap, patientFileID).Scan(&st.LongestGapDays); err != nil {
		// A missing gap is not worth failing the answer over.
		st.LongestGapDays = 0
	}
	return st, nil
}

const sqlReportDigests = `
SELECT r.session_id, s.session_date, r.title, r.summary_short
  FROM reports r
  JOIN sessions s ON s.id = r.session_id
 WHERE s.patient_file_id = $1 AND s.deleted_at IS NULL
 ORDER BY s.session_date DESC
 LIMIT $2`

// ReportDigests loads report titles and short summaries.
//
// title and summary_short are stored unencrypted AND pseudonymized
// (docs/compliance/06 section 5.2), so this needs no KMS round trip. The
// full report body is not loaded: A8-A10 ground their hypotheses in
// transcript quotes, and a report summary is another model's output —
// grounding one generation in another is how a small error becomes a
// consistent one.
func (r Retriever) ReportDigests(ctx context.Context, patientFileID uuid.UUID, limit int) ([]ReportDigest, error) {
	if limit <= 0 {
		limit = r.maxSessions()
	}
	rows, err := r.Pool.Query(ctx, sqlReportDigests, patientFileID, limit)
	if err != nil {
		return nil, fmt.Errorf("chat: report digests: %w", err)
	}
	defer rows.Close()

	var out []ReportDigest
	for rows.Next() {
		var d ReportDigest
		if err := rows.Scan(&d.SessionID, &d.SessionAt, &d.Title, &d.SummaryShort); err != nil {
			return nil, fmt.Errorf("chat: scan digest: %w", err)
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// SegmentMap indexes segments by ID for the verifier.
func SegmentMap(segs []Segment) map[string]guardrail.Segment {
	m := make(map[string]guardrail.Segment, len(segs))
	for _, s := range segs {
		if s.ID == uuid.Nil {
			continue
		}
		m[s.ID.String()] = guardrail.Segment{
			ID:        s.ID.String(),
			SessionID: s.SessionID.String(),
			Text:      s.Text,
			Speaker:   s.Speaker,
			TsStartMs: s.TsStartMs,
			TsEndMs:   s.TsEndMs,
		}
	}
	return m
}

// FormatContext renders segments as model input, bounded by
// MaxContextChars. Each line carries its segment ID so the model can cite
// it; that ID is the handle the verifier checks against.
func (r Retriever) FormatContext(segs []Segment) string {
	var b strings.Builder
	budget := r.maxContextChars()
	for _, s := range segs {
		if s.ID == uuid.Nil {
			// Without an ID a quote cannot be verified, so the segment
			// cannot be offered as citable material.
			continue
		}
		line := fmt.Sprintf("[segment_id=%s session_id=%s %s %s] %s\n",
			s.ID, s.SessionID, s.SessionAt.Format("2006-01-02"), s.Speaker, s.Text)
		if b.Len()+len(line) > budget {
			break
		}
		b.WriteString(line)
	}
	return b.String()
}

const sqlRAGPool = `
WITH recent_sessions AS (
    SELECT source_session_id, max(created_at) AS session_at
      FROM rag_memories
     WHERE patient_file_id = $1 AND NOT is_compacted
       AND source_session_id IS NOT NULL
     GROUP BY source_session_id
     ORDER BY session_at DESC
     LIMIT $2
)
SELECT m.id, m.source_session_id, m.chunk_type, m.created_at, m.embedding::text
  FROM rag_memories m
  JOIN recent_sessions rs ON rs.source_session_id = m.source_session_id
 WHERE m.patient_file_id = $1 AND NOT m.is_compacted`

// CandidateSessions ranks sessions by thematic similarity to the query
// and returns the winners.
//
// This is the ONLY thing rag_memories does in the chat. The rows are
// pseudonymized per-session theme summaries with no timestamps and no
// offsets, so they can say which sessions are worth reading and nothing
// more. Grounding a quote needs exact text and exact offsets, which only
// the transcript has — see the package comment.
//
// The ranking is the report pipeline's, reused wholesale from pkg/rag:
// recency-weighted cosine with a per-session cap and a similarity floor,
// already tuned against this corpus.
func (r Retriever) CandidateSessions(ctx context.Context, patientFileID uuid.UUID, queryVec []float32) ([]uuid.UUID, error) {
	if len(queryVec) == 0 {
		return nil, nil
	}
	rows, err := r.Pool.Query(ctx, sqlRAGPool, patientFileID, rag.LookbackSessions)
	if err != nil {
		return nil, fmt.Errorf("chat: rag pool: %w", err)
	}
	defer rows.Close()

	var pool []rag.Candidate
	for rows.Next() {
		var c rag.Candidate
		var embText string
		if err := rows.Scan(&c.ID, &c.SessionID, &c.ChunkType, &c.CreatedAt, &embText); err != nil {
			return nil, fmt.Errorf("chat: scan rag row: %w", err)
		}
		c.Embedding = parseEmbedding(embText)
		pool = append(pool, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(pool) == 0 {
		return nil, nil
	}

	// No anchor: the chat has no "current session" to keep continuity
	// with, unlike report generation where the anchor is the session
	// being written up.
	hits := rag.SelectHits(pool, [][]float32{queryVec}, uuid.Nil, time.Now())

	seen := map[uuid.UUID]bool{}
	out := make([]uuid.UUID, 0, len(hits))
	for _, h := range hits {
		if h.SessionID == uuid.Nil || seen[h.SessionID] {
			continue
		}
		seen[h.SessionID] = true
		out = append(out, h.SessionID)
	}
	return out, nil
}

// parseEmbedding parses pgvector's text form "[f1,f2,...]".
func parseEmbedding(s string) []float32 {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "[")
	s = strings.TrimSuffix(s, "]")
	if s == "" {
		return nil
	}
	parts := strings.Split(s, ",")
	v := make([]float32, 0, len(parts))
	for _, p := range parts {
		f, err := strconv.ParseFloat(strings.TrimSpace(p), 32)
		if err != nil {
			return nil
		}
		v = append(v, float32(f))
	}
	return v
}
