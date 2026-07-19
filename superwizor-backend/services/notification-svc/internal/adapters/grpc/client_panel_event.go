package grpc

import (
	"context"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
	"github.com/superwizor-ai/backend/services/notification-svc/internal/adapters/fcm"
	fswriter "github.com/superwizor-ai/backend/services/notification-svc/internal/adapters/firestore"
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

	// Wrap in the beautiful, branded generic HTML template
	ctaText := "Otwórz panel"
	if req.GetEvent() == "CLIENT_NOTE_RECEIVED" {
		if strings.ToLower(req.GetLocale()) == "en" {
			ctaText = "View Note"
		} else {
			ctaText = "Zobacz notatkę"
		}
	} else {
		if strings.ToLower(req.GetLocale()) == "en" {
			ctaText = "Open Panel"
		}
	}
	htmlBody := wrapWithGenericTemplate(req.GetLocale(), subject, subject, body, req.GetPanelUrl(), ctaText)

	// CHANNEL ORDER MATTERS: the Firestore inbox write and the FCM push
	// are the LIVE in-app channels; the e-mail is the closed-app channel.
	// They must not depend on each other — the previous shape returned on
	// e-mail failure BEFORE the inbox write, so any Resend rejection
	// (rate limit, disposable-domain bounce) silently killed the live
	// refresh and the therapist saw the note only after an app restart
	// (reported 2026-07-19). In-app channels run first, each best-effort.

	// docs/39 PR12: mirror the event into the recipient's Firestore inbox
	// (user_notifications/{firebaseUid}/inbox). The therapist iOS app and
	// the web client panel already subscribe to that collection, so this
	// write is what makes a sent note / newly shared item appear LIVE —
	// no dependence on iOS foreground-push quirks or web-push setup.
	if s.fsWriter != nil && req.GetRecipientUserId() != "" {
		s.writeClientPanelInbox(ctx, req)
	}

	// docs/39 PR11: for a delivered client note, ALSO push FCM to the
	// therapist's devices so their app refreshes the notes list live
	// (the e-mail alone never reached the in-app view). Best-effort +
	// PHI-free (no names, no content) — the app pulls the note over the
	// authenticated channel using patient_file_id.
	if req.GetEvent() == "CLIENT_NOTE_RECEIVED" && s.fcm != nil && req.GetRecipientUserId() != "" {
		s.pushClientNoteReceived(ctx, req)
	}

	if err := s.emailer.Send(ctx, email.Message{
		To:       req.GetRecipientEmail(),
		Subject:  subject,
		HTMLBody: htmlBody,
		TextBody: body,
		From:     tpl.From,
	}); err != nil {
		// In-app channels already delivered; surface the e-mail failure
		// to the caller's log without having gated the live path on it.
		return nil, status.Errorf(codes.Internal, "send email: %v", err)
	}
	return &emptypb.Empty{}, nil
}

// writeClientPanelInbox mirrors a client-panel event into the recipient's
// Firestore inbox. Best-effort + PHI-free (no client identity, no content):
// carries only a localized signal + the patient_file_id the app uses to
// refresh the right kartoteka. Failures are logged and dropped — the item
// is already durable in Postgres and the e-mail already went out.
func (s *Server) writeClientPanelInbox(ctx context.Context, req *notificationv1.SendClientPanelEventRequest) {
	uid, err := uuid.Parse(req.GetRecipientUserId())
	if err != nil {
		return
	}
	fbUID, err := s.store.LookupFirebaseUIDByUserID(ctx, uid)
	if err != nil || fbUID == "" {
		// No Firebase account (pseudonymous kartoteka client, deleted
		// user, or NULL uid) — nothing to address. E-mail/FCM already ran.
		return
	}

	var notifType, title, body string
	switch req.GetEvent() {
	case "CLIENT_NOTE_RECEIVED":
		notifType = "client_note_received"
		title, body = localizeClientNoteReceived(req.GetLocale())
	case "ITEM_SHARED":
		notifType = "item_shared"
		title, body = localizeItemShared(req.GetLocale(), req.GetItemKind())
	default:
		return
	}

	if err := s.fsWriter.WriteInboxNotification(ctx, fswriter.InboxNotification{
		NotificationID:   uuid.NewString(),
		FirebaseUID:      fbUID,
		NotificationType: notifType,
		Title:            title,
		Body:             body,
		PatientFileID:    req.GetPatientFileId(),
	}); err != nil {
		slog.WarnContext(ctx, "client-panel inbox write failed",
			"event", req.GetEvent(), "recipient_user_id", uid, "error", err)
		return
	}
	// Success breadcrumb — makes "did the live channel fire?" a one-line
	// log query next time a stale-notes report comes in.
	slog.InfoContext(ctx, "analytics",
		"ae", "client_panel.inbox_written",
		"event", req.GetEvent(),
		"recipient_user_id", uid.String(),
		"patient_file_id", req.GetPatientFileId())
}

// localizeItemShared — PHI-free inbox copy for the client's web panel when
// the therapist shares a session/note. Reuses itemLabel for the accusative
// item phrase. pl default.
func localizeItemShared(locale, kind string) (title, body string) {
	if strings.HasPrefix(strings.ToLower(locale), "en") {
		return "New in your panel", "Your therapist shared " + itemLabel(locale, kind) + " with you."
	}
	return "Nowość w Twoim panelu", "Terapeuta udostępnił Ci " + itemLabel(locale, kind) + "."
}

// pushClientNoteReceived fans a PHI-free FCM data push out to the
// therapist's active devices. Failures are logged and dropped — the
// e-mail already went out and the note is safely in the DB.
func (s *Server) pushClientNoteReceived(ctx context.Context, req *notificationv1.SendClientPanelEventRequest) {
	uid, err := uuid.Parse(req.GetRecipientUserId())
	if err != nil {
		return
	}
	tokens, err := s.store.ListActiveFCMTokensByUser(ctx, uid)
	if err != nil || len(tokens) == 0 {
		return
	}
	strs := make([]string, len(tokens))
	for i, t := range tokens {
		strs[i] = t.Token
	}
	title, bodyText := localizeClientNoteReceived(req.GetLocale())
	if _, err := s.fcm.Send(ctx, fcm.Push{
		Tokens:           strs,
		Title:            title,
		Body:             bodyText,
		NotificationType: "client_note_received",
		PatientFileID:    req.GetPatientFileId(),
	}); err != nil {
		slog.WarnContext(ctx, "client_note_received FCM push failed",
			"recipient_user_id", uid, "error", err)
	}
}

// localizeClientNoteReceived — PHI-free push copy (no client identity,
// no content). pl default.
func localizeClientNoteReceived(locale string) (title, body string) {
	if strings.HasPrefix(strings.ToLower(locale), "en") {
		return "New client note", "A client sent you a note in the panel."
	}
	return "Nowa notatka klienta", "Klient przesłał Ci notatkę w panelu."
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
