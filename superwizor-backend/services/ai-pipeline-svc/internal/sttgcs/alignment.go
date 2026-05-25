package sttgcs

// alignment.go — Cross-chunk speaker-label alignment for the
// server-side chunking flow (Stage 2 of feat/stt-long_audio_support).
//
// When ingestion-svc splits a long audio into N chunks, Chirp 3's
// native diarization labels are independent PER CHUNK — Speaker "1"
// in chunk_i and Speaker "1" in chunk_{i+1} might be different
// people. The merger must reconcile these label spaces before
// concatenating words.
//
// The algorithm uses TIME ANCHORS as the primary matching signal:
// Chirp's word-level timestamps are stable across calls to within
// ~100-250ms. Text edit distance is the tie-breaker when multiple
// candidates fall in the same time window. This makes the alignment
// SCRIPT-AGNOSTIC — works for Latin/Cyrillic AND for CJK where
// word-only edit distance would break.
//
// See docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md "Cross-chunk
// diarization alignment" for the full decision table.

import (
	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
)

// Algorithm parameters. Centralized so future tuning is one PR;
// eval harness (cmd/stt-align-eval/) iterates over these constants.
const (
	// Maximum time gap (ms) between two words across chunk boundaries
	// to consider them the same utterance for co-occurrence purposes.
	// 200ms covers Chirp's normal jitter; tighter values miss legitimate
	// pairs, looser ones false-positive on back-to-back utterances.
	alignTimeMatchToleranceMS = 200

	// When multiple prior-chunk words fall inside the time tolerance
	// of one current-chunk word, pick the one with highest text
	// similarity. Below this ratio (Levenshtein over max-length),
	// even the best text match is rejected and we skip the word.
	alignTextSimilarityRatio = 0.7

	// Minimum matched-pair count to trust the translation map.
	// Below this we fall back to label-by-ordinal offset.
	alignMinMatchedPairs = 10

	// For each current-chunk label, the fraction of co-occurrences
	// that must agree on a single prior-chunk label to accept the
	// translation. Below this the label is "ambiguous" and gets
	// offset into a non-colliding range.
	//
	// Lowered 0.60 → 0.45 on 2026-05-25 after repeat ghosts on the
	// Janek Johny 53-min session (sids 18d1b6d6, 266163a5, ab6a4f13
	// all showed initial_speakers=4 → final_speakers=3 with one
	// surviving substantive ghost). 0.45 is still a clear plurality
	// signal but tolerates the realistic case where ~half the
	// overlap window has the dominant speaker and the secondary
	// speaker barely co-occurs — without compromising couple's-
	// therapy sessions which would have rich pair distributions on
	// either side of 0.5.
	alignMajorityFraction = 0.45
)

// AlignAndMapSpeakers translates the speaker labels in currLocalWords
// from the current chunk's labeling space into the prior chunk's
// labeling space, using time-anchored matching across the overlap
// window. Then returns the rewritten currLocalWords (still in LOCAL
// time — the merger handles the absolute-time conversion).
//
// Parameters:
//
//   priorAbsWords      — prior chunk's words IN ABSOLUTE TIME,
//                        restricted to the overlap window.
//   currLocalWords     — current chunk's words IN LOCAL TIME
//                        (chunk-relative offsets).
//   currStartOffsetMS  — chunk_i.start_offset_ms (used to convert
//                        currLocalWords to absolute time for matching).
//   priorSeamMS        — chunk_{i-1}.seam_offset_ms (defines the end
//                        of the overlap window).
//   prevMaxLabel       — highest numeric speaker label seen so far in
//                        previously-merged chunks. Used for collision
//                        avoidance in fallback / new-speaker cases.
//
// Returns:
//
//   mappedWords  — currLocalWords with SpeakerLabel rewritten.
//                  Empty SpeakerLabel ("") for words the algorithm
//                  couldn't confidently map (LLM re-clusters them
//                  downstream).
//   newMaxLabel  — highest numeric label after mapping (the next
//                  chunk's prevMaxLabel input).
//   fellBack     — true when the algorithm fell back to label-by-
//                  ordinal offset because the overlap was too sparse
//                  or alignment was inconclusive. Mergers emit a
//                  metric per fallback so production drift is visible.
func AlignAndMapSpeakers(
	priorAbsWords, currLocalWords []chunker.Word,
	currStartOffsetMS, priorSeamMS int64,
	prevMaxLabel int,
) (mappedWords []chunker.Word, newMaxLabel int, fellBack bool) {
	if len(currLocalWords) == 0 {
		return nil, prevMaxLabel, false
	}

	// Defensive: native diarization is OFF if no prior word carries
	// a label. The merger should already have skipped the alignment
	// branch in that case, but handle it here too — emit
	// currLocalWords with empty labels (LLM clustering downstream).
	if !anyLabeled(priorAbsWords) || !anyLabeled(currLocalWords) {
		return currLocalWords, prevMaxLabel, false
	}

	// 1. Pair words across the overlap by time anchor.
	pairs := timeAnchorPairs(
		priorAbsWords,
		currLocalWords,
		currStartOffsetMS,
		priorSeamMS,
	)

	// 2. Sparse overlap → fall back to label-by-ordinal offset.
	if len(pairs) < alignMinMatchedPairs {
		return offsetLabels(currLocalWords, prevMaxLabel), maxLabelAfterOffset(currLocalWords, prevMaxLabel), true
	}

	// 3. Build co-occurrence matrix: currLabel → priorLabel → count.
	cooc := map[string]map[string]int{}
	totals := map[string]int{}
	for _, p := range pairs {
		if p.CurrLabel == "" || p.PriorLabel == "" {
			continue
		}
		if cooc[p.CurrLabel] == nil {
			cooc[p.CurrLabel] = map[string]int{}
		}
		cooc[p.CurrLabel][p.PriorLabel]++
		totals[p.CurrLabel]++
	}

	// 4. Derive translation map (currLabel → priorLabel) gated on
	//    alignMajorityFraction. Ambiguous current-labels left out
	//    of the map; those words get empty SpeakerLabel for LLM
	//    downstream re-clustering.
	translation := map[string]string{}
	for currLabel, byPrior := range cooc {
		total := totals[currLabel]
		bestPrior := ""
		bestCount := 0
		for priorLabel, count := range byPrior {
			if count > bestCount {
				bestCount = count
				bestPrior = priorLabel
			}
		}
		if total > 0 && float64(bestCount)/float64(total) >= alignMajorityFraction {
			translation[currLabel] = bestPrior
		}
	}

	// 5. Apply translation. Labels not in the map (new speakers,
	//    ambiguous) need a placement strategy.
	//
	//    Naive approach (pre-2026-05-25): offset to a fresh integer
	//    above prevMaxLabel. This is correct when the unmapped label
	//    represents a genuine NEW speaker the prior chunk had never
	//    seen — but in the dominant 2-speaker therapy case it's
	//    wrong. If the prior chunk had speakers {1, 2} and the
	//    overlap window happened to contain only speaker 1's words,
	//    chunk_i's "2" label has zero co-occurrences with chunk_{i-1}'s
	//    "2" → unmapped → offset to "3". That "3" is the SAME PERSON
	//    as the prior "2" (the patient who happened to be quiet in
	//    the overlap window). Result: a substantive ghost speaker
	//    surviving downstream — observed three times on the Janek
	//    Johny 53-min session.
	//
	//    Smarter strategy: identify "missing priors" — prior-chunk
	//    labels that were never used as a translation target —
	//    and FIRST assign unmapped current labels to those. Only
	//    fall back to a fresh offset once we've exhausted the
	//    missing priors (truly novel speaker).
	missingPriors := computeMissingPriors(priorAbsWords, translation)
	mapped := make([]chunker.Word, len(currLocalWords))
	unmappedOffsets := map[string]string{} // currLabel → assigned label
	maxLabel := prevMaxLabel
	for i, w := range currLocalWords {
		mapped[i] = w
		if w.SpeakerLabel == "" {
			continue
		}
		if t, ok := translation[w.SpeakerLabel]; ok {
			mapped[i].SpeakerLabel = t
			if n := parseLabelNum(t); n > maxLabel {
				maxLabel = n
			}
			continue
		}
		// Unmapped label — assign a stable label within this call.
		if existing, ok := unmappedOffsets[w.SpeakerLabel]; ok {
			mapped[i].SpeakerLabel = existing
			continue
		}
		var assigned string
		if len(missingPriors) > 0 {
			// Pop the first missing prior. Deterministic by sort
			// order (numeric on parseLabelNum, then string).
			assigned = missingPriors[0]
			missingPriors = missingPriors[1:]
		} else {
			// No more missing-priors — genuine new speaker.
			maxLabel++
			assigned = labelNum(maxLabel)
		}
		unmappedOffsets[w.SpeakerLabel] = assigned
		mapped[i].SpeakerLabel = assigned
		if n := parseLabelNum(assigned); n > maxLabel {
			maxLabel = n
		}
	}

	return mapped, maxLabel, false
}

// computeMissingPriors returns the prior-chunk labels that did NOT
// appear as values in the translation map. These are the most
// likely candidates for chunk_i's unmapped labels: same speaker as
// before, just quiet in the overlap window. Returned in sorted
// numeric-then-string order so the assignment is deterministic
// across runs (important for downstream tests + ML
// reproducibility).
func computeMissingPriors(
	priorAbsWords []chunker.Word,
	translation map[string]string,
) []string {
	priorSet := map[string]bool{}
	for _, w := range priorAbsWords {
		if w.SpeakerLabel == "" {
			continue
		}
		priorSet[w.SpeakerLabel] = true
	}
	used := map[string]bool{}
	for _, v := range translation {
		used[v] = true
	}
	var missing []string
	for p := range priorSet {
		if !used[p] {
			missing = append(missing, p)
		}
	}
	// Numeric-aware sort: "2" before "10", but treat non-numeric
	// labels (degenerate input) as ranked after numerics.
	sortLabelsNumericAware(missing)
	return missing
}

// sortLabelsNumericAware sorts in place. Numeric labels first by
// integer value, then non-numeric labels by string order.
func sortLabelsNumericAware(labels []string) {
	type item struct {
		s string
		n int // 0 means non-numeric → sort after numerics
	}
	items := make([]item, len(labels))
	for i, l := range labels {
		items[i] = item{s: l, n: parseLabelNum(l)}
	}
	// Simple insertion sort — N ≤ 10 in practice.
	for i := 1; i < len(items); i++ {
		j := i
		for j > 0 && lessLabel(items[j], items[j-1]) {
			items[j], items[j-1] = items[j-1], items[j]
			j--
		}
	}
	for i, it := range items {
		labels[i] = it.s
	}
}

// lessLabel: numerics ordered by integer; non-numeric (n==0) come
// after numerics; within non-numeric, lexicographic.
func lessLabel(a, b struct {
	s string
	n int
}) bool {
	switch {
	case a.n > 0 && b.n > 0:
		return a.n < b.n
	case a.n > 0 && b.n == 0:
		return true
	case a.n == 0 && b.n > 0:
		return false
	default:
		return a.s < b.s
	}
}

// timeMatchedPair records one cross-chunk word pairing for the
// co-occurrence matrix.
type timeMatchedPair struct {
	PriorLabel string
	CurrLabel  string
}

// timeAnchorPairs scans currLocalWords (converted to absolute time)
// against priorAbsWords. For each curr word, finds prior words
// within ±alignTimeMatchToleranceMS. Picks the best match by text
// similarity (≥ alignTextSimilarityRatio) when multiple candidates
// are in range.
func timeAnchorPairs(
	priorAbsWords, currLocalWords []chunker.Word,
	currStartOffsetMS, priorSeamMS int64,
) []timeMatchedPair {
	pairs := make([]timeMatchedPair, 0)
	for _, c := range currLocalWords {
		cAbs := c.StartMS + currStartOffsetMS
		// Skip current-chunk words outside the overlap window —
		// they have nothing to align with.
		if cAbs >= priorSeamMS {
			break
		}

		bestPrior := -1
		bestSim := -1.0
		for j, p := range priorAbsWords {
			delta := p.StartMS - cAbs
			if delta < 0 {
				delta = -delta
			}
			if delta > alignTimeMatchToleranceMS {
				continue
			}
			sim := textSimilarity(p.Text, c.Text)
			if sim > bestSim {
				bestSim = sim
				bestPrior = j
			}
		}

		if bestPrior >= 0 {
			if bestSim >= alignTextSimilarityRatio || onlyOneCandidate(priorAbsWords, cAbs) {
				pairs = append(pairs, timeMatchedPair{
					PriorLabel: priorAbsWords[bestPrior].SpeakerLabel,
					CurrLabel:  c.SpeakerLabel,
				})
			}
		}
	}
	return pairs
}

// onlyOneCandidate reports whether exactly one prior word falls
// inside the time-tolerance window of `targetAbsMS`. When true the
// text-similarity floor is relaxed — the time anchor alone is
// definitive.
func onlyOneCandidate(priorAbsWords []chunker.Word, targetAbsMS int64) bool {
	n := 0
	for _, p := range priorAbsWords {
		delta := p.StartMS - targetAbsMS
		if delta < 0 {
			delta = -delta
		}
		if delta <= alignTimeMatchToleranceMS {
			n++
			if n > 1 {
				return false
			}
		}
	}
	return n == 1
}

// textSimilarity computes a normalized similarity score between
// two strings: 1.0 - (LevenshteinDistance / maxLen). Result is in
// [0.0, 1.0]. Used as a tie-breaker when multiple prior-chunk words
// fall inside the time tolerance of one current-chunk word.
//
// Case-insensitive, ignores leading/trailing punctuation that Chirp
// sometimes shuffles (".", ",") — keep this lenient because
// nondeterministic punctuation across re-transcriptions is common.
func textSimilarity(a, b string) float64 {
	a = normalizeWord(a)
	b = normalizeWord(b)
	if a == "" && b == "" {
		return 1.0
	}
	d := levenshtein(a, b)
	maxLen := len(a)
	if len(b) > maxLen {
		maxLen = len(b)
	}
	if maxLen == 0 {
		return 0.0
	}
	return 1.0 - float64(d)/float64(maxLen)
}

// normalizeWord lower-cases + strips a few common boundary chars
// to make the similarity check robust against Chirp's variable
// punctuation. Doesn't try to be clever — heavy-handed normalization
// would defeat the alignment when speakers genuinely say different
// words at the same timestamp.
func normalizeWord(s string) string {
	out := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		switch c {
		case '.', ',', '?', '!', '"', '\'':
			continue
		case ' ':
			continue
		}
		if c >= 'A' && c <= 'Z' {
			c = c + ('a' - 'A')
		}
		out = append(out, c)
	}
	return string(out)
}

// levenshtein returns the edit distance between two strings.
// O(len(a) * len(b)) time, O(min(len(a), len(b))) space. Standard
// two-row implementation. Inputs are expected to be short (≤30
// bytes typically — clinical-speech words).
func levenshtein(a, b string) int {
	la, lb := len(a), len(b)
	if la == 0 {
		return lb
	}
	if lb == 0 {
		return la
	}
	prev := make([]int, lb+1)
	curr := make([]int, lb+1)
	for j := 0; j <= lb; j++ {
		prev[j] = j
	}
	for i := 1; i <= la; i++ {
		curr[0] = i
		for j := 1; j <= lb; j++ {
			cost := 1
			if a[i-1] == b[j-1] {
				cost = 0
			}
			del := prev[j] + 1
			ins := curr[j-1] + 1
			sub := prev[j-1] + cost
			best := del
			if ins < best {
				best = ins
			}
			if sub < best {
				best = sub
			}
			curr[j] = best
		}
		prev, curr = curr, prev
	}
	return prev[lb]
}

// offsetLabels rewrites every non-empty SpeakerLabel in `words` to
// a label in the prevMaxLabel+1..N range, preserving intra-chunk
// continuity (same orig label → same new label) but ensuring no
// collision with previously-merged chunks. Used by the fallback
// path when time-anchored matching is too sparse.
func offsetLabels(words []chunker.Word, prevMaxLabel int) []chunker.Word {
	out := make([]chunker.Word, len(words))
	remap := map[string]string{}
	max := prevMaxLabel
	for i, w := range words {
		out[i] = w
		if w.SpeakerLabel == "" {
			continue
		}
		if t, ok := remap[w.SpeakerLabel]; ok {
			out[i].SpeakerLabel = t
			continue
		}
		max++
		remap[w.SpeakerLabel] = labelNum(max)
		out[i].SpeakerLabel = labelNum(max)
	}
	return out
}

// maxLabelAfterOffset is the post-offset maximum label, mirroring
// offsetLabels' counter. Pulled out so callers can know the new
// prevMaxLabel without iterating the mapped slice.
func maxLabelAfterOffset(words []chunker.Word, prevMaxLabel int) int {
	seen := map[string]bool{}
	max := prevMaxLabel
	for _, w := range words {
		if w.SpeakerLabel == "" || seen[w.SpeakerLabel] {
			continue
		}
		seen[w.SpeakerLabel] = true
		max++
	}
	return max
}

// anyLabeled reports whether at least one word in the slice has a
// non-empty SpeakerLabel. Used to short-circuit the alignment when
// native diarization is off (LLM-clustering path).
func anyLabeled(ws []chunker.Word) bool {
	for _, w := range ws {
		if w.SpeakerLabel != "" {
			return true
		}
	}
	return false
}

// parseLabelNum decodes the numeric form of a Chirp speaker label.
// Chirp emits "1", "2", … — strings, not ints. Returns 0 for any
// non-numeric (or empty) label.
func parseLabelNum(s string) int {
	n := 0
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c < '0' || c > '9' {
			return 0
		}
		n = n*10 + int(c-'0')
	}
	return n
}

// labelNum encodes an integer as a string label, matching Chirp's
// "1", "2" output convention.
func labelNum(n int) string {
	if n == 0 {
		return "0"
	}
	digits := []byte{}
	for n > 0 {
		digits = append([]byte{byte('0' + n%10)}, digits...)
		n /= 10
	}
	return string(digits)
}
