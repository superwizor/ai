package chunker

import "testing"

func TestChunkByPauses_BasicSplit(t *testing.T) {
	words := []Word{
		{Text: "Cześć", StartMS: 0, EndMS: 500, Confidence: 0.95},
		{Text: "jak", StartMS: 600, EndMS: 800, Confidence: 0.92},
		{Text: "się", StartMS: 850, EndMS: 1000, Confidence: 0.93},
		{Text: "masz", StartMS: 1050, EndMS: 1300, Confidence: 0.94},
		// Pauza 800ms — split tutaj
		{Text: "Dobrze", StartMS: 2100, EndMS: 2500, Confidence: 0.91},
		{Text: "dziękuję", StartMS: 2550, EndMS: 3000, Confidence: 0.90},
	}

	chunks := ChunkByPauses(words, Config{PauseThresholdMS: 600})

	if len(chunks) != 2 {
		t.Fatalf("expected 2 chunks, got %d", len(chunks))
	}
	if chunks[0].Text != "Cześć jak się masz" {
		t.Errorf("chunk 0 text = %q", chunks[0].Text)
	}
	if chunks[1].Text != "Dobrze dziękuję" {
		t.Errorf("chunk 1 text = %q", chunks[1].Text)
	}
	if chunks[0].WordCount != 4 {
		t.Errorf("chunk 0 word count = %d, want 4", chunks[0].WordCount)
	}
}

func TestChunkByPauses_EmptyInput(t *testing.T) {
	chunks := ChunkByPauses([]Word{}, DefaultConfig())
	if len(chunks) != 0 {
		t.Errorf("expected 0 chunks, got %d", len(chunks))
	}
}

func TestChunkByPauses_SingleWord(t *testing.T) {
	words := []Word{{Text: "Tak", StartMS: 0, EndMS: 200, Confidence: 0.9}}
	chunks := ChunkByPauses(words, DefaultConfig())
	if len(chunks) != 1 {
		t.Fatalf("expected 1 chunk, got %d", len(chunks))
	}
	if chunks[0].Text != "Tak" {
		t.Errorf("text = %q", chunks[0].Text)
	}
}

func TestChunkByPauses_LongMonologue(t *testing.T) {
	words := []Word{}
	startMS := int64(0)
	for i := 0; i < 30; i++ {
		w := Word{
			Text:       "słowo",
			StartMS:    startMS,
			EndMS:      startMS + 200,
			Confidence: 0.9,
		}
		words = append(words, w)
		startMS += 250
	}

	cfg := Config{
		PauseThresholdMS:   600,
		MaxChunkDurationMS: 3000,
	}
	chunks := ChunkByPauses(words, cfg)

	if len(chunks) < 2 {
		t.Errorf("expected splitting, got %d chunks", len(chunks))
	}
	for _, c := range chunks {
		duration := c.EndMS - c.StartMS
		if duration > 3500 {
			t.Errorf("chunk duration %dms exceeds max+slack", duration)
		}
	}
}

func TestComputeStats(t *testing.T) {
	chunks := []Chunk{
		{Text: "abc", WordCount: 1, StartMS: 0, EndMS: 1000, Confidence: 0.9},
		{Text: "def", WordCount: 1, StartMS: 2000, EndMS: 3000, Confidence: 0.8},
	}
	s := ComputeStats(chunks)
	if s.ChunkCount != 2 {
		t.Errorf("count = %d", s.ChunkCount)
	}
	if s.TotalWords != 2 {
		t.Errorf("words = %d", s.TotalWords)
	}
}

// Speaker change forces a chunk boundary even when timing-adjacent.
// Without this, two back-and-forth speakers in a couple session would
// merge into one chunk and lose attribution downstream.
func TestChunkByPauses_SpeakerChangeForcesSplit(t *testing.T) {
	words := []Word{
		{Text: "How", StartMS: 0, EndMS: 200, Confidence: 0.95, SpeakerLabel: "1"},
		{Text: "are", StartMS: 250, EndMS: 400, Confidence: 0.95, SpeakerLabel: "1"},
		{Text: "you", StartMS: 450, EndMS: 600, Confidence: 0.95, SpeakerLabel: "1"},
		// 100ms gap — well under pause threshold (600) — but speaker changes
		{Text: "Fine", StartMS: 700, EndMS: 900, Confidence: 0.95, SpeakerLabel: "2"},
		{Text: "thanks", StartMS: 950, EndMS: 1200, Confidence: 0.95, SpeakerLabel: "2"},
	}
	chunks := ChunkByPauses(words, Config{PauseThresholdMS: 600})

	if len(chunks) != 2 {
		t.Fatalf("speaker change must force split, expected 2 chunks, got %d: %+v", len(chunks), chunks)
	}
	if chunks[0].SpeakerLabel != "1" || chunks[1].SpeakerLabel != "2" {
		t.Errorf("speaker labels: %q / %q", chunks[0].SpeakerLabel, chunks[1].SpeakerLabel)
	}
	if chunks[0].Text != "How are you" {
		t.Errorf("chunk 0 text = %q", chunks[0].Text)
	}
	if chunks[1].Text != "Fine thanks" {
		t.Errorf("chunk 1 text = %q", chunks[1].Text)
	}
}

// Same-speaker timing-adjacent words still group as one chunk —
// proves the speaker rule only triggers on a real change.
func TestChunkByPauses_SameSpeakerNoSplit(t *testing.T) {
	words := []Word{
		{Text: "Hello", StartMS: 0, EndMS: 200, Confidence: 0.95, SpeakerLabel: "1"},
		{Text: "world", StartMS: 250, EndMS: 500, Confidence: 0.95, SpeakerLabel: "1"},
	}
	chunks := ChunkByPauses(words, Config{PauseThresholdMS: 600})

	if len(chunks) != 1 {
		t.Fatalf("same-speaker timing-adjacent must stay 1 chunk, got %d", len(chunks))
	}
	if chunks[0].SpeakerLabel != "1" {
		t.Errorf("speaker label: %q", chunks[0].SpeakerLabel)
	}
}

// Cross-speaker short chunks must NOT be merged into the previous
// chunk by mergeShortChunks — even with sub-min duration.
func TestChunkByPauses_MergeShortRespectsSpeakerBoundary(t *testing.T) {
	words := []Word{
		// Speaker 1 — long enough
		{Text: "I", StartMS: 0, EndMS: 100, Confidence: 0.95, SpeakerLabel: "1"},
		{Text: "feel", StartMS: 150, EndMS: 400, Confidence: 0.95, SpeakerLabel: "1"},
		{Text: "anxious", StartMS: 450, EndMS: 900, Confidence: 0.95, SpeakerLabel: "1"},
		// Speaker 2 — tiny "uh-huh" back-channel
		{Text: "uh-huh", StartMS: 950, EndMS: 1100, Confidence: 0.95, SpeakerLabel: "2"},
		// Speaker 1 resumes
		{Text: "every", StartMS: 1200, EndMS: 1500, Confidence: 0.95, SpeakerLabel: "1"},
		{Text: "morning", StartMS: 1550, EndMS: 2000, Confidence: 0.95, SpeakerLabel: "1"},
	}
	chunks := ChunkByPauses(words, Config{
		PauseThresholdMS:   600,
		MinChunkDurationMS: 500, // 150ms "uh-huh" is below this
	})

	// Without the cross-speaker guard, the 150ms "uh-huh" chunk would
	// get merged into the preceding speaker-1 chunk → speaker 2's
	// attribution silently vanishes from the transcript.
	speakerSeq := make([]string, len(chunks))
	for i, c := range chunks {
		speakerSeq[i] = c.SpeakerLabel
	}
	if len(chunks) < 3 {
		t.Fatalf("speaker sequence collapsed: got %d chunks (labels=%v) — short cross-speaker chunk was merged", len(chunks), speakerSeq)
	}
	// Expected speaker pattern: 1, 2, 1 (with possible internal splits within speaker-1 stretches OK)
	if speakerSeq[0] != "1" {
		t.Errorf("first chunk speaker: %q want 1", speakerSeq[0])
	}
	foundSpeaker2 := false
	for _, s := range speakerSeq {
		if s == "2" {
			foundSpeaker2 = true
			break
		}
	}
	if !foundSpeaker2 {
		t.Errorf("speaker 2 must appear at least once in the chunk sequence, got %v", speakerSeq)
	}
}

// When STT didn't diarize (every SpeakerLabel is empty), behavior
// is identical to pre-refactor: split by pause only, chunks carry
// empty SpeakerLabel.
func TestChunkByPauses_NoDiarization_BehaviorUnchanged(t *testing.T) {
	words := []Word{
		{Text: "Cześć", StartMS: 0, EndMS: 500, Confidence: 0.95},
		{Text: "świat", StartMS: 600, EndMS: 900, Confidence: 0.95},
	}
	chunks := ChunkByPauses(words, DefaultConfig())
	if len(chunks) != 1 {
		t.Fatalf("expected 1 chunk, got %d", len(chunks))
	}
	if chunks[0].SpeakerLabel != "" {
		t.Errorf("speaker_label should be empty when no diarization, got %q", chunks[0].SpeakerLabel)
	}
}
