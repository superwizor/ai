package grpc

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/pkg/cryptobox"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
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
}

type Server struct {
	clinicalv1.UnimplementedClinicalServiceServer
	dbPool   *pgxpool.Pool
	queries  *db.Queries
	identity identityv1.IdentityServiceClient
	crypto   cryptobox.CryptoBox
	pubsub   SessionEventPublisher
	version  string
}

func NewServer(dbPool *pgxpool.Pool, queries *db.Queries, identity identityv1.IdentityServiceClient, crypto cryptobox.CryptoBox, pubsub SessionEventPublisher, version string) *Server {
	return &Server{dbPool: dbPool, queries: queries, identity: identity, crypto: crypto, pubsub: pubsub, version: version}
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
	if req.PatientFirstName == "" {
		return nil, status.Error(codes.InvalidArgument, "patient_first_name required")
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
	tx, err := s.dbPool.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "begin tx: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }() // no-op on commit
	qtx := s.queries.WithTx(tx)

	patientUserID, err := qtx.CreatePatientUser(ctx, db.CreatePatientUserParams{
		FirstName:  req.PatientFirstName,
		LastName:   req.PatientLastName,
		UiLanguage: patientLang,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "create patient user: %v", err)
	}

	pf, err := qtx.CreatePatientFile(ctx, db.CreatePatientFileParams{
		TherapistID:         therapistID,
		PatientID:           pgtype.UUID{Bytes: patientUserID, Valid: true},
		ModalityID:          modality.ID,
		WorkingAlias:        req.WorkingAlias,
		ProcessType:         dbProcessType,
		InitialComplaint:    &req.InitialComplaint,
		HasRecordingConsent: req.HasRecordingConsent,
	})
	if err != nil {
		// Unique violation on (therapist_id, working_alias) means
		// this therapist already has a kartoteka with the same alias.
		// Surface as AlreadyExists so Flutter can show a clear message.
		if isUniqueViolation(err) {
			return nil, status.Errorf(codes.AlreadyExists,
				"working_alias %q already used by another active kartoteka", req.WorkingAlias)
		}
		return nil, status.Errorf(codes.Internal, "create patient_file: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	// Audit log (async w produkcji; synchroniczne w MVP)
	auditMeta, _ := json.Marshal(map[string]any{
		"modality_code": modality.SystemCode,
		"alias":         req.WorkingAlias,
	})
	_ = s.queries.CreateAuditEvent(ctx, db.CreateAuditEventParams{
		ActorUserID:  pgtype.UUID{Bytes: therapistID, Valid: true},
		Action:       "patient_file.create",
		ResourceType: "patient_file",
		ResourceID:   pgtype.UUID{Bytes: pf.ID, Valid: true},
		Metadata:     auditMeta,
	})

	// We already have all the inputs needed to populate the response;
	// no second SELECT required. ConsentGivenAt / FirstConsultationAt
	// stay zero — the insert didn't set them and the standard mapper
	// would also omit them via timestamppb.Valid checks.
	resp := toProtoPatientFile(pf, modality.SystemCode)
	resp.PatientFirstName = req.PatientFirstName
	resp.PatientLastName = req.PatientLastName
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

func (s *Server) GetPatientFile(ctx context.Context, req *clinicalv1.GetPatientFileRequest) (*clinicalv1.PatientFile, error) {
	id, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}
	row, err := s.queries.GetPatientFileWithUser(ctx, id)
	if err != nil {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	// TODO Faza 2: pobrać modality_code dla wyświetlenia
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

	if _, err := s.queries.UpdatePatientFile(ctx, db.UpdatePatientFileParams{
		ID:              id,
		Column2:         req.WorkingAlias,
		Column3:         req.InitialComplaint,
		Column4:         req.PrivateTherapistNotes,
		IsProcessClosed: req.IsProcessClosed,
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
	if !pf.PatientID.Valid {
		// No paired user exists (probably wiped via DeletePatientUser).
		// Refuse rather than auto-recreate — caller should make a
		// deliberate decision (e.g. recreate the kartoteka).
		return nil, status.Error(codes.FailedPrecondition,
			"this kartoteka has no patient user attached")
	}

	if _, err := s.queries.UpdatePatientUser(ctx, db.UpdatePatientUserParams{
		ID:           uuid.UUID(pf.PatientID.Bytes),
		FirstName:    req.FirstName,
		LastName:     req.LastName,
		LanguageCode: req.LanguageCode,
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "update patient user: %v", err)
	}

	// Re-read with JOIN so the response carries the now-current
	// user fields alongside the unchanged kartoteka fields.
	row, err := s.queries.GetPatientFileWithUser(ctx, pfID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "refetch after update: %v", err)
	}
	return toProtoPatientFileFromJoinRow(row, ""), nil
}

// DeletePatientUser drops just the paired users row. The kartoteka
// stays — its patient_id becomes NULL via the SET NULL FK constraint
// added in migration 000013. Therapist may use this when scrubbing
// PII while keeping clinical history.
//
// Re-reads + returns the refreshed PatientFile with empty user
// fields so Flutter can replace the displayed PII in one hop.
func (s *Server) DeletePatientUser(ctx context.Context, req *clinicalv1.DeletePatientUserRequest) (*clinicalv1.PatientFile, error) {
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
		// Already deleted (idempotent path) — re-emit current state
		// without trying to delete again.
		row, err := s.queries.GetPatientFileWithUser(ctx, pfID)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "refetch: %v", err)
		}
		return toProtoPatientFileFromJoinRow(row, ""), nil
	}

	if _, err := s.queries.DeletePatientUser(ctx, uuid.UUID(pf.PatientID.Bytes)); err != nil {
		return nil, status.Errorf(codes.Internal, "delete patient user: %v", err)
	}

	row, err := s.queries.GetPatientFileWithUser(ctx, pfID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "refetch after delete: %v", err)
	}
	return toProtoPatientFileFromJoinRow(row, ""), nil
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
	tx, err := s.dbPool.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "begin tx: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := s.queries.WithTx(tx)

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
// The two With-User variants extract patient_first_name / last_name /
// language_code from the LEFT JOINed nullable columns; empty strings
// when the user row was deleted (FK SET NULL after DeletePatientUser).

func toProtoPatientFileFromJoinRow(row db.GetPatientFileWithUserRow, modalityCode string) *clinicalv1.PatientFile {
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
	if row.PatientFirstName != nil {
		resp.PatientFirstName = *row.PatientFirstName
	}
	if row.PatientLastName != nil {
		resp.PatientLastName = *row.PatientLastName
	}
	if row.PatientLanguageCode != nil {
		resp.PatientLanguageCode = *row.PatientLanguageCode
	}
	return resp
}

func toProtoPatientFileFromListJoinRow(row db.ListPatientFilesByTherapistWithUserRow, modalityCode string) *clinicalv1.PatientFile {
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
	if row.PatientFirstName != nil {
		resp.PatientFirstName = *row.PatientFirstName
	}
	if row.PatientLastName != nil {
		resp.PatientLastName = *row.PatientLastName
	}
	if row.PatientLanguageCode != nil {
		resp.PatientLanguageCode = *row.PatientLanguageCode
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
