package grpc

import (
	"context"
	"log/slog"
)

// InvitationEmailer is the minimal seam between identity-svc and the
// real Resend-backed email path that lands in commit 7. Until then,
// the default implementation is a NoopEmailSender that logs at INFO
// — enough to manually click-through invite flows in staging.
//
// In production this is wired (commit 7) to a gRPC client of
// notification-svc.SendInvitationEmail.
type InvitationEmailer interface {
	SendInvitation(ctx context.Context, params InvitationEmailParams) error
}

// InvitationEmailParams captures everything the invitation template
// (services/notification-svc/internal/i18n/templates/{locale}/invitation.md)
// needs to render. Field names mirror the template variables.
type InvitationEmailParams struct {
	Recipient        string // email
	OrgName          string
	InviterFirstName string
	AcceptURL        string // includes the cleartext token
	ExpiresAt        string // ISO-8601 in the recipient's locale; renderer formats
	Locale           string // pl | en
}

// NoopEmailSender logs but does nothing. It's the default until the
// Resend path lands (commit 7). Returning nil error keeps the
// InviteTherapist RPC happy without any transactional rollback.
type NoopEmailSender struct{}

func (NoopEmailSender) SendInvitation(ctx context.Context, params InvitationEmailParams) error {
	slog.InfoContext(ctx, "invitation email (noop sender)",
		"recipient", params.Recipient,
		"org", params.OrgName,
		"accept_url", params.AcceptURL,
		"locale", params.Locale,
		"expires_at", params.ExpiresAt,
	)
	return nil
}
