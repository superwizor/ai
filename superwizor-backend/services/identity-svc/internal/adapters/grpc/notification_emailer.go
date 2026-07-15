package grpc

import (
	"context"

	"log/slog"

	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
)

// NotificationServiceEmailer is the production InvitationEmailer that
// hands the email off to notification-svc.SendInvitationEmail via gRPC.
// Wired in cmd/server/main.go for staging/prod; tests / local dev
// stay on NoopEmailSender so they don't need a notification-svc gRPC
// dial.
type NotificationServiceEmailer struct {
	client notificationv1.NotificationServiceClient
}

func NewNotificationServiceEmailer(client notificationv1.NotificationServiceClient) NotificationServiceEmailer {
	return NotificationServiceEmailer{client: client}
}

func (e NotificationServiceEmailer) SendInvitation(ctx context.Context, p InvitationEmailParams) error {
	_, err := e.client.SendInvitationEmail(ctx, &notificationv1.SendInvitationEmailRequest{
		RecipientEmail:   p.Recipient,
		OrganizationName: p.OrgName,
		InviterFirstName: p.InviterFirstName,
		AcceptUrl:        p.AcceptURL,
		ExpiresAtIso:     p.ExpiresAt,
		Locale:           p.Locale,
		InvitedRole:      p.InvitedRole,
	})
	if err != nil {
		slog.WarnContext(ctx, "notification-svc.SendInvitationEmail failed",
			"recipient", p.Recipient, "error", err)
		return err
	}
	return nil
}

func (e NotificationServiceEmailer) SendVerification(ctx context.Context, p VerificationEmailParams) error {
	_, err := e.client.SendEmailVerification(ctx, &notificationv1.SendEmailVerificationRequest{
		RecipientEmail: p.Recipient,
		FirstName:      p.FirstName,
		VerifyUrl:      p.VerifyURL,
		Locale:         p.Locale,
	})
	if err != nil {
		slog.WarnContext(ctx, "notification-svc.SendEmailVerification failed",
			"recipient", p.Recipient, "error", err)
		return err
	}
	return nil
}
