package llmworker

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	"cloud.google.com/go/aiplatform/apiv1/aiplatformpb"
	kms "cloud.google.com/go/kms/apiv1"
	"cloud.google.com/go/pubsub"
	vertexai "cloud.google.com/go/vertexai/genai"
	"github.com/GoogleCloudPlatform/functions-framework-go/funcframework"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/cloudevents/sdk-go/v2/event"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/pkg/cryptobox"
)

type TranscriptCompletedEvent struct {
	SessionID    string `json:"session_id"`
	TranscriptID string `json:"transcript_id"`
}

type MessagePublishedData struct {
	Message struct {
		Data       []byte            `json:"data"`
		Attributes map[string]string `json:"attributes"`
	} `json:"message"`
}

var (
	dbPool       *pgxpool.Pool
	vertexClient *vertexai.Client
	pubsubClient *pubsub.Client
	crypto       cryptobox.CryptoBox
	projectID    string
	geminiModel  string = "gemini-2.5-pro"
	geminiRegion string = "europe-west4"
)

func init() {
	ctx := context.Background()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	projectID = os.Getenv("GCP_PROJECT_ID")
	dbDSN := os.Getenv("DATABASE_URL")
	kmsKeyURI := os.Getenv("KMS_KEY_URI")

	var err error
	dbPool, err = pgxpool.New(ctx, dbDSN)
	if err != nil {
		slog.Error("db", "error", err)
		os.Exit(1)
	}

	vertexClient, err = vertexai.NewClient(ctx, projectID, geminiRegion)
	if err != nil {
		slog.Error("vertex", "error", err)
		os.Exit(1)
	}

	pubsubClient, err = pubsub.NewClient(ctx, projectID)
	if err != nil {
		slog.Error("pubsub", "error", err)
		os.Exit(1)
	}

	if kmsKeyURI != "" {
		kmsClient, err := kms.NewKeyManagementClient(ctx)
		if err != nil {
			slog.Error("kms client", "error", err)
			os.Exit(1)
		}
		crypto = cryptobox.NewCloudKMSBox(kmsClient, kmsKeyURI)
	} else {
		crypto = cryptobox.NewMockBox()
	}

	functions.CloudEvent("ProcessTranscript", ProcessTranscript)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	if err := funcframework.Start(port); err != nil {
		slog.Error("framework", "error", err)
		os.Exit(1)
	}
}

func ProcessTranscript(ctx context.Context, e event.Event) error {
	logger := slog.With("function", "llm-worker")

	var msgData MessagePublishedData
	if err := e.DataAs(&msgData); err != nil {
		logger.Error("decode cloudevent", "error", err)
		return err
	}

	var event TranscriptCompletedEvent
	if err := json.Unmarshal(msgData.Message.Data, &event); err != nil {
		logger.Error("parse event", "error", err)
		return err
	}

	logger = logger.With("session_id", event.SessionID, "transcript_id", event.TranscriptID)
	logger.Info("processing transcript")

	startTime := time.Now()

	// 1. Load session context
	session, err := loadSession(ctx, event.SessionID)
	if err != nil {
		return fmt.Errorf("load session: %w", err)
	}

	// 2. Load transcript z kanonicznego blob (ADR-IMPL-006)
	transcriptText, err := loadTranscriptText(ctx, event.TranscriptID)
	if err != nil {
		return fmt.Errorf("load transcript: %w", err)
	}

	// 3. Load modality prompt
	modalityPrompt, err := loadModalityPrompt(ctx, session.ModalityID)
	if err != nil {
		return fmt.Errorf("load prompt: %w", err)
	}

	// 4. Load RAG context (top 5 najbardziej relevantnych memories)
	ragContext, err := loadRAGContext(ctx, session.PatientFileID, transcriptText)
	if err != nil {
		logger.Warn("rag context", "error", err)
		ragContext = ""
	}

	// 5. Generate report z Gemini
	reportJSON, tokenStats, err := generateReport(ctx, modalityPrompt, ragContext, transcriptText)
	if err != nil {
		_ = updateSessionStatus(ctx, event.SessionID, "FAILED")
		return fmt.Errorf("generate: %w", err)
	}

	// 6. Parse + validate report
	var report ReportPayload
	if err := json.Unmarshal([]byte(reportJSON), &report); err != nil {
		return fmt.Errorf("parse report: %w", err)
	}

	// 7. Persist report + HiTOP measurements
	reportID, err := persistReport(ctx, session, event.TranscriptID, &report, reportJSON, tokenStats, time.Since(startTime))
	if err != nil {
		return fmt.Errorf("persist: %w", err)
	}

	// 8. Generate embedding dla RAG memory chunk
	embedding, err := generateEmbedding(ctx, report.RAGSummaryChunk)
	if err != nil {
		logger.Warn("embedding", "error", err)
	} else {
		if err := persistRAGMemory(ctx, session, reportID, &report, embedding); err != nil {
			logger.Warn("rag persist", "error", err)
		}
	}

	// 9. Update status COMPLETED
	if err := updateSessionStatus(ctx, event.SessionID, "COMPLETED"); err != nil {
		logger.Warn("status", "error", err)
	}

	// 10. Publish report.generated
	_ = publishReportGenerated(ctx, event.SessionID, reportID)

	logger.Info("done",
		"report_id", reportID,
		"duration_ms", time.Since(startTime).Milliseconds(),
		"input_tokens", tokenStats.InputTokens,
		"output_tokens", tokenStats.OutputTokens)

	return nil
}

type SessionContext struct {
	ID                  uuid.UUID
	PatientFileID       uuid.UUID
	ModalityID          uuid.UUID
	LanguageCode        string
	SpeakerLabelMapping map[int32]string  // {1: "Osoba 1", 2: "Osoba 2"}
}

type ReportPayload struct {
	PodsumowanieSesji            string                          `json:"podsumowanie_sesji"`
	WnikliweObserwacje           string                          `json:"wnikliwe_obserwacje"`
	PlanDzialaniaKlienta         string                          `json:"plan_dzialania_klienta"`
	PropozycjeInterwencji        string                          `json:"propozycje_interwencji"`
	WatkiDoPoglebienia           string                          `json:"watki_do_poglebienia"`
	WskazowkiSuperwizyjne        string                          `json:"wskazowki_superwizyjne"`
	WstepneHipotezyDiagnostyczne string                          `json:"wstepne_hipotezy_diagnostyczne"`
	SpeakerRoleInference         map[string]SpeakerRoleInference `json:"speaker_role_inference"`
	HiTOPDimensions              []HiTOPItem                     `json:"hitop_dimensions"`
	RAGSummaryChunk              string                          `json:"rag_summary_chunk"`
}

type SpeakerRoleInference struct {
	Role       string  `json:"role"`         // 'therapist', 'patient', 'couple_partner', etc.
	Confidence float64 `json:"confidence"`
	Evidence   string  `json:"evidence"`
}

type HiTOPItem struct {
	DimensionCode string  `json:"dimension_code"`
	Score         float64 `json:"score"`
	Confidence    float64 `json:"confidence"`
	Evidence      string  `json:"evidence"`
}

type TokenStats struct {
	InputTokens  int32
	OutputTokens int32
}

func generateReport(ctx context.Context, modalityPrompt, ragContext, transcriptText string) (string, TokenStats, error) {
	model := vertexClient.GenerativeModel(geminiModel)

	// Load schema
	schemaBytes, _ := os.ReadFile("schemas/report_schema.json")
	var schema map[string]any
	json.Unmarshal(schemaBytes, &schema)

	model.GenerationConfig = vertexai.GenerationConfig{
		Temperature:      vertexai.Ptr[float32](0.2),
		TopP:             vertexai.Ptr[float32](0.95),
		MaxOutputTokens:  vertexai.Ptr[int32](8192),
		ResponseMIMEType: "application/json",
		ResponseSchema:   schemaToVertexSchema(schema),
	}

	prompt := fmt.Sprintf(`%s

UWAGA O ETYKIETACH MÓWCÓW:
Transkrypt zawiera neutralne etykiety mówców (np. "Osoba 1", "Osoba 2" lub "Person 1", "Person 2") — to NIE są role, tylko numeracja.
Twoim zadaniem jest **dedukować role z kontekstu rozmowy** i zapisać dedukcję w polu speaker_role_inference.

Wskazówki dot. dedukcji ról:
- Osoba pełniąca rolę terapeuty zazwyczaj: zadaje pytania otwarte, stosuje techniki (np. socratic questioning, reflektowanie), używa fachowego języka, kieruje rozmową.
- Osoba pełniąca rolę pacjenta zazwyczaj: opisuje swoje odczucia/objawy, odpowiada na pytania, mówi o sobie w pierwszej osobie o problemach.
- W sesjach par/rodzin: wskaż couple_partner / family_member_*. Jeśli niejasne — użyj 'unknown'.
- Confidence: 0.9+ jeśli wzorce są jednoznaczne, 0.5-0.8 jeśli są wskazówki ale nie pewność, < 0.5 jeśli niejasne.

KONTEKST POPRZEDNICH SESJI:
%s

TRANSKRYPT BIEŻĄCEJ SESJI:
%s

Wygeneruj raport zgodny z podanym JSON Schema. Pamiętaj o:
- Dedukcji ról dla KAŻDEJ etykiety mówcy w transkrypcie (speaker_role_inference).
- Cytatach maksymalnie 100 znaków każdy.
- Skali HiTOP: 0-100 score, 0-1 confidence (mierzymy DLA pacjenta — używaj tylko wypowiedzi osoby zdedukowanej jako 'patient').
- RAG summary chunk: NIE zawierać danych identyfikujących — używać tylko etykiet typu "pacjent" (nie imion ani neutralnych labels).`,
		modalityPrompt, ragContext, transcriptText)

	resp, err := model.GenerateContent(ctx, vertexai.Text(prompt))
	if err != nil {
		return "", TokenStats{}, err
	}

	if len(resp.Candidates) == 0 || resp.Candidates[0].Content == nil {
		return "", TokenStats{}, fmt.Errorf("no candidates returned")
	}

	var output strings.Builder
	for _, part := range resp.Candidates[0].Content.Parts {
		if text, ok := part.(vertexai.Text); ok {
			output.WriteString(string(text))
		}
	}

	stats := TokenStats{}
	if resp.UsageMetadata != nil {
		stats.InputTokens = resp.UsageMetadata.PromptTokenCount
		stats.OutputTokens = resp.UsageMetadata.CandidatesTokenCount
	}

	return output.String(), stats, nil
}

func schemaToVertexSchema(s map[string]any) *vertexai.Schema {
	// Konwersja JSON Schema → Vertex AI Schema (uproszczone)
	schemaJSON, _ := json.Marshal(s)
	var vs vertexai.Schema
	_ = json.Unmarshal(schemaJSON, &vs)
	return &vs
}

func generateEmbedding(ctx context.Context, text string) ([]float32, error) {
	// Use textembedding-gecko via Vertex AI
	// W Fazie 2: stub embedding (np. zera lub random)
	// W Fazie 3: real Vertex embeddings call
	return make([]float32, 768), nil
}

// SQL helpers (simplified)

func loadSession(ctx context.Context, sessionID string) (*SessionContext, error) {
	id, err := uuid.Parse(sessionID)
	if err != nil {
		return nil, err
	}

	var sc SessionContext
	sc.ID = id

	var mappingJSON []byte
	var langCode *string
	row := dbPool.QueryRow(ctx, `
		SELECT s.patient_file_id, pf.modality_id, s.speaker_label_mapping, s.language_code
		FROM sessions s
		JOIN patient_files pf ON pf.id = s.patient_file_id
		WHERE s.id = $1`, id)
	if err := row.Scan(&sc.PatientFileID, &sc.ModalityID, &mappingJSON, &langCode); err != nil {
		return nil, err
	}

	if langCode != nil {
		sc.LanguageCode = *langCode
	}

	mapping := map[string]string{}
	json.Unmarshal(mappingJSON, &mapping)

	sc.SpeakerLabelMapping = make(map[int32]string)
	for k, v := range mapping {
		var tag int32
		fmt.Sscanf(k, "%d", &tag)
		sc.SpeakerLabelMapping[tag] = v
	}

	return &sc, nil
}

// loadTranscriptText czyta transkrypt z KANONICZNEGO blob'a w transcripts (ADR-IMPL-006).
// NIE iteruje po segments — pełny tekst jest jednym zaszyfrowanym JSON-em.
//
// Format blob (po decrypt): JSON array z {speaker_tag, speaker_label, text, start_ms, end_ms}.
// Zwraca sformatowany tekst dla LLM:
//   "[Osoba 1] (1200ms-4500ms) Cześć, jak się czujesz dzisiaj?"
//   "[Osoba 2] (4600ms-7800ms) Trochę zmęczona, ale ogólnie dobrze."
func loadTranscriptText(ctx context.Context, transcriptID string) (string, error) {
	id, _ := uuid.Parse(transcriptID)

	var ciphertext []byte
	var encryptedDEK []byte
	row := dbPool.QueryRow(ctx,
		"SELECT transcript_ciphertext, transcript_encrypted_dek FROM transcripts WHERE id = $1", id)
	if err := row.Scan(&ciphertext, &encryptedDEK); err != nil {
		return "", err
	}

	blobJSONBytes, err := crypto.Decrypt(ctx, ciphertext, encryptedDEK)
	if err != nil {
		return "", fmt.Errorf("decrypt transcript blob: %w", err)
	}
	blobJSON := string(blobJSONBytes)

	type BlobLine struct {
		SpeakerTag   int32  `json:"speaker_tag"`
		SpeakerLabel string `json:"speaker_label"`
		Text         string `json:"text"`
		StartMS      int64  `json:"start_ms"`
		EndMS        int64  `json:"end_ms"`
	}

	var lines []BlobLine
	if err := json.Unmarshal([]byte(blobJSON), &lines); err != nil {
		return "", fmt.Errorf("unmarshal transcript blob: %w", err)
	}

	var sb strings.Builder
	for _, l := range lines {
		fmt.Fprintf(&sb, "[%s] (%dms-%dms) %s\n", l.SpeakerLabel, l.StartMS, l.EndMS, l.Text)
	}

	return sb.String(), nil
}

func loadModalityPrompt(ctx context.Context, modalityID uuid.UUID) (string, error) {
	var promptJSON []byte
	row := dbPool.QueryRow(ctx,
		"SELECT therapist_ai_general_prompt FROM modalities WHERE id = $1", modalityID)
	if err := row.Scan(&promptJSON); err != nil {
		return "", err
	}

	var prompt map[string]string
	json.Unmarshal(promptJSON, &prompt)
	return prompt["system"], nil
}

func loadRAGContext(ctx context.Context, patientFileID uuid.UUID, currentText string) (string, error) {
	// W Fazie 2 stub — return empty.
	// W Fazie 3 generate query embedding + similarity search via pgvector.
	return "", nil
}

func persistReport(ctx context.Context, session *SessionContext, transcriptID string, report *ReportPayload, fullJSON string, tokenStats TokenStats, processingTime time.Duration) (string, error) {
	transID, _ := uuid.Parse(transcriptID)
	reportID := uuid.New()

	ciphertext, encDEK, err := crypto.Encrypt(ctx, []byte(fullJSON))
	if err != nil {
		return "", fmt.Errorf("encrypt report: %w", err)
	}

	tx, err := dbPool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)

	costUSD := float64(tokenStats.InputTokens)*0.00000125 + float64(tokenStats.OutputTokens)*0.000005

	// Marshal speaker_role_inference dla JSONB column
	roleInferenceJSON, _ := json.Marshal(report.SpeakerRoleInference)

	_, err = tx.Exec(ctx, `
		INSERT INTO reports (id, session_id, transcript_id, modality_id,
			report_ciphertext, report_encrypted_dek, title, summary_short,
			sentiment_label, risk_level, speaker_role_inference,
			llm_model, llm_input_tokens,
			llm_output_tokens, llm_processing_seconds, llm_total_cost_usd)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)`,
		reportID, session.ID, transID, session.ModalityID,
		ciphertext, encDEK, "", report.PodsumowanieSesji,
		"", "", roleInferenceJSON,
		geminiModel,
		tokenStats.InputTokens, tokenStats.OutputTokens,
		int(processingTime.Seconds()), costUSD)
	if err != nil {
		return "", err
	}

	// HiTOP measurements
	for _, h := range report.HiTOPDimensions {
		var dimID uuid.UUID
		err := tx.QueryRow(ctx,
			"SELECT id FROM hitop_dimensions WHERE code = $1", h.DimensionCode).Scan(&dimID)
		if err == pgx.ErrNoRows {
			// Auto-create dimension if not exists (Faza 2 quick-and-dirty; Faza 3 strict)
			dimID = uuid.New()
			_, _ = tx.Exec(ctx,
				"INSERT INTO hitop_dimensions (id, code, display_name, level) VALUES ($1, $2, $2, 'syndrome')",
				dimID, h.DimensionCode)
		} else if err != nil {
			continue
		}

		evidenceCipher, evidenceDEK, eErr := crypto.Encrypt(ctx, []byte(h.Evidence))
		if eErr != nil {
			continue
		}

		_, err = tx.Exec(ctx, `
			INSERT INTO hitop_measurements (session_id, report_id, dimension_id,
				score, confidence, evidence_ciphertext, evidence_encrypted_dek)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			ON CONFLICT (session_id, dimension_id) DO UPDATE
			SET score = EXCLUDED.score, confidence = EXCLUDED.confidence`,
			session.ID, reportID, dimID, h.Score, h.Confidence, evidenceCipher, evidenceDEK)
		if err != nil {
			continue
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return "", err
	}

	return reportID.String(), nil
}

func persistRAGMemory(ctx context.Context, session *SessionContext, reportID string, report *ReportPayload, embedding []float32) error {
	repID, _ := uuid.Parse(reportID)

	summaryCipher, summaryDEK, err := crypto.Encrypt(ctx, []byte(report.RAGSummaryChunk))
	if err != nil {
		return fmt.Errorf("encrypt rag summary: %w", err)
	}

	// Convert embedding to pgvector format string
	embeddingStr := vectorToString(embedding)

	_, err = dbPool.Exec(ctx, `
		INSERT INTO rag_memories (patient_file_id, source_session_id, source_report_id,
			summary_ciphertext, summary_encrypted_dek, embedding,
			chunk_type, importance_score)
		VALUES ($1, $2, $3, $4, $5, $6::vector, 'summary', 0.7)`,
		session.PatientFileID, session.ID, repID, summaryCipher, summaryDEK, embeddingStr)
	return err
}

func vectorToString(v []float32) string {
	var sb strings.Builder
	sb.WriteString("[")
	for i, x := range v {
		if i > 0 {
			sb.WriteString(",")
		}
		fmt.Fprintf(&sb, "%f", x)
	}
	sb.WriteString("]")
	return sb.String()
}

func updateSessionStatus(ctx context.Context, sessionID, status string) error {
	id, _ := uuid.Parse(sessionID)
	_, err := dbPool.Exec(ctx,
		"UPDATE sessions SET status = $1, status_updated_at = now() WHERE id = $2",
		status, id)
	return err
}

func publishReportGenerated(ctx context.Context, sessionID, reportID string) error {
	topic := pubsubClient.Topic("report.generated")
	defer topic.Stop()

	payload, _ := json.Marshal(map[string]string{
		"session_id": sessionID,
		"report_id":  reportID,
	})
	res := topic.Publish(ctx, &pubsub.Message{Data: payload})
	_, err := res.Get(ctx)
	return err
}

// Stub for unused import
var _ = aiplatformpb.PredictRequest{}
