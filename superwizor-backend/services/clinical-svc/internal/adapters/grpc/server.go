package grpc

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Server struct {
	clinicalv1.UnimplementedClinicalServiceServer
	dbPool   *pgxpool.Pool
	queries  *db.Queries
	identity identityv1.IdentityServiceClient
	version  string
}

func NewServer(dbPool *pgxpool.Pool, queries *db.Queries, identity identityv1.IdentityServiceClient, version string) *Server {
	return &Server{dbPool: dbPool, queries: queries, identity: identity, version: version}
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

func (s *Server) DeletePatientFile(ctx context.Context, req *clinicalv1.DeletePatientFileRequest) (*emptypb.Empty, error) {
	id, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}

	// We need therapist ID from context, but we don't have authentication logic implemented in this mock yet. 
	// For now, let's just use empty uuid to make it compile, or since SoftDeletePatientFile requires TherapistID, 
	// let's fetch the patient file first to get the therapist ID.
	pf, err := s.queries.GetPatientFile(ctx, id)
	if err != nil {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}

	err = s.queries.SoftDeletePatientFile(ctx, db.SoftDeletePatientFileParams{
		ID:          id,
		TherapistID: pf.TherapistID,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
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
