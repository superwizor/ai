package sttworker

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/superwizor-ai/backend/pkg/pubsubx"
)

type mockPublisher struct {
	PublishedMessages []pubsubx.Message
}

func (m *mockPublisher) Publish(ctx context.Context, topicID string, msg pubsubx.Message) (string, error) {
	m.PublishedMessages = append(m.PublishedMessages, msg)
	return "msg-id", nil
}

func (m *mockPublisher) Close() error { return nil }

func TestPublishTranscriptCompletedEvent(t *testing.T) {
	mockPub := &mockPublisher{}
	
	// Create mock event data
	sessID := uuid.New()
	transcriptID := uuid.New()
	processingTime := 5 * time.Second
	
	result := &TranscriptResult{
		LanguageCode:  "pl-PL",
		SpeakerCount:  2,
		ConfidenceAvg: 0.95,
		WordCount:     150,
	}
	
	// Call function to test (assume it takes pubsub interface)
	err := publishTranscriptCompletedEvent(context.Background(), mockPub, "transcript.completed", sessID.String(), transcriptID.String(), result, processingTime)
	
	assert.NoError(t, err)
	assert.Len(t, mockPub.PublishedMessages, 1)
	
	msg := mockPub.PublishedMessages[0]
	assert.Equal(t, "transcript.completed", msg.Attributes["eventType"])
	assert.Equal(t, sessID.String(), msg.Attributes["sessionId"])
	
	var payload TranscriptCompletedPayload
	err = json.Unmarshal(msg.Data, &payload)
	assert.NoError(t, err)
	
	assert.Equal(t, sessID.String(), payload.SessionID)
	assert.Equal(t, transcriptID.String(), payload.TranscriptID)
	assert.Equal(t, "pl-PL", payload.LanguageCode)
	assert.Equal(t, 2, payload.SpeakerCount)
	assert.Equal(t, float32(0.95), payload.ConfidenceAvg)
	assert.Equal(t, 150, payload.WordCount)
	assert.Equal(t, 5, payload.ProcessingTimeSeconds)
}
