package grouping

import (
	"math"
	"testing"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
)

// seg is a brevity helper for building TranscriptSegment fixtures in
// tests without the proto verbosity drowning the actual case logic.
func seg(tag int32, label string, startMs, endMs int32, text string, conf float32) *clinicalv1.TranscriptSegment {
	return &clinicalv1.TranscriptSegment{
		SpeakerTag:    tag,
		SpeakerLabel:  label,
		StartOffsetMs: startMs,
		EndOffsetMs:   endMs,
		Text:          text,
		Confidence:    conf,
	}
}

// floatNear compares two float32s within an epsilon. Confidence math
// goes through float32 sum/division so exact equality is brittle.
func floatNear(a, b float32) bool {
	return math.Abs(float64(a-b)) < 1e-4
}

func TestGroupSegmentsIntoTurns_Empty(t *testing.T) {
	if got := GroupSegmentsIntoTurns(nil); len(got) != 0 {
		t.Errorf("nil input → expected nil/empty, got %d turns", len(got))
	}
	if got := GroupSegmentsIntoTurns([]*clinicalv1.TranscriptSegment{}); len(got) != 0 {
		t.Errorf("empty input → expected nil/empty, got %d turns", len(got))
	}
}

func TestGroupSegmentsIntoTurns_SingleSegment(t *testing.T) {
	in := []*clinicalv1.TranscriptSegment{seg(1, "Osoba 1", 0, 1000, "Cześć", 0.95)}
	out := GroupSegmentsIntoTurns(in)
	if len(out) != 1 {
		t.Fatalf("want 1 turn, got %d", len(out))
	}
	tt := out[0]
	if tt.SpeakerTag != 1 || tt.SpeakerLabel != "Osoba 1" {
		t.Errorf("speaker mismatch: tag=%d label=%q", tt.SpeakerTag, tt.SpeakerLabel)
	}
	if tt.StartOffsetMs != 0 || tt.EndOffsetMs != 1000 {
		t.Errorf("time range wrong: [%d, %d]", tt.StartOffsetMs, tt.EndOffsetMs)
	}
	if tt.Text != "Cześć" {
		t.Errorf("text mismatch: %q", tt.Text)
	}
	if tt.SegmentCount != 1 {
		t.Errorf("segment_count: want 1, got %d", tt.SegmentCount)
	}
	if !floatNear(tt.ConfidenceAvg, 0.95) {
		t.Errorf("confidence: want 0.95, got %f", tt.ConfidenceAvg)
	}
}

// Two segments from the same speaker → one turn, end_ms from the
// second, joined text with a single space, segment_count == 2.
func TestGroupSegmentsIntoTurns_SameSpeakerCollapsed(t *testing.T) {
	in := []*clinicalv1.TranscriptSegment{
		seg(1, "Osoba 1", 0, 1000, "Cześć,", 0.9),
		seg(1, "Osoba 1", 1100, 2500, "jak się masz?", 0.8),
	}
	out := GroupSegmentsIntoTurns(in)
	if len(out) != 1 {
		t.Fatalf("same speaker must collapse to 1 turn, got %d", len(out))
	}
	if out[0].Text != "Cześć, jak się masz?" {
		t.Errorf("joined text wrong: %q", out[0].Text)
	}
	if out[0].EndOffsetMs != 2500 {
		t.Errorf("end_ms: want 2500 (latest segment), got %d", out[0].EndOffsetMs)
	}
	if out[0].SegmentCount != 2 {
		t.Errorf("segment_count: want 2, got %d", out[0].SegmentCount)
	}
}

// Two different speakers → two turns. Verifies the boundary detection
// is by speaker_tag, not by time gap.
func TestGroupSegmentsIntoTurns_TwoSpeakersSplit(t *testing.T) {
	in := []*clinicalv1.TranscriptSegment{
		seg(1, "Osoba 1", 0, 1000, "Witam", 0.9),
		seg(2, "Osoba 2", 1100, 2000, "Dzień dobry", 0.9),
	}
	out := GroupSegmentsIntoTurns(in)
	if len(out) != 2 {
		t.Fatalf("want 2 turns, got %d", len(out))
	}
	if out[0].SpeakerTag != 1 || out[1].SpeakerTag != 2 {
		t.Errorf("turn order wrong: %d, %d", out[0].SpeakerTag, out[1].SpeakerTag)
	}
}

// A → B → A → three turns, NOT two. The user spec explicitly wants
// every speaker switch surfaced; "same person resumed" must not merge
// across an interjection.
func TestGroupSegmentsIntoTurns_SameSpeakerResumedAfterInterjection(t *testing.T) {
	in := []*clinicalv1.TranscriptSegment{
		seg(1, "Klient", 0, 1000, "Powiedziałem mu", 0.9),
		seg(2, "Terapeuta", 1100, 1300, "Aha", 0.9),
		seg(1, "Klient", 1400, 2500, "że nie zgadzam się", 0.9),
	}
	out := GroupSegmentsIntoTurns(in)
	if len(out) != 3 {
		t.Fatalf("want 3 turns (A → B → A), got %d", len(out))
	}
	if out[0].SpeakerTag != 1 || out[1].SpeakerTag != 2 || out[2].SpeakerTag != 1 {
		t.Errorf("speaker sequence: want [1,2,1], got [%d,%d,%d]",
			out[0].SpeakerTag, out[1].SpeakerTag, out[2].SpeakerTag)
	}
	if out[2].Text != "że nie zgadzam się" {
		t.Errorf("resumed turn must NOT include earlier text; got %q", out[2].Text)
	}
}

// speaker_tag == 0 → STT-only placeholders before LLM diarization
// finished. Should still group consecutively. Label is empty;
// renderer decides how to display unknown.
func TestGroupSegmentsIntoTurns_UnlabeledSegmentsGroupOnTag(t *testing.T) {
	in := []*clinicalv1.TranscriptSegment{
		seg(0, "", 0, 1000, "fragment one", 0.7),
		seg(0, "", 1100, 2000, "fragment two", 0.7),
	}
	out := GroupSegmentsIntoTurns(in)
	if len(out) != 1 {
		t.Fatalf("two tag=0 segments should collapse, got %d turns", len(out))
	}
	if out[0].SpeakerLabel != "" {
		t.Errorf("unlabeled turn must keep empty label, got %q", out[0].SpeakerLabel)
	}
}

// Defensive split: same tag, different label. Should NOT happen in
// production (UpdateSpeakerLabels keeps labels consistent per tag) but
// we'd rather show two turns than silently collapse a half-applied
// rebuild that would otherwise mis-attribute speech.
func TestGroupSegmentsIntoTurns_LabelMismatchSameTagForcesSplit(t *testing.T) {
	in := []*clinicalv1.TranscriptSegment{
		seg(1, "Old Name", 0, 1000, "first", 0.9),
		seg(1, "New Name", 1100, 2000, "second", 0.9),
	}
	out := GroupSegmentsIntoTurns(in)
	if len(out) != 2 {
		t.Fatalf("label change must force a split even on same tag, got %d", len(out))
	}
}

// Confidence averaging: equal-weighted (today every segment has the
// same effective weight of 1; the test pins the math so a future
// change to per-word weighting is caught).
func TestGroupSegmentsIntoTurns_ConfidenceAveraged(t *testing.T) {
	in := []*clinicalv1.TranscriptSegment{
		seg(1, "X", 0, 1000, "a", 0.9),
		seg(1, "X", 1100, 2000, "b", 0.5),
	}
	out := GroupSegmentsIntoTurns(in)
	if len(out) != 1 {
		t.Fatalf("want 1 turn, got %d", len(out))
	}
	if !floatNear(out[0].ConfidenceAvg, 0.7) {
		t.Errorf("expected (0.9+0.5)/2 = 0.7, got %f", out[0].ConfidenceAvg)
	}
}

// Segment with zero/missing confidence shouldn't poison the average.
// Today the producer always emits a confidence, but defensive coverage.
func TestGroupSegmentsIntoTurns_ZeroConfidenceSegmentSkipped(t *testing.T) {
	in := []*clinicalv1.TranscriptSegment{
		seg(1, "X", 0, 1000, "a", 0.9),
		seg(1, "X", 1100, 2000, "b", 0.0), // missing — should be ignored in avg
	}
	out := GroupSegmentsIntoTurns(in)
	if !floatNear(out[0].ConfidenceAvg, 0.9) {
		t.Errorf("zero-confidence segment must be ignored in average, got %f", out[0].ConfidenceAvg)
	}
}

// Empty-text segments (post-decrypt failure, etc.) should be skipped
// in the join but still bump segment_count and the end timestamp so
// the turn's audio span stays accurate.
func TestGroupSegmentsIntoTurns_EmptyTextSegmentSkippedInJoinButCounted(t *testing.T) {
	in := []*clinicalv1.TranscriptSegment{
		seg(1, "X", 0, 1000, "hello", 0.9),
		seg(1, "X", 1100, 2000, "", 0.9),
		seg(1, "X", 2100, 3000, "world", 0.9),
	}
	out := GroupSegmentsIntoTurns(in)
	if len(out) != 1 {
		t.Fatalf("want 1 turn, got %d", len(out))
	}
	if out[0].Text != "hello world" {
		t.Errorf("empty-text segment must be skipped in join, got %q", out[0].Text)
	}
	if out[0].SegmentCount != 3 {
		t.Errorf("segment_count must still include empty segments, got %d", out[0].SegmentCount)
	}
	if out[0].EndOffsetMs != 3000 {
		t.Errorf("end_ms must reach last segment, got %d", out[0].EndOffsetMs)
	}
}

// Whitespace-only / trailing-space chunks shouldn't produce double
// spaces in the joined text. STT sometimes ships punctuation followed
// by a trailing space.
func TestGroupSegmentsIntoTurns_TrailingWhitespaceCleanedOnJoin(t *testing.T) {
	in := []*clinicalv1.TranscriptSegment{
		seg(1, "X", 0, 1000, "first.  ", 0.9),
		seg(1, "X", 1100, 2000, "  second.", 0.9),
	}
	out := GroupSegmentsIntoTurns(in)
	if out[0].Text != "first. second." {
		t.Errorf("expected single space at join, got %q", out[0].Text)
	}
}

// Out-of-order input must still produce monotonic output. The handler
// pulls from sqlc with an ORDER BY but a future caller might not, and
// the bug would only show up when two adjacent turns time-overlap.
func TestGroupSegmentsIntoTurns_OutOfOrderInputSorted(t *testing.T) {
	in := []*clinicalv1.TranscriptSegment{
		seg(2, "B", 2000, 3000, "second turn", 0.9),
		seg(1, "A", 0, 1000, "first turn", 0.9),
	}
	out := GroupSegmentsIntoTurns(in)
	if len(out) != 2 {
		t.Fatalf("want 2 turns, got %d", len(out))
	}
	if out[0].SpeakerTag != 1 || out[1].SpeakerTag != 2 {
		t.Errorf("turns must be in time order regardless of input order; got [%d, %d]",
			out[0].SpeakerTag, out[1].SpeakerTag)
	}
}
