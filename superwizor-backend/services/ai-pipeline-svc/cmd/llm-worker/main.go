package llmworker

import (
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"cloud.google.com/go/aiplatform/apiv1/aiplatformpb"
	kms "cloud.google.com/go/kms/apiv1"
	"cloud.google.com/go/pubsub/v2"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"google.golang.org/genai"
	"github.com/cloudevents/sdk-go/v2/event"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/sync/errgroup"

	"github.com/superwizor-ai/backend/pkg/cryptobox"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/diarization"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/reportprefs"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/transcriptfmt"
	"github.com/superwizor-ai/backend/pkg/i18n/rolelabels"
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
	vertexClient *genai.Client
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

	// Embedding model for the RAG long-term-memory pipeline. Vertex AI's
	// text-embedding-005 produces 768-dim multilingual vectors — matches
	// `rag_memories.embedding vector(768)` exactly. Used by
	// generateEmbedding(); failures are non-fatal (the worker Warns and
	// skips persistRAGMemory, preserving report save).
	embeddingModel string = "text-embedding-005"
	embeddingDims  int    = 768

	// RAG read-side knobs. loadRAGContext is a two-stage filter:
	//   1. Bound the candidate pool to the patient's last
	//      `ragLookbackMemories` rows (most-recent first by
	//      created_at).
	//   2. Within that pool, pick the top-`ragTopK` nearest neighbors
	//      by cosine similarity.
	// Joined output is capped at `ragContextMaxChars` to keep
	// call-1/call-2 prompts bounded.
	//
	// Sizing rationale:
	//   - lookback=36: ≈9 months at weekly cadence, ≈18 months at
	//     bi-weekly. Captures the patient's recent clinical arc
	//     without dragging in stale states from years ago. Also
	//     matches the typical "this client has been in therapy
	//     ~1 year" attention window. Tunable as we observe long-run
	//     patients.
	//   - K=3: enough to ground "what we've worked on so far" without
	//     drowning the prompt. Tunable from production data once read
	//     side has flown.
	//   - max-chars=5000: ≈3× 1500-char per-memory cap. Generous head-
	//     room for the typical case; truncation triggers only on huge
	//     summaries or future K bumps. Keep below ~10% of the call-2
	//     input budget so RAG never dominates the prompt.
	ragLookbackMemories int = 36
	ragTopK             int = 3
	ragContextMaxChars  int = 5000

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
	// 3× headroom over the directive's target (2026-05-19 bump from 4096):
	// the `TargetLengthDirective` prompt already shapes report length
	// effectively — the cap should be a remote safety net, NOT a
	// budget the model races to hit. With cap = target, sessions that
	// the model naturally writes 10% over budget triggered the
	// safety-retry (extra Vertex call, ~3× cost on the affected
	// session, ~2.5× latency). Bumping cap to 3× of the directive
	// target moves the safety net far from the working zone:
	//   - directive says: "aim for ~2 pages / ~1200 effective tok"
	//   - actual emission: typically 1500–4500 tok
	//   - new cap: 12288 → never fires under normal use
	// Cost impact of the bump: zero — Vertex bills on actual output
	// tokens, not the cap. See reportprefs.MaxOutputTokens for the
	// per-length bumps and section_emphasis scaling.
	geminiMaxOutReportDefault      int32   = 12288
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
		// Bounded pool (see docs/17 §11). llm-worker spends most of a
		// request blocked on Vertex AI's Gemini call — single conn is
		// fine; concurrent invocations on the same instance serialize
		// through pgxpool.Acquire's wait queue.
		poolCfg, perr := pgxpool.ParseConfig(dbDSN)
		if perr != nil {
			slog.Error("parse db dsn", "error", perr)
			os.Exit(1)
		}
		poolCfg.MaxConns = 1
		poolCfg.MinConns = 0
		poolCfg.MaxConnIdleTime = 30 * time.Second
		dbPool, err = pgxpool.NewWithConfig(ctx, poolCfg)
		if err != nil {
			slog.Error("db", "error", err)
			os.Exit(1)
		}
	}

	if projectID != "" {
		// Migrated from cloud.google.com/go/vertexai (deprecated
		// 2025-06-24, removed 2026-06-24) to google.golang.org/genai.
		// BackendVertexAI keeps us on the Vertex AI surface (same
		// auth, same quotas, same region). Project + Location are now
		// passed via ClientConfig instead of positional args.
		vertexClient, err = genai.NewClient(ctx, &genai.ClientConfig{
			Project:  projectID,
			Location: geminiRegion,
			Backend:  genai.BackendVertexAI,
		})
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

	// DB-load failures below are TRANSIENT (Cloud SQL hiccup, KMS blip):
	// do NOT mark FAILED, just NACK so Pub/Sub retries within the ~24h
	// window (docs/21 §3.1). Flipping FAILED here flashed a permanent
	// failure to the user on a recoverable blip.
	session, err := loadSession(ctx, ev.SessionID)
	if err != nil {
		logger.Error("load session (transient — pubsub will retry)", "error", err)
		return fmt.Errorf("load session: %w", err)
	}

	chunks, err := loadTranscriptBlob(ctx, ev.TranscriptID)
	if err != nil {
		logger.Error("load transcript (transient — pubsub will retry)", "error", err)
		return fmt.Errorf("load transcript: %w", err)
	}

	modalityPrompt, err := loadModalityPrompt(ctx, session.ModalityID)
	if err != nil {
		logger.Error("load modality prompt (transient — pubsub will retry)", "error", err, "modality_id", session.ModalityID)
		return fmt.Errorf("load prompt: %w", err)
	}

	// Pipeline: call-1 (metadata + themes) → RAG retrieve → call-2.
	// Vertex AI errors from EITHER call get the same terminal/transient
	// classification; failGen returns nil to ack a terminal failure
	// (marks FAILED + mirrors to the user) and a wrapped error to NACK a
	// transient one for Pub/Sub retry within the ~24h window.
	failGen := func(genErr error, stage string) error {
		logger.Error("generate report (Vertex AI)",
			"error", genErr, "stage", stage,
			"prompt_len", len(modalityPrompt), "chunk_count", len(chunks))
		if isTerminalLLMError(genErr) {
			_ = updateSessionStatus(ctx, ev.SessionID, "FAILED")
			if perr := publishSessionStatusChanged(ctx, ev.SessionID, "failed"); perr != nil {
				logger.Warn("publish session.status_changed(failed) failed", "error", perr)
			}
			logger.Error("llm: terminal generate failure — FAILED, ack, no retry", "error", genErr, "stage", stage)
			return nil
		}
		return fmt.Errorf("generate (%s): %w", stage, genErr)
	}

	mode := diarizationMode()
	native := hasNativeSpeakers(chunks)
	slog.Info("llm config",
		"diarization_mode", mode,
		"native_speakers", native,
		"chunk_count", len(chunks),
		"preferences", session.ReportPreferences.Summary())

	// Call 1 first — its themes/summary are the retrieval query.
	metadataPayload, stats, err := generateMetadata(ctx, ev.SessionID, session.ReportLanguage, mode, native, chunks)
	if err != nil {
		return failGen(err, "metadata")
	}

	// Retrieve prior-session context using THIS session's distilled
	// themes (docs/30). LLM_RAG_MODE=legacy falls back to the old
	// raw-transcript reader. Always best-effort — empty on any failure.
	var ragContext string
	if ragMode() == "legacy" {
		ragContext, err = loadRAGContext(ctx, ev.SessionID, session.PatientFileID, legacyChunkFormat(chunks))
	} else {
		ragContext, err = loadRAGContextV2(ctx, ev.SessionID, session.PatientFileID,
			metadataPayload.RAGThemes, metadataPayload.RAGSummaryChunk, chunks)
	}
	if err != nil {
		logger.Warn("rag context", "error", err)
		ragContext = ""
	}

	// Call 2 — the full report, now grounded in the retrieved context.
	reportJSON, tokenStats, err := generateReportBody(ctx, ev.SessionID, session.ReportLanguage,
		modalityPrompt, ragContext, chunks, session.ReportPreferences, metadataPayload, stats)
	if err != nil {
		return failGen(err, "report")
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
		// DB write failure — transient. NACK, retry; do not mark FAILED.
		logger.Error("persist report (transient — pubsub will retry)", "error", err)
		return fmt.Errorf("persist: %w", err)
	}

	// Po analizie LLM: generate speaker labels z speaker_groups + zapisz
	// do sessions.speaker_label_mapping i transcript_segments.speaker_label
	// (zob. ADR-IMPL-002 + ADR-IMPL-007).
	if err := generateAndSaveSpeakerLabels(ctx, session, ev.TranscriptID, &report); err != nil {
		logger.Warn("speaker labels", "error", err)
	}

	// Write long-term memory: a summary row + one row per RAG_Theme,
	// each independently embedded (docs/30 §3.2). Best-effort — a
	// failure here Warns but never fails the report.
	if err := persistRAGMemoryV2(ctx, session, reportID, &report); err != nil {
		logger.Warn("rag persist", "error", err)
	}

	if err := updateSessionStatus(ctx, ev.SessionID, "COMPLETED"); err != nil {
		logger.Warn("status", "error", err)
	}

	// Publish the terminal-success transition. notification-worker-on-status
	// consumes "done" and owns the report-ready fan-out (Firestore mirror +
	// FCM "report ready" push + inbox doc) — docs/21 Faza-4. The old
	// report.generated topic + notification-worker-on-report are retired.
	_ = publishSessionStatusChanged(ctx, ev.SessionID, "done")

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
	// ModalityType discriminates the modalities catalog into
	// therapy vs coaching (migration 000026). Drives the localized
	// role-label vocabulary in generateAndSaveSpeakerLabels:
	// therapy → "Terapeuta"/"Pacjent", coaching → "Trener"/"Klient".
	// Unknown / NULL falls back to "therapy" (conservative; almost
	// every modality in the catalog is clinical).
	ModalityType        string
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
	// RAGThemes are 2–5 distinct clinical threads of THIS session, each
	// persisted as its own embedded rag_memories row for thread-level
	// cross-session retrieval (docs/30). Empty for short/legacy sessions.
	RAGThemes []string `json:"rag_themes,omitempty"`
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

// metadataGenConfigJSON returns the GenerateContentConfig for call 1
// in JSON mode (schema-constrained structured output). Built from
// the package-level gemini* constants so all three call sites stay
// in lockstep — see the comment block on `geminiTempMetadata`.
//
// New-SDK note: config is now passed PER CALL to
// client.Models.GenerateContent(...) — there's no per-model
// GenerationConfig slot to mutate (vertexai's pattern).
func metadataGenConfigJSON(schema *genai.Schema) *genai.GenerateContentConfig {
	return &genai.GenerateContentConfig{
		Temperature:      genai.Ptr[float32](geminiTempMetadata),
		TopP:             genai.Ptr[float32](geminiTopP),
		MaxOutputTokens:  geminiMaxOutMetadata,
		ResponseMIMEType: "application/json",
		ResponseSchema:   schema,
	}
}

// metadataGenConfigMarkdown returns the config for call 1 in
// Markdown mode (free-form text). Same sampling profile as the
// JSON variant; differs only by absence of ResponseMIMEType +
// ResponseSchema so the model emits plain text we parse ourselves
// via internal/diarization.
func metadataGenConfigMarkdown() *genai.GenerateContentConfig {
	return &genai.GenerateContentConfig{
		Temperature:     genai.Ptr[float32](geminiTempMetadata),
		TopP:            genai.Ptr[float32](geminiTopP),
		MaxOutputTokens: geminiMaxOutMetadata,
	}
}

// reportGenConfig returns the config for call 2 (the full clinical
// report). maxOut is the per-call cap — caller computes it from the
// therapist's length preference via reportprefs.MaxOutputTokens,
// falling back to geminiMaxOutReportDefault when no preference is
// set. We accept it as an arg rather than computing inside because
// the call site already has the prefs in scope and computing here
// would force a second package import for an otherwise trivial
// helper.
func reportGenConfig(maxOut int32) *genai.GenerateContentConfig {
	if maxOut <= 0 {
		maxOut = geminiMaxOutReportDefault
	}
	return &genai.GenerateContentConfig{
		Temperature:      genai.Ptr[float32](geminiTempReport),
		TopP:             genai.Ptr[float32](geminiTopP),
		MaxOutputTokens:  maxOut,
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

// ragMode selects the retrieval reader: "v2" (default — theme-level,
// docs/30) or "legacy" (the pre-Phase-3 raw-transcript summary reader,
// kept as a rollback). Anything other than "legacy" is treated as v2.
func ragMode() string {
	if strings.ToLower(strings.TrimSpace(os.Getenv("LLM_RAG_MODE"))) == "legacy" {
		return "legacy"
	}
	return "v2"
}

// generateMetadata runs call-1 (diarization + metadata + RAG_Summary +
// RAG_Themes). It deliberately receives NO prior-session context — every
// call-1 output is a self-contained fact about THIS session (see
// docs/agents/05 "Why call-1 doesn't get RAG"). Its outputs (themes /
// summary) become the *query* for v2 retrieval, which is why the pipeline
// runs call-1 → retrieve → call-2 (docs/30). mode/native are computed by
// the caller (which also logs the shared "llm config" line).
func generateMetadata(ctx context.Context, sessionID, reportLanguage, mode string, native bool, chunks []transcriptfmt.Chunk) (ReportPayload, TokenStats, error) {
	// New SDK: no per-model object. Each GenerateContent call gets
	// its own config (call-1 metadata vs call-2 report). The
	// package-level vertexClient (genai.Client) is shared.

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
			mdResult, mdStats, err := callMetadataMarkdown(ctx, reportLanguage, chunks, native)
			if err != nil {
				slog.InfoContext(ctx, "analytics",
					"ae", "llm.failed",
					"session_id", sessionID,
					"call_number", 1,
					"error_category", func() string {
						if isTerminalLLMError(err) {
							return "terminal"
						}
						return "transient"
					}(),
					"error", err.Error(),
				)
				return ReportPayload{}, TokenStats{}, err
			}
			metadataPayload = markdownResultToPayload(mdResult, chunks, native)
			stats.InputTokens += mdStats.InputTokens
			stats.OutputTokens += mdStats.OutputTokens
		default: // "json" — legacy path, byte-identical to pre-refactor behavior.
			payload, jsonStats, err := callMetadataJSON(ctx, reportLanguage, legacyChunkFormat(chunks))
			if err != nil {
				slog.InfoContext(ctx, "analytics",
					"ae", "llm.failed",
					"session_id", sessionID,
					"call_number", 1,
					"error_category", func() string {
						if isTerminalLLMError(err) {
							return "terminal"
						}
						return "transient"
					}(),
					"error", err.Error(),
				)
				return ReportPayload{}, TokenStats{}, err
			}
			metadataPayload = payload
			stats.InputTokens += jsonStats.InputTokens
			stats.OutputTokens += jsonStats.OutputTokens
		}
	}

	// Analityka: llm.call1.completed
	if len(chunks) >= 2 {
		speakersDetected := len(metadataPayload.SpeakerRoleInference.SpeakerGroups)
		diarizationConfidence := metadataPayload.SpeakerRoleInference.OverallDiarizationConfidence

		slog.InfoContext(ctx, "analytics",
			"ae", "llm.call1.completed",
			"session_id", sessionID,
			"mode", mode,
			"diarization_confidence", diarizationConfidence,
			"speakers_detected", speakersDetected,
		)
	}

	return metadataPayload, stats, nil
}

// generateReportBody runs call-2 (the full clinical report) from call-1's
// metadata plus the retrieved prior-session context (ragContext, empty in
// legacy/first-session cases). stats carries call-1's token counts in; the
// returned stats include call-2's.
func generateReportBody(ctx context.Context, sessionID, reportLanguage, modalityPrompt, ragContext string, chunks []transcriptfmt.Chunk, prefs reportprefs.Preferences, metadataPayload ReportPayload, stats TokenStats) (string, TokenStats, error) {
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
	reportCfg := reportGenConfig(effectiveMaxOut)

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

TARGET LANGUAGE FOR THE REPORT / JĘZYK DOCELOWY RAPORTU: %s

CRITICAL — produce 100%% of the report output in the target language
above. This includes EVERY part of the report, no exceptions besides
literal transcript quotes:
- All section headings (e.g. translate Polish prompt headings like
  "Bilans Sesji", "Inspiracje Między Sesjami" into the target language).
- All bullet labels and structural markdown (e.g. "Tytuł", "Cel",
  "Instrukcja", "Opis sytuacji" → target-language equivalents).
- All example phrasings, suggested instructions to the client, and
  intervention scripts that the modality template above shows in
  Polish — these are STRUCTURAL EXAMPLES, not content; translate
  them. Do not copy Polish wording verbatim.
- All your own prose, analysis, and clinical interpretation.

The ONLY text you must preserve untranslated: literal direct quotes
from the transcript section below. Render each quote as a markdown
blockquote on its own line, prefixed with "> " (greater-than + space):

    > "tekst cytatu w oryginalnym języku"

DO NOT use the label form (e.g. "**Cytat:** ..." or "**Quote:** ...").
DO NOT inline quotes inside a paragraph with just quote marks. The
Flutter rendering layer styles only the "> " blockquote shape —
label-form quotes lose their visual treatment and read as plain
text. Even if the modality template suggests a label form, override
it and use "> ".

Everything else: target language.

KRYTYCZNE — wygeneruj 100%% raportu w docelowym języku powyżej,
łącznie z nagłówkami sekcji, etykietami punktów, oraz przykładami
sformułowań z szablonu modality. JEDYNY wyjątek: dosłowne cytaty z
transkryptu — te pozostaw w oryginale.

Sformatuj raport używając czytelnego Markdown (nagłówki ##, pogrubienia, cytaty).
%s
%s

CZEGO NIE PISZ / WHAT NOT TO WRITE:
- NIE umieszczaj na początku raportu nagłówka z polami typu Klient /
  Client, Imię / Name, ID, Data sesji / Session Date, Terapeuta /
  Therapist. Te metadane są zarządzane przez aplikację (system
  wyświetla je obok raportu) i nie należą do treści generowanej
  przez Ciebie. DO NOT emit a metadata header block with fields like
  Client / Patient / Therapist / Session Date / ID, even with
  placeholder values like "[not provided]". Skip those entirely.
- NIE pisz przedmowy ani powitania w stylu „Witaj, jako Superwizor AI
  specjalizujący się w terapii…" / „Cześć, oto twój raport…" /
  „As Superwizor AI, I will now analyze…". Raport zaczyna się
  bezpośrednio od pierwszej sekcji analitycznej zdefiniowanej w
  szablonie modality (np. „## Podsumowanie sesji" / „## Bilans
  Sesji"). DO NOT emit a self-introductory greeting or preamble —
  no "As Superwizor AI…", no "Hello, here is your report…", no
  "I will now analyze the session…". Start with the first analytical
  heading from the modality template above; the reader already knows
  what tool produced this output.
- NIE rozwijaj sekcji o pola, których szablon nie wymaga.

ZASADY ZWIĘZŁOŚCI (kluczowe — nie ignoruj):
- Raport powinien być WARTOŚCIOWY dla superwizora, NIE wielostronicowy.
- Każda sekcja: 2-5 zdań, max 1 akapit. Wyjątek: studium przypadku / hipotezy
  kliniczne — do 2 akapitów gdy uzasadnione.
- Cytaty z transkryptu: krótkie (1-2 zdania), tylko gdy bezpośrednio
  ilustrują obserwację. Nie cytuj dla samego cytowania.
- UNIKAJ powtórzeń między sekcjami — każda informacja w raporcie max raz.
- Pisz konkretami, używaj fachowego języka, ale nie nadużywaj żargonu.
- Pomijaj nagłówki sekcji jeśli ich treść byłaby pusta/spekulatywna.

KONTEKST POPRZEDNICH SESJI:
%s

TRANSKRYPT BIEŻĄCEJ SESJI (Markdown, grupowanie po mówcach):
%s`,
		modalityPrompt, reportLanguage, prefsFragment, lengthDirective, ragContext, transcriptForCall2)

	debugLogChunked(slog.Default(), "vertex_prompt", "step", "markdown", "content", reportPrompt)

	respReport, err := vertexClient.Models.GenerateContent(ctx, geminiModel, genai.Text(reportPrompt), reportCfg)
	if err != nil {
		slog.InfoContext(ctx, "analytics",
			"ae", "llm.failed",
			"session_id", sessionID,
			"call_number", 2,
			"error_category", func() string {
				if isTerminalLLMError(err) {
					return "terminal"
				}
				return "transient"
			}(),
			"error", err.Error(),
		)
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
	if respReport.Candidates[0].FinishReason == genai.FinishReasonMaxTokens {
		// Analityka: llm.safety_retry
		slog.InfoContext(ctx, "analytics",
			"ae", "llm.safety_retry",
			"session_id", sessionID,
			"retry_reason", "FinishReasonMaxTokens",
		)

		// 2026-05-19: bumped retry multiplier from 2× to 4×. The 2×
		// multiplier sometimes re-hit MaxTokens on the retry (observed:
		// session 0a5523a0, both calls truncated). 4× gives the retry
		// real headroom — with the new 3×-headroom defaults, this path
		// should essentially never fire, but if it does, the retry has
		// budget to actually finish.
		retryMaxOut := effectiveMaxOut * 4
		if retryMaxOut > geminiMaxOutReportHardCeiling {
			retryMaxOut = geminiMaxOutReportHardCeiling
		}
		slog.Warn("call 2 hit MaxOutputTokens — retrying once at 4× cap",
			"original_cap", effectiveMaxOut,
			"retry_cap", retryMaxOut,
			"length_preference", prefs.Length)
		reportCfg = reportGenConfig(retryMaxOut)
		respReport, err = vertexClient.Models.GenerateContent(ctx, geminiModel, genai.Text(reportPrompt), reportCfg)
		if err != nil {
			slog.InfoContext(ctx, "analytics",
				"ae", "llm.failed",
				"session_id", sessionID,
				"call_number", 2,
				"error_category", func() string {
					if isTerminalLLMError(err) {
						return "terminal"
					}
					return "transient"
				}(),
				"error", err.Error(),
			)
			return "", TokenStats{}, fmt.Errorf("generate report markdown (retry): %w", err)
		}
		if len(respReport.Candidates) == 0 || respReport.Candidates[0].Content == nil {
			return "", TokenStats{}, fmt.Errorf("no candidates returned for report markdown (retry)")
		}
		if respReport.Candidates[0].FinishReason == genai.FinishReasonMaxTokens {
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
		if part.Text != "" {
			reportOutput.WriteString(part.Text)
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
// Note: ragContext is NOT passed to call-1. All call-1 outputs (title,
// summary_short, speaker clustering, RAG_Summary, diarization
// confidence) describe THIS session — prior-session context can only
// confuse the structural extraction. See docs/agents/05_ai-pipeline-svc.md
// §"Long-term memory (RAG)" for the rationale.
func callMetadataJSON(ctx context.Context, reportLanguage, transcriptText string) (ReportPayload, TokenStats, error) {
	var schema map[string]any
	if err := json.Unmarshal(reportSchemaBytes, &schema); err != nil {
		return ReportPayload{}, TokenStats{}, fmt.Errorf("parse schema: %w", err)
	}
	cfg := metadataGenConfigJSON(schemaToVertexSchema(schema))

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

TRANSKRYPT BIEŻĄCEJ SESJI:
%s

Wygeneruj TYLKO metadane zgodnie z podanym JSON Schema.

ZASADY ZWIĘZŁOŚCI (kluczowe — nie ignoruj):
- title: max 100 znaków, jedno zdanie/fraza. Opisuje TĘ sesję, nie buduj numeracji ani kontynuacji z wcześniejszych spotkań.
- summary_short: max 500 znaków, 2-3 zdania. Samodzielne streszczenie TEJ sesji — nie odwołuj się do wcześniejszych spotkań.
- evidence (cytaty z transkryptu): pojedynczy cytat, max 200 znaków.
- rag_summary_chunk: max 1500 znaków, kluczowe fakty z TEJ sesji dla pamięci długoterminowej. Nie powtarzaj treści wcześniejszych podsumowań — niech wpis będzie samodzielnym śladem tej sesji.
- rag_themes: 2-5 odrębnych wątków klinicznych TEJ sesji (osobne pozycje tablicy), każdy 2-3 zdania, BEZ danych identyfikujących, w 3. osobie. Pomiń gdy materiał zbyt krótki.
- Pisz konkretami, NIE parafrazuj całych wypowiedzi.`,
		reportLanguage, transcriptText)

	debugLogChunked(slog.Default(), "vertex_prompt", "step", "metadata", "mode", "json", "content", prompt)

	resp, err := vertexClient.Models.GenerateContent(ctx, geminiModel, genai.Text(prompt), cfg)
	if err != nil {
		return ReportPayload{}, TokenStats{}, fmt.Errorf("generate metadata (json): %w", err)
	}
	if len(resp.Candidates) == 0 || resp.Candidates[0].Content == nil {
		return ReportPayload{}, TokenStats{}, fmt.Errorf("no candidates returned for metadata (json)")
	}
	var out strings.Builder
	for _, part := range resp.Candidates[0].Content.Parts {
		if part.Text != "" {
			out.WriteString(part.Text)
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
//
// Note: ragContext is NOT passed to call-1. All call-1 outputs (title,
// summary_short, speaker clustering, RAG_Summary, diarization
// confidence) describe THIS session — prior-session context can only
// confuse the structural extraction. See docs/agents/05_ai-pipeline-svc.md
// §"Long-term memory (RAG)" for the rationale.
func callMetadataMarkdown(ctx context.Context, reportLanguage string, chunks []transcriptfmt.Chunk, native bool) (diarization.Result, TokenStats, error) {
	// No ResponseMIMEType / ResponseSchema in Markdown mode —
	// free-form text out, parsed server-side by internal/diarization.
	cfg := metadataGenConfigMarkdown()

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

TRANSKRYPT (pogrupowany po mówcach):
%s

ODPOWIEDŹ — Sformatuj DOKŁADNIE w tym kształcie Markdown (bez bloków kodu, bez bold, bez list):

# Speakers

Speaker 1 — therapist (confidence 0.92)
Speaker 2 — patient (confidence 0.95)

# Metadata

Title: <tytuł, max 100 znaków, opisuje TĘ sesję — nie buduj numeracji ani kontynuacji>
Summary: <streszczenie, max 500 znaków, 2-3 zdania, samodzielne podsumowanie TEJ sesji>
Overall_diarization_confidence: 0.94
RAG_Summary: <streszczenie do pamięci długoterminowej, max 1500 znaków, gęsto informacyjne, BEZ danych identyfikujących (imion, miejsc, kontaktów). Skup się na kluczowych faktach klinicznych Z TEJ SESJI, wzorcach, hipotezach roboczych. Pisz w 3. osobie ("klient", "pacjent"), bez imion. Nie powtarzaj treści wcześniejszych podsumowań — niech wpis będzie samodzielnym śladem tej sesji.>
RAG_Theme: <jeden odrębny wątek kliniczny TEJ sesji w jednej linii (2-3 zdania), np. "lęk przed matką — klient opisuje onieśmielenie i unikanie". Wygeneruj 2-5 osobnych linii "RAG_Theme:", każda inny temat mogący powrócić w przyszłych sesjach. BEZ danych identyfikujących, w 3. osobie. Nie dziel jednego tematu na kilka wpisów; nie twórz wątku ze small-talku. Pomiń gdy materiał zbyt krótki (≤1 chunk).>

ZASADY:
- Sekcje "# Speakers" i "# Metadata", dokładnie w tej kolejności.
- Po jednym wierszu na speakera w "# Speakers".
- Confidence: float 0.0–1.0.
- RAG_Summary jest opcjonalne tylko gdy materiał jest zbyt krótki (≤1 chunk); inaczej WYMAGANE.
- RAG_Theme: 2-5 osobnych linii (po jednym wątku), opcjonalne; pomiń gdy materiał zbyt krótki.
- BEZ żadnego tekstu poza tym blokiem.`,
			reportLanguage, transcriptStr)
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

Title: <tytuł, max 100 znaków, opisuje TĘ sesję — nie buduj numeracji ani kontynuacji>
Summary: <streszczenie, max 500 znaków, 2-3 zdania, samodzielne podsumowanie TEJ sesji>
Overall_diarization_confidence: 0.89
RAG_Summary: <streszczenie do pamięci długoterminowej, max 1500 znaków, gęsto informacyjne, BEZ danych identyfikujących (imion, miejsc, kontaktów). Skup się na kluczowych faktach klinicznych Z TEJ SESJI, wzorcach, hipotezach roboczych. Pisz w 3. osobie ("klient", "pacjent"), bez imion. Nie powtarzaj treści wcześniejszych podsumowań — niech wpis będzie samodzielnym śladem tej sesji.>
RAG_Theme: <jeden odrębny wątek kliniczny TEJ sesji w jednej linii (2-3 zdania), np. "lęk przed matką — klient opisuje onieśmielenie i unikanie". Wygeneruj 2-5 osobnych linii "RAG_Theme:", każda inny temat mogący powrócić w przyszłych sesjach. BEZ danych identyfikujących, w 3. osobie. Nie dziel jednego tematu na kilka wpisów; nie twórz wątku ze small-talku. Pomiń gdy materiał zbyt krótki (≤1 chunk).>

ZASADY:
- Sekcje "# Speakers" i "# Metadata", dokładnie w tej kolejności.
- "## Group N — <rola> (confidence 0.XX)" — używaj em-dash "—".
- "Chunks:" — liczby chunków oddzielone przecinkami, każdy chunk w DOKŁADNIE JEDNEJ grupie.
- "Evidence:" — pojedynczy cytat z transkrypcji w cudzysłowach.
- Confidence: float 0.0–1.0.
- RAG_Summary jest opcjonalne tylko gdy materiał jest zbyt krótki (≤1 chunk); inaczej WYMAGANE.
- RAG_Theme: 2-5 osobnych linii (po jednym wątku), opcjonalne; pomiń gdy materiał zbyt krótki.
- BEZ żadnego tekstu poza tym blokiem.`,
			reportLanguage, transcriptStr)
	}

	debugLogChunked(slog.Default(), "vertex_prompt", "step", "metadata", "mode", "markdown", "native", native, "content", prompt)

	resp, err := vertexClient.Models.GenerateContent(ctx, geminiModel, genai.Text(prompt), cfg)
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
	if resp.Candidates[0].FinishReason == genai.FinishReasonMaxTokens {
		// 4× multiplier (bumped from 2× on 2026-05-19) — symmetric with
		// the call-2 retry. Call-1 metadata cap is already generous
		// (16384), so 4× ceilings at the hard limit; the clamp below
		// handles that.
		retryMaxOut := geminiMaxOutMetadata * 4
		if retryMaxOut > geminiMaxOutReportHardCeiling {
			retryMaxOut = geminiMaxOutReportHardCeiling
		}
		slog.Warn("call 1 (markdown) hit MaxOutputTokens — retrying once at 4× cap",
			"original_cap", geminiMaxOutMetadata,
			"retry_cap", retryMaxOut,
			"native_diarization", native)
		// Rebuild config with bumped cap; keep temp/TopP identical.
		retryConfig := metadataGenConfigMarkdown()
		retryConfig.MaxOutputTokens = retryMaxOut
		resp, err = vertexClient.Models.GenerateContent(ctx, geminiModel, genai.Text(prompt), retryConfig)
		if err != nil {
			return diarization.Result{}, TokenStats{}, fmt.Errorf("generate metadata (markdown, retry): %w", err)
		}
		if len(resp.Candidates) == 0 || resp.Candidates[0].Content == nil {
			return diarization.Result{}, TokenStats{}, fmt.Errorf("no candidates returned for metadata (markdown, retry)")
		}
		if resp.Candidates[0].FinishReason == genai.FinishReasonMaxTokens {
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
		if part.Text != "" {
			out.WriteString(part.Text)
		}
	}
	debugLogChunked(slog.Default(), "vertex_response", "step", "metadata", "mode", "markdown", "content", out.String())

	result, err := diarization.ParseMetadataMarkdown(out.String())
	if err != nil {
		return diarization.Result{}, TokenStats{}, fmt.Errorf("parse markdown metadata: %w", err)
	}
	// Surface the cross-group-duplicate count if the parser silently
	// resolved one. Healthy sessions log nothing; non-zero is a
	// quality signal we want to watch (Marcin 2026-05-28 incident).
	if result.DroppedDuplicates > 0 {
		slog.Warn("diarization parser dropped cross-group duplicate chunks",
			"dropped_count", result.DroppedDuplicates,
			"speakers", len(result.Speakers),
		)
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

	// Stage-2-alignment orphan reattach (added 2026-05-23 after the
	// Gabriela En test session 78679bff-…). Cross-chunk speaker-label
	// alignment in internal/sttgcs/alignment.go::AlignAndMapSpeakers
	// can offset a borderline-ambiguous label into a fresh integer
	// (e.g. "3" in a 2-speaker session) when the majority-fraction
	// threshold (alignMajorityFraction=0.6) isn't met. The LLM has
	// already inferred the true speaker count N from transcript
	// content; any chunk whose SpeakerTag is outside the LLM's
	// Speaker.Index set is an alignment artifact representing
	// continuation of one of the LLM-identified speakers — not a
	// genuine extra person. Without this reattach those chunks
	// silently disappear from the report ("missing person"), since
	// the loop above only matches chunks by exact Index ↔ SpeakerTag
	// equality.
	//
	// Strategy: for each extra-tag chunk, scan forward and backward
	// in chunk-index order for the nearest chunk whose tag IS in
	// knownTags; attribute the orphan to that LLM speaker. Adjacency
	// is the right signal because alignment artifacts cluster
	// temporally — a misaligned label run usually appears inside
	// one speaker's continuous utterance.
	if native && len(groups) >= 2 {
		knownTags := make(map[int32]int, len(r.Speakers))
		for i, sp := range r.Speakers {
			knownTags[int32(sp.Index)] = i
		}
		// Track which chunk indices have already been assigned (either through
		// exact native speaker matching or the emptyCount==1 reattach layer)
		// to prevent double assignment of tag=0 chunks.
		assignedIndices := make(map[int]bool)
		for _, g := range groups {
			for _, idx := range g.ChunkIndices {
				assignedIndices[idx] = true
			}
		}
		extraTagCount := 0
		extraTagSet := map[int32]bool{}
		for i, c := range chunks {
			if _, ok := knownTags[c.SpeakerTag]; ok {
				continue
			}
			if assignedIndices[c.ChunkIdx] {
				continue
			}
			gIdx := nearestKnownGroupIndex(chunks, i, knownTags)
			if gIdx < 0 {
				continue
			}
			groups[gIdx].ChunkIndices = append(groups[gIdx].ChunkIndices, c.ChunkIdx)
			extraTagCount++
			extraTagSet[c.SpeakerTag] = true
		}
		if extraTagCount > 0 {
			tags := make([]int, 0, len(extraTagSet))
			for t := range extraTagSet {
				tags = append(tags, int(t))
			}
			slog.Info("stt_stage2_alignment_orphan_reattach",
				"reattached_chunks", extraTagCount,
				"orphan_tags", tags,
				"known_tags", knownTagsAsInts(knownTags))
		}
	}

	// RAGSummaryChunk fall-through: prefer the dedicated RAG_Summary
	// line from the parser; fall back to SummaryShort when the model
	// didn't emit one (small sessions, parser leniency). Empty stays
	// empty — persistRAGMemory writes a row anyway today but the
	// real loadRAGContext will filter empty plaintext when reading.
	rag := r.RAGSummary
	if rag == "" {
		rag = r.Summary
	}
	return ReportPayload{
		Title:           r.Title,
		SummaryShort:    r.Summary,
		RAGSummaryChunk: rag,
		RAGThemes:       r.RAGThemes,
		SpeakerRoleInference: SpeakerRoleInference{
			Method:                       method,
			SpeakerGroups:                groups,
			OverallDiarizationConfidence: r.OverallDiarizationConfidence,
		},
	}
}

// nearestKnownGroupIndex returns the groups[] index for the LLM
// speaker whose chunks are temporally closest (in chunk-index order)
// to chunks[i]. Used by the Stage-2-alignment orphan reattach in
// markdownResultToPayload to assign chunks whose SpeakerTag is not
// in the LLM's Index set to one of the LLM-inferred speakers.
//
// Scans symmetrically outward from i. The first chunk found whose
// SpeakerTag is in knownTags wins. Ties (same distance forward and
// backward) prefer backward — matches the common case where a
// misaligned label run is a continuation of the immediately-prior
// speaker's utterance after a brief pause.
//
// Returns -1 if no neighbouring chunk has a known tag (degenerate:
// the entire chunk array consists of unknown-tag chunks; nothing
// reasonable to do).
func nearestKnownGroupIndex(chunks []transcriptfmt.Chunk, i int, knownTags map[int32]int) int {
	for off := 1; off < len(chunks); off++ {
		if b := i - off; b >= 0 {
			if gIdx, ok := knownTags[chunks[b].SpeakerTag]; ok {
				return gIdx
			}
		}
		if f := i + off; f < len(chunks) {
			if gIdx, ok := knownTags[chunks[f].SpeakerTag]; ok {
				return gIdx
			}
		}
	}
	return -1
}

// knownTagsAsInts is a small helper for the slog.Info call in the
// Stage-2 reattach. Renders the map's keys as a []int so the log
// line gets a stable, ordered representation of which SpeakerTag
// values the LLM expects to see.
func knownTagsAsInts(knownTags map[int32]int) []int {
	out := make([]int, 0, len(knownTags))
	for t := range knownTags {
		out = append(out, int(t))
	}
	return out
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

func mapSchemaType(t string) genai.Type {
	switch t {
	case "string":
		return genai.TypeString
	case "number":
		return genai.TypeNumber
	case "integer":
		return genai.TypeInteger
	case "boolean":
		return genai.TypeBoolean
	case "array":
		return genai.TypeArray
	case "object":
		return genai.TypeObject
	default:
		return genai.TypeUnspecified
	}
}

func schemaToVertexSchema(s map[string]any) *genai.Schema {
	if s == nil {
		return nil
	}
	vs := &genai.Schema{}

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
		vs.Properties = make(map[string]*genai.Schema)
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
//  3. Generujemy lokalizowany label per tag — role-aware via
//     pkg/i18n/rolelabels (which branches on session.ModalityType
//     and falls through to speakerlabels.Generate for non-dyadic
//     roles like couple_partner / family_member / third_party).
//  4. UPDATE transcript_segments — wszystkie segmenty należące do chunków z grupy.
//  5. UPDATE sessions.speaker_label_mapping = {1: "Terapeuta", 2: "Pacjent"}
//     (or "Trener"/"Klient" for coaching modality, or "Osoba N" for
//     non-dyadic roles, or numeric suffix for collisions).
//
// Iteration order is the order the LLM emitted the SpeakerGroups —
// stable across runs given the same response. The first speaker
// classified as `therapist` claims the bare "Terapeuta" label;
// the second claims "Terapeuta 2"; same for `patient`. Independent
// counters are maintained by rolelabels.Generate via the
// `takenRoles` map we pass in.
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

	// Walk tags in insertion order so the first "therapist" /
	// "patient" group gets the bare label and subsequent groups of
	// the same role get the numeric suffix. Sorting by tag (which
	// equals insertion order) gives us that determinism without
	// relying on Go map iteration order.
	tagToLabel := map[int32]string{}
	takenRoles := map[string]int{}
	orderedTags := make([]int32, 0, len(tagToRole))
	for t := range tagToRole {
		orderedTags = append(orderedTags, t)
	}
	sort.Slice(orderedTags, func(i, j int) bool { return orderedTags[i] < orderedTags[j] })
	for _, t := range orderedTags {
		label, _ := rolelabels.Generate(
			session.LanguageCode,
			session.ModalityType,
			tagToRole[t],
			int(t),
			takenRoles,
		)
		tagToLabel[t] = label
	}
	// speakerlabels stays imported for the fallthrough path inside
	// rolelabels.Generate. Touch a no-op reference here so a
	// future refactor that removes it from rolelabels still has a
	// compile-time pointer to the right place.
	_ = speakerlabels.Generate

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

	// Rebuild the canonical transcript blob (transcripts.transcript_ciphertext)
	// so the per-line speaker_tag + speaker_label written above are reflected
	// in the blob too. Without this step the blob keeps stt-worker's
	// "no diarization" defaults (speaker_tag=null, speaker_label=null) and
	// any consumer reading the blob (e.g. clinical-svc.GetSessionDetails
	// optimized path) sees text without role assignment. The blob is the
	// source of truth (ADR-IMPL-006); segments are derived. We mirror what
	// labels.go::UpdateSpeakerLabels does — same shape, same transaction —
	// minus the user-supplied label remap. Cost: 1 KMS decrypt + 1 KMS
	// encrypt total, independent of segment count.
	if err := rebuildBlobWithRoles(ctx, tx, transID, chunkToTag, tagToLabel); err != nil {
		// Soft-fail: surfaces in logs but doesn't roll back the segment
		// + mapping writes. Per-segment data is still correct; only the
		// blob lags. A retry of the whole label step (Pub/Sub redelivery)
		// would re-write everything.
		slog.WarnContext(ctx, "rebuild transcript blob failed", "error", err, "transcript_id", transID)
	}

	return tx.Commit(ctx)
}

// rebuildBlobWithRoles reads transcripts.transcript_ciphertext, applies the
// freshly-inferred chunk_idx → speaker_tag → speaker_label mapping to each
// blob line, and writes the result back. Runs inside the supplied tx so
// the blob stays consistent with transcript_segments at commit time.
//
// Why we read the blob here rather than reusing the already-decrypted
// `chunks` from ProcessTranscript: the on-disk blob carries fields the
// caller's transcriptfmt.Chunk type strips (confidence, word_count), and
// keeping them preserves debugging context for the long term. Single KMS
// decrypt is cheap.
func rebuildBlobWithRoles(ctx context.Context, tx pgx.Tx, transcriptID uuid.UUID, chunkToTag map[int]int32, tagToLabel map[int32]string) error {
	var ciphertext, encryptedDEK []byte
	if err := tx.QueryRow(ctx,
		"SELECT transcript_ciphertext, transcript_encrypted_dek FROM transcripts WHERE id = $1 FOR UPDATE",
		transcriptID).Scan(&ciphertext, &encryptedDEK); err != nil {
		return fmt.Errorf("read transcript: %w", err)
	}
	if len(ciphertext) == 0 {
		// No blob to rebuild (legacy / mock-mode rows). Skip silently;
		// the segment + sessions writes above already happened.
		return nil
	}

	plain, err := crypto.Decrypt(ctx, ciphertext, encryptedDEK)
	if err != nil {
		return fmt.Errorf("decrypt blob: %w", err)
	}

	// Preserve the stt-worker BlobLine schema (pointers on speaker_*
	// stay, but we always populate them now). Old consumers (llm-worker
	// loadTranscriptBlob, clinical-svc when it learns to use the blob)
	// keep working — only the speaker_* fields change from null to set.
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
	if err := json.Unmarshal(plain, &lines); err != nil {
		return fmt.Errorf("unmarshal blob: %w", err)
	}

	for i := range lines {
		// Use chunk_idx if present and within range, otherwise positional
		// fallback (the blob is written in chunk_idx order at persist time).
		idx := lines[i].ChunkIdx
		if idx <= 0 && i > 0 {
			idx = i
		}
		tag, ok := chunkToTag[idx]
		if !ok {
			// Chunk didn't end up in any inferred speaker group
			// (filler/unknown/silence). Clear the speaker fields so
			// downstream consumers see the absence rather than stale
			// labels from a prior rebuild.
			lines[i].SpeakerTag = nil
			lines[i].SpeakerLabel = nil
			continue
		}
		t := tag
		lbl := tagToLabel[tag]
		lines[i].SpeakerTag = &t
		lines[i].SpeakerLabel = &lbl
	}

	newJSON, err := json.Marshal(lines)
	if err != nil {
		return fmt.Errorf("marshal blob: %w", err)
	}
	newCiphertext, newDEK, err := crypto.Encrypt(ctx, newJSON)
	if err != nil {
		return fmt.Errorf("encrypt blob: %w", err)
	}
	if _, err := tx.Exec(ctx,
		`UPDATE transcripts
		   SET transcript_ciphertext   = $1,
		       transcript_encrypted_dek = $2,
		       blob_rebuilt_at          = NOW(),
		       blob_rebuild_count       = COALESCE(blob_rebuild_count, 0) + 1
		 WHERE id = $3`,
		newCiphertext, newDEK, transcriptID); err != nil {
		return fmt.Errorf("update transcript: %w", err)
	}
	return nil
}

// generateEmbedding calls Vertex AI's text-embedding-005 to produce a
// 768-dim multilingual vector for the given text. Returns the
// zero-vector (and a nil error) on empty input — keeps the worker
// path resilient to the small-session edge case where the LLM didn't
// emit a RAG_Summary line.
//
// Cost: ~$0.0001 per call at current Vertex AI pricing (negligible —
// one embed per report).
//
// Failure mode: any Vertex error returns the error to the caller.
// The caller (`ProcessTranscript`) already logs Warn + skips
// persistRAGMemory rather than failing the whole report.
func generateEmbedding(ctx context.Context, text string) ([]float32, error) {
	if vertexClient == nil {
		// Local/dev mode (no project configured) — preserve the old
		// stub behavior so unit tests don't need a Vertex shim.
		return make([]float32, embeddingDims), nil
	}
	if strings.TrimSpace(text) == "" {
		// Common case for sub-2-chunk sessions where the LLM skipped
		// RAG_Summary entirely. Zero vector means the row still
		// participates in the patient's memory index (via
		// patient_file_id filtering) but ranks neutrally in cosine
		// similarity. Caller decides whether to persist.
		return make([]float32, embeddingDims), nil
	}

	resp, err := vertexClient.Models.EmbedContent(ctx, embeddingModel,
		[]*genai.Content{genai.NewContentFromText(text, genai.RoleUser)},
		nil)
	if err != nil {
		return nil, fmt.Errorf("embed text: %w", err)
	}
	if len(resp.Embeddings) == 0 || len(resp.Embeddings[0].Values) == 0 {
		return nil, fmt.Errorf("embed: empty response")
	}
	vec := resp.Embeddings[0].Values
	if len(vec) != embeddingDims {
		// Defensive: Vertex documents 768 for text-embedding-005 but a
		// dimension mismatch would silently corrupt the pgvector
		// column (vector(768) constraint would reject the INSERT, but
		// surface the cause early here).
		return nil, fmt.Errorf("embed: unexpected dim %d (want %d)", len(vec), embeddingDims)
	}
	return vec, nil
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
	var modalityType *string
	row := dbPool.QueryRow(ctx, `
		SELECT s.patient_file_id, pf.therapist_id, pf.modality_id,
		       m.modality_type::text,
		       s.speaker_label_mapping, s.language_code, s.report_language,
		       COALESCE(u.report_preferences, '{}'::jsonb)
		FROM sessions s
		JOIN patient_files pf ON pf.id = s.patient_file_id
		JOIN users u ON u.id = pf.therapist_id
		LEFT JOIN modalities m ON m.id = pf.modality_id
		WHERE s.id = $1`, id)
	if err := row.Scan(&sc.PatientFileID, &sc.TherapistID, &sc.ModalityID,
		&modalityType,
		&mappingJSON, &langCode, &reportLang, &prefsRaw); err != nil {
		return nil, err
	}
	// LEFT JOIN guards against a patient_file with a NULL or
	// dangling modality_id (shouldn't happen but harmless). Fall
	// back to therapy — the catalog is overwhelmingly clinical.
	if modalityType != nil {
		sc.ModalityType = *modalityType
	} else {
		sc.ModalityType = "therapy"
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

// loadRAGContext retrieves up to ragTopK encrypted long-term-memory
// summaries from this patient's prior sessions, ranked by cosine
// similarity against currentText's embedding, decrypts them, and
// returns a newline-joined block suitable for the call-1/call-2
// prompt's `KONTEKST POPRZEDNICH SESJI:` slot.
//
// Returns empty string (and nil error) for any of:
//   - dbPool unconfigured (local/test mode)
//   - this patient has no prior memories yet (first session)
//   - the query embedding failed
//   - every nearest neighbor decrypts to empty plaintext (the legacy
//     "RAGSummaryChunk == \"\"" historical bug; option-A backfill is
//     skipped per user direction — those rows just rank low)
//
// Side effect: bumps `last_accessed_at` on the retrieved rows so
// future compaction prioritizes stale memories. Best-effort; an
// UPDATE failure logs Warn but doesn't fail the read.
//
// Prompt-budget guard: caps the joined output at ragContextMaxChars
// to avoid blowing the call-1/call-2 input window when a patient
// accumulates 50+ sessions. Older rows truncated last (the SELECT
// orders by similarity ascending — closest first).
func loadRAGContext(ctx context.Context, sessionID string, patientFileID uuid.UUID, currentText string) (string, error) {
	if dbPool == nil {
		return "", nil
	}
	if strings.TrimSpace(currentText) == "" {
		return "", nil
	}

	queryVec, err := generateEmbedding(ctx, currentText)
	if err != nil {
		// Non-fatal — log via the caller's Warn. Returning empty here
		// means the model gets no prior context this round, same as
		// the legacy stub behavior. Better than failing the report.
		return "", fmt.Errorf("rag query embed: %w", err)
	}

	// Two-stage filter to keep the candidate pool bounded:
	//   stage 1 (recent CTE): patient's last ragLookbackMemories rows,
	//     newest first by created_at. Hard ceiling so a veteran patient
	//     with 200 sessions doesn't drag in 5-year-old states.
	//   stage 2 (outer SELECT): nearest neighbors within that pool by
	//     pgvector cosine distance. HNSW index
	//     `idx_rag_memories_embedding` covers the inner ORDER BY when
	//     the candidate count is comparable to lookback size.
	//
	// patient_file_id filter on the CTE is BOTH a privacy guarantee
	// (no cross-patient leakage) and an HNSW pre-filter via the
	// partial index `idx_rag_memories_patient_file`.
	rows, err := dbPool.Query(ctx, `
		WITH recent AS (
			SELECT id, summary_ciphertext, summary_encrypted_dek, embedding
			FROM rag_memories
			WHERE patient_file_id = $1 AND NOT is_compacted
			  -- chunk_type='summary' keeps this legacy reader on its
			  -- original whole-session behavior even after persistRAGMemoryV2
			  -- starts writing 'theme' rows. The v2 reader (docs/30 Phase 3)
			  -- is what consumes themes; until then they accumulate dormant.
			  AND chunk_type = 'summary'
			ORDER BY created_at DESC
			LIMIT $4
		)
		SELECT id, summary_ciphertext, summary_encrypted_dek
		FROM recent
		ORDER BY embedding <=> $2::vector
		LIMIT $3`,
		patientFileID, vectorToString(queryVec), ragTopK, ragLookbackMemories)
	if err != nil {
		return "", fmt.Errorf("rag query: %w", err)
	}
	defer rows.Close()

	type memHit struct {
		id        uuid.UUID
		plaintext string
	}
	var hits []memHit
	for rows.Next() {
		var id uuid.UUID
		var ct, dek []byte
		if scanErr := rows.Scan(&id, &ct, &dek); scanErr != nil {
			return "", fmt.Errorf("rag scan: %w", scanErr)
		}
		pt, decErr := crypto.Decrypt(ctx, ct, dek)
		if decErr != nil {
			// KMS misconfig or corrupted row. Log + skip — one bad
			// row shouldn't poison the whole retrieval.
			slog.Warn("rag decrypt failed", "rag_memory_id", id.String(), "error", decErr)
			continue
		}
		ptStr := strings.TrimSpace(string(pt))
		if ptStr == "" {
			// Legacy markdown-mode rows with RAGSummaryChunk="" land
			// here. Skip silently — they got ranked by zero-vector
			// embedding back when the stub ran, so they're high in
			// the result set on every query. Not actionable signal.
			continue
		}
		hits = append(hits, memHit{id: id, plaintext: ptStr})
	}
	if rerr := rows.Err(); rerr != nil {
		return "", fmt.Errorf("rag rows: %w", rerr)
	}
	if len(hits) == 0 {
		return "", nil
	}

	// Bump last_accessed_at on the retrieved rows (best-effort).
	// Background UPDATE so the cosmetic timestamp bump doesn't add
	// latency to the worker's critical path.
	hitIDs := make([]uuid.UUID, len(hits))
	for i, h := range hits {
		hitIDs[i] = h.id
	}
	go func(ids []uuid.UUID) {
		bgCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if _, uerr := dbPool.Exec(bgCtx,
			`UPDATE rag_memories SET last_accessed_at = now() WHERE id = ANY($1)`,
			ids); uerr != nil {
			slog.Warn("rag last_accessed bump failed", "ids_count", len(ids), "error", uerr)
		}
	}(hitIDs)

	// Join with double-newlines so the LLM sees each memory as its
	// own paragraph. Number them (1., 2., …) so prompt instructions
	// can reference "the most relevant prior session" naturally.
	var sb strings.Builder
	memoriesUsed := 0
	for i, h := range hits {
		next := fmt.Sprintf("%d. %s\n\n", i+1, h.plaintext)
		// Prompt-budget guard. ragContextMaxChars is generous enough
		// for the typical top-3 hits (~4500 chars) but trims when the
		// LLM occasionally writes a longer summary or when ragTopK
		// grows in the future.
		if sb.Len()+len(next) > ragContextMaxChars {
			break
		}
		sb.WriteString(next)
		memoriesUsed++
	}
	resultString := strings.TrimRight(sb.String(), "\n")

	// Analityka: rag.retrieved
	slog.InfoContext(ctx, "analytics",
		"ae", "rag.retrieved",
		"session_id", sessionID,
		"memories_found", len(hits),
		"memories_used", memoriesUsed,
		"context_chars", len(resultString),
	)

	return resultString, nil
}

// loadRAGContextV2 is the theme-level retriever (docs/30). The query is
// THIS session's distilled themes (from call-1), not the raw transcript —
// which both fixes the embedding-truncation bug and matches query
// representation to the stored theme/summary rows. Ranking (anchor +
// recency-weighted cosine + MMR diversity) runs in Go via selectRAGHits;
// only the winners are decrypted. Best-effort: returns "" + err on any
// failure, exactly like the legacy reader.
func loadRAGContextV2(ctx context.Context, sessionID string, patientFileID uuid.UUID, themes []string, ragSummary string, chunks []transcriptfmt.Chunk) (string, error) {
	if dbPool == nil {
		return "", nil
	}
	curSession, err := uuid.Parse(sessionID)
	if err != nil {
		return "", fmt.Errorf("parse session id: %w", err)
	}

	// Query texts: each theme is its own query vector; fall back to the
	// summary, then the transcript head+tail. The per-theme vectors are
	// what let selectRAGHits surface DISTINCT prior threads.
	queryTexts := make([]string, 0, len(themes)+1)
	for _, t := range themes {
		if t = strings.TrimSpace(t); t != "" {
			queryTexts = append(queryTexts, t)
		}
	}
	if len(queryTexts) == 0 {
		if s := strings.TrimSpace(ragSummary); s != "" {
			queryTexts = append(queryTexts, s)
		}
	}
	if len(queryTexts) == 0 {
		if s := strings.TrimSpace(transcriptHeadTail(chunks, 1000)); s != "" {
			queryTexts = append(queryTexts, s)
		}
	}
	if len(queryTexts) == 0 {
		return "", nil
	}

	// Embed query texts concurrently.
	queryVecs := make([][]float32, len(queryTexts))
	g, gctx := errgroup.WithContext(ctx)
	g.SetLimit(6)
	for i := range queryTexts {
		i := i
		g.Go(func() error {
			v, embErr := generateEmbedding(gctx, queryTexts[i])
			if embErr != nil {
				return embErr
			}
			queryVecs[i] = v
			return nil
		})
	}
	if err := g.Wait(); err != nil {
		return "", fmt.Errorf("rag query embed: %w", err)
	}
	qv := make([][]float32, 0, len(queryVecs))
	for _, v := range queryVecs {
		if len(v) == embeddingDims {
			qv = append(qv, v)
		}
	}
	if len(qv) == 0 {
		return "", nil
	}

	pool, anchorID, err := loadRAGPool(ctx, patientFileID, curSession)
	if err != nil {
		return "", err
	}
	if len(pool) == 0 {
		return "", nil
	}

	hits := selectRAGHits(pool, qv, anchorID, time.Now())
	if len(hits) == 0 {
		return "", nil
	}

	block, used := assembleRAGContext(ctx, hits, anchorID)

	// last_accessed_at bump (best-effort, background — cosmetic).
	hitIDs := make([]uuid.UUID, len(hits))
	for i, h := range hits {
		hitIDs[i] = h.ID
	}
	go func(ids []uuid.UUID) {
		bg, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if _, uerr := dbPool.Exec(bg,
			`UPDATE rag_memories SET last_accessed_at = now() WHERE id = ANY($1)`, ids); uerr != nil {
			slog.Warn("rag last_accessed bump failed", "ids_count", len(ids), "error", uerr)
		}
	}(hitIDs)

	sessSet := map[uuid.UUID]bool{}
	for _, h := range hits {
		sessSet[h.SessionID] = true
	}
	slog.InfoContext(ctx, "analytics",
		"ae", "rag.retrieved",
		"session_id", sessionID,
		"mode", "v2",
		"pool_size", len(pool),
		"themes_count", len(qv),
		"hits", len(hits),
		"memories_used", used,
		"sessions_represented", len(sessSet),
		"anchor_used", anchorID != uuid.Nil,
		"context_chars", len(block),
	)
	return block, nil
}

// loadRAGPool fetches the ranking pool: every memory row belonging to the
// patient's most-recent ragLookbackSessions sessions (excluding the
// session being processed), embeddings only — no ciphertext, no decrypt.
// Returns the pool and the anchor id (the summary row of the most recent
// prior session, uuid.Nil if none).
func loadRAGPool(ctx context.Context, patientFileID, excludeSession uuid.UUID) ([]ragCandidate, uuid.UUID, error) {
	rows, err := dbPool.Query(ctx, `
		WITH recent_sessions AS (
			SELECT source_session_id, max(created_at) AS session_at
			FROM rag_memories
			WHERE patient_file_id = $1 AND NOT is_compacted
			  AND source_session_id IS NOT NULL
			  AND source_session_id <> $2
			GROUP BY source_session_id
			ORDER BY session_at DESC
			LIMIT $3
		)
		SELECT m.id, m.source_session_id, m.chunk_type, m.created_at, m.embedding::text
		FROM rag_memories m
		JOIN recent_sessions rs ON rs.source_session_id = m.source_session_id
		WHERE m.patient_file_id = $1 AND NOT m.is_compacted`,
		patientFileID, excludeSession, ragLookbackSessions)
	if err != nil {
		return nil, uuid.Nil, fmt.Errorf("rag pool query: %w", err)
	}
	defer rows.Close()

	var pool []ragCandidate
	var anchorID uuid.UUID
	var anchorAt time.Time
	for rows.Next() {
		var c ragCandidate
		var embStr string
		if scanErr := rows.Scan(&c.ID, &c.SessionID, &c.ChunkType, &c.CreatedAt, &embStr); scanErr != nil {
			return nil, uuid.Nil, fmt.Errorf("rag pool scan: %w", scanErr)
		}
		c.Embedding = parseEmbedding(embStr)
		pool = append(pool, c)
		if c.ChunkType == "summary" && (anchorID == uuid.Nil || c.CreatedAt.After(anchorAt)) {
			anchorID = c.ID
			anchorAt = c.CreatedAt
		}
	}
	return pool, anchorID, rows.Err()
}

// assembleRAGContext decrypts the selected rows and renders the call-2
// context block: hits grouped by session (anchor session first, then in
// hit order), each session dated, items globally numbered. Honors
// ragContextMaxCharsV2 (anchor is never trimmed). Returns the block and
// the number of memories actually rendered.
func assembleRAGContext(ctx context.Context, hits []ragCandidate, anchorID uuid.UUID) (string, int) {
	ids := make([]uuid.UUID, len(hits))
	for i, h := range hits {
		ids[i] = h.ID
	}
	plain := map[uuid.UUID]string{}
	rows, err := dbPool.Query(ctx,
		`SELECT id, summary_ciphertext, summary_encrypted_dek FROM rag_memories WHERE id = ANY($1)`, ids)
	if err != nil {
		slog.Warn("rag assemble query failed", "error", err)
		return "", 0
	}
	defer rows.Close()
	for rows.Next() {
		var id uuid.UUID
		var ct, dek []byte
		if rows.Scan(&id, &ct, &dek) != nil {
			continue
		}
		pt, decErr := crypto.Decrypt(ctx, ct, dek)
		if decErr != nil {
			slog.Warn("rag decrypt failed", "rag_memory_id", id.String(), "error", decErr)
			continue
		}
		if s := strings.TrimSpace(string(pt)); s != "" {
			plain[id] = s
		}
	}

	// Group by session, preserving hit order (anchor-first, then score).
	type grp struct {
		date  time.Time
		items []ragCandidate
	}
	var order []*grp
	bySession := map[uuid.UUID]*grp{}
	for _, h := range hits {
		gp := bySession[h.SessionID]
		if gp == nil {
			gp = &grp{date: h.CreatedAt}
			bySession[h.SessionID] = gp
			order = append(order, gp)
		}
		if h.CreatedAt.After(gp.date) {
			gp.date = h.CreatedAt
		}
		gp.items = append(gp.items, h)
	}

	var sb strings.Builder
	sb.WriteString("KONTEKST POPRZEDNICH SESJI:\n")
	n, used := 0, 0
	for _, gp := range order {
		isAnchor := len(gp.items) > 0 && gp.items[0].ID == anchorID
		header := fmt.Sprintf("\n[Sesja z %s — powiązane wątki]\n", gp.date.Format("2006-01-02"))
		if isAnchor {
			header = fmt.Sprintf("\n[Poprzednia sesja — %s]\n", gp.date.Format("2006-01-02"))
		}
		pending := header
		added := 0
		for _, it := range gp.items {
			txt := plain[it.ID]
			if txt == "" {
				continue
			}
			line := fmt.Sprintf("%d. %s\n", n+1, txt)
			if !isAnchor && sb.Len()+len(pending)+len(line) > ragContextMaxCharsV2 {
				break
			}
			pending += line
			n++
			added++
			used++
		}
		if added > 0 {
			sb.WriteString(pending)
		}
	}
	return strings.TrimSpace(sb.String()), used
}

// parseEmbedding parses pgvector's text form "[f1,f2,...]" into []float32.
// A malformed value yields nil (length-0) so the row ranks neutrally
// rather than corrupting the cosine math.
func parseEmbedding(s string) []float32 {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "[")
	s = strings.TrimSuffix(s, "]")
	if s == "" {
		return nil
	}
	parts := strings.Split(s, ",")
	v := make([]float32, 0, len(parts))
	for _, p := range parts {
		f, perr := strconv.ParseFloat(strings.TrimSpace(p), 32)
		if perr != nil {
			return nil
		}
		v = append(v, float32(f))
	}
	return v
}

// transcriptHeadTail is the last-resort retrieval query when call-1
// produced neither themes nor a summary (sub-2-chunk sessions): the
// first + last n chars of the formatted transcript.
func transcriptHeadTail(chunks []transcriptfmt.Chunk, n int) string {
	full := legacyChunkFormat(chunks)
	if len(full) <= 2*n {
		return full
	}
	return full[:n] + " … " + full[len(full)-n:]
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

// persistRAGMemoryV2 writes this session's long-term memory: one
// 'summary' row (always — it doubles as the previous-session anchor and
// the fallback when no themes were emitted) plus one 'theme' row per
// distinct RAG_Theme the model produced (docs/30 §3.2). Each row gets
// its own embedding, generated concurrently (bounded), and all rows land
// in a single transaction.
//
// Best-effort by contract: the caller Warns and continues on error. A
// missing memory degrades future recall but must never fail the report.
func persistRAGMemoryV2(ctx context.Context, session *SessionContext, reportID string, report *ReportPayload) error {
	repID, err := uuid.Parse(reportID)
	if err != nil {
		return err
	}

	type ragRow struct {
		text       string
		chunkType  string
		importance float64
	}
	// Summary first (anchor / fallback), then de-duplicated non-empty themes.
	rows := []ragRow{{text: report.RAGSummaryChunk, chunkType: "summary", importance: 0.7}}
	seen := map[string]bool{}
	for _, th := range report.RAGThemes {
		th = strings.TrimSpace(th)
		if th == "" || seen[th] {
			continue
		}
		seen[th] = true
		rows = append(rows, ragRow{text: th, chunkType: "theme", importance: 0.5})
	}

	// Embed every row concurrently. generateEmbedding returns a zero
	// vector for empty text, so an empty summary still yields a
	// (neutral-ranking) anchor row rather than an error.
	embeddings := make([][]float32, len(rows))
	g, gctx := errgroup.WithContext(ctx)
	g.SetLimit(6)
	for i := range rows {
		i := i
		g.Go(func() error {
			emb, embErr := generateEmbedding(gctx, rows[i].text)
			if embErr != nil {
				return fmt.Errorf("embed %s row %d: %w", rows[i].chunkType, i, embErr)
			}
			embeddings[i] = emb
			return nil
		})
	}
	if err := g.Wait(); err != nil {
		return err
	}

	tx, err := dbPool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	for i, r := range rows {
		cipher, dek, encErr := crypto.Encrypt(ctx, []byte(r.text))
		if encErr != nil {
			return fmt.Errorf("encrypt %s: %w", r.chunkType, encErr)
		}
		if _, execErr := tx.Exec(ctx, `
			INSERT INTO rag_memories (patient_file_id, source_session_id, source_report_id,
				summary_ciphertext, summary_encrypted_dek, embedding,
				chunk_type, importance_score)
			VALUES ($1, $2, $3, $4, $5, $6::vector, $7, $8)`,
			session.PatientFileID, session.ID, repID,
			cipher, dek, vectorToString(embeddings[i]), r.chunkType, r.importance); execErr != nil {
			return execErr
		}
	}
	return tx.Commit(ctx)
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

// publishSessionStatusChanged mirrors a terminal transition to the unified
// `session.status_changed` topic (docs/21 Faza-4). [status] is the Firestore
// vocabulary — llm-worker emits "done" (terminal success → report-ready
// fan-out on the consumer) and "failed" (terminal error). NEVER call for a
// transient error that Pub/Sub will retry. Best-effort.
func publishSessionStatusChanged(ctx context.Context, sessionID, status string) error {
	if pubsubClient == nil {
		return nil
	}
	topic := pubsubClient.Publisher("session.status_changed")
	defer topic.Stop()
	payload, _ := json.Marshal(map[string]string{
		"session_id": sessionID,
		"status":     status,
	})
	res := topic.Publish(ctx, &pubsub.Message{
		Data: payload,
		Attributes: map[string]string{
			"event_type": "session.status_changed",
			"session_id": sessionID,
			"status":     status,
		},
	})
	_, err := res.Get(ctx)
	return err
}

// isTerminalLLMError decides whether a report-generation error will
// never succeed on retry (docs/21 §3.1 WS0C). Terminal: Vertex content/
// safety blocks and invalid-argument/schema rejections — retrying the
// same transcript+prompt gets the same rejection. Everything else
// (5xx / Unavailable / DeadlineExceeded / rate-limit / DB hiccup /
// truncated JSON) is transient and must retry. Default: transient — we
// over-retry rather than surface a false permanent failure to a user
// who has already lost the local audio.
func isTerminalLLMError(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	switch {
	case strings.Contains(msg, "safety"),
		strings.Contains(msg, "blocked"),
		strings.Contains(msg, "block_reason"),
		strings.Contains(msg, "content filter"),
		strings.Contains(msg, "prohibited"),
		strings.Contains(msg, "invalid_argument"),
		strings.Contains(msg, "invalidargument"),
		strings.Contains(msg, "failed_precondition"):
		return true
	}
	return false
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
