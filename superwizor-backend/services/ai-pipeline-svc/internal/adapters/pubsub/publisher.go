package pubsub

import (
	"context"
	"encoding/json"
	"fmt"

	"cloud.google.com/go/pubsub"
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

func (p *Publisher) Close() {
	if p.client != nil {
		p.client.Close()
	}
}

type TranscriptCompletedPayload struct {
	SessionID    string `json:"sessionId"`
	TranscriptID string `json:"transcriptId"`
}

func (p *Publisher) PublishTranscriptCompleted(ctx context.Context, sessionID, transcriptID string) error {
	topic := p.client.Topic("transcript.completed")
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

type ReportGeneratedPayload struct {
	SessionID string `json:"sessionId"`
	ReportID  string `json:"reportId"`
}

func (p *Publisher) PublishReportGenerated(ctx context.Context, sessionID, reportID string) error {
	topic := p.client.Topic("report.generated")
	defer topic.Stop()

	payload := ReportGeneratedPayload{
		SessionID: sessionID,
		ReportID:  reportID,
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal report generated payload: %v", err)
	}

	res := topic.Publish(ctx, &pubsub.Message{
		Data: data,
	})

	if _, err := res.Get(ctx); err != nil {
		return fmt.Errorf("failed to publish report.generated message: %v", err)
	}

	return nil
}
