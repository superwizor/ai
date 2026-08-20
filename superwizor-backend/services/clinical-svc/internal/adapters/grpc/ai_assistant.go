// ai_assistant.go — the AI chat RPC handler.
//
// This file is deliberately thin. Everything that decides what the system
// is allowed to do lives in internal/chat and pkg/guardrail; the handler
// authenticates the caller, translates to and from protobuf, and maps
// errors to status codes. Putting policy here would put it somewhere the
// eval suite cannot reach.

package grpc

import (
	"context"
	"errors"
	"log/slog"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/pkg/guardrail"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/chat"
)

// AskPatientQuestion answers one chat turn.
//
// Unary, not streaming: the verifier inspects the complete response
// before any of it is shown, and a token already on the wire cannot be
// withdrawn (ADR section 4.2).
func (s *Server) AskPatientQuestion(ctx context.Context, req *clinicalv1.AskPatientQuestionRequest) (*clinicalv1.AskPatientQuestionResponse, error) {
	if s.chat == nil {
		return nil, status.Error(codes.Unavailable, "FEATURE_DISABLED")
	}

	patientFileID, err := uuid.Parse(req.GetPatientFileId())
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid patient_file_id: %v", err)
	}
	if req.GetQuestion() == "" {
		return nil, status.Error(codes.InvalidArgument, "question is required")
	}

	pf, err := s.queries.GetPatientFile(ctx, patientFileID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	if err := s.requireTherapistDataAccess(ctx, pf.TherapistID); err != nil {
		return nil, err
	}

	// A new conversation gets a fresh ID; a continuing one keeps its own.
	convID := uuid.New()
	if raw := req.GetConversationId(); raw != "" {
		if parsed, err := uuid.Parse(raw); err == nil {
			convID = parsed
		}
	}

	out, err := s.chat.Ask(ctx, chat.Turn{
		TherapistID:    pf.TherapistID,
		OrganizationID: orgIDFromContext(ctx),
		PatientFileID:  patientFileID,
		ConversationID: convID,
		Question:       req.GetQuestion(),
		Platform:       platformFromContext(ctx),
		StarterID:      req.GetStarterId(),
		StarterEdited:  req.GetStarterEdited(),
	})
	if err != nil {
		if errors.Is(err, chat.ErrChatDisabled) {
			return nil, status.Error(codes.Unavailable, "FEATURE_DISABLED")
		}
		slog.ErrorContext(ctx, "chat.turn_failed", "error", err,
			"patient_file_id", patientFileID.String())
		return nil, status.Error(codes.Internal, "chat turn failed")
	}

	return toProto(convID, out), nil
}

func toProto(convID uuid.UUID, out chat.Outcome) *clinicalv1.AskPatientQuestionResponse {
	resp := &clinicalv1.AskPatientQuestionResponse{
		ConversationId: convID.String(),
		Outcome:        outcomeToProto(out.Kind),
		Meta: &clinicalv1.ChatMeta{
			Intent:                 intentToProto(out.Meta.Intent),
			ConfidenceBucket:       out.Meta.ConfidenceBucket,
			DegradeReason:          out.Meta.DegradeReason,
			CostMicroUsd:           out.Meta.CostMicroUSD,
			QuotaRemainingMicroUsd: out.Meta.QuotaRemaining,
			RagHitsUsed:            int32(out.Meta.RagHitsUsed),
			LatencyMs:              int32(out.Meta.LatencyMs),
		},
	}

	if out.Refusal != nil {
		r := &clinicalv1.ChatRefusal{
			Message:               out.Refusal.MessageKey,
			ShowCrisisInformation: out.Refusal.ShowCrisisInformation,
		}
		for _, alt := range out.Refusal.Alternatives {
			r.Alternatives = append(r.Alternatives, &clinicalv1.RefusalAlternative{
				Intent:  intentToProto(alt.Intent),
				Label:   alt.LabelKey,
				Prefill: alt.PrefillKey,
			})
		}
		resp.Payload = &clinicalv1.AskPatientQuestionResponse_Refusal{Refusal: r}
		return resp
	}

	if out.Answer != nil {
		a := &clinicalv1.ChatAnswer{}
		for _, sec := range out.Answer.Sections {
			a.Sections = append(a.Sections, &clinicalv1.AnswerSection{
				Title:        sec.Title,
				Body:         sec.Body,
				Kind:         sectionKindToProto(sec.Kind),
				UserAuthored: sec.UserAuthored,
				Quotes:       quotesToProto(sec.Quotes),
			})
		}
		for _, sq := range out.Answer.SuggestedQuestions {
			a.SuggestedQuestions = append(a.SuggestedQuestions, &clinicalv1.SuggestedQuestion{
				Question: sq.Question,
				Quotes:   quotesToProto(sq.Quotes),
			})
		}
		resp.Payload = &clinicalv1.AskPatientQuestionResponse_Answer{Answer: a}
	}
	return resp
}

func quotesToProto(qs []chat.Quote) []*clinicalv1.Quote {
	out := make([]*clinicalv1.Quote, 0, len(qs))
	for _, q := range qs {
		pq := &clinicalv1.Quote{
			SessionId: q.SessionID,
			SegmentId: q.SegmentID,
			Text:      q.Text,
			Speaker:   q.Speaker,
			TsStartMs: q.TsStartMs,
			TsEndMs:   q.TsEndMs,
		}
		if !q.SessionAt.IsZero() {
			pq.SessionAt = timestamppb.New(q.SessionAt)
		}
		out = append(out, pq)
	}
	return out
}

func outcomeToProto(k chat.OutcomeKind) clinicalv1.ChatOutcome {
	switch k {
	case chat.OutcomeAnswered:
		return clinicalv1.ChatOutcome_CHAT_OUTCOME_ANSWERED
	case chat.OutcomeDegraded:
		return clinicalv1.ChatOutcome_CHAT_OUTCOME_DEGRADED
	case chat.OutcomeRefused:
		return clinicalv1.ChatOutcome_CHAT_OUTCOME_REFUSED
	case chat.OutcomeVerifierBlocked:
		return clinicalv1.ChatOutcome_CHAT_OUTCOME_VERIFIER_BLOCKED
	case chat.OutcomeUnavailable:
		return clinicalv1.ChatOutcome_CHAT_OUTCOME_UNAVAILABLE
	}
	return clinicalv1.ChatOutcome_CHAT_OUTCOME_UNSPECIFIED
}

// intentToProtoTable maps the guardrail taxonomy onto the wire enum.
//
// An explicit table rather than an arithmetic cast: the two enumerations
// are independently versioned, and a silent off-by-one here would
// mislabel a refusal as an allowed intent in the UI.
var intentToProtoTable = map[guardrail.Intent]clinicalv1.ChatIntent{
	guardrail.A1Search:        clinicalv1.ChatIntent_CHAT_INTENT_A1_SEARCH,
	guardrail.A2Stats:         clinicalv1.ChatIntent_CHAT_INTENT_A2_FACTS,
	guardrail.A3Format:        clinicalv1.ChatIntent_CHAT_INTENT_A3_FORMAT,
	guardrail.A4Edu:           clinicalv1.ChatIntent_CHAT_INTENT_A4_EDU,
	guardrail.A5Prep:          clinicalv1.ChatIntent_CHAT_INTENT_A5_SUPERVISION_PACK,
	guardrail.A6Admin:         clinicalv1.ChatIntent_CHAT_INTENT_A6_ADMIN,
	guardrail.A7Template:      clinicalv1.ChatIntent_CHAT_INTENT_A7_TEMPLATE_MAP,
	guardrail.A8Concept:       clinicalv1.ChatIntent_CHAT_INTENT_A8_CONCEPT,
	guardrail.A9Progress:      clinicalv1.ChatIntent_CHAT_INTENT_A9_PROGRESS,
	guardrail.A10Intervention: clinicalv1.ChatIntent_CHAT_INTENT_A10_TREAT,
	guardrail.P1Diag:          clinicalv1.ChatIntent_CHAT_INTENT_P1_DIAG,
	guardrail.P2Med:           clinicalv1.ChatIntent_CHAT_INTENT_P2_MED,
	guardrail.RRisk:           clinicalv1.ChatIntent_CHAT_INTENT_R_RISK,
	guardrail.XOther:          clinicalv1.ChatIntent_CHAT_INTENT_X_OTHER,
}

func intentToProto(i guardrail.Intent) clinicalv1.ChatIntent {
	if v, ok := intentToProtoTable[i]; ok {
		return v
	}
	return clinicalv1.ChatIntent_CHAT_INTENT_UNSPECIFIED
}

func sectionKindToProto(kind string) clinicalv1.SectionKind {
	switch kind {
	case "extract":
		return clinicalv1.SectionKind_SECTION_KIND_EXTRACT
	case "summary":
		return clinicalv1.SectionKind_SECTION_KIND_SUMMARY
	case "stats":
		return clinicalv1.SectionKind_SECTION_KIND_STATS
	case "hypothesis":
		return clinicalv1.SectionKind_SECTION_KIND_HYPOTHESIS
	case "user_only":
		return clinicalv1.SectionKind_SECTION_KIND_USER_ONLY
	}
	return clinicalv1.SectionKind_SECTION_KIND_UNSPECIFIED
}

// orgIDFromContext reads the caller's organization for per-org config
// overrides. Absence is normal (a solo therapist has no organization) and
// resolves to the global configuration.
func orgIDFromContext(ctx context.Context) uuid.UUID {
	raw, _ := ctx.Value(OrganizationIDKey).(string)
	if raw == "" {
		return uuid.Nil
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil
	}
	return id
}

// platformFromContext reads the client platform header for telemetry.
func platformFromContext(ctx context.Context) string {
	p, _ := ctx.Value(PlatformKey).(string)
	return p
}

// GenerateSessionBrief remains unimplemented.
//
// The briefing was Faza 1 of an earlier design in which it preceded the
// chat. It is superseded: A5_PREP does the same job through the guardrail
// pipeline, so shipping a second generative path that bypasses the
// classifier and the verifier would undo the architecture. Kept as an
// explicit Unimplemented rather than deleted because the RPC is in the
// published proto and clients may still call it.
func (s *Server) GenerateSessionBrief(ctx context.Context, req *clinicalv1.GenerateSessionBriefRequest) (*clinicalv1.GenerateSessionBriefResponse, error) {
	return nil, status.Error(codes.Unimplemented,
		"GenerateSessionBrief is superseded by AskPatientQuestion with intent A5_PREP")
}
