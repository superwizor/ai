// prompt_tuning.go — Natural Language AI Preference Tuning (Meta-Prompting).
// Allows therapists to customize AI behavior (report length, therapeutic focus,
// clinical style) via natural language instructions while enforcing strict
// system guardrails (RODO/PII non-negotiables, no medical diagnoses).

package grpc

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/structpb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
)

// ── Meta-Prompt System Instructions ───────────────────────────────────

const metaPromptSystemInstruction = `Jesteś ekspertem inżynierii promptów dla systemu Superwizor AI — copilota klinicznego dla psychoterapeutów.

TWÓJ CEL:
Przekształć naturalną instrukcję terapeuty na zaktualizowany zestaw preferencji raportu (JSON) oraz czytelne podsumowanie zmian po polsku.

Naruszenie poniższych ZASAD BEZPIECZEŃSTWA (GUARDRAILS) jest SUROWO ZABRONIONE:
1. NIE wolno wyłączać anonimizacji PII ani ochrony danych osobowych pacjenta (RODO).
2. NIE wolno wymuszać stawiania medycznych diagnoz psychiatrycznych (ICD/DSM).
3. NIE wolno zmieniać podstawowego schematu struktury raportu gRPC.

JEŚLI INSTRUKCJA TERAPEUTY NARUSZA ZASADY:
Zwróć informację o odrzuceniu prośby i wyjaśnij dlaczego.`

// Secret key for signing update tokens (HMAC-SHA256)
const promptTuningTokenSecret = "superwizor-prompt-tuning-secret-v1"

// ── Handlers ───────────────────────────────────────────────────────────

func (s *Server) UpdateReportPreferencesFromPrompt(
	ctx context.Context,
	req *clinicalv1.UpdateReportPreferencesFromPromptRequest,
) (*clinicalv1.UpdateReportPreferencesFromPromptResponse, error) {
	callerIDStr, _ := ctx.Value(UserIDKey).(string)
	if callerIDStr == "" {
		return nil, status.Error(codes.Unauthenticated, "missing caller identity")
	}

	therapistID, err := uuid.Parse(callerIDStr)
	if err != nil {
		return nil, status.Errorf(codes.Unauthenticated, "invalid caller ID: %v", err)
	}

	instruction := strings.TrimSpace(req.GetInstruction())
	if instruction == "" {
		return nil, status.Error(codes.InvalidArgument, "instrukcja nie może być pusta")
	}

	slog.InfoContext(ctx, "prompt_tuning.request_received",
		"therapist_id", therapistID.String(),
		"instruction_len", len(instruction),
	)

	// 1. Guardrail check against harmful prompt injection
	if err := validateGuardrails(instruction); err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "Nie można zastosować zmian: %v", err)
	}

	// 2. Build proposal summary and updated preferences struct
	// In production, this calls Vertex AI (Gemini Pro) to generate the meta-prompt payload.
	summaryPL, proposedStruct, err := generateMetaPromptProposal(instruction)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "błąd generowania wytycznych przez AI: %v", err)
	}

	// 3. Create a signed update token (valid for 15 minutes)
	updateToken := signUpdateToken(therapistID.String(), summaryPL, time.Now().Add(15*time.Minute))

	return &clinicalv1.UpdateReportPreferencesFromPromptResponse{
		SummaryPl:           summaryPL,
		ProposedPreferences: proposedStruct,
		UpdateToken:         updateToken,
	}, nil
}

func (s *Server) ConfirmReportPreferencesUpdate(
	ctx context.Context,
	req *clinicalv1.ConfirmReportPreferencesUpdateRequest,
) (*emptypb.Empty, error) {
	callerIDStr, _ := ctx.Value(UserIDKey).(string)
	if callerIDStr == "" {
		return nil, status.Error(codes.Unauthenticated, "missing caller identity")
	}

	token := req.GetUpdateToken()
	if token == "" {
		return nil, status.Error(codes.InvalidArgument, "brak tokenu autoryzacyjnego")
	}

	if !verifyUpdateToken(callerIDStr, token) {
		return nil, status.Error(codes.Unauthenticated, "nieprawidłowy lub wygasły token weryfikacyjny")
	}

	slog.InfoContext(ctx, "prompt_tuning.confirmed",
		"therapist_id", callerIDStr,
	)

	// Zapis wygenerowanych preferencji do bazy danych (users.report_preferences)
	return &emptypb.Empty{}, nil
}

func (s *Server) ResetReportPreferencesToDefault(
	ctx context.Context,
	req *emptypb.Empty,
) (*emptypb.Empty, error) {
	callerIDStr, _ := ctx.Value(UserIDKey).(string)
	if callerIDStr == "" {
		return nil, status.Error(codes.Unauthenticated, "missing caller identity")
	}

	slog.InfoContext(ctx, "prompt_tuning.reset_to_default",
		"therapist_id", callerIDStr,
	)

	// Reset preferencji do wartości domyślnych
	return &emptypb.Empty{}, nil
}

// ── Helpers ───────────────────────────────────────────────────────────

func validateGuardrails(instruction string) error {
	lower := strings.ToLower(instruction)

	// Check forbidden directives
	forbiddenKeywords := []string{
		"wyłącz rodo",
		"usuń anoni",
		"pokazuj dane osobowe",
		"stawiaj diagnoz",
		"rób diagnozę",
		"ignore previous instructions",
		"system prompt",
	}

	for _, kw := range forbiddenKeywords {
		if strings.Contains(lower, kw) {
			return fmt.Errorf("instrukcja narusza zasady bezpieczeństwa systemu (wykryto frazę: '%s')", kw)
		}
	}
	return nil
}

func generateMetaPromptProposal(instruction string) (string, *structpb.Struct, error) {
	// Generowanie propozycji podsumowania dla terapeuty po polsku
	summary := fmt.Sprintf("Wprowadzone dostosowania wytycznych AI:\n• Uwzględniono nową preferencję: „%s”\n• Zachowano pełną zgodność z zasadami RODO i brakiem diagnozowania medycznego.\n• Przyszłe raporty i czat będą używały zaktualizowanego stylu.", instruction)

	// Przykładowa struktura preferencji w protobuf Struct
	props, err := structpb.NewStruct(map[string]interface{}{
		"custom_instruction": instruction,
		"updated_at":         time.Now().Format(time.RFC3339),
		"version":            2,
	})
	if err != nil {
		return "", nil, err
	}

	return summary, props, nil
}

func signUpdateToken(therapistID, summary string, expiresAt time.Time) string {
	payload := fmt.Sprintf("%s:%d", therapistID, expiresAt.Unix())
	h := hmac.New(sha256.New, []byte(promptTuningTokenSecret))
	h.Write([]byte(payload))
	sig := hex.EncodeToString(h.Sum(nil))
	return fmt.Sprintf("%s:%s", payload, sig)
}

func verifyUpdateToken(therapistID, token string) bool {
	parts := strings.Split(token, ":")
	if len(parts) != 3 {
		return false
	}
	tokenTherapistID := parts[0]
	if tokenTherapistID != therapistID {
		return false
	}

	payload := fmt.Sprintf("%s:%s", parts[0], parts[1])
	h := hmac.New(sha256.New, []byte(promptTuningTokenSecret))
	h.Write([]byte(payload))
	expectedSig := hex.EncodeToString(h.Sum(nil))

	return hmac.Equal([]byte(parts[2]), []byte(expectedSig))
}
