package sttgcs

import (
	"testing"

	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
)

func TestMergeChirpResults_SingleChunk_Passthrough(t *testing.T) {
	words := []chunker.Word{
		{Text: "hello", StartMS: 100, EndMS: 400, Confidence: 0.95},
		{Text: "world", StartMS: 500, EndMS: 800, Confidence: 0.92, SpeakerLabel: "1"},
		{Text: "again", StartMS: 1200, EndMS: 1500, Confidence: 0.91, SpeakerLabel: "2"},
	}
	parts := []ChunkResult{{
		ChunkIndex:           0,
		StartOffsetMS:        0,
		LanguageCode:         "pl-PL",
		UsedNativeDiarization: true,
		Words:                words,
	}}

	merged, summary, stats := MergeChirpResults(parts)

	if len(merged) != 3 {
		t.Fatalf("merged word count = %d, want 3", len(merged))
	}
	// Stage 1: no offset shift because StartOffsetMS = 0.
	if merged[0].StartMS != 100 || merged[2].EndMS != 1500 {
		t.Errorf("Stage 1 should pass through timestamps unchanged: got %+v", merged)
	}
	if summary.WordCount != 3 {
		t.Errorf("summary.WordCount = %d, want 3", summary.WordCount)
	}
	if summary.SpeakerCount != 2 {
		t.Errorf("summary.SpeakerCount = %d, want 2", summary.SpeakerCount)
	}
	if summary.LanguageCode != "pl-PL" {
		t.Errorf("summary.LanguageCode = %q, want pl-PL", summary.LanguageCode)
	}
	if !summary.HasNativeDiarization {
		t.Errorf("summary.HasNativeDiarization should be true")
	}
	wantConf := float32((0.95 + 0.92 + 0.91) / 3.0)
	if delta := summary.ConfidenceAvg - wantConf; delta > 0.001 || delta < -0.001 {
		t.Errorf("ConfidenceAvg = %v, want ~%v", summary.ConfidenceAvg, wantConf)
	}
	if stats.FallbackCount != 0 {
		t.Errorf("Stage 1 should never fall back; got %d", stats.FallbackCount)
	}
}

func TestMergeChirpResults_EmptyParts(t *testing.T) {
	merged, summary, stats := MergeChirpResults(nil)
	if merged != nil {
		t.Errorf("want nil merged for nil parts; got %v", merged)
	}
	if summary.WordCount != 0 || stats.TotalWordCount != 0 {
		t.Errorf("want zero counts for nil parts")
	}
}

// TestMergeChirpResults_TwoChunk_AlignmentAndDedup exercises the
// Stage 2 critical path: two overlapping chunks with independent
// native-diarization labels. The merger should:
//
//   1. Align chunk-1's labels to chunk-0's space via
//      AlignAndMapSpeakers (A→1, B→2 in this fixture).
//   2. Discard chunk-1 words whose absolute timestamp falls inside
//      the [chunk-1.start, chunk-0.seam] overlap window.
//   3. Re-relativize remaining chunk-1 words to absolute time.
func TestMergeChirpResults_TwoChunk_AlignmentAndDedup(t *testing.T) {
	// Layout (ms):
	//   chunk 0: [0,         12_000]  seam=12_000
	//   chunk 1: [10_000,    20_000]  seam=20_000  overlap_ms=2000
	//
	// chunk 0 has labeled words from 0..12000 (last 2s = overlap).
	// chunk 1 has the same overlap words (10000..12000) as locals
	// 0..2000, plus 2000..10000 of unique words.

	// chunk 0 absolute words (already in absolute time):
	chunk0 := []chunker.Word{
		{Text: "first", StartMS: 0, EndMS: 500, Confidence: 0.9, SpeakerLabel: "1"},
		{Text: "thing", StartMS: 1000, EndMS: 1500, Confidence: 0.9, SpeakerLabel: "1"},
		// ... overlap region 10000..12000:
		{Text: "yes", StartMS: 10_000, EndMS: 10_300, Confidence: 0.9, SpeakerLabel: "1"},
		{Text: "ok", StartMS: 10_500, EndMS: 10_800, Confidence: 0.9, SpeakerLabel: "2"},
		{Text: "yes", StartMS: 11_000, EndMS: 11_300, Confidence: 0.9, SpeakerLabel: "1"},
		{Text: "ok", StartMS: 11_500, EndMS: 11_800, Confidence: 0.9, SpeakerLabel: "2"},
		// (continue for 6 more words to clear the 10-pair threshold)
		{Text: "a", StartMS: 10_100, EndMS: 10_200, Confidence: 0.9, SpeakerLabel: "1"},
		{Text: "b", StartMS: 10_300, EndMS: 10_400, Confidence: 0.9, SpeakerLabel: "2"},
		{Text: "c", StartMS: 10_700, EndMS: 10_800, Confidence: 0.9, SpeakerLabel: "1"},
		{Text: "d", StartMS: 10_900, EndMS: 11_000, Confidence: 0.9, SpeakerLabel: "2"},
		{Text: "e", StartMS: 11_100, EndMS: 11_200, Confidence: 0.9, SpeakerLabel: "1"},
		{Text: "f", StartMS: 11_400, EndMS: 11_500, Confidence: 0.9, SpeakerLabel: "2"},
	}

	// chunk 1 LOCAL words. start_offset = 10_000, so local = abs - 10_000.
	chunk1Local := []chunker.Word{
		// Overlap (local 0..2000): same words as chunk 0's tail, but
		// labeled "A" / "B" instead of "1" / "2".
		{Text: "yes", StartMS: 0, EndMS: 300, Confidence: 0.9, SpeakerLabel: "A"},
		{Text: "ok", StartMS: 500, EndMS: 800, Confidence: 0.9, SpeakerLabel: "B"},
		{Text: "yes", StartMS: 1000, EndMS: 1300, Confidence: 0.9, SpeakerLabel: "A"},
		{Text: "ok", StartMS: 1500, EndMS: 1800, Confidence: 0.9, SpeakerLabel: "B"},
		{Text: "a", StartMS: 100, EndMS: 200, Confidence: 0.9, SpeakerLabel: "A"},
		{Text: "b", StartMS: 300, EndMS: 400, Confidence: 0.9, SpeakerLabel: "B"},
		{Text: "c", StartMS: 700, EndMS: 800, Confidence: 0.9, SpeakerLabel: "A"},
		{Text: "d", StartMS: 900, EndMS: 1000, Confidence: 0.9, SpeakerLabel: "B"},
		{Text: "e", StartMS: 1100, EndMS: 1200, Confidence: 0.9, SpeakerLabel: "A"},
		{Text: "f", StartMS: 1400, EndMS: 1500, Confidence: 0.9, SpeakerLabel: "B"},
		// Post-overlap (local 2000..10000): unique chunk-1 content.
		{Text: "more", StartMS: 3000, EndMS: 3500, Confidence: 0.9, SpeakerLabel: "A"},
		{Text: "stuff", StartMS: 5000, EndMS: 5500, Confidence: 0.9, SpeakerLabel: "B"},
	}

	parts := []ChunkResult{
		{
			ChunkIndex:            0,
			StartOffsetMS:         0,
			SeamOffsetMS:          12_000, // absolute seam
			EndOffsetMS:           12_000,
			OverlapMS:             0,
			LanguageCode:          "en-US",
			UsedNativeDiarization: true,
			Words:                 chunk0,
		},
		{
			ChunkIndex:            1,
			StartOffsetMS:         10_000,
			SeamOffsetMS:          20_000,
			EndOffsetMS:           20_000,
			OverlapMS:             2000,
			LanguageCode:          "en-US",
			UsedNativeDiarization: true,
			Words:                 chunk1Local,
		},
	}

	merged, summary, stats := MergeChirpResults(parts)

	// Expectations:
	//   chunk 0 contributes all 12 words.
	//   chunk 1's overlap words (local 0..2000 → abs 10000..12000) are
	//   discarded. Only "more" and "stuff" remain.
	wantCount := 12 + 2
	if len(merged) != wantCount {
		t.Fatalf("len = %d, want %d", len(merged), wantCount)
	}
	// "more" should land at absolute time 13_000ms (local 3000 + 10000).
	moreFound := false
	for _, w := range merged {
		if w.Text == "more" {
			moreFound = true
			if w.StartMS != 13_000 {
				t.Errorf("'more' abs StartMS = %d, want 13_000", w.StartMS)
			}
			// Translation should have mapped A → 1.
			if w.SpeakerLabel != "1" {
				t.Errorf("'more' label = %q, want '1' (A→1 mapping)", w.SpeakerLabel)
			}
		}
	}
	if !moreFound {
		t.Fatal("'more' word not in merged stream")
	}

	if stats.FallbackCount != 0 {
		t.Errorf("happy path should not fall back; stats.FallbackCount = %d", stats.FallbackCount)
	}
	// chunk 0 had labels {1, 2}, chunk 1's A/B mapped to 1/2 — total
	// speaker set is still 2.
	if summary.SpeakerCount != 2 {
		t.Errorf("SpeakerCount = %d, want 2", summary.SpeakerCount)
	}
}

// TestMergeChirpResults_PrevMaxLabel_NoCollisionAcrossChunks is the
// regression test for the chunk-0 → chunk-1 collision bug
// (2026-05-24, found alongside the Janek Johny session). The
// scenario:
//
//   - chunk 0 has speakers "1" and "2" (no alignment, i==0 branch).
//     prevMaxLabel previously stayed at 0 going into chunk 1.
//   - chunk 1 has fresh Chirp-numbered labels "1" and "2" that
//     represent DIFFERENT people, with NO timestamp overlap with
//     chunk 0 (so AlignAndMapSpeakers gets zero matched pairs and
//     falls back to offsetLabels).
//   - In the buggy code, offsetLabels started maxLabel at
//     prevMaxLabel=0 and assigned chunk 1's "1" → "1" (collision
//     with chunk 0's actual speaker 1) and "2" → "2" (collision
//     with chunk 0's actual speaker 2).
//   - Correct behaviour: chunk 1's "1" → "3" and "2" → "4",
//     preserving the identity separation. Final speaker set: 4.
func TestMergeChirpResults_PrevMaxLabel_NoCollisionAcrossChunks(t *testing.T) {
	// chunk 0: two speakers, both labelled by Chirp as "1" / "2".
	chunk0 := []chunker.Word{
		{Text: "alpha", StartMS: 0, EndMS: 500, Confidence: 0.9, SpeakerLabel: "1"},
		{Text: "beta", StartMS: 1000, EndMS: 1500, Confidence: 0.9, SpeakerLabel: "2"},
		{Text: "gamma", StartMS: 2000, EndMS: 2500, Confidence: 0.9, SpeakerLabel: "1"},
		{Text: "delta", StartMS: 3000, EndMS: 3500, Confidence: 0.9, SpeakerLabel: "2"},
	}
	// chunk 1: two DIFFERENT speakers, also labelled "1" / "2" by
	// Chirp (independent per-call labelling). All chunk-1 words sit
	// AFTER chunk 0's seam at 12_000 ms → zero overlap → alignment
	// must fall back to offsetLabels.
	chunk1Local := []chunker.Word{
		// local 0..1000 = absolute 13_000..14_000 (post-seam).
		{Text: "epsilon", StartMS: 0, EndMS: 500, Confidence: 0.9, SpeakerLabel: "1"},
		{Text: "zeta", StartMS: 1000, EndMS: 1500, Confidence: 0.9, SpeakerLabel: "2"},
		{Text: "eta", StartMS: 2000, EndMS: 2500, Confidence: 0.9, SpeakerLabel: "1"},
		{Text: "theta", StartMS: 3000, EndMS: 3500, Confidence: 0.9, SpeakerLabel: "2"},
	}

	parts := []ChunkResult{
		{
			ChunkIndex:            0,
			StartOffsetMS:         0,
			SeamOffsetMS:          12_000,
			EndOffsetMS:           12_000,
			OverlapMS:             0,
			LanguageCode:          "en-US",
			UsedNativeDiarization: true,
			Words:                 chunk0,
		},
		{
			ChunkIndex:            1,
			StartOffsetMS:         13_000, // post-seam → no overlap with chunk 0
			SeamOffsetMS:          17_000,
			EndOffsetMS:           17_000,
			OverlapMS:             0,
			LanguageCode:          "en-US",
			UsedNativeDiarization: true,
			Words:                 chunk1Local,
		},
	}

	merged, summary, stats := MergeChirpResults(parts)

	// Sparse-overlap fallback must have fired — alignment had nothing
	// to align against.
	if stats.FallbackCount != 1 {
		t.Errorf("expected 1 alignment fallback (no overlap); got %d",
			stats.FallbackCount)
	}

	// Speaker set MUST be {1, 2, 3, 4}. Pre-fix, chunk 1's labels
	// would have collided onto {1, 2} producing a 2-speaker total
	// with WRONG identity assignment.
	if summary.SpeakerCount != 4 {
		t.Errorf("expected 4 distinct speakers after non-overlapping "+
			"chunk merge; got %d (collision regression?)",
			summary.SpeakerCount)
	}

	// Verify chunk 0's words kept their original labels.
	gotChunk0Labels := map[string]string{}
	for _, w := range merged {
		if w.StartMS < 12_000 {
			gotChunk0Labels[w.Text] = w.SpeakerLabel
		}
	}
	if gotChunk0Labels["alpha"] != "1" || gotChunk0Labels["gamma"] != "1" {
		t.Errorf("chunk 0 speaker '1' words got remapped: alpha=%q gamma=%q",
			gotChunk0Labels["alpha"], gotChunk0Labels["gamma"])
	}
	if gotChunk0Labels["beta"] != "2" || gotChunk0Labels["delta"] != "2" {
		t.Errorf("chunk 0 speaker '2' words got remapped: beta=%q delta=%q",
			gotChunk0Labels["beta"], gotChunk0Labels["delta"])
	}

	// Verify chunk 1's words got offset to new labels (NOT colliding
	// with chunk 0's "1"/"2"). Allowed range: anything >= 3.
	for _, w := range merged {
		if w.StartMS < 12_000 {
			continue
		}
		if w.SpeakerLabel == "1" || w.SpeakerLabel == "2" {
			t.Errorf("chunk 1 word %q collided onto chunk-0 label %q "+
				"(prevMaxLabel regression — should offset to >=3)",
				w.Text, w.SpeakerLabel)
		}
	}
}

// TestMergeChirpResults_MultiChunk_RelativizesOffsets validates the
// Stage 2 contract: words from later chunks get their offsets shifted
// by StartOffsetMS. Stage 1 only ever passes len==1, but the loop
// already handles len>1 — pin the behavior so Stage 2's alignment
// work can layer on top without changing the offset math.
//
// NOTE: This test does NOT exercise alignment/dedup yet — those land
// in Stage 2 along with AlignAndMapSpeakers.
func TestMergeChirpResults_MultiChunk_RelativizesOffsets(t *testing.T) {
	parts := []ChunkResult{
		{
			ChunkIndex:     0,
			StartOffsetMS:  0,
			LanguageCode:   "en-US",
			Words: []chunker.Word{
				{Text: "first", StartMS: 100, EndMS: 400, Confidence: 0.9, SpeakerLabel: "1"},
			},
		},
		{
			ChunkIndex:     1,
			StartOffsetMS:  1_140_000, // 19 min mark
			LanguageCode:   "en-US",
			Words: []chunker.Word{
				{Text: "second", StartMS: 500, EndMS: 900, Confidence: 0.85, SpeakerLabel: "2"},
			},
		},
	}
	merged, summary, _ := MergeChirpResults(parts)

	if len(merged) != 2 {
		t.Fatalf("want 2 merged words; got %d", len(merged))
	}
	// Chunk 1's word "second" started at 500ms local → 1,140,500ms absolute.
	if merged[1].StartMS != 1_140_500 {
		t.Errorf("absolute StartMS for chunk-1 word = %d, want 1140500", merged[1].StartMS)
	}
	if merged[1].EndMS != 1_140_900 {
		t.Errorf("absolute EndMS for chunk-1 word = %d, want 1140900", merged[1].EndMS)
	}
	if summary.SpeakerCount != 2 {
		t.Errorf("want 2 speakers; got %d", summary.SpeakerCount)
	}
}
