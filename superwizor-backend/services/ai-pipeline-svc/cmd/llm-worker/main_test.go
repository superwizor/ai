package llmworker

import (
	"sort"
	"testing"

	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/diarization"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/transcriptfmt"
)

// Test setup for the Stage-2-alignment orphan-reattach branch in
// markdownResultToPayload (added 2026-05-23 after the Gabriela En
// test session 78679bff-…). The shape we want to exercise:
//
//   - native=true (Chirp diarization was on; per-word labels exist)
//   - LLM call 1 inferred 2 speakers, Index = {1, 2}
//   - Transcript chunks carry SpeakerTag ∈ {1, 2, 3}, where tag=3
//     is the "ghost speaker" from cross-chunk alignment offset.
//     Without the reattach, tag=3 chunks fall out of every group
//     and disappear from the report — the user-visible "missing
//     person" symptom.
//
// Helper: build a Chunk with explicit (chunkIdx, startMS, tag).
func ch(chunkIdx int, startMS int64, tag int32) transcriptfmt.Chunk {
	return transcriptfmt.Chunk{
		ChunkIdx:   chunkIdx,
		StartMS:    startMS,
		EndMS:      startMS + 1000,
		SpeakerTag: tag,
	}
}

func TestMarkdownResultToPayload_Stage2OrphanReattach(t *testing.T) {
	// Chunks 0,1 are speaker 1 (therapist) — clean Chirp labels.
	// Chunks 2,3 are speaker 2 (patient) — clean Chirp labels.
	// Chunks 4,5 are tag=3 — the alignment ghost. Bracketed by
	// patient-tagged chunks on both sides → adjacency picks
	// patient.
	// Chunks 6,7 are speaker 2 again.
	chunks := []transcriptfmt.Chunk{
		ch(0, 0, 1),
		ch(1, 1000, 1),
		ch(2, 2000, 2),
		ch(3, 3000, 2),
		ch(4, 4000, 3), // ghost
		ch(5, 5000, 3), // ghost
		ch(6, 6000, 2),
		ch(7, 7000, 2),
	}

	r := diarization.Result{
		Speakers: []diarization.Speaker{
			{Index: 1, Role: "therapist", Confidence: 0.95},
			{Index: 2, Role: "patient", Confidence: 0.93},
		},
	}

	payload := markdownResultToPayload(r, chunks, true)

	if len(payload.SpeakerRoleInference.SpeakerGroups) != 2 {
		t.Fatalf("expected 2 SpeakerGroups, got %d",
			len(payload.SpeakerRoleInference.SpeakerGroups))
	}

	// groups[0] = therapist (Index=1) → chunks 0, 1.
	therapist := payload.SpeakerRoleInference.SpeakerGroups[0]
	sort.Ints(therapist.ChunkIndices)
	if got, want := therapist.ChunkIndices, []int{0, 1}; !sliceEq(got, want) {
		t.Errorf("therapist.ChunkIndices = %v; want %v", got, want)
	}

	// groups[1] = patient (Index=2) → chunks 2,3,6,7 PLUS the
	// reattached ghosts 4,5.
	patient := payload.SpeakerRoleInference.SpeakerGroups[1]
	sort.Ints(patient.ChunkIndices)
	if got, want := patient.ChunkIndices, []int{2, 3, 4, 5, 6, 7}; !sliceEq(got, want) {
		t.Errorf("patient.ChunkIndices = %v; want %v (ghost chunks 4,5 should reattach to patient via adjacency)", got, want)
	}
}

// Regression guard: when no ghost tags exist, the new branch must
// be a no-op (it shouldn't reshuffle chunks that already mapped
// cleanly to known LLM Index values).
func TestMarkdownResultToPayload_Stage2NoOpWhenNoGhost(t *testing.T) {
	chunks := []transcriptfmt.Chunk{
		ch(0, 0, 1),
		ch(1, 1000, 2),
		ch(2, 2000, 1),
		ch(3, 3000, 2),
	}
	r := diarization.Result{
		Speakers: []diarization.Speaker{
			{Index: 1, Role: "therapist"},
			{Index: 2, Role: "patient"},
		},
	}
	payload := markdownResultToPayload(r, chunks, true)
	g := payload.SpeakerRoleInference.SpeakerGroups
	if len(g) != 2 {
		t.Fatalf("expected 2 groups, got %d", len(g))
	}
	sort.Ints(g[0].ChunkIndices)
	sort.Ints(g[1].ChunkIndices)
	if !sliceEq(g[0].ChunkIndices, []int{0, 2}) {
		t.Errorf("therapist.ChunkIndices = %v; want [0 2]", g[0].ChunkIndices)
	}
	if !sliceEq(g[1].ChunkIndices, []int{1, 3}) {
		t.Errorf("patient.ChunkIndices = %v; want [1 3]", g[1].ChunkIndices)
	}
}

// Regression guard: tag=0 orphans must still flow through the
// existing emptyCount==1 branch (the original ADR-IMPL-007a fix)
// and NOT through the new extra-tag branch. They are different
// failure modes — Chirp dropped labels vs. alignment created a
// fresh label — and conflating them would double-assign chunks.
func TestMarkdownResultToPayload_Stage1OrphanReattachStillWorks(t *testing.T) {
	chunks := []transcriptfmt.Chunk{
		ch(0, 0, 1),
		ch(1, 1000, 1),
		ch(2, 2000, 0), // tag=0 orphan (Chirp didn't label)
		ch(3, 3000, 0),
	}
	// LLM inferred 2 speakers, patient group will end up empty
	// because every labeled chunk is therapist (tag=1).
	r := diarization.Result{
		Speakers: []diarization.Speaker{
			{Index: 1, Role: "therapist"},
			{Index: 2, Role: "patient"},
		},
	}
	payload := markdownResultToPayload(r, chunks, true)
	g := payload.SpeakerRoleInference.SpeakerGroups
	sort.Ints(g[0].ChunkIndices)
	sort.Ints(g[1].ChunkIndices)
	if !sliceEq(g[0].ChunkIndices, []int{0, 1}) {
		t.Errorf("therapist.ChunkIndices = %v; want [0 1]", g[0].ChunkIndices)
	}
	if !sliceEq(g[1].ChunkIndices, []int{2, 3}) {
		t.Errorf("patient.ChunkIndices = %v; want [2 3] (Stage 1 tag=0 reattach)", g[1].ChunkIndices)
	}
}

func TestNearestKnownGroupIndex(t *testing.T) {
	chunks := []transcriptfmt.Chunk{
		ch(0, 0, 1),
		ch(1, 1000, 1),
		ch(2, 2000, 3),
		ch(3, 3000, 2),
		ch(4, 4000, 2),
	}
	known := map[int32]int{1: 0, 2: 1}

	// chunks[2] (tag=3): nearest forward is chunks[3] (tag=2, gIdx=1)
	// at distance 1; nearest backward is chunks[1] (tag=1, gIdx=0)
	// at distance 1. Tie → backward wins per the helper's contract.
	if got := nearestKnownGroupIndex(chunks, 2, known); got != 0 {
		t.Errorf("ties prefer backward; got gIdx=%d want 0", got)
	}
}

func sliceEq(a, b []int) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
