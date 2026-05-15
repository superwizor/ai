// Package transcriptfmt builds the two Markdown shapes the llm-worker
// feeds to Vertex AI's Gemini calls.
//
// Format A — chunk-indexed Markdown. Used for call 1 when native
// diarization is absent (the LLM has to cluster). Each chunk header
// carries its index so the LLM can output "Chunks: 0, 2, 5" referring
// back to source rows.
//
//	## Chunk 0 [00:01.20]
//	Z czym dzisiaj przychodzisz?
//
//	## Chunk 1 [00:04.80]
//	Trochę zmęczona ostatnio.
//
// Format B — speaker-turn Markdown. Used for call 2 (always) and for
// call 1 when native diarization is present. Consecutive same-speaker
// chunks merge into one turn with a single time range. No chunk
// indices because the LLM doesn't need them — output is a small
// speaker→role map.
//
//	## Speaker 1 [00:01.20 – 00:07.30]
//	Z czym dzisiaj przychodzisz? Co cię trapi?
//
//	## Speaker 2 [00:08.00 – 00:12.45]
//	Trochę zmęczona ostatnio.
//
// Why decouple from stt-worker.BlobLine: the worker's struct lives in
// `package sttworker`. Importing it here would cycle, so we accept a
// local Chunk type and the callers convert. Conversion is cheap
// (no allocations beyond the slice header) and keeps the package
// reusable from the llm-eval matrix runner.
package transcriptfmt

import (
	"fmt"
	"sort"
	"strings"
)

// Chunk is the minimal representation of a transcript line the
// formatters need. Mirrors stt-worker.BlobLine but without the JSON
// tags so this package has no transitive dependency on the worker.
//
// SpeakerTag == 0 means "no native diarization, all chunks treated as
// one group" for Format B purposes; Format A ignores SpeakerTag
// entirely.
type Chunk struct {
	ChunkIdx     int
	Text         string
	StartMS      int64
	EndMS        int64
	SpeakerTag   int32  // 0 if no native diarization
	SpeakerLabel string // typically unused at format time; resolved later
}

// FormatChunkIndexed returns Format A — one Markdown section per
// chunk, chunk index visible. Chunks are sorted by StartMS so callers
// don't have to (cheap insurance against unordered input from sqlc).
// Empty input → empty string.
func FormatChunkIndexed(chunks []Chunk) string {
	if len(chunks) == 0 {
		return ""
	}
	sorted := sortByStart(chunks)

	var b strings.Builder
	for i, c := range sorted {
		if i > 0 {
			b.WriteByte('\n')
		}
		fmt.Fprintf(&b, "## Chunk %d [%s]\n%s\n", c.ChunkIdx, formatOffset(c.StartMS), strings.TrimSpace(c.Text))
	}
	return b.String()
}

// FormatSpeakerTurns returns Format B — consecutive same-speaker
// chunks merged into one section per turn. Same boundary rule as
// clinical-svc/internal/grouping/turns.go: a new turn starts when the
// SpeakerTag changes. SpeakerLabel is not used as a boundary because
// the format is consumed by an LLM that only needs the (anonymized)
// speaker_tag stable.
//
// When all SpeakerTags are 0 (no native diarization), every chunk
// folds into a single "Speaker 1" turn — semantically the correct
// answer for "we have no speaker info", and lets the format degrade
// gracefully. Callers that want chunk-level granularity in this case
// should pick Format A instead.
//
// Sort defensive against unordered input (same as Format A).
func FormatSpeakerTurns(chunks []Chunk) string {
	if len(chunks) == 0 {
		return ""
	}
	sorted := sortByStart(chunks)

	type turn struct {
		speakerTag int32
		startMS    int64
		endMS      int64
		texts      []string
	}
	var turns []turn
	for _, c := range sorted {
		// Treat SpeakerTag 0 as "default speaker 1" for Format B
		// so unattributed transcripts still produce a valid Markdown
		// shape. Production won't ship this path — Format A is
		// preferred when speaker_tag is 0 — but the eval matrix
		// exercises it.
		tag := c.SpeakerTag
		if tag == 0 {
			tag = 1
		}
		if n := len(turns); n > 0 && turns[n-1].speakerTag == tag {
			if c.EndMS > turns[n-1].endMS {
				turns[n-1].endMS = c.EndMS
			}
			if t := strings.TrimSpace(c.Text); t != "" {
				turns[n-1].texts = append(turns[n-1].texts, t)
			}
			continue
		}
		t := turn{speakerTag: tag, startMS: c.StartMS, endMS: c.EndMS}
		if txt := strings.TrimSpace(c.Text); txt != "" {
			t.texts = []string{txt}
		}
		turns = append(turns, t)
	}

	var b strings.Builder
	for i, t := range turns {
		if i > 0 {
			b.WriteByte('\n')
		}
		fmt.Fprintf(&b, "## Speaker %d [%s – %s]\n%s\n",
			t.speakerTag,
			formatOffset(t.startMS),
			formatOffset(t.endMS),
			strings.Join(t.texts, " "))
	}
	return b.String()
}

// formatOffset renders milliseconds as `mm:ss.dd` (decisecond
// precision). Chosen over the proto's full Duration string format
// because the LLM prompt example uses this shape — keeping the
// formatter and the worked example in lockstep matters for prompt
// adherence on smaller models.
func formatOffset(ms int64) string {
	if ms < 0 {
		ms = 0
	}
	totalSeconds := ms / 1000
	deci := (ms % 1000) / 10
	minutes := totalSeconds / 60
	seconds := totalSeconds % 60
	return fmt.Sprintf("%02d:%02d.%02d", minutes, seconds, deci)
}

func sortByStart(chunks []Chunk) []Chunk {
	out := make([]Chunk, len(chunks))
	copy(out, chunks)
	sort.SliceStable(out, func(i, j int) bool {
		return out[i].StartMS < out[j].StartMS
	})
	return out
}
