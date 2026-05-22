package sttgcs

import (
	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
)

// ChunkResult bundles one chunk's Chirp output for the merger.
// Fields mirror the stt_operations row + the parsed Chirp response.
//
// Stage 1 (single chunk per session): the merger gets one of these
// and emits a passthrough []chunker.Word + summary.
//
// Stage 2 (forthcoming): N of these per session in chunk_index
// order; merger does time-anchored speaker-label alignment across
// adjacent chunks' overlap windows, deduplicates words inside the
// overlap, and re-relativizes to absolute audio time.
type ChunkResult struct {
	ChunkIndex           int
	StartOffsetMS        int64
	SeamOffsetMS         int64
	EndOffsetMS          int64
	OverlapMS            int            // overlap with the prior chunk; 0 for chunk 0
	UsedNativeDiarization bool
	LanguageCode         string

	// Words from this chunk in LOCAL TIME (chunk-relative offsets).
	// Caller is responsible for adjusting to absolute time during merge.
	Words []chunker.Word
}

// MergeSummary mirrors the existing stt-worker TranscriptResult shape
// (in cmd/stt-worker/main.go) so the merger can drop straight into
// the persistTranscript path. Re-declared here to keep the sttgcs
// package import-free of the worker binary.
type MergeSummary struct {
	WordCount            int
	SpeakerCount         int
	LanguageCode         string
	ConfidenceAvg        float32
	HasNativeDiarization bool
}

// MergeStats is returned alongside the merged stream for
// observability. Stage 2 will populate FallbackCount when the
// alignment algorithm falls back to label-by-ordinal offset.
type MergeStats struct {
	TotalWordCount  int
	FallbackCount   int // # of seams that fell back; 0 in Stage 1
}

// MergeChirpResults stitches per-chunk Chirp outputs into a single
// word stream with absolute-time offsets.
//
// Stage 1 contract: len(parts) == 1 (single chunk per session,
// chunk_index = 0, start_offset_ms = 0). Words are passed through
// with their original timestamps; summary is computed from the
// single ChunkResult.
//
// Stage 2 contract: len(parts) >= 1. For each parts[i > 0]:
//   1. Run time-anchored speaker-label alignment across the
//      [parts[i].StartOffsetMS, parts[i-1].SeamOffsetMS] overlap
//      window with parts[i-1].Words (already in absolute time).
//   2. Rewrite parts[i].Words speaker labels via the translation map.
//   3. Discard parts[i] words whose absolute StartMS falls inside
//      the overlap (dedup against parts[i-1]'s tail).
//   4. Add parts[i].StartOffsetMS to remaining words' StartMS/EndMS
//      and append.
//
// In Stage 1 the alignment / dedup steps are skipped; this function
// is a thin shim. Keeping the signature stable lets Stage 2 land
// without touching the caller in stt-finalize.
func MergeChirpResults(parts []ChunkResult) ([]chunker.Word, *MergeSummary, MergeStats) {
	var stats MergeStats
	if len(parts) == 0 {
		return nil, &MergeSummary{}, stats
	}

	merged := make([]chunker.Word, 0, estimateTotalWords(parts))
	speakerSet := map[string]bool{}
	languageCode := ""
	var totalConfidence float32
	var confidenceWords int

	for i, p := range parts {
		// Stage 1: only chunk 0 ever lands here. Stage 2: i > 0
		// chunks would go through AlignAndMapSpeakers + overlap dedup
		// before this loop. Keep the per-word loop ready for that.
		_ = i

		for _, w := range p.Words {
			abs := chunker.Word{
				Text:         w.Text,
				StartMS:      w.StartMS + p.StartOffsetMS,
				EndMS:        w.EndMS + p.StartOffsetMS,
				Confidence:   w.Confidence,
				SpeakerLabel: w.SpeakerLabel,
			}
			merged = append(merged, abs)
			if w.SpeakerLabel != "" {
				speakerSet[w.SpeakerLabel] = true
			}
			if w.Confidence > 0 {
				totalConfidence += w.Confidence
				confidenceWords++
			}
		}
		if languageCode == "" && p.LanguageCode != "" {
			languageCode = p.LanguageCode
		}
	}

	stats.TotalWordCount = len(merged)

	summary := &MergeSummary{
		WordCount:            len(merged),
		SpeakerCount:         len(speakerSet),
		LanguageCode:         languageCode,
		HasNativeDiarization: parts[0].UsedNativeDiarization,
	}
	if confidenceWords > 0 {
		summary.ConfidenceAvg = totalConfidence / float32(confidenceWords)
	}
	return merged, summary, stats
}

func estimateTotalWords(parts []ChunkResult) int {
	n := 0
	for _, p := range parts {
		n += len(p.Words)
	}
	return n
}
