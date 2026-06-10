package grpc

import (
	"context"
	"fmt"
	"strings"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
	"github.com/superwizor-ai/backend/services/notification-svc/internal/email"
)

// SendContactEmail is the internal RPC called by billing-svc to route contact form submissions.
func (s *Server) SendContactEmail(ctx context.Context, req *notificationv1.SendContactEmailRequest) (*emptypb.Empty, error) {
	if strings.TrimSpace(req.GetName()) == "" {
		return nil, status.Error(codes.InvalidArgument, "name required")
	}
	if strings.TrimSpace(req.GetEmail()) == "" {
		return nil, status.Error(codes.InvalidArgument, "email required")
	}
	if strings.TrimSpace(req.GetMessage()) == "" {
		return nil, status.Error(codes.InvalidArgument, "message required")
	}

	subject := fmt.Sprintf("[Kontakt] %s", req.GetSubject())
	if strings.TrimSpace(req.GetSubject()) == "" {
		subject = fmt.Sprintf("[Kontakt] Wiadomość od %s", req.GetName())
	}

	textBody := fmt.Sprintf(
		"Nowa wiadomość z formularza kontaktowego:\n\n"+
			"Nadawca: %s\n"+
			"E-mail: %s\n"+
			"Temat: %s\n\n"+
			"Treść wiadomości:\n%s\n",
		req.GetName(),
		req.GetEmail(),
		req.GetSubject(),
		req.GetMessage(),
	)

	htmlBody := fmt.Sprintf(
		"<html><body style=\"font-family:system-ui,sans-serif;color:#1B2522;line-height:1.5;\">"+
			"<h2>Nowa wiadomość z formularza kontaktowego</h2>"+
			"<p><strong>Nadawca:</strong> %s</p>"+
			"<p><strong>E-mail:</strong> <a href=\"mailto:%s\">%s</a></p>"+
			"<p><strong>Temat:</strong> %s</p>"+
			"<hr style=\"border:none;border-top:1px solid #E2E8F0;margin:20px 0;\" />"+
			"<p><strong>Treść wiadomości:</strong></p>"+
			"<p style=\"white-space:pre-wrap;background-color:#F7FAFC;padding:15px;border-radius:6px;border:1px solid #E2E8F0;\">%s</p>"+
			"</body></html>",
		htmlEscape(req.GetName()),
		htmlEscape(req.GetEmail()),
		htmlEscape(req.GetEmail()),
		htmlEscape(req.GetSubject()),
		htmlEscape(req.GetMessage()),
	)

	err := s.emailer.Send(ctx, email.Message{
		To:       "kontakt@superwizor.ai",
		Subject:  subject,
		HTMLBody: htmlBody,
		TextBody: textBody,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to send contact email: %v", err)
	}

	return &emptypb.Empty{}, nil
}

// htmlEscape escapes standard HTML special characters.
func htmlEscape(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	s = strings.ReplaceAll(s, "\"", "&quot;")
	s = strings.ReplaceAll(s, "'", "&#39;")
	return s
}
