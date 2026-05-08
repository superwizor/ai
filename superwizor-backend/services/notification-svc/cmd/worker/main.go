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

// ReportGeneratedEvent — published by llm-worker on successful report
// persistence. CamelCase per existing convention (see llm-worker source).
type ReportGeneratedEvent struct {
	SessionID string `json:"sessionId"`
	ReportID  string `json:"reportId"`
}

// TranscriptCompletedEvent — published by stt-worker. CamelCase.
type TranscriptCompletedEvent struct {
	SessionID    string `json:"sessionId"`
	TranscriptID string `json:"transcriptId"`
}

// AudioUploadedEvent — published by ingestion-svc on
// CompleteAudioUpload. snake_case (different convention — see
// ingestion-svc/internal/adapters/pubsub).
type AudioUploadedEvent struct {
	SessionID  string `json:"session_id"`
	UploadID   string `json:"upload_id"`
	ObjectPath string `json:"object_path"`
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
		return "", fmt.Errorf("transcript.completed missing sessionId")
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
