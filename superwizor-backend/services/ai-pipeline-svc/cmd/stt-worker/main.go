package sttworker

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"strconv"
	"strings"
	"time"

	kms "cloud.google.com/go/kms/apiv1"
	"cloud.google.com/go/pubsub/v2"
	speech "cloud.google.com/go/speech/apiv2"
	"cloud.google.com/go/speech/apiv2/speechpb"
	gcs "cloud.google.com/go/storage"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/cloudevents/sdk-go/v2/event"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/api/idtoken"
	"google.golang.org/api/option"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/oauth"
	grpcstatus "google.golang.org/grpc/status"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/pkg/cryptobox"
	"github.com/superwizor-ai/backend/pkg/i18n/lang"
	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/sttgcs"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/transcriptfmt"
)

// AudioUploadedEvent matches publisher payload
type AudioUploadedEvent struct {
	SessionID  string `json:"session_id"`
	UploadID   string `json:"upload_id"`
	ObjectPath string `json:"object_path"`
}

// MessagePublishedData matches the Pub/Sub CloudEvent payload data
type MessagePublishedData struct {
	Message PubSubMessage `json:"message"`
}

type PubSubMessage struct {
	Data       []byte            `json:"data"`
	Attributes map[string]string `json:"attributes"`
}

var (
	dbPool             *pgxpool.Pool
	speechClient       *speech.Client
	pubsubClient       *pubsub.Client
	gcsClient          *gcs.Client
	crypto             cryptobox.CryptoBox
	bucketName         string // audio uploads bucket (Chirp input source)
	transcriptsRawBkt  string // Chirp output destination (Stage 1)
	projectID          string
	billingClient      billingv1.BillingServiceClient // nil = billing hook disabled
)

func init() {
	ctx := context.Background()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	projectID = os.Getenv("GCP_PROJECT_ID")
	bucketName = os.Getenv("AUDIO_BUCKET_NAME")
	transcriptsRawBkt = os.Getenv("TRANSCRIPTS_RAW_BUCKET")
	dbDSN := os.Getenv("DATABASE_URL")
	kmsKeyURI := os.Getenv("KMS_KEY_URI")

	var err error
	if dbDSN != "" {
		// Bounded pool (see docs/17 §11). This binary runs in multiple
		// Cloud Functions (stt-worker / stt-finalize / stt-watchdog),
		// each scaling independently — single conn per instance keeps
		// the total under Cloud SQL's hard cap regardless of which
		// function is hot.
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
			slog.Error("db init", "error", err)
			os.Exit(1)
		}
	}

	if projectID != "" {
		// EU-only endpoint: dane nie opuszczają UE (Konstytucja §3)
		speechClient, err = speech.NewClient(ctx,
			option.WithEndpoint("eu-speech.googleapis.com:443"),
		)
		if err != nil {
			slog.Error("speech client", "error", err)
			os.Exit(1)
		}

		pubsubClient, err = pubsub.NewClient(ctx, projectID)
		if err != nil {
			slog.Error("pubsub client", "error", err)
			os.Exit(1)
		}

		// GCS client. Used by stt-finalize for downloading Chirp's
		// output JSON from the transcripts-raw bucket and by the
		// watchdog when manually driving a stuck finalize. Shared
		// across the three entry points in this package via the
		// gcsClient global.
		gcsClient, err = gcs.NewClient(ctx)
		if err != nil {
			slog.Error("gcs client", "error", err)
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

		// Billing client — optional. Set BILLING_SVC_URL to enable
		// CommitUsage call after STT finalize (fail-soft on errors).
		if billingURL := os.Getenv("BILLING_SVC_URL"); billingURL != "" {
			bc, bErr := newBillingClient(ctx, billingURL)
			if bErr != nil {
				slog.Error("billing client init failed", "url", billingURL, "error", bErr)
			} else {
				billingClient = bc
				slog.Info("stt-worker: billing-svc client wired", "url", billingURL)
			}
		} else {
			slog.Info("stt-worker: BILLING_SVC_URL unset — CommitUsage hook disabled")
		}
	} else {
		crypto = cryptobox.NewMockBox()
	}

	functions.CloudEvent("ProcessAudio", ProcessAudio)
}

func ProcessAudio(ctx context.Context, e event.Event) error {
	logger := slog.With("function", "stt-worker")

	var msgData MessagePublishedData
	if err := e.DataAs(&msgData); err != nil {
		logger.Error("failed to decode cloudevent data", "error", err)
		return err
	}

	var event AudioUploadedEvent
	if err := json.Unmarshal(msgData.Message.Data, &event); err != nil {
		logger.Warn("invalid event format, ignoring", "error", err, "data", string(msgData.Message.Data))
		return nil
	}

	if event.SessionID == "" || event.ObjectPath == "" {
		logger.Warn("missing session_id or object_path, ignoring event", "data", string(msgData.Message.Data))
		return nil
	}

	logger = logger.With("session_id", event.SessionID, "upload_id", event.UploadID)
	logger.Info("processing audio")

	// Poison-message guard. If the session is already in a terminal
	// state, a prior worker invocation already concluded (success or
	// permanent failure). Redelivery of the same Pub/Sub message
	// would just re-run Chirp on the same audio with the same result
	// — wasted spend and noise. ACK by returning nil.
	//
	// "FAILED" terminal-fail case (the b6c7a606 scenario from
	// 2026-05-14): first attempt set status=FAILED + returned error
	// → Pub/Sub redelivered for 24h without DLQ. Now: redelivery
	// sees FAILED → drops the message.
	// "COMPLETED" should never see a redelivery in practice
	// (transcript.completed has already been published, llm-worker
	// ran, report saved), but is included for symmetry.
	//
	// Non-terminal statuses ("", CREATED, TRANSCRIBING, ANALYZING)
	// fall through — TRANSCRIBING in particular means a previous
	// invocation crashed mid-flight before reaching FAILED/COMPLETED,
	// and we want the retry to make progress.
	if status, err := loadSessionStatus(ctx, event.SessionID); err != nil {
		logger.Warn("session status pre-check", "error", err)
	} else if status == "FAILED" || status == "COMPLETED" {
		logger.Warn("dropping poison redelivery — session already terminal",
			"prior_status", status,
			"hint", "manual admin path is to reset session.status before re-uploading audio")
		return nil
	}

	if err := updateSessionStatus(ctx, event.SessionID, "TRANSCRIBING"); err != nil {
		logger.Error("status update", "error", err)
		return err
	}
	// Mirror progress to the user (docs/21 §3.3, WS1B): the stepper
	// advances to step 3 instead of sitting on step 2 for the whole
	// (long) transcription then jumping to step 4. Best-effort.
	if perr := publishSessionStatusChanged(ctx, event.SessionID, "transcribing"); perr != nil {
		logger.Warn("publish session.status_changed(transcribing) failed", "error", perr)
	}

	// Resolve language from session.language_code (populated by
	// ingestion-svc.CompleteAudioUpload from patient_user.ui_language).
	// Empty means orphan session / pre-feat/llm-optimisation row →
	// fall back to multi-language auto-detect (preserves the old
	// behavior for legacy data).
	sessionLanguage, err := loadSessionLanguage(ctx, event.SessionID)
	if err != nil {
		logger.Warn("session language lookup", "error", err)
		sessionLanguage = ""
	}
	// BCP47-ize so callers can pass "pl" or "pl-PL"; both end up
	// "pl-PL" on the wire to Chirp.
	bcp47Lang := lang.BCP47ize(sessionLanguage)

	// Native diarization gate (ADR-IMPL-007). Two-key system:
	//   (a) operator opt-in via STT_NATIVE_DIARIZATION=on env var
	//       (legacy USE_NATIVE_DIARIZATION=true also accepted), AND
	//   (b) language is flagged true in
	//       transcriptfmt.Chirp3DiarizationLanguages.
	operatorOptIn := os.Getenv("STT_NATIVE_DIARIZATION") == "on" || os.Getenv("USE_NATIVE_DIARIZATION") == "true"
	useNativeDiarization := operatorOptIn && transcriptfmt.NativeDiarizationSupported(bcp47Lang)

	logger.Info("stt config",
		"session_language", sessionLanguage,
		"bcp47", bcp47Lang,
		"operator_opt_in", operatorOptIn,
		"native_diarization", useNativeDiarization)

	sessionUUID, err := uuid.Parse(event.SessionID)
	if err != nil {
		// Should never happen — sessionUUID came from a valid
		// CloudEvent payload — but defend defensively.
		return nil
	}

	// Stage 2: read audio_chunks for this upload. If ingestion-svc
	// ran the chunker (long audio path), N rows exist with
	// chunk_index 0..N-1. Otherwise synthesize a single virtual
	// chunk covering the whole upload (Stage 1 behavior).
	chunks, err := loadChunkPlan(ctx, event.UploadID, event.ObjectPath)
	if err != nil {
		logger.Warn("loadChunkPlan failed; falling back to single virtual chunk",
			"error", err)
		chunks = []ChunkPlan{{
			ChunkIndex:    0,
			GCSUri:        fmt.Sprintf("gs://%s/%s", bucketName, event.ObjectPath),
			StartOffsetMS: 0,
		}}
	}
	logger.Info("chunk plan loaded",
		"chunk_count", len(chunks),
		"upload_id", event.UploadID)

	// Pre-flight: skip chunks already submitted by a prior (now-
	// redelivered) Pub/Sub event. Eliminates the common case of
	// re-billing Chirp on every retry. The UNIQUE constraint on
	// (session_id, chunk_index) is the second-line defense for the
	// true-concurrency race that this SELECT can't close.
	submitted, err := loadSubmittedChunks(ctx, sessionUUID)
	if err != nil {
		logger.Warn("pre-flight loadSubmittedChunks failed; proceeding without skip", "error", err)
		submitted = map[int]bool{}
	}

	for _, ch := range chunks {
		if submitted[ch.ChunkIndex] {
			logger.Info("chunk already submitted; skipping",
				"chunk_index", ch.ChunkIndex)
			continue
		}
		outputPrefix := fmt.Sprintf("gs://%s/%s",
			transcriptsRawBkt,
			sttgcs.OutputPrefixFor(sessionUUID, ch.ChunkIndex))

		opName, err := submitBatchRecognize(ctx, ch.GCSUri, outputPrefix, bcp47Lang, useNativeDiarization)
		if err != nil {
			// Terminal errors (e.g. malformed request, IAM denied)
			// ack and stop; transient errors return non-nil and
			// Pub/Sub retries.
			return handleSTTError(ctx, logger, event.SessionID, err)
		}

		insertErr := insertSTTOperation(ctx, insertSTTOpParams{
			SessionID:             sessionUUID,
			ChunkIndex:            ch.ChunkIndex,
			ChunkCount:            len(chunks),
			StartOffsetMS:         ch.StartOffsetMS,
			OperationID:           opName,
			GCSOutputURI:          outputPrefix,
			LanguageCode:          bcp47Lang,
			UsedNativeDiarization: useNativeDiarization,
		})
		if insertErr != nil {
			if isUniqueViolation(insertErr) {
				// Race: another worker INSERTed first. Our
				// BatchRecognize call already submitted an operation
				// to Chirp — that's a small, accepted cost. Their
				// row is the canonical one; OBJECT_FINALIZE on our
				// orphan output will be a no-op (RowsAffected = 0).
				logger.Warn("submit race; another worker won the chunk",
					"chunk_index", ch.ChunkIndex,
					"orphan_operation_id", opName)
				continue
			}
			return handleSTTError(ctx, logger, event.SessionID, insertErr)
		}

		slog.InfoContext(ctx, "analytics",
			"ae", "stt.submitted",
			"session_id", event.SessionID,
			"language_code", bcp47Lang,
			"native_diarization", useNativeDiarization,
			"chunk_count", len(chunks),
		)

		logger.Info("submitted",
			"chunk_index", ch.ChunkIndex,
			"operation_id", opName,
			"output_prefix", outputPrefix,
			"chunk_count", len(chunks))
	}

	// Pub/Sub acks. Chirp does its work async; the result lands in
	// gs://transcriptsRawBkt/{session_id}/chunk_{i}/transcript_*.json
	// and OBJECT_FINALIZE triggers stt-finalize (ProcessTranscriptObject)
	// from finalize.go in this same package.
	return nil
}

// ChunkPlan describes one BatchRecognize submission target.
//
// Stage 1: a single ChunkPlan covering the whole audio_upload
// object (StartOffsetMS=0). Synthesized when audio_chunks is empty.
//
// Stage 2: one ChunkPlan per audio_chunks row when ingestion-svc
// ran the ffmpeg silence-detect chunker (long audio path).
type ChunkPlan struct {
	ChunkIndex    int
	GCSUri        string // gs://bucket/path of the audio file
	StartOffsetMS int64  // chunk's start in the ORIGINAL audio timeline
	SeamOffsetMS  int64  // logical cut point shared with chunk_{i+1}; 0 for the virtual chunk
	EndOffsetMS   int64  // chunk's end in the ORIGINAL audio timeline; 0 for the virtual chunk
	OverlapMS     int    // overlap with prior chunk; 0 for chunk 0
}

// loadChunkPlan returns the BatchRecognize fan-out plan for this
// audio_upload. When ingestion-svc ran the Stage 2 chunker, the
// audio_chunks table has one row per chunk; otherwise empty and we
// synthesize a single virtual chunk pointing at the original
// audio_uploads object_path.
//
// Both paths are correct and observationally indistinguishable to
// the caller; the consumer just gets a different `len(chunks)`.
func loadChunkPlan(ctx context.Context, uploadIDStr string, fallbackObjectPath string) ([]ChunkPlan, error) {
	if dbPool == nil {
		return defaultChunkPlan(fallbackObjectPath), nil
	}
	uploadID, err := uuid.Parse(uploadIDStr)
	if err != nil {
		return defaultChunkPlan(fallbackObjectPath), nil
	}

	rows, err := dbPool.Query(ctx, `
		SELECT chunk_index, bucket_name, object_path,
		       start_offset_ms, seam_offset_ms, end_offset_ms, overlap_ms
		FROM audio_chunks
		WHERE audio_upload_id = $1
		ORDER BY chunk_index`,
		uploadID)
	if err != nil {
		return nil, fmt.Errorf("query audio_chunks: %w", err)
	}
	defer rows.Close()

	var out []ChunkPlan
	for rows.Next() {
		var (
			idx                                int32
			bkt, obj                           string
			start, seam, end                   int64
			overlap                            int32
		)
		if err := rows.Scan(&idx, &bkt, &obj, &start, &seam, &end, &overlap); err != nil {
			return nil, fmt.Errorf("scan audio_chunks: %w", err)
		}
		out = append(out, ChunkPlan{
			ChunkIndex:    int(idx),
			GCSUri:        fmt.Sprintf("gs://%s/%s", bkt, obj),
			StartOffsetMS: start,
			SeamOffsetMS:  seam,
			EndOffsetMS:   end,
			OverlapMS:     int(overlap),
		})
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	if len(out) == 0 {
		return defaultChunkPlan(fallbackObjectPath), nil
	}
	return out, nil
}

// defaultChunkPlan synthesizes the Stage 1 single-virtual-chunk
// plan: one ChunkPlan over the entire audio_upload object. Used
// when audio_chunks has no rows for this upload (short audio,
// pre-Stage 2 sessions, or DB unavailable).
func defaultChunkPlan(objectPath string) []ChunkPlan {
	return []ChunkPlan{{
		ChunkIndex:    0,
		GCSUri:        fmt.Sprintf("gs://%s/%s", bucketName, objectPath),
		StartOffsetMS: 0,
	}}
}

// TranscriptResult zawiera płaską listę słów (bez speaker_tag w default flow).
// Gdy USE_NATIVE_DIARIZATION=true, Word.SpeakerTag wypełnione przez Chirp 3.
type TranscriptResult struct {
	Words                []chunker.Word
	LanguageCode         string
	WordCount            int
	ConfidenceAvg        float32
	HasNativeDiarization bool
	SpeakerCount         int
}

// transcribeAudio wywołuje Chirp 3 BatchRecognize.
//
// languageCode: when non-empty, pinned as the single recognized
// language (e.g. "pl-PL"). Empty falls back to the legacy
// multi-language auto-detect list — used when session.language_code
// wasn't set (orphan rows / pre-feat/llm-optimisation sessions) so
// the worker still produces useful output.
//
// useNativeDiarization: gated upstream by operator opt-in AND the
// Chirp3DiarizationLanguages allow-list. When true, Chirp emits
// per-word speaker_tag; when false (current default for every
// language), words come back flat and llm-worker clusters them.
// submitBatchRecognize fires a BatchRecognize call to Chirp 3 with
// GcsOutputConfig pointing at outputPrefix. Returns the long-running
// operation's name (used as a handle by the watchdog) without
// waiting for the operation to complete — the result will land in
// GCS at outputPrefix and OBJECT_FINALIZE will trigger stt-finalize.
//
// Replaces the old transcribeAudio path which used
// InlineResponseConfig + op.Wait(ctx). The wait coupled Cloud
// Function runtime to Chirp's latency; with the GCS callback model
// the worker hangs up immediately and the result-handling is
// asynchronous. See docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md.
//
// outputPrefix is a `gs://bucket/{sid}/chunk_{i}/` URI; Chirp picks
// the filename inside it.
func submitBatchRecognize(
	ctx context.Context,
	gcsURI string,
	outputPrefix string,
	languageCode string,
	useNativeDiarization bool,
) (operationName string, err error) {
	features := &speechpb.RecognitionFeatures{
		EnableAutomaticPunctuation: true,
		EnableWordTimeOffsets:      true,
	}

	if useNativeDiarization {
		features.DiarizationConfig = &speechpb.SpeakerDiarizationConfig{
			MinSpeakerCount: 2,
			MaxSpeakerCount: 4,
		}
	}

	// Language list: pinned single language when known (cleaner Chirp
	// behavior, fewer mis-detections), multi-list fallback otherwise.
	// Multi-list intentionally includes uk-UA because Polish therapy
	// occasionally hits Ukrainian-speaking patients post-2022, and
	// we'd rather Chirp pick the right one than misroute pl-PL.
	var languageCodes []string
	if languageCode != "" {
		languageCodes = []string{languageCode}
	} else {
		languageCodes = []string{"pl-PL", "en-US", "de-DE", "uk-UA"}
	}

	req := &speechpb.BatchRecognizeRequest{
		Recognizer: fmt.Sprintf("projects/%s/locations/eu/recognizers/_", projectID),
		// Dynamic batching = the "Standard dynamic batch recognition"
		// pricing tier ($0.003/min vs ~$0.016/min for standard batch —
		// ~5× cheaper, and STT is ~58% of GCP spend). The trade is no
		// latency SLA: Chirp runs the job when capacity frees up rather
		// than ASAP. Our pipeline is fully async and tolerates this —
		// stt-finalize is triggered by the GCS OBJECT_FINALIZE of Chirp's
		// output, and stt-watchdog idempotently RE-POLLS the existing
		// operation by ID (never resubmits, never fails on duration), so
		// a slower job is just re-checked each tick with no double-charge.
		// Without this field the request defaults to
		// PROCESSING_STRATEGY_UNSPECIFIED = the pricier standard-batch rate.
		ProcessingStrategy: speechpb.BatchRecognizeRequest_DYNAMIC_BATCHING,
		Config: &speechpb.RecognitionConfig{
			DecodingConfig: &speechpb.RecognitionConfig_AutoDecodingConfig{
				AutoDecodingConfig: &speechpb.AutoDetectDecodingConfig{},
			},
			Model:         "chirp_3",
			LanguageCodes: languageCodes,
			Features:      features,
		},
		Files: []*speechpb.BatchRecognizeFileMetadata{
			{AudioSource: &speechpb.BatchRecognizeFileMetadata_Uri{Uri: gcsURI}},
		},
		RecognitionOutputConfig: &speechpb.RecognitionOutputConfig{
			Output: &speechpb.RecognitionOutputConfig_GcsOutputConfig{
				GcsOutputConfig: &speechpb.GcsOutputConfig{
					Uri: outputPrefix,
				},
			},
		},
	}

	op, err := speechClient.BatchRecognize(ctx, req)
	if err != nil {
		return "", fmt.Errorf("batch recognize: %w", err)
	}
	// No op.Wait(ctx). Chirp will write the result to outputPrefix
	// and OBJECT_FINALIZE will pick up the work in stt-finalize.
	return op.Name(), nil
}

// ParseChirp3Results extracts words and confidence from the Speech API response.
// Słowa są zwracane bez speaker_tag (default flow) — chunker je zgrupuje.
//
// fallbackLanguage is the language we pinned in the recognize request
// (e.g. "en-US"). Chirp returns the actually-detected language per
// SpeechRecognitionResult.LanguageCode — first non-empty value wins.
// We fall back to fallbackLanguage only when none of the result rows
// carry a language (multi-detect mode with empty input, or older API
// responses). The hardcoded "pl-PL" that this function used to default
// to was a Polish-only-era leftover that silently overwrote
// session.language_code on every transcribe — fixed 2026-05-14.
//
// Returns an error if any file-level result has a non-nil Error status. We
// always submit a single file per BatchRecognize call (one audio upload per
// session), so any file-level error means transcription failed and the
// caller should not proceed with a "successful but empty" TranscriptResult.
// This prevents the silent-failure path where Chirp 3 rejects the codec
// (e.g. M4A/AAC), the response carries an INTERNAL/INVALID_ARGUMENT
// per-file Error, and ProcessAudio would otherwise see WordCount=0 and
// keep going.
func ParseChirp3Results(resp *speechpb.BatchRecognizeResponse, useNativeDiarization bool, fallbackLanguage string) (*TranscriptResult, error) {
	result := &TranscriptResult{
		HasNativeDiarization: useNativeDiarization,
	}
	speakerSet := map[string]bool{}
	totalConfidence := float32(0)
	confidenceCount := 0

	// Collect every file-level error so the message names all failing
	// inputs at once (useful if/when we ever batch multiple files).
	var fileErrors []string

	for fileKey, fileResult := range resp.Results {
		if errStatus := fileResult.GetError(); errStatus != nil {
			fileErrors = append(fileErrors,
				fmt.Sprintf("%s: code=%d %s", fileKey, errStatus.Code, errStatus.Message))
			slog.Error("Speech-to-Text returned an error for file",
				"file", fileKey,
				"code", errStatus.Code,
				"message", errStatus.Message)
			continue
		}

		inline := fileResult.GetInlineResult()
		if inline == nil || inline.GetTranscript() == nil {
			continue
		}
		for _, r := range inline.GetTranscript().Results {
			if len(r.Alternatives) == 0 {
				continue
			}
			alt := r.Alternatives[0]

			// Capture the actually-detected language. Chirp populates
			// this per result; first non-empty value wins (results
			// within one file share a language). If Chirp didn't set
			// it for any result we fall back to the pinned language
			// after the loop.
			if result.LanguageCode == "" && r.LanguageCode != "" {
				result.LanguageCode = r.LanguageCode
			}

			for _, w := range alt.Words {
				word := chunker.Word{
					Text:       w.Word,
					StartMS:    w.StartOffset.AsDuration().Milliseconds(),
					EndMS:      w.EndOffset.AsDuration().Milliseconds(),
					Confidence: w.Confidence,
				}
				if useNativeDiarization {
					// Propagate Chirp's per-word speaker label so the
					// chunker can preserve attribution. Without this,
					// downstream BlobLines lose speaker_tag and llm-
					// worker falls back to LLM clustering even on
					// languages where Chirp diarized successfully.
					// Empty label is allowed (Chirp can skip labeling
					// some words, e.g. cross-speaker filler).
					word.SpeakerLabel = w.SpeakerLabel
					if w.SpeakerLabel != "" {
						speakerSet[w.SpeakerLabel] = true
					}
				}
				result.Words = append(result.Words, word)
				result.WordCount++
			}

			if alt.Confidence > 0 {
				totalConfidence += alt.Confidence
				confidenceCount++
			}
		}
	}

	if confidenceCount > 0 {
		result.ConfidenceAvg = totalConfidence / float32(confidenceCount)
	}
	result.SpeakerCount = len(speakerSet)

	// Fallback for the case where Chirp didn't populate LanguageCode
	// on any result (multi-detect with no recognized words, or older
	// API responses). Use whatever we pinned in the request; empty
	// stays empty so updateSessionLanguage's guard kicks in.
	if result.LanguageCode == "" {
		result.LanguageCode = fallbackLanguage
	}

	if len(fileErrors) > 0 {
		// Common causes:
		//   - Codec not supported by Chirp 3 (e.g. M4A/AAC; use FLAC, WAV-LINEAR16, OGG-OPUS).
		//   - Sample rate outside [8000, 48000] Hz.
		//   - Audio file fundamentally unreadable.
		// Returning an error fails the session loud instead of silently
		// producing an empty transcript that triggers downstream LLM noise.
		return result, fmt.Errorf("chirp 3 returned %d file-level error(s): %s",
			len(fileErrors), strings.Join(fileErrors, "; "))
	}

	return result, nil
}

// fillSpeakerLabels propagates per-word SpeakerLabels into adjacent
// unlabeled words. Chirp 3 native diarization is reliable on labeling
// the more dominant / longer-speaking speaker but routinely drops
// labels on the other speaker's words and on filler / short
// interjections (observed empirically on session 26ecf316 — 100 of 295
// words returned label=""). The chunker treats label="" as a separate
// "speaker" from label="1"/"2", so unlabeled runs become orphan
// tag=0 chunks that the downstream LLM role-only path can't reattach.
//
// Algorithm: forward pass propagates the most recently seen label
// forward into contiguous unlabeled words; backward pass does the
// same for leading unlabeled words (case where Chirp didn't label
// anyone until the second speaker's first turn). Both passes are
// bounded by maxGapMS — if there's a pause >= the chunker's pause
// threshold between the last labeled word and the current one, we
// stop propagating. Pauses are the only signal we have that the
// speaker may have changed, so crossing them silently would be the
// classic "fix one bug, introduce another" trap.
//
// Mutates words in place. No-op when len(words) == 0.
func fillSpeakerLabels(words []chunker.Word, maxGapMS int64) {
	if len(words) == 0 {
		return
	}

	// Forward pass.
	lastLabel := ""
	var lastEndMS int64 = -1
	for i := range words {
		if words[i].SpeakerLabel != "" {
			lastLabel = words[i].SpeakerLabel
			lastEndMS = words[i].EndMS
			continue
		}
		if lastLabel == "" {
			continue
		}
		if lastEndMS >= 0 && words[i].StartMS-lastEndMS > maxGapMS {
			// Pause boundary crossed — speaker may have changed; stop
			// propagating until we see another labeled word.
			lastLabel = ""
			continue
		}
		words[i].SpeakerLabel = lastLabel
		lastEndMS = words[i].EndMS
	}

	// Backward pass for leading unlabeled words.
	nextLabel := ""
	var nextStartMS int64 = -1
	for i := len(words) - 1; i >= 0; i-- {
		if words[i].SpeakerLabel != "" {
			nextLabel = words[i].SpeakerLabel
			nextStartMS = words[i].StartMS
			continue
		}
		if nextLabel == "" {
			continue
		}
		if nextStartMS >= 0 && nextStartMS-words[i].EndMS > maxGapMS {
			nextLabel = ""
			continue
		}
		words[i].SpeakerLabel = nextLabel
		nextStartMS = words[i].StartMS
	}
}

// isTerminalSTTError classifies an error from the STT pipeline as
// "no point retrying" vs "should retry per Pub/Sub policy".
//
// Terminal (return nil from handler → Pub/Sub acks → no retry):
//   - InvalidArgument: bad codec, malformed audio header, wrong sample
//     rate. Chirp will keep rejecting on every retry.
//   - OutOfRange: file size or duration outside Chirp limits.
//   - NotFound: GCS object missing (OLM 48h already deleted it, or a
//     race where the user retried CompleteAudioUpload after the object
//     was GCed).
//   - PermissionDenied / Unauthenticated: SA can't read the bucket;
//     retrying doesn't fix IAM.
//   - File-level errors from ParseChirp3Results carrying any of the
//     above status strings (Chirp sometimes embeds the status as text
//     inside a BatchRecognize success envelope).
//
// Retryable (return the error → Pub/Sub retries per topic policy):
//   - Internal / Unavailable: Chirp 5xx, network blips, Cloud SQL
//     hiccups, KMS transient.
//   - DeadlineExceeded: caller-side timeout; Pub/Sub retry gets a fresh
//     deadline.
//   - Anything not on the terminal allowlist (default to retry — we'd
//     rather over-retry a transient than under-retry a real failure).
//
// Before this helper landed (2026-05-20), every error path returned
// non-nil. The poison-message guard at the top of ProcessAudio caught
// most repeats by reading sessions.status, but the first attempt's
// FAILED status had to land before retries started, which doesn't help
// when the first attempt itself crashes before updateSessionStatus.
// The terminal-ack path closes that gap.
func isTerminalSTTError(err error) bool {
	if err == nil {
		return false
	}
	// gRPC code on the wrapped chain. errors.As via FromError unwraps
	// any %w-wrapped grpc error and surfaces the code; direct grpc
	// errors are matched too.
	if s, ok := grpcstatus.FromError(err); ok {
		switch s.Code() {
		case codes.InvalidArgument,
			codes.OutOfRange,
			codes.NotFound,
			codes.PermissionDenied,
			codes.Unauthenticated:
			return true
		}
	}
	// String fallback for file-level errors from ParseChirp3Results.
	// Chirp's BatchRecognizeFileResult.Error is a google.rpc.Status that
	// we stringify into the wrapped message; pattern-match the known
	// terminal signatures.
	msg := err.Error()
	switch {
	case strings.Contains(msg, "chirp 3 returned"):
		// File-level error always means "this specific input is bad" —
		// retrying with the same input gets the same result. Terminal.
		return true
	case strings.Contains(msg, "INVALID_ARGUMENT"),
		strings.Contains(msg, "invalid_argument"),
		strings.Contains(msg, "unsupported codec"),
		strings.Contains(msg, "Unsupported audio"),
		strings.Contains(msg, "audio is too long"),
		strings.Contains(msg, "audio is too short"):
		return true
	}
	return false
}

// handleSTTError centralizes the FAILED-write + ack-or-retry decision
// for any error during transcription. Marks the session FAILED
// regardless (best-effort; idempotent write to sessions.status), then
// returns either nil (ack — terminal) or the original error (retry —
// transient).
//
// Returning the original `err` preserves stack/message for Cloud
// Logging at the function framework layer.
func handleSTTError(ctx context.Context, logger *slog.Logger, sessionID string, err error) error {
	// Analityka: stt.failed
	langCode := ""
	if ulang, errLang := loadSessionLanguage(ctx, sessionID); errLang == nil {
		langCode = lang.BCP47ize(ulang)
	}
	errorCategory := "transient"
	if isTerminalSTTError(err) {
		errorCategory = "terminal"
	}
	slog.InfoContext(ctx, "analytics",
		"ae", "stt.failed",
		"session_id", sessionID,
		"error_category", errorCategory,
		"language_code", langCode,
		"error", err.Error(),
	)

	if isTerminalSTTError(err) {
		// Terminal — this input will never succeed. Mark FAILED, mirror
		// to the user (docs/21: authoritative-FAILED source #1), ack so
		// Pub/Sub stops retrying.
		_ = updateSessionStatus(ctx, sessionID, "FAILED")
		if perr := publishSessionStatusChanged(ctx, sessionID, "failed"); perr != nil {
			logger.Warn("stt: publish session.status_changed(failed) failed", "error", perr)
		}
		releaseBillingCredit(ctx, sessionID, "STT_FAILED")
		logger.Error("stt: terminal failure — FAILED + acking pubsub, no retry",
			"error", err,
			"hint", "check audio codec (Chirp 3 accepts FLAC/WAV/OGG/AMR; M4A must be transcoded via ingestion-svc.ConvertAudio before CompleteAudioUpload)")
		return nil
	}
	// Transient (Chirp 5xx / Unavailable / deadline / network). Do NOT
	// write FAILED and do NOT publish — that would flash a permanent
	// failure to the user for audio they can no longer re-process
	// (docs/21 §2.2). Leave the session in its in-progress status and
	// NACK so Pub/Sub retries within the ~24h window; the DLQ give-up
	// reaper surfaces FAILED only if retries are genuinely exhausted.
	logger.Error("stt: transient failure — status left in-progress, pubsub will retry",
		"error", err)
	return err
}

// newBillingClient — same pattern as ingestion-svc + clinical-svc.
// Cloud Run service-to-service OIDC token via idtoken.NewTokenSource.
func newBillingClient(ctx context.Context, serviceURL string) (billingv1.BillingServiceClient, error) {
	tokenSource, err := idtoken.NewTokenSource(ctx, serviceURL)
	if err != nil {
		return nil, fmt.Errorf("idtoken: %w", err)
	}
	// Strip scheme + add :443
	target := strings.TrimPrefix(strings.TrimPrefix(serviceURL, "https://"), "http://")
	target = strings.TrimSuffix(target, "/")
	if !strings.Contains(target, ":") {
		target += ":443"
	}
	conn, err := grpc.NewClient(target,
		grpc.WithTransportCredentials(credentials.NewTLS(nil)),
		grpc.WithPerRPCCredentials(oauth.TokenSource{TokenSource: tokenSource}),
	)
	if err != nil {
		return nil, fmt.Errorf("dial: %w", err)
	}
	return billingv1.NewBillingServiceClient(conn), nil
}

// commitBillingUsageAsync — fire-and-forget bills 1 session's tokens.
// Loads duration_seconds from session row (set by ingestion finalize),
// then calls billing-svc.CommitUsage. Idempotent po session_id na backendzie
// (UNIQUE constraint), więc retry safe.
//
// Resolves organization_id z users table. Loguje + swallowuje errors.
func commitBillingUsageAsync(sessionIDStr string) {
	if billingClient == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	logger := slog.With("function", "stt-worker", "session_id", sessionIDStr)

	var duration *int32
	var therapistID, orgID string
	err := dbPool.QueryRow(ctx, `
		SELECT s.duration_seconds, s.therapist_id::text, COALESCE(u.organization_id::text, '')
		FROM sessions s
		JOIN users u ON u.id = s.therapist_id
		WHERE s.id = $1`, sessionIDStr).Scan(&duration, &therapistID, &orgID)
	if err != nil {
		logger.Warn("billing commit: lookup failed", "error", err)
		return
	}
	if orgID == "" {
		logger.Info("billing commit: user has no org (skipping)")
		return
	}
	if duration == nil || *duration <= 0 {
		logger.Info("billing commit: session has no duration (skipping)")
		return
	}

	_, err = billingClient.CommitUsage(ctx, &billingv1.CommitUsageRequest{
		SessionId:       sessionIDStr,
		OrganizationId:  orgID,
		TherapistId:     therapistID,
		DurationSeconds: *duration,
		UsageType:       "session_analysis",
		IdempotencyKey:  "stt-commit-" + sessionIDStr,
	})
	if err != nil {
		logger.Warn("billing commit: CommitUsage failed (fail-soft)", "error", err, "duration_seconds", *duration)
		return
	}
	logger.Info("billing commit: tokens committed", "duration_seconds", *duration)
}

// releaseBillingCredit releases the held reservation for a session that
// failed terminally (or is being given up on), so the token returns to
// the org promptly instead of waiting out the 26h reservation TTL
// (docs/21 WS0E/WS2A). Synchronous + best-effort: must run before the
// handler returns (Cloud Functions may freeze the instance after), so we
// don't background it; resolves org_id and fires ReleaseCredit, logging
// on failure. Idempotent on the billing side (no-op if already released
// / expired).
func releaseBillingCredit(ctx context.Context, sessionIDStr, reason string) {
	if billingClient == nil || dbPool == nil {
		return
	}
	logger := slog.With("function", "stt-worker", "session_id", sessionIDStr)

	var orgID string
	err := dbPool.QueryRow(ctx, `
		SELECT COALESCE(u.organization_id::text, '')
		FROM sessions s
		JOIN users u ON u.id = s.therapist_id
		WHERE s.id = $1`, sessionIDStr).Scan(&orgID)
	if err != nil {
		logger.Warn("billing release: lookup failed", "error", err)
		return
	}
	if orgID == "" {
		return
	}
	if _, rerr := billingClient.ReleaseCredit(ctx, &billingv1.ReleaseCreditRequest{
		SessionId:      sessionIDStr,
		OrganizationId: orgID,
		Reason:         reason,
	}); rerr != nil {
		logger.Warn("billing release: ReleaseCredit failed (fail-soft)", "error", rerr)
		return
	}
	logger.Info("billing release: token released", "reason", reason)
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

// loadSessionStatus reads sessions.status. Used as the poison-
// message guard at ProcessAudio entry. Returns "" on missing row or
// DB unavailable (the caller treats empty as "proceed normally" so
// we never block legitimate first-time processing on a transient DB
// hiccup). Non-fatal — we'd rather over-process than silently drop.
func loadSessionStatus(ctx context.Context, sessionID string) (string, error) {
	if dbPool == nil {
		return "", nil
	}
	id, err := uuid.Parse(sessionID)
	if err != nil {
		return "", err
	}
	var status string
	err = dbPool.QueryRow(ctx,
		"SELECT status FROM sessions WHERE id = $1",
		id).Scan(&status)
	if err != nil {
		return "", err
	}
	return status, nil
}

// loadSessionLanguage reads session.language_code (BCP47 tag like
// "pl-PL") set by ingestion-svc.CompleteAudioUpload at session create.
// Empty string means the row is NULL — caller falls back to
// multi-language auto-detect. Non-fatal errors (DB down, row not
// found) also return "" so the worker degrades gracefully rather
// than failing the whole STT call.
func loadSessionLanguage(ctx context.Context, sessionID string) (string, error) {
	if dbPool == nil {
		return "", nil
	}
	id, err := uuid.Parse(sessionID)
	if err != nil {
		return "", err
	}
	var languageCode *string
	err = dbPool.QueryRow(ctx,
		"SELECT language_code FROM sessions WHERE id = $1",
		id).Scan(&languageCode)
	if err != nil {
		return "", err
	}
	if languageCode == nil {
		return "", nil
	}
	return *languageCode, nil
}

// updateSessionLanguage zapisuje wykryty/użyty language_code dla sesji.
// speaker_label_mapping zostaje pusty {} — zostanie wypełniony przez
// llm-worker.generateAndSaveSpeakerLabels po analizie LLM.
//
// Idempotency: when session.language_code was already populated by
// ingestion-svc (the common case post-feat/llm-optimisation), this
// just overwrites with the same value. Harmless. We keep the write
// for two reasons: (a) record what Chirp actually used, including
// the multi-detect fallback path where the input language was
// unknown; (b) backwards compatibility with reports / dashboards
// that read this column after STT.
func updateSessionLanguage(ctx context.Context, sessionID string, languageCode string) error {
	if dbPool == nil {
		return nil
	}
	id, err := uuid.Parse(sessionID)
	if err != nil {
		return err
	}
	_, err = dbPool.Exec(ctx,
		"UPDATE sessions SET language_code = $1 WHERE id = $2",
		languageCode, id)
	return err
}

// BlobLine to pojedynczy wpis w kanonicznym blob'ie transkryptu (ADR-IMPL-006).
// W default flow (USE_NATIVE_DIARIZATION=false) chunki nie mają speaker_tag/label —
// LLM przypisze je w Sprint 2.6. Pola speaker_* są wypełniane tylko gdy
// native diarization jest aktywna (przyszła ścieżka).
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

// logPlaintextTranscript dumps the raw transcript text to the structured
// log for development debugging. Output is split across multiple log
// entries to stay under Cloud Logging's 256 KB per-entry limit.
//
// **PHI EXPOSURE WARNING** — gated by env var DEV_LOG_PLAINTEXT_TRANSCRIPT
// in the caller. Never enable on a function instance that processes real
// patient audio.
func logPlaintextTranscript(logger *slog.Logger, sessionID string, result *TranscriptResult, chunks []chunker.Chunk) {
	logger.Warn("DEV_LOG_PLAINTEXT_TRANSCRIPT=true — dumping plaintext transcript (PHI EXPOSURE)",
		"session_id", sessionID,
		"language", result.LanguageCode,
		"word_count", result.WordCount,
		"chunk_count", len(chunks))

	if result.WordCount == 0 {
		logger.Warn("dev-plaintext: Chirp 3 returned no words; nothing to dump",
			"session_id", sessionID)
		return
	}

	// Per-chunk lines — each chunk is its own log entry, so we get
	// per-chunk timing + confidence in the structured payload.
	for _, c := range chunks {
		logger.Info("dev-plaintext-chunk",
			"session_id", sessionID,
			"chunk_idx", c.Index,
			"start_ms", c.StartMS,
			"end_ms", c.EndMS,
			"word_count", c.WordCount,
			"confidence", c.Confidence,
			"text", c.Text)
	}

	// Compact summary on a single line so it's grep-friendly in
	// `gcloud logging read`. Truncate at 8 KB to keep one entry small;
	// per-chunk entries above carry the full content.
	const maxSummary = 8 * 1024
	var b strings.Builder
	for _, c := range chunks {
		fmt.Fprintf(&b, "[%d] %s ", c.Index, c.Text)
		if b.Len() > maxSummary {
			b.WriteString("…(truncated)")
			break
		}
	}
	logger.Info("dev-plaintext-summary",
		"session_id", sessionID,
		"text", b.String())
}

// persistTranscript zapisuje:
//  1. KANONICZNY blob w transcripts.transcript_ciphertext — JSON z chunkami.
//  2. Per-chunk placeholder w transcript_segments (speaker_tag=0, speaker_label="")
//     — llm-worker zaktualizuje labels po dedukcji ról.
//
// Zob. ADR-IMPL-006 (blob jako source of truth) i ADR-IMPL-007 (LLM diarization).
func persistTranscript(ctx context.Context, sessionID string, result *TranscriptResult, chunks []chunker.Chunk, processingTime time.Duration) (string, error) {
	transcriptID := uuid.New()
	sessID, err := uuid.Parse(sessionID)
	if err != nil {
		return "", err
	}

	blobLines := make([]BlobLine, 0, len(chunks))
	for _, c := range chunks {
		bl := BlobLine{
			ChunkIdx:   c.Index,
			Text:       c.Text,
			StartMS:    c.StartMS,
			EndMS:      c.EndMS,
			WordCount:  c.WordCount,
			Confidence: c.Confidence,
		}
		// Propagate speaker attribution from STT-native diarization.
		// Chirp returns SpeakerLabel as a numeric string ("1", "2",
		// ...); we store both the integer SpeakerTag (for downstream
		// llm-worker.generateAndSaveSpeakerLabels which keys on tags)
		// and the raw SpeakerLabel (for debugging / future Chirp
		// label-format changes). Parse-failure → log a warning and
		// emit SpeakerTag=0, which downstream treats as "no native
		// diarization" — degrades to LLM clustering rather than
		// silently corrupting the attribution.
		if c.SpeakerLabel != "" {
			label := c.SpeakerLabel
			bl.SpeakerLabel = &label
			if tag, err := strconv.Atoi(c.SpeakerLabel); err == nil {
				t := int32(tag)
				bl.SpeakerTag = &t
			} else {
				slog.Warn("non-numeric Chirp speaker label; speaker_tag left nil — chunk will route to LLM clustering",
					"chunk_idx", c.Index, "speaker_label", c.SpeakerLabel)
			}
		}
		blobLines = append(blobLines, bl)
	}

	blobJSON, err := json.Marshal(blobLines)
	if err != nil {
		return "", fmt.Errorf("marshal blob: %w", err)
	}

	blobCiphertext, blobDEK, err := crypto.Encrypt(ctx, blobJSON)
	if err != nil {
		return "", fmt.Errorf("encrypt blob: %w", err)
	}

	if dbPool == nil {
		return transcriptID.String(), nil
	}
	tx, err := dbPool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	_, err = tx.Exec(ctx, `
		INSERT INTO transcripts (
			id, session_id, transcript_ciphertext, transcript_encrypted_dek,
			language_code, word_count, speaker_count, confidence_avg,
			stt_model, stt_processing_seconds
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		transcriptID, sessID, blobCiphertext, blobDEK,
		result.LanguageCode, result.WordCount, result.SpeakerCount,
		result.ConfidenceAvg, "chirp_3", int(processingTime.Seconds()))
	if err != nil {
		return "", err
	}

	// Per-chunk placeholder w transcript_segments.
	// speaker_tag=0, speaker_label="" zostaną nadpisane przez llm-worker
	// po analizie ról. Kolejność (ORDER BY start_offset_ms) odpowiada chunk_idx.
	for _, c := range chunks {
		segID := uuid.New()
		segCiphertext, segDEK, err := crypto.Encrypt(ctx, []byte(c.Text))
		if err != nil {
			return "", fmt.Errorf("encrypt segment: %w", err)
		}

		_, err = tx.Exec(ctx, `
			INSERT INTO transcript_segments (
				id, transcript_id, speaker_tag, speaker_label,
				start_offset_ms, end_offset_ms,
				text_ciphertext, text_encrypted_dek,
				text_word_count, confidence
			) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
			segID, transcriptID,
			int32(0), "",
			c.StartMS, c.EndMS,
			segCiphertext, segDEK,
			c.WordCount, c.Confidence)
		if err != nil {
			return "", err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return "", err
	}

	return transcriptID.String(), nil
}

func publishTranscriptCompleted(ctx context.Context, sessionID, transcriptID string) error {
	if pubsubClient == nil {
		return nil
	}
	topic := pubsubClient.Publisher("transcript.completed")
	defer topic.Stop()

	payload, _ := json.Marshal(map[string]string{
		"session_id":    sessionID,
		"transcript_id": transcriptID,
	})

	res := topic.Publish(ctx, &pubsub.Message{
		Data: payload,
		Attributes: map[string]string{
			"event_type": "transcript.completed",
			"session_id": sessionID,
		},
	})
	if _, err := res.Get(ctx); err != nil {
		return err
	}
	// docs/21 Faza-4 consolidation: also mirror "analyzing" via the
	// unified session.status_changed topic (notification-worker-on-status
	// is the single status-mirror consumer; on-transcribed retired).
	// transcript.completed itself stays — it drives llm-worker.
	return publishSessionStatusChanged(ctx, sessionID, "analyzing")
}

// publishSessionStatusChanged mirrors a session lifecycle status to the
// `session.status_changed` topic (docs/21). notification-worker-on-status
// writes it into Firestore session_states so the Flutter app advances /
// shows the failure. [status] is the Firestore vocabulary
// ("transcribing" | "failed"), NOT the PG enum.
//
// IMPORTANT (docs/21 §3.1): only call this for TERMINAL failures and for
// genuine progress (transcribing). NEVER publish "failed" on a transient
// error that Pub/Sub will retry — that would flash a permanent-looking
// failure for a recording the user can no longer re-process.
//
// Best-effort: a publish failure is logged by the caller; it never blocks
// the PG write or the ack/nack decision.
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
