package deepgram

import (
	"encoding/json"
	"fmt"
	"strconv"

	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
)

// Result is the provider-neutral transcript produced from a Deepgram
// response. Word timings are in milliseconds and speaker labels are
// 1-based numeric strings ("1", "2", …) — the exact shape
// ParseChirp3Results emits, so everything downstream of the stt-worker
// (chunker, persistTranscript, llm-worker role-only branch) is
// untouched (docs/39 D5/D6).
type Result struct {
	Words         []chunker.Word
	RequestID     string
	LanguageCode  string // Deepgram short code ("pl"); caller BCP47izes
	WordCount     int
	SpeakerCount  int
	ConfidenceAvg float32
	// AudioDurationSec is Deepgram's measured input duration — a free
	// cross-check against sessions.duration_seconds.
	AudioDurationSec float64

	// droppedWords counts words discarded for implausible timestamps;
	// exposed via DroppedWords() for the caller's observability log.
	droppedWords int
}

// maxPlausibleWordOffsetMS mirrors the identical guard in
// stt-worker.ParseChirp3Results: a word offset beyond 24 h is garbage
// and would overflow the int4 transcript_segments column.
const maxPlausibleWordOffsetMS = 24 * 60 * 60 * 1000

// response mirrors the subset of Deepgram's /v1/listen JSON we consume.
// https://developers.deepgram.com/docs/pre-recorded-audio (json shape:
// results.channels[0].alternatives[0].words[]).
type response struct {
	Metadata struct {
		RequestID string  `json:"request_id"`
		Duration  float64 `json:"duration"`
	} `json:"metadata"`
	Results struct {
		Channels []struct {
			DetectedLanguage string `json:"detected_language"`
			Alternatives     []struct {
				Transcript string  `json:"transcript"`
				Confidence float64 `json:"confidence"`
				Words      []struct {
					Word              string  `json:"word"`
					PunctuatedWord    string  `json:"punctuated_word"`
					Start             float64 `json:"start"`
					End               float64 `json:"end"`
					Confidence        float64 `json:"confidence"`
					Speaker           *int    `json:"speaker"`
					SpeakerConfidence float64 `json:"speaker_confidence"`
				} `json:"words"`
			} `json:"alternatives"`
		} `json:"channels"`
	} `json:"results"`
}

// Parse converts a raw /v1/listen 200-response body into a Result.
//
// Mapping decisions (docs/39 D6):
//   - punctuated_word preferred over word (punctuate+smart_format are
//     always requested), so transcripts keep casing + punctuation.
//   - speaker is 0-based from Deepgram → SpeakerLabel "1"/"2"/…
//     matching Chirp's 1-based numeric-string convention. A missing
//     speaker field leaves SpeakerLabel "" (downstream treats it as an
//     unlabeled word; with Deepgram this is rare, unlike Chirp's
//     systematic sparse labels).
//   - implausible offsets are dropped, same guard as ParseChirp3Results.
func Parse(raw []byte) (*Result, error) {
	var r response
	if err := json.Unmarshal(raw, &r); err != nil {
		return nil, fmt.Errorf("deepgram parse: %w", err)
	}
	if len(r.Results.Channels) == 0 || len(r.Results.Channels[0].Alternatives) == 0 {
		return nil, fmt.Errorf("deepgram parse: response has no channels/alternatives")
	}

	res := &Result{
		RequestID:        r.Metadata.RequestID,
		AudioDurationSec: r.Metadata.Duration,
	}
	ch := r.Results.Channels[0]
	res.LanguageCode = ch.DetectedLanguage

	alt := ch.Alternatives[0]
	res.ConfidenceAvg = float32(alt.Confidence)

	speakerSet := map[string]bool{}
	dropped := 0
	for _, w := range alt.Words {
		startMS := int64(w.Start * 1000)
		endMS := int64(w.End * 1000)
		if startMS < 0 || endMS < startMS || startMS > maxPlausibleWordOffsetMS || endMS > maxPlausibleWordOffsetMS {
			dropped++
			continue
		}
		text := w.PunctuatedWord
		if text == "" {
			text = w.Word
		}
		word := chunker.Word{
			Text:       text,
			StartMS:    startMS,
			EndMS:      endMS,
			Confidence: float32(w.Confidence),
		}
		if w.Speaker != nil {
			label := strconv.Itoa(*w.Speaker + 1)
			word.SpeakerLabel = label
			speakerSet[label] = true
		}
		res.Words = append(res.Words, word)
	}

	res.WordCount = len(res.Words)
	res.SpeakerCount = len(speakerSet)
	if dropped > 0 {
		// Rare; surfaced to the caller for logging without failing the
		// transcript (mirrors the Chirp-side slog.Warn behavior — the
		// caller logs since this package stays log-free).
		res.droppedWords = dropped
	}
	return res, nil
}

// DroppedWords returns how many words were discarded for implausible
// timestamps. Non-zero is worth a warning log at the call site.
func (r *Result) DroppedWords() int { return r.droppedWords }
