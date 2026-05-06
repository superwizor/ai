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
