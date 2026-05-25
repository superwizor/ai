// Package postgres holds the notification-svc database adapter. We use raw
// pgx (not sqlc) here because:
//   - The query surface is small (~7 statements).
//   - The Cloud Functions worker (cmd/worker) and the Cloud Run server
//     (cmd/server) share a single store struct — keeping one style across the
//     module avoids the sqlc-vs-handwritten split that the rest of the
//     codebase has.
//   - Matches the inline-pgx pattern used by the Phase 2 stt-worker /
//     llm-worker (see services/ai-pipeline-svc/cmd/{stt,llm}-worker).
//
// Reference SQL with full commentary lives in queries/notifications.sql.
package postgres

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Store wraps a pgx pool with notification-svc query helpers. All methods
// take a Context and return errors verbatim — callers (gRPC server / Cloud
// Function worker) decide whether to map them to gRPC codes or just log.
type Store struct {
	Pool *pgxpool.Pool
}

func New(pool *pgxpool.Pool) *Store {
	return &Store{Pool: pool}
}

// ---------- users ----------

// User is the slim view we need from the users table.
type User struct {
	ID             uuid.UUID
	FirebaseUID    string
	Role           string
	OrganizationID *uuid.UUID
}

// LookupUserByFirebaseUID resolves Firebase UID → users row. Returns
// pgx.ErrNoRows when the user has not been registered yet (caller maps this
// to UNAUTHENTICATED — auth-without-account).
func (s *Store) LookupUserByFirebaseUID(ctx context.Context, fbUID string) (*User, error) {
	var u User
	var orgID *uuid.UUID
	err := s.Pool.QueryRow(ctx, `
		SELECT id, firebase_uid, role, organization_id
		FROM users
		WHERE firebase_uid = $1 AND deleted_at IS NULL`,
		fbUID).Scan(&u.ID, &u.FirebaseUID, &u.Role, &orgID)
	if err != nil {
		return nil, err
	}
	u.OrganizationID = orgID
	return &u, nil
}

// ---------- sessions (worker side) ----------

type SessionForNotification struct {
	SessionID            uuid.UUID
	TherapistID          uuid.UUID
	PatientFileID        uuid.UUID
	SessionDate          time.Time
	SessionStatus        string
	TherapistFirebaseUID string
	TherapistLocale      string
}

// LoadSessionForNotification loads everything the worker needs to send a
// push for a session: the therapist's Firebase UID (for Firestore doc
// addressing) plus their preferred locale (for FCM body localization).
// Locale falls back to architecture default 'pl-PL'.
func (s *Store) LoadSessionForNotification(ctx context.Context, sessionID uuid.UUID) (*SessionForNotification, error) {
	var out SessionForNotification
	err := s.Pool.QueryRow(ctx, `
		SELECT
		    s.id, s.therapist_id, s.patient_file_id, s.session_date,
		    s.status, u.firebase_uid,
		    -- ui_language is short-form ('pl', 'en'); BCP-47 expansion happens
		    -- in the worker locale helper, not in SQL.
		    COALESCE(u.ui_language, 'pl')
		FROM sessions s
		JOIN users u ON u.id = s.therapist_id
		WHERE s.id = $1 AND s.deleted_at IS NULL`,
		sessionID,
	).Scan(
		&out.SessionID, &out.TherapistID, &out.PatientFileID, &out.SessionDate,
		&out.SessionStatus, &out.TherapistFirebaseUID, &out.TherapistLocale,
	)
	if err != nil {
		return nil, err
	}
	return &out, nil
}

// ---------- fcm_tokens ----------

type FCMToken struct {
	ID       uuid.UUID
	Token    string
	Platform string
	Locale   *string
}

// ListActiveFCMTokensByUser returns up to 10 active tokens per user, most
// recently used first. The 10-cap protects against runaway accumulation
// (FCM SendMulticast itself supports 500).
func (s *Store) ListActiveFCMTokensByUser(ctx context.Context, userID uuid.UUID) ([]FCMToken, error) {
	rows, err := s.Pool.Query(ctx, `
		SELECT id, token, platform, locale
		FROM fcm_tokens
		WHERE user_id = $1 AND invalidated_at IS NULL
		ORDER BY last_used_at DESC
		LIMIT 10`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []FCMToken
	for rows.Next() {
		var t FCMToken
		var locale *string
		if err := rows.Scan(&t.ID, &t.Token, &t.Platform, &locale); err != nil {
			return nil, err
		}
		t.Locale = locale
		out = append(out, t)
	}
	return out, rows.Err()
}

type UpsertFCMTokenParams struct {
	UserID      uuid.UUID
	Token       string
	Platform    string
	AppVersion  string
	DeviceModel string
	Locale      string
}

type UpsertFCMTokenResult struct {
	ID    uuid.UUID
	WasNew bool
}

// UpsertFCMToken is an idempotent register call. If the (user_id, token)
// pair is already present (and active), it updates last_used_at + metadata
// and returns WasNew=false; otherwise it inserts a fresh row and returns
// WasNew=true. The xmax=0 trick: postgres sets xmax to 0 only on raw
// INSERT, non-zero on UPDATE — so we can disambiguate without an extra
// roundtrip.
func (s *Store) UpsertFCMToken(ctx context.Context, p UpsertFCMTokenParams) (*UpsertFCMTokenResult, error) {
	var out UpsertFCMTokenResult
	// pgx quirk: passing empty strings as NULL is cleaner via NULLIF here,
	// but we keep them as-is so debugging is honest about what was sent.
	err := s.Pool.QueryRow(ctx, `
		INSERT INTO fcm_tokens
		    (user_id, token, platform, app_version, device_model, locale, last_used_at)
		VALUES ($1, $2, $3, NULLIF($4, ''), NULLIF($5, ''), NULLIF($6, ''), now())
		ON CONFLICT (user_id, token) WHERE invalidated_at IS NULL
		DO UPDATE SET
		    last_used_at = now(),
		    app_version  = COALESCE(EXCLUDED.app_version,  fcm_tokens.app_version),
		    device_model = COALESCE(EXCLUDED.device_model, fcm_tokens.device_model),
		    locale       = COALESCE(EXCLUDED.locale,       fcm_tokens.locale)
		RETURNING id, (xmax = 0)::bool`,
		p.UserID, p.Token, p.Platform, p.AppVersion, p.DeviceModel, p.Locale,
	).Scan(&out.ID, &out.WasNew)
	if err != nil {
		return nil, fmt.Errorf("upsert fcm_token: %w", err)
	}
	return &out, nil
}

// InvalidateFCMToken soft-deletes a single token. Called by the worker on
// FCM NotRegistered / InvalidArgument response.
func (s *Store) InvalidateFCMToken(ctx context.Context, tokenID uuid.UUID, reason string) error {
	_, err := s.Pool.Exec(ctx, `
		UPDATE fcm_tokens
		SET invalidated_at = now(), invalidated_reason = $2
		WHERE id = $1 AND invalidated_at IS NULL`,
		tokenID, reason)
	return err
}

// RemoveFCMTokenByValue is what the gRPC server calls on user logout. It is
// idempotent — already-invalidated tokens are simply skipped (WHERE clause
// filters them out).
func (s *Store) RemoveFCMTokenByValue(ctx context.Context, userID uuid.UUID, token string) error {
	_, err := s.Pool.Exec(ctx, `
		UPDATE fcm_tokens
		SET invalidated_at = now(), invalidated_reason = 'user_logout'
		WHERE user_id = $1 AND token = $2 AND invalidated_at IS NULL`,
		userID, token)
	return err
}

// ---------- notification_deliveries ----------

type InsertDeliveryParams struct {
	UserID           uuid.UUID
	SessionID        *uuid.UUID
	NotificationType string
	IdempotencyKey   string
	TargetTokenID    *uuid.UUID
}

// InsertNotificationDelivery is the idempotency gate. Returns the new row's
// ID on first insert; ErrAlreadyDelivered when the idempotency_key is
// already present — callers MUST short-circuit on that error and ACK
// Pub/Sub without resending FCM.
var ErrAlreadyDelivered = errors.New("notification already delivered (idempotency_key conflict)")

func (s *Store) InsertNotificationDelivery(ctx context.Context, p InsertDeliveryParams) (uuid.UUID, error) {
	var id uuid.UUID
	err := s.Pool.QueryRow(ctx, `
		INSERT INTO notification_deliveries
		    (user_id, session_id, notification_type, idempotency_key, status, target_token_id)
		VALUES ($1, $2, $3, $4, 'queued', $5)
		ON CONFLICT (idempotency_key) DO NOTHING
		RETURNING id`,
		p.UserID, p.SessionID, p.NotificationType, p.IdempotencyKey, p.TargetTokenID,
	).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return uuid.Nil, ErrAlreadyDelivered
		}
		return uuid.Nil, fmt.Errorf("insert delivery: %w", err)
	}
	return id, nil
}

type UpdateDeliveryStatusParams struct {
	ID           uuid.UUID
	Status       string
	FCMMessageID *string
	ErrorCode    *string
	ErrorMessage *string
}

func (s *Store) UpdateNotificationDeliveryStatus(ctx context.Context, p UpdateDeliveryStatusParams) error {
	// $2 is referenced twice in the statement — once as the value
	// written to the `status` column (type: notification_status enum),
	// and once inside a CASE expression compared against the text
	// literal 'sent'. Without explicit casts, pgx fails type inference
	// with: ERROR: inconsistent types deduced for parameter $2
	// (SQLSTATE 42P08). Casting both occurrences pins the type to the
	// enum and lets Postgres coerce the literal 'sent' through the
	// enum's implicit text-from-enum cast.
	_, err := s.Pool.Exec(ctx, `
		UPDATE notification_deliveries
		SET status         = $2::notification_status,
		    fcm_message_id = $3,
		    error_code     = $4,
		    error_message  = $5,
		    sent_at        = CASE WHEN $2::notification_status = 'sent'::notification_status
		                            THEN now()
		                            ELSE sent_at
		                     END
		WHERE id = $1`,
		p.ID, p.Status, p.FCMMessageID, p.ErrorCode, p.ErrorMessage)
	return err
}

// GetUnreadNotificationCount is a coarse audit count for badge support.
// Production-grade: query Firestore (the source of truth for inbox readAt
// state). This count looks only at sent deliveries and is for diagnostics —
// Flutter gets the live count via its Firestore listener.
func (s *Store) GetUnreadNotificationCount(ctx context.Context, userID uuid.UUID) (int64, error) {
	var n int64
	err := s.Pool.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM notification_deliveries
		WHERE user_id = $1 AND status = 'sent'`,
		userID).Scan(&n)
	return n, err
}
