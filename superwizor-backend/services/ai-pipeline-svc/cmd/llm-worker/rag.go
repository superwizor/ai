package llmworker

import (
	"math"
	"time"

	"github.com/google/uuid"
)

// rag.go — ranking core for the theme-level RAG context refactor
// (docs/30_RAG_THEME_CONTEXT_REFACTOR.md).
//
// Phase 1 lands the pure, fully-unit-tested scoring functions only. The
// v2 retrieval reader (loadRAGContextV2), the call-1 RAG_Themes write
// side, and the call-1/call-2 split that consume these arrive in later
// phases. Everything here is intentionally free of DB, KMS, and Vertex
// dependencies so it can be exercised in isolation — `now` is injected
// rather than read from the clock for the same reason.

const (
	// ragRecencyHalfLifeDays sets how fast a prior memory's ranking
	// weight decays: 1.0 today → 0.5 at this many days old. 90d ≈ one
	// quarter — recent threads beat equally-similar older ones without
	// burying genuinely relevant history.
	ragRecencyHalfLifeDays = 90.0

	// ragRecencyFloor bounds recency's influence. The final score is
	// cosine × (floor + (1-floor)*recency). At 0.7, an ancient but
	// perfectly-matching memory still scores 70% of a same-day one —
	// recency tunes ordering, it never dominates relevance.
	ragRecencyFloor = 0.7

	// ragMaxHits caps the retrieved context block: 1 anchor (previous
	// session) + up to 5 semantic hits.
	ragMaxHits = 6

	// ragPerSessionCap limits how many rows a single prior session may
	// contribute, so one chatty session can't crowd out the rest.
	ragPerSessionCap = 2

	// ragDupSimThreshold is the MMR near-duplicate gate: a candidate
	// whose cosine similarity to any already-selected row exceeds this
	// is skipped, so the block spans distinct threads (e.g. "intimidating
	// mother" AND "work stress") instead of three copies of the
	// strongest one.
	ragDupSimThreshold = 0.92
)

// ragCandidate is one prior-session memory row in the ranking pool.
// Embedding-only by design — plaintext is decrypted lazily for the
// winners, never during ranking (docs/30 §3.3).
type ragCandidate struct {
	ID        uuid.UUID
	SessionID uuid.UUID
	ChunkType string // "summary" | "theme"
	CreatedAt time.Time
	Embedding []float32

	score float64 // filled in by selectRAGHits
}

// cosineSim returns cosine similarity in [-1, 1]. It returns 0 when the
// vectors differ in length, are empty, or either has zero norm — the
// last case makes legacy zero-vector rows rank neutrally so they can
// never outrank a real match.
func cosineSim(a, b []float32) float64 {
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

// recencyWeight decays exponentially from 1.0 at age 0 to 0.5 at
// ragRecencyHalfLifeDays. Negative ages (clock skew) clamp to 1.0.
func recencyWeight(ageDays float64) float64 {
	if ageDays < 0 {
		ageDays = 0
	}
	return math.Exp(-ageDays * math.Ln2 / ragRecencyHalfLifeDays)
}

// scoreCandidate is the best similarity across the current session's
// query (theme) vectors, modulated by recency. Result ∈ [0, maxSim];
// an empty query set scores 0.
func scoreCandidate(emb []float32, queryVecs [][]float32, ageDays float64) float64 {
	best := 0.0
	for _, q := range queryVecs {
		if s := cosineSim(emb, q); s > best {
			best = s
		}
	}
	return best * (ragRecencyFloor + (1-ragRecencyFloor)*recencyWeight(ageDays))
}

// selectRAGHits ranks the candidate pool into the ordered set of
// memories to inject into call-2:
//
//   - the anchor (the previous session's summary, identified by
//     anchorID) is always selected first when present, regardless of
//     score, for clinical continuity;
//   - remaining slots are filled greedily by descending score, subject
//     to: at most ragPerSessionCap rows per session; no candidate whose
//     similarity to an already-selected row exceeds ragDupSimThreshold
//     (MMR diversity); and a strictly-positive score (zero-vector /
//     no-match rows never surface);
//   - at most ragMaxHits rows total.
//
// now is injected (not read from the clock) so ranking is deterministic
// under test. The returned rows carry their computed score.
func selectRAGHits(cands []ragCandidate, queryVecs [][]float32, anchorID uuid.UUID, now time.Time) []ragCandidate {
	scored := make([]ragCandidate, len(cands))
	copy(scored, cands)
	for i := range scored {
		ageDays := now.Sub(scored[i].CreatedAt).Hours() / 24
		scored[i].score = scoreCandidate(scored[i].Embedding, queryVecs, ageDays)
	}

	selected := make([]ragCandidate, 0, ragMaxHits)
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

	for len(selected) < ragMaxHits {
		best := -1
		for i := range scored {
			if usedIdx[i] {
				continue
			}
			c := scored[i]
			if c.score <= 0 {
				continue // zero-vector / no-match rows never surface
			}
			if perSession[c.SessionID] >= ragPerSessionCap {
				continue
			}
			dup := false
			for _, s := range selected {
				if cosineSim(c.Embedding, s.Embedding) > ragDupSimThreshold {
					dup = true
					break
				}
			}
			if dup {
				continue
			}
			// Strictly-greater keeps selection stable on score ties:
			// the earliest candidate in input order wins.
			if best == -1 || c.score > scored[best].score {
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
