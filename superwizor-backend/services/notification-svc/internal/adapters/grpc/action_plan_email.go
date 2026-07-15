package grpc

import (
	"context"
	"errors"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
	pgstore "github.com/superwizor-ai/backend/services/notification-svc/internal/adapters/postgres"
	"github.com/superwizor-ai/backend/services/notification-svc/internal/email"
	"github.com/superwizor-ai/backend/services/notification-svc/internal/i18n"
)

// SendActionPlanEmail delivers a session's "action plan" to the patient
// by e-mail (docs/22). This is an internal RPC: clinical-svc fires it
// from SavePatientNote when the therapist chooses "save and send". Like
// SendInvitationEmail it is service-to-service (Cloud Run IAM) — no
// Firebase ID token is verified here.
//
// Template resolution prefers the DB-backed, editable email_templates
// row (migration 000041, key "action_plan") and falls back to the
// embedded i18n template if the row is missing — so the service is safe
// to run before the table is seeded.
//
// Idempotency + audit: when the recipient resolves to a users row we
// record a notification_deliveries row keyed by req.idempotency_key and
// short-circuit a duplicate call (same key) without re-sending. When the
// recipient is not a users row (the table's user_id is NOT NULL, so we
// cannot record one) we degrade to a best-effort send — matching how the
// other transactional e-mails (invitation, verification, quota) skip the
// deliveries audit entirely.
func (s *Server) SendActionPlanEmail(
	ctx context.Context, req *notificationv1.SendActionPlanEmailRequest,
) (*notificationv1.SendActionPlanEmailResponse, error) {
	if strings.TrimSpace(req.GetToEmail()) == "" {
		return nil, status.Error(codes.InvalidArgument, "to_email required")
	}

	vars := map[string]string{
		"therapist_name": req.GetTherapistDisplayName(),
		"session_date":   req.GetSessionDate(),
		"action_plan":    req.GetActionPlanText(),
	}

	subject, htmlBody, textBody, err := s.renderActionPlan(ctx, req.GetLocale(), vars)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "render action plan template: %v", err)
	}

	// Idempotency + audit gate. Only available when the recipient is a
	// real users row (deliveries.user_id is NOT NULL) and we have a store.
	deliveryID, ownerID, recorded := s.recordActionPlanDelivery(ctx, req)
	if recorded && deliveryID == uuid.Nil {
		// Duplicate idempotency_key — already delivered. Return the
		// original delivery id without re-sending.
		existing, err := s.store.GetDeliveryIDByIdempotencyKey(ctx, req.GetIdempotencyKey())
		if err != nil {
			slog.ErrorContext(ctx, "lookup existing action_plan delivery", "error", err)
			return nil, status.Error(codes.Internal, "lookup existing delivery")
		}
		slog.InfoContext(ctx, "action_plan email already delivered (idempotent replay)",
			"delivery_id", existing.String())
		return &notificationv1.SendActionPlanEmailResponse{DeliveryId: existing.String()}, nil
	}

	if err := s.emailer.Send(ctx, email.Message{
		To:       req.GetToEmail(),
		Subject:  subject,
		HTMLBody: htmlBody,
		TextBody: textBody,
	}); err != nil {
		if recorded {
			s.markActionPlanDeliveryFailed(ctx, deliveryID, err)
		}
		slog.ErrorContext(ctx, "send action_plan email", "error", err)
		return nil, status.Errorf(codes.Internal, "send email: %v", err)
	}

	if recorded {
		if uerr := s.store.UpdateNotificationDeliveryStatus(ctx, pgstore.UpdateDeliveryStatusParams{
			ID:     deliveryID,
			Status: "sent",
		}); uerr != nil {
			// The e-mail went out; a stuck 'queued' audit row is not worth
			// failing the RPC over. Log and return success.
			slog.WarnContext(ctx, "mark action_plan delivery sent", "delivery_id", deliveryID.String(), "error", uerr)
		}
	}

	// When we have no deliveries row (no resolvable user) the delivery id
	// is a fresh uuid so the caller still gets a stable, non-empty handle.
	if deliveryID == uuid.Nil {
		deliveryID = uuid.New()
	}
	_ = ownerID
	return &notificationv1.SendActionPlanEmailResponse{DeliveryId: deliveryID.String()}, nil
}

// renderActionPlan resolves the template. It prefers the DB-backed
// email_templates row and falls back to the embedded i18n template when
// the row (and its 'pl' fallback) is missing, or when no store is wired
// (local/dev/test). The HTML body gets action_plan newlines converted to
// <br> before substitution so a multi-line plan renders; the text body
// keeps raw newlines.
func (s *Server) renderActionPlan(
	ctx context.Context, locale string, vars map[string]string,
) (subject, htmlBody, textBody string, err error) {
	if s.store != nil {
		subj, bodyHTML, bodyText, derr := s.store.GetEmailTemplate(ctx, "action_plan", locale)
		switch {
		case derr == nil:
			// HTML uses an action_plan with newlines linkified to <br>;
			// the text body keeps the raw plan.
			htmlVars := make(map[string]string, len(vars))
			for k, v := range vars {
				htmlVars[k] = v
			}
			htmlVars["action_plan"] = strings.ReplaceAll(vars["action_plan"], "\n", "<br>")

			subject = substituteVars(subj, htmlVars)
			htmlBody = substituteVars(bodyHTML, htmlVars)
			textBody = substituteVars(bodyText, vars)
			return subject, htmlBody, textBody, nil
		case errors.Is(derr, pgx.ErrNoRows):
			// Fall through to the embedded template.
		default:
			return "", "", "", derr
		}
	}

	// Embedded fallback: one body for both text + HTML.
	tpl, lerr := i18n.Load(locale, "action_plan")
	if lerr != nil {
		return "", "", "", lerr
	}
	subject, body := tpl.Render(vars)
	return subject, wrapWithGenericTemplate(locale, subject, subject, body, "", ""), body, nil
}

// recordActionPlanDelivery inserts the idempotency/audit row when the
// recipient resolves to a users row. Returns:
//   - (newID, ownerID, true)  — first delivery, row inserted (status queued)
//   - (uuid.Nil, ownerID, true) — duplicate idempotency_key (already delivered)
//   - (uuid.Nil, uuid.Nil, false) — no audit row (no store, no idempotency
//     key, or recipient is not a users row); caller does a best-effort send.
func (s *Server) recordActionPlanDelivery(
	ctx context.Context, req *notificationv1.SendActionPlanEmailRequest,
) (deliveryID, ownerID uuid.UUID, recorded bool) {
	if s.store == nil || strings.TrimSpace(req.GetIdempotencyKey()) == "" {
		return uuid.Nil, uuid.Nil, false
	}

	userID, err := s.store.LookupUserIDByEmail(ctx, req.GetToEmail())
	if err != nil {
		if !errors.Is(err, pgx.ErrNoRows) {
			slog.WarnContext(ctx, "lookup user by email for action_plan delivery", "error", err)
		}
		// No users row for this recipient — can't write the NOT NULL
		// user_id, so skip the audit and do a best-effort send.
		return uuid.Nil, uuid.Nil, false
	}

	id, err := s.store.InsertNotificationDelivery(ctx, pgstore.InsertDeliveryParams{
		UserID:           userID,
		NotificationType: "action_plan",
		IdempotencyKey:   req.GetIdempotencyKey(),
	})
	if err != nil {
		if errors.Is(err, pgstore.ErrAlreadyDelivered) {
			return uuid.Nil, userID, true
		}
		slog.WarnContext(ctx, "insert action_plan delivery", "error", err)
		// Audit write failed for a non-idempotency reason — degrade to a
		// best-effort send rather than block the patient's e-mail.
		return uuid.Nil, uuid.Nil, false
	}
	return id, userID, true
}

func (s *Server) markActionPlanDeliveryFailed(ctx context.Context, deliveryID uuid.UUID, sendErr error) {
	if s.store == nil || deliveryID == uuid.Nil {
		return
	}
	msg := sendErr.Error()
	if uerr := s.store.UpdateNotificationDeliveryStatus(ctx, pgstore.UpdateDeliveryStatusParams{
		ID:           deliveryID,
		Status:       "failed",
		ErrorMessage: &msg,
	}); uerr != nil {
		slog.WarnContext(ctx, "mark action_plan delivery failed", "delivery_id", deliveryID.String(), "error", uerr)
	}
}

// substituteVars replaces every {key} occurrence with vars[key]. Mirrors
// the i18n templater's {placeholder} convention so the DB-backed and
// embedded templates render identically.
func substituteVars(s string, vars map[string]string) string {
	for k, v := range vars {
		s = strings.ReplaceAll(s, "{"+k+"}", v)
	}
	return s
}
