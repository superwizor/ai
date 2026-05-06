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
		return nil, fmt.Errorf("pubsub client: %w", err)
	}
	return &Publisher{client: client}, nil
}

type AudioUploadedEvent struct {
	SessionID  string `json:"session_id"`
	UploadID   string `json:"upload_id"`
	ObjectPath string `json:"object_path"`
}

func (p *Publisher) PublishAudioUploaded(ctx context.Context, sessionID, uploadID, objectPath string) error {
	payload := AudioUploadedEvent{
		SessionID:  sessionID,
		UploadID:   uploadID,
		ObjectPath: objectPath,
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	topic := p.client.Publisher("audio.uploaded")
	defer topic.Stop()

	res := topic.Publish(ctx, &pubsub.Message{
		Data: data,
		Attributes: map[string]string{
			"event_type": "audio.uploaded",
			"session_id": sessionID,
		},
	})
	_, err = res.Get(ctx)
	return err
}
