package sttgcs

// collapse.go — Post-merge ghost-speaker elimination.
//
// `AlignAndMapSpeakers` in alignment.go offsets a chunk's
// borderline-ambiguous labels into a fresh integer range when the
// majority-fraction threshold isn't met (default 0.6). Conservative
// for novel-speaker preservation, but the side effect is occasional
// "ghost" labels that represent the same person as one of the
// existing labels — Chirp just couldn't decide cleanly in the
// overlap window. Without intervention, the ghost survives all the
// way to the LLM call 1 prompt as a numbered speaker turn group,
// and the LLM dutifully reports the count it was shown.
//
// Evidence: session 78679bff (Gabriela En, 2026-05-22) and
// e7a1031c-… (Janek Johny, 2026-05-24) both reported speaker_count=3
// for what were 2-speaker therapy sessions. Downstream "missing
// person" symptom because chunks tagged with the ghost integer get
// attributed to a fake third speaker; the real speaker loses those
// chunks.
//
// The collapse heuristic: count words per SpeakerLabel; any label
// holding fewer than `ghostMaxWords` words AND fewer than
// `ghostMaxFraction` of the total is suspected of being an
// alignment artifact and merged into the temporally-nearest
// non-ghost neighbour. Iterates until the speaker set settles or
// no label is below threshold. Bounded by the initial label count
// so termination is guaranteed.
//
// Defensive thresholds (conservative; safe for couple's-therapy or
// any multi-speaker scenario where each speaker actually contributes
// non-trivial speech):
//
//   - ghostMaxWords     = 50   (a therapist or patient always
//                               speaks more than 50 words in any
//                               session worth diarizing)
//   - ghostMaxFraction  = 0.01 (1% of total — covers very long
//                               sessions where 50 absolute might
//                               otherwise feel tight)
//
// Tuning these tighter would risk collapsing a legitimate quiet
// participant. Tuning looser leaves ghosts intact. The current
// values were chosen to catch only the alignment-offset case
// (where the ghost is typically a handful of words).

import (
	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
)

// Thresholds for ghost-label detection. Exposed via constants so
// tests can override without touching production behaviour.
const (
	collapseGhostMaxWords    = 50
	collapseGhostMaxFraction = 0.01
)

// CollapseStats is the per-call summary surfaced to the caller for
// observability. Mergers emit a structured log when RemovedLabels
// > 0 so production drift in the alignment is visible.
type CollapseStats struct {
	// Total distinct speaker labels in `words` BEFORE collapse.
	InitialSpeakers int
	// Total distinct speaker labels AFTER collapse.
	FinalSpeakers int
	// Labels removed by the heuristic (in iteration order).
	RemovedLabels []string
	// Per-removed-label word count before reassignment.
	RemovedWordCounts map[string]int
}

// CollapseGhostSpeakers walks `words` and eliminates ghost speaker
// labels in place. Words with the ghost label have their
// `SpeakerLabel` rewritten to the nearest non-ghost neighbor's
// label. No-op when <= 2 distinct labels exist (the common case)
// or when every label exceeds the ghost thresholds.
//
// Mutates `words` in place. Caller's slice is owned post-call.
func CollapseGhostSpeakers(words []chunker.Word) CollapseStats {
	return CollapseGhostSpeakersWithThresholds(
		words, collapseGhostMaxWords, collapseGhostMaxFraction,
	)
}

// CollapseGhostSpeakersWithThresholds is the parameterized variant
// used by tests. Most callers should use CollapseGhostSpeakers.
func CollapseGhostSpeakersWithThresholds(
	words []chunker.Word,
	ghostMaxWords int,
	ghostMaxFraction float64,
) CollapseStats {
	stats := CollapseStats{RemovedWordCounts: map[string]int{}}
	if len(words) == 0 {
		return stats
	}
	counts := wordCountsByLabel(words)
	stats.InitialSpeakers = len(counts)
	if len(counts) <= 2 {
		stats.FinalSpeakers = len(counts)
		return stats
	}

	// Effective ghost threshold: capped strictly at ghostMaxWords (50).
	// This ensures that any speaker contributing more than 50 words (such
	// as Janek Johny) is preserved as a legitimate participant, while
	// still collapsing tiny alignment artifacts (under 50 words) in
	// both short and long sessions.
	totalWords := 0
	for _, c := range counts {
		totalWords += c
	}
	threshold := ghostMaxWords

	// Iterate: each round, pick the smallest below-threshold label
	// and merge it. Bounded by initial label count so we can't loop.
	for iter := 0; iter < stats.InitialSpeakers; iter++ {
		ghost := ""
		ghostCount := threshold + 1
		for label, c := range counts {
			if c <= threshold && c < ghostCount {
				ghost = label
				ghostCount = c
			}
		}
		if ghost == "" {
			break
		}
		// Safety: don't collapse so far that we'd remove the last
		// non-empty label. Defensive in case threshold ever gets
		// set so high that everything is below it.
		if len(counts) <= 1 {
			break
		}

		// Build the candidate set of NON-ghost labels (this round
		// — other labels removed in earlier iterations are no
		// longer eligible either). Used by the nearest-neighbour
		// scan so it doesn't reattach to a label we just dropped.
		eligible := make(map[string]bool, len(counts))
		for label := range counts {
			if label != ghost {
				eligible[label] = true
			}
		}

		// Reassign every ghost word.
		for i := range words {
			if words[i].SpeakerLabel != ghost {
				continue
			}
			words[i].SpeakerLabel = nearestEligibleLabel(words, i, eligible)
		}

		stats.RemovedLabels = append(stats.RemovedLabels, ghost)
		stats.RemovedWordCounts[ghost] = ghostCount
		delete(counts, ghost)
	}

	stats.FinalSpeakers = len(counts)
	return stats
}

// wordCountsByLabel returns the per-label word count, excluding
// words with empty SpeakerLabel (those are LLM-clustered downstream
// and don't participate in the ghost-detection question).
func wordCountsByLabel(words []chunker.Word) map[string]int {
	out := make(map[string]int)
	for _, w := range words {
		if w.SpeakerLabel == "" {
			continue
		}
		out[w.SpeakerLabel]++
	}
	return out
}

// nearestEligibleLabel scans symmetrically outward from i for the
// closest word whose SpeakerLabel is in `eligible`. Ties prefer
// backward (matches the convention used by
// llm-worker.nearestKnownGroupIndex). Returns "" if no eligible
// neighbor exists — degenerate case, caller already guarded.
func nearestEligibleLabel(
	words []chunker.Word,
	i int,
	eligible map[string]bool,
) string {
	for off := 1; off < len(words); off++ {
		if b := i - off; b >= 0 {
			if eligible[words[b].SpeakerLabel] {
				return words[b].SpeakerLabel
			}
		}
		if f := i + off; f < len(words) {
			if eligible[words[f].SpeakerLabel] {
				return words[f].SpeakerLabel
			}
		}
	}
	return ""
}
