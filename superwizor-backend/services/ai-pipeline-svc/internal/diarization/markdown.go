// Package diarization parses the call-1 LLM output when llm-worker
// runs in Markdown mode (LLM_DIARIZATION_MODE=markdown).
//
// Two grammars share the same state machine because the downstream
// SpeakerRoleInference struct is identical on both branches:
//
//   1. Cluster grammar — LLM clustered chunks AND inferred roles.
//      Produced when call 1's input was Format A (chunk-indexed).
//
//        # Speakers
//        ## Group 1 — therapist (confidence 0.87)
//        Chunks: 0, 2, 5, 8
//        Evidence: "Z czym dzisiaj przychodzisz?"
//
//        ## Group 2 — patient (confidence 0.92)
//        Chunks: 1, 3, 6, 9
//        Evidence: "Trochę zmęczona ostatnio."
//
//        # Metadata
//        Title: ...
//        Summary: ...
//        Overall_diarization_confidence: 0.89
//
//   2. Role-only grammar — speakers were already known from Chirp.
//      LLM only mapped speaker_tag → role.
//
//        # Speakers
//        Speaker 1 — therapist (confidence 0.92)
//        Speaker 2 — patient (confidence 0.95)
//
//        # Metadata
//        Title: ...
//        Summary: ...
//        Overall_diarization_confidence: 0.94
//
// Failure modes return typed errors (ErrUnexpectedLine, ErrInvalidRole,
// etc.) so the worker can log the exact reason a response didn't
// parse instead of "parse failed". Same retry path as the JSON-mode
// parse failure today: return error from the worker → Pub/Sub
// redelivers → DLQ after retry budget. No auto-fallback to JSON.
package diarization

import (
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

// Result is the parsed output the worker hands to
// generateAndSaveSpeakerLabels. Same field set on both grammars; the
// cluster grammar fills ChunkIndices, role-only leaves it empty and
// the worker derives it by walking the transcript's existing
// speaker_tag column.
type Result struct {
	Title                        string
	Summary                      string
	OverallDiarizationConfidence float64
	Speakers                     []Speaker
}

// Speaker — one entry under "# Speakers". For cluster grammar Index
// is the group number (1, 2, ...) AND ChunkIndices is populated. For
// role-only grammar Index is the speaker_tag (1, 2, ...) and
// ChunkIndices is nil.
type Speaker struct {
	Index        int      // group N or speaker_tag N
	Role         string   // therapist, patient, couple_partner, etc.
	Confidence   float64  // [0, 1]
	ChunkIndices []int    // populated by cluster grammar only
	Evidence     string   // optional; cluster grammar only
}

// Typed errors. parse() wraps the input line where useful via fmt.Errorf.
var (
	ErrEmptyInput               = errors.New("diarization: empty input")
	ErrUnexpectedLine           = errors.New("diarization: unexpected line")
	ErrMissingSection           = errors.New("diarization: missing required section")
	ErrInvalidRole              = errors.New("diarization: invalid role")
	ErrInvalidConfidence        = errors.New("diarization: invalid confidence value")
	ErrInvalidChunkList         = errors.New("diarization: invalid chunk index list")
	ErrDuplicateChunkAssignment = errors.New("diarization: chunk index appears in multiple groups")
	ErrTitleTooLong             = errors.New("diarization: title exceeds budget")
	ErrSummaryTooLong           = errors.New("diarization: summary exceeds budget")
)

// validRoles — exactly the enum we accept downstream. Matches the
// SpeakerRoleInference struct's Role field in llm-worker/main.go.
// Update both in lockstep if the enum grows.
var validRoles = map[string]bool{
	"therapist":             true,
	"patient":               true,
	"couple_partner":        true,
	"family_member_parent":  true,
	"family_member_child":   true,
	"family_member_sibling": true,
	"third_party":           true,
	"filler":                true,
	"unknown":               true,
}

const (
	maxTitleLen   = 100
	maxSummaryLen = 500
)

// Compiled regexes — patterns are tight on purpose. The prompt
// explicitly forbids any output outside this shape; a model that
// drifts gets caught here and the request retries.
var (
	// "## Group 1 — therapist (confidence 0.87)"   (cluster)
	groupHeader = regexp.MustCompile(`^##\s+Group\s+(\d+)\s+[—–-]\s+(\w+)\s+\(confidence\s+([0-9.]+)\)\s*$`)
	// "Speaker 1 — therapist (confidence 0.92)"    (role-only)
	speakerRow = regexp.MustCompile(`^Speaker\s+(\d+)\s+[—–-]\s+(\w+)\s+\(confidence\s+([0-9.]+)\)\s*$`)
	// "Chunks: 0, 2, 5, 8"                          (cluster only)
	// (.*) so an empty-after-colon shape still reaches parseChunkList
	// and surfaces the correct ErrInvalidChunkList instead of an
	// "unexpected line" diagnostic.
	chunksLine = regexp.MustCompile(`^Chunks:\s*(.*)$`)
	// `Evidence: "..."`                             (cluster only, optional)
	evidenceLine = regexp.MustCompile(`^Evidence:\s*"(.+)"\s*$`)
	// "Title: ..."
	titleLine = regexp.MustCompile(`^Title:\s*(.+)$`)
	// "Summary: ..." or "Summary_short: ..." (alias accepted)
	summaryLine = regexp.MustCompile(`^Summary(?:_short)?:\s*(.+)$`)
	// "Overall_diarization_confidence: 0.89"
	overallLine = regexp.MustCompile(`(?i)^Overall(?:_diarization)?_confidence:\s*([0-9.]+)\s*$`)
)

// ParseMetadataMarkdown parses an LLM call-1 response. Auto-detects
// the grammar from the first non-blank line under "# Speakers":
// "## Group N" → cluster, "Speaker N" → role-only.
//
// Tolerances baked in:
//   - Leading/trailing whitespace per line: trimmed
//   - Blank lines between sections / between groups: ignored
//   - Case-insensitive on section/field headers
//   - Role enum: case-insensitive against validRoles
//   - BOM at start: stripped
//   - "Summary:" and "Summary_short:" both accepted
//   - "Overall_confidence:" and "Overall_diarization_confidence:" both accepted
//
// Anything outside these tolerances is rejected with a typed error.
// The retry path (Pub/Sub redeliver) handles transient model glitches.
func ParseMetadataMarkdown(raw string) (Result, error) {
	raw = strings.TrimPrefix(raw, "\uFEFF") // strip UTF-8 BOM
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return Result{}, ErrEmptyInput
	}

	lines := strings.Split(raw, "\n")

	var (
		res         Result
		state       = stateInit
		sawSpeakers bool
		sawMetadata bool
		current     *Speaker // current group being assembled (cluster grammar)
		seenChunk   = map[int]int{} // chunk_idx → group it was assigned to (duplicate guard)
	)

	// finalizeCurrentGroup pushes `current` to res.Speakers UNLESS it
	// has no chunks assigned (parseChunkList returned nil for empty
	// `Chunks:` line, or the LLM forgot the Chunks: line entirely).
	// In cluster grammar a group without any chunks is a degenerate
	// placeholder — happens on tiny sessions (1 chunk total, prompt
	// still asks for ≥2 groups). Drop it silently rather than error.
	// Role-only grammar appends directly without using `current`, so
	// this helper only affects the cluster-grammar path.
	finalizeCurrentGroup := func() {
		if current == nil {
			return
		}
		if len(current.ChunkIndices) > 0 {
			res.Speakers = append(res.Speakers, *current)
		}
		current = nil
	}

	for _, rawLine := range lines {
		line := strings.TrimRight(strings.TrimLeft(rawLine, " \t"), " \t\r")
		if line == "" {
			continue
		}

		// Section transitions are uniform across grammars.
		if isSection(line, "Speakers") {
			if sawSpeakers {
				return Result{}, fmt.Errorf("%w: duplicate '# Speakers' header", ErrUnexpectedLine)
			}
			sawSpeakers = true
			state = stateInSpeakers
			continue
		}
		if isSection(line, "Metadata") {
			if !sawSpeakers {
				return Result{}, fmt.Errorf("%w: '# Metadata' before '# Speakers'", ErrUnexpectedLine)
			}
			// Finalize any open group before switching sections.
			finalizeCurrentGroup()
			sawMetadata = true
			state = stateInMetadata
			continue
		}

		switch state {
		case stateInit:
			return Result{}, fmt.Errorf("%w: %q before any section header", ErrUnexpectedLine, line)

		case stateInSpeakers:
			// Try cluster header
			if m := groupHeader.FindStringSubmatch(line); m != nil {
				finalizeCurrentGroup()
				idx, _ := strconv.Atoi(m[1]) // regex guarantees \d+
				role := strings.ToLower(m[2])
				if !validRoles[role] {
					return Result{}, fmt.Errorf("%w: %q (group %d)", ErrInvalidRole, role, idx)
				}
				conf, err := parseConfidence(m[3])
				if err != nil {
					return Result{}, fmt.Errorf("%w: group %d", err, idx)
				}
				current = &Speaker{Index: idx, Role: role, Confidence: conf}
				continue
			}
			// Try role-only row
			if m := speakerRow.FindStringSubmatch(line); m != nil {
				if current != nil {
					// We were in cluster grammar and now see a role-only
					// line — grammar drift. Reject.
					return Result{}, fmt.Errorf("%w: mixed grammars in '# Speakers'", ErrUnexpectedLine)
				}
				idx, _ := strconv.Atoi(m[1])
				role := strings.ToLower(m[2])
				if !validRoles[role] {
					return Result{}, fmt.Errorf("%w: %q (speaker %d)", ErrInvalidRole, role, idx)
				}
				conf, err := parseConfidence(m[3])
				if err != nil {
					return Result{}, fmt.Errorf("%w: speaker %d", err, idx)
				}
				res.Speakers = append(res.Speakers, Speaker{Index: idx, Role: role, Confidence: conf})
				continue
			}
			// Inside a cluster group, accept Chunks: and Evidence:
			if current != nil {
				if m := chunksLine.FindStringSubmatch(line); m != nil {
					indices, err := parseChunkList(m[1])
					if err != nil {
						return Result{}, fmt.Errorf("%w (group %d)", err, current.Index)
					}
					for _, ci := range indices {
						if prev, dup := seenChunk[ci]; dup {
							return Result{}, fmt.Errorf("%w: chunk %d in groups %d and %d", ErrDuplicateChunkAssignment, ci, prev, current.Index)
						}
						seenChunk[ci] = current.Index
					}
					// Note: indices may be nil for empty `Chunks:` line
					// — finalizeCurrentGroup drops such groups when
					// the next section/header is seen.
					current.ChunkIndices = indices
					continue
				}
				if m := evidenceLine.FindStringSubmatch(line); m != nil {
					current.Evidence = m[1]
					continue
				}
			}
			return Result{}, fmt.Errorf("%w: %q in '# Speakers'", ErrUnexpectedLine, line)

		case stateInMetadata:
			if m := titleLine.FindStringSubmatch(line); m != nil {
				if res.Title != "" {
					return Result{}, fmt.Errorf("%w: duplicate Title", ErrUnexpectedLine)
				}
				res.Title = strings.TrimSpace(m[1])
				if len(res.Title) > maxTitleLen {
					return Result{}, fmt.Errorf("%w: %d > %d", ErrTitleTooLong, len(res.Title), maxTitleLen)
				}
				continue
			}
			if m := summaryLine.FindStringSubmatch(line); m != nil {
				if res.Summary != "" {
					return Result{}, fmt.Errorf("%w: duplicate Summary", ErrUnexpectedLine)
				}
				res.Summary = strings.TrimSpace(m[1])
				if len(res.Summary) > maxSummaryLen {
					return Result{}, fmt.Errorf("%w: %d > %d", ErrSummaryTooLong, len(res.Summary), maxSummaryLen)
				}
				continue
			}
			if m := overallLine.FindStringSubmatch(line); m != nil {
				conf, err := parseConfidence(m[1])
				if err != nil {
					return Result{}, err
				}
				res.OverallDiarizationConfidence = conf
				continue
			}
			return Result{}, fmt.Errorf("%w: %q in '# Metadata'", ErrUnexpectedLine, line)
		}
	}

	if !sawSpeakers {
		return Result{}, fmt.Errorf("%w: '# Speakers'", ErrMissingSection)
	}
	if !sawMetadata {
		return Result{}, fmt.Errorf("%w: '# Metadata'", ErrMissingSection)
	}
	// If we ended mid-cluster, finalize the last group (drops if no chunks).
	finalizeCurrentGroup()
	if len(res.Speakers) == 0 {
		return Result{}, fmt.Errorf("%w: '# Speakers' is empty", ErrMissingSection)
	}
	return res, nil
}

type parseState int

const (
	stateInit parseState = iota
	stateInSpeakers
	stateInMetadata
)

// isSection matches "# <name>" with case-insensitive name match. The
// "#" sigil is intentionally strict — only one "#" — because "##"
// introduces group headers within Speakers.
func isSection(line, name string) bool {
	t := strings.TrimSpace(line)
	if !strings.HasPrefix(t, "# ") {
		return false
	}
	rest := strings.TrimSpace(strings.TrimPrefix(t, "# "))
	return strings.EqualFold(rest, name)
}

func parseConfidence(s string) (float64, error) {
	f, err := strconv.ParseFloat(strings.TrimSpace(s), 64)
	if err != nil {
		return 0, fmt.Errorf("%w: %q", ErrInvalidConfidence, s)
	}
	if f < 0 || f > 1 {
		return 0, fmt.Errorf("%w: %v out of [0,1]", ErrInvalidConfidence, f)
	}
	return f, nil
}

// parseChunkList parses "0, 2, 5, 8" → [0,2,5,8]. Strict: comma
// separator, integers only, no ranges, no negatives. The prompt's
// worked example shows the exact shape so the model shouldn't drift.
//
// Empty list returns (nil, nil) — not an error — because for sessions
// with few chunks the LLM sometimes emits a group with no chunks
// (e.g. 1-chunk session, prompt still asks for 2 groups, group 2 has
// `Chunks:` empty). Caller's finalize-current-group step drops cluster
// groups whose ChunkIndices ended up nil. See the 2026-05-18
// Agnieszka incident for the motivating case.
func parseChunkList(s string) ([]int, error) {
	trimmed := strings.TrimSpace(s)
	if trimmed == "" {
		return nil, nil
	}
	parts := strings.Split(trimmed, ",")
	out := make([]int, 0, len(parts))
	seen := map[int]bool{}
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" {
			return nil, fmt.Errorf("%w: empty element in %q", ErrInvalidChunkList, s)
		}
		n, err := strconv.Atoi(p)
		if err != nil {
			return nil, fmt.Errorf("%w: %q not an integer", ErrInvalidChunkList, p)
		}
		if n < 0 {
			return nil, fmt.Errorf("%w: negative index %d", ErrInvalidChunkList, n)
		}
		if seen[n] {
			return nil, fmt.Errorf("%w: %d repeated within a single group", ErrInvalidChunkList, n)
		}
		seen[n] = true
		out = append(out, n)
	}
	return out, nil
}
