// Package email is notification-svc's transactional-email seam.
//
// Two implementations:
//   - ResendSender: production. Uses Resend's Go SDK (resend-go/v2).
//     Picks up RESEND_API_KEY from env (set by Cloud Run via Secret
//     Manager mount, see infra/environments/staging/main.tf).
//   - MockSender: no-op, in-memory capture for tests + local dev when
//     RESEND_API_KEY is unset. Logs at INFO so you can still verify
//     the call shape in a local run.
//
// Reference: docs/18 §14.7, R7 (D1=Resend).
package email

import (
	"context"
	"sync"

	"log/slog"

	"github.com/resend/resend-go/v2"
)

// Message is the rendered, ready-to-send email. The templater builds
// it from a request + locale-specific template.
type Message struct {
	To       string
	From     string // optional override; ResendSender falls back to a default address
	Subject  string
	HTMLBody string
	TextBody string // optional plain-text alternative
}

// Sender is the seam every email-producing handler depends on.
type Sender interface {
	Send(ctx context.Context, msg Message) error
}

// ResendSender is the production implementation.
type ResendSender struct {
	client      *resend.Client
	defaultFrom string
}

// NewResendSender builds a Sender backed by Resend. defaultFrom is
// the "From:" address used when Message.From is empty — typically
// something like "Superwizor <noreply@superwizor.ai>". apiKey is
// the Resend API key (validate before calling this).
func NewResendSender(apiKey, defaultFrom string) *ResendSender {
	return &ResendSender{
		client:      resend.NewClient(apiKey),
		defaultFrom: defaultFrom,
	}
}

func (s *ResendSender) Send(ctx context.Context, msg Message) error {
	from := msg.From
	if from == "" {
		from = s.defaultFrom
	}
	params := &resend.SendEmailRequest{
		From:    from,
		To:      []string{msg.To},
		Subject: msg.Subject,
		Html:    msg.HTMLBody,
		Text:    msg.TextBody,
	}
	_, err := s.client.Emails.SendWithContext(ctx, params)
	if err != nil {
		return err
	}
	return nil
}

// MockSender captures everything passed to Send. Used by tests and
// local dev runs (when RESEND_API_KEY is unset). Send always succeeds.
type MockSender struct {
	mu   sync.Mutex
	sent []Message
}

func NewMockSender() *MockSender { return &MockSender{} }

func (m *MockSender) Send(ctx context.Context, msg Message) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sent = append(m.sent, msg)
	slog.InfoContext(ctx, "email (mock sender)",
		"to", msg.To, "subject", msg.Subject, "from", msg.From,
	)
	return nil
}

// Sent returns a copy of every message captured so far (test helper).
func (m *MockSender) Sent() []Message {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]Message, len(m.sent))
	copy(out, m.sent)
	return out
}

// Reset clears the capture buffer (test helper).
func (m *MockSender) Reset() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sent = nil
}
