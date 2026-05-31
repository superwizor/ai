// Package pubsub is clinical-svc's outbound event publisher.
//
// Currently emits one event: session.deleted — fired from
// DeleteSession and (per-session) from DeletePatientFile so
// downstream consumers (notification-svc) can wipe the Firestore
// session_states mirror + per-user inbox notifications.
//
// Mirrors the shape of services/ingestion-svc/internal/adapters/pubsub
// for consistency. Kept a separate package per service so each owns
// its event schema and topic name.

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

// SessionDeletedEvent is the payload published on the session.deleted
// topic. notification-svc-on-deleted consumes it. Keep this struct in
// sync with the consumer's expected schema (currently 1:1; if you add
// fields, default them to optional or version the topic).
type SessionDeletedEvent struct {
	SessionID   string `json:"session_id"`
	TherapistID string `json:"therapist_id"`
}

// PublishSessionDeleted fires a single session.deleted message.
// Blocks until the broker acks; the call site in clinical-svc treats
// any error as best-effort (logs but doesn't fail the gRPC call).
//
// We attach event_type + session_id as message attributes so
// subscribers can filter / inspect at the Pub/Sub layer without
// decoding the JSON payload — matches the convention used by
// ingestion-svc.PublishAudioUploaded.
func (p *Publisher) PublishSessionDeleted(ctx context.Context, sessionID, therapistID string) error {
	payload := SessionDeletedEvent{
		SessionID:   sessionID,
		TherapistID: therapistID,
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	topic := p.client.Publisher("session.deleted")
	defer topic.Stop()

	res := topic.Publish(ctx, &pubsub.Message{
		Data: data,
		Attributes: map[string]string{
			"event_type": "session.deleted",
			"session_id": sessionID,
		},
	})
	_, err = res.Get(ctx)
	return err
}

// PublishSessionStatusChanged mirrors a lifecycle status to the
// session.status_changed topic (docs/21). clinical-svc uses it for
// "cancelled" (CancelSession) so the Firestore session_states doc
// reflects a user-initiated cancellation. [status] is the Firestore
// vocabulary ("cancelled"), not the PG enum. Best-effort — the call
// site logs but does not fail the gRPC call on error.
func (p *Publisher) PublishSessionStatusChanged(ctx context.Context, sessionID, status string) error {
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
