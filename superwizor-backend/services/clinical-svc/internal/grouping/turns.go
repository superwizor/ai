// Package grouping collapses the flat per-chunk transcript segments
// produced by STT + diarization into speaker turns — one block per
// uninterrupted stretch of a single speaker. The read-only transcript
// view in Flutter (and any future export endpoint) binds to the turn
// shape; the raw segments are still served alongside for the speaker-
// label edit UI which needs per-chunk granularity.
//
// Why this lives backend-side rather than in each client:
//   - Single source of truth for join/punctuation/confidence policy
//   - Consistent rendering across web/iOS/Android
//   - If a future server-side export (PDF, plain-text share link) ever
//     ships, it reuses the same function without duplicating the rules
//
// Why derived on read rather than persisted:
//   - llm-worker analyses the canonical blob and needs per-chunk
//     granularity. A "grouped" persisted copy would either double the
//     storage or break that analysis path.
//   - Recomputing on each GetSessionDetails is O(n) and negligible
//     (typical session: ~200-2000 segments).
//   - Speaker-label edits would otherwise need to re-group too,
//     coupling the edit handler to the display projection.
package grouping

import (
	"sort"
	"strings"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
)

// GroupSegmentsIntoTurns collapses consecutive same-speaker segments
// into SpeakerTurn entries. Input is taken by value so the caller
// keeps ownership of the underlying slice; output is independent.
//
// Splitting rules — a new turn starts when:
//   - speaker_tag differs from the previous segment, OR
//   - speaker_label differs (defensive: protects against a half-applied
//     UpdateSpeakerLabels rebuild that leaves two labels on one tag)
//
// Text join: single space between segments, trailing whitespace on
// the previous chunk is trimmed first so we don't produce double spaces.
// Empty-text segments (post-decrypt failure, etc.) are skipped in the
// join but still kept in segment_count and time-range accounting so
// the turn's timestamps remain accurate.
//
// Confidence: word-count-weighted mean across segments. If every
// underlying segment has zero word_count (shouldn't happen — STT
// always emits one — but defensive), falls back to a plain mean over
// segments that had a confidence value.
//
// Ordering: input is sorted by start_offset_ms before grouping. The
// sort is stable so segments with identical start ms (rare STT chunk-
// boundary case) keep their relative order. Sorting defensively even
// though sqlc's ListTranscriptSegments already ORDER BYs — saves us
// if a future caller passes segments from a different source.
func GroupSegmentsIntoTurns(segments []*clinicalv1.TranscriptSegment) []*clinicalv1.SpeakerTurn {
	if len(segments) == 0 {
		return nil
	}

	// Copy so we don't mutate the caller's slice ordering.
	sorted := make([]*clinicalv1.TranscriptSegment, len(segments))
	copy(sorted, segments)
	sort.SliceStable(sorted, func(i, j int) bool {
		return sorted[i].StartOffsetMs < sorted[j].StartOffsetMs
	})

	var turns []*clinicalv1.SpeakerTurn
	var current *turnBuilder

	for _, seg := range sorted {
		if current == nil || !current.matches(seg) {
			// Boundary: finalize the previous turn (if any) and open a new one.
			if current != nil {
				turns = append(turns, current.finalize())
			}
			current = newTurnBuilder(seg)
			continue
		}
		current.append(seg)
	}
	if current != nil {
		turns = append(turns, current.finalize())
	}
	return turns
}

// turnBuilder accumulates segments into one SpeakerTurn. Pulled into
// its own type so the boundary/append/finalize logic doesn't litter
// the top-level loop with running totals.
type turnBuilder struct {
	speakerTag   int32
	speakerLabel string
	startMs      int32
	endMs        int32
	textParts    []string
	segmentCount int32

	// Confidence accounting: weighted by word count when available,
	// falls back to plain mean if zero total weight.
	weightedConfSum float32
	weightTotal     int32
	plainConfSum    float32
	plainConfCount  int32
}

func newTurnBuilder(seg *clinicalv1.TranscriptSegment) *turnBuilder {
	b := &turnBuilder{
		speakerTag:   seg.SpeakerTag,
		speakerLabel: seg.SpeakerLabel,
		startMs:      seg.StartOffsetMs,
		endMs:        seg.EndOffsetMs,
	}
	// append handles segmentCount + endMs + text + confidence so the
	// first segment goes through the same path as continuation ones.
	b.append(seg)
	return b
}

func (b *turnBuilder) matches(seg *clinicalv1.TranscriptSegment) bool {
	return seg.SpeakerTag == b.speakerTag && seg.SpeakerLabel == b.speakerLabel
}

func (b *turnBuilder) append(seg *clinicalv1.TranscriptSegment) {
	b.segmentCount++
	if seg.EndOffsetMs > b.endMs {
		b.endMs = seg.EndOffsetMs
	}
	if text := strings.TrimSpace(seg.Text); text != "" {
		b.textParts = append(b.textParts, text)
	}
	// Confidence math. word_count not on proto today (storage-only),
	// so we treat every segment as weight=1. If we ever surface
	// word_count in the proto, switch to per-segment weighting here.
	if seg.Confidence > 0 {
		b.plainConfSum += seg.Confidence
		b.plainConfCount++
		// Same value into the weighted accumulator since weight=1 always
		// today — kept separate so the upgrade path is a one-line change.
		b.weightedConfSum += seg.Confidence
		b.weightTotal++
	}
}

func (b *turnBuilder) finalize() *clinicalv1.SpeakerTurn {
	var conf float32
	switch {
	case b.weightTotal > 0:
		conf = b.weightedConfSum / float32(b.weightTotal)
	case b.plainConfCount > 0:
		conf = b.plainConfSum / float32(b.plainConfCount)
	}
	return &clinicalv1.SpeakerTurn{
		SpeakerTag:    b.speakerTag,
		SpeakerLabel:  b.speakerLabel,
		StartOffsetMs: b.startMs,
		EndOffsetMs:   b.endMs,
		Text:          strings.Join(b.textParts, " "),
		SegmentCount:  b.segmentCount,
		ConfidenceAvg: conf,
	}
}
