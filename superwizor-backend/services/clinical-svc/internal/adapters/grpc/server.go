package grpc

import (
	"context"
	"encoding/json"
	"log/slog"

	"github.com/google/uuid"
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

	// Create
	pf, err := s.queries.CreatePatientFile(ctx, db.CreatePatientFileParams{
		TherapistID:         therapistID,
		ModalityID:          modality.ID,
		WorkingAlias:        req.WorkingAlias,
		ProcessType:         dbProcessType,
		InitialComplaint:    &req.InitialComplaint,
		HasRecordingConsent: req.HasRecordingConsent,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
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

	return toProtoPatientFile(pf, modality.SystemCode), nil
}

func (s *Server) GetPatientFile(ctx context.Context, req *clinicalv1.GetPatientFileRequest) (*clinicalv1.PatientFile, error) {
	id, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}
	pf, err := s.queries.GetPatientFile(ctx, id)
	if err != nil {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	// TODO Faza 2: pobrać modality_code dla wyświetlenia
	return toProtoPatientFile(pf, ""), nil
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
	files, err := s.queries.ListPatientFilesByTherapist(ctx, db.ListPatientFilesByTherapistParams{
		TherapistID: therapistID,
		Limit:       pageSize,
		Offset:      0, // simple paging w MVP, page_token w Fazie 2
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	resp := &clinicalv1.ListPatientFilesResponse{}
	for _, pf := range files {
		resp.PatientFiles = append(resp.PatientFiles, toProtoPatientFile(pf, ""))
	}
	return resp, nil
}

func (s *Server) UpdatePatientFile(ctx context.Context, req *clinicalv1.UpdatePatientFileRequest) (*clinicalv1.PatientFile, error) {
	id, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}

	pf, err := s.queries.UpdatePatientFile(ctx, db.UpdatePatientFileParams{
		ID:              id,
		Column2:         req.WorkingAlias,
		Column3:         req.InitialComplaint,
		Column4:         req.PrivateTherapistNotes,
		IsProcessClosed: req.IsProcessClosed,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	return toProtoPatientFile(pf, ""), nil
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

	// List session IDs before the hard delete so we can fan out events.
	// After HardDeletePatientFile runs, sessions for this kartoteka are
	// gone — we'd have nothing to publish.
	sessionIDs, err := s.queries.ListSessionIDsForPatientFile(ctx, id)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list session ids: %v", err)
	}

	rows, err := s.queries.HardDeletePatientFile(ctx, db.HardDeletePatientFileParams{
		ID:          id,
		TherapistID: therapistID,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "hard delete patient_file: %v", err)
	}
	if rows == 0 {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}

	// Fan out cleanup events. Per-session because notification-svc's
	// handler is keyed on session_id (Firestore doc id). Each publish
	// is best-effort and independent — a single failure doesn't block
	// the rest.
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
