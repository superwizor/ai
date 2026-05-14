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
	// gemini-2.5-flash — bumped from flash-lite (2026-05-14) on the
	// feat/llm-optimisation branch. The flash-lite line has a
	// documented structured-output weakness ("prefers concise
	// instructions or short JSON"); the metadata-step schema (an
	// array of speaker_groups with nested chunk index arrays) is
	// exactly the shape that struggles. Flash's structured output is
	// "plugged directly into a downstream parser without cleaning in
	// most cases." Cost increases from $0.0375/M+$0.15/M to
	// $0.075/M+$0.30/M input/output — roughly $0.002/session at
	// typical 40-min volumes (vs $0.0007). Negligible at our scale.
	//
	// Available in europe-west4 since the 2.5 GA rollout. When
	// gemini-3-flash lands in europe-west4 we'll evaluate the swap
	// separately via the llm-eval matrix; do not chain a model bump
	// into the Markdown-mode rollout — one variable at a time.
	geminiModel  string = "gemini-2.5-flash"
	geminiRegion string = "europe-west4"
	// debugLogPrompts controls whether we emit the full prompt sent to
	// Vertex + the full raw response back, to Cloud Logging. Gated by
	// the LLM_DEBUG_LOG_PROMPTS env var ("true" = on, anything else =
	// off) so it's an explicit opt-in.
	//
	// PHI WARNING: every prompt embeds the full session transcript
	// and every response is a clinical report. Turning this on writes
	// PHI to Cloud Logging — only enable on staging / a dedicated
	// debug deployment, NEVER on the production data path that
	// serves real therapists. Audit logs are subject to a 30-day
	// retention by default; the operator MUST verify their
	// log-sink + retention policy is appropriate before flipping
	// this flag.
	debugLogPrompts bool
)

func init() {
	ctx := context.Background()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	projectID = os.Getenv("GCP_PROJECT_ID")
	dbDSN := os.Getenv("DATABASE_URL")
	kmsKeyURI := os.Getenv("KMS_KEY_URI")
	debugLogPrompts = os.Getenv("LLM_DEBUG_LOG_PROMPTS") == "true"
	if debugLogPrompts {
		// Log loudly at startup so the operator sees this is on the
		// moment the instance comes up — easier to catch a debug
		// flag accidentally left enabled in production.
		slog.Warn("LLM_DEBUG_LOG_PROMPTS=true — every prompt + response will be written to Cloud Logging (includes PHI)")
	}

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

	reportJSON, tokenStats, err := generateReport(ctx, session.ReportLanguage, modalityPrompt, ragContext, transcriptText)
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
		// Do NOT flip sessions.status to FAILED here — Gemini
		// occasionally truncates output and Pub/Sub will redeliver.
		// Observed in production: first 1-2 attempts fail mid-JSON,
		// then a redelivery succeeds (output token nondeterminism).
		// Mirroring "FAILED" to Firestore between retries produced
		// a jarring UI flash. Status stays ANALYZING until the
		// Pub/Sub subscription's max-delivery-attempts is exhausted
		// and the message lands in audio.uploaded.dlq /
		// transcript.completed.dlq — the DLQ consumer is what
		// surfaces the genuine dead-letter as FAILED.
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
	ReportLanguage      string
}

type ReportPayload struct {
	Title                string               `json:"title"`
	SummaryShort         string               `json:"summary_short"`
	SpeakerRoleInference SpeakerRoleInference `json:"speaker_role_inference"`
	ReportMarkdown       string               `json:"report_markdown"`
	RAGSummaryChunk      string               `json:"rag_summary_chunk"`
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

// Removed HiTOPItem struct

type TokenStats struct {
	InputTokens  int32
	OutputTokens int32
}

//go:embed schemas/report_schema.json
var reportSchemaBytes []byte

func generateReport(ctx context.Context, reportLanguage, modalityPrompt, ragContext, transcriptText string) (string, TokenStats, error) {
	model := vertexClient.GenerativeModel(geminiModel)
	
	// --- Krok 1: Diaryzacja i Metadane (JSON Mode) ---
	var schema map[string]any
	if err := json.Unmarshal(reportSchemaBytes, &schema); err != nil {
		return "", TokenStats{}, fmt.Errorf("parse schema: %w", err)
	}

	model.GenerationConfig = vertexai.GenerationConfig{
		Temperature: vertexai.Ptr[float32](0.1),
		TopP:        vertexai.Ptr[float32](0.95),
		// 16384 is a safety margin for the metadata JSON step.
		// Typical successful output is ~1-2k tokens (title +
		// summary_short + speaker_groups + rag_summary_chunk), but
		// the 8192 cap occasionally truncated mid-`speaker_groups`
		// array on long sessions with many chunks. The wider cap
		// eliminates that truncation cliff — cost is unchanged
		// because you only pay for tokens actually generated.
		MaxOutputTokens:  vertexai.Ptr[int32](16384),
		ResponseMIMEType: "application/json",
		ResponseSchema:   schemaToVertexSchema(schema),
	}

	metadataPrompt := fmt.Sprintf(`
WAŻNE — KONTEKST DIARYZACJI I METADANYCH:
Transkrypt poniżej składa się z PONUMEROWANYCH chunków oddzielonych pauzami.
Chunki NIE mają jeszcze przypisanych mówców.

Twoje zadania:
1. Klastrowanie: Pogrupuj chunki w 2 (lub 3 dla par/rodzin) wirtualne grupy mówców.
2. Dedukcja ról: Określ rolę każdej grupy (therapist/patient/...).
3. Metadane: Wygeneruj krótki tytuł i streszczenie.

Wskazówki dot. klastrowania:
- Terapeuta: zadaje pytania, stosuje techniki, mówi krócej.
- Pacjent: opisuje odczucia, odpowiada, ma dłuższe wypowiedzi.

JĘZYK RAPORTU: %s

KONTEKST POPRZEDNICH SESJI:
%s

TRANSKRYPT BIEŻĄCEJ SESJI:
%s

Wygeneruj TYLKO metadane zgodnie z podanym JSON Schema.

ZASADY ZWIĘZŁOŚCI (kluczowe — nie ignoruj):
- title: max 100 znaków, jedno zdanie/fraza.
- summary_short: max 500 znaków, 2-3 zdania.
- evidence (cytaty z transkryptu): pojedynczy cytat, max 200 znaków.
- rag_summary_chunk: max 1500 znaków, kluczowe fakty dla pamięci długoterminowej.
- Pisz konkretami, NIE parafrazuj całych wypowiedzi.`,
		reportLanguage, ragContext, transcriptText)

	debugLogChunked(slog.Default(), "vertex_prompt", "step", "metadata", "content", metadataPrompt)

	respMetadata, err := model.GenerateContent(ctx, vertexai.Text(metadataPrompt))
	if err != nil {
		return "", TokenStats{}, fmt.Errorf("generate metadata: %w", err)
	}
	if len(respMetadata.Candidates) == 0 || respMetadata.Candidates[0].Content == nil {
		return "", TokenStats{}, fmt.Errorf("no candidates returned for metadata")
	}

	var metaOutput strings.Builder
	for _, part := range respMetadata.Candidates[0].Content.Parts {
		if text, ok := part.(vertexai.Text); ok {
			metaOutput.WriteString(string(text))
		}
	}

	debugLogChunked(slog.Default(), "vertex_response", "step", "metadata", "content", metaOutput.String())

	var metadataPayload ReportPayload
	if err := json.Unmarshal([]byte(metaOutput.String()), &metadataPayload); err != nil {
		return "", TokenStats{}, fmt.Errorf("parse metadata json: %w", err)
	}

	stats := TokenStats{}
	if respMetadata.UsageMetadata != nil {
		stats.InputTokens += respMetadata.UsageMetadata.PromptTokenCount
		stats.OutputTokens += respMetadata.UsageMetadata.CandidatesTokenCount
	}

	// --- Krok 2: Pełny Raport Kliniczny (Raw Text Mode) ---
	model.GenerationConfig = vertexai.GenerationConfig{
		Temperature:      vertexai.Ptr[float32](0.3),
		TopP:             vertexai.Ptr[float32](0.95),
		// Vertex enforces this as an EXCLUSIVE upper bound on
		// gemini-2.5-flash-lite — 65536 is rejected with
		// "supported range is from 1 (inclusive) to 65536 (exclusive)".
		// 65535 is the highest accepted value.
		MaxOutputTokens:  vertexai.Ptr[int32](65535),
		ResponseMIMEType: "text/plain",
	}

	reportPrompt := fmt.Sprintf(`%s

JĘZYK RAPORTU: %s
Wygeneruj CAŁY raport w tym języku. Cytaty z transkryptu pozostaw w oryginale.
Sformatuj raport używając czytelnego Markdown (nagłówki ##, pogrubienia, cytaty).

ZASADY ZWIĘZŁOŚCI (kluczowe — nie ignoruj):
- Raport powinien być WARTOŚCIOWY dla superwizora, NIE wielostronicowy.
- Każda sekcja: 2-5 zdań, max 1 akapit. Wyjątek: studium przypadku / hipotezy
  kliniczne — do 2 akapitów gdy uzasadnione.
- Cytaty z transkryptu: krótkie (1-2 zdania), tylko gdy bezpośrednio
  ilustrują obserwację. Nie cytuj dla samego cytowania.
- UNIKAJ powtórzeń między sekcjami — każda informacja w raporcie max raz.
- Pisz konkretami, używaj fachowego języka, ale nie nadużywaj żargonu.
- NIE rozwijaj sekcji o pola, których szablon nie wymaga.
- Pomijaj nagłówki sekcji jeśli ich treść byłaby pusta/spekulatywna.

KONTEKST POPRZEDNICH SESJI:
%s

TRANSKRYPT BIEŻĄCEJ SESJI:
%s`,
		modalityPrompt, reportLanguage, ragContext, transcriptText)

	debugLogChunked(slog.Default(), "vertex_prompt", "step", "markdown", "content", reportPrompt)

	respReport, err := model.GenerateContent(ctx, vertexai.Text(reportPrompt))
	if err != nil {
		return "", TokenStats{}, fmt.Errorf("generate report markdown: %w", err)
	}
	if len(respReport.Candidates) == 0 || respReport.Candidates[0].Content == nil {
		return "", TokenStats{}, fmt.Errorf("no candidates returned for report markdown")
	}

	var reportOutput strings.Builder
	for _, part := range respReport.Candidates[0].Content.Parts {
		if text, ok := part.(vertexai.Text); ok {
			reportOutput.WriteString(string(text))
		}
	}

	debugLogChunked(slog.Default(), "vertex_response", "step", "markdown", "content", reportOutput.String())

	if respReport.UsageMetadata != nil {
		stats.InputTokens += respReport.UsageMetadata.PromptTokenCount
		stats.OutputTokens += respReport.UsageMetadata.CandidatesTokenCount
	}

	// --- Połączenie wyników ---
	metadataPayload.ReportMarkdown = reportOutput.String()

	finalJSON, err := json.Marshal(metadataPayload)
	if err != nil {
		return "", TokenStats{}, fmt.Errorf("marshal final payload: %w", err)
	}

	return string(finalJSON), stats, nil
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
	var reportLang *string
	row := dbPool.QueryRow(ctx, `
		SELECT s.patient_file_id, pf.modality_id, s.speaker_label_mapping, s.language_code, s.report_language
		FROM sessions s
		JOIN patient_files pf ON pf.id = s.patient_file_id
		WHERE s.id = $1`, id)
	if err := row.Scan(&sc.PatientFileID, &sc.ModalityID, &mappingJSON, &langCode, &reportLang); err != nil {
		return nil, err
	}

	if langCode != nil {
		sc.LanguageCode = *langCode
	}
	if reportLang != nil {
		sc.ReportLanguage = *reportLang
	} else {
		sc.ReportLanguage = "pl" // fallback just in case
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
		nil, nil, roleInferenceJSON,
		geminiModel,
		tokenStats.InputTokens, tokenStats.OutputTokens,
		int(processingTime.Seconds()), costUSD)
	if err != nil {
		return "", err
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

// debugLogChunked emits the prompt or response payload to Cloud
// Logging in fixed-size chunks when `debugLogPrompts` is on. Gated
// by env var LLM_DEBUG_LOG_PROMPTS=true — never enabled by default.
//
// Why chunked: Cloud Logging caps a single jsonPayload entry at
// 256 KB, but a typical session prompt is ~10-30 KB and a 60-min
// transcript can blow past that. We split into 60 KB chunks
// (leaves headroom for the slog wrapper fields) and emit one log
// line per chunk with a `chunk_seq` / `chunk_total` pair so the
// reader can stitch them back together.
//
// Caller passes attributes as variadic key/value pairs after the
// `content` arg — the function strips out `content` and adds it
// last as its own field. Other attrs (e.g. session_id, step) are
// preserved across every chunk so Cloud Logging filters work.
//
// PHI note: see the comment on debugLogPrompts. Every line written
// here contains the full transcript and/or report. Audit + retain
// accordingly.
func debugLogChunked(logger *slog.Logger, msg string, kvs ...any) {
	if !debugLogPrompts {
		return
	}
	const chunkBytes = 60 * 1024 // 60 KB — well below Cloud Logging's 256 KB cap

	// Extract `content` from the variadic args. If absent, just log
	// the attrs and return (still useful as a marker).
	var content string
	rest := make([]any, 0, len(kvs))
	for i := 0; i+1 < len(kvs); i += 2 {
		k, _ := kvs[i].(string)
		if k == "content" {
			if s, ok := kvs[i+1].(string); ok {
				content = s
			}
			continue
		}
		rest = append(rest, kvs[i], kvs[i+1])
	}
	if content == "" {
		logger.Info(msg, rest...)
		return
	}

	total := (len(content) + chunkBytes - 1) / chunkBytes
	for i := 0; i < total; i++ {
		start := i * chunkBytes
		end := start + chunkBytes
		if end > len(content) {
			end = len(content)
		}
		fields := append([]any{}, rest...)
		fields = append(fields,
			"chunk_seq", i+1,
			"chunk_total", total,
			"chunk_bytes", end-start,
			"content_total_bytes", len(content),
			"content", content[start:end],
		)
		logger.Info(msg, fields...)
	}
}
