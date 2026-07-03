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

// SendClientPanelEvent delivers the PHI-free client-panel signals
// (docs/39 PR9). Internal RPC — clinical-svc calls it best-effort from
// the share toggles (ITEM_SHARED → client) and ClientCreateNote
// (CLIENT_NOTE_RECEIVED → therapist). The templates carry no names, no
// titles, no content: D6 makes the panel the content channel and the
// e-mail only the signal, so nothing here needs a consent-grade PHI
// review.
func (s *Server) SendClientPanelEvent(ctx context.Context, req *notificationv1.SendClientPanelEventRequest) (*emptypb.Empty, error) {
	if strings.TrimSpace(req.GetRecipientEmail()) == "" {
		return nil, status.Error(codes.InvalidArgument, "recipient_email required")
	}
	if strings.TrimSpace(req.GetPanelUrl()) == "" {
		return nil, status.Error(codes.InvalidArgument, "panel_url required")
	}

	var templateKey string
	switch req.GetEvent() {
	case "ITEM_SHARED":
		templateKey = "client_panel_new_item"
	case "CLIENT_NOTE_RECEIVED":
		templateKey = "client_note_received"
	default:
		return nil, status.Errorf(codes.InvalidArgument, "unknown event %q", req.GetEvent())
	}

	tpl, err := i18n.Load(req.GetLocale(), templateKey)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load template: %v", err)
	}
	subject, body := tpl.Render(map[string]string{
		"item_label": itemLabel(req.GetLocale(), req.GetItemKind()),
		"panel_url":  req.GetPanelUrl(),
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

// itemLabel localizes the shared-item kind for client_panel_new_item.
// Grammar note: the PL template reads "udostępnił Ci {item_label}", so
// the label carries the accusative ("nową sesję").
func itemLabel(locale, kind string) string {
	en := strings.HasPrefix(strings.ToLower(locale), "en")
	switch kind {
	case "SESSION":
		if en {
			return "a new session"
		}
		return "nową sesję"
	case "NOTE":
		if en {
			return "a new note"
		}
		return "nową notatkę"
	default:
		if en {
			return "a new item"
		}
		return "nową pozycję"
	}
}
