package llmworker

import (
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	"cloud.google.com/go/aiplatform/apiv1/aiplatformpb"
	kms "cloud.google.com/go/kms/apiv1"
	"cloud.google.com/go/pubsub/v2"
	vertexai "cloud.google.com/go/vertexai/genai"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/cloudevents/sdk-go/v2/event"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/pkg/cryptobox"
	"github.com/superwizor-ai/backend/pkg/i18n/speakerlabels"
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
	if dbDSN != "" {
		dbPool, err = pgxpool.New(ctx, dbDSN)
		if err != nil {
			slog.Error("db", "error", err)
			os.Exit(1)
		}
	}

	if projectID != "" {
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

func ProcessTranscript(ctx context.Context, e event.Event) error {
	logger := slog.With("function", "llm-worker")

	var msgData MessagePublishedData
	if err := e.DataAs(&msgData); err != nil {
		logger.Error("decode cloudevent", "error", err)
		return err
	}

	var ev TranscriptCompletedEvent
	if err := json.Unmarshal(msgData.Message.Data, &ev); err != nil {
		logger.Error("parse event", "error", err)
		return err
	}

	logger = logger.With("session_id", ev.SessionID, "transcript_id", ev.TranscriptID)
	logger.Info("processing transcript")

	startTime := time.Now()

	// Each fatal step logs the error explicitly before returning so the
	// reason is visible in Cloud Logging — the Cloud Functions framework
	// only surfaces a generic HTTP 500 to the request log otherwise, and
	// we end up grepping audit logs for downstream API rejections (which
	// happened with the chunk_assignments / Vertex schema bug). Mark the
	// session FAILED on every fatal error so the polling clients see it.

	session, err := loadSession(ctx, ev.SessionID)
	if err != nil {
		logger.Error("load session", "error", err)
		_ = updateSessionStatus(ctx, ev.SessionID, "FAILED")
		return fmt.Errorf("load session: %w", err)
	}

	transcriptText, err := loadTranscriptText(ctx, ev.TranscriptID)
	if err != nil {
		logger.Error("load transcript", "error", err)
		_ = updateSessionStatus(ctx, ev.SessionID, "FAILED")
		return fmt.Errorf("load transcript: %w", err)
	}

	modalityPrompt, err := loadModalityPrompt(ctx, session.ModalityID)
	if err != nil {
		logger.Error("load modality prompt", "error", err, "modality_id", session.ModalityID)
		_ = updateSessionStatus(ctx, ev.SessionID, "FAILED")
		return fmt.Errorf("load prompt: %w", err)
	}

	ragContext, err := loadRAGContext(ctx, session.PatientFileID, transcriptText)
	if err != nil {
		logger.Warn("rag context", "error", err)
		ragContext = ""
	}

	reportJSON, tokenStats, err := generateReport(ctx, modalityPrompt, ragContext, transcriptText)
	if err != nil {
		// Vertex AI errors (quota, schema rejection, content filter,
		// region availability) all land here. Log full error text so we
		// don't have to dig through cloudaudit.googleapis.com for the
		// reason.
		logger.Error("generate report (Vertex AI)",
			"error", err,
			"prompt_len", len(modalityPrompt),
			"transcript_len", len(transcriptText),
			"rag_context_len", len(ragContext))
		_ = updateSessionStatus(ctx, ev.SessionID, "FAILED")
		return fmt.Errorf("generate: %w", err)
	}

	var report ReportPayload
	if err := json.Unmarshal([]byte(reportJSON), &report); err != nil {
		// Surface the head of the response so we can see what Gemini
		// returned vs what we expected (e.g. wrong shape, error JSON,
		// truncation). Cap to keep the log entry small.
		const peek = 1024
		preview := reportJSON
		if len(preview) > peek {
			preview = preview[:peek] + "…(truncated)"
		}
		logger.Error("parse report JSON", "error", err, "response_preview", preview)
		_ = updateSessionStatus(ctx, ev.SessionID, "FAILED")
		return fmt.Errorf("parse report: %w", err)
	}

	reportID, err := persistReport(ctx, session, ev.TranscriptID, &report, reportJSON, tokenStats, time.Since(startTime))
	if err != nil {
		logger.Error("persist report", "error", err)
		_ = updateSessionStatus(ctx, ev.SessionID, "FAILED")
		return fmt.Errorf("persist: %w", err)
	}

	// Po analizie LLM: generate speaker labels z speaker_groups + zapisz
	// do sessions.speaker_label_mapping i transcript_segments.speaker_label
	// (zob. ADR-IMPL-002 + ADR-IMPL-007).
	if err := generateAndSaveSpeakerLabels(ctx, session, ev.TranscriptID, &report); err != nil {
		logger.Warn("speaker labels", "error", err)
	}

	embedding, err := generateEmbedding(ctx, report.RAGSummaryChunk)
	if err != nil {
		logger.Warn("embedding", "error", err)
	} else {
		if err := persistRAGMemory(ctx, session, reportID, &report, embedding); err != nil {
			logger.Warn("rag persist", "error", err)
		}
	}

	if err := updateSessionStatus(ctx, ev.SessionID, "COMPLETED"); err != nil {
		logger.Warn("status", "error", err)
	}

	_ = publishReportGenerated(ctx, ev.SessionID, reportID)

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
	SpeakerLabelMapping map[int32]string
}

// ReportPayload odpowiada strukturze zwracanej przez Gemini wg report_schema.json
// (zob. Sprint 2.6.1). Zawiera m.in. wynik diaryzacji LLM (SpeakerRoleInference).
type ReportPayload struct {
	Title                           string               `json:"title"`
	SummaryShort                    string               `json:"summary_short"`
	SpeakerRoleInference            SpeakerRoleInference `json:"speaker_role_inference"`
	MainThemes                      []ThemeItem          `json:"main_themes"`
	TherapeuticAllianceObservations string               `json:"therapeutic_alliance_observations"`
	InterventionsObserved           []InterventionItem   `json:"interventions_observed"`
	HiTOPDimensions                 []HiTOPItem          `json:"hitop_dimensions"`
	RiskAssessment                  RiskAssessment       `json:"risk_assessment"`
	Sentiment                       string               `json:"sentiment"`
	RecommendationsForNextSession   []string             `json:"recommendations_for_next_session"`
	RAGSummaryChunk                 string               `json:"rag_summary_chunk"`
}

// SpeakerRoleInference reprezentuje wynik diaryzacji wykonanej przez LLM
// (ADR-IMPL-007). Zawiera (a) klastrowanie chunków na grupy mówców
// i (b) dedukowane role per grupa.
type SpeakerRoleInference struct {
	Method string `json:"method"` // 'llm_inferred' | 'native_chirp_3'
	// chunk_assignments removed — Gemini's response_schema doesn't support
	// `additionalProperties` (open string-keyed maps), and SpeakerGroups
	// already carries the inverse mapping via .ChunkIndices. If a future
	// caller needs per-chunk lookup, derive it from SpeakerGroups in code.
	SpeakerGroups                []SpeakerGroup `json:"speaker_groups"`
	OverallDiarizationConfidence float64        `json:"overall_diarization_confidence"`
}

type SpeakerGroup struct {
	Role         string  `json:"role"`
	ChunkIndices []int   `json:"chunk_indices"`
	Confidence   float64 `json:"confidence"`
	Evidence     string  `json:"evidence"`
}

type ThemeItem struct {
	Theme    string   `json:"theme"`
	Salience float64  `json:"salience"`
	Evidence []string `json:"evidence_quotes"`
}

type InterventionItem struct {
	Type            string `json:"intervention_type"`
	Description     string `json:"description"`
	PatientResponse string `json:"patient_response"`
}

type HiTOPItem struct {
	DimensionCode string  `json:"dimension_code"`
	Score         float64 `json:"score"`
	Confidence    float64 `json:"confidence"`
	Evidence      string  `json:"evidence"`
}

type RiskAssessment struct {
	Level              string   `json:"level"`
	Concerns           []string `json:"concerns"`
	RecommendedActions []string `json:"recommended_actions"`
}

type TokenStats struct {
	InputTokens  int32
	OutputTokens int32
}

//go:embed schemas/report_schema.json
var reportSchemaBytes []byte

func generateReport(ctx context.Context, modalityPrompt, ragContext, transcriptText string) (string, TokenStats, error) {
	model := vertexClient.GenerativeModel(geminiModel)

	var schema map[string]any
	if err := json.Unmarshal(reportSchemaBytes, &schema); err != nil {
		return "", TokenStats{}, fmt.Errorf("parse schema: %w", err)
	}

	model.GenerationConfig = vertexai.GenerationConfig{
		Temperature:      vertexai.Ptr[float32](0.2),
		TopP:             vertexai.Ptr[float32](0.95),
		MaxOutputTokens:  vertexai.Ptr[int32](8192),
		ResponseMIMEType: "application/json",
		ResponseSchema:   schemaToVertexSchema(schema),
	}

	prompt := fmt.Sprintf(`%s

WAŻNE — KONTEKST DIARYZACJI:
Transkrypt poniżej składa się z PONUMEROWANYCH chunków oddzielonych pauzami.
Chunki NIE mają jeszcze przypisanych mówców (Chirp 3 nie supportuje diaryzacji
dla polskiego — robimy to przez analizę treści).

Twoje zadania w jednym wywołaniu:
1. Klastrowanie: Pogrupuj chunki w 2 (lub 3 dla par/rodzin) wirtualne grupy mówców
   na podstawie stylu wypowiedzi, treści, formy zwracania się.
2. Dedukcja ról: Określ rolę każdej grupy (therapist/patient/couple_partner/...).
3. Generacja raportu: Po przypisaniu, generuj raport bazując na chunkach
   przypisanych do każdej grupy.

Wskazówki dot. klastrowania i dedukcji ról:
- Terapeuta zazwyczaj: zadaje pytania otwarte, stosuje techniki (reflektowanie,
  podsumowywanie, normalizacja), używa fachowego języka, mówi krócej.
- Pacjent zazwyczaj: opisuje swoje odczucia/objawy, odpowiada na pytania,
  mówi o sobie w pierwszej osobie o problemach, ma dłuższe wypowiedzi.
- Krótkie wtrącenia ("mhm", "tak", "rozumiem") oznaczaj jako "filler".
- W sesjach par/rodzin: 3 grupy (terapeuta + 2 osoby relacji).
- Confidence: 0.9+ jednoznaczne, 0.5-0.8 wskazówki, < 0.5 niejasne.

Zapisz wynik klastrowania w polu speaker_role_inference (method="llm_inferred").

KONTEKST POPRZEDNICH SESJI:
%s

TRANSKRYPT BIEŻĄCEJ SESJI (chunki ponumerowane):
%s

Wygeneruj raport zgodny z podanym JSON Schema. Pamiętaj o:
- Wypełnieniu speaker_role_inference.speaker_groups: dla KAŻDEJ grupy mówców
  podaj role + chunk_indices (lista indeksów chunków przypisanych do tej grupy)
  + confidence + evidence. Każdy chunk MUSI należeć do dokładnie jednej grupy
  (lub być oznaczony jako "filler" w odrębnej grupie).
- HiTOP measurements: mierz DLA pacjenta — używaj tylko chunków, które należą
  do grupy z role="patient".
- Cytatach maksymalnie 100 znaków każdy.
- W therapeutic_alliance_observations zaznacz że confidence jest niski jeśli
  overall_diarization_confidence < 0.7.
- RAG summary chunk: NIE zawierać danych identyfikujących — używać tylko etykiet
  typu "pacjent" (nie imion ani numerów chunków).`,
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

func mapSchemaType(t string) vertexai.Type {
	switch t {
	case "string":
		return vertexai.TypeString
	case "number":
		return vertexai.TypeNumber
	case "integer":
		return vertexai.TypeInteger
	case "boolean":
		return vertexai.TypeBoolean
	case "array":
		return vertexai.TypeArray
	case "object":
		return vertexai.TypeObject
	default:
		return vertexai.TypeUnspecified
	}
}

func schemaToVertexSchema(s map[string]any) *vertexai.Schema {
	if s == nil {
		return nil
	}
	vs := &vertexai.Schema{}

	if t, ok := s["type"].(string); ok {
		vs.Type = mapSchemaType(t)
	}
	if d, ok := s["description"].(string); ok {
		vs.Description = d
	}
	if e, ok := s["enum"].([]any); ok {
		for _, val := range e {
			if str, ok := val.(string); ok {
				vs.Enum = append(vs.Enum, str)
			}
		}
	}
	if p, ok := s["properties"].(map[string]any); ok {
		vs.Properties = make(map[string]*vertexai.Schema)
		for k, v := range p {
			if vMap, ok := v.(map[string]any); ok {
				vs.Properties[k] = schemaToVertexSchema(vMap)
			}
		}
	}
	if i, ok := s["items"].(map[string]any); ok {
		vs.Items = schemaToVertexSchema(i)
	}
	if req, ok := s["required"].([]any); ok {
		for _, val := range req {
			if str, ok := val.(string); ok {
				vs.Required = append(vs.Required, str)
			}
		}
	}

	return vs
}

// generateAndSaveSpeakerLabels po analizie LLM tworzy mapping speaker → label
// i zapisuje do sessions.speaker_label_mapping oraz transcript_segments.speaker_label.
//
// Strategia:
//  1. Z report.SpeakerRoleInference.SpeakerGroups dostajemy listę grup z chunk_indices.
//  2. Dla każdej grupy: przypisujemy kolejny speaker_tag (1, 2, 3...).
//  3. Generujemy lokalizowany label (z pkg/i18n/speakerlabels) per tag.
//  4. UPDATE transcript_segments — wszystkie segmenty należące do chunków z grupy.
//  5. UPDATE sessions.speaker_label_mapping = {1: "Osoba 1", 2: "Osoba 2"}.
func generateAndSaveSpeakerLabels(ctx context.Context, session *SessionContext, transcriptID string, report *ReportPayload) error {
	if dbPool == nil {
		return nil
	}
	transID, err := uuid.Parse(transcriptID)
	if err != nil {
		return err
	}

	chunkToTag := map[int]int32{}
	tagToRole := map[int32]string{}
	tag := int32(1)
	for _, group := range report.SpeakerRoleInference.SpeakerGroups {
		// Skip "filler" / "unknown" — chunki zostają z speaker_tag=0
		if group.Role == "" || group.Role == "filler" || group.Role == "unknown" {
			continue
		}
		for _, idx := range group.ChunkIndices {
			chunkToTag[idx] = tag
		}
		tagToRole[tag] = group.Role
		tag++
	}

	tagToLabel := map[int32]string{}
	for t := range tagToRole {
		tagToLabel[t] = speakerlabels.Generate(session.LanguageCode, int(t))
	}

	tx, err := dbPool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// transcript_segments są w kolejności chunków (ORDER BY start_offset_ms),
	// więc chunk_idx == row position.
	rows, err := tx.Query(ctx, `
		SELECT id FROM transcript_segments
		WHERE transcript_id = $1
		ORDER BY start_offset_ms`, transID)
	if err != nil {
		return err
	}
	segmentIDs := []uuid.UUID{}
	for rows.Next() {
		var segID uuid.UUID
		if err := rows.Scan(&segID); err != nil {
			rows.Close()
			return err
		}
		segmentIDs = append(segmentIDs, segID)
	}
	rows.Close()

	for chunkIdx, segID := range segmentIDs {
		assignedTag, ok := chunkToTag[chunkIdx]
		if !ok {
			continue
		}
		label := tagToLabel[assignedTag]
		if _, err := tx.Exec(ctx, `
			UPDATE transcript_segments
			SET speaker_tag = $1, speaker_label = $2
			WHERE id = $3`,
			assignedTag, label, segID); err != nil {
			return err
		}
	}

	mappingForJSON := map[string]string{}
	for t, label := range tagToLabel {
		mappingForJSON[fmt.Sprintf("%d", t)] = label
	}
	mappingJSON, _ := json.Marshal(mappingForJSON)
	if _, err := tx.Exec(ctx, `
		UPDATE sessions SET speaker_label_mapping = $1 WHERE id = $2`,
		mappingJSON, session.ID); err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func generateEmbedding(ctx context.Context, text string) ([]float32, error) {
	// Faza 2: stub. Faza 3: real Vertex textembedding-gecko call.
	return make([]float32, 768), nil
}

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
	if len(mappingJSON) > 0 {
		if err := json.Unmarshal(mappingJSON, &mapping); err != nil {
			return nil, fmt.Errorf("decode speaker_label_mapping: %w", err)
		}
	}

	sc.SpeakerLabelMapping = make(map[int32]string)
	for k, v := range mapping {
		var tag int32
		if _, err := fmt.Sscanf(k, "%d", &tag); err != nil {
			slog.Warn("skipping non-numeric speaker tag in mapping", "key", k, "error", err)
			continue
		}
		sc.SpeakerLabelMapping[tag] = v
	}

	return &sc, nil
}

// loadTranscriptText czyta KANONICZNY blob z transcripts (ADR-IMPL-006) i
// formatuje go dla LLM jako numerowane chunki (ADR-IMPL-007):
//
//	"[CHUNK 0] (1200ms-4500ms) Cześć, jak się czujesz dzisiaj?"
//	"[CHUNK 1] (4800ms-7800ms) Trochę zmęczona, ale ogólnie dobrze."
//
// Format umożliwia LLM odwołanie się do chunków po indeksie w polu
// speaker_role_inference.speaker_groups[*].chunk_indices.
func loadTranscriptText(ctx context.Context, transcriptID string) (string, error) {
	id, err := uuid.Parse(transcriptID)
	if err != nil {
		return "", err
	}

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

	type BlobLine struct {
		ChunkIdx     int     `json:"chunk_idx"`
		Text         string  `json:"text"`
		StartMS      int64   `json:"start_ms"`
		EndMS        int64   `json:"end_ms"`
		WordCount    int     `json:"word_count"`
		Confidence   float32 `json:"confidence"`
		SpeakerTag   *int32  `json:"speaker_tag,omitempty"`
		SpeakerLabel *string `json:"speaker_label,omitempty"`
	}

	var lines []BlobLine
	if err := json.Unmarshal(blobJSONBytes, &lines); err != nil {
		return "", fmt.Errorf("unmarshal transcript blob: %w", err)
	}

	var sb strings.Builder
	for _, l := range lines {
		if l.SpeakerLabel != nil && *l.SpeakerLabel != "" {
			// Native diarization: pokazujemy speaker label
			fmt.Fprintf(&sb, "[CHUNK %d / %s] (%dms-%dms) %s\n",
				l.ChunkIdx, *l.SpeakerLabel, l.StartMS, l.EndMS, l.Text)
		} else {
			// Default flow (v1.2): tylko numerowany chunk, LLM przypisze speaker
			fmt.Fprintf(&sb, "[CHUNK %d] (%dms-%dms) %s\n",
				l.ChunkIdx, l.StartMS, l.EndMS, l.Text)
		}
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
	if err := json.Unmarshal(promptJSON, &prompt); err != nil {
		return "", fmt.Errorf("decode therapist_ai_general_prompt: %w", err)
	}
	return prompt["system"], nil
}

func loadRAGContext(ctx context.Context, patientFileID uuid.UUID, currentText string) (string, error) {
	// Faza 2 stub. Faza 3: query embedding + similarity search via pgvector.
	return "", nil
}

func persistReport(ctx context.Context, session *SessionContext, transcriptID string, report *ReportPayload, fullJSON string, tokenStats TokenStats, processingTime time.Duration) (string, error) {
	transID, err := uuid.Parse(transcriptID)
	if err != nil {
		return "", err
	}
	reportID := uuid.New()

	ciphertext, encDEK, err := crypto.Encrypt(ctx, []byte(fullJSON))
	if err != nil {
		return "", fmt.Errorf("encrypt report: %w", err)
	}

	tx, err := dbPool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	costUSD := float64(tokenStats.InputTokens)*0.00000125 + float64(tokenStats.OutputTokens)*0.000005

	roleInferenceJSON, _ := json.Marshal(report.SpeakerRoleInference)

	_, err = tx.Exec(ctx, `
		INSERT INTO reports (id, session_id, transcript_id, modality_id,
			report_ciphertext, report_encrypted_dek, title, summary_short,
			sentiment_label, risk_level, speaker_role_inference,
			llm_model, llm_input_tokens,
			llm_output_tokens, llm_processing_seconds, llm_total_cost_usd)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)`,
		reportID, session.ID, transID, session.ModalityID,
		ciphertext, encDEK, report.Title, report.SummaryShort,
		report.Sentiment, report.RiskAssessment.Level, roleInferenceJSON,
		geminiModel,
		tokenStats.InputTokens, tokenStats.OutputTokens,
		int(processingTime.Seconds()), costUSD)
	if err != nil {
		return "", err
	}

	for _, h := range report.HiTOPDimensions {
		var dimID uuid.UUID
		err := tx.QueryRow(ctx,
			"SELECT id FROM hitop_dimensions WHERE code = $1", h.DimensionCode).Scan(&dimID)
		if err == pgx.ErrNoRows {
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
	repID, err := uuid.Parse(reportID)
	if err != nil {
		return err
	}

	summaryCipher, summaryDEK, err := crypto.Encrypt(ctx, []byte(report.RAGSummaryChunk))
	if err != nil {
		return fmt.Errorf("encrypt rag summary: %w", err)
	}

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
	if dbPool == nil {
		return nil
	}
	id, err := uuid.Parse(sessionID)
	if err != nil {
		return err
	}
	_, err = dbPool.Exec(ctx,
		"UPDATE sessions SET status = $1, status_updated_at = now() WHERE id = $2",
		status, id)
	return err
}

func publishReportGenerated(ctx context.Context, sessionID, reportID string) error {
	if pubsubClient == nil {
		return nil
	}
	topic := pubsubClient.Publisher("report.generated")
	defer topic.Stop()

	payload, _ := json.Marshal(map[string]string{
		"session_id": sessionID,
		"report_id":  reportID,
	})
	res := topic.Publish(ctx, &pubsub.Message{Data: payload})
	_, err := res.Get(ctx)
	return err
}

var _ = aiplatformpb.PredictRequest{}
