package grpc

import (
	"context"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/types/known/emptypb"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
)

// ConnectAdapter wraps *Server (the gRPC ClinicalServiceServer) and
// exposes it as a Connect-RPC handler. See identity-svc/internal/
// adapters/grpc/connect_adapter.go for the design rationale — same
// pattern, mechanical 1:1 wrapping.
//
// docs/18 §5 (R1). docs/19 commit 6.
type ConnectAdapter struct {
	s *Server
}

func NewConnectAdapter(s *Server) *ConnectAdapter { return &ConnectAdapter{s: s} }

func (a *ConnectAdapter) CreatePatientFile(ctx context.Context, req *connect.Request[clinicalv1.CreatePatientFileRequest]) (*connect.Response[clinicalv1.PatientFile], error) {
	resp, err := a.s.CreatePatientFile(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetPatientFile(ctx context.Context, req *connect.Request[clinicalv1.GetPatientFileRequest]) (*connect.Response[clinicalv1.PatientFile], error) {
	resp, err := a.s.GetPatientFile(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ListPatientFiles(ctx context.Context, req *connect.Request[clinicalv1.ListPatientFilesRequest]) (*connect.Response[clinicalv1.ListPatientFilesResponse], error) {
	resp, err := a.s.ListPatientFiles(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) UpdatePatientFile(ctx context.Context, req *connect.Request[clinicalv1.UpdatePatientFileRequest]) (*connect.Response[clinicalv1.PatientFile], error) {
	resp, err := a.s.UpdatePatientFile(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) DeletePatientFile(ctx context.Context, req *connect.Request[clinicalv1.DeletePatientFileRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.DeletePatientFile(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) UpdatePatientUser(ctx context.Context, req *connect.Request[clinicalv1.UpdatePatientUserRequest]) (*connect.Response[clinicalv1.PatientFile], error) {
	resp, err := a.s.UpdatePatientUser(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) DeletePatientUser(ctx context.Context, req *connect.Request[clinicalv1.DeletePatientUserRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.DeletePatientUser(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

// Patient notes + action plan (docs/22) — mechanical 1:1 Connect wrappers
// over the *Server gRPC handlers in patient_notes.go.

func (a *ConnectAdapter) CreatePatientNote(ctx context.Context, req *connect.Request[clinicalv1.CreatePatientNoteRequest]) (*connect.Response[clinicalv1.PatientNote], error) {
	resp, err := a.s.CreatePatientNote(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ListPatientNotes(ctx context.Context, req *connect.Request[clinicalv1.ListPatientNotesRequest]) (*connect.Response[clinicalv1.ListPatientNotesResponse], error) {
	resp, err := a.s.ListPatientNotes(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) UpdatePatientNote(ctx context.Context, req *connect.Request[clinicalv1.UpdatePatientNoteRequest]) (*connect.Response[clinicalv1.PatientNote], error) {
	resp, err := a.s.UpdatePatientNote(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) DeletePatientNote(ctx context.Context, req *connect.Request[clinicalv1.DeletePatientNoteRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.DeletePatientNote(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetActionPlanDraft(ctx context.Context, req *connect.Request[clinicalv1.GetActionPlanDraftRequest]) (*connect.Response[clinicalv1.ActionPlanDraft], error) {
	resp, err := a.s.GetActionPlanDraft(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) SavePatientNote(ctx context.Context, req *connect.Request[clinicalv1.SavePatientNoteRequest]) (*connect.Response[clinicalv1.SavePatientNoteResponse], error) {
	resp, err := a.s.SavePatientNote(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ListModalities(ctx context.Context, req *connect.Request[emptypb.Empty]) (*connect.Response[clinicalv1.ListModalitiesResponse], error) {
	resp, err := a.s.ListModalities(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) HealthCheck(ctx context.Context, req *connect.Request[emptypb.Empty]) (*connect.Response[clinicalv1.HealthCheckResponse], error) {
	resp, err := a.s.HealthCheck(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetMyBillingState(ctx context.Context, req *connect.Request[emptypb.Empty]) (*connect.Response[billingv1.Subscription], error) {
	resp, err := a.s.GetMyBillingState(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) UpdateSpeakerLabels(ctx context.Context, req *connect.Request[clinicalv1.UpdateSpeakerLabelsRequest]) (*connect.Response[clinicalv1.UpdateSpeakerLabelsResponse], error) {
	resp, err := a.s.UpdateSpeakerLabels(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ListSessions(ctx context.Context, req *connect.Request[clinicalv1.ListSessionsRequest]) (*connect.Response[clinicalv1.ListSessionsResponse], error) {
	resp, err := a.s.ListSessions(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetSessionDetails(ctx context.Context, req *connect.Request[clinicalv1.GetSessionDetailsRequest]) (*connect.Response[clinicalv1.GetSessionDetailsResponse], error) {
	resp, err := a.s.GetSessionDetails(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) UpdateSession(ctx context.Context, req *connect.Request[clinicalv1.UpdateSessionRequest]) (*connect.Response[clinicalv1.Session], error) {
	resp, err := a.s.UpdateSession(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) DeleteSession(ctx context.Context, req *connect.Request[clinicalv1.DeleteSessionRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.DeleteSession(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) CancelSession(ctx context.Context, req *connect.Request[clinicalv1.CancelSessionRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.CancelSession(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) RateReport(ctx context.Context, req *connect.Request[clinicalv1.RateReportRequest]) (*connect.Response[clinicalv1.RateReportResponse], error) {
	resp, err := a.s.RateReport(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetReportRating(ctx context.Context, req *connect.Request[clinicalv1.GetReportRatingRequest]) (*connect.Response[clinicalv1.ReportRating], error) {
	resp, err := a.s.GetReportRating(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetActiveSuggestion(ctx context.Context, req *connect.Request[clinicalv1.GetActiveSuggestionRequest]) (*connect.Response[clinicalv1.PreferenceSuggestion], error) {
	resp, err := a.s.GetActiveSuggestion(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) LogPreferenceSuggestion(ctx context.Context, req *connect.Request[clinicalv1.LogPreferenceSuggestionRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.LogPreferenceSuggestion(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminListSessions(ctx context.Context, req *connect.Request[clinicalv1.AdminListSessionsRequest]) (*connect.Response[clinicalv1.AdminListSessionsResponse], error) {
	resp, err := a.s.AdminListSessions(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}
