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
