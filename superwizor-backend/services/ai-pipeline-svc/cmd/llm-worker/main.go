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
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/diarization"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/reportprefs"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/transcriptfmt"
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

	// Two distinct sampling profiles by design. Don't collapse them
	// into one — call 1 wants determinism for parser-friendly output,
	// call 2 also wants determinism (clinical accuracy > prose variety).
	//
	//   Metadata (call 1): very low temperature, generous budget.
	//     - JSON mode: structured-output, schema-constrained, fits
	//       easily in a few KB.
	//     - Markdown mode (LLM_DIARIZATION_MODE=markdown): output
	//       includes EVERY chunk index inline per speaker group, e.g.
	//       "Chunks: 0, 2, 5, 8, 12, 14, 17, 23, 28, 33, 36, ...".
	//       A 60-min session with 50+ chunks across 2-3 speakers
	//       can push past 2k tokens just on the chunk-index lists.
	//       Keep this generous — call-1 truncation causes the
	//       markdown parser to fail (missing '# Metadata' section,
	//       mid-quote 'Evidence:' lines, empty Chunks: lists), which
	//       cascades into 5+ Pub/Sub retries and ultimately a
	//       dead-letter for the session. See the 2026-05-18 incident
	//       (session 17cd350e) — caused by 2048 cap, fixed by
	//       reverting to 16384.
	//   Report   (call 2): low temperature for clinical accuracy +
	//     budget *calibrated to actual target length*, not headroom.
	//     The model fills available room; we no longer give it 65k.
	//
	// Token math (Polish, ~2.0 tok/word, ~30 tok/sentence, ~600
	// tok/page) per the ZASADY ZWIĘZŁOŚCI rules (2-5 sentences per
	// section, 7 sections + title + summary):
	//   brief    ≈1 page  ≈ 600 effective tok → cap 2048 (3× safety)
	//   standard ≈2 pages ≈1200 effective tok → cap 4096 (3× safety)
	//   detailed ≈3 pages ≈2000 effective tok → cap 8192 (4× safety)
	//
	// Hard ceiling = the Vertex-enforced cap on gemini-2.5-flash
	// (65536 exclusive → 65535 highest accepted). Used only by the
	// safety-retry paths when calls return FinishReasonMaxTokens.
	//
	// Temp 0.2 (down from 0.3 on 2026-05-18): pushes call 2 toward
	// the same accuracy-first profile as call 1. Verbosity reports
	// from short sessions suggested 0.3 was giving the model too much
	// "creative" room to elaborate — accuracy beats prose variety on
	// a clinical document.
	geminiTempMetadata             float32 = 0.1
	geminiTempReport               float32 = 0.2
	geminiTopP                     float32 = 0.95
	geminiMaxOutMetadata           int32   = 16384
	geminiMaxOutReportDefault      int32   = 4096
	geminiMaxOutReportHardCeiling  int32   = 65535
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

	chunks, err := loadTranscriptBlob(ctx, ev.TranscriptID)
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

	// RAG-context lookup still operates on text — passes the legacy
	// formatted transcript so existing pgvector similarity logic
	// (Phase 3) gets the same shape it's used to. Cheap conversion;
	// stays out of the LLM-input critical path.
	ragContext, err := loadRAGContext(ctx, session.PatientFileID, legacyChunkFormat(chunks))
	if err != nil {
		logger.Warn("rag context", "error", err)
		ragContext = ""
	}

	reportJSON, tokenStats, err := generateReport(ctx, session.ReportLanguage, modalityPrompt, ragContext, chunks, session.ReportPreferences)
	if err != nil {
		// Vertex AI errors (quota, schema rejection, content filter,
		// region availability) all land here. Log full error text so we
		// don't have to dig through cloudaudit.googleapis.com for the
		// reason.
		logger.Error("generate report (Vertex AI)",
			"error", err,
			"prompt_len", len(modalityPrompt),
			"chunk_count", len(chunks),
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
	TherapistID         uuid.UUID
	ModalityID          uuid.UUID
	LanguageCode        string
	SpeakerLabelMapping map[int32]string
	ReportLanguage      string
	// Per-therapist style preferences loaded from
	// users.report_preferences (identity-svc's domain, JOIN'd here
	// because llm-worker needs them at call-2 prompt build time).
	// Zero value = "use defaults" — the renderer emits an empty
	// fragment in that case, preserving byte-identical prompts for
	// users who haven't configured anything.
	ReportPreferences reportprefs.Preferences
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

// metadataGenConfigJSON returns the GenerationConfig for call 1
// in JSON mode (schema-constrained structured output). Built from
// the package-level gemini* constants so all three call sites stay
// in lockstep — see the comment block on `geminiTempMetadata`.
func metadataGenConfigJSON(schema *vertexai.Schema) vertexai.GenerationConfig {
	return vertexai.GenerationConfig{
		Temperature:      vertexai.Ptr[float32](geminiTempMetadata),
		TopP:             vertexai.Ptr[float32](geminiTopP),
		MaxOutputTokens:  vertexai.Ptr[int32](geminiMaxOutMetadata),
		ResponseMIMEType: "application/json",
		ResponseSchema:   schema,
	}
}

// metadataGenConfigMarkdown returns the GenerationConfig for call 1
// in Markdown mode (free-form text). Same sampling profile as the
// JSON variant; differs only by absence of ResponseMIMEType +
// ResponseSchema so the model emits plain text we parse ourselves
// via internal/diarization.
func metadataGenConfigMarkdown() vertexai.GenerationConfig {
	return vertexai.GenerationConfig{
		Temperature:     vertexai.Ptr[float32](geminiTempMetadata),
		TopP:            vertexai.Ptr[float32](geminiTopP),
		MaxOutputTokens: vertexai.Ptr[int32](geminiMaxOutMetadata),
	}
}

// reportGenConfig returns the GenerationConfig for call 2 (the
// full clinical report). maxOut is the per-call cap — caller
// computes it from the therapist's length preference via
// reportprefs.MaxOutputTokens, falling back to
// geminiMaxOutReportDefault when no preference is set. We accept
// it as an arg rather than computing inside because the call site
// already has the prefs in scope and computing here would force
// a second package import for an otherwise trivial helper.
func reportGenConfig(maxOut int32) vertexai.GenerationConfig {
	if maxOut <= 0 {
		maxOut = geminiMaxOutReportDefault
	}
	return vertexai.GenerationConfig{
		Temperature:      vertexai.Ptr[float32](geminiTempReport),
		TopP:             vertexai.Ptr[float32](geminiTopP),
		MaxOutputTokens:  vertexai.Ptr[int32](maxOut),
		ResponseMIMEType: "text/plain",
	}
}

// diarizationMode reports the active LLM_DIARIZATION_MODE setting.
// "json" (default) keeps the legacy schema-constrained call 1;
// "markdown" switches call 1 to free-form Markdown + server-side
// parsing via the internal/diarization package. Call 2's transcript
// format is ALWAYS Format B Markdown (speaker-turn-grouped)
// regardless of this flag — the read-friendliness gain is
// unconditional and uncoupled from the call-1 output format.
func diarizationMode() string {
	v := strings.ToLower(strings.TrimSpace(os.Getenv("LLM_DIARIZATION_MODE")))
	if v == "" {
		return "json"
	}
	return v
}

func generateReport(ctx context.Context, reportLanguage, modalityPrompt, ragContext string, chunks []transcriptfmt.Chunk, prefs reportprefs.Preferences) (string, TokenStats, error) {
	model := vertexClient.GenerativeModel(geminiModel)
	mode := diarizationMode()
	native := hasNativeSpeakers(chunks)

	slog.Info("llm config",
		"diarization_mode", mode,
		"native_speakers", native,
		"chunk_count", len(chunks),
		"preferences", prefs.Summary())

	// --- Krok 1: Diaryzacja i Metadane ---
	var metadataPayload ReportPayload
	stats := TokenStats{}

	// Fast-path for tiny sessions: skip the diarization LLM call
	// entirely when there are fewer than 2 chunks. The cluster prompt
	// asks the model for "2 (lub 3) wirtualne grupy mówców" — a single
	// chunk can't be split into multiple groups, the LLM emits a
	// degenerate "Chunks:" empty list for group 2, and the strict
	// Markdown parser barfs (the 2026-05-18 Agnieszka incident).
	// Synthesize a single-speaker payload with role "unknown" so call
	// 2 still produces a content-focused report; downstream
	// generateAndSaveSpeakerLabels skips "unknown" groups, which
	// leaves transcript_segments with their default speaker_tag=0
	// state — UI shows the segment under the default speaker label.
	//
	// Also handles len(chunks)==0 — Chirp returned no words; report
	// will be minimal/empty but the pipeline doesn't crash.
	if len(chunks) < 2 {
		slog.Info("skipping call 1 — fewer than 2 chunks, diarization is a no-op",
			"chunk_count", len(chunks))
		chunkIndices := make([]int, len(chunks))
		for i, c := range chunks {
			chunkIndices[i] = c.ChunkIdx
		}
		metadataPayload = ReportPayload{
			SpeakerRoleInference: SpeakerRoleInference{
				Method: "skipped_too_few_chunks",
				SpeakerGroups: []SpeakerGroup{
					{
						Role:         "unknown",
						Confidence:   1.0,
						ChunkIndices: chunkIndices,
					},
				},
				OverallDiarizationConfidence: 1.0,
			},
		}
	} else {
		switch mode {
		case "markdown":
			mdResult, mdStats, err := callMetadataMarkdown(ctx, model, reportLanguage, ragContext, chunks, native)
			if err != nil {
				return "", TokenStats{}, err
			}
			metadataPayload = markdownResultToPayload(mdResult, chunks, native)
			stats.InputTokens += mdStats.InputTokens
			stats.OutputTokens += mdStats.OutputTokens
		default: // "json" — legacy path, byte-identical to pre-refactor behavior.
			payload, jsonStats, err := callMetadataJSON(ctx, model, reportLanguage, ragContext, legacyChunkFormat(chunks))
			if err != nil {
				return "", TokenStats{}, err
			}
			metadataPayload = payload
			stats.InputTokens += jsonStats.InputTokens
			stats.OutputTokens += jsonStats.OutputTokens
		}
	}

	// --- Krok 2: Pełny Raport Kliniczny (Raw Text Mode) ---
	// Call 2's transcript is ALWAYS Format B (speaker-turn-grouped
	// Markdown) — readable prose with speaker attribution baked in.
	// Annotate chunks with the just-resolved speaker tags first so
	// the formatter can group by speaker (otherwise chunks with
	// SpeakerTag=0 all collapse into a single "Speaker 1" turn —
	// correct for native-diarization-off sessions before call 1 runs,
	// but not what we want post-call-1).
	annotated := annotateChunksWithSpeakers(chunks, metadataPayload.SpeakerRoleInference.SpeakerGroups)
	transcriptForCall2 := transcriptfmt.FormatSpeakerTurns(annotated)

	// Compute the effective cap up front (rather than letting
	// reportGenConfig apply the default internally) so the
	// safety-retry path below can reason about the same value.
	effectiveMaxOut := reportprefs.MaxOutputTokens(prefs)
	if effectiveMaxOut <= 0 {
		effectiveMaxOut = geminiMaxOutReportDefault
	}
	model.GenerationConfig = reportGenConfig(effectiveMaxOut)

	// Render the optional preference fragment. Empty when the
	// therapist hasn't customized — preserves byte-identical prompts
	// for the default path.
	prefsFragment := reportprefs.RenderFragment(prefs)
	if prefsFragment != "" {
		// Add a blank line above so it visually separates from the
		// modality prompt in the rendered text.
		prefsFragment = "\n" + prefsFragment
	}

	// Explicit length directive paired with the MaxOutputTokens cap.
	// The model honors prompt budgets much better than implicit
	// caps — without this directive the model fills available room
	// regardless of session length. Standalone block above ZASADY
	// ZWIĘZŁOŚCI so it reads as a top-level constraint.
	lengthDirective := reportprefs.TargetLengthDirective(prefs)

	reportPrompt := fmt.Sprintf(`%s

JĘZYK RAPORTU: %s
Wygeneruj CAŁY raport w tym języku. Cytaty z transkryptu pozostaw w oryginale.
Sformatuj raport używając czytelnego Markdown (nagłówki ##, pogrubienia, cytaty).
%s
%s

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

TRANSKRYPT BIEŻĄCEJ SESJI (Markdown, grupowanie po mówcach):
%s`,
		modalityPrompt, reportLanguage, prefsFragment, lengthDirective, ragContext, transcriptForCall2)

	debugLogChunked(slog.Default(), "vertex_prompt", "step", "markdown", "content", reportPrompt)

	respReport, err := model.GenerateContent(ctx, vertexai.Text(reportPrompt))
	if err != nil {
		return "", TokenStats{}, fmt.Errorf("generate report markdown: %w", err)
	}
	if len(respReport.Candidates) == 0 || respReport.Candidates[0].Content == nil {
		return "", TokenStats{}, fmt.Errorf("no candidates returned for report markdown")
	}

	// Safety retry: if the new tighter caps occasionally bite and
	// the model gets truncated mid-sentence, retry ONCE with a 2×
	// budget. Bounded by geminiMaxOutReportHardCeiling so we never
	// exceed Vertex's hard limit. Logs loudly so we can monitor
	// the trigger rate and tune caps if it fires often.
	//
	// This is a rollout-period safety net — once production data
	// shows the trigger rate is near-zero, the retry block can be
	// removed. Tracked in docs/agents/TODO.md.
	if respReport.Candidates[0].FinishReason == vertexai.FinishReasonMaxTokens {
		retryMaxOut := effectiveMaxOut * 2
		if retryMaxOut > geminiMaxOutReportHardCeiling {
			retryMaxOut = geminiMaxOutReportHardCeiling
		}
		slog.Warn("call 2 hit MaxOutputTokens — retrying once at 2× cap",
			"original_cap", effectiveMaxOut,
			"retry_cap", retryMaxOut,
			"length_preference", prefs.Length)
		model.GenerationConfig = reportGenConfig(retryMaxOut)
		respReport, err = model.GenerateContent(ctx, vertexai.Text(reportPrompt))
		if err != nil {
			return "", TokenStats{}, fmt.Errorf("generate report markdown (retry): %w", err)
		}
		if len(respReport.Candidates) == 0 || respReport.Candidates[0].Content == nil {
			return "", TokenStats{}, fmt.Errorf("no candidates returned for report markdown (retry)")
		}
		if respReport.Candidates[0].FinishReason == vertexai.FinishReasonMaxTokens {
			// Retry also truncated. Take what we have + log; don't
			// loop. Therapist will see the report; we'll see it in
			// metrics + tune caps next iteration.
			slog.Error("call 2 hit MaxOutputTokens twice — accepting truncated output",
				"retry_cap", retryMaxOut,
				"length_preference", prefs.Length)
		}
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

// callMetadataJSON is the legacy schema-constrained call 1 path —
// extracted verbatim from the pre-refactor generateReport so that
// the LLM_DIARIZATION_MODE=json branch is byte-for-byte identical
// to pre-refactor behavior. Don't refactor the prompt content here
// without explicit go-ahead; it's the production hot path.
func callMetadataJSON(ctx context.Context, model *vertexai.GenerativeModel, reportLanguage, ragContext, transcriptText string) (ReportPayload, TokenStats, error) {
	var schema map[string]any
	if err := json.Unmarshal(reportSchemaBytes, &schema); err != nil {
		return ReportPayload{}, TokenStats{}, fmt.Errorf("parse schema: %w", err)
	}
	model.GenerationConfig = metadataGenConfigJSON(schemaToVertexSchema(schema))

	prompt := fmt.Sprintf(`
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

	debugLogChunked(slog.Default(), "vertex_prompt", "step", "metadata", "mode", "json", "content", prompt)

	resp, err := model.GenerateContent(ctx, vertexai.Text(prompt))
	if err != nil {
		return ReportPayload{}, TokenStats{}, fmt.Errorf("generate metadata (json): %w", err)
	}
	if len(resp.Candidates) == 0 || resp.Candidates[0].Content == nil {
		return ReportPayload{}, TokenStats{}, fmt.Errorf("no candidates returned for metadata (json)")
	}
	var out strings.Builder
	for _, part := range resp.Candidates[0].Content.Parts {
		if text, ok := part.(vertexai.Text); ok {
			out.WriteString(string(text))
		}
	}
	debugLogChunked(slog.Default(), "vertex_response", "step", "metadata", "mode", "json", "content", out.String())

	var payload ReportPayload
	if err := json.Unmarshal([]byte(out.String()), &payload); err != nil {
		return ReportPayload{}, TokenStats{}, fmt.Errorf("parse metadata json: %w", err)
	}
	var stats TokenStats
	if resp.UsageMetadata != nil {
		stats.InputTokens = resp.UsageMetadata.PromptTokenCount
		stats.OutputTokens = resp.UsageMetadata.CandidatesTokenCount
	}
	return payload, stats, nil
}

// callMetadataMarkdown — new call-1 path that asks the LLM for
// Markdown output (free-form, no schema constraint) and parses it
// server-side via internal/diarization. Format A (chunk-indexed)
// when native diarization is absent — the LLM has to cluster; Format
// B (speaker-turn) when native diarization is present — the LLM only
// labels roles. Same model + temperature as the JSON path.
func callMetadataMarkdown(ctx context.Context, model *vertexai.GenerativeModel, reportLanguage, ragContext string, chunks []transcriptfmt.Chunk, native bool) (diarization.Result, TokenStats, error) {
	// No ResponseMIMEType / ResponseSchema in Markdown mode —
	// free-form text out, parsed server-side by internal/diarization.
	model.GenerationConfig = metadataGenConfigMarkdown()

	var transcriptStr, prompt string
	if native {
		// Format B input, role-only grammar output.
		transcriptStr = transcriptfmt.FormatSpeakerTurns(chunks)
		prompt = fmt.Sprintf(`
WAŻNE — TRANSCRIPT JUŻ JEST POGRUPOWANY PER MÓWCA.
Każda sekcja ## Speaker N reprezentuje jednego mówcę z natywnej diaryzacji STT.
Twoim zadaniem jest tylko PRZYPISAĆ ROLĘ każdemu mówcy oraz wygenerować metadane.

Role: therapist, patient, couple_partner, family_member_parent,
family_member_child, family_member_sibling, third_party, filler, unknown.

JĘZYK RAPORTU: %s

KONTEKST POPRZEDNICH SESJI:
%s

TRANSKRYPT (pogrupowany po mówcach):
%s

ODPOWIEDŹ — Sformatuj DOKŁADNIE w tym kształcie Markdown (bez bloków kodu, bez bold, bez list):

# Speakers

Speaker 1 — therapist (confidence 0.92)
Speaker 2 — patient (confidence 0.95)

# Metadata

Title: <tytuł, max 100 znaków>
Summary: <streszczenie, max 500 znaków, 2-3 zdania>
Overall_diarization_confidence: 0.94

ZASADY:
- Sekcje "# Speakers" i "# Metadata", dokładnie w tej kolejności.
- Po jednym wierszu na speakera w "# Speakers".
- Confidence: float 0.0–1.0.
- BEZ żadnego tekstu poza tym blokiem.`,
			reportLanguage, ragContext, transcriptStr)
	} else {
		// Format A input, cluster grammar output (current Polish path
		// — pl-PL has no native Chirp diarization).
		transcriptStr = transcriptfmt.FormatChunkIndexed(chunks)
		prompt = fmt.Sprintf(`
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

Role: therapist, patient, couple_partner, family_member_parent,
family_member_child, family_member_sibling, third_party, filler, unknown.

JĘZYK RAPORTU: %s

KONTEKST POPRZEDNICH SESJI:
%s

TRANSKRYPT BIEŻĄCEJ SESJI:
%s

ODPOWIEDŹ — Sformatuj DOKŁADNIE w tym kształcie Markdown (bez bloków kodu, bez bold, bez list):

# Speakers

## Group 1 — therapist (confidence 0.87)
Chunks: 0, 2, 5, 8, 12, 14, 17
Evidence: "Z czym dzisiaj przychodzisz?"

## Group 2 — patient (confidence 0.92)
Chunks: 1, 3, 6, 9, 13, 15, 18, 19
Evidence: "Trochę zmęczona ostatnio."

# Metadata

Title: <tytuł, max 100 znaków>
Summary: <streszczenie, max 500 znaków, 2-3 zdania>
Overall_diarization_confidence: 0.89

ZASADY:
- Sekcje "# Speakers" i "# Metadata", dokładnie w tej kolejności.
- "## Group N — <rola> (confidence 0.XX)" — używaj em-dash "—".
- "Chunks:" — liczby chunków oddzielone przecinkami, każdy chunk w DOKŁADNIE JEDNEJ grupie.
- "Evidence:" — pojedynczy cytat z transkrypcji w cudzysłowach.
- Confidence: float 0.0–1.0.
- BEZ żadnego tekstu poza tym blokiem.`,
			reportLanguage, ragContext, transcriptStr)
	}

	debugLogChunked(slog.Default(), "vertex_prompt", "step", "metadata", "mode", "markdown", "native", native, "content", prompt)

	resp, err := model.GenerateContent(ctx, vertexai.Text(prompt))
	if err != nil {
		return diarization.Result{}, TokenStats{}, fmt.Errorf("generate metadata (markdown): %w", err)
	}
	if len(resp.Candidates) == 0 || resp.Candidates[0].Content == nil {
		return diarization.Result{}, TokenStats{}, fmt.Errorf("no candidates returned for metadata (markdown)")
	}

	// Safety retry: if call 1 hit MaxOutputTokens, the Markdown
	// output is truncated mid-output and ParseMetadataMarkdown will
	// fail with errors like "missing required section '# Metadata'"
	// or "unexpected line: Evidence: ...". Retry ONCE at 2× cap
	// (bounded by geminiMaxOutReportHardCeiling) before letting
	// Pub/Sub see the failure. Mirrors the call-2 safety retry
	// added in commit d212f38. See the 2026-05-18 incident
	// (session 17cd350e — 6+ Pub/Sub redeliveries) for the
	// motivating case.
	if resp.Candidates[0].FinishReason == vertexai.FinishReasonMaxTokens {
		retryMaxOut := geminiMaxOutMetadata * 2
		if retryMaxOut > geminiMaxOutReportHardCeiling {
			retryMaxOut = geminiMaxOutReportHardCeiling
		}
		slog.Warn("call 1 (markdown) hit MaxOutputTokens — retrying once at 2× cap",
			"original_cap", geminiMaxOutMetadata,
			"retry_cap", retryMaxOut,
			"native_diarization", native)
		// Rebuild config with bumped cap; keep temp/TopP identical.
		retryConfig := metadataGenConfigMarkdown()
		retryConfig.MaxOutputTokens = vertexai.Ptr[int32](retryMaxOut)
		model.GenerationConfig = retryConfig
		resp, err = model.GenerateContent(ctx, vertexai.Text(prompt))
		if err != nil {
			return diarization.Result{}, TokenStats{}, fmt.Errorf("generate metadata (markdown, retry): %w", err)
		}
		if len(resp.Candidates) == 0 || resp.Candidates[0].Content == nil {
			return diarization.Result{}, TokenStats{}, fmt.Errorf("no candidates returned for metadata (markdown, retry)")
		}
		if resp.Candidates[0].FinishReason == vertexai.FinishReasonMaxTokens {
			// Even 2× wasn't enough. Accept the truncated output
			// and let the parser fail loud — Pub/Sub will redeliver,
			// metrics will fire, we tune caps next iteration. Don't
			// loop indefinitely.
			slog.Error("call 1 hit MaxOutputTokens twice — Markdown parser will likely fail downstream",
				"retry_cap", retryMaxOut)
		}
	}

	var out strings.Builder
	for _, part := range resp.Candidates[0].Content.Parts {
		if text, ok := part.(vertexai.Text); ok {
			out.WriteString(string(text))
		}
	}
	debugLogChunked(slog.Default(), "vertex_response", "step", "metadata", "mode", "markdown", "content", out.String())

	result, err := diarization.ParseMetadataMarkdown(out.String())
	if err != nil {
		return diarization.Result{}, TokenStats{}, fmt.Errorf("parse markdown metadata: %w", err)
	}

	var stats TokenStats
	if resp.UsageMetadata != nil {
		stats.InputTokens = resp.UsageMetadata.PromptTokenCount
		stats.OutputTokens = resp.UsageMetadata.CandidatesTokenCount
	}
	return result, stats, nil
}

// markdownResultToPayload adapts the parser's Result into the
// existing ReportPayload struct so downstream
// generateAndSaveSpeakerLabels (and the persistReport JSON shape) is
// untouched.
//
// Cluster grammar: ChunkIndices comes from the parsed output directly.
// Role-only grammar: ChunkIndices is empty in the Result, we
// reconstruct it by walking the input transcript and grouping chunks
// by their existing SpeakerTag.
func markdownResultToPayload(r diarization.Result, chunks []transcriptfmt.Chunk, native bool) ReportPayload {
	method := "llm_inferred"
	if native {
		method = "native_chirp_3"
	}

	groups := make([]SpeakerGroup, 0, len(r.Speakers))
	for _, sp := range r.Speakers {
		g := SpeakerGroup{
			Role:       sp.Role,
			Confidence: sp.Confidence,
			Evidence:   sp.Evidence,
		}
		if native {
			// Walk chunks and collect those whose SpeakerTag matches
			// this speaker's Index. Stable order = sorted by chunk_idx
			// (chunks are usually pre-sorted by start_ms).
			for _, c := range chunks {
				if c.SpeakerTag == int32(sp.Index) {
					g.ChunkIndices = append(g.ChunkIndices, c.ChunkIdx)
				}
			}
		} else {
			g.ChunkIndices = sp.ChunkIndices
		}
		groups = append(groups, g)
	}

	// Native-mode orphan-chunk reattach. Chirp 3 sometimes labels one
	// speaker reliably ("1") and drops labels on the other speaker's
	// words — the stt-worker's fillSpeakerLabels pass catches most of
	// those, but residual unlabeled runs (e.g. leading words before
	// Chirp's first label, or chunks across pauses) still arrive with
	// SpeakerTag=0. Without this fallback those chunks stay tag=0 in
	// the DB and the UI shows only the speakers Chirp labeled.
	//
	// Strategy: if the LLM inferred N speakers (N >= 2) but exactly
	// one of them ended up with no chunks attached, give that speaker
	// all orphan tag=0 chunks. The LLM saw the transcript content and
	// concluded there were N speakers — a single empty group is the
	// "Chirp labeled only the other one" case from session 26ecf316.
	// Multiple empty groups means we're guessing about which orphan
	// chunk belongs to which speaker; skip — current behavior preserved
	// (orphans stay tag=0, log a warning so operators see the case).
	if native && len(groups) >= 2 {
		emptyIdx := -1
		emptyCount := 0
		for i, g := range groups {
			if len(g.ChunkIndices) == 0 {
				emptyIdx = i
				emptyCount++
			}
		}
		if emptyCount == 1 {
			var orphans []int
			for _, c := range chunks {
				if c.SpeakerTag == 0 {
					orphans = append(orphans, c.ChunkIdx)
				}
			}
			if len(orphans) > 0 {
				slog.Info("native-mode orphan reattach",
					"role", groups[emptyIdx].Role,
					"orphan_chunks", len(orphans))
				groups[emptyIdx].ChunkIndices = orphans
			}
		} else if emptyCount > 1 {
			slog.Warn("native-mode diarization left multiple speaker groups empty — keeping orphan tag=0 chunks unassigned",
				"empty_groups", emptyCount,
				"total_groups", len(groups),
				"hint", "Chirp labeling reliability — consider re-running with diarization off for this language")
		}
	}

	return ReportPayload{
		Title:        r.Title,
		SummaryShort: r.Summary,
		SpeakerRoleInference: SpeakerRoleInference{
			Method:                       method,
			SpeakerGroups:                groups,
			OverallDiarizationConfidence: r.OverallDiarizationConfidence,
		},
	}
}

// annotateChunksWithSpeakers stamps the just-resolved speaker tags
// onto the chunk slice so FormatSpeakerTurns can group properly for
// call 2. Group index N → speaker_tag N. Chunks not assigned to any
// group keep their existing speaker_tag (which is usually 0 — falls
// into "Speaker 1" by Format B's graceful-degradation rule).
//
// Returns a new slice — does not mutate the input.
func annotateChunksWithSpeakers(chunks []transcriptfmt.Chunk, groups []SpeakerGroup) []transcriptfmt.Chunk {
	annotated := make([]transcriptfmt.Chunk, len(chunks))
	copy(annotated, chunks)

	// Build chunk_idx → speaker_tag from groups (1-indexed by group order).
	tagByChunkIdx := make(map[int]int32, 0)
	for i, g := range groups {
		tag := int32(i + 1)
		for _, ci := range g.ChunkIndices {
			tagByChunkIdx[ci] = tag
		}
	}
	for i := range annotated {
		if t, ok := tagByChunkIdx[annotated[i].ChunkIdx]; ok {
			annotated[i].SpeakerTag = t
		}
	}
	return annotated
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
	// Join in the therapist (via patient_files) and their report
	// style preferences (JSONB) so call 2 can build a personalized
	// prompt without a second round-trip. ReportPreferences is a
	// JSONB column on users; empty {} is the common case for users
	// who haven't customized — the renderer treats that as no-op.
	var prefsRaw []byte
	row := dbPool.QueryRow(ctx, `
		SELECT s.patient_file_id, pf.therapist_id, pf.modality_id,
		       s.speaker_label_mapping, s.language_code, s.report_language,
		       COALESCE(u.report_preferences, '{}'::jsonb)
		FROM sessions s
		JOIN patient_files pf ON pf.id = s.patient_file_id
		JOIN users u ON u.id = pf.therapist_id
		WHERE s.id = $1`, id)
	if err := row.Scan(&sc.PatientFileID, &sc.TherapistID, &sc.ModalityID,
		&mappingJSON, &langCode, &reportLang, &prefsRaw); err != nil {
		return nil, err
	}

	if prefs, err := reportprefs.Decode(prefsRaw); err != nil {
		// Corrupt JSONB on users.report_preferences should never
		// happen (identity-svc writes only validated payloads), but
		// if it does, log + fall back to defaults rather than
		// failing the whole report-generation pipeline.
		slog.Warn("decode report_preferences fell through to defaults",
			"therapist_id", sc.TherapistID, "error", err)
	} else {
		sc.ReportPreferences = prefs
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
// loadTranscriptBlob reads the canonical encrypted blob (ADR-IMPL-006),
// decrypts it, and returns the chunks in their decoded form for
// downstream formatting. Replaces the old loadTranscriptText, which
// fused decryption and formatting; separating them lets us format
// the same blob differently for call 1 vs call 2.
func loadTranscriptBlob(ctx context.Context, transcriptID string) ([]transcriptfmt.Chunk, error) {
	id, err := uuid.Parse(transcriptID)
	if err != nil {
		return nil, err
	}

	var ciphertext []byte
	var encryptedDEK []byte
	row := dbPool.QueryRow(ctx,
		"SELECT transcript_ciphertext, transcript_encrypted_dek FROM transcripts WHERE id = $1", id)
	if err := row.Scan(&ciphertext, &encryptedDEK); err != nil {
		return nil, err
	}

	blobJSONBytes, err := crypto.Decrypt(ctx, ciphertext, encryptedDEK)
	if err != nil {
		return nil, fmt.Errorf("decrypt transcript blob: %w", err)
	}

	// The canonical blob's on-disk shape (stt-worker.BlobLine). We
	// don't import that package here to keep the worker-to-worker
	// dependency surface small. The Chunk type the formatter wants
	// is the subset we actually need.
	type blobLine struct {
		ChunkIdx     int     `json:"chunk_idx"`
		Text         string  `json:"text"`
		StartMS      int64   `json:"start_ms"`
		EndMS        int64   `json:"end_ms"`
		WordCount    int     `json:"word_count"`
		Confidence   float32 `json:"confidence"`
		SpeakerTag   *int32  `json:"speaker_tag,omitempty"`
		SpeakerLabel *string `json:"speaker_label,omitempty"`
	}

	var lines []blobLine
	if err := json.Unmarshal(blobJSONBytes, &lines); err != nil {
		return nil, fmt.Errorf("unmarshal transcript blob: %w", err)
	}

	chunks := make([]transcriptfmt.Chunk, len(lines))
	for i, l := range lines {
		c := transcriptfmt.Chunk{
			ChunkIdx: l.ChunkIdx,
			Text:     l.Text,
			StartMS:  l.StartMS,
			EndMS:    l.EndMS,
		}
		if l.SpeakerTag != nil {
			c.SpeakerTag = *l.SpeakerTag
		}
		if l.SpeakerLabel != nil {
			c.SpeakerLabel = *l.SpeakerLabel
		}
		chunks[i] = c
	}
	return chunks, nil
}

// legacyChunkFormat renders the chunk list in the pre-Markdown shape
// that the JSON-mode prompt expects:
//
//	[CHUNK 0] (1200ms-4500ms) text
//	[CHUNK 1 / Speaker 1] (4800ms-7800ms) text    (when native diarization)
//
// Kept inline rather than in transcriptfmt because it's the legacy
// format — we don't want to encourage new callers.
func legacyChunkFormat(chunks []transcriptfmt.Chunk) string {
	var sb strings.Builder
	for _, c := range chunks {
		if c.SpeakerLabel != "" {
			fmt.Fprintf(&sb, "[CHUNK %d / %s] (%dms-%dms) %s\n",
				c.ChunkIdx, c.SpeakerLabel, c.StartMS, c.EndMS, c.Text)
		} else {
			fmt.Fprintf(&sb, "[CHUNK %d] (%dms-%dms) %s\n",
				c.ChunkIdx, c.StartMS, c.EndMS, c.Text)
		}
	}
	return sb.String()
}

// hasNativeSpeakers reports whether any chunk carries a non-zero
// speaker_tag (i.e., Chirp 3 native diarization fired upstream).
// When true, call 1 uses the role-only grammar; when false, call 1
// uses the cluster grammar (LLM has to group chunks).
func hasNativeSpeakers(chunks []transcriptfmt.Chunk) bool {
	for _, c := range chunks {
		if c.SpeakerTag != 0 {
			return true
		}
	}
	return false
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
