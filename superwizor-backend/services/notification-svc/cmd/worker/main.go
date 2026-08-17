// Package notificationworker is the Cloud Functions Gen2 entrypoint for
// notification-svc. After the docs/21 Faza-4 consolidation it registers two
// CloudEvent handlers:
//
//	session.status_changed → ProcessSessionStatusChanged (notification-worker-on-status)
//	    The single status-mirror consumer for the whole lifecycle
//	    (uploaded | transcribing | analyzing | done | failed | cancelled).
//	    On "done" it ALSO sends the report-ready FCM push + inbox doc
//	    (handleReportReady) — the job formerly owned by the retired
//	    notification-worker-on-report.
//	session.deleted        → ProcessSessionDeleted       (notification-worker-on-deleted)
//	    RODO erase of the Firestore mirror + inbox docs.
//
// The former per-topic functions (on-uploaded → audio.uploaded,
// on-transcribed → transcript.completed, on-report → report.generated) are
// retired; their producers now publish to the unified session.status_changed
// topic. Each remaining handler is wired to its own Cloud Function resource
// in infra/modules/cloud-functions/main.tf (one shared zip, Eventarc routes
// one topic per function).
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

	"github.com/superwizor-ai/backend/pkg/logging"
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

// Producers (clinical-svc, stt-worker, llm-worker, ingestion-svc) use
// snake_case JSON keys — verified against their source. Stay consistent
// with that convention here so the worker doesn't drop session_id.
//
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
	store     *pgstore.Store
	fsWriter  *fswriter.Writer
	fcmSender *fcm.Sender
	projectID string
)

func init() {
	// pkg/logging: bez mapowania level→severity Cloud Logging widzi
	// wszystko jako DEFAULT. Alerty w infra/modules/monitoring dopasowuja
	// sie po jsonPayload.msg, ktore helper zachowuje.
	logging.SetupDefault()

	ctx := context.Background()
	projectID = os.Getenv("GCP_PROJECT_ID")

	if dsn := os.Getenv("DATABASE_URL"); dsn != "" {
		// Bounded pool (see docs/17 §11). This binary runs in five
		// Cloud Functions (notification-worker-on-{billing,uploaded,
		// transcribed,report,deleted}); each invocation is single-
		// flight and only writes a few rows + Firestore docs.
		poolCfg, err := pgxpool.ParseConfig(dsn)
		if err != nil {
			slog.Error("notification-worker: parse db dsn", "error", err)
			os.Exit(1)
		}
		poolCfg.MaxConns = 1
		poolCfg.MinConns = 0
		poolCfg.MaxConnIdleTime = 30 * time.Second
		pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
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

	// docs/21 Faza-4 consolidation: a SINGLE status consumer
	// (ProcessSessionStatusChanged, deployed as notification-worker-on-status)
	// owns the whole session lifecycle mirror AND the report-ready FCM push.
	// The three former per-topic functions (on-uploaded, on-transcribed,
	// on-report) are retired — their producers now publish to the unified
	// session.status_changed topic. on-deleted stays (RODO erase is a
	// different action, not a status transition).
	functions.CloudEvent("ProcessSessionDeleted", ProcessSessionDeleted)
	functions.CloudEvent("ProcessSessionStatusChanged", ProcessSessionStatusChanged)
}

// ---------------------------------------------------------------------------
// handleReportReady — the report-ready fan-out: FCM "report ready" push +
// Firestore status=done + inbox doc + audit row in PG. Fully idempotent.
//
// Invoked by ProcessSessionStatusChanged on the "done" transition (docs/21
// Faza-4). This was formerly ProcessReportGenerated /
// notification-worker-on-report. That function logged report_id but never
// used it for the push or inbox — both key off session_id — so the unified
// session.status_changed event carries everything this path needs and the
// dedicated on-report function was retired.
// ---------------------------------------------------------------------------
func handleReportReady(ctx context.Context, logger *slog.Logger, sessionIDStr string, session *pgstore.SessionForNotification) error {
	idempotencyKey := sessionIDStr + ":report_ready"
	deliveryID, err := store.InsertNotificationDelivery(ctx, pgstore.InsertDeliveryParams{
		UserID:           session.TherapistID,
		SessionID:        &session.SessionID,
		NotificationType: "report_ready",
		IdempotencyKey:   idempotencyKey,
	})
	if err != nil {
		if isAlreadyDelivered(err) {
			logger.Info("duplicate report-ready (done) event — already processed")
			// Still mirror status to Firestore — cheap and ensures
			// readers converge if a previous attempt crashed mid-write.
			_ = fsWriter.WriteSessionState(ctx, fswriter.SessionState{
				SessionID:            sessionIDStr,
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
			SessionID:        sessionIDStr,
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
		SessionID:            sessionIDStr,
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
		SessionID:        sessionIDStr,
		CreatedAt:        time.Now().UTC(),
	})

	logger.Info("report-ready (done) handled",
		"push_status", pushStatus, "tokens", len(tokens))
	return nil
}

// ProcessSessionStatusChanged — consumes session.status_changed (docs/21
// Faza-4). The SINGLE status consumer (deployed as
// notification-worker-on-status). The status VARIES (uploaded | transcribing
// | analyzing | done | failed | cancelled) and is carried in the payload, so
// it is read from the event and validated against the Firestore vocabulary.
//
// Most transitions are pure Firestore mirrors. "done" is special: beyond the
// mirror it ALSO fires the report-ready FCM push + inbox doc
// (handleReportReady) — the work formerly done by the retired
// notification-worker-on-report.
func ProcessSessionStatusChanged(ctx context.Context, e event.Event) error {
	logger := slog.With("function", "notification-worker", "trigger", "session.status_changed")

	var msgData MessagePublishedData
	if err := e.DataAs(&msgData); err != nil {
		logger.Error("decode cloudevent", "error", err)
		return err
	}
	sessionIDStr, fsStatus, err := parseSessionStatusChanged(msgData.Message.Data)
	if err != nil {
		logger.Error("parse payload", "error", err, "raw", string(msgData.Message.Data))
		return err
	}
	logger = logger.With("session_id", sessionIDStr, "status", fsStatus)

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

	// "done" is the report-ready transition: beyond the status mirror it
	// fires the FCM "report ready" push + writes the inbox doc. Delegated to
	// handleReportReady, which carries its own ("report_ready") idempotency
	// key so it never collides with the "status_done" mirror key.
	if fsStatus == "done" {
		return handleReportReady(ctx, logger, sessionIDStr, session)
	}

	// Idempotency per (session, status) so a duplicate Pub/Sub delivery
	// of the same transition doesn't re-mirror.
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

	if err := fsWriter.WriteSessionState(ctx, fswriter.SessionState{
		SessionID:            sessionIDStr,
		TherapistFirebaseUID: session.TherapistFirebaseUID,
		Status:               fsStatus,
		ProgressPercent:      progressForStatus(fsStatus),
	}); err != nil {
		logger.Warn("firestore mirror failed", "error", err)
	}

	// Silent data-only push for intermediate pipeline states so the iOS
	// Live Activity widget updates in real time even when the app is
	// backgrounded. Best-effort: if this fails the widget just shows the
	// last known status until the next transition (or the final
	// report_ready visible push).
	if shouldSilentPush(fsStatus) {
		tokens, tokErr := store.ListActiveFCMTokensByUser(ctx, session.TherapistID)
		if tokErr != nil {
			logger.Warn("silent push: list tokens failed", "error", tokErr)
		} else if len(tokens) > 0 {
			tokenStrings := make([]string, len(tokens))
			for i, t := range tokens {
				tokenStrings[i] = t.Token
			}
			_, pushErr := fcmSender.SendSilent(ctx, fcm.Push{
				Tokens:           tokenStrings,
				SessionID:        sessionIDStr,
				NotificationType: "status_" + fsStatus,
			})
			if pushErr != nil {
				logger.Warn("silent push failed (non-fatal)", "error", pushErr)
			} else {
				logger.Info("silent push sent", "status", fsStatus)
			}
		}
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

// shouldSilentPush returns true for intermediate pipeline statuses that
// warrant a silent data-only FCM push to update the iOS Live Activity
// widget. "done" is excluded because it gets a full visible push via
// handleReportReady. "failed" and "cancelled" are excluded because the
// app handles those through Firestore listener or app-resume checks.
func shouldSilentPush(status string) bool {
	switch status {
	case "uploaded", "transcribing", "analyzing":
		return true
	default:
		return false
	}
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

// parseSessionStatusChanged extracts session_id + status and validates
// the status against the Firestore vocabulary this consumer understands.
// An unknown status is rejected (→ retried, then DLQ) rather than
// silently writing garbage into session_states.
func parseSessionStatusChanged(b []byte) (sessionID, status string, err error) {
	var ev struct {
		SessionID string `json:"session_id"`
		Status    string `json:"status"`
	}
	if uerr := json.Unmarshal(b, &ev); uerr != nil {
		return "", "", uerr
	}
	if ev.SessionID == "" {
		return "", "", fmt.Errorf("session.status_changed missing session_id")
	}
	switch ev.Status {
	// Full lifecycle (docs/21 Faza-4 consolidation): on-status is now the
	// single status-mirror consumer. Producers publish every transition
	// here, and notification-worker-on-uploaded/-transcribed/-report are
	// retired. (on-deleted stays — deletion is a different action.)
	case "uploaded", "transcribing", "analyzing", "done", "failed", "cancelled":
		return ev.SessionID, ev.Status, nil
	default:
		return "", "", fmt.Errorf("session.status_changed unknown status %q", ev.Status)
	}
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
//  1. Delete session_states/{sessionId} doc so the Flutter listener
//     stops showing the stale stepper.
//  2. Delete every user_notifications/{uid}/inbox/{notif} doc that
//     references this session, so the inbox tray doesn't keep showing
//     "Report ready" entries for a session that no longer exists.
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
