// Package rag provides the pure scoring and ranking functions for
// theme-level RAG context retrieval. These are dependency-free (no DB,
// KMS, or Vertex AI) and fully unit-testable.
//
// Extracted from services/ai-pipeline-svc/cmd/llm-worker/rag.go to
// allow reuse by clinical-svc (AI assistant) and any future consumer.
//
// Design doc: docs/35_RAG_THEME_CONTEXT_REFACTOR.md
package rag

import (
	"math"
	"time"

	"github.com/google/uuid"
)

// ── Tuning Constants ──────────────────────────────────────────────────
//
// Exported so consumers can inspect them; values are not configurable at
// runtime — they were tuned empirically (docs/30 §3.4, prod-verified
// 2026-06-10).

const (
	// RecencyHalfLifeDays sets how fast a prior memory's ranking weight
	// decays: 1.0 today → 0.5 at this many days old. 90d ≈ one quarter
	// — recent threads beat equally-similar older ones without burying
	// genuinely relevant history.
	RecencyHalfLifeDays = 90.0

	// RecencyFloor bounds recency's influence. The final score is
	// cosine × (floor + (1-floor)*recency). At 0.7, an ancient but
	// perfectly-matching memory still scores 70% of a same-day one —
	// recency tunes ordering, it never dominates relevance.
	RecencyFloor = 0.7

	// MaxHits caps the retrieved context block: 1 anchor (previous
	// session) + up to 5 semantic hits.
	MaxHits = 6

	// PerSessionCap limits how many rows a single prior session may
	// contribute, so one chatty session can't crowd out the rest.
	PerSessionCap = 2

	// DupSimThreshold is the MMR near-duplicate gate: a candidate
	// whose cosine similarity to any already-selected row exceeds this
	// is skipped, so the block spans distinct threads.
	DupSimThreshold = 0.92

	// LookbackSessions bounds the candidate pool to the patient's most
	// recent N sessions. ≈9 months weekly / ≈18 months bi-weekly.
	LookbackSessions = 36

	// ContextMaxChars caps the assembled call-2 context block.
	// ≈4k tokens — anchor summary + ~5 theme hits, still <10% of the
	// call-2 input window.
	ContextMaxChars = 8000
)

// ── Candidate ─────────────────────────────────────────────────────────

// Candidate is one prior-session memory row in the ranking pool.
// Embedding-only by design — plaintext is decrypted lazily for the
// winners, never during ranking (docs/30 §3.3).
type Candidate struct {
	ID        uuid.UUID
	SessionID uuid.UUID
	ChunkType string // "summary" | "theme"
	CreatedAt time.Time
	Embedding []float32

	Score float64 // filled in by SelectHits
}

// ── Scoring Functions ─────────────────────────────────────────────────

// CosineSim returns cosine similarity in [-1, 1]. It returns 0 when the
// vectors differ in length, are empty, or either has zero norm — the
// last case makes legacy zero-vector rows rank neutrally so they can
// never outrank a real match.
func CosineSim(a, b []float32) float64 {
	if len(a) == 0 || len(a) != len(b) {
		return 0
	}
	var dot, na, nb float64
	for i := range a {
		av, bv := float64(a[i]), float64(b[i])
		dot += av * bv
		na += av * av
		nb += bv * bv
	}
	if na == 0 || nb == 0 {
		return 0
	}
	return dot / (math.Sqrt(na) * math.Sqrt(nb))
}

// RecencyWeight decays exponentially from 1.0 at age 0 to 0.5 at
// RecencyHalfLifeDays. Negative ages (clock skew) clamp to 1.0.
func RecencyWeight(ageDays float64) float64 {
	if ageDays < 0 {
		ageDays = 0
	}
	return math.Exp(-ageDays * math.Ln2 / RecencyHalfLifeDays)
}

// ScoreCandidate is the best similarity across the current session's
// query (theme) vectors, modulated by recency. Result ∈ [0, maxSim];
// an empty query set scores 0.
func ScoreCandidate(emb []float32, queryVecs [][]float32, ageDays float64) float64 {
	best := 0.0
	for _, q := range queryVecs {
		if s := CosineSim(emb, q); s > best {
			best = s
		}
	}
	return best * (RecencyFloor + (1-RecencyFloor)*RecencyWeight(ageDays))
}

// ── Hit Selection ─────────────────────────────────────────────────────

// SelectHits ranks the candidate pool into the ordered set of memories
// to inject into the AI context:
//
//   - the anchor (the previous session's summary, identified by
//     anchorID) is always selected first when present, regardless of
//     score, for clinical continuity;
//   - remaining slots are filled greedily by descending score, subject
//     to: at most PerSessionCap rows per session; no candidate whose
//     similarity to an already-selected row exceeds DupSimThreshold
//     (MMR diversity); and a strictly-positive score (zero-vector /
//     no-match rows never surface);
//   - at most MaxHits rows total.
//
// now is injected (not read from the clock) so ranking is deterministic
// under test. The returned rows carry their computed Score.
func SelectHits(cands []Candidate, queryVecs [][]float32, anchorID uuid.UUID, now time.Time) []Candidate {
	scored := make([]Candidate, len(cands))
	copy(scored, cands)
	for i := range scored {
		ageDays := now.Sub(scored[i].CreatedAt).Hours() / 24
		scored[i].Score = ScoreCandidate(scored[i].Embedding, queryVecs, ageDays)
	}

	selected := make([]Candidate, 0, MaxHits)
	perSession := map[uuid.UUID]int{}
	usedIdx := map[int]bool{}

	// Anchor first (continuity), if it's in the pool.
	for i := range scored {
		if anchorID != uuid.Nil && scored[i].ID == anchorID {
			selected = append(selected, scored[i])
			perSession[scored[i].SessionID]++
			usedIdx[i] = true
			break
		}
	}

	for len(selected) < MaxHits {
		best := -1
		for i := range scored {
			if usedIdx[i] {
				continue
			}
			c := scored[i]
			if c.Score <= 0 {
				continue // zero-vector / no-match rows never surface
			}
			if perSession[c.SessionID] >= PerSessionCap {
				continue
			}
			dup := false
			for _, s := range selected {
				if CosineSim(c.Embedding, s.Embedding) > DupSimThreshold {
					dup = true
					break
				}
			}
			if dup {
				continue
			}
			// Strictly-greater keeps selection stable on score ties:
			// the earliest candidate in input order wins.
			if best == -1 || c.Score > scored[best].Score {
				best = i
			}
		}
		if best == -1 {
			break
		}
		selected = append(selected, scored[best])
		perSession[scored[best].SessionID]++
		usedIdx[best] = true
	}
	return selected
}
