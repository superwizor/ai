package diarization

import (
	"errors"
	"strings"
	"testing"
)

// goldenCluster — a known-good cluster-grammar response.
const goldenCluster = `# Speakers

## Group 1 — therapist (confidence 0.87)
Chunks: 0, 2, 5, 8, 12, 14, 17
Evidence: "Z czym dzisiaj przychodzisz?"

## Group 2 — patient (confidence 0.92)
Chunks: 1, 3, 6, 9, 13, 15, 18, 19
Evidence: "Trochę zmęczona ostatnio."

# Metadata

Title: Pierwsza sesja - problemy ze snem
Summary: Pacjentka zgłasza objawy bezsenności od 3 tygodni.
Overall_diarization_confidence: 0.89`

// goldenRoleOnly — a known-good role-only-grammar response (used
// when Chirp 3 already assigned speaker tags natively).
const goldenRoleOnly = `# Speakers

Speaker 1 — therapist (confidence 0.92)
Speaker 2 — patient (confidence 0.95)

# Metadata

Title: Druga sesja
Summary: Kontynuacja pracy nad bezsennością.
Overall_diarization_confidence: 0.94`

func TestParse_ClusterGolden(t *testing.T) {
	got, err := ParseMetadataMarkdown(goldenCluster)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Title != "Pierwsza sesja - problemy ze snem" {
		t.Errorf("title: %q", got.Title)
	}
	if !strings.Contains(got.Summary, "bezsenność") && !strings.Contains(got.Summary, "bezsenności") {
		t.Errorf("summary missing keyword: %q", got.Summary)
	}
	if got.OverallDiarizationConfidence < 0.88 || got.OverallDiarizationConfidence > 0.90 {
		t.Errorf("overall confidence: %v", got.OverallDiarizationConfidence)
	}
	if len(got.Speakers) != 2 {
		t.Fatalf("want 2 speakers, got %d", len(got.Speakers))
	}
	if got.Speakers[0].Role != "therapist" || got.Speakers[1].Role != "patient" {
		t.Errorf("roles: %+v", got.Speakers)
	}
	if len(got.Speakers[0].ChunkIndices) != 7 || got.Speakers[0].ChunkIndices[0] != 0 {
		t.Errorf("therapist chunks: %v", got.Speakers[0].ChunkIndices)
	}
	if got.Speakers[1].Evidence != "Trochę zmęczona ostatnio." {
		t.Errorf("patient evidence: %q", got.Speakers[1].Evidence)
	}
}

func TestParse_RoleOnlyGolden(t *testing.T) {
	got, err := ParseMetadataMarkdown(goldenRoleOnly)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got.Speakers) != 2 {
		t.Fatalf("want 2 speakers, got %d", len(got.Speakers))
	}
	if got.Speakers[0].Index != 1 || got.Speakers[1].Index != 2 {
		t.Errorf("indices: %+v", got.Speakers)
	}
	if got.Speakers[0].Role != "therapist" || got.Speakers[1].Role != "patient" {
		t.Errorf("roles: %+v", got.Speakers)
	}
	if len(got.Speakers[0].ChunkIndices) != 0 {
		t.Errorf("role-only must leave ChunkIndices empty; got %v", got.Speakers[0].ChunkIndices)
	}
}

func TestParse_EmptyInput(t *testing.T) {
	if _, err := ParseMetadataMarkdown(""); !errors.Is(err, ErrEmptyInput) {
		t.Errorf("want ErrEmptyInput, got %v", err)
	}
	if _, err := ParseMetadataMarkdown("   \n  \n\n"); !errors.Is(err, ErrEmptyInput) {
		t.Errorf("whitespace-only must be ErrEmptyInput, got %v", err)
	}
}

func TestParse_MissingSpeakers(t *testing.T) {
	in := `# Metadata
Title: x
Summary: y`
	_, err := ParseMetadataMarkdown(in)
	if !errors.Is(err, ErrUnexpectedLine) {
		t.Errorf("want ErrUnexpectedLine (Metadata before Speakers), got %v", err)
	}
}

func TestParse_MissingMetadata(t *testing.T) {
	in := `# Speakers
Speaker 1 — therapist (confidence 0.9)`
	_, err := ParseMetadataMarkdown(in)
	if !errors.Is(err, ErrMissingSection) {
		t.Errorf("want ErrMissingSection, got %v", err)
	}
}

func TestParse_InvalidRole(t *testing.T) {
	in := `# Speakers
Speaker 1 — wizard (confidence 0.9)
# Metadata
Title: x
Summary: y`
	_, err := ParseMetadataMarkdown(in)
	if !errors.Is(err, ErrInvalidRole) {
		t.Errorf("want ErrInvalidRole, got %v", err)
	}
}

func TestParse_ConfidenceOutOfRange(t *testing.T) {
	in := `# Speakers
Speaker 1 — therapist (confidence 1.5)
# Metadata
Title: x
Summary: y`
	_, err := ParseMetadataMarkdown(in)
	if !errors.Is(err, ErrInvalidConfidence) {
		t.Errorf("want ErrInvalidConfidence, got %v", err)
	}
}

func TestParse_DuplicateChunkAcrossGroups(t *testing.T) {
	in := `# Speakers

## Group 1 — therapist (confidence 0.9)
Chunks: 0, 2, 5

## Group 2 — patient (confidence 0.9)
Chunks: 2, 3, 6

# Metadata
Title: x
Summary: y`
	_, err := ParseMetadataMarkdown(in)
	if !errors.Is(err, ErrDuplicateChunkAssignment) {
		t.Errorf("want ErrDuplicateChunkAssignment, got %v", err)
	}
}

func TestParse_MalformedChunkList(t *testing.T) {
	cases := []struct{ name, list string }{
		{"empty", "Chunks: "},
		{"non-int", "Chunks: a, b"},
		{"negative", "Chunks: -1"},
		{"repeated within group", "Chunks: 0, 0, 1"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			in := "# Speakers\n## Group 1 — therapist (confidence 0.9)\n" + c.list +
				"\n# Metadata\nTitle: x\nSummary: y"
			_, err := ParseMetadataMarkdown(in)
			if !errors.Is(err, ErrInvalidChunkList) {
				t.Errorf("want ErrInvalidChunkList, got %v", err)
			}
		})
	}
}

func TestParse_TitleTooLong(t *testing.T) {
	in := `# Speakers
Speaker 1 — therapist (confidence 0.9)
# Metadata
Title: ` + strings.Repeat("x", maxTitleLen+1) + `
Summary: y`
	_, err := ParseMetadataMarkdown(in)
	if !errors.Is(err, ErrTitleTooLong) {
		t.Errorf("want ErrTitleTooLong, got %v", err)
	}
}

func TestParse_SummaryTooLong(t *testing.T) {
	in := `# Speakers
Speaker 1 — therapist (confidence 0.9)
# Metadata
Title: x
Summary: ` + strings.Repeat("x", maxSummaryLen+1)
	_, err := ParseMetadataMarkdown(in)
	if !errors.Is(err, ErrSummaryTooLong) {
		t.Errorf("want ErrSummaryTooLong, got %v", err)
	}
}

// "Summary_short:" must be accepted as an alias for "Summary:". The
// existing JSON schema uses summary_short; this prevents the LLM
// from getting penalized for using the schema-side name when we
// switch to Markdown.
func TestParse_SummaryShortAlias(t *testing.T) {
	in := `# Speakers
Speaker 1 — therapist (confidence 0.9)
# Metadata
Title: x
Summary_short: alias works`
	got, err := ParseMetadataMarkdown(in)
	if err != nil {
		t.Fatalf("Summary_short alias must parse: %v", err)
	}
	if got.Summary != "alias works" {
		t.Errorf("Summary missed: %q", got.Summary)
	}
}

func TestParse_MixedGrammarsRejected(t *testing.T) {
	// Cluster header then a role-only row — model drifted, reject.
	in := `# Speakers

## Group 1 — therapist (confidence 0.9)
Chunks: 0, 1

Speaker 2 — patient (confidence 0.9)

# Metadata
Title: x
Summary: y`
	_, err := ParseMetadataMarkdown(in)
	if !errors.Is(err, ErrUnexpectedLine) {
		t.Errorf("want ErrUnexpectedLine on mixed grammars, got %v", err)
	}
}

// BOM at start (Windows-y outputs) must be stripped, not rejected.
// Use a Unicode escape rather than a literal BOM so the Go source
// stays clean (the compiler rejects literal BOMs in comments).
func TestParse_BOMStripped(t *testing.T) {
	in := "\uFEFF" + goldenRoleOnly
	if _, err := ParseMetadataMarkdown(in); err != nil {
		t.Errorf("BOM must be stripped, got %v", err)
	}
}

// Case-insensitive on section headers.
func TestParse_CaseInsensitiveSections(t *testing.T) {
	in := `# speakers
Speaker 1 — therapist (confidence 0.9)
# METADATA
Title: x
Summary: y`
	if _, err := ParseMetadataMarkdown(in); err != nil {
		t.Errorf("case-insensitive sections must parse: %v", err)
	}
}

// Em dash (—), en dash (–), and plain hyphen (-) all accepted as
// the separator in headers. Model emits whichever it likes.
func TestParse_DashVariants(t *testing.T) {
	for _, dash := range []string{"—", "–", "-"} {
		t.Run(dash, func(t *testing.T) {
			in := `# Speakers
Speaker 1 ` + dash + ` therapist (confidence 0.9)
# Metadata
Title: x
Summary: y`
			if _, err := ParseMetadataMarkdown(in); err != nil {
				t.Errorf("dash %q must parse, got %v", dash, err)
			}
		})
	}
}

// Duplicate Title is suspicious — the model emitted it twice. Reject
// with ErrUnexpectedLine so we don't silently keep the wrong one.
func TestParse_DuplicateTitleRejected(t *testing.T) {
	in := `# Speakers
Speaker 1 — therapist (confidence 0.9)
# Metadata
Title: first
Title: second
Summary: y`
	_, err := ParseMetadataMarkdown(in)
	if !errors.Is(err, ErrUnexpectedLine) {
		t.Errorf("want ErrUnexpectedLine on duplicate Title, got %v", err)
	}
}

// Extra LLM commentary outside section blocks is rejected. The
// prompt forbids it; the parser enforces it. Catches a model that
// adds "Sure, here is..." preamble.
func TestParse_ExtraneousCommentaryRejected(t *testing.T) {
	in := `Sure, here you go:

# Speakers
Speaker 1 — therapist (confidence 0.9)
# Metadata
Title: x
Summary: y`
	_, err := ParseMetadataMarkdown(in)
	if !errors.Is(err, ErrUnexpectedLine) {
		t.Errorf("want ErrUnexpectedLine on preamble, got %v", err)
	}
}

// 3-speaker couple session: cluster grammar with three groups.
func TestParse_ThreeSpeakerCouple(t *testing.T) {
	in := `# Speakers

## Group 1 — therapist (confidence 0.88)
Chunks: 0, 5, 10
Evidence: "Co tu się dzieje?"

## Group 2 — couple_partner (confidence 0.85)
Chunks: 1, 6, 11
Evidence: "Ja uważam, że ..."

## Group 3 — couple_partner (confidence 0.85)
Chunks: 2, 7, 12
Evidence: "A ja widzę to inaczej."

# Metadata
Title: Para - sesja 3
Summary: Praca nad komunikacją.
Overall_diarization_confidence: 0.86`

	got, err := ParseMetadataMarkdown(in)
	if err != nil {
		t.Fatalf("3-speaker couple must parse: %v", err)
	}
	if len(got.Speakers) != 3 {
		t.Errorf("want 3 speakers, got %d", len(got.Speakers))
	}
}

// parseConfidence is internal; spot-check edges so failures point
// to the right place when bigger tests regress.
func TestParseConfidence(t *testing.T) {
	cases := []struct {
		in   string
		want float64
		err  error
	}{
		{"0", 0, nil},
		{"1", 1, nil},
		{"0.5", 0.5, nil},
		{"-0.1", 0, ErrInvalidConfidence},
		{"1.001", 0, ErrInvalidConfidence},
		{"abc", 0, ErrInvalidConfidence},
		{"", 0, ErrInvalidConfidence},
	}
	for _, c := range cases {
		got, err := parseConfidence(c.in)
		if c.err != nil {
			if !errors.Is(err, c.err) {
				t.Errorf("parseConfidence(%q): want err %v, got %v", c.in, c.err, err)
			}
			continue
		}
		if err != nil {
			t.Errorf("parseConfidence(%q): unexpected err %v", c.in, err)
		}
		if got != c.want {
			t.Errorf("parseConfidence(%q) = %v, want %v", c.in, got, c.want)
		}
	}
}
