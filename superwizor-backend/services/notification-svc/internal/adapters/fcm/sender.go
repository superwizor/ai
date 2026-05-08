// Package fcm wraps the Firebase Admin SDK Messaging client. The worker
// uses this to send multicast pushes to all of a therapist's active devices
// (iPhone + iPad + Android — see ADR-IMPL-011).
//
// The payload deliberately contains NO PHI (ADR-IMPL-013). Only:
//   - generic localized title + body ("Raport gotowy" / "Report ready")
//   - opaque session_id + notification_type in data dict
// Flutter, on tap, opens the session screen and decrypts via clinical-svc.
package fcm

import (
	"context"
	"errors"
	"fmt"

	fbmessaging "firebase.google.com/go/v4/messaging"
)

type Sender struct {
	client *fbmessaging.Client
}

func NewSender(client *fbmessaging.Client) *Sender {
	return &Sender{client: client}
}

type Push struct {
	Tokens           []string
	Title            string
	Body             string
	SessionID        string
	NotificationType string // "report_ready" | "session_uploaded" | ...
}

// PerTokenResult mirrors fbmessaging.SendResponse one-to-one. We surface it
// in our own type so callers don't have to import the Firebase package
// directly to inspect results.
type PerTokenResult struct {
	Success         bool
	MessageID       string
	Err             error
	TokenInvalidated bool // true when Err is a NotRegistered / Unregistered / InvalidArgument
}

// Send issues one multicast call. If the underlying Firebase client is nil
// (test/dev env), Send returns a synthetic all-success response so the
// worker can still exercise its happy path without real FCM credentials.
//
// We intentionally use SendEachForMulticast over the deprecated
// SendMulticast — SendEach issues one HTTP call per token (slightly higher
// latency, but no batching limits, easier debugging from server-side
// telemetry, and the path that Firebase actively maintains).
func (s *Sender) Send(ctx context.Context, p Push) ([]PerTokenResult, error) {
	if len(p.Tokens) == 0 {
		return nil, nil
	}
	if s == nil || s.client == nil {
		// Mock mode for local/dev runs without Firebase Admin credentials.
		out := make([]PerTokenResult, len(p.Tokens))
		for i := range out {
			out[i] = PerTokenResult{Success: true, MessageID: "mock-no-fcm"}
		}
		return out, nil
	}

	msg := &fbmessaging.MulticastMessage{
		Tokens: p.Tokens,
		Notification: &fbmessaging.Notification{
			Title: p.Title,
			Body:  p.Body,
		},
		Data: map[string]string{
			"session_id":        p.SessionID,
			"notification_type": p.NotificationType,
		},
		// APNS sound + badge for iOS foreground/background presentation.
		APNS: &fbmessaging.APNSConfig{
			Payload: &fbmessaging.APNSPayload{
				Aps: &fbmessaging.Aps{Sound: "default"},
			},
		},
		// Android "high" priority so devices in Doze mode wake up.
		Android: &fbmessaging.AndroidConfig{
			Priority: "high",
		},
	}

	batch, err := s.client.SendEachForMulticast(ctx, msg)
	if err != nil {
		return nil, fmt.Errorf("fcm SendEachForMulticast: %w", err)
	}

	out := make([]PerTokenResult, len(batch.Responses))
	for i, r := range batch.Responses {
		out[i] = PerTokenResult{
			Success:          r.Success,
			MessageID:        r.MessageID,
			Err:              r.Error,
			TokenInvalidated: r.Error != nil && isTokenInvalid(r.Error),
		}
	}
	return out, nil
}

// isTokenInvalid centralises the "should we invalidate this token?"
// decision. NotRegistered (app uninstalled) and Unregistered are the
// canonical signals; InvalidArgument also typically means the token string
// is malformed and won't ever work again.
func isTokenInvalid(err error) bool {
	if err == nil {
		return false
	}
	if fbmessaging.IsRegistrationTokenNotRegistered(err) {
		return true
	}
	if fbmessaging.IsUnregistered(err) {
		return true
	}
	if fbmessaging.IsInvalidArgument(err) {
		return true
	}
	// Defensive: keep room to extend without a recompile cascade.
	return errors.Is(err, errSentinelTokenInvalid)
}

var errSentinelTokenInvalid = errors.New("fcm: sentinel token-invalid (unused)")
