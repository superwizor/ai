package llmworker

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/google/uuid"
	"google.golang.org/genai"

	"github.com/superwizor-ai/backend/pkg/ontology"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/ontopipe"
)

// Galaz ontologiczna generacji raportu (plan 16, F2).
//
// Zastepuje WYLACZNIE call-2 (tresc raportu). Call-1 zostaje: tytul,
// streszczenie, klastrowanie mowcow i tematy RAG opisuja sesje, a nie
// konceptualizacje, wiec nowy potok nie ma powodu ich przejmowac —
// a produkt ich potrzebuje niezaleznie od tego, czym powstala tresc.
//
// Stara sciezka pozostaje NIETKNIETA takze na poziomie diffa: warunkiem
// wiarygodnosci przelacznika jest to, ze powrot do niej nie zalezy od
// niczego, co tutaj napisano.

// vertexLLM adaptuje klienta Vertexa do waskiego interfejsu ontopipe.
type vertexLLM struct{ logger *slog.Logger }

func (v vertexLLM) GenerateJSON(ctx context.Context, req ontopipe.LLMRequest) (ontopipe.LLMResponse, error) {
	cfg := &genai.GenerateContentConfig{
		// T=0 zawsze: potok ma byc ODTWARZALNY, nie kreatywny. Raport,
		// ktorego nie da sie powtorzyc, nie da sie tez zbenchmarkowac
		// ani obronic w audycie.
		Temperature:       genai.Ptr[float32](0),
		MaxOutputTokens:   req.MaxTokens,
		ResponseMIMEType:  "application/json",
		ResponseSchema:    schemaToVertexSchema(req.Schema),
		SystemInstruction: genai.NewContentFromText(req.SystemPrompt, genai.RoleUser),
	}

	resp, err := vertexClient.Models.GenerateContent(ctx, req.Model,
		genai.Text(req.UserContent), cfg)
	if err != nil {
		return ontopipe.LLMResponse{}, err
	}
	if len(resp.Candidates) == 0 || resp.Candidates[0].Content == nil {
		return ontopipe.LLMResponse{}, fmt.Errorf("ontopipe: model %s nie zwrocil kandydata", req.Model)
	}

	var out ontopipe.LLMResponse
	var txt string
	for _, part := range resp.Candidates[0].Content.Parts {
		txt += part.Text
	}
	out.JSON = txt
	if resp.UsageMetadata != nil {
		out.InputTokens = int64(resp.UsageMetadata.PromptTokenCount)
		out.OutputTokens = int64(resp.UsageMetadata.CandidatesTokenCount)
	}
	// Obciecie odpowiedzi rozpoznajemy po powodzie zakonczenia, a nie po
	// nieudanym parsowaniu: JSON ucięty w dobrym miejscu bywa poprawny
	// skladniowo i przeszedlby dalej z brakujacymi twierdzeniami.
	if resp.Candidates[0].FinishReason == genai.FinishReasonMaxTokens {
		out.Truncated = true
	}
	return out, nil
}

// workerDB adaptuje pule do waskiego interfejsu ontopipe.
type workerDB struct{}

func (workerDB) Exec(ctx context.Context, sql string, args ...any) error {
	_, err := dbPool.Exec(ctx, sql, args...)
	return err
}

func (workerDB) QueryUUID(ctx context.Context, sql string, args ...any) (uuid.UUID, error) {
	var id uuid.UUID
	err := dbPool.QueryRow(ctx, sql, args...).Scan(&id)
	return id, err
}

// loadActiveOntology czyta i parsuje AKTYWNA wersje ontologii modalnosci.
//
// Zrodlem prawdy runtime jest baza (Ontology Studio), nie plik w repo —
// pliki `ontology/<modality>/<semver>.yaml` sa seedami i dokumentacja
// formatu. Uzywamy Load, nie Parse: tresc, ktora nie przechodzi
// metaschematu, nie ma prawa wejsc do potoku, nawet jesli ktos ja
// aktywowal.
func loadActiveOntology(ctx context.Context, modalityID uuid.UUID) (*ontology.Ontology, string, error) {
	var content, version string
	err := dbPool.QueryRow(ctx, `
		SELECT ov.content, ov.version
		  FROM modalities m
		  JOIN ontology_versions ov ON ov.id = m.active_ontology_version_id
		 WHERE m.id = $1`, modalityID).Scan(&content, &version)
	if err != nil {
		return nil, "", err
	}
	o, err := ontology.Load([]byte(content))
	if err != nil {
		return nil, version, fmt.Errorf("aktywna ontologia %s nie przechodzi metaschematu: %w",
			version, err)
	}
	return o, version, nil
}

// runOntologyPipeline generuje tresc raportu potokiem S1-S5.
//
// Zwraca to samo co call-2 — JSON raportu i statystyki tokenow — zeby
// wolajacy nie musial rozgalezać sie ponownie przy zapisie.
func runOntologyPipeline(
	ctx context.Context,
	logger *slog.Logger,
	session *SessionContext,
	transcriptText string,
	metadataPayload ReportPayload,
	o *ontology.Ontology,
) (ReportPayload, ontopipe.Result, TokenStats, error) {

	res, err := ontopipe.Run(ctx, vertexLLM{logger}, ontopipe.Input{
		SessionID:  session.ID.String(),
		Transcript: transcriptText,
		Ontology:   o,
	})
	stats := TokenStats{
		InputTokens:  int32(res.Usage.InputTokens),
		OutputTokens: int32(res.Usage.OutputTokens),
	}
	if err != nil {
		return ReportPayload{}, res, stats, err
	}

	logger.Info("ontopipe: przebieg zakonczony",
		"spans", len(res.Spans),
		"s1_rejected", len(res.S1Rejected),
		"patterns", len(res.Patterns),
		"approved", len(res.Approved),
		"rejected", len(res.Rejected),
		"degraded", len(res.Degraded),
		"no_fit", len(res.NoFit),
		"insufficient", len(res.Insufficient),
		"skipped_composites", len(res.SkippedComposites),
		"extractive", res.Extractive,
		"calls", res.Usage.Calls)

	if res.Extractive {
		// Tryb ekstraktywny to sygnal do alertu, nie wariant renderingu:
		// oznacza, ze model dwukrotnie nie utrzymal sie w szynach.
		logger.Error("report_extractive_fallback",
			"session_id", session.ID, "violations", len(res.Violations))
	}
	for _, r := range res.Rejected {
		slog.InfoContext(ctx, "analytics", "ae", "report_claim_rejected",
			"session_id", session.ID, "rule", string(r.Reason),
			"construct_id", r.ConstructID)
	}
	for _, id := range res.NoFit {
		slog.InfoContext(ctx, "analytics", "ae", "report_construct_no_fit",
			"session_id", session.ID, "construct_id", id)
	}

	payload := metadataPayload
	payload.ReportMarkdown = ontopipe.RenderMarkdown(o, res)
	return payload, res, stats, nil
}

// ontologyReportJSON serializuje raport do postaci zapisywanej w bazie.
func ontologyReportJSON(payload ReportPayload) (string, error) {
	b, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	return string(b), nil
}
