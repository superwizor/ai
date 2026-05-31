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
	if _, err = res.Get(ctx); err != nil {
		return err
	}

	// docs/21 Faza-4 consolidation: also mirror "uploaded" via the
	// unified session.status_changed topic so notification-worker-on-status
	// is the single status-mirror consumer (notification-worker-on-uploaded
	// retired). audio.uploaded itself stays — it drives stt-worker. This
	// publish is best-effort: a failure doesn't unwind the audio.uploaded
	// that already drove the pipeline.
	if perr := p.publishSessionStatusChanged(ctx, sessionID, "uploaded"); perr != nil {
		return perr
	}
	return nil
}

// publishSessionStatusChanged mirrors a lifecycle status onto the unified
// session.status_changed topic (docs/21).
func (p *Publisher) publishSessionStatusChanged(ctx context.Context, sessionID, status string) error {
	data, err := json.Marshal(map[string]string{
		"session_id": sessionID,
		"status":     status,
	})
	if err != nil {
		return err
	}
	topic := p.client.Publisher("session.status_changed")
	defer topic.Stop()
	res := topic.Publish(ctx, &pubsub.Message{
		Data: data,
		Attributes: map[string]string{
			"event_type": "session.status_changed",
			"session_id": sessionID,
			"status":     status,
		},
	})
	_, err = res.Get(ctx)
	return err
}
