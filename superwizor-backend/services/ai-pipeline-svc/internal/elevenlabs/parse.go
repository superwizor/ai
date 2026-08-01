package elevenlabs

import (
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"strings"

	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
)

// Result is the provider-neutral transcript produced from a Scribe
// response. Word timings are in milliseconds and speaker labels are
// 1-based numeric strings ("1", "2", …) — the exact shape
// ParseChirp3Results and the Deepgram parser emit, so everything
// downstream of stt-worker (chunker, persistTranscript, llm-worker
// role-only branch) is untouched (docs/59 D5/D6).
type Result struct {
	Words         []chunker.Word
	RequestID     string
	LanguageCode  string  // ISO-639-3 as returned ("pol"); caller BCP47izes
	LanguageProb  float32 // low value ⇒ session language disagrees with audio
	WordCount     int
	SpeakerCount  int
	ConfidenceAvg float32

	// AudioDurationSec is ElevenLabs' measured input duration. Unlike the
	// Deepgram path this is not merely a cross-check against
	// sessions.duration_seconds — it is the denominator of the coverage
	// guard (coverage.go), the invariant that would have caught nova-3.
	AudioDurationSec float64

	droppedWords int
}

// maxPlausibleWordOffsetMS mirrors the identical guard in
// stt-worker.ParseChirp3Results: a word offset beyond 24 h is garbage
// and would overflow the int4 transcript_segments column.
const maxPlausibleWordOffsetMS = 24 * 60 * 60 * 1000

// response mirrors the subset of POST /v1/speech-to-text we consume.
//
// words[] mixes three kinds of entries distinguished by Type:
// "word", "spacing" (bare whitespace) and "audio_event" (laughter and
// similar, when tag_audio_events is on). A 26-minute recording carried
// 3256 words alongside 3252 spacing entries, so failing to filter would
// roughly double every count and inject empty tokens into the
// transcript. TestParse_IgnoresNonWordEntries pins this.
type response struct {
	LanguageCode      string  `json:"language_code"`
	LanguageProb      float64 `json:"language_probability"`
	Text              string  `json:"text"`
	TranscriptionID   string  `json:"transcription_id"`
	AudioDurationSecs float64 `json:"audio_duration_secs"`
	Words             []struct {
		Text      string  `json:"text"`
		Start     float64 `json:"start"`
		End       float64 `json:"end"`
		Type      string  `json:"type"`
		SpeakerID string  `json:"speaker_id"`
		LogProb   float64 `json:"logprob"`
	} `json:"words"`
}

// speakerLabel maps ElevenLabs' "speaker_0", "speaker_1", … onto the
// 1-based numeric strings the rest of the pipeline expects. An
// unrecognised shape yields "" so the word stays unlabeled rather than
// being attributed to the wrong person — a mislabeled speaker in a
// therapy transcript is worse than an unlabeled one.
func speakerLabel(id string) string {
	if id == "" {
		return ""
	}
	n, err := strconv.Atoi(strings.TrimPrefix(id, "speaker_"))
	if err != nil || n < 0 {
		return ""
	}
	return strconv.Itoa(n + 1)
}

// Parse converts a raw 200-response body into a Result.
//
// Mapping decisions (docs/59 D6):
//   - only entries with type=="word" become transcript words;
//   - start/end are seconds float → ms;
//   - speaker_id "speaker_N" → SpeakerLabel "N+1";
//   - logprob is a log-probability in (-inf, 0]; exp() would be the
//     linear confidence, but downstream only ever compares and averages
//     these, so we keep the raw value's ordering and clamp to [0,1] via
//     exp to stay compatible with the float32 Confidence field that the
//     Chirp and Deepgram paths populate with linear confidences;
//   - implausible offsets are dropped, same guard as ParseChirp3Results.
func Parse(raw []byte) (*Result, error) {
	var r response
	if err := json.Unmarshal(raw, &r); err != nil {
		return nil, fmt.Errorf("elevenlabs parse: %w", err)
	}
	// A response with no words[] key at all is a shape we do not
	// understand; an empty-but-present array is a legitimate "silence"
	// answer and is left to the coverage guard to judge.
	if r.Words == nil {
		return nil, fmt.Errorf("elevenlabs parse: response has no words array")
	}

	res := &Result{
		RequestID:        r.TranscriptionID,
		LanguageCode:     r.LanguageCode,
		LanguageProb:     float32(r.LanguageProb),
		AudioDurationSec: r.AudioDurationSecs,
	}

	speakerSet := map[string]bool{}
	var confSum float64
	dropped := 0
	for _, w := range r.Words {
		if w.Type != "word" {
			continue
		}
		startMS := int64(w.Start * 1000)
		endMS := int64(w.End * 1000)
		if startMS < 0 || endMS < startMS || startMS > maxPlausibleWordOffsetMS || endMS > maxPlausibleWordOffsetMS {
			dropped++
			continue
		}
		conf := linearConfidence(w.LogProb)
		word := chunker.Word{
			Text:       w.Text,
			StartMS:    startMS,
			EndMS:      endMS,
			Confidence: float32(conf),
		}
		if label := speakerLabel(w.SpeakerID); label != "" {
			word.SpeakerLabel = label
			speakerSet[label] = true
		}
		confSum += conf
		res.Words = append(res.Words, word)
	}

	res.WordCount = len(res.Words)
	res.SpeakerCount = len(speakerSet)
	if res.WordCount > 0 {
		res.ConfidenceAvg = float32(confSum / float64(res.WordCount))
	}
	res.droppedWords = dropped
	return res, nil
}

// linearConfidence turns a log-probability into the [0,1] confidence the
// rest of the pipeline stores. Guards the degenerate inputs (positive or
// absurdly negative logprobs) so a provider quirk cannot produce a
// confidence outside the range persistTranscript expects.
func linearConfidence(logprob float64) float64 {
	switch {
	case logprob >= 0:
		return 1
	case logprob < -80: // exp underflows to 0 well before this
		return 0
	default:
		return math.Exp(logprob)
	}
}

// DroppedWords returns how many words were discarded for implausible
// timestamps. Non-zero is worth a warning log at the call site.
func (r *Result) DroppedWords() int { return r.droppedWords }
