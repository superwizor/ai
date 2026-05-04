package sttworker

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"sort"
	"strings"
	"time"

	kms "cloud.google.com/go/kms/apiv1"
	"cloud.google.com/go/pubsub"
	speech "cloud.google.com/go/speech/apiv2"
	"cloud.google.com/go/speech/apiv2/speechpb"
	"github.com/GoogleCloudPlatform/functions-framework-go/funcframework"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/cloudevents/sdk-go/v2/event"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/api/option"

	"github.com/superwizor-ai/backend/pkg/cryptobox"
	"github.com/superwizor-ai/backend/pkg/i18n/speakerlabels"
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

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	if err := funcframework.Start(port); err != nil {
		slog.Error("framework start", "error", err)
		os.Exit(1)
	}
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

	// 1. Update session status
	if err := updateSessionStatus(ctx, event.SessionID, "TRANSCRIBING"); err != nil {
		logger.Error("status update", "error", err)
		return err
	}

	// 2. Run Chirp 3 batch recognize
	gcsURI := fmt.Sprintf("gs://%s/%s", bucketName, event.ObjectPath)
	transcriptResult, err := transcribeWithDiarization(ctx, gcsURI)
	if err != nil {
		logger.Error("chirp 3", "error", err)
		_ = updateSessionStatus(ctx, event.SessionID, "FAILED")
		return err
	}

	// 3. Generuj neutralne lokalizowane labels (NIE role)
	//    Pełne uzasadnienie: ADR-IMPL-002. Role są dedukowane przez LLM w Sprint 2.6.
	speakerLabels := generateSpeakerLabels(transcriptResult.Segments, transcriptResult.LanguageCode)

	// 4. Persist blob (kanoniczny, ADR-IMPL-006) + segments (statystyki)
	transcriptID, err := persistTranscript(ctx, event.SessionID, transcriptResult, speakerLabels, time.Since(startTime))
	if err != nil {
		logger.Error("persist", "error", err)
		_ = updateSessionStatus(ctx, event.SessionID, "FAILED")
		return err
	}

	// 5. Update session: zapisz mapping labels + language_code
	if err := updateSessionLabels(ctx, event.SessionID, speakerLabels, transcriptResult.LanguageCode); err != nil {
		logger.Warn("session labels update", "error", err)
	}
	_ = updateSessionStatus(ctx, event.SessionID, "ANALYZING")

	// 6. Publish transcript.completed
	if err := publishTranscriptCompleted(ctx, event.SessionID, transcriptID); err != nil {
		logger.Error("publish completed", "error", err)
		return err
	}

	logger.Info("done",
		"transcript_id", transcriptID,
		"duration_ms", time.Since(startTime).Milliseconds(),
		"segments", len(transcriptResult.Segments))

	return nil
}

type TranscriptResult struct {
	Segments       []TranscriptSegment
	LanguageCode   string
	WordCount      int
	SpeakerCount   int
	ConfidenceAvg  float32
}

type TranscriptSegment struct {
	SpeakerTag    int32
	StartOffsetMS int64
	EndOffsetMS   int64
	Text          string
	WordCount     int
	Confidence    float32
}

func transcribeWithDiarization(ctx context.Context, gcsURI string) (*TranscriptResult, error) {
	req := &speechpb.BatchRecognizeRequest{
		Recognizer: fmt.Sprintf("projects/%s/locations/eu/recognizers/_", projectID),
		Config: &speechpb.RecognitionConfig{
			DecodingConfig: &speechpb.RecognitionConfig_AutoDecodingConfig{
				AutoDecodingConfig: &speechpb.AutoDetectDecodingConfig{},
			},
			Model:         "chirp_3",
			LanguageCodes: []string{"pl-PL"},
			Features: &speechpb.RecognitionFeatures{
				EnableAutomaticPunctuation: true,
				EnableWordTimeOffsets:      true,
			},
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

	return ParseChirp3Results(resp), nil
}

// ParseChirp3Results extracts transcript segments from the Speech API response.
func ParseChirp3Results(resp *speechpb.BatchRecognizeResponse) *TranscriptResult {
	result := &TranscriptResult{LanguageCode: "pl-PL"}
	speakerSet := make(map[int32]bool)
	totalConfidence := float32(0)
	confidenceCount := 0

	for _, fileResult := range resp.Results {
		if fileResult.Transcript == nil {
			continue
		}
		for _, r := range fileResult.Transcript.Results {
			if len(r.Alternatives) == 0 {
				continue
			}
			alt := r.Alternatives[0]

			// Build segments per speaker turn
			currentSegment := TranscriptSegment{}
			for _, w := range alt.Words {
				speakerTag := w.SpeakerLabel
				speakerSet[parseSpeakerLabel(speakerTag)] = true

				wordOffset := w.StartOffset.AsDuration().Milliseconds()
				wordEndOffset := w.EndOffset.AsDuration().Milliseconds()

				if currentSegment.SpeakerTag != parseSpeakerLabel(speakerTag) {
					if currentSegment.Text != "" {
						result.Segments = append(result.Segments, currentSegment)
					}
					currentSegment = TranscriptSegment{
						SpeakerTag:    parseSpeakerLabel(speakerTag),
						StartOffsetMS: wordOffset,
						EndOffsetMS:   wordEndOffset,
					}
				}
				currentSegment.Text += w.Word + " "
				currentSegment.EndOffsetMS = wordEndOffset
				currentSegment.WordCount++
				result.WordCount++
			}
			if currentSegment.Text != "" {
				result.Segments = append(result.Segments, currentSegment)
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

func parseSpeakerLabel(label string) int32 {
	// "speaker_1" → 1
	var n int32
	fmt.Sscanf(label, "speaker_%d", &n)
	return n
}

// generateSpeakerLabels tworzy mapping speaker_tag → lokalizowana etykieta.
// NIE zwraca ról (THERAPIST/PATIENT) — to robi LLM w Sprint 2.6.
//
// Dla pl-PL: {1: "Osoba 1", 2: "Osoba 2", 3: "Osoba 3"}
// Dla en-US: {1: "Person 1", 2: "Person 2"}
// Dla unknown locale: {1: "Speaker 1", 2: "Speaker 2"}
func generateSpeakerLabels(segments []TranscriptSegment, languageCode string) map[int32]string {
	if len(segments) == 0 {
		return map[int32]string{}
	}

	// Zbierz wszystkie unique speaker tags
	speakerTagsSet := map[int32]bool{}
	for _, seg := range segments {
		speakerTagsSet[seg.SpeakerTag] = true
	}

	// Zamień na sorted slice (deterministyczne kolejność)
	tags := make([]int32, 0, len(speakerTagsSet))
	for t := range speakerTagsSet {
		tags = append(tags, t)
	}
	sort.Slice(tags, func(i, j int) bool { return tags[i] < tags[j] })

	// Generuj labels per tag
	mapping := make(map[int32]string, len(tags))
	for _, tag := range tags {
		mapping[tag] = speakerlabels.Generate(languageCode, int(tag))
	}

	return mapping
}

// Helpers SQL — uproszczone, w prod używamy sqlc-generated code
func updateSessionStatus(ctx context.Context, sessionID, status string) error {
	if dbPool == nil { return nil } // dla testów bez db
	id, err := uuid.Parse(sessionID)
	if err != nil {
		return err
	}
	_, err = dbPool.Exec(ctx,
		"UPDATE sessions SET status = $1, status_updated_at = now() WHERE id = $2",
		status, id)
	return err
}

func updateSessionLabels(ctx context.Context, sessionID string, mapping map[int32]string, languageCode string) error {
	if dbPool == nil { return nil } // dla testów bez db
	id, _ := uuid.Parse(sessionID)

	// Konwertuj klucze int32 → string dla JSONB
	jsonMapping := make(map[string]string, len(mapping))
	for tag, label := range mapping {
		jsonMapping[fmt.Sprintf("%d", tag)] = label
	}
	jsonBytes, _ := json.Marshal(jsonMapping)

	_, err := dbPool.Exec(ctx, `
		UPDATE sessions
		SET speaker_label_mapping = $1, language_code = $2
		WHERE id = $3`,
		jsonBytes, languageCode, id)
	return err
}

// persistTranscript zapisuje:
// 1. KANONICZNY blob w `transcripts.transcript_ciphertext` — JSON z full text + labels.
// 2. Segmenty w `transcript_segments` jako per-speaker statystyki + źródło rebuild.
//
// Zob. ADR-IMPL-006 — blob jest source of truth, Flutter czyta tylko z `transcripts`.
func persistTranscript(ctx context.Context, sessionID string, result *TranscriptResult, labels map[int32]string, processingTime time.Duration) (string, error) {
	transcriptID := uuid.New()
	sessID, _ := uuid.Parse(sessionID)

	// Build kanoniczny blob — pełny tekst z labels
	type BlobLine struct {
		SpeakerTag   int32  `json:"speaker_tag"`
		SpeakerLabel string `json:"speaker_label"`
		Text         string `json:"text"`
		StartMS      int64  `json:"start_ms"`
		EndMS        int64  `json:"end_ms"`
		Confidence   float32 `json:"confidence"`
	}

	blobLines := make([]BlobLine, 0, len(result.Segments))
	for _, seg := range result.Segments {
		label := labels[seg.SpeakerTag]
		if label == "" {
			label = fmt.Sprintf("Speaker %d", seg.SpeakerTag)  // safety fallback
		}
		blobLines = append(blobLines, BlobLine{
			SpeakerTag:   seg.SpeakerTag,
			SpeakerLabel: label,
			Text:         strings.TrimSpace(seg.Text),
			StartMS:      seg.StartOffsetMS,
			EndMS:        seg.EndOffsetMS,
			Confidence:   seg.Confidence,
		})
	}

	blobJSON, _ := json.Marshal(blobLines)

	blobCiphertext, blobDEK, err := crypto.Encrypt(ctx, blobJSON)
	if err != nil {
		slog.Error("encrypt blob", "error", err)
		return "", err
	}

	if dbPool == nil { return transcriptID.String(), nil } // test
	tx, err := dbPool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)

	// 1. INSERT transcripts (kanoniczny blob)
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

	// 2. INSERT transcript_segments (statystyki + rebuild source)
	for _, seg := range result.Segments {
		segID := uuid.New()
		segText := strings.TrimSpace(seg.Text)

		segCiphertext, segDEK, err := crypto.Encrypt(ctx, []byte(segText))
		if err != nil {
			slog.Error("encrypt segment", "error", err)
			return "", err
		}

		label := labels[seg.SpeakerTag]
		if label == "" {
			label = fmt.Sprintf("Speaker %d", seg.SpeakerTag)
		}

		_, err = tx.Exec(ctx, `
			INSERT INTO transcript_segments (
				id, transcript_id, speaker_tag, speaker_label,
				start_offset_ms, end_offset_ms,
				text_ciphertext, text_encrypted_dek,
				text_word_count, confidence
			) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
			segID, transcriptID, seg.SpeakerTag, label,
			seg.StartOffsetMS, seg.EndOffsetMS,
			segCiphertext, segDEK,
			seg.WordCount, seg.Confidence)
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
	if pubsubClient == nil { return nil } // test mode
	topic := pubsubClient.Topic("transcript.completed")
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

// Defensywny stub — w prod struct nie jest używany jak http.Handler
var _ = http.HandlerFunc(nil)
