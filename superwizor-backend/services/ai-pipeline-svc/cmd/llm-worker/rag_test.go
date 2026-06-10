package llmworker

import (
	"math"
	"testing"
	"time"

	"github.com/google/uuid"
)

func approxEq(a, b float64) bool { return math.Abs(a-b) < 1e-9 }

func TestCosineSim(t *testing.T) {
	tests := []struct {
		name string
		a, b []float32
		want float64
	}{
		{"identical", []float32{1, 2, 3}, []float32{1, 2, 3}, 1},
		{"scaled identical", []float32{1, 0, 0}, []float32{5, 0, 0}, 1},
		{"orthogonal", []float32{1, 0, 0}, []float32{0, 1, 0}, 0},
		{"opposite", []float32{1, 0, 0}, []float32{-1, 0, 0}, -1},
		{"zero vector a", []float32{0, 0, 0}, []float32{1, 0, 0}, 0},
		{"zero vector b", []float32{1, 0, 0}, []float32{0, 0, 0}, 0},
		{"length mismatch", []float32{1, 0}, []float32{1, 0, 0}, 0},
		{"empty", []float32{}, []float32{}, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := cosineSim(tt.a, tt.b); !approxEq(got, tt.want) {
				t.Errorf("cosineSim(%v,%v) = %v, want %v", tt.a, tt.b, got, tt.want)
			}
		})
	}
}

func TestRecencyWeight(t *testing.T) {
	tests := []struct {
		name    string
		ageDays float64
		want    float64
	}{
		{"today", 0, 1.0},
		{"half-life", ragRecencyHalfLifeDays, 0.5},
		{"two half-lives", 2 * ragRecencyHalfLifeDays, 0.25},
		{"negative clamps to now", -10, 1.0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := recencyWeight(tt.ageDays); math.Abs(got-tt.want) > 1e-6 {
				t.Errorf("recencyWeight(%v) = %v, want %v", tt.ageDays, got, tt.want)
			}
		})
	}
	// Strictly decreasing.
	prev := recencyWeight(0)
	for _, d := range []float64{10, 30, 90, 180, 365} {
		cur := recencyWeight(d)
		if cur >= prev {
			t.Errorf("recencyWeight not strictly decreasing at %v days (%v >= %v)", d, cur, prev)
		}
		prev = cur
	}
}

func TestScoreCandidate(t *testing.T) {
	mother := []float32{1, 0, 0}
	work := []float32{0, 1, 0}
	queries := [][]float32{mother, work}

	// Perfect match on the "work" theme, today → score == recency-floored max sim.
	gotToday := scoreCandidate(work, queries, 0)
	if !approxEq(gotToday, 1.0) {
		t.Errorf("perfect match today = %v, want 1.0", gotToday)
	}

	// Same match, one half-life old → cosine 1 × (0.7 + 0.3×0.5) = 0.85.
	gotOld := scoreCandidate(work, queries, ragRecencyHalfLifeDays)
	if math.Abs(gotOld-0.85) > 1e-6 {
		t.Errorf("perfect match at half-life = %v, want 0.85", gotOld)
	}

	// Takes the MAX across themes, not the average: a row matching only
	// "work" still scores ~1 even though it's orthogonal to "mother".
	if gotOld >= gotToday {
		t.Errorf("recency should reduce score: old %v should be < today %v", gotOld, gotToday)
	}

	// Empty query set → 0.
	if got := scoreCandidate(work, nil, 0); got != 0 {
		t.Errorf("empty queries = %v, want 0", got)
	}

	// An old perfect match still beats the recency floor (≥0.7×maxSim).
	if gotOld < ragRecencyFloor {
		t.Errorf("floored score %v should stay ≥ floor %v for a perfect match", gotOld, ragRecencyFloor)
	}
}

// fixedNow keeps recency neutral (age 0) so these tests isolate the
// similarity/diversity/anchor logic.
var fixedNow = time.Date(2026, 6, 10, 0, 0, 0, 0, time.UTC)

func mkCand(id, sess uuid.UUID, chunkType string, emb []float32) ragCandidate {
	return ragCandidate{ID: id, SessionID: sess, ChunkType: chunkType, CreatedAt: fixedNow, Embedding: emb}
}

// The headline case from docs/30: a session about an intimidating mother
// AND work stress must retrieve BOTH threads, not three near-duplicate
// "mother" memories.
func TestSelectRAGHits_DiversityBeatsDuplicates(t *testing.T) {
	mother := []float32{1, 0, 0}
	work := []float32{0, 1, 0}
	queries := [][]float32{mother, work}

	m1 := mkCand(uuid.New(), uuid.New(), "theme", []float32{1, 0, 0})
	m2 := mkCand(uuid.New(), uuid.New(), "theme", []float32{0.99, 0.01, 0})  // near-dup of m1
	m3 := mkCand(uuid.New(), uuid.New(), "theme", []float32{0.98, 0, 0.02}) // near-dup of m1
	w1 := mkCand(uuid.New(), uuid.New(), "theme", []float32{0, 1, 0})

	got := selectRAGHits([]ragCandidate{m1, m2, m3, w1}, queries, uuid.Nil, fixedNow)

	if len(got) != 2 {
		t.Fatalf("want 2 selected (1 mother + 1 work), got %d", len(got))
	}
	// The work thread must be represented despite 3 mother candidates.
	foundWork := false
	for _, c := range got {
		if c.ID == w1.ID {
			foundWork = true
		}
	}
	if !foundWork {
		t.Errorf("work-stress thread was crowded out by mother near-duplicates: %+v", got)
	}
}

func TestSelectRAGHits_AnchorAlwaysIncluded(t *testing.T) {
	work := []float32{0, 1, 0}
	queries := [][]float32{work}

	// Anchor is the previous session's summary — orthogonal to the query
	// (low score) but must still be selected for continuity.
	anchor := mkCand(uuid.New(), uuid.New(), "summary", []float32{0, 0, 1})
	hit := mkCand(uuid.New(), uuid.New(), "theme", []float32{0, 1, 0})

	got := selectRAGHits([]ragCandidate{anchor, hit}, queries, anchor.ID, fixedNow)

	if len(got) == 0 || got[0].ID != anchor.ID {
		t.Fatalf("anchor must be selected first; got %+v", got)
	}
}

func TestSelectRAGHits_PerSessionCap(t *testing.T) {
	q := [][]float32{{1, 0, 0}}
	sess := uuid.New() // all four rows belong to ONE session

	cands := []ragCandidate{
		mkCand(uuid.New(), sess, "theme", []float32{1, 0, 0}),
		mkCand(uuid.New(), sess, "theme", []float32{0.6, 0.8, 0}),    // distinct enough to dodge dup gate
		mkCand(uuid.New(), sess, "theme", []float32{0.3, 0, 0.95}),   // distinct again
		mkCand(uuid.New(), sess, "theme", []float32{0.2, 0.97, 0.1}), // distinct again
	}
	got := selectRAGHits(cands, q, uuid.Nil, fixedNow)
	if len(got) > ragPerSessionCap {
		t.Errorf("per-session cap %d violated: selected %d from one session", ragPerSessionCap, len(got))
	}
}

func TestSelectRAGHits_ZeroVectorNeverSelected(t *testing.T) {
	q := [][]float32{{1, 0, 0}}
	zero := mkCand(uuid.New(), uuid.New(), "summary", []float32{0, 0, 0}) // legacy zero-vector row
	real := mkCand(uuid.New(), uuid.New(), "theme", []float32{1, 0, 0})

	got := selectRAGHits([]ragCandidate{zero, real}, q, uuid.Nil, fixedNow)
	for _, c := range got {
		if c.ID == zero.ID {
			t.Errorf("zero-vector row must never be selected; got %+v", got)
		}
	}
	if len(got) != 1 || got[0].ID != real.ID {
		t.Errorf("want only the real match, got %+v", got)
	}
}

func TestSelectRAGHits_RespectsMaxHits(t *testing.T) {
	q := [][]float32{{1, 0, 0}}
	var cands []ragCandidate
	// 12 distinct sessions, each with a distinct-enough vector to clear
	// the dup gate, all positively matching the query.
	for i := 0; i < 12; i++ {
		v := []float32{1, float32(i) * 0.05, 0}
		cands = append(cands, mkCand(uuid.New(), uuid.New(), "theme", v))
	}
	got := selectRAGHits(cands, q, uuid.Nil, fixedNow)
	if len(got) > ragMaxHits {
		t.Errorf("selected %d exceeds ragMaxHits %d", len(got), ragMaxHits)
	}
}

func TestSelectRAGHits_EmptyPool(t *testing.T) {
	got := selectRAGHits(nil, [][]float32{{1, 0, 0}}, uuid.Nil, fixedNow)
	if len(got) != 0 {
		t.Errorf("empty pool should yield no hits, got %d", len(got))
	}
}

// parseEmbedding must invert vectorToString — a mismatch silently
// corrupts every cosine score in the pool.
func TestParseEmbedding_RoundTrip(t *testing.T) {
	orig := []float32{1.5, -2.25, 0, 0.123456, 768.0}
	got := parseEmbedding(vectorToString(orig))
	if len(got) != len(orig) {
		t.Fatalf("len %d != %d", len(got), len(orig))
	}
	for i := range orig {
		if math.Abs(float64(got[i]-orig[i])) > 1e-4 {
			t.Errorf("index %d: got %v, want %v", i, got[i], orig[i])
		}
	}
}

func TestParseEmbedding_Edge(t *testing.T) {
	if v := parseEmbedding("[]"); v != nil {
		t.Errorf("empty vector should be nil, got %v", v)
	}
	if v := parseEmbedding("[1,abc,3]"); v != nil {
		t.Errorf("malformed vector should be nil, got %v", v)
	}
	if v := parseEmbedding("  [ 1 , 2 ]  "); len(v) != 2 || v[0] != 1 || v[1] != 2 {
		t.Errorf("whitespace handling failed: %v", v)
	}
}
