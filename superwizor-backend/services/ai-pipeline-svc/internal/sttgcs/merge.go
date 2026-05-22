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
// Stage 1 (len(parts) == 1): pass-through. Words emitted with their
// original timestamps; summary computed from the single ChunkResult.
//
// Stage 2 (len(parts) > 1): for each parts[i > 0]:
//   1. Run AlignAndMapSpeakers across the [parts[i].StartOffsetMS,
//      parts[i-1].SeamOffsetMS] overlap window, using the prior
//      chunk's IMMEDIATELY-MERGED absolute-time words (priorAbsWords)
//      — NOT the entire merged stream so far. The bug-fix from the
//      v1 design sketch.
//   2. Discard current-chunk words whose ABSOLUTE StartMS falls
//      inside the overlap window (dedup against priorAbsWords).
//   3. Re-relativize remaining words by parts[i].StartOffsetMS and
//      append.
//
// stats.FallbackCount counts seams where alignment fell back to the
// label-by-ordinal-offset path — observability for production drift.
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

	// Rolling state across chunks. priorAbsWords is the IMMEDIATELY
	// PRIOR chunk's words in absolute time (post-alignment). The
	// next iteration's AlignAndMapSpeakers uses only this slice —
	// O(overlap_size) alignment cost, not O(N²).
	var priorAbsWords []chunker.Word
	var priorSeamMS int64
	prevMaxLabel := 0

	for i, p := range parts {
		// 1. Take chunk's local words (relative to its own start).
		localWords := p.Words

		// 2. Cross-chunk alignment: only for i > 0 AND when both
		//    sides have native diarization labels.
		var mappedLocal []chunker.Word
		if i == 0 || !p.UsedNativeDiarization {
			mappedLocal = localWords
		} else {
			var fellBack bool
			mappedLocal, prevMaxLabel, fellBack = AlignAndMapSpeakers(
				priorAbsWords,
				localWords,
				p.StartOffsetMS,
				priorSeamMS,
				prevMaxLabel,
			)
			if fellBack {
				stats.FallbackCount++
			}
		}

		// 3. Dedup: discard current-chunk words whose ABSOLUTE
		//    StartMS falls inside the overlap with the prior chunk.
		//    (Chunk 0 has no prior, so priorSeamMS = 0 and the
		//    condition trivially fails — nothing dropped.)
		overlapAbsEnd := priorSeamMS
		absChunkWords := make([]chunker.Word, 0, len(mappedLocal))
		for _, w := range mappedLocal {
			absStart := w.StartMS + p.StartOffsetMS
			if i > 0 && absStart < overlapAbsEnd {
				continue // duplicate from prior chunk's tail
			}
			abs := chunker.Word{
				Text:         w.Text,
				StartMS:      absStart,
				EndMS:        w.EndMS + p.StartOffsetMS,
				Confidence:   w.Confidence,
				SpeakerLabel: w.SpeakerLabel,
			}
			absChunkWords = append(absChunkWords, abs)
			if w.SpeakerLabel != "" {
				speakerSet[w.SpeakerLabel] = true
			}
			if w.Confidence > 0 {
				totalConfidence += w.Confidence
				confidenceWords++
			}
		}

		merged = append(merged, absChunkWords...)
		if languageCode == "" && p.LanguageCode != "" {
			languageCode = p.LanguageCode
		}

		// 4. Advance the rolling state — use THIS chunk's words
		//    (not the cumulative merged) so the next alignment
		//    only searches a bounded overlap window.
		//
		//    KEY: for chunk 0, priorAbsWords is the chunk-0 stream
		//    (no alignment was performed); for i > 0 it's the
		//    post-alignment current chunk. Either way the next
		//    iteration sees only one chunk's worth of words.
		priorAbsWords = absChunkWords
		// SeamOffsetMS is already absolute (audio_chunks stores
		// absolute offsets per migration 000023). For the Stage 1
		// virtual single-chunk case SeamOffsetMS is 0 — but the
		// i == 0 branch above never triggers alignment so the
		// value doesn't matter.
		priorSeamMS = p.SeamOffsetMS
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
