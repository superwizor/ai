// Package pubsub — outbound event publisher dla billing-svc.
//
// Eventy są publikowane przez outbox poller (internal/outbox/poller.go),
// nie bezpośrednio przez gRPC handlery. To zapewnia transactional spójność
// (ADR-DM-009): commit DB i publish do Pub/Sub są rozdzielone w czasie,
// ale obie operacje są at-least-once z idempotency po stronie konsumenta.
package pubsub

import (
	"context"
	"fmt"

	"cloud.google.com/go/pubsub/v2"
)

const (
	// TopicBillingOutbox — wszystkie eventy billingowe (quota.*, subscription.*)
	// idą na jeden topic; konsumenci filtrują po Attribute "event_type".
	TopicBillingOutbox = "billing.outbox"
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

func (p *Publisher) Close() error {
	return p.client.Close()
}

// PublishOutboxEvent — emituje payload na topic billing.outbox.
// Atrybuty wiadomości zawierają routing metadata (event_type, organization_id,
// aggregate_type) żeby konsumenci mogli filtrować bez deserializacji payloadu.
//
// idempotencyKey jest wstawiany jako atrybut żeby konsument (notification-svc)
// mógł deduplikować na poziomie message ID + key zamiast (lub w dodatku do)
// własnej tabeli idempotencyjnej.
func (p *Publisher) PublishOutboxEvent(
	ctx context.Context,
	eventType string,
	aggregateType string,
	organizationID string,
	idempotencyKey string,
	payload []byte,
) error {
	topic := p.client.Publisher(TopicBillingOutbox)
	defer topic.Stop()

	res := topic.Publish(ctx, &pubsub.Message{
		Data: payload,
		Attributes: map[string]string{
			"event_type":      eventType,
			"aggregate_type":  aggregateType,
			"organization_id": organizationID,
			"idempotency_key": idempotencyKey,
		},
	})
	_, err := res.Get(ctx)
	return err
}
