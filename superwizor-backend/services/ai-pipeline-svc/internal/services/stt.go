package services

import (
	"context"
	"fmt"
	"log"
	speech "cloud.google.com/go/speech/apiv2"
	"cloud.google.com/go/speech/apiv2/speechpb"
)

type STTService struct {
	client    *speech.Client
	projectID string
}

func NewSTTService(ctx context.Context, projectID string) (*STTService, error) {
	client, err := speech.NewClient(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to create speech client: %v", err)
	}
	return &STTService{
		client:    client,
		projectID: projectID,
	}, nil
}

func (s *STTService) TranscribeAudio(ctx context.Context, gcsURI string) (string, error) {
	log.Printf("Starting transcription for %s", gcsURI)
	
	// Default to europe-west4 for Chirp / Gemini usage as per ADR
	location := "europe-west4"
	
	req := &speechpb.RecognizeRequest{
		Recognizer: fmt.Sprintf("projects/%s/locations/%s/recognizers/_", s.projectID, location),
		Config: &speechpb.RecognitionConfig{
			Model: "chirp", // Using Chirp model for STT
			LanguageCodes: []string{"pl-PL"},
			Features: &speechpb.RecognitionFeatures{
				EnableWordTimeOffsets: true,
				EnableAutomaticPunctuation: true,
				DiarizationConfig: &speechpb.SpeakerDiarizationConfig{
					MinSpeakerCount: 2,
					MaxSpeakerCount: 6,
				},
			},
		},
		AudioSource: &speechpb.RecognizeRequest_Uri{
			Uri: gcsURI,
		},
	}

	resp, err := s.client.Recognize(ctx, req)
	if err != nil {
		return "", fmt.Errorf("recognize error: %v", err)
	}

	// Just a simple concatenation for the prototype
	var fullTranscript string
	for _, result := range resp.Results {
		if len(result.Alternatives) > 0 {
			fullTranscript += result.Alternatives[0].Transcript + " "
		}
	}

	return fullTranscript, nil
}
