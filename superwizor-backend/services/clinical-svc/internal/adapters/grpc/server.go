package grpc

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
	"github.com/superwizor-ai/backend/pkg/analytics"
	"github.com/superwizor-ai/backend/pkg/cryptobox"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/chat"
)

// SessionEventPublisher is the publish-side dependency clinical-svc
// uses to emit cross-service events (currently only session.deleted).
// Kept as an interface so we don't hard-link to the Pub/Sub SDK in
// the gRPC layer — production wires a concrete pubsub.Publisher, and
// tests pass a stub that records calls. Nil is allowed; handlers
// short-circuit the publish when it's not set (e.g. during local dev
// without Pub/Sub creds).
type SessionEventPublisher interface {
	PublishSessionDeleted(ctx context.Context, sessionID, therapistID string) error
	// PublishSessionStatusChanged mirrors a lifecycle status to Firestore
	// via session.status_changed (docs/21). Used for "cancelled".
	PublishSessionStatusChanged(ctx context.Context, sessionID, status string) error
	PublishAnalyticsEvent(ctx context.Context, event analytics.Event) error
}

// TxOpener abstracts "start a transaction, give me a Querier scoped to
// it." Production wires this to pgxpool+*db.Queries; tests pass a fake
// that records the Commit/Rollback calls. Returning Querier (interface)
// rather than *db.Queries keeps the seam fully mockable. Handlers that
// don't open transactions (Update*, simple Delete*) don't touch this —
// they go through Server.queries directly.
type TxOpener interface {
	Begin(ctx context.Context) (Tx, error)
}

// Tx is the transactional handle TxOpener.Begin returns. Queries()
// gives the tx-scoped Querier; Commit/Rollback do exactly what they
// say on the tin. Idiomatic pgx semantics — Rollback after a successful
// Commit is a no-op error that callers ignore with a deferred call.
//
// Raw exposes the underlying pgx.Tx for the few places that still need
// raw SQL (today: labels.go's transcript_segments speaker-label lookup
// — no sqlc query exists for that one-off SELECT, and creating one
// just to satisfy the abstraction would be ceremony). Tests that don't
// exercise the labels handler can return nil from Raw.
type Tx interface {
	Queries() db.Querier
	Raw() pgx.Tx
	Commit(ctx context.Context) error
	Rollback(ctx context.Context) error
}

// pgxTxOpener is the production wiring: open a pgx tx on the pool and
// hand back a Querier scoped to it via sqlc's WithTx.
type pgxTxOpener struct {
	pool *pgxpool.Pool
	base *db.Queries
}

func (p *pgxTxOpener) Begin(ctx context.Context) (Tx, error) {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	return &pgxTx{tx: tx, q: p.base.WithTx(tx)}, nil
}

type pgxTx struct {
	tx pgx.Tx
	q  *db.Queries
}

func (t *pgxTx) Queries() db.Querier              { return t.q }
func (t *pgxTx) Raw() pgx.Tx                      { return t.tx }
func (t *pgxTx) Commit(ctx context.Context) error { return t.tx.Commit(ctx) }
func (t *pgxTx) Rollback(ctx context.Context) error {
	return t.tx.Rollback(ctx)
}

type Server struct {
	clinicalv1.UnimplementedClinicalServiceServer
	queries  db.Querier
	tx       TxOpener
	identity identityv1.IdentityServiceClient
	billing  billingv1.BillingServiceClient // nil = GetMyBillingState returns Unavailable
	// notification is the upstream NotificationServiceClient used by
	// SavePatientNote to e-mail an action plan to the patient. nil =
	// NOTIFICATION_SVC_URL unset (local dev) → the send leg returns
	// Unavailable("EMAIL_NOT_CONFIGURED"); the note is still saved.
	notification notificationv1.NotificationServiceClient
	// panelURL is the login link embedded in PHI-free client-panel
	// notifications (docs/39 PR9). Empty = default set by WithPanelURL /
	// main.go's PANEL_URL_BASE.
	panelURL  string
	crypto    cryptobox.CryptoBox
	pubsub    SessionEventPublisher
	version   string
	collector *analytics.Collector
	// chat runs the guardrailed AI chat. nil = the feature is not
	// wired in this build, and AskPatientQuestion returns
	// FEATURE_DISABLED. Every existing test constructor leaves it nil,
	// which is the correct default: a chat that answers must be
	// deliberately switched on.
	chat *chat.Service
}

// WithChat injects the AI chat service. Post-construction option rather
// than a NewServer parameter so every existing test constructor keeps
// compiling with the chat absent — which is also the safe default.
func (s *Server) WithChat(c *chat.Service) *Server {
	s.chat = c
	return s
}

// WithNotification injects the notification-svc client. Kept as a
// post-construction option (rather than a NewServerWithDeps param) so the
// existing test constructors keep compiling unchanged. Production wires
// it from cmd/server/main.go via NewServer.
func (s *Server) WithNotification(n notificationv1.NotificationServiceClient) *Server {
	s.notification = n
	return s
}

// WithPanelURL sets the app login link used by the PHI-free client-panel
// notifications (docs/39 PR9). Same post-construction-option pattern as
// WithNotification. Empty input keeps the previous value.
func (s *Server) WithPanelURL(u string) *Server {
	if u != "" {
		s.panelURL = u
	}
	return s
}

// NewServer wires the production gRPC server: pgxpool + concrete sqlc
// Queries get wrapped behind the Querier+TxOpener interfaces so the
// handler code never sees the pool directly. Tests construct Server
// fields directly via NewServerWithDeps.
//
// `billing` is the upstream BillingServiceClient used by GetMyBillingState
// to proxy through to billing-svc.GetSubscription. Pass nil for tests
// or environments where billing-svc isn't wired — GetMyBillingState
// will respond with Unavailable in that case.
func NewServer(dbPool *pgxpool.Pool, queries *db.Queries, identity identityv1.IdentityServiceClient, billing billingv1.BillingServiceClient, notification notificationv1.NotificationServiceClient, crypto cryptobox.CryptoBox, pubsub SessionEventPublisher, version string, collector *analytics.Collector) *Server {
	return &Server{
		queries:      queries,
		tx:           &pgxTxOpener{pool: dbPool, base: queries},
		identity:     identity,
		billing:      billing,
		notification: notification,
		panelURL:     defaultPanelURL,
		crypto:       crypto,
		pubsub:       pubsub,
		version:      version,
		collector:    collector,
	}
}

// defaultPanelURL is where the Flutter web app (and therefore the client
// panel) lives; overridable per environment via PANEL_URL_BASE.
const defaultPanelURL = "https://superwizor-app.web.app/"

// NewServerWithDeps is the test-friendly constructor — every interface
// dependency is explicit so tests can inject fakes. Production code
// uses NewServer; this exists purely to keep test files honest about
// what they're stubbing.
func NewServerWithDeps(queries db.Querier, tx TxOpener, identity identityv1.IdentityServiceClient, billing billingv1.BillingServiceClient, crypto cryptobox.CryptoBox, pubsub SessionEventPublisher, version string, collector *analytics.Collector) *Server {
	return &Server{
		queries:   queries,
		tx:        tx,
		identity:  identity,
		billing:   billing,
		crypto:    crypto,
		pubsub:    pubsub,
		version:   version,
		collector: collector,
	}
}

func (s *Server) HealthCheck(ctx context.Context, _ *emptypb.Empty) (*clinicalv1.HealthCheckResponse, error) {
	return &clinicalv1.HealthCheckResponse{
		Status:  "OK",
		Version: s.version,
	}, nil
}

func (s *Server) ListModalities(ctx context.Context, _ *emptypb.Empty) (*clinicalv1.ListModalitiesResponse, error) {
	modalities, err := s.queries.ListSupportedModalities(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	resp := &clinicalv1.ListModalitiesResponse{}
	for _, m := range modalities {
		resp.Modalities = append(resp.Modalities, &clinicalv1.Modality{
			Id:          m.ID.String(),
			SystemCode:  m.SystemCode,
			DisplayName: m.DisplayName,
			IsSupported: m.IsSupported,
			// "therapy" | "coaching" — migration 000026. Drives
			// llm-worker's role-label vocabulary; Flutter doesn't
			// branch on it yet but the field is exposed for future
			// UI cues ("Coaching" badge on cards, etc.).
			ModalityType: string(m.ModalityType),
		})
	}
	return resp, nil
}

func (s *Server) CreatePatientFile(ctx context.Context, req *clinicalv1.CreatePatientFileRequest) (*clinicalv1.PatientFile, error) {
	therapistIDStr, ok := ctx.Value(UserIDKey).(string)
	if !ok || therapistIDStr == "" {
		return nil, status.Error(codes.Unauthenticated, "missing user ID in context")
	}
	therapistID, err := uuid.Parse(therapistIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id in context")
	}
	if req.WorkingAlias == "" || req.ModalityCode == "" {
		return nil, status.Error(codes.InvalidArgument, "working_alias and modality_code required")
	}
	// patient_first_name/last_name/patient_email are accepted for wire
	// compat with older app builds but IGNORED (docs/43 §4: working_alias
	// is the kartoteka's only identifier; the client's e-mail lives in
	// the identity domain — invitations/users — never on the kartoteka).

	// Idempotency pre-check (migration 000017). Empty key opts out —
	// legacy clients keep their current "always create" semantics.
	// Non-empty key: if we've already created a kartoteka for this
	// (therapist_id, idempotency_key) pair, short-circuit and return
	// the cached row. Critical: this MUST run before the audit write
	// below and before any side-effect (CreatePatientUser, etc.) so
	// replays don't double-write.
	if req.IdempotencyKey != "" {
		existing, gerr := s.queries.GetPatientFileByIdempotency(ctx,
			db.GetPatientFileByIdempotencyParams{
				TherapistID:    therapistID,
				IdempotencyKey: &req.IdempotencyKey,
			})
		if gerr == nil {
			// Found — return cached row. Need modality + patient-user
			// fields to reconstruct the response in the same shape as
			// the first call returned. GetPatientFileWithUser does the
			// JOIN we need; cheaper than re-running GetModalityByCode
			// + GetPatientUser separately.
			row, werr := s.queries.GetPatientFileWithUser(ctx, existing.ID)
			if werr != nil {
				return nil, status.Errorf(codes.Internal, "idempotency replay fetch: %v", werr)
			}
			return toProtoPatientFileFromJoinRow(row, ""), nil
		}
		// pgx.ErrNoRows is the expected "first call" path. Any other
		// error is a real DB failure — surface it.
		if !errors.Is(gerr, pgx.ErrNoRows) {
			return nil, status.Errorf(codes.Internal, "idempotency lookup: %v", gerr)
		}
	}

	// Resolve modality
	modality, err := s.queries.GetModalityByCode(ctx, req.ModalityCode)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "unknown modality: %s", req.ModalityCode)
	}

	// Map process type
	dbProcessType := db.ProcessType("INDIVIDUAL")
	switch req.ProcessType {
	case clinicalv1.ProcessType_PROCESS_TYPE_COUPLE:
		dbProcessType = "COUPLE"
	case clinicalv1.ProcessType_PROCESS_TYPE_FAMILY:
		dbProcessType = "FAMILY"
	case clinicalv1.ProcessType_PROCESS_TYPE_GROUP:
		dbProcessType = "GROUP"
	}

	// Resolve patient language: explicit request value, else inherit
	// the therapist's ui_language (the kartoteka's "default world"
	// language). Falls back to 'pl' if the therapist row somehow
	// lacks one (defensive; should never fire because identity-svc
	// seeds 'pl' on register).
	patientLang := req.PatientLanguageCode
	if patientLang == "" {
		if ulang, err := s.queries.GetTherapistUILanguage(ctx, therapistID); err == nil && ulang != "" {
			patientLang = ulang
		} else {
			patientLang = "pl"
		}
	}

	// Run user-insert + patient_file-insert in one tx so we never end
	// up with an orphan user (insert succeeded) without a kartoteka.
	tx, err := s.tx.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "begin tx: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }() // no-op on commit
	qtx := tx.Queries()

	patientUserID, err := qtx.CreatePatientUser(ctx, patientLang)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "create patient user: %v", err)
	}

	var idempotencyKeyPtr *string
	if req.IdempotencyKey != "" {
		idempotencyKeyPtr = &req.IdempotencyKey
	}

	pf, err := qtx.CreatePatientFile(ctx, db.CreatePatientFileParams{
		TherapistID:         therapistID,
		PatientID:           pgtype.UUID{Bytes: patientUserID, Valid: true},
		ModalityID:          modality.ID,
		WorkingAlias:        req.WorkingAlias,
		ProcessType:         dbProcessType,
		InitialComplaint:    &req.InitialComplaint,
		HasRecordingConsent: req.HasRecordingConsent,
		IdempotencyKey:      idempotencyKeyPtr,
	})
	if err != nil {
		// Two distinct unique-violation paths land here. Disambiguate
		// by constraint name (pgconn surfaces it via PgError) so the
		// caller gets a useful error.
		if cname := uniqueViolationConstraint(err); cname != "" {
			switch cname {
			case "ux_patient_files_idempotency":
				// Race: another goroutine won the (therapist_id,
				// idempotency_key) insert between our pre-check and
				// this INSERT. Roll back, re-fetch, return cached.
				_ = tx.Rollback(ctx)
				existing, gerr := s.queries.GetPatientFileByIdempotency(ctx,
					db.GetPatientFileByIdempotencyParams{
						TherapistID:    therapistID,
						IdempotencyKey: &req.IdempotencyKey,
					})
				if gerr != nil {
					return nil, status.Errorf(codes.Internal, "idempotency race refetch: %v", gerr)
				}
				row, werr := s.queries.GetPatientFileWithUser(ctx, existing.ID)
				if werr != nil {
					return nil, status.Errorf(codes.Internal, "idempotency race fetch full: %v", werr)
				}
				return toProtoPatientFileFromJoinRow(row, ""), nil
			default:
				// Default behavior: (therapist_id, working_alias) is the
				// other partial unique index. Surface as AlreadyExists so
				// Flutter can show "this alias is taken".
				return nil, status.Errorf(codes.AlreadyExists,
					"working_alias %q already used by another active kartoteka", req.WorkingAlias)
			}
		}
		return nil, status.Errorf(codes.Internal, "create patient_file: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	// Analityka: patient_file.created
	var orgIDPtr *uuid.UUID
	orgIDPg, errOrg := s.queries.GetUserOrganizationID(ctx, therapistID)
	if errOrg == nil && orgIDPg.Valid {
		id := uuid.UUID(orgIDPg.Bytes)
		orgIDPtr = &id
	}

	s.trackEvent(ctx, analytics.Event{
		Name:           "patient_file.created",
		TherapistID:    &therapistID,
		OrganizationID: orgIDPtr,
		PatientFileID:  &pf.ID,
		Properties: map[string]any{
			"modality_code": req.ModalityCode,
			"process_type":  req.ProcessType.String(),
		},
		Source: "server",
	})

	// Audit log (async w produkcji; synchroniczne w MVP). No working_alias
	// here: audit metadata stays free of client identifiers (docs/43 §4) —
	// the resource UUID is enough to correlate.
	auditMeta, _ := json.Marshal(map[string]any{
		"modality_code": modality.SystemCode,
	})
	_ = s.queries.CreateAuditEvent(ctx, db.CreateAuditEventParams{
		ActorUserID:  pgtype.UUID{Bytes: therapistID, Valid: true},
		Action:       "patient_file.create",
		ResourceType: "patient_file",
		ResourceID:   pgtype.UUID{Bytes: pf.ID, Valid: true},
		Metadata:     auditMeta,
	})

	// We already have all the inputs needed to populate the response;
	// no second SELECT required. FirstConsultationAt stays zero —
	// the insert didn't set it. ConsentGivenAt is set by the SQL CASE
	// when has_recording_consent=true and emitted by the mapper.
	resp := toProtoPatientFile(pf, modality.SystemCode)
	resp.PatientLanguageCode = patientLang
	return resp, nil
}

// isUniqueViolation returns true if err is a PG SQLSTATE 23505
// (unique_violation). Used by Create/UpdatePatientFile to translate
// the partial unique index ux_patient_files_therapist_alias trip
// into AlreadyExists rather than a generic Internal.
func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return pgErr.Code == pgerrcode.UniqueViolation
	}
	return false
}

// uniqueViolationConstraint returns the violated constraint's name
// for SQLSTATE 23505 errors, or "" if err isn't a unique violation.
// Used to disambiguate the two partial unique indexes on patient_files
// (working_alias vs idempotency_key) inside CreatePatientFile so the
// race-window catch can route correctly. Surface area kept narrow:
// callers don't need to know about pgconn internals.
func uniqueViolationConstraint(err error) string {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == pgerrcode.UniqueViolation {
		return pgErr.ConstraintName
	}
	return ""
}

func (s *Server) GetPatientFile(ctx context.Context, req *clinicalv1.GetPatientFileRequest) (*clinicalv1.PatientFile, error) {
	id, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}
	row, err := s.queries.GetPatientFileWithUser(ctx, id)
	if err != nil {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	// Object-level authz (IDOR fix): only the owning therapist (or an
	// ORG_ADMIN of their org / SUPERWIZOR_ADMIN) may read this kartoteka.
	if err := s.requireTherapistDataAccess(ctx, row.TherapistID); err != nil {
		return nil, err
	}
	return toProtoPatientFileFromJoinRow(row, ""), nil
}

func (s *Server) ListPatientFiles(ctx context.Context, req *clinicalv1.ListPatientFilesRequest) (*clinicalv1.ListPatientFilesResponse, error) {
	therapistIDStr, ok := ctx.Value(UserIDKey).(string)
	if !ok || therapistIDStr == "" {
		return nil, status.Error(codes.Unauthenticated, "missing user ID in context")
	}
	therapistID, err := uuid.Parse(therapistIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id in context")
	}
	pageSize := req.PageSize
	if pageSize <= 0 || pageSize > 100 {
		pageSize = 25
	}
	files, err := s.queries.ListPatientFilesByTherapistWithUser(ctx, db.ListPatientFilesByTherapistWithUserParams{
		TherapistID: therapistID,
		Limit:       pageSize,
		Offset:      0, // simple paging w MVP, page_token w Fazie 2
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	resp := &clinicalv1.ListPatientFilesResponse{}
	for _, row := range files {
		resp.PatientFiles = append(resp.PatientFiles,
			toProtoPatientFileFromListJoinRow(row, ""))
	}
	return resp, nil
}

// UpdatePatientFile edits kartoteka-side fields (working_alias,
// initial_complaint, private_therapist_notes, is_process_closed).
// Patient-user fields are NOT touched here — therapist edits them
// via UpdatePatientUser. The two surfaces are kept independent so
// a rename of the kartoteka label doesn't accidentally rewrite the
// patient's stored PII.
//
// Translates the partial unique index trip on (therapist_id,
// working_alias) into AlreadyExists so Flutter can surface a clean
// "alias already in use" error rather than a generic Internal.
func (s *Server) UpdatePatientFile(ctx context.Context, req *clinicalv1.UpdatePatientFileRequest) (*clinicalv1.PatientFile, error) {
	id, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}
	// Object-level authz (IDOR fix): confirm ownership BEFORE mutating the
	// kartoteka — otherwise any caller could edit any therapist's record.
	pf, err := s.queries.GetPatientFile(ctx, id)
	if err != nil {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	if err := s.requireTherapistDataAccess(ctx, pf.TherapistID); err != nil {
		return nil, err
	}

	if _, err := s.queries.UpdatePatientFile(ctx, db.UpdatePatientFileParams{
		ID:              id,
		Column2:         req.WorkingAlias,
		Column3:         req.InitialComplaint,
		Column4:         req.PrivateTherapistNotes,
		IsProcessClosed: req.IsProcessClosed,
		Column6:         req.LifecycleStatus,
	}); err != nil {
		if isUniqueViolation(err) {
			return nil, status.Errorf(codes.AlreadyExists,
				"working_alias %q already used by another active kartoteka", req.WorkingAlias)
		}
		return nil, status.Errorf(codes.Internal, "update patient_file: %v", err)
	}

	// Re-read with user JOIN so the response carries fresh PII +
	// the updated kartoteka fields together.
	row, err := s.queries.GetPatientFileWithUser(ctx, id)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "refetch after update: %v", err)
	}
	return toProtoPatientFileFromJoinRow(row, ""), nil
}

// UpdatePatientUser edits the paired users(role='PATIENT') row.
// Identified by patient_file_id (the kartoteka's id) so the ownership
// check uses the standard therapist_id predicate — patient users
// themselves have no auth metadata yet.
//
// Empty string in any field = no change (SQL-side COALESCE/NULLIF).
// Returns the refreshed PatientFile with the new user fields so the
// Flutter side can re-render in one hop.
func (s *Server) UpdatePatientUser(ctx context.Context, req *clinicalv1.UpdatePatientUserRequest) (*clinicalv1.PatientFile, error) {
	therapistIDStr, ok := ctx.Value(UserIDKey).(string)
	if !ok || therapistIDStr == "" {
		return nil, status.Error(codes.Unauthenticated, "missing user ID in context")
	}
	therapistID, err := uuid.Parse(therapistIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id in context")
	}

	pfID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}

	// Authz + resolve patient_id in one fetch. Treat a not-found OR
	// a wrong-therapist row as 404 to avoid leaking ownership.
	pf, err := s.queries.GetPatientFile(ctx, pfID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	if pf.TherapistID != therapistID {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	// Since migration 000077 the kartoteka stores NO client e-mail and
	// the users row stores NO client names (docs/43 §4) — patient_email
	// is accepted for wire compat with older app builds and IGNORED
	// (the client's e-mail lives in the identity domain).
	//
	// Deprecated first_name/last_name are NOT silently dropped though:
	// pre-invariant builds edit the patient "name" through these fields
	// and show no error on success, so ignoring them silently loses the
	// therapist's edit ("Daję zapisz i nic się nie zmienia", 2026-07-18).
	// Map the legacy intent onto working_alias — the exact string those
	// builds render after their alias-split display fallback. New builds
	// never send names here (they edit the alias via UpdatePatientFile),
	// so this path is inert for them.
	//nolint:staticcheck // SA1019: deliberate read of the deprecated fields — this IS the legacy-compat path
	if legacyAlias := strings.TrimSpace(strings.TrimSpace(req.FirstName) + " " + strings.TrimSpace(req.LastName)); legacyAlias != "" {
		if err := s.queries.SetWorkingAlias(ctx, db.SetWorkingAliasParams{
			ID:           pfID,
			WorkingAlias: legacyAlias,
		}); err != nil {
			if isUniqueViolation(err) {
				return nil, status.Errorf(codes.AlreadyExists,
					"working_alias %q already used by another active kartoteka", legacyAlias)
			}
			return nil, status.Errorf(codes.Internal, "set working alias: %v", err)
		}
	}

	// Only the patient's UI language remains editable on the users row.
	if pf.PatientID.Valid {
		if _, err := s.queries.UpdatePatientUser(ctx, db.UpdatePatientUserParams{
			ID:           uuid.UUID(pf.PatientID.Bytes),
			LanguageCode: req.LanguageCode,
		}); err != nil {
			return nil, status.Errorf(codes.Internal, "update patient user: %v", err)
		}
	}

	// Re-read with JOIN so the response carries the now-current
	// user fields alongside the unchanged kartoteka fields.
	row, err := s.queries.GetPatientFileWithUser(ctx, pfID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "refetch after update: %v", err)
	}
	return toProtoPatientFileFromJoinRow(row, ""), nil
}

// DeletePatientUser performs RODO-style full erasure for a patient.
// Deletes the users row; migration 000014 makes patient_files.patient_id
// CASCADE, so every kartoteka under this patient — plus its sessions,
// transcripts, reports, hitop measurements, audio_uploads,
// rag_memories — goes away in one statement.
//
// Identified by patient_file_id (the entry point the therapist UI has).
// Authz: standard therapist-ownership check on the kartoteka. Since one
// patient can technically have multiple patient_files under different
// therapists, we ONLY use the request's kartoteka to find the
// patient_id; the cascade then takes out every patient_file under that
// user, even those owned by other therapists. This is acceptable
// because:
//   - in MVP each patient has exactly one therapist (1:1 patient_file)
//   - the action is gated by RODO right-to-erasure — once a patient
//     asks to be forgotten, all their data goes, regardless of which
//     therapist's kartoteka holds it
//
// Cleanup steps:
//  1. Pre-fetch every session_id that will be cascade-deleted, so
//     we can fan out session.deleted Pub/Sub events afterwards.
//     The cascade itself emits no application signal.
//  2. DELETE FROM users — cascade does the rest server-side.
//  3. Publish session.deleted events (best-effort; failures don't
//     block — PG is authoritative).
func (s *Server) DeletePatientUser(ctx context.Context, req *clinicalv1.DeletePatientUserRequest) (*emptypb.Empty, error) {
	therapistIDStr, ok := ctx.Value(UserIDKey).(string)
	if !ok || therapistIDStr == "" {
		return nil, status.Error(codes.Unauthenticated, "missing user ID in context")
	}
	therapistID, err := uuid.Parse(therapistIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id in context")
	}

	pfID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}

	pf, err := s.queries.GetPatientFile(ctx, pfID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	if pf.TherapistID != therapistID {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	if !pf.PatientID.Valid {
		// No user attached to wipe. Treat as no-op success — the
		// kartoteka itself can still be removed via DeletePatientFile.
		return &emptypb.Empty{}, nil
	}
	patientUserID := uuid.UUID(pf.PatientID.Bytes)

	// Pre-fetch session IDs under this patient (across all their
	// kartoteki) so we can fan out session.deleted events after the
	// cascade fires.
	sessionIDs, err := s.queries.ListSessionIDsForPatient(ctx, pf.PatientID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list patient sessions: %v", err)
	}

	// Single DELETE — FK CASCADE (000014) handles everything below.
	if _, err := s.queries.DeletePatientUser(ctx, patientUserID); err != nil {
		return nil, status.Errorf(codes.Internal, "delete patient user: %v", err)
	}

	// Fan out cleanup events for the cascaded sessions. Independent
	// publish per session — one failure doesn't block the rest.
	if s.pubsub != nil {
		for _, sid := range sessionIDs {
			if err := s.pubsub.PublishSessionDeleted(ctx, sid.String(), therapistID.String()); err != nil {
				slog.Warn("publish session.deleted (from patient user delete) failed",
					"session_id", sid, "patient_user_id", patientUserID, "error", err)
			}
		}
	}

	return &emptypb.Empty{}, nil
}

// DeletePatientFile hard-deletes a kartoteka (since migration 000012):
// cascades through audio_uploads, sessions, transcripts, reports,
// hitop_measurements. PHI gone permanently — backs RODO right-to-erasure.
//
// Authz happens at the SQL layer (HardDeletePatientFile predicate
// `WHERE id = $1 AND therapist_id = $2`). We still resolve therapist_id
// from the ctx auth interceptor first so we can list session_ids for
// the Pub/Sub fan-out, and so we don't accidentally delete a row that
// belongs to a different therapist via a misconfigured query.
//
// Fan-out: one session.deleted event per session that lived under this
// patient_file. notification-svc picks them up and wipes the Firestore
// session_states/{id} mirror + per-user inbox notifications.
// Best-effort — a failed publish is logged but doesn't unwind the
// hard delete (PG is the source of truth; the mirror eventually
// reconciles via stale-doc TTL).
func (s *Server) DeletePatientFile(ctx context.Context, req *clinicalv1.DeletePatientFileRequest) (*emptypb.Empty, error) {
	therapistIDStr, ok := ctx.Value(UserIDKey).(string)
	if !ok || therapistIDStr == "" {
		return nil, status.Error(codes.Unauthenticated, "missing user ID in context")
	}
	therapistID, err := uuid.Parse(therapistIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id in context")
	}

	id, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}

	// Pre-fetch: (a) session IDs for Pub/Sub fan-out (sessions go
	// on cascade so we'd lose them after HardDelete), (b) patient_id
	// so we can drop the paired users row in the same transaction.
	sessionIDs, err := s.queries.ListSessionIDsForPatientFile(ctx, id)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list session ids: %v", err)
	}
	pf, err := s.queries.GetPatientFile(ctx, id)
	if err != nil {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	if pf.TherapistID != therapistID {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}

	// Single transaction: kartoteka delete (cascades to sessions/
	// transcripts/etc.) + paired user delete. Ordering matters:
	// patient_files.patient_id is FK SET NULL since 000013, so
	// deleting the user first would just blank the patient_id on
	// the kartoteka. Deleting the kartoteka first then the user
	// avoids that race entirely.
	tx, err := s.tx.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "begin tx: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := tx.Queries()

	rows, err := qtx.HardDeletePatientFile(ctx, db.HardDeletePatientFileParams{
		ID:          id,
		TherapistID: therapistID,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "hard delete patient_file: %v", err)
	}
	if rows == 0 {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}

	if pf.PatientID.Valid {
		// :execrows ignored — patient row may have been deleted by
		// a concurrent DeletePatientUser; either way it's gone.
		if _, err := qtx.DeletePatientUser(ctx, uuid.UUID(pf.PatientID.Bytes)); err != nil {
			return nil, status.Errorf(codes.Internal, "delete patient user: %v", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	// Fan out cleanup events. Per-session because notification-svc's
	// handler is keyed on session_id (Firestore doc id). Each publish
	// is best-effort and independent — a single failure doesn't block
	// the rest, and PG is already committed.
	if s.pubsub != nil {
		for _, sid := range sessionIDs {
			if err := s.pubsub.PublishSessionDeleted(ctx, sid.String(), therapistID.String()); err != nil {
				slog.Warn("publish session.deleted (from patient_file delete) failed",
					"session_id", sid, "patient_file_id", id, "error", err)
			}
		}
	}

	return &emptypb.Empty{}, nil
}

// Helpers
//
// Three proto mappers share most of the field copies:
//   - toProtoPatientFile           — from the bare db.PatientFile (no user JOIN)
//   - toProtoPatientFileFromJoinRow      — from GetPatientFileWithUserRow
//   - toProtoPatientFileFromListJoinRow  — from ListPatientFilesByTherapistWithUserRow
// The two With-User variants extract language_code + the RESOLVED
// patient_email (users.email → latest non-revoked invitation, see
// migration 000077) from the LEFT JOINed nullable columns; empty
// strings when absent. patient_first_name/last_name are deprecated
// proto fields left at their zero value (docs/43 §4 — the kartoteka's
// only identifier is working_alias).

// toProtoPatientFileFromJoinRow emits a Modality system_code resolved
// from the modalities JOIN. The `modalityCodeOverride` argument is
// kept for backwards-compat with callers that already have a fresher
// value to splice in (none today, but keeping the seam for future
// transactional re-reads). Empty override means "use the JOINed value".
func toProtoPatientFileFromJoinRow(row db.GetPatientFileWithUserRow, modalityCodeOverride string) *clinicalv1.PatientFile {
	modalityCode := row.ModalityCode
	if modalityCodeOverride != "" {
		modalityCode = modalityCodeOverride
	}
	resp := &clinicalv1.PatientFile{
		Id:                  row.ID.String(),
		TherapistId:         row.TherapistID.String(),
		ModalityId:          row.ModalityID.String(),
		ModalityCode:        modalityCode,
		WorkingAlias:        row.WorkingAlias,
		ProcessType:         toProtoProcessType(row.ProcessType),
		IsProcessClosed:     row.IsProcessClosed,
		HasRecordingConsent: row.HasRecordingConsent,
		CreatedAt:           timestamppb.New(row.CreatedAt),
		UpdatedAt:           timestamppb.New(row.UpdatedAt),
	}
	if row.PatientID.Valid {
		resp.PatientId = uuid.UUID(row.PatientID.Bytes).String()
	}
	if row.InitialComplaint != nil {
		resp.InitialComplaint = *row.InitialComplaint
	}
	if row.PrivateTherapistNotes != nil {
		resp.PrivateTherapistNotes = *row.PrivateTherapistNotes
	}
	if row.PatientLanguageCode != nil {
		resp.PatientLanguageCode = *row.PatientLanguageCode
	}
	// patient_email is RESOLVED (users.email → latest invitation,
	// migration 000077), never stored on the kartoteka. nil → "".
	if row.PatientEmail != nil {
		resp.PatientEmail = *row.PatientEmail
	}
	// Nullable timestamps: pgtype.Timestamptz emits Valid=false when the
	// DB column is NULL (consent never given, or consent_given_at not
	// backfilled on a pre-fix row). Leave the proto field zero in that
	// case so Flutter's timestamppb.Valid checks treat it as absent.
	if row.ConsentGivenAt.Valid {
		resp.ConsentGivenAt = timestamppb.New(row.ConsentGivenAt.Time)
	}
	if row.FirstConsultationAt.Valid {
		resp.FirstConsultationAt = timestamppb.New(row.FirstConsultationAt.Time)
	}
	resp.LifecycleStatus = row.LifecycleStatus
	if len(row.AvatarConfig) > 0 {
		resp.AvatarConfig = string(row.AvatarConfig)
	}
	return resp
}

// toProtoPatientFileFromListJoinRow — list-side analogue of
// toProtoPatientFileFromJoinRow. modality_code comes from the JOIN;
// override arg kept for symmetry.
func toProtoPatientFileFromListJoinRow(row db.ListPatientFilesByTherapistWithUserRow, modalityCodeOverride string) *clinicalv1.PatientFile {
	modalityCode := row.ModalityCode
	if modalityCodeOverride != "" {
		modalityCode = modalityCodeOverride
	}
	resp := &clinicalv1.PatientFile{
		Id:                  row.ID.String(),
		TherapistId:         row.TherapistID.String(),
		ModalityId:          row.ModalityID.String(),
		ModalityCode:        modalityCode,
		WorkingAlias:        row.WorkingAlias,
		ProcessType:         toProtoProcessType(row.ProcessType),
		IsProcessClosed:     row.IsProcessClosed,
		HasRecordingConsent: row.HasRecordingConsent,
		CreatedAt:           timestamppb.New(row.CreatedAt),
		UpdatedAt:           timestamppb.New(row.UpdatedAt),
	}
	if row.PatientID.Valid {
		resp.PatientId = uuid.UUID(row.PatientID.Bytes).String()
	}
	if row.InitialComplaint != nil {
		resp.InitialComplaint = *row.InitialComplaint
	}
	if row.PrivateTherapistNotes != nil {
		resp.PrivateTherapistNotes = *row.PrivateTherapistNotes
	}
	if row.PatientLanguageCode != nil {
		resp.PatientLanguageCode = *row.PatientLanguageCode
	}
	if row.PatientEmail != nil {
		resp.PatientEmail = *row.PatientEmail
	}
	// See toProtoPatientFileFromJoinRow for the Valid-check rationale.
	if row.ConsentGivenAt.Valid {
		resp.ConsentGivenAt = timestamppb.New(row.ConsentGivenAt.Time)
	}
	if row.FirstConsultationAt.Valid {
		resp.FirstConsultationAt = timestamppb.New(row.FirstConsultationAt.Time)
	}
	resp.LifecycleStatus = row.LifecycleStatus
	if len(row.AvatarConfig) > 0 {
		resp.AvatarConfig = string(row.AvatarConfig)
	}
	return resp
}

func toProtoPatientFile(pf db.PatientFile, modalityCode string) *clinicalv1.PatientFile {
	resp := &clinicalv1.PatientFile{
		Id:                  pf.ID.String(),
		TherapistId:         pf.TherapistID.String(),
		ModalityId:          pf.ModalityID.String(),
		ModalityCode:        modalityCode,
		WorkingAlias:        pf.WorkingAlias,
		ProcessType:         toProtoProcessType(pf.ProcessType),
		IsProcessClosed:     pf.IsProcessClosed,
		HasRecordingConsent: pf.HasRecordingConsent,
		CreatedAt:           timestamppb.New(pf.CreatedAt),
		UpdatedAt:           timestamppb.New(pf.UpdatedAt),
	}
	if pf.PatientID.Valid {
		resp.PatientId = uuid.UUID(pf.PatientID.Bytes).String()
	}
	if pf.InitialComplaint != nil {
		resp.InitialComplaint = *pf.InitialComplaint
	}
	if pf.PrivateTherapistNotes != nil {
		resp.PrivateTherapistNotes = *pf.PrivateTherapistNotes
	}
	// See toProtoPatientFileFromJoinRow for the Valid-check rationale.
	if pf.ConsentGivenAt.Valid {
		resp.ConsentGivenAt = timestamppb.New(pf.ConsentGivenAt.Time)
	}
	if pf.FirstConsultationAt.Valid {
		resp.FirstConsultationAt = timestamppb.New(pf.FirstConsultationAt.Time)
	}
	resp.LifecycleStatus = pf.LifecycleStatus
	if len(pf.AvatarConfig) > 0 {
		resp.AvatarConfig = string(pf.AvatarConfig)
	}
	return resp
}

func toProtoProcessType(p db.ProcessType) clinicalv1.ProcessType {
	switch p {
	case "INDIVIDUAL":
		return clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL
	case "COUPLE":
		return clinicalv1.ProcessType_PROCESS_TYPE_COUPLE
	case "FAMILY":
		return clinicalv1.ProcessType_PROCESS_TYPE_FAMILY
	case "GROUP":
		return clinicalv1.ProcessType_PROCESS_TYPE_GROUP
	}
	return clinicalv1.ProcessType_PROCESS_TYPE_UNSPECIFIED
}

func (s *Server) trackEvent(ctx context.Context, event analytics.Event) {
	if s.collector != nil {
		s.collector.Track(ctx, event)
	}

	if s.pubsub != nil {
		if err := s.pubsub.PublishAnalyticsEvent(ctx, event); err != nil {
			slog.ErrorContext(ctx, "failed to publish analytics event to Pub/Sub",
				"error", err,
				"event_name", event.Name,
			)
		}
	}
}
