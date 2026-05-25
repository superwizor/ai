package sttgcs

import (
	"testing"

	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
)

// TestAlignAndMapSpeakers_HappyPath: two chunks with a clean overlap.
// Prior chunk labels speakers as "1" (therapist) and "2" (patient).
// Current chunk labels the same people as "A" and "B" (independent
// label space). Algorithm should translate A→1 and B→2.
func TestAlignAndMapSpeakers_HappyPath(t *testing.T) {
	// Overlap is 10s, 16 words. Even split: 8 "1"/A pairs, 8 "2"/B
	// pairs. Comfortably above alignMinMatchedPairs=10.
	prior := []chunker.Word{}
	curr := []chunker.Word{}
	for i := 0; i < 8; i++ {
		// Therapist words at 1000ms intervals, labeled "1" / "A".
		startMS := int64(1_140_000 + i*1000) // absolute, in overlap
		prior = append(prior, chunker.Word{
			Text: "yes", StartMS: startMS, EndMS: startMS + 300,
			Confidence: 0.9, SpeakerLabel: "1",
		})
		// Current chunk: same word at the same local offset.
		// currStartOffsetMS = 1_140_000, so local = absolute - 1_140_000
		curr = append(curr, chunker.Word{
			Text: "yes", StartMS: startMS - 1_140_000, EndMS: startMS - 1_140_000 + 300,
			Confidence: 0.9, SpeakerLabel: "A",
		})
	}
	for i := 0; i < 8; i++ {
		startMS := int64(1_140_500 + i*1000) // interleaved with therapist
		prior = append(prior, chunker.Word{
			Text: "ok", StartMS: startMS, EndMS: startMS + 250,
			Confidence: 0.88, SpeakerLabel: "2",
		})
		curr = append(curr, chunker.Word{
			Text: "ok", StartMS: startMS - 1_140_000, EndMS: startMS - 1_140_000 + 250,
			Confidence: 0.88, SpeakerLabel: "B",
		})
	}

	mapped, newMax, fellBack := AlignAndMapSpeakers(
		prior, curr,
		1_140_000, // currStartOffsetMS
		1_152_000, // priorSeamMS — covers ALL the overlap words
		2,         // prevMaxLabel — prior chunk had labels "1" and "2"
	)
	if fellBack {
		t.Fatalf("expected confident map; got fellBack=true")
	}
	if newMax != 2 {
		t.Errorf("newMaxLabel = %d, want 2 (no new speakers introduced)", newMax)
	}

	// Every A should map to 1, every B to 2.
	for i, w := range mapped {
		want := "1"
		if curr[i].SpeakerLabel == "B" {
			want = "2"
		}
		if w.SpeakerLabel != want {
			t.Errorf("mapped[%d] = %q, want %q (curr label=%q)", i, w.SpeakerLabel, want, curr[i].SpeakerLabel)
		}
	}
}

// TestAlignAndMapSpeakers_SparseOverlap: few matched pairs → fall
// back to label-by-ordinal offset (prevMaxLabel + k).
func TestAlignAndMapSpeakers_SparseOverlap(t *testing.T) {
	// Only 3 matched pairs — below alignMinMatchedPairs=10.
	prior := []chunker.Word{
		{Text: "hello", StartMS: 1_140_000, EndMS: 1_140_500, SpeakerLabel: "1"},
		{Text: "world", StartMS: 1_141_000, EndMS: 1_141_500, SpeakerLabel: "1"},
		{Text: "yes",   StartMS: 1_142_000, EndMS: 1_142_500, SpeakerLabel: "2"},
	}
	curr := []chunker.Word{
		{Text: "hello", StartMS: 0, EndMS: 500, SpeakerLabel: "X"},
		{Text: "world", StartMS: 1000, EndMS: 1500, SpeakerLabel: "X"},
		{Text: "yes",   StartMS: 2000, EndMS: 2500, SpeakerLabel: "Y"},
		// Words after the overlap — kept with offset labels.
		{Text: "more",  StartMS: 15_000, EndMS: 15_500, SpeakerLabel: "X"},
		{Text: "stuff", StartMS: 16_000, EndMS: 16_500, SpeakerLabel: "Y"},
	}

	mapped, newMax, fellBack := AlignAndMapSpeakers(
		prior, curr,
		1_140_000, // currStartOffsetMS
		1_152_000, // priorSeamMS
		2,         // prevMaxLabel
	)
	if !fellBack {
		t.Fatalf("expected fellBack=true on sparse overlap; got false")
	}
	if newMax != 4 {
		// X → 3, Y → 4
		t.Errorf("newMaxLabel = %d, want 4 (X→3, Y→4)", newMax)
	}
	// All X's should now be "3", all Y's "4" (offset by prevMaxLabel=2).
	for i, w := range mapped {
		want := "3"
		if curr[i].SpeakerLabel == "Y" {
			want = "4"
		}
		if w.SpeakerLabel != want {
			t.Errorf("mapped[%d] = %q, want %q", i, w.SpeakerLabel, want)
		}
	}
}

// TestAlignAndMapSpeakers_NoDiarization: neither side has speaker
// labels (LLM-clustering path). Algorithm returns input unchanged
// with fellBack=false.
func TestAlignAndMapSpeakers_NoDiarization(t *testing.T) {
	prior := []chunker.Word{
		{Text: "hi", StartMS: 1_140_000, EndMS: 1_141_000},
	}
	curr := []chunker.Word{
		{Text: "hi", StartMS: 0, EndMS: 1000},
	}
	mapped, newMax, fellBack := AlignAndMapSpeakers(prior, curr, 1_140_000, 1_150_000, 0)
	if fellBack {
		t.Errorf("no-diarization path should not flag fellBack")
	}
	if newMax != 0 {
		t.Errorf("newMax = %d, want 0", newMax)
	}
	if mapped[0].SpeakerLabel != "" {
		t.Errorf("expected empty speaker label preserved; got %q", mapped[0].SpeakerLabel)
	}
}

// TestLevenshtein covers the edit-distance helper used by the
// text-similarity tie-breaker.
func TestLevenshtein(t *testing.T) {
	cases := []struct {
		a, b string
		want int
	}{
		{"", "", 0},
		{"hello", "hello", 0},
		{"hello", "helo", 1},
		{"kitten", "sitting", 3},
		{"abc", "", 3},
	}
	for _, tc := range cases {
		if got := levenshtein(tc.a, tc.b); got != tc.want {
			t.Errorf("levenshtein(%q, %q) = %d, want %d", tc.a, tc.b, got, tc.want)
		}
	}
}

// TestTextSimilarity covers the normalized 0.0–1.0 score the
// alignment uses as a tie-breaker.
func TestTextSimilarity(t *testing.T) {
	cases := []struct {
		a, b string
		want float64
	}{
		{"hello", "hello", 1.0},          // exact
		{"Hello", "hello.", 1.0},         // normalization (case, punctuation)
		{"yes", "no", 0.0},               // completely different short strings
	}
	for _, tc := range cases {
		got := textSimilarity(tc.a, tc.b)
		if !floatNear(got, tc.want, 0.01) {
			t.Errorf("textSimilarity(%q, %q) = %v, want %v", tc.a, tc.b, got, tc.want)
		}
	}
}

func TestParseLabelNum(t *testing.T) {
	cases := map[string]int{
		"":    0,
		"1":   1,
		"42":  42,
		"abc": 0,
		"1a":  0,
	}
	for in, want := range cases {
		if got := parseLabelNum(in); got != want {
			t.Errorf("parseLabelNum(%q) = %d, want %d", in, got, want)
		}
	}
}

func floatNear(a, b, eps float64) bool {
	d := a - b
	if d < 0 {
		d = -d
	}
	return d <= eps
}

// TestAlignAndMapSpeakers_MissingPriorReassignment is the Path B
// regression test (2026-05-25). The scenario mirrors the Janek
// Johny session that repeatedly produced a substantive ghost:
//
//   - chunk_0 had speakers {"1": therapist (loud), "2": patient (briefly)}
//   - The overlap window between chunk_0 and chunk_1 happened to
//     contain ONLY the therapist's speech. Translation map gets
//     populated for the therapist (chunk_1's "1" → "1") but
//     chunk_1's "2" has zero co-occurrences against chunk_0's "2".
//   - Pre-fix: chunk_1's "2" gets offset to "3" (one above
//     prevMaxLabel=2). That "3" is the SAME PERSON as the
//     prior "2" — a substantive ghost survives downstream.
//   - Post-fix: smart fallback assigns chunk_1's "2" to the
//     missing prior "2" (which DID exist in chunk_0 but didn't
//     show up in translation). Result: no ghost.
func TestAlignAndMapSpeakers_MissingPriorReassignment(t *testing.T) {
	// Prior chunk: 11 therapist words, 1 patient word — patient
	// was quiet during the overlap window. (1 because we still
	// need it to appear as a chunk_0 label so the prior label set
	// includes "2".)
	prior := []chunker.Word{}
	for i := 0; i < 11; i++ {
		prior = append(prior, chunker.Word{
			Text: "hello", StartMS: int64(i)*100, EndMS: int64(i)*100 + 50,
			SpeakerLabel: "1",
		})
	}
	prior = append(prior, chunker.Word{
		Text: "yes", StartMS: 1500, EndMS: 1550, SpeakerLabel: "2",
	})

	// Current chunk: therapist's same "hello" words at matching
	// times (so alignment maps chunk_1's "1" → "1"), plus the
	// patient saying a lot of stuff that has ZERO co-occurrence
	// with the prior chunk's "2" (because Chirp put the patient
	// in a different position in chunk_1).
	curr := []chunker.Word{}
	for i := 0; i < 11; i++ {
		curr = append(curr, chunker.Word{
			Text: "hello", StartMS: int64(i)*100, EndMS: int64(i)*100 + 50,
			SpeakerLabel: "1",
		})
	}
	// Patient at LOCAL times far from any prior "2" word — no
	// match possible in time-anchor scan. Note: in real Stage 2,
	// these are local times; the test reuses local==abs to keep
	// the fixture small.
	patientStarts := []int64{2000, 2500, 3000, 3500, 4000, 4500, 5000, 5500, 6000, 6500}
	for _, ms := range patientStarts {
		curr = append(curr, chunker.Word{
			Text: "patient", StartMS: ms, EndMS: ms + 50,
			SpeakerLabel: "2",
		})
	}

	// currStartOffsetMS=0 so the time-anchor check sees curr
	// words in the prior's space. priorSeamMS large enough that
	// the 0..1100ms region is "in the overlap window" for the
	// timeAnchorPairs scan.
	mapped, newMax, fellBack := AlignAndMapSpeakers(
		prior, curr,
		/*currStartOffsetMS=*/ 0,
		/*priorSeamMS=*/ 10_000,
		/*prevMaxLabel=*/ 2,
	)
	if fellBack {
		t.Errorf("expected normal alignment path (10+ matched pairs); fell back")
	}

	// Therapist words (chunk_1 "1") should map to "1".
	for i := 0; i < 11; i++ {
		if mapped[i].SpeakerLabel != "1" {
			t.Errorf("therapist word %d: got label %q, want \"1\"",
				i, mapped[i].SpeakerLabel)
		}
	}

	// Patient words (chunk_1 "2") MUST map back to "2" (the
	// missing prior), NOT to "3" (fresh offset). This is the
	// regression assertion.
	for i := 11; i < len(mapped); i++ {
		if mapped[i].SpeakerLabel != "2" {
			t.Errorf("patient word %d: got label %q, want \"2\" "+
				"(missing-prior reassignment regression — pre-fix "+
				"this would have been \"3\")",
				i, mapped[i].SpeakerLabel)
		}
	}

	// newMax should be at most prevMaxLabel (=2) since we didn't
	// mint any new offsets.
	if newMax > 2 {
		t.Errorf("newMax=%d > prevMaxLabel=2 — should not have minted "+
			"new offset labels", newMax)
	}
}

// TestAlignAndMapSpeakers_GenuineNewSpeakerStillGetsOffset covers
// the converse: when chunk_i has an unmapped label AND no prior
// label was unused in the translation map, the speaker is genuinely
// new and must still get a fresh offset (couple's-therapy /
// late-arriving participant case).
func TestAlignAndMapSpeakers_GenuineNewSpeakerStillGetsOffset(t *testing.T) {
	// Prior: only ONE speaker labeled "1".
	prior := []chunker.Word{}
	for i := 0; i < 12; i++ {
		prior = append(prior, chunker.Word{
			Text: "hello", StartMS: int64(i)*100, EndMS: int64(i)*100 + 50,
			SpeakerLabel: "1",
		})
	}

	// Current: same speaker maps to "1", PLUS a new "2" that
	// represents a never-before-seen speaker (no missing-prior to
	// claim it).
	curr := []chunker.Word{}
	for i := 0; i < 12; i++ {
		curr = append(curr, chunker.Word{
			Text: "hello", StartMS: int64(i)*100, EndMS: int64(i)*100 + 50,
			SpeakerLabel: "1",
		})
	}
	// New-speaker words at non-overlapping positions.
	for _, ms := range []int64{3000, 3500, 4000} {
		curr = append(curr, chunker.Word{
			Text: "newspeaker", StartMS: ms, EndMS: ms + 50,
			SpeakerLabel: "2",
		})
	}

	mapped, newMax, _ := AlignAndMapSpeakers(
		prior, curr, 0, 10_000, 1, // prevMaxLabel=1 (prior had only "1")
	)

	// First 12 stay "1".
	for i := 0; i < 12; i++ {
		if mapped[i].SpeakerLabel != "1" {
			t.Errorf("therapist word %d: got %q, want \"1\"",
				i, mapped[i].SpeakerLabel)
		}
	}
	// New-speaker words must get a FRESH offset — there's no
	// missing prior to claim. Expected: "2" (prevMaxLabel + 1).
	for i := 12; i < len(mapped); i++ {
		if mapped[i].SpeakerLabel != "2" {
			t.Errorf("new-speaker word %d: got %q, want \"2\" "+
				"(prevMaxLabel=1 + 1) — genuine new speakers must "+
				"still mint a fresh label",
				i, mapped[i].SpeakerLabel)
		}
	}
	if newMax != 2 {
		t.Errorf("newMax = %d, want 2 (prevMaxLabel + 1 for the new speaker)",
			newMax)
	}
}

// TestComputeMissingPriors verifies the helper directly.
func TestComputeMissingPriors(t *testing.T) {
	prior := []chunker.Word{
		{SpeakerLabel: "1"}, {SpeakerLabel: "2"}, {SpeakerLabel: "3"},
		{SpeakerLabel: "1"}, {SpeakerLabel: ""},
	}

	// translation populates "1" and "3"; "2" is missing.
	translation := map[string]string{"A": "1", "B": "3"}
	got := computeMissingPriors(prior, translation)
	if len(got) != 1 || got[0] != "2" {
		t.Errorf("missing priors = %v, want [\"2\"]", got)
	}

	// All priors used → empty result.
	translation2 := map[string]string{"A": "1", "B": "2", "C": "3"}
	got2 := computeMissingPriors(prior, translation2)
	if len(got2) != 0 {
		t.Errorf("missing priors when all used = %v, want []", got2)
	}

	// No translation populated → all priors are "missing".
	got3 := computeMissingPriors(prior, map[string]string{})
	if len(got3) != 3 || got3[0] != "1" || got3[1] != "2" || got3[2] != "3" {
		t.Errorf("missing priors with empty translation = %v, want [1 2 3] "+
			"(numeric sort)", got3)
	}
}
