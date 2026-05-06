package sttworker

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"time"

	kms "cloud.google.com/go/kms/apiv1"
	"cloud.google.com/go/pubsub/v2"
	speech "cloud.google.com/go/speech/apiv2"
	"cloud.google.com/go/speech/apiv2/speechpb"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/cloudevents/sdk-go/v2/event"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/api/option"

	"github.com/superwizor-ai/backend/pkg/cryptobox"
	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
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
	dbPool       *pgxpool.Pool
	speechClient *speech.Client
	pubsubClient *pubsub.Client
	crypto       cryptobox.CryptoBox
	bucketName   string
	projectID    string
)

func init() {
	ctx := context.Background()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	projectID = os.Getenv("GCP_PROJECT_ID")
	bucketName = os.Getenv("AUDIO_BUCKET_NAME")
	dbDSN := os.Getenv("DATABASE_URL")
	kmsKeyURI := os.Getenv("KMS_KEY_URI")

	var err error
	if dbDSN != "" {
		dbPool, err = pgxpool.New(ctx, dbDSN)
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

	startTime := time.Now()

	if err := updateSessionStatus(ctx, event.SessionID, "TRANSCRIBING"); err != nil {
		logger.Error("status update", "error", err)
		return err
	}

	// 2. Run Chirp 3 — feature flag USE_NATIVE_DIARIZATION (ADR-IMPL-007).
	//    Default false: polski nie jest na liście supported dla diarization,
	//    więc słowa są zwracane bez speaker_tag i grupowane przez chunker.
	gcsURI := fmt.Sprintf("gs://%s/%s", bucketName, event.ObjectPath)
	useNativeDiarization := os.Getenv("USE_NATIVE_DIARIZATION") == "true"

	transcriptResult, err := transcribeAudio(ctx, gcsURI, useNativeDiarization)
	if err != nil {
		logger.Error("chirp 3", "error", err)
		_ = updateSessionStatus(ctx, event.SessionID, "FAILED")
		return err
	}

	// 3. Chunkowanie słów na podstawie pauz (zob. pkg/transcription/chunker).
	//    LLM przypisze chunki do mówców w Sprint 2.6.
	chunks := chunker.ChunkByPauses(transcriptResult.Words, chunker.DefaultConfig())
	stats := chunker.ComputeStats(chunks)
	logger.Info("chunked transcript",
		"chunk_count", stats.ChunkCount,
		"total_words", stats.TotalWords,
		"avg_chunk_duration_ms", stats.AvgChunkLength.Milliseconds(),
		"avg_confidence", stats.AvgConfidence)

	// 4. Persist blob (kanoniczny, ADR-IMPL-006) — chunki bez speaker labels.
	transcriptID, err := persistTranscript(ctx, event.SessionID, transcriptResult, chunks, time.Since(startTime))
	if err != nil {
		logger.Error("persist", "error", err)
		_ = updateSessionStatus(ctx, event.SessionID, "FAILED")
		return err
	}

	// 5. Update session: language_code (speaker_label_mapping zostanie wypełniony
	//    przez llm-worker.generateAndSaveSpeakerLabels po analizie LLM).
	if err := updateSessionLanguage(ctx, event.SessionID, transcriptResult.LanguageCode); err != nil {
		logger.Warn("session language update", "error", err)
	}
	_ = updateSessionStatus(ctx, event.SessionID, "ANALYZING")

	if err := publishTranscriptCompleted(ctx, event.SessionID, transcriptID); err != nil {
		logger.Error("publish completed", "error", err)
		return err
	}

	logger.Info("done",
		"transcript_id", transcriptID,
		"duration_ms", time.Since(startTime).Milliseconds(),
		"chunks", len(chunks))

	return nil
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
// Default (useNativeDiarization=false): zwraca płaską listę słów z timestamps
// bez przypisania mówców. Diarization jest robiona później przez LLM (ADR-IMPL-007).
func transcribeAudio(ctx context.Context, gcsURI string, useNativeDiarization bool) (*TranscriptResult, error) {
	features := &speechpb.RecognitionFeatures{
		EnableAutomaticPunctuation: true,
		EnableWordTimeOffsets:      true,
	}

	// Native diarization tylko jeśli flag explicit włączony.
	// Polski (pl-PL) NIE jest na liście supportowanych dla diarization w v1.2.
	if useNativeDiarization {
		features.DiarizationConfig = &speechpb.SpeakerDiarizationConfig{
			MinSpeakerCount: 2,
			MaxSpeakerCount: 4,
		}
	}

	req := &speechpb.BatchRecognizeRequest{
		Recognizer: fmt.Sprintf("projects/%s/locations/eu/recognizers/_", projectID),
		Config: &speechpb.RecognitionConfig{
			DecodingConfig: &speechpb.RecognitionConfig_AutoDecodingConfig{
				AutoDecodingConfig: &speechpb.AutoDetectDecodingConfig{},
			},
			Model:         "chirp_3",
			LanguageCodes: []string{"pl-PL"},
			Features:      features,
		},
		Files: []*speechpb.BatchRecognizeFileMetadata{
			{
				AudioSource: &speechpb.BatchRecognizeFileMetadata_Uri{Uri: gcsURI},
			},
		},
		RecognitionOutputConfig: &speechpb.RecognitionOutputConfig{
			Output: &speechpb.RecognitionOutputConfig_InlineResponseConfig{
				InlineResponseConfig: &speechpb.InlineOutputConfig{},
			},
		},
	}

	op, err := speechClient.BatchRecognize(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("batch recognize: %w", err)
	}

	resp, err := op.Wait(ctx)
	if err != nil {
		return nil, fmt.Errorf("await: %w", err)
	}

	return ParseChirp3Results(resp, useNativeDiarization), nil
}

// ParseChirp3Results extracts words and confidence from the Speech API response.
// Słowa są zwracane bez speaker_tag (default flow) — chunker je zgrupuje.
func ParseChirp3Results(resp *speechpb.BatchRecognizeResponse, useNativeDiarization bool) *TranscriptResult {
	result := &TranscriptResult{
		LanguageCode:         "pl-PL",
		HasNativeDiarization: useNativeDiarization,
	}
	speakerSet := map[string]bool{}
	totalConfidence := float32(0)
	confidenceCount := 0

	for _, fileResult := range resp.Results {
		inline := fileResult.GetInlineResult()
		if inline == nil || inline.GetTranscript() == nil {
			continue
		}
		for _, r := range inline.GetTranscript().Results {
			if len(r.Alternatives) == 0 {
				continue
			}
			alt := r.Alternatives[0]

			for _, w := range alt.Words {
				word := chunker.Word{
					Text:       w.Word,
					StartMS:    w.StartOffset.AsDuration().Milliseconds(),
					EndMS:      w.EndOffset.AsDuration().Milliseconds(),
					Confidence: w.Confidence,
				}
				result.Words = append(result.Words, word)
				result.WordCount++

				if useNativeDiarization && w.SpeakerLabel != "" {
					speakerSet[w.SpeakerLabel] = true
				}
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

	return result
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

// updateSessionLanguage zapisuje wykryty/użyty language_code dla sesji.
// speaker_label_mapping zostaje pusty {} — zostanie wypełniony przez
// llm-worker.generateAndSaveSpeakerLabels po analizie LLM.
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
		blobLines = append(blobLines, BlobLine{
			ChunkIdx:   c.Index,
			Text:       c.Text,
			StartMS:    c.StartMS,
			EndMS:      c.EndMS,
			WordCount:  c.WordCount,
			Confidence: c.Confidence,
		})
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
	_, err := res.Get(ctx)
	return err
}
