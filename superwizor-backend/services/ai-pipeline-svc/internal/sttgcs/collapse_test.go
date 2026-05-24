package sttgcs

import (
	"sort"
	"testing"

	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
)

// interleave returns a slice in the given order: each entry is a
// label and a count; the slice picks one word from each in
// rotation. Used to build temporally-realistic transcripts where
// adjacent words don't all share the same label.
func interleave(spec ...interface{}) []chunker.Word {
	// spec: alternating string,int pairs.
	var groups []struct {
		label string
		n     int
	}
	for i := 0; i < len(spec); i += 2 {
		groups = append(groups, struct {
			label string
			n     int
		}{spec[i].(string), spec[i+1].(int)})
	}
	total := 0
	for _, g := range groups {
		total += g.n
	}
	out := make([]chunker.Word, 0, total)
	cursor := make([]int, len(groups))
	for len(out) < total {
		for gi := range groups {
			if cursor[gi] >= groups[gi].n {
				continue
			}
			out = append(out, chunker.Word{
				Text:         "x",
				StartMS:      int64(len(out)) * 100,
				EndMS:        int64(len(out))*100 + 50,
				SpeakerLabel: groups[gi].label,
			})
			cursor[gi]++
		}
	}
	return out
}

func sortedLabels(words []chunker.Word) []string {
	set := map[string]bool{}
	for _, w := range words {
		if w.SpeakerLabel != "" {
			set[w.SpeakerLabel] = true
		}
	}
	out := make([]string, 0, len(set))
	for k := range set {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

// === Core behaviour ===

func TestCollapseGhostSpeakers_NoOpWhenTwoLabels(t *testing.T) {
	words := interleave("1", 200, "2", 200)
	stats := CollapseGhostSpeakers(words)
	if stats.InitialSpeakers != 2 || stats.FinalSpeakers != 2 {
		t.Errorf("expected 2/2 speakers; got %d/%d",
			stats.InitialSpeakers, stats.FinalSpeakers)
	}
	if len(stats.RemovedLabels) != 0 {
		t.Errorf("nothing should be removed; got %v", stats.RemovedLabels)
	}
}

func TestCollapseGhostSpeakers_NoOpOnEmpty(t *testing.T) {
	words := []chunker.Word{}
	stats := CollapseGhostSpeakers(words)
	if stats.InitialSpeakers != 0 || stats.FinalSpeakers != 0 {
		t.Errorf("expected 0/0 on empty; got %d/%d",
			stats.InitialSpeakers, stats.FinalSpeakers)
	}
}

func TestCollapseGhostSpeakers_ThreeRealSpeakersAllAboveThreshold(t *testing.T) {
	// 3 speakers in a couple's-therapy-style session, all
	// contributing > 50 words. Heuristic must leave them alone.
	words := interleave("1", 200, "2", 180, "3", 120)
	stats := CollapseGhostSpeakers(words)
	if stats.FinalSpeakers != 3 {
		t.Errorf("real 3-speaker session was collapsed; want 3 got %d",
			stats.FinalSpeakers)
	}
	if len(stats.RemovedLabels) != 0 {
		t.Errorf("legit speakers got dropped: %v", stats.RemovedLabels)
	}
}

// === Ghost detection ===

func TestCollapseGhostSpeakers_DropsTinyGhostBelowAbsolute(t *testing.T) {
	// Session shape mimicking the Janek/Gabriela case:
	//   - "1" therapist 300 words
	//   - "2" patient   280 words
	//   - "3" ghost      12 words  (cross-chunk alignment artifact)
	// Ghost should disappear; its 12 words reassign to neighbors.
	words := interleave("1", 300, "2", 280, "3", 12)
	stats := CollapseGhostSpeakers(words)
	if stats.FinalSpeakers != 2 {
		t.Fatalf("ghost not collapsed; want 2 final speakers got %d",
			stats.FinalSpeakers)
	}
	if len(stats.RemovedLabels) != 1 || stats.RemovedLabels[0] != "3" {
		t.Errorf("expected ['3'] removed; got %v", stats.RemovedLabels)
	}
	if stats.RemovedWordCounts["3"] != 12 {
		t.Errorf("expected 12 words removed for '3'; got %d",
			stats.RemovedWordCounts["3"])
	}
	// Every previously-ghost word must now have label "1" or "2".
	for i, w := range words {
		if w.SpeakerLabel != "1" && w.SpeakerLabel != "2" {
			t.Errorf("word %d still has unexpected label %q", i, w.SpeakerLabel)
		}
	}
}

func TestCollapseGhostSpeakers_DropsGhostBelowFraction(t *testing.T) {
	// Long session where 50 absolute is generous but the
	// fraction threshold catches it. 5000 total words, ghost
	// has 40 (< 1% of 5000 = 50). Should collapse.
	words := interleave("1", 2500, "2", 2460, "3", 40)
	stats := CollapseGhostSpeakers(words)
	if stats.FinalSpeakers != 2 {
		t.Errorf("ghost (40 of 5000, 0.8%%) not collapsed; got %d final",
			stats.FinalSpeakers)
	}
}

func TestCollapseGhostSpeakers_GhostExactlyAtAbsoluteEdge(t *testing.T) {
	// 50 words exactly — collapse fires (`<= threshold`).
	words := interleave("1", 300, "2", 280, "3", 50)
	stats := CollapseGhostSpeakers(words)
	if stats.FinalSpeakers != 2 {
		t.Errorf("ghost at exactly threshold not collapsed; got %d",
			stats.FinalSpeakers)
	}
}

func TestCollapseGhostSpeakers_GhostJustAboveEdge(t *testing.T) {
	// 51 words — should be PRESERVED. The threshold is < 50
	// absolute OR < 1% fraction. Total = 631; 1% = 6.31.
	// 51 > 50 → above absolute, and 51 > 6 → above fraction.
	words := interleave("1", 300, "2", 280, "3", 51)
	stats := CollapseGhostSpeakers(words)
	if stats.FinalSpeakers != 3 {
		t.Errorf("speaker just above threshold should survive; got %d",
			stats.FinalSpeakers)
	}
}

// === Regression: alignment-style 4-label cascade (Janek shape) ===

func TestCollapseGhostSpeakers_AlignmentCascade(t *testing.T) {
	// Worst-case alignment regression: chunk_0 labels {"1","2"},
	// chunk_1 cleanly maps {"1","2"}→{"1","2"}, chunk_2 has BOTH
	// labels offset to fresh {"3","4"} due to a sparse overlap.
	// Result: 4 labels in merged stream; "3" and "4" each carry
	// some words from chunk_2.
	//
	// Realistic distribution: bulk of session is 1+2, with 3+4
	// representing the chunk_2 misalignment.
	words := interleave("1", 250, "2", 230, "3", 18, "4", 22)
	stats := CollapseGhostSpeakers(words)
	if stats.FinalSpeakers != 2 {
		t.Fatalf("4-label alignment cascade not collapsed to 2; got %d",
			stats.FinalSpeakers)
	}
	// Both ghosts removed, in order from smallest to largest.
	if len(stats.RemovedLabels) != 2 {
		t.Errorf("expected 2 labels removed; got %v", stats.RemovedLabels)
	}
	// Remaining set must be {"1","2"}.
	remaining := sortedLabels(words)
	if len(remaining) != 2 || remaining[0] != "1" || remaining[1] != "2" {
		t.Errorf("final labels = %v; want [1 2]", remaining)
	}
}

// === Adjacency-based reassignment correctness ===

func TestNearestEligibleLabel_PrefersClosestBackward(t *testing.T) {
	// Words: 1 1 1 [G] 2 2 2 — i=3 is the ghost.
	// Eligible: {1, 2}. Distance backward = 1 (to "1"),
	// forward = 1 (to "2"). Ties prefer backward.
	words := []chunker.Word{
		{SpeakerLabel: "1"},
		{SpeakerLabel: "1"},
		{SpeakerLabel: "1"},
		{SpeakerLabel: "G"},
		{SpeakerLabel: "2"},
		{SpeakerLabel: "2"},
		{SpeakerLabel: "2"},
	}
	eligible := map[string]bool{"1": true, "2": true}
	got := nearestEligibleLabel(words, 3, eligible)
	if got != "1" {
		t.Errorf("ties should prefer backward; got %q want \"1\"", got)
	}
}

func TestNearestEligibleLabel_SkipsEmptyLabels(t *testing.T) {
	// 1 [empty] [G] 2 — empty label is not in eligible, so we
	// should walk past it to find "2" forward.
	words := []chunker.Word{
		{SpeakerLabel: "1"},
		{SpeakerLabel: ""},
		{SpeakerLabel: "G"},
		{SpeakerLabel: "2"},
	}
	eligible := map[string]bool{"1": true, "2": true}
	// Backward from i=2: i=1 is "" (not eligible), i=0 is "1" (eligible). Distance 2.
	// Forward from i=2: i=3 is "2". Distance 1.
	// Forward wins (distance 1 vs 2).
	got := nearestEligibleLabel(words, 2, eligible)
	if got != "2" {
		t.Errorf("expected forward winner '2'; got %q", got)
	}
}

// === Stats payload completeness ===

func TestCollapseGhostSpeakers_StatsRecordRemovedCount(t *testing.T) {
	words := interleave("1", 200, "2", 180, "3", 7)
	stats := CollapseGhostSpeakers(words)
	if stats.RemovedWordCounts["3"] != 7 {
		t.Errorf("expected RemovedWordCounts['3'] == 7; got %v",
			stats.RemovedWordCounts)
	}
}
