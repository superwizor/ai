package pubsub

import (
	"context"
	"encoding/json"
	"fmt"

	"cloud.google.com/go/pubsub/v2"
)

type Publisher struct {
	client *pubsub.Client
}

func NewPublisher(ctx context.Context, projectID string) (*Publisher, error) {
	client, err := pubsub.NewClient(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("failed to create pubsub client: %v", err)
	}
	return &Publisher{client: client}, nil
}

func (p *Publisher) Close() error {
	if p.client != nil {
		return p.client.Close()
	}
	return nil
}

type TranscriptCompletedPayload struct {
	SessionID    string `json:"sessionId"`
	TranscriptID string `json:"transcriptId"`
}

func (p *Publisher) PublishTranscriptCompleted(ctx context.Context, sessionID, transcriptID string) error {
	topic := p.client.Publisher("transcript.completed")
	defer topic.Stop()

	payload := TranscriptCompletedPayload{
		SessionID:    sessionID,
		TranscriptID: transcriptID,
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal transcript completed payload: %v", err)
	}

	res := topic.Publish(ctx, &pubsub.Message{
		Data: data,
	})

	if _, err := res.Get(ctx); err != nil {
		return fmt.Errorf("failed to publish transcript.completed message: %v", err)
	}

	return nil
}

// NOTE: report.generated is retired (docs/21 Faza-4). llm-worker now
// publishes the terminal-success transition to session.status_changed
// ("done"); notification-worker-on-status owns the report-ready fan-out.
