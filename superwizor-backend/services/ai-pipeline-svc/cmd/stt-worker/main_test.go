package sttworker

import (
	"testing"
	"time"

	"cloud.google.com/go/speech/apiv2/speechpb"
	"github.com/stretchr/testify/assert"
	"google.golang.org/protobuf/types/known/durationpb"

	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
)

// TestParseChirp3Results — default flow (USE_NATIVE_DIARIZATION=false).
// Słowa są zwracane bez speaker_tag — LLM zrobi diarization (ADR-IMPL-007).
func TestParseChirp3Results(t *testing.T) {
	resp := &speechpb.BatchRecognizeResponse{
		Results: map[string]*speechpb.BatchRecognizeFileResult{
			"file1": {
				Result: &speechpb.BatchRecognizeFileResult_InlineResult{
					InlineResult: &speechpb.InlineResult{
						Transcript: &speechpb.BatchRecognizeResults{
							Results: []*speechpb.SpeechRecognitionResult{
								{
									Alternatives: []*speechpb.SpeechRecognitionAlternative{
										{
											Transcript: "Hello world. How are you?",
											Confidence: 0.9,
											Words: []*speechpb.WordInfo{
												{Word: "Hello", StartOffset: durationpb.New(100 * time.Millisecond), EndOffset: durationpb.New(500 * time.Millisecond)},
												{Word: "world.", StartOffset: durationpb.New(500 * time.Millisecond), EndOffset: durationpb.New(1000 * time.Millisecond)},
												{Word: "How", StartOffset: durationpb.New(1700 * time.Millisecond), EndOffset: durationpb.New(1800 * time.Millisecond)},
												{Word: "are", StartOffset: durationpb.New(1800 * time.Millisecond), EndOffset: durationpb.New(1900 * time.Millisecond)},
												{Word: "you?", StartOffset: durationpb.New(1900 * time.Millisecond), EndOffset: durationpb.New(2100 * time.Millisecond)},
											},
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}

	result := ParseChirp3Results(resp, false)

	assert.NotNil(t, result)
	assert.Equal(t, "pl-PL", result.LanguageCode)
	assert.Equal(t, 5, result.WordCount)
	assert.Equal(t, float32(0.9), result.ConfidenceAvg)
	assert.False(t, result.HasNativeDiarization)
	assert.Equal(t, 0, result.SpeakerCount)
	assert.Len(t, result.Words, 5)

	// Words → chunker robi grouping. Pauza 700ms (1000→1700) → split.
	chunks := chunker.ChunkByPauses(result.Words, chunker.DefaultConfig())
	assert.Len(t, chunks, 2)
	assert.Equal(t, "Hello world.", chunks[0].Text)
	assert.Equal(t, "How are you?", chunks[1].Text)
}

// TestParseChirp3Results_NativeDiarization — feature flag USE_NATIVE_DIARIZATION=true
// (przyszła ścieżka gdy polski będzie supported).
func TestParseChirp3Results_NativeDiarization(t *testing.T) {
	resp := &speechpb.BatchRecognizeResponse{
		Results: map[string]*speechpb.BatchRecognizeFileResult{
			"file1": {
				Result: &speechpb.BatchRecognizeFileResult_InlineResult{
					InlineResult: &speechpb.InlineResult{
						Transcript: &speechpb.BatchRecognizeResults{
							Results: []*speechpb.SpeechRecognitionResult{
								{
									Alternatives: []*speechpb.SpeechRecognitionAlternative{
										{
											Confidence: 0.9,
											Words: []*speechpb.WordInfo{
												{Word: "Hi", StartOffset: durationpb.New(0), EndOffset: durationpb.New(200 * time.Millisecond), SpeakerLabel: "speaker_1"},
												{Word: "Hello", StartOffset: durationpb.New(300 * time.Millisecond), EndOffset: durationpb.New(600 * time.Millisecond), SpeakerLabel: "speaker_2"},
											},
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}

	result := ParseChirp3Results(resp, true)

	assert.True(t, result.HasNativeDiarization)
	assert.Equal(t, 2, result.SpeakerCount)
}
