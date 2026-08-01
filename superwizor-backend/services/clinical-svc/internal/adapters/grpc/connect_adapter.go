package grpc

import (
	"context"
	"fmt"

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

func (a *ConnectAdapter) TrackEvents(ctx context.Context, req *connect.Request[clinicalv1.TrackEventsRequest]) (*connect.Response[clinicalv1.TrackEventsResponse], error) {
	resp, err := a.s.TrackEvents(ctx, req.Msg)
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

func (a *ConnectAdapter) GetAdminAnalytics(ctx context.Context, req *connect.Request[clinicalv1.GetAdminAnalyticsRequest]) (*connect.Response[clinicalv1.GetAdminAnalyticsResponse], error) {
	resp, err := a.s.GetAdminAnalytics(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminListReportRatings(ctx context.Context, req *connect.Request[clinicalv1.AdminListReportRatingsRequest]) (*connect.Response[clinicalv1.AdminListReportRatingsResponse], error) {
	resp, err := a.s.AdminListReportRatings(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminSetRatingReviewStatus(ctx context.Context, req *connect.Request[clinicalv1.AdminSetRatingReviewStatusRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.AdminSetRatingReviewStatus(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetOrgTherapistMetrics(ctx context.Context, req *connect.Request[clinicalv1.GetOrgTherapistMetricsRequest]) (*connect.Response[clinicalv1.OrgTherapistMetricsResponse], error) {
	resp, err := a.s.GetOrgTherapistMetrics(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetOrgAnalytics(ctx context.Context, req *connect.Request[clinicalv1.GetOrgAnalyticsRequest]) (*connect.Response[clinicalv1.GetOrgAnalyticsResponse], error) {
	resp, err := a.s.GetOrgAnalytics(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ClientGetMyOverview(ctx context.Context, req *connect.Request[emptypb.Empty]) (*connect.Response[clinicalv1.ClientOverview], error) {
	resp, err := a.s.ClientGetMyOverview(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ClientListSessions(ctx context.Context, req *connect.Request[clinicalv1.ClientListSessionsRequest]) (*connect.Response[clinicalv1.ClientListSessionsResponse], error) {
	resp, err := a.s.ClientListSessions(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ClientGetTranscript(ctx context.Context, req *connect.Request[clinicalv1.ClientGetTranscriptRequest]) (*connect.Response[clinicalv1.ClientGetTranscriptResponse], error) {
	resp, err := a.s.ClientGetTranscript(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ClientListNotes(ctx context.Context, req *connect.Request[clinicalv1.ClientListNotesRequest]) (*connect.Response[clinicalv1.ClientListNotesResponse], error) {
	resp, err := a.s.ClientListNotes(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ClientCreateNote(ctx context.Context, req *connect.Request[clinicalv1.ClientCreateNoteRequest]) (*connect.Response[clinicalv1.ClientNote], error) {
	resp, err := a.s.ClientCreateNote(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ClientSendNote(ctx context.Context, req *connect.Request[clinicalv1.ClientSendNoteRequest]) (*connect.Response[clinicalv1.ClientNote], error) {
	resp, err := a.s.ClientSendNote(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ClientMarkNoteRead(ctx context.Context, req *connect.Request[clinicalv1.ClientMarkNoteReadRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.ClientMarkNoteRead(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ClientDeleteNote(ctx context.Context, req *connect.Request[clinicalv1.ClientDeleteNoteRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.ClientDeleteNote(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ClientHideItem(ctx context.Context, req *connect.Request[clinicalv1.ClientHideItemRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.ClientHideItem(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ShareSessionWithClient(ctx context.Context, req *connect.Request[clinicalv1.ShareSessionWithClientRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.ShareSessionWithClient(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ShareNoteWithClient(ctx context.Context, req *connect.Request[clinicalv1.ShareNoteWithClientRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.ShareNoteWithClient(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ExportPatientData(ctx context.Context, req *connect.Request[clinicalv1.ExportPatientDataRequest]) (*connect.Response[clinicalv1.ExportPatientDataResponse], error) {
	resp, err := a.s.ExportPatientData(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) DeletePatientData(ctx context.Context, req *connect.Request[clinicalv1.DeletePatientDataRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.DeletePatientData(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

// ─── Cross-device preference sync (migration 000059) ────────────────

func (a *ConnectAdapter) MarkReportViewed(ctx context.Context, req *connect.Request[clinicalv1.MarkReportViewedRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.MarkReportViewed(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) SetAvatarConfig(ctx context.Context, req *connect.Request[clinicalv1.SetAvatarConfigRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.SetAvatarConfig(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

// ─── Admin Prompt Studio (docs/31) ──────────────────────────────────

func (a *ConnectAdapter) AdminListModalityPrompts(ctx context.Context, req *connect.Request[emptypb.Empty]) (*connect.Response[clinicalv1.AdminListModalityPromptsResponse], error) {
	resp, err := a.s.AdminListModalityPrompts(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminGetModalityPromptHistory(ctx context.Context, req *connect.Request[clinicalv1.AdminGetModalityPromptHistoryRequest]) (*connect.Response[clinicalv1.AdminGetModalityPromptHistoryResponse], error) {
	resp, err := a.s.AdminGetModalityPromptHistory(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminUpdateModalityPrompt(ctx context.Context, req *connect.Request[clinicalv1.AdminUpdateModalityPromptRequest]) (*connect.Response[clinicalv1.AdminUpdateModalityPromptResponse], error) {
	resp, err := a.s.AdminUpdateModalityPrompt(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) EditTranscriptSegment(ctx context.Context, req *connect.Request[clinicalv1.EditTranscriptSegmentRequest]) (*connect.Response[clinicalv1.EditTranscriptSegmentResponse], error) {
	resp, err := a.s.EditTranscriptSegment(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) SplitTranscriptSegment(ctx context.Context, req *connect.Request[clinicalv1.SplitTranscriptSegmentRequest]) (*connect.Response[clinicalv1.SplitTranscriptSegmentResponse], error) {
	resp, err := a.s.SplitTranscriptSegment(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GenerateSessionBrief(ctx context.Context, req *connect.Request[clinicalv1.GenerateSessionBriefRequest]) (*connect.Response[clinicalv1.GenerateSessionBriefResponse], error) {
	resp, err := a.s.GenerateSessionBrief(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AskPatientQuestion(ctx context.Context, req *connect.Request[clinicalv1.AskPatientQuestionRequest], stream *connect.ServerStream[clinicalv1.AskPatientQuestionResponse]) error {
	return connect.NewError(connect.CodeUnimplemented, fmt.Errorf("AskPatientQuestion streaming not implemented yet"))
}
