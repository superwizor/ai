// Package firestore wraps the per-collection writes the notification-svc
// worker performs as the only backend writer to Firestore (architecture
// §6.3). Two collections:
//
//   session_states/{sessionId}            — live session status mirror
//   user_notifications/{uid}/inbox/{id}   — per-user notification inbox
//
// Both writes are best-effort (ADR-IMPL-009). Errors are logged and
// returned, but callers MUST NOT block the FCM send or Pub/Sub ACK on a
// Firestore failure — the clinical pipeline never waits.
package firestore

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	fs "cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"
	"google.golang.org/grpc/codes"
	grpcstatus "google.golang.org/grpc/status"
)

type Writer struct {
	client *fs.Client
}

func NewWriter(client *fs.Client) *Writer {
	return &Writer{client: client}
}

// SessionState is the document shape for session_states/{sessionId}.
//
// CRITICAL: TherapistFirebaseUID must be the Firebase UID (not users.id PG
// UUID). Firestore rules match against request.auth.uid (Firebase UID), so
// any mismatch silently breaks Flutter reads. This is troubleshooting
// cookbook problem #2 in 08_FAZA_3_NOTIFICATIONS.md.
type SessionState struct {
	SessionID            string    `firestore:"sessionId"`
	TherapistFirebaseUID string    `firestore:"therapistFirebaseUid"`
	Status               string    `firestore:"status"`
	ProgressPercent      int       `firestore:"progressPercent"`
	UpdatedAt            time.Time `firestore:"updatedAt,serverTimestamp"`
}

// sessionStatusRank gives a total order on the lifecycle states a session
// goes through. The notification-worker is fanned out across three
// independent Cloud Functions (on-uploaded / on-transcribed / on-report)
// subscribed to three independent Pub/Sub topics. Pub/Sub is at-least-once
// and unordered, so the events can arrive out of order — most commonly
// when an `audio.uploaded` redelivery from a backlog lands after the
// session has already advanced to "analyzing" or "done". Without a guard
// here, the late event would overwrite the more-advanced status and the
// Flutter listener would see the stepper jump backwards.
//
// 0 is the default for any unknown / unset status — that way a new doc
// (where the current rank is 0) always accepts the first write.
var sessionStatusRank = map[string]int{
	"":             0,
	"uploaded":     1,
	"transcribing": 2, // docs/21 WS1B — between uploaded and analyzing
	"analyzing":    3,
	"done":         4,
	"failed":       4, // terminal — same tier as done
	"cancelled":    4, // terminal — user-initiated
}

// terminalStatuses are the sticky end states. Once a doc reaches one,
// no other (different) terminal state may overwrite it — first terminal
// wins. This stops a late `failed` redelivery from clobbering a `done`
// (or vice-versa) under reordered at-least-once delivery (docs/21 §3.4).
var terminalStatuses = map[string]bool{
	"done":      true,
	"failed":    true,
	"cancelled": true,
}

// shouldMirror decides whether a session_states write transitioning the
// doc from currStatus → newStatus should proceed. Pure (no Firestore) so
// the monotonic-rank + terminal-sticky rules (docs/21 §3.4) are unit-
// testable. currStatus "" means a fresh/absent doc (always accepts).
//   - newStatus unknown to the rank map → allow (logged elsewhere as drift).
//   - newRank < currRank → skip (monotonic regress, e.g. a backlog
//     `uploaded` landing after `analyzing`).
//   - currStatus terminal and != newStatus → skip (first-terminal-wins:
//     a late `failed` must not clobber a real `done`, nor reopen a
//     `cancelled`).
func shouldMirror(currStatus, newStatus string) bool {
	newRank, known := sessionStatusRank[newStatus]
	if !known {
		return true
	}
	if newRank < sessionStatusRank[currStatus] {
		return false
	}
	if terminalStatuses[currStatus] && currStatus != newStatus {
		return false
	}
	return true
}

// WriteSessionState merges the status field into session_states/{sessionId}
// IF AND ONLY IF the new status outranks (>=) the currently-stored status.
// A read-modify-write inside a Firestore transaction prevents the lost-
// update race even under concurrent invocations of the three notification
// Cloud Functions.
//
// MergeAll-style behaviour is preserved on the write side: only the fields
// we set here get touched; other fields on the doc are left alone.
func (w *Writer) WriteSessionState(ctx context.Context, st SessionState) error {
	if w == nil || w.client == nil {
		return nil
	}
	docRef := w.client.Doc("session_states/" + st.SessionID)
	if _, ok := sessionStatusRank[st.Status]; !ok {
		// Defensive: unknown status string. Don't block — write it
		// through but log so we notice schema drift.
		slog.Warn("firestore session_states: unknown status — writing anyway",
			"session_id", st.SessionID, "status", st.Status)
	}

	err := w.client.RunTransaction(ctx, func(ctx context.Context, tx *fs.Transaction) error {
		snap, getErr := tx.Get(docRef)
		if getErr != nil && grpcstatus.Code(getErr) != codes.NotFound {
			// Some other error — surface it.
			return getErr
		}
		if snap != nil && snap.Exists() {
			var currStatus string
			if v, err := snap.DataAt("status"); err == nil {
				if s, ok := v.(string); ok {
					currStatus = s
				}
			}
			if !shouldMirror(currStatus, st.Status) {
				slog.Info("firestore session_states: skipping write",
					"session_id", st.SessionID,
					"current_status", currStatus,
					"new_status", st.Status)
				return nil
			}
		}
		return tx.Set(docRef, map[string]any{
			"sessionId":            st.SessionID,
			"therapistFirebaseUid": st.TherapistFirebaseUID,
			"status":               st.Status,
			"progressPercent":      st.ProgressPercent,
			"updatedAt":            fs.ServerTimestamp,
		}, fs.MergeAll)
	})
	if err != nil {
		// Log here, not just at the call site, so reader of Cloud Logging
		// sees the doc path that failed without grep'ing call stacks.
		slog.Warn("firestore session_states write failed",
			"session_id", st.SessionID, "error", err)
		return fmt.Errorf("firestore session_states: %w", err)
	}
	return nil
}

// DeleteSessionState removes the live status mirror for a session.
// Called from the notification-worker session.deleted handler so the
// Flutter listener stops seeing the stale doc after the therapist
// hard-deletes a session via clinical-svc.
//
// Idempotent: deleting a non-existent doc is a no-op in Firestore
// (Set→Delete returns success), so Pub/Sub redeliveries are safe.
func (w *Writer) DeleteSessionState(ctx context.Context, sessionID string) error {
	if w == nil || w.client == nil {
		return nil
	}
	_, err := w.client.Doc("session_states/" + sessionID).Delete(ctx)
	if err != nil {
		slog.Warn("firestore session_states delete failed",
			"session_id", sessionID, "error", err)
		return fmt.Errorf("firestore session_states delete: %w", err)
	}
	return nil
}

// DeleteInboxNotificationsBySession walks every per-user inbox under
// user_notifications/*/inbox/* and deletes any doc whose sessionId
// matches the deleted session. We don't know the firebase_uid ahead
// of time (clinical-svc only publishes session_id + therapist users.id),
// so the implementation falls back to a CollectionGroup query against
// the "inbox" sub-collection — Firestore handles the cross-user
// traversal server-side, so we don't have to scan users.
//
// Returns the count of deleted docs so the caller can log it; errors
// don't fail the event handler — best-effort cleanup. Stale notifs
// pointing at a deleted session are harmless to the user (tapping
// produces a "session not found" sheet via the Flutter route gate).
func (w *Writer) DeleteInboxNotificationsBySession(ctx context.Context, sessionID string) (int, error) {
	if w == nil || w.client == nil {
		return 0, nil
	}
	// CollectionGroup matches every collection named "inbox" anywhere
	// in the document tree — i.e. all user_notifications/*/inbox in
	// one query.
	iter := w.client.CollectionGroup("inbox").
		Where("sessionId", "==", sessionID).
		Documents(ctx)
	defer iter.Stop()

	deleted := 0
	for {
		doc, err := iter.Next()
		if errors.Is(err, iterator.Done) {
			return deleted, nil
		}
		if err != nil {
			slog.Warn("firestore inbox iterate failed",
				"session_id", sessionID, "error", err, "deleted_so_far", deleted)
			return deleted, fmt.Errorf("firestore inbox iter: %w", err)
		}
		if _, derr := doc.Ref.Delete(ctx); derr != nil {
			slog.Warn("firestore inbox delete failed",
				"session_id", sessionID, "doc_path", doc.Ref.Path, "error", derr)
			// Continue — best effort, don't return early.
			continue
		}
		deleted++
	}
}

// InboxNotification is the document shape for
// user_notifications/{uid}/inbox/{notifId}. The Flutter client subscribes
// to this collection for the in-app notification tray and may set readAt
// (only) — see firestore.rules.
type InboxNotification struct {
	NotificationID   string
	FirebaseUID      string
	NotificationType string // "report_ready" | "session_uploaded" | "client_note_received" | "item_shared"
	Title            string
	Body             string
	SessionID        string
	// PatientFileID scopes a client-panel event (docs/39 PR12) to the
	// exact kartoteka the Flutter listener should refresh. Empty for the
	// session-pipeline notifications, which carry SessionID instead.
	PatientFileID string
	CreatedAt     time.Time
}

// WriteInboxNotification creates a new doc under
// user_notifications/{uid}/inbox/{notifId}. We use the
// notification_deliveries.id as notifId so the Firestore doc is uniquely
// keyed by the same primary key as the audit row in PG — easy cross-link
// when debugging "why did this push happen?".
func (w *Writer) WriteInboxNotification(ctx context.Context, n InboxNotification) error {
	if w == nil || w.client == nil {
		return nil
	}
	path := fmt.Sprintf("user_notifications/%s/inbox/%s", n.FirebaseUID, n.NotificationID)
	doc := map[string]any{
		"notificationId":   n.NotificationID,
		"notificationType": n.NotificationType,
		"title":            n.Title,
		"body":             n.Body,
		"sessionId":        n.SessionID,
		"createdAt":        fs.ServerTimestamp,
		// readAt intentionally omitted — Flutter sets it; rules permit
		// only that field to be modified by the user.
	}
	if n.PatientFileID != "" {
		doc["patientFileId"] = n.PatientFileID
	}
	_, err := w.client.Doc(path).Set(ctx, doc)
	if err != nil {
		slog.Warn("firestore inbox notification write failed",
			"firebase_uid", n.FirebaseUID, "notif_id", n.NotificationID, "error", err)
		return fmt.Errorf("firestore inbox: %w", err)
	}
	return nil
}
