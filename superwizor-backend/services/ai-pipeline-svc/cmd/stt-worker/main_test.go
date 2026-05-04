package sttworker

import (
	"testing"
	"time"

	"cloud.google.com/go/speech/apiv2/speechpb"
	"github.com/stretchr/testify/assert"
	"google.golang.org/protobuf/types/known/durationpb"
)

func TestParseChirp3Results(t *testing.T) {
	// Mock the response from Chirp 3
	resp := &speechpb.BatchRecognizeResponse{
		Results: map[string]*speechpb.BatchRecognizeFileResult{
			"file1": {
				Transcript: &speechpb.BatchRecognizeResults{
					Results: []*speechpb.SpeechRecognitionResult{
						{
							Alternatives: []*speechpb.SpeechRecognitionAlternative{
								{
									Transcript: "Hello world. How are you?",
									Confidence: 0.9,
									Words: []*speechpb.WordInfo{
										{
											Word:         "Hello",
											StartOffset:  durationpb.New(100 * time.Millisecond),
											EndOffset:    durationpb.New(500 * time.Millisecond),
											SpeakerLabel: "speaker_1",
										},
										{
											Word:         "world.",
											StartOffset:  durationpb.New(500 * time.Millisecond),
											EndOffset:    durationpb.New(1000 * time.Millisecond),
											SpeakerLabel: "speaker_1",
										},
										{
											Word:         "How",
											StartOffset:  durationpb.New(1100 * time.Millisecond),
											EndOffset:    durationpb.New(1200 * time.Millisecond),
											SpeakerLabel: "speaker_2",
										},
										{
											Word:         "are",
											StartOffset:  durationpb.New(1200 * time.Millisecond),
											EndOffset:    durationpb.New(1300 * time.Millisecond),
											SpeakerLabel: "speaker_2",
										},
										{
											Word:         "you?",
											StartOffset:  durationpb.New(1300 * time.Millisecond),
											EndOffset:    durationpb.New(1500 * time.Millisecond),
											SpeakerLabel: "speaker_2",
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

	result := ParseChirp3Results(resp)

	assert.NotNil(t, result)
	assert.Equal(t, "pl-PL", result.LanguageCode)
	assert.Equal(t, 2, result.SpeakerCount)
	assert.Equal(t, float32(0.9), result.ConfidenceAvg)
	assert.Equal(t, 5, result.WordCount)
	assert.Len(t, result.Segments, 2)

	// Verify segment 1 (Speaker 1)
	assert.Equal(t, int32(1), result.Segments[0].SpeakerTag)
	assert.Equal(t, "Hello world. ", result.Segments[0].Text)
	assert.Equal(t, int64(100), result.Segments[0].StartOffsetMS)
	assert.Equal(t, int64(1000), result.Segments[0].EndOffsetMS)
	assert.Equal(t, 2, result.Segments[0].WordCount)

	// Verify segment 2 (Speaker 2)
	assert.Equal(t, int32(2), result.Segments[1].SpeakerTag)
	assert.Equal(t, "How are you? ", result.Segments[1].Text)
	assert.Equal(t, int64(1100), result.Segments[1].StartOffsetMS)
	assert.Equal(t, int64(1500), result.Segments[1].EndOffsetMS)
	assert.Equal(t, 3, result.Segments[1].WordCount)
}

func TestParseSpeakerLabel(t *testing.T) {
	assert.Equal(t, int32(1), parseSpeakerLabel("speaker_1"))
	assert.Equal(t, int32(2), parseSpeakerLabel("speaker_2"))
	assert.Equal(t, int32(42), parseSpeakerLabel("speaker_42"))
}

func TestGenerateSpeakerLabels(t *testing.T) {
	segments := []TranscriptSegment{
		{SpeakerTag: 1},
		{SpeakerTag: 2},
		{SpeakerTag: 1},
	}
	
	// Test pl-PL
	labelsPL := generateSpeakerLabels(segments, "pl-PL")
	assert.Equal(t, "Osoba 1", labelsPL[1])
	assert.Equal(t, "Osoba 2", labelsPL[2])
	
	// Test en-US
	labelsEN := generateSpeakerLabels(segments, "en-US")
	assert.Equal(t, "Person 1", labelsEN[1])
	assert.Equal(t, "Person 2", labelsEN[2])
	
	// Test unknown
	labelsUnknown := generateSpeakerLabels(segments, "xx-XX")
	assert.Equal(t, "Speaker 1", labelsUnknown[1])
	assert.Equal(t, "Speaker 2", labelsUnknown[2])
}
