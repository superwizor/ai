package transcriptfmt

import (
	"strings"
	"testing"
)

// chunk is a brevity helper for table-driven tests.
func chunk(idx int, startMS, endMS int64, tag int32, text string) Chunk {
	return Chunk{ChunkIdx: idx, StartMS: startMS, EndMS: endMS, SpeakerTag: tag, Text: text}
}

func TestFormatChunkIndexed_Empty(t *testing.T) {
	if got := FormatChunkIndexed(nil); got != "" {
		t.Errorf("nil input → expected empty, got %q", got)
	}
	if got := FormatChunkIndexed([]Chunk{}); got != "" {
		t.Errorf("empty input → expected empty, got %q", got)
	}
}

func TestFormatChunkIndexed_Basic(t *testing.T) {
	out := FormatChunkIndexed([]Chunk{
		chunk(0, 1200, 4500, 0, "Z czym dzisiaj przychodzisz?"),
		chunk(1, 4800, 7800, 0, "Trochę zmęczona ostatnio."),
	})
	want := strings.TrimLeft(`
## Chunk 0 [00:01.20]
Z czym dzisiaj przychodzisz?

## Chunk 1 [00:04.80]
Trochę zmęczona ostatnio.
`, "\n")
	if out != want {
		t.Errorf("format mismatch:\nwant:\n%s\ngot:\n%s", want, out)
	}
}

// Out-of-order input must be sorted before rendering. Defensive
// against sqlc query results that didn't ORDER BY.
func TestFormatChunkIndexed_SortsByStartMS(t *testing.T) {
	out := FormatChunkIndexed([]Chunk{
		chunk(1, 4800, 7800, 0, "second"),
		chunk(0, 1200, 4500, 0, "first"),
	})
	if !strings.Contains(out, "## Chunk 0") || !strings.Contains(out, "## Chunk 1") {
		t.Fatalf("both chunks must appear: %q", out)
	}
	firstIdx := strings.Index(out, "## Chunk 0")
	secondIdx := strings.Index(out, "## Chunk 1")
	if firstIdx > secondIdx {
		t.Errorf("chunk 0 (start=1200) must precede chunk 1 (start=4800) regardless of input order")
	}
}

// SpeakerTag is irrelevant for Format A — it should not affect the
// output. This pins the contract: Format A is the "no native
// diarization needed" path.
func TestFormatChunkIndexed_IgnoresSpeakerTag(t *testing.T) {
	withTags := FormatChunkIndexed([]Chunk{
		chunk(0, 1200, 4500, 1, "a"),
		chunk(1, 4800, 7800, 2, "b"),
	})
	without := FormatChunkIndexed([]Chunk{
		chunk(0, 1200, 4500, 0, "a"),
		chunk(1, 4800, 7800, 0, "b"),
	})
	if withTags != without {
		t.Errorf("Format A must ignore speaker_tag; outputs differ:\n%q\n%q", withTags, without)
	}
}

// Whitespace-padded text gets trimmed so the Markdown is clean.
func TestFormatChunkIndexed_TrimsText(t *testing.T) {
	out := FormatChunkIndexed([]Chunk{
		chunk(0, 1200, 4500, 0, "  padded text  \n"),
	})
	if !strings.Contains(out, "padded text") || strings.Contains(out, "  padded text") {
		t.Errorf("text must be TrimSpace'd; got %q", out)
	}
}

func TestFormatSpeakerTurns_Empty(t *testing.T) {
	if got := FormatSpeakerTurns(nil); got != "" {
		t.Errorf("nil → expected empty, got %q", got)
	}
}

func TestFormatSpeakerTurns_SingleSpeakerCollapsed(t *testing.T) {
	out := FormatSpeakerTurns([]Chunk{
		chunk(0, 1200, 4500, 1, "Z czym dzisiaj przychodzisz?"),
		chunk(1, 4800, 7800, 1, "Co cię trapi?"),
	})
	want := strings.TrimLeft(`
## Speaker 1 [00:01.20 – 00:07.80]
Z czym dzisiaj przychodzisz? Co cię trapi?
`, "\n")
	if out != want {
		t.Errorf("two same-speaker chunks must collapse:\nwant:\n%s\ngot:\n%s", want, out)
	}
}

// A → B → A produces three turns (matches the clinical-svc grouping
// rule). User spec wants every speaker switch surfaced.
func TestFormatSpeakerTurns_ABA_ProducesThreeTurns(t *testing.T) {
	out := FormatSpeakerTurns([]Chunk{
		chunk(0, 1200, 4500, 1, "Powiedziałem mu"),
		chunk(1, 4800, 5100, 2, "Aha"),
		chunk(2, 5400, 8000, 1, "że nie zgadzam się"),
	})
	count := strings.Count(out, "## Speaker")
	if count != 3 {
		t.Errorf("A → B → A must yield 3 sections, got %d:\n%s", count, out)
	}
	if !strings.Contains(out, "## Speaker 1 [00:01.20 – 00:04.50]") ||
		!strings.Contains(out, "## Speaker 2 [00:04.80 – 00:05.10]") ||
		!strings.Contains(out, "## Speaker 1 [00:05.40 – 00:08.00]") {
		t.Errorf("missing expected speaker-turn headers:\n%s", out)
	}
}

// SpeakerTag == 0 (no native diarization) must produce a single
// "Speaker 1" group — graceful degradation rather than empty output.
func TestFormatSpeakerTurns_Tag0_CollapsesToSpeaker1(t *testing.T) {
	out := FormatSpeakerTurns([]Chunk{
		chunk(0, 1200, 4500, 0, "a"),
		chunk(1, 4800, 7800, 0, "b"),
	})
	if strings.Count(out, "## Speaker") != 1 {
		t.Errorf("tag=0 should yield 1 section, got:\n%s", out)
	}
	if !strings.Contains(out, "## Speaker 1") {
		t.Errorf("tag=0 must render as 'Speaker 1', got:\n%s", out)
	}
}

// Empty text in a chunk doesn't get joined into the prose (no double
// spaces) but the time range still extends through it.
func TestFormatSpeakerTurns_EmptyTextSkippedInJoin(t *testing.T) {
	out := FormatSpeakerTurns([]Chunk{
		chunk(0, 1200, 4500, 1, "hello"),
		chunk(1, 4800, 5800, 1, ""),
		chunk(2, 6100, 8000, 1, "world"),
	})
	if !strings.Contains(out, "hello world") {
		t.Errorf("empty chunk must be skipped in join, expected 'hello world' in:\n%s", out)
	}
	if !strings.Contains(out, "[00:01.20 – 00:08.00]") {
		t.Errorf("turn span must cover all three chunks, got:\n%s", out)
	}
}

func TestFormatSpeakerTurns_SortsByStartMS(t *testing.T) {
	out := FormatSpeakerTurns([]Chunk{
		chunk(1, 4800, 7800, 2, "second"),
		chunk(0, 1200, 4500, 1, "first"),
	})
	firstIdx := strings.Index(out, "## Speaker 1")
	secondIdx := strings.Index(out, "## Speaker 2")
	if firstIdx > secondIdx {
		t.Errorf("turns must render in time order; out:\n%s", out)
	}
}

// ===== BCP47 / language =====

func TestBCP47ize(t *testing.T) {
	cases := []struct {
		in, want string
	}{
		{"", ""},
		{" ", ""},
		{"pl", "pl-PL"},
		{"en", "en-US"},
		{"de", "de-DE"},
		{"es", "es-ES"},
		{"fr", "fr-FR"},
		{"uk", "uk-UA"},
		{"PL", "pl-PL"}, // case-insensitive
		{"xx", ""},      // unknown → empty (caller falls back)
		// pre-tagged inputs are case-normalized and returned as-is
		{"pl-PL", "pl-PL"},
		{"PL-pl", "pl-PL"},
		{"en-GB", "en-GB"}, // distinct region preserved
	}
	for _, c := range cases {
		t.Run(c.in, func(t *testing.T) {
			if got := BCP47ize(c.in); got != c.want {
				t.Errorf("BCP47ize(%q) = %q, want %q", c.in, got, c.want)
			}
		})
	}
}

func TestNativeDiarizationSupported_StaticMap(t *testing.T) {
	// Pin the exact state of the static map. Flipping a language
	// from false → true (or vice versa) is intentional and should
	// land in the same commit as the test update. This catches
	// accidental edits.
	//
	// 2026-05-15: expanded to Google's authoritative Chirp 3
	// diarization-supported list. pl-PL and uk-UA explicitly stay
	// false (not on Google's list; pl-PL probe confirmed Chirp
	// returns no speaker_tag).
	want := map[string]bool{
		"pl-PL":       false,
		"uk-UA":       false,
		"cmn-Hans-CN": true,
		"de-DE":       true,
		"en-GB":       true,
		"en-IN":       true,
		"en-US":       true,
		"es-ES":       true,
		"es-US":       true,
		"fr-CA":       true,
		"fr-FR":       true,
		"hi-IN":       true,
		"it-IT":       true,
		"ja-JP":       true,
		"ko-KR":       true,
		"pt-BR":       true,
	}
	if len(Chirp3DiarizationLanguages) != len(want) {
		t.Errorf("map size: want %d, got %d", len(want), len(Chirp3DiarizationLanguages))
	}
	for tag, expected := range want {
		if got := NativeDiarizationSupported(tag); got != expected {
			t.Errorf("%q: want %v, got %v", tag, expected, got)
		}
	}
}

func TestNativeDiarizationSupported_UnknownReturnsFalse(t *testing.T) {
	if NativeDiarizationSupported("zz-ZZ") {
		t.Errorf("unknown language must be false")
	}
}

// formatOffset is internal but the rendered output depends on it.
// Spot-check edge cases here so failures in the bigger tests point
// at the right place.
func TestFormatOffset(t *testing.T) {
	cases := []struct {
		ms   int64
		want string
	}{
		{0, "00:00.00"},
		{100, "00:00.10"},
		{1200, "00:01.20"},
		{59500, "00:59.50"},
		{60000, "01:00.00"},
		{3661230, "61:01.23"},
		{-1, "00:00.00"}, // negative clamps to 0
	}
	for _, c := range cases {
		if got := formatOffset(c.ms); got != c.want {
			t.Errorf("formatOffset(%d) = %q, want %q", c.ms, got, c.want)
		}
	}
}
