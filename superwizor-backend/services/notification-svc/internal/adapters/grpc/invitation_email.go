package grpc

import (
	"context"
	"strings"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
	"github.com/superwizor-ai/backend/services/notification-svc/internal/email"
	"github.com/superwizor-ai/backend/services/notification-svc/internal/i18n"
)

// SendInvitationEmail is the internal RPC identity-svc calls from
// InviteTherapist. NOT exposed to client traffic — the gRPC auth
// pattern for service-to-service inside the project relies on Cloud
// Run IAM (no Firebase ID token needed; the caller's SA owns the
// invoker binding on notification-svc).
//
// docs/18 §6.5, §14.7.
func (s *Server) SendInvitationEmail(ctx context.Context, req *notificationv1.SendInvitationEmailRequest) (*emptypb.Empty, error) {
	if strings.TrimSpace(req.GetRecipientEmail()) == "" {
		return nil, status.Error(codes.InvalidArgument, "recipient_email required")
	}
	if strings.TrimSpace(req.GetAcceptUrl()) == "" {
		return nil, status.Error(codes.InvalidArgument, "accept_url required")
	}
	if strings.TrimSpace(req.GetOrganizationName()) == "" {
		return nil, status.Error(codes.InvalidArgument, "organization_name required")
	}

	tpl, err := i18n.Load(req.GetLocale(), "invitation")
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load template: %v", err)
	}
	subject, body := tpl.Render(map[string]string{
		"recipient_email":     req.GetRecipientEmail(),
		"organization_name":   req.GetOrganizationName(),
		"inviter_first_name":  inviterOrDefault(req.GetInviterFirstName()),
		"accept_url":          req.GetAcceptUrl(),
		"expires_at":          req.GetExpiresAtIso(),
	})

	if err := s.emailer.Send(ctx, email.Message{
		To:       req.GetRecipientEmail(),
		Subject:  subject,
		HTMLBody: bodyToHTML(body),
		TextBody: body,
		From:     tpl.From,
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "send email: %v", err)
	}
	return &emptypb.Empty{}, nil
}

func inviterOrDefault(s string) string {
	if strings.TrimSpace(s) == "" {
		return "Twój kolega" // PL fallback; EN template's user fills it in
	}
	return s
}

// bodyToHTML is the minimum-viable Markdown-ish conversion the
// invitation templates need: paragraphs separated by blank lines,
// **bold**, and bare URLs become <a> tags. We deliberately don't
// pull in a full Markdown renderer for a one-shot template.
func bodyToHTML(body string) string {
	// Split on double newline to detect paragraphs.
	paras := strings.Split(strings.TrimSpace(body), "\n\n")
	var sb strings.Builder
	sb.WriteString("<html><body style=\"font-family:system-ui,sans-serif;\">")
	for _, p := range paras {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		// **bold** → <strong>
		for {
			start := strings.Index(p, "**")
			if start < 0 {
				break
			}
			end := strings.Index(p[start+2:], "**")
			if end < 0 {
				break
			}
			p = p[:start] + "<strong>" + p[start+2:start+2+end] + "</strong>" + p[start+2+end+2:]
		}
		// Bare https?:// URLs → <a>
		// (one URL per paragraph max; the templates we own don't violate this.)
		if idx := strings.Index(p, "https://"); idx >= 0 {
			end := strings.IndexAny(p[idx:], " \n\t")
			if end < 0 {
				end = len(p) - idx
			}
			url := p[idx : idx+end]
			p = p[:idx] + `<a href="` + url + `">` + url + `</a>` + p[idx+end:]
		}
		// Newlines inside a paragraph → <br>
		p = strings.ReplaceAll(p, "\n", "<br>")
		sb.WriteString("<p>")
		sb.WriteString(p)
		sb.WriteString("</p>")
	}
	sb.WriteString("</body></html>")
	return sb.String()
}
