// Package notificationworker is the Cloud Functions Gen2 entrypoint for
// notification-svc. It registers three CloudEvent handlers, one per Pub/Sub
// topic that the AI pipeline emits:
//
//	report.generated     → ProcessReportGenerated      (sends FCM + sets status=done)
//	transcript.completed → ProcessTranscriptCompleted  (status=analyzing, no push)
//	audio.uploaded       → ProcessAudioUploaded        (status=uploaded, no push)
//
// Each handler is wired to its own Cloud Function resource in
// infra/modules/cloud-functions/main.tf — Eventarc routes one topic per
// function. Source code is shared (one zip, three resources).
//
// Pattern lifted from services/ai-pipeline-svc/cmd/{stt,llm}-worker:
//   - package <name>worker, NO func main()
//   - init() bootstraps clients, then registers handlers via
//     functions.CloudEvent().
//   - The Cloud Functions framework calls the handler with a CloudEvent
//     whose .Data() is the Pub/Sub envelope (MessagePublishedData JSON).
package notificationworker

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"time"

	fs "cloud.google.com/go/firestore"
	firebase "firebase.google.com/go/v4"
	fbmessaging "firebase.google.com/go/v4/messaging"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/cloudevents/sdk-go/v2/event"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/services/notification-svc/internal/adapters/fcm"
	fswriter "github.com/superwizor-ai/backend/services/notification-svc/internal/adapters/firestore"
	pgstore "github.com/superwizor-ai/backend/services/notification-svc/internal/adapters/postgres"
)

// MessagePublishedData is the Eventarc envelope wrapping Pub/Sub messages
// for CloudEvent handlers (matches the format used by stt-worker/llm-worker).
type MessagePublishedData struct {
	Message struct {
		Data       []byte            `json:"data"`
		Attributes map[string]string `json:"attributes"`
	} `json:"message"`
}

// All three publishers (ingestion-svc, stt-worker, llm-worker) use
// snake_case JSON keys — verified against their source. Stay consistent
// with that convention here so the worker doesn't drop session_id.
type ReportGeneratedEvent struct {
	SessionID string `json:"session_id"`
	ReportID  string `json:"report_id"`
}

type TranscriptCompletedEvent struct {
	SessionID    string `json:"session_id"`
	TranscriptID string `json:"transcript_id"`
}

type AudioUploadedEvent struct {
	SessionID  string `json:"session_id"`
	UploadID   string `json:"upload_id"`
	ObjectPath string `json:"object_path"`
}

// SessionDeletedEvent matches the schema published by clinical-svc
// (services/clinical-svc/internal/adapters/pubsub/publisher.go) when a
// session is hard-deleted via DeleteSession or DeletePatientFile.
// Keep in sync with that producer.
type SessionDeletedEvent struct {
	SessionID   string `json:"session_id"`
	TherapistID string `json:"therapist_id"`
}

// Globals — populated by init() once per Cloud Function instance, reused
// across invocations.
var (
	store      *pgstore.Store
	fsWriter   *fswriter.Writer
	fcmSender  *fcm.Sender
	projectID  string
)

func init() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	ctx := context.Background()
	projectID = os.Getenv("GCP_PROJECT_ID")

	if dsn := os.Getenv("DATABASE_URL"); dsn != "" {
		pool, err := pgxpool.New(ctx, dsn)
		if err != nil {
			slog.Error("notification-worker: db pool init", "error", err)
			os.Exit(1)
		}
		store = pgstore.New(pool)
	} else {
		slog.Warn("notification-worker: DATABASE_URL not set — running in mock-store mode")
	}

	if projectID != "" {
		// Firestore client uses ADC; the function's SA needs roles/datastore.user.
		fc, err := fs.NewClient(ctx, projectID)
		if err != nil {
			slog.Error("notification-worker: firestore client", "error", err)
			os.Exit(1)
		}
		fsWriter = fswriter.NewWriter(fc)

		// Firebase Admin SDK for FCM. Same SA needs
		// roles/firebasecloudmessaging.messagesSender.
		app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID})
		if err != nil {
			slog.Error("notification-worker: firebase app", "error", err)
			os.Exit(1)
		}
		mc, err := app.Messaging(ctx)
		if err != nil {
			slog.Error("notification-worker: firebase messaging", "error", err)
			os.Exit(1)
		}
		fcmSender = fcm.NewSender(mc)
	} else {
		slog.Warn("notification-worker: GCP_PROJECT_ID not set — Firestore + FCM disabled")
	}

	functions.CloudEvent("ProcessReportGenerated", ProcessReportGenerated)
	functions.CloudEvent("ProcessTranscriptCompleted", ProcessTranscriptCompleted)
	functions.CloudEvent("ProcessAudioUploaded", ProcessAudioUploaded)
	functions.CloudEvent("ProcessSessionDeleted", ProcessSessionDeleted)
	functions.CloudEvent("ProcessBillingEvent", ProcessBillingEvent)
}

// BillingEventPayload — schema dla billing.outbox messages. Mapuje 1:1 na
// billing-svc/internal/domain/outbox.QuotaPayload. Jeśli dodajesz pole tam,
// dodaj też tutaj (loose coupling: zostawiamy unknown fields ignored przez
// json.Unmarshal, ale znane fields muszą być spójne).
type BillingEventPayload struct {
	SubscriptionID  string    `json:"subscription_id"`
	OrganizationID  string    `json:"organization_id"`
	PlanTier        string    `json:"plan_tier"`
	TokensUsed      int32     `json:"tokens_used"`
	TokensReserved  int32     `json:"tokens_reserved"`
	TokensRemaining int32     `json:"tokens_remaining"`
	TokensLimit     int32     `json:"tokens_limit"`
	PeriodStart     time.Time `json:"period_start"`
	PeriodEnd       time.Time `json:"period_end"`
}

// computeWarningLevel — taka sama logika jak w Flutter QuotaState.computeLevel.
// Backend pisze ten string do Firestore, więc klient ma 1 źródło prawdy.
// Progi spójne z billing-svc env defaults (BILLING_WARN_REMAINING=5,
// BILLING_CRITICAL_REMAINING=1, docs/16 §16.1).
func computeWarningLevel(remaining int32) string {
	switch {
	case remaining <= 0:
		return "exhausted"
	case remaining <= 1:
		return "critical"
	case remaining <= 5:
		return "warning"
	default:
		return "none"
	}
}

// ---------------------------------------------------------------------------
// ProcessReportGenerated — final fan-out: FCM push + Firestore status=done
// + inbox doc + audit row in PG. Fully idempotent.
// ---------------------------------------------------------------------------
func ProcessReportGenerated(ctx context.Context, e event.Event) error {
	logger := slog.With("function", "notification-worker", "trigger", "report.generated")

	var msgData MessagePublishedData
	if err := e.DataAs(&msgData); err != nil {
		logger.Error("decode cloudevent", "error", err)
		return err
	}
	var ev ReportGeneratedEvent
	if err := json.Unmarshal(msgData.Message.Data, &ev); err != nil {
		logger.Error("parse report.generated payload", "error", err,
			"raw", string(msgData.Message.Data))
		return err
	}
	logger = logger.With("session_id", ev.SessionID, "report_id", ev.ReportID)

	if store == nil {
		logger.Warn("no store — skipping (mock mode)")
		return nil
	}
	sessionID, err := uuid.Parse(ev.SessionID)
	if err != nil {
		logger.Error("invalid session_id", "error", err)
		return err
	}

	session, err := store.LoadSessionForNotification(ctx, sessionID)
	if err != nil {
		logger.Error("load session", "error", err)
		return fmt.Errorf("load session: %w", err)
	}

	idempotencyKey := ev.SessionID + ":report_ready"
	deliveryID, err := store.InsertNotificationDelivery(ctx, pgstore.InsertDeliveryParams{
		UserID:           session.TherapistID,
		SessionID:        &session.SessionID,
		NotificationType: "report_ready",
		IdempotencyKey:   idempotencyKey,
	})
	if err != nil {
		if isAlreadyDelivered(err) {
			logger.Info("duplicate report.generated event — already processed")
			// Still mirror status to Firestore — cheap and ensures
			// readers converge if a previous attempt crashed mid-write.
			_ = fsWriter.WriteSessionState(ctx, fswriter.SessionState{
				SessionID:            ev.SessionID,
				TherapistFirebaseUID: session.TherapistFirebaseUID,
				Status:               "done",
				ProgressPercent:      100,
			})
			return nil
		}
		logger.Error("insert notification_delivery", "error", err)
		return err
	}
	logger = logger.With("delivery_id", deliveryID)

	tokens, err := store.ListActiveFCMTokensByUser(ctx, session.TherapistID)
	if err != nil {
		logger.Error("list fcm tokens", "error", err)
		_ = store.UpdateNotificationDeliveryStatus(ctx, pgstore.UpdateDeliveryStatusParams{
			ID: deliveryID, Status: "failed",
			ErrorCode:    strPtr("db_error"),
			ErrorMessage: strPtr(err.Error()),
		})
		return err
	}

	title, body := localizeReportReady(session.TherapistLocale, session.SessionDate)

	// Send FCM (no-op when sender is mock or no tokens). Best-effort:
	// Firestore write happens regardless so the foreground app sees the
	// status transition even if FCM is broken.
	pushStatus := "sent"
	var pushErrCode, pushErrMsg *string
	var fcmMsgID *string

	if len(tokens) == 0 {
		logger.Warn("therapist has no active FCM tokens — skipping push")
		pushStatus = "failed"
		c := "no_active_tokens"
		pushErrCode = &c
	} else {
		tokenStrings := make([]string, len(tokens))
		for i, t := range tokens {
			tokenStrings[i] = t.Token
		}
		results, err := fcmSender.Send(ctx, fcm.Push{
			Tokens:           tokenStrings,
			Title:            title,
			Body:             body,
			SessionID:        ev.SessionID,
			NotificationType: "report_ready",
		})
		if err != nil {
			logger.Error("fcm send", "error", err)
			pushStatus = "failed"
			c := "fcm_error"
			m := err.Error()
			pushErrCode, pushErrMsg = &c, &m
		} else {
			anySuccess := false
			for i, r := range results {
				if r.Success {
					anySuccess = true
					if fcmMsgID == nil {
						id := r.MessageID
						fcmMsgID = &id
					}
					continue
				}
				if r.TokenInvalidated {
					logger.Info("invalidating fcm token", "token_id", tokens[i].ID)
					if iErr := store.InvalidateFCMToken(ctx, tokens[i].ID, "fcm_not_registered"); iErr != nil {
						logger.Warn("invalidate token failed", "error", iErr)
					}
				}
				if r.Err != nil {
					logger.Warn("fcm per-token failure",
						"token_id", tokens[i].ID, "error", r.Err)
				}
			}
			if !anySuccess {
				pushStatus = "token_invalid"
				c := "all_tokens_failed"
				pushErrCode = &c
			}
		}
	}

	// Audit row update — sent/failed/token_invalid.
	if err := store.UpdateNotificationDeliveryStatus(ctx, pgstore.UpdateDeliveryStatusParams{
		ID:           deliveryID,
		Status:       pushStatus,
		FCMMessageID: fcmMsgID,
		ErrorCode:    pushErrCode,
		ErrorMessage: pushErrMsg,
	}); err != nil {
		logger.Warn("update delivery status", "error", err)
	}

	// Best-effort Firestore writes. Errors are logged inside the writer.
	_ = fsWriter.WriteSessionState(ctx, fswriter.SessionState{
		SessionID:            ev.SessionID,
		TherapistFirebaseUID: session.TherapistFirebaseUID,
		Status:               "done",
		ProgressPercent:      100,
	})
	_ = fsWriter.WriteInboxNotification(ctx, fswriter.InboxNotification{
		NotificationID:   deliveryID.String(),
		FirebaseUID:      session.TherapistFirebaseUID,
		NotificationType: "report_ready",
		Title:            title,
		Body:             body,
		SessionID:        ev.SessionID,
		CreatedAt:        time.Now().UTC(),
	})

	logger.Info("report.generated handled",
		"push_status", pushStatus, "tokens", len(tokens))
	return nil
}

// ---------------------------------------------------------------------------
// ProcessTranscriptCompleted — pure status mirror (analyzing). No FCM.
// ---------------------------------------------------------------------------
func ProcessTranscriptCompleted(ctx context.Context, e event.Event) error {
	return handleStatusMirror(ctx, e, "transcript.completed", "analyzing", parseTranscriptCompleted)
}

// ---------------------------------------------------------------------------
// ProcessAudioUploaded — pure status mirror (uploaded). No FCM.
// ---------------------------------------------------------------------------
func ProcessAudioUploaded(ctx context.Context, e event.Event) error {
	return handleStatusMirror(ctx, e, "audio.uploaded", "uploaded", parseAudioUploaded)
}

// handleStatusMirror is the shared body for the silent status-update
// handlers. Idempotency: we still INSERT a row in notification_deliveries
// (notification_type = "status_<topic>") so duplicate Pub/Sub messages
// don't write to Firestore twice. The FCM-related delivery columns stay
// empty for these rows.
func handleStatusMirror(
	ctx context.Context,
	e event.Event,
	topicLabel, fsStatus string,
	parse func([]byte) (string, error),
) error {
	logger := slog.With("function", "notification-worker", "trigger", topicLabel)

	var msgData MessagePublishedData
	if err := e.DataAs(&msgData); err != nil {
		logger.Error("decode cloudevent", "error", err)
		return err
	}
	sessionIDStr, err := parse(msgData.Message.Data)
	if err != nil {
		logger.Error("parse payload", "error", err, "raw", string(msgData.Message.Data))
		return err
	}
	logger = logger.With("session_id", sessionIDStr)

	if store == nil {
		logger.Warn("no store — skipping (mock mode)")
		return nil
	}
	sessionID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		logger.Error("invalid session_id", "error", err)
		return err
	}

	session, err := store.LoadSessionForNotification(ctx, sessionID)
	if err != nil {
		logger.Error("load session", "error", err)
		return fmt.Errorf("load session: %w", err)
	}

	// Idempotency only — no FCM, no audit columns to update.
	idempotencyKey := sessionIDStr + ":status_" + fsStatus
	if _, err := store.InsertNotificationDelivery(ctx, pgstore.InsertDeliveryParams{
		UserID:           session.TherapistID,
		SessionID:        &session.SessionID,
		NotificationType: "status_" + fsStatus,
		IdempotencyKey:   idempotencyKey,
	}); err != nil {
		if isAlreadyDelivered(err) {
			logger.Info("duplicate status event — already mirrored")
			return nil
		}
		logger.Error("insert delivery", "error", err)
		return err
	}

	progress := progressForStatus(fsStatus)
	if err := fsWriter.WriteSessionState(ctx, fswriter.SessionState{
		SessionID:            sessionIDStr,
		TherapistFirebaseUID: session.TherapistFirebaseUID,
		Status:               fsStatus,
		ProgressPercent:      progress,
	}); err != nil {
		// Best-effort: log but don't fail. The Pub/Sub message gets
		// ACK'd; if Firestore is down, Flutter falls back to clinical-svc
		// poll for status (architecture §6.3).
		logger.Warn("firestore mirror failed", "error", err)
	}

	logger.Info("status mirror written", "status", fsStatus)
	return nil
}

// progressForStatus maps a status to a coarse percent for client progress
// bars. Aligns with ADR-IMPL-012 timeline (uploaded ~10%, analyzing ~60%,
// done 100%).
func progressForStatus(s string) int {
	switch s {
	case "uploaded":
		return 10
	case "transcribing":
		return 35
	case "analyzing":
		return 60
	case "done":
		return 100
	default:
		return 0
	}
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

func parseTranscriptCompleted(b []byte) (string, error) {
	var ev TranscriptCompletedEvent
	if err := json.Unmarshal(b, &ev); err != nil {
		return "", err
	}
	if ev.SessionID == "" {
		return "", fmt.Errorf("transcript.completed missing session_id")
	}
	return ev.SessionID, nil
}

func parseAudioUploaded(b []byte) (string, error) {
	var ev AudioUploadedEvent
	if err := json.Unmarshal(b, &ev); err != nil {
		return "", err
	}
	if ev.SessionID == "" {
		return "", fmt.Errorf("audio.uploaded missing session_id")
	}
	return ev.SessionID, nil
}

// localizeReportReady returns (title, body) for the report-ready push,
// localized by the therapist's UI language. The body intentionally does
// NOT include patient name or any session content (ADR-IMPL-013).
func localizeReportReady(uiLang string, sessionDate time.Time) (string, string) {
	switch uiLang {
	case "en", "en-US", "en-GB":
		return "Report ready",
			fmt.Sprintf("Session from %s is ready to view.", sessionDate.Format("Jan 2"))
	default:
		// pl / pl-PL / fallback
		return "Raport gotowy",
			fmt.Sprintf("Sesja z dnia %s jest gotowa do wglądu.", sessionDate.Format("2.01"))
	}
}

func isAlreadyDelivered(err error) bool {
	return err != nil && err == pgstore.ErrAlreadyDelivered
}

func strPtr(s string) *string { return &s }

// Compile-time assertion that we're holding the FCM messaging types we
// expect (catches API drift on dependency upgrades).
var _ = (*fbmessaging.Client)(nil)

// ---------------------------------------------------------------------------
// ProcessSessionDeleted — clean up Firestore mirrors when clinical-svc
// hard-deletes a session.
//
// Triggered by Pub/Sub topic session.deleted. clinical-svc publishes one
// event per session — both for single DeleteSession calls AND for the
// fan-out from DeletePatientFile (which can fire N events in succession).
//
// Two cleanup actions, both best-effort:
//   1. Delete session_states/{sessionId} doc so the Flutter listener
//      stops showing the stale stepper.
//   2. Delete every user_notifications/{uid}/inbox/{notif} doc that
//      references this session, so the inbox tray doesn't keep showing
//      "Report ready" entries for a session that no longer exists.
//
// Idempotent: deleting a missing doc is a no-op in Firestore, and the
// inbox cleanup walks via CollectionGroup so re-running just finds zero
// matching docs the second time. Pub/Sub retries on this topic are safe.
//
// We don't write a notification_deliveries audit row for this event —
// it's a destructive action, not a delivery. PG history is what's left
// after the cascade in clinical-svc (status SET NULL on the FK).
func ProcessSessionDeleted(ctx context.Context, e event.Event) error {
	logger := slog.With("function", "notification-worker", "trigger", "session.deleted")

	var msgData MessagePublishedData
	if err := e.DataAs(&msgData); err != nil {
		logger.Error("decode cloudevent", "error", err)
		return err
	}

	var ev SessionDeletedEvent
	if err := json.Unmarshal(msgData.Message.Data, &ev); err != nil {
		logger.Error("parse session.deleted payload", "error", err,
			"raw", string(msgData.Message.Data))
		return err
	}
	if ev.SessionID == "" {
		// Same pattern as parseAudioUploaded: defend against stray
		// raw GCS storage events accidentally routed to this topic.
		// Without a session_id we have nothing to clean up — ACK and
		// drop instead of dead-lettering forever.
		logger.Warn("session.deleted missing session_id, dropping",
			"raw", string(msgData.Message.Data))
		return nil
	}
	logger = logger.With("session_id", ev.SessionID, "therapist_id", ev.TherapistID)
	logger.Info("processing session.deleted")

	if fsWriter == nil {
		logger.Warn("no firestore writer — skipping (mock mode)")
		return nil
	}

	// Step 1: drop the session_states mirror.
	if err := fsWriter.DeleteSessionState(ctx, ev.SessionID); err != nil {
		// Log + continue — we still want to attempt inbox cleanup
		// even if the status doc delete fails (they're independent).
		logger.Warn("session_states delete failed", "error", err)
	}

	// Step 2: scrub inbox notifications referencing this session.
	deleted, err := fsWriter.DeleteInboxNotificationsBySession(ctx, ev.SessionID)
	if err != nil {
		logger.Warn("inbox cleanup partial failure",
			"deleted_before_err", deleted, "error", err)
	} else {
		logger.Info("inbox notifications cleaned", "count", deleted)
	}

	// ACK by returning nil regardless — handler is best-effort by
	// design. notification.deliveries is left as-is (the
	// notification_deliveries.session_id FK gets SET NULL via migration
	// 000012 when the PG cascade runs, so audit history survives).
	return nil
}

// ---------------------------------------------------------------------------
// ProcessBillingEvent — billing-svc → notification-svc fan-out.
//
// Routes outbox events (quota.warning / quota.critical / quota.exhausted /
// subscription.period_renewed / subscription.payment_failed / subscription.canceled)
// to the organization's primary admin therapist via FCM push.
//
// Idempotency: outbox poller publishes with `idempotency_key` Pub/Sub
// attribute = aggregate_type:event_type:aggregate_id:created_at.nano.
// We use that as the notification_deliveries.idempotency_key — duplicate
// Pub/Sub deliveries short-circuit at the DB layer.
//
// No PHI in push body (ADR-IMPL-013): only counts/dates.
//
// Reference: docs/16_BILLING_SERVICE_PHASE_3.md §16.2.
func ProcessBillingEvent(ctx context.Context, e event.Event) error {
	logger := slog.With("function", "notification-worker", "trigger", "billing.outbox")

	var msgData MessagePublishedData
	if err := e.DataAs(&msgData); err != nil {
		logger.Error("decode cloudevent", "error", err)
		return err
	}

	eventType := msgData.Message.Attributes["event_type"]
	orgIDStr := msgData.Message.Attributes["organization_id"]
	idempotencyKey := msgData.Message.Attributes["idempotency_key"]
	if eventType == "" || orgIDStr == "" || idempotencyKey == "" {
		logger.Error("billing event missing required attributes",
			"event_type", eventType,
			"organization_id", orgIDStr,
			"has_idempotency_key", idempotencyKey != "")
		return nil // ACK — bez wymaganych atrybutów nic nie zrobimy, retry nie pomoże.
	}
	logger = logger.With("event_type", eventType, "organization_id", orgIDStr)

	var payload BillingEventPayload
	if err := json.Unmarshal(msgData.Message.Data, &payload); err != nil {
		logger.Error("parse billing payload", "error", err,
			"raw", string(msgData.Message.Data))
		return err
	}

	if store == nil {
		logger.Warn("no store — skipping (mock mode)")
		return nil
	}

	orgID, err := uuid.Parse(orgIDStr)
	if err != nil {
		logger.Error("invalid organization_id", "error", err)
		return nil // ACK — bad UUID, retry też zawiedzie.
	}

	target, err := store.LookupBillingNotificationTarget(ctx, orgID)
	if err != nil {
		logger.Error("lookup notification target", "error", err)
		return fmt.Errorf("lookup target: %w", err)
	}
	logger = logger.With("user_id", target.UserID)

	deliveryID, err := store.InsertNotificationDelivery(ctx, pgstore.InsertDeliveryParams{
		UserID:           target.UserID,
		NotificationType: eventType,
		IdempotencyKey:   idempotencyKey,
	})
	if err != nil {
		if isAlreadyDelivered(err) {
			logger.Info("duplicate billing event — already processed")
			return nil
		}
		logger.Error("insert delivery", "error", err)
		return err
	}
	logger = logger.With("delivery_id", deliveryID)

	title, body := localizeBillingEvent(target.Locale, eventType, payload)
	if title == "" {
		// Nieznany event_type — zapisaliśmy delivery row dla audytu,
		// nic nie wysyłamy (defensive: nowy event type w billing-svc
		// nie powinien zawiesić workera).
		logger.Warn("unknown billing event_type, skipping push", "event_type", eventType)
		_ = store.UpdateNotificationDeliveryStatus(ctx, pgstore.UpdateDeliveryStatusParams{
			ID: deliveryID, Status: "failed",
			ErrorCode: strPtr("unknown_event_type"),
		})
		return nil
	}

	tokens, err := store.ListActiveFCMTokensByUser(ctx, target.UserID)
	if err != nil {
		logger.Error("list fcm tokens", "error", err)
		return err
	}

	pushStatus := "sent"
	var fcmMsgID *string
	var pushErrCode, pushErrMsg *string

	if len(tokens) == 0 {
		logger.Warn("target has no active FCM tokens")
		pushStatus = "failed"
		c := "no_active_tokens"
		pushErrCode = &c
	} else if fcmSender == nil {
		logger.Warn("fcm sender disabled (no project ID) — skipping push")
		pushStatus = "failed"
		c := "fcm_disabled"
		pushErrCode = &c
	} else {
		tokenStrings := make([]string, len(tokens))
		for i, t := range tokens {
			tokenStrings[i] = t.Token
		}
		results, sendErr := fcmSender.Send(ctx, fcm.Push{
			Tokens:           tokenStrings,
			Title:            title,
			Body:             body,
			SessionID:        "", // billing eventy nie są związane z konkretną sesją
			NotificationType: eventType,
		})
		if sendErr != nil {
			logger.Error("fcm send", "error", sendErr)
			pushStatus = "failed"
			c := "fcm_error"
			m := sendErr.Error()
			pushErrCode, pushErrMsg = &c, &m
		} else {
			anySuccess := false
			for i, r := range results {
				if r.Success {
					anySuccess = true
					if fcmMsgID == nil {
						id := r.MessageID
						fcmMsgID = &id
					}
					continue
				}
				if r.TokenInvalidated {
					_ = store.InvalidateFCMToken(ctx, tokens[i].ID, "fcm_not_registered")
				}
			}
			if !anySuccess {
				pushStatus = "token_invalid"
				c := "all_tokens_failed"
				pushErrCode = &c
			}
		}
	}

	if err := store.UpdateNotificationDeliveryStatus(ctx, pgstore.UpdateDeliveryStatusParams{
		ID:           deliveryID,
		Status:       pushStatus,
		FCMMessageID: fcmMsgID,
		ErrorCode:    pushErrCode,
		ErrorMessage: pushErrMsg,
	}); err != nil {
		logger.Warn("update delivery status", "error", err)
	}

	// Inbox doc (best-effort; bez session_id bo eventy billingowe są org-scoped).
	if fsWriter != nil {
		_ = fsWriter.WriteInboxNotification(ctx, fswriter.InboxNotification{
			NotificationID:   deliveryID.String(),
			FirebaseUID:      target.TherapistFirebaseUID,
			NotificationType: eventType,
			Title:            title,
			Body:             body,
			SessionID:        "",
			CreatedAt:        time.Now().UTC(),
		})

		// Slice 4: mirror current quota state to Firestore
		// organization_quota/{orgId}. Flutter QuotaWarningBanner reads
		// this doc. Best-effort: errors don't fail the event handler.
		warningLevel := computeWarningLevel(payload.TokensRemaining)
		if mErr := fsWriter.WriteOrganizationQuota(ctx, fswriter.OrganizationQuota{
			OrganizationID:  payload.OrganizationID,
			TokensUsed:      payload.TokensUsed,
			TokensReserved:  payload.TokensReserved,
			TokensLimit:     payload.TokensLimit,
			TokensRemaining: payload.TokensRemaining,
			WarningLevel:    warningLevel,
			PlanTier:        payload.PlanTier,
			PeriodStart:     payload.PeriodStart,
			PeriodEnd:       payload.PeriodEnd,
		}); mErr != nil {
			logger.Warn("organization_quota mirror write failed",
				"organization_id", payload.OrganizationID, "error", mErr)
		} else {
			logger.Debug("organization_quota mirror written",
				"organization_id", payload.OrganizationID,
				"warning_level", warningLevel,
				"tokens_remaining", payload.TokensRemaining)
		}
	}

	logger.Info("billing event handled", "push_status", pushStatus, "tokens", len(tokens))
	return nil
}

// localizeBillingEvent — tłumaczenia per design §16.2. Pusty tytuł oznacza
// "nieznany event type" → worker pomija push.
//
// Body NIE zawiera PHI: tylko liczby tokenów i bardzo generyczne sformułowania.
// Kropki dziesiętne dla zgodności z PL.
func localizeBillingEvent(locale, eventType string, p BillingEventPayload) (title, body string) {
	pl := locale != "en" && locale != "en-US" && locale != "en-GB"

	switch eventType {
	case "quota.warning":
		if pl {
			return "Zostało Ci niewiele tokenów",
				fmt.Sprintf("Pozostało %d tokenów do końca okresu rozliczeniowego.", p.TokensRemaining)
		}
		return "Running low on tokens",
			fmt.Sprintf("%d tokens left in the current billing period.", p.TokensRemaining)

	case "quota.critical":
		if pl {
			return "Ostatni token", "Został Ci 1 token. Rozważ rozszerzenie planu."
		}
		return "Last token", "Only 1 token left. Consider upgrading your plan."

	case "quota.exhausted":
		if pl {
			return "Wyczerpano pulę tokenów",
				"Nagrywaj dalej — sesje zostaną zachowane lokalnie i przetworzone po odnowieniu puli."
		}
		return "Token pool exhausted",
			"Keep recording — sessions will be saved locally and processed after renewal."

	case "subscription.period_renewed":
		if pl {
			return "Pula tokenów odnowiona",
				fmt.Sprintf("Masz znów %d tokenów na nowy okres rozliczeniowy.", p.TokensLimit)
		}
		return "Token pool renewed",
			fmt.Sprintf("You now have %d tokens for the new billing period.", p.TokensLimit)

	case "subscription.payment_failed":
		if pl {
			return "Problem z płatnością",
				"Nie udało się pobrać opłaty. Sprawdź metodę płatności w ustawieniach."
		}
		return "Payment failed",
			"Could not process payment. Please check your payment method in settings."

	case "subscription.canceled":
		if pl {
			return "Subskrypcja zakończona",
				"Twoja subskrypcja kończy się. Do tego czasu możesz dalej korzystać z aplikacji."
		}
		return "Subscription ended",
			"Your subscription is ending. You can continue using the app until that date."

	default:
		return "", ""
	}
}
