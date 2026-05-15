// Package chunker segmentuje strumień słów (z timestamps) na "chunki"
// na podstawie pauz między słowami.
//
// Ten pakiet jest używany jako workaround braku natywnej diaryzacji
// Chirp 3 dla polskiego (zob. ADR-IMPL-007). Zwracane chunki nie mają
// przypisanych mówców — przypisanie robi LLM w następnym kroku pipeline'u
// na podstawie analizy treści.
package chunker

import (
	"strings"
	"time"
)

// Word reprezentuje pojedyncze słowo z timestamps zwrócone przez STT.
// SpeakerLabel jest wypełniony tylko gdy STT zwrócił natywną diaryzację
// (Chirp 3 z DiarizationConfig dla wspieranego języka). Pusty string =
// brak diaryzacji, llm-worker zrobi klastrowanie potem.
type Word struct {
	Text         string
	StartMS      int64
	EndMS        int64
	Confidence   float32
	SpeakerLabel string // "" when STT didn't diarize
}

// Chunk reprezentuje grupę kolejnych słów rozdzieloną pauzą od następnej grupy.
// Wszystkie słowa w chunku mają ten sam SpeakerLabel — ChunkByPauses
// forsuje split przy zmianie mówcy, więc Chunk.SpeakerLabel == words[0].
// SpeakerLabel pusty gdy STT nie diaryzował.
type Chunk struct {
	Index        int     // 0-based, w kolejności występowania
	Text         string  // konkatenowane słowa, jeden spacja
	StartMS      int64   // timestamp pierwszego słowa
	EndMS        int64   // timestamp końca ostatniego słowa
	WordCount    int
	Confidence   float32 // średnia ważona długością słów
	SpeakerLabel string  // raw label from STT (e.g. "1", "2"); empty when not diarized
}

// Config kontroluje zachowanie chunkera.
type Config struct {
	// PauseThresholdMS: minimalna długość pauzy (w ms) między słowem N a N+1
	// żeby uznać że jest zmiana chunka. Default 600ms.
	PauseThresholdMS int

	// MinChunkDurationMS: minimalna długość chunka. Krótsze są mergowane do
	// poprzedniego (filler tokens jak "mhm", "tak"). Default 300ms.
	// Set 0 żeby wyłączyć merging.
	MinChunkDurationMS int

	// MaxChunkDurationMS: maksymalna długość chunka. Długie monologi są
	// dzielone na pod-chunki nawet bez pauzy. Default 60000ms (60s).
	// Set 0 żeby wyłączyć splitting.
	MaxChunkDurationMS int
}

// DefaultConfig zwraca rozsądne domyślne parametry dla sesji terapeutycznych.
func DefaultConfig() Config {
	return Config{
		PauseThresholdMS:   600,
		MinChunkDurationMS: 300,
		MaxChunkDurationMS: 60000,
	}
}

// ChunkByPauses segmentuje słowa na chunki według pauz.
func ChunkByPauses(words []Word, cfg Config) []Chunk {
	if len(words) == 0 {
		return []Chunk{}
	}

	chunks := buildBaseChunks(words, cfg.PauseThresholdMS)

	if cfg.MinChunkDurationMS > 0 {
		chunks = mergeShortChunks(chunks, cfg.MinChunkDurationMS)
	}

	if cfg.MaxChunkDurationMS > 0 {
		chunks = splitLongChunks(chunks, words, cfg.MaxChunkDurationMS)
	}

	for i := range chunks {
		chunks[i].Index = i
	}

	return chunks
}

func buildBaseChunks(words []Word, pauseThresholdMS int) []Chunk {
	chunks := []Chunk{}
	current := Chunk{StartMS: words[0].StartMS, SpeakerLabel: words[0].SpeakerLabel}
	wordsInChunk := []Word{}

	for i, w := range words {
		current.Text += w.Text + " "
		current.EndMS = w.EndMS
		current.WordCount++
		wordsInChunk = append(wordsInChunk, w)

		isLastWord := i == len(words)-1
		shouldFlush := isLastWord
		if !isLastWord {
			// Flush condition (a): pause threshold exceeded
			pauseMS := words[i+1].StartMS - w.EndMS
			if int(pauseMS) >= pauseThresholdMS {
				shouldFlush = true
			}
			// Flush condition (b): speaker change. Without this, two
			// adjacent speakers in tight timing (back-and-forth in a
			// couple session) would merge into one chunk and lose
			// attribution. ChunkByPauses guarantees every chunk has a
			// single SpeakerLabel; mergeShortChunks must also respect
			// this.
			if words[i+1].SpeakerLabel != w.SpeakerLabel {
				shouldFlush = true
			}
		}

		if shouldFlush {
			current.Text = strings.TrimSpace(current.Text)
			current.Confidence = weightedAverageConfidence(wordsInChunk)
			chunks = append(chunks, current)

			if !isLastWord {
				current = Chunk{StartMS: words[i+1].StartMS, SpeakerLabel: words[i+1].SpeakerLabel}
				wordsInChunk = []Word{}
			}
		}
	}

	return chunks
}

func mergeShortChunks(chunks []Chunk, minDurationMS int) []Chunk {
	if len(chunks) <= 1 {
		return chunks
	}

	merged := []Chunk{chunks[0]}
	for i := 1; i < len(chunks); i++ {
		c := chunks[i]
		duration := c.EndMS - c.StartMS

		// Cross-speaker guard: a short chunk from speaker B must NOT
		// be merged into the previous speaker-A chunk — that'd
		// silently mis-attribute a back-channel "uh-huh" from the
		// therapist as part of the patient's prior turn (or vice
		// versa). Only merge when both chunks share a speaker label.
		// Empty labels (no native diarization) match each other, so
		// the old behavior is preserved when STT didn't diarize.
		sameSpeaker := len(merged) > 0 && merged[len(merged)-1].SpeakerLabel == c.SpeakerLabel
		if duration < int64(minDurationMS) && sameSpeaker {
			prev := &merged[len(merged)-1]
			prev.Text += " " + c.Text
			prev.EndMS = c.EndMS
			prevWords := prev.WordCount
			cWords := c.WordCount
			total := prevWords + cWords
			if total > 0 {
				prev.Confidence = (prev.Confidence*float32(prevWords) +
					c.Confidence*float32(cWords)) / float32(total)
			}
			prev.WordCount = total
		} else {
			merged = append(merged, c)
		}
	}

	return merged
}

func splitLongChunks(chunks []Chunk, words []Word, maxDurationMS int) []Chunk {
	result := []Chunk{}
	for _, c := range chunks {
		duration := c.EndMS - c.StartMS
		if duration <= int64(maxDurationMS) {
			result = append(result, c)
			continue
		}

		chunkWords := []Word{}
		for _, w := range words {
			if w.StartMS >= c.StartMS && w.EndMS <= c.EndMS {
				chunkWords = append(chunkWords, w)
			}
		}

		subChunks := recursiveSplit(chunkWords, maxDurationMS)
		result = append(result, subChunks...)
	}
	return result
}

func recursiveSplit(words []Word, maxDurationMS int) []Chunk {
	if len(words) == 0 {
		return []Chunk{}
	}

	duration := words[len(words)-1].EndMS - words[0].StartMS
	if duration <= int64(maxDurationMS) {
		return []Chunk{wordsToChunk(words)}
	}

	longestPause := int64(0)
	splitIdx := -1
	for i := 0; i < len(words)-1; i++ {
		pause := words[i+1].StartMS - words[i].EndMS
		if pause > longestPause {
			longestPause = pause
			splitIdx = i
		}
	}

	if splitIdx == -1 || longestPause < 100 {
		splitIdx = len(words)/2 - 1
		if splitIdx < 0 {
			splitIdx = 0
		}
	}

	left := recursiveSplit(words[:splitIdx+1], maxDurationMS)
	right := recursiveSplit(words[splitIdx+1:], maxDurationMS)
	return append(left, right...)
}

func wordsToChunk(words []Word) Chunk {
	if len(words) == 0 {
		return Chunk{}
	}
	c := Chunk{
		StartMS:      words[0].StartMS,
		EndMS:        words[len(words)-1].EndMS,
		WordCount:    len(words),
		SpeakerLabel: words[0].SpeakerLabel, // all words in a recursive-split slice share a speaker (forced by buildBaseChunks)
	}
	parts := make([]string, len(words))
	for i, w := range words {
		parts[i] = w.Text
	}
	c.Text = strings.Join(parts, " ")
	c.Confidence = weightedAverageConfidence(words)
	return c
}

func weightedAverageConfidence(words []Word) float32 {
	if len(words) == 0 {
		return 0
	}
	totalChars := 0
	weightedSum := float32(0)
	for _, w := range words {
		l := len(w.Text)
		if l == 0 {
			l = 1
		}
		totalChars += l
		weightedSum += w.Confidence * float32(l)
	}
	if totalChars == 0 {
		return 0
	}
	return weightedSum / float32(totalChars)
}

// Stats oblicza statystyki dla zbioru chunków (do logowania / debug).
type Stats struct {
	ChunkCount     int
	TotalWords     int
	TotalDuration  time.Duration
	AvgChunkLength time.Duration
	AvgConfidence  float32
}

func ComputeStats(chunks []Chunk) Stats {
	if len(chunks) == 0 {
		return Stats{}
	}
	s := Stats{ChunkCount: len(chunks)}
	totalDurMS := int64(0)
	totalConf := float32(0)
	for _, c := range chunks {
		s.TotalWords += c.WordCount
		totalDurMS += c.EndMS - c.StartMS
		totalConf += c.Confidence
	}
	s.TotalDuration = time.Duration(totalDurMS) * time.Millisecond
	s.AvgChunkLength = s.TotalDuration / time.Duration(len(chunks))
	s.AvgConfidence = totalConf / float32(len(chunks))
	return s
}
