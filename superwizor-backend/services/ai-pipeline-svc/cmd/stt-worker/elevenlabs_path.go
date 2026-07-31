package sttworker

// elevenlabs_path.go — the ElevenLabs Scribe v2 provider branch of
// ProcessAudio (docs/59_ELEVENLABS_STT_MIGRATION.md, Faza 1).
//
// Structurally identical to the Deepgram branch: claim the work, mint a
// short-lived signed GET URL, call the API synchronously, finish inline
// via completeTranscript. The claim/takeover machinery is shared
// verbatim (claimSyncOperation) rather than copied.
//
// The one thing this branch does that no previous provider branch did is
// CHECK THAT THE TRANSCRIPT REACHES THE END OF THE AUDIO before storing
// it. Nova-3 shipped to production returning transcripts that stopped a
// quarter of the way in, and the pipeline stored them as COMPLETED
// because nothing ever asked. See internal/elevenlabs/coverage.go.

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/pkg/i18n/lang"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/elevenlabs"
)

// sttModelElevenLabs is stamped into transcripts.stt_model.
const sttModelElevenLabs = "elevenlabs-scribe-v2"

// errElevenLabsLowCoverage marks a transcript rejected by the coverage
// guard. Deliberately a transient-shaped failure: NACK, let Pub/Sub
// redeliver, and after dgMaxAttempts the shared claim machinery fails
// the session over to Chirp. A truncated transcript must never be the
// session's final answer, but it also must not fail the session
// outright — the audio is fine and another engine can read it.
var errElevenLabsLowCoverage = fmt.Errorf("elevenlabs: transcript coverage below floor")

// elevenLabsLanguage maps the session's BCP47 tag onto the ISO-639-3
// code the API expects ("pl-PL" → "pol").
//
// Unlike deepgramLanguage this does NOT default to Polish on an empty
// tag. Sessions predating feat/llm-optimisation have no language_code,
// and the benchmark showed Scribe auto-detects correctly — whereas
// forcing a wrong language is exactly what made nova-3 return zero words
// on English audio (docs/59 D7). Empty in, empty out; the client then
// omits the parameter.
func elevenLabsLanguage(bcp47 string) string {
	if bcp47 == "" {
		return ""
	}
	primary := bcp47
	if i := strings.IndexByte(bcp47, '-'); i > 0 {
		primary = bcp47[:i]
	}
	switch strings.ToLower(primary) {
	case "pl":
		return "pol"
	case "en":
		return "eng"
	case "de":
		return "deu"
	case "uk":
		return "ukr"
	case "es":
		return "spa"
	case "fr":
		return "fra"
	}
	// Unknown language: send nothing rather than a guess. Auto-detect
	// beats a wrong hint.
	return ""
}

// iso639_3to1 converts the ISO-639-3 code the API returns ("pol") back to
// the two-letter form the rest of the platform speaks ("pl").
//
// Needed because lang.BCP47ize looks the value up in a map keyed by
// two-letter codes, so it silently returns "" for "pol" — which is
// exactly what happened on the first live session: the transcript landed
// with an empty language_code. Round-trips elevenLabsLanguage.
func iso639_3to1(code string) string {
	switch strings.ToLower(strings.TrimSpace(code)) {
	case "pol":
		return "pl"
	case "eng":
		return "en"
	case "deu", "ger":
		return "de"
	case "ukr":
		return "uk"
	case "spa":
		return "es"
	case "fra", "fre":
		return "fr"
	}
	// Already two-letter (or something we don't know) — hand it over
	// unchanged and let BCP47ize decide.
	return code
}

// processAudioElevenLabs is the elevenlabs branch of ProcessAudio. The
// caller has already: validated the event, passed the poison guard, set
// sessions.status=TRANSCRIBING and resolved bcp47Lang.
func processAudioElevenLabs(ctx context.Context, logger *slog.Logger, ev AudioUploadedEvent, sessionUUID uuid.UUID, bcp47Lang string) error {
	logger = logger.With("provider", providerElevenLabs)
	sourceURI := fmt.Sprintf("gs://%s/%s", bucketName, ev.ObjectPath)

	claim, err := claimSyncOperation(ctx, sessionUUID, providerElevenLabs, sourceURI, bcp47Lang)
	if err != nil {
		return err // transient DB → NACK
	}
	switch claim.state {
	case dgClaimAlreadyDone:
		logger.Info("elevenlabs row already finalized; ack")
		return nil
	case dgClaimForeignProvider:
		logger.Info("chunk rows owned by another provider; letting it finish",
			"row_provider", claim.rowProvider)
		return nil
	case dgClaimInFlight:
		logger.Info("another elevenlabs attempt in flight; NACK for later redelivery")
		return errDeepgramInFlight
	case dgClaimExhausted:
		logger.Warn("elevenlabs attempts exhausted; failing over to chirp",
			"attempts", claim.attempt)
		return fallbackToChirp(ctx, logger, sessionUUID, sourceURI, bcp47Lang)
	}

	logger.Info("elevenlabs attempt claimed", "attempt", claim.attempt)

	signedURL, err := signAudioURL(ev.ObjectPath)
	if err != nil {
		// Signing is local/IAM — failures are transient (token blip) →
		// NACK. The claim row ages into takeover on the next delivery.
		logger.Error("signAudioURL failed", "error", err)
		return err
	}

	start := time.Now()
	res, err := elClient.Transcribe(ctx, signedURL, elevenlabs.Params{
		Language: elevenLabsLanguage(bcp47Lang),
	})
	if err != nil {
		return handleElevenLabsError(ctx, logger, sessionUUID, err)
	}
	_ = updateProviderRequestID(ctx, sessionUUID, providerElevenLabs, res.RequestID)

	// ── coverage guard (docs/59 §6.1) ─────────────────────────────────
	verdict, coverage := res.CheckCoverage()
	logger.Info("elevenlabs transcription complete",
		"el_transcription_id", res.RequestID,
		"word_count", res.WordCount,
		"speaker_count", res.SpeakerCount,
		"audio_duration_sec", res.AudioDurationSec,
		"coverage", coverage,
		"coverage_verdict", verdict.String(),
		"words_per_second", res.WordsPerSecond(),
		"bogus_timestamps", res.BogusTimestamps(),
		"language_code", res.LanguageCode,
		"language_probability", res.LanguageProb,
		"transcribe_ms", time.Since(start).Milliseconds())

	switch verdict {
	case elevenlabs.CoverageReject:
		// Distinct log signature: this is the nova-3 failure mode, and it
		// must be visible as a provider incident rather than disappearing
		// into a stored transcript nobody re-reads.
		logger.Error("stt_low_coverage — transcript rejected; NACK for retry then chirp fallback",
			"coverage", coverage,
			"floor", elevenlabs.CoverageFloor,
			"word_count", res.WordCount,
			"audio_duration_sec", res.AudioDurationSec)
		return errElevenLabsLowCoverage
	case elevenlabs.CoverageDegraded:
		// Store it — a partial transcript beats none for the therapist —
		// but say so loudly.
		logger.Warn("stt_low_coverage — transcript missing a chunk of the tail; storing anyway",
			"coverage", coverage, "word_count", res.WordCount)
	}

	slog.InfoContext(ctx, "analytics",
		"ae", "stt.submitted",
		"session_id", sessionUUID.String(),
		"provider", providerElevenLabs,
		"language_code", bcp47Lang,
		"native_diarization", res.SpeakerCount > 0,
		"chunk_count", 1,
		"el_transcription_id", res.RequestID,
		"el_transcribe_ms", time.Since(start).Milliseconds(),
		"stt_coverage", coverage,
		"stt_words_per_second", res.WordsPerSecond(),
	)
	if res.DroppedWords() > 0 {
		logger.Warn("dropped words with implausible timestamps",
			"dropped_words", res.DroppedWords(), "kept_words", res.WordCount)
	}

	tr := &TranscriptResult{
		Words: res.Words,
		// The API reports ISO-639-3 ("pol"), which BCP47ize does not
		// understand — hence the two-letter hop first. Falls back to the
		// session's own tag when detection returned nothing.
		LanguageCode:         lang.BCP47ize(firstNonEmpty(iso639_3to1(res.LanguageCode), bcp47Lang)),
		WordCount:            res.WordCount,
		ConfidenceAvg:        res.ConfidenceAvg,
		HasNativeDiarization: res.SpeakerCount > 0,
		SpeakerCount:         res.SpeakerCount,
	}

	if err := completeTranscript(ctx, logger, sessionUUID, tr, sttModelElevenLabs, start); err != nil {
		if isTerminalSTTError(err) {
			return handleSTTError(ctx, logger, sessionUUID.String(), err)
		}
		logger.Error("completeTranscript transient failure; NACK", "error", err)
		return err
	}

	if _, err := markChunkFinalized(ctx, sessionUUID, 0); err != nil {
		// Transcript is durably persisted + published; only the ops row
		// stayed pending. fallbackToChirp's transcript-exists guard makes
		// the eventual watchdog touch a no-op, so just log.
		logger.Warn("markChunkFinalized failed post-persist (harmless; guarded downstream)", "error", err)
	}
	return nil
}

// handleElevenLabsError applies the docs/21 failure semantics to a
// Transcribe error. Same three buckets as the Deepgram path.
func handleElevenLabsError(ctx context.Context, logger *slog.Logger, sessionUUID uuid.UUID, err error) error {
	switch elevenlabs.Classify(err) {
	case elevenlabs.Auth:
		// Credential rot — a platform incident, not a session failure.
		// Distinct log signature for alerting; NACK so the session waits
		// for the key fix (or the chirp fallback after dgMaxAttempts).
		logger.Error("elevenlabs_auth_error — API key rejected; session left in-progress",
			"error", err.Error())
		return err
	case elevenlabs.Terminal:
		recordFinalizeError(ctx, sessionUUID, 0, truncateOpError(err.Error()))
		_, _ = markChunkFinalized(ctx, sessionUUID, 0)
		return handleSTTError(ctx, logger, sessionUUID.String(),
			fmt.Errorf("elevenlabs: %w: %s", errTerminalSTT, err.Error()))
	default:
		// Includes the expired-signed-URL case, which Classify keeps
		// Transient on purpose: the URL died, not the session.
		logger.Warn("elevenlabs transient error; NACK for retry", "error", err.Error())
		return err
	}
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}
