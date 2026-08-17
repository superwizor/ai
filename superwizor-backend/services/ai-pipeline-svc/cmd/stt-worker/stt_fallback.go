package sttworker

// stt_fallback.go — co robimy, gdy silnik STT nie daje rady.
//
// Do 2026-07-31 kazda porazka spadala wprost na Chirpa. Przy defaultcie
// ElevenLabs to jest zly wybor: Chirp NIE diaryzuje pl-PL w ogole
// (transcriptfmt.Chirp3DiarizationLanguages["pl-PL"] = false, recognizer
// eu/_ odrzuca diarizationConfig bledem 400), wiec fallback oddawal
// transkrypt bez rozdzielenia terapeuty i klienta. To degradacja
// jakosci, nie samo opoznienie — i widoczna dla terapeuty w raporcie.
//
// Lancuch jest teraz stopniowy:
//
//	elevenlabs → deepgram → chirp
//	deepgram   → chirp
//	chirp      → (koniec drogi)
//
// Deepgram jako drugi stopien jest kompromisem, nie ideałem: nova-3
// potrafi urwac transkrypcje na monotonnym materiale (zmierzone 24,5%
// pokrycia na 62 s liczenia) i pomylic dwoch mowcow z jednym. Ale
// diaryzacje dla polskiego ma, a Chirp nie — a fallback ma ratowac
// sesje, nie oddawac ja w gorszym stanie, niz musi.

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/pkg/i18n/lang"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/deepgram"
)

// nextFallbackProvider zwraca kolejny silnik w lancuchu, pomijajac te
// bez wpietego klienta. Pusty wynik = nie ma dokad spadac.
func nextFallbackProvider(from string) string {
	switch from {
	case providerElevenLabs:
		if providerAvailable(providerDeepgram) {
			return providerDeepgram
		}
		return providerChirp
	case providerDeepgram:
		return providerChirp
	}
	return ""
}

// fallbackFrom kieruje sesje na kolejny silnik. Wywolywane z galezi
// providera po wyczerpaniu prob i z watchdoga dla wiszacych wierszy.
func fallbackFrom(ctx context.Context, logger *slog.Logger, sessionUUID uuid.UUID, from, sourceURI, bcp47Lang string) error {
	switch nextFallbackProvider(from) {
	case providerDeepgram:
		return fallbackToDeepgram(ctx, logger, sessionUUID, sourceURI, bcp47Lang)
	default:
		return fallbackToChirp(ctx, logger, sessionUUID, sourceURI, bcp47Lang)
	}
}

// objectPathFromURI zdejmuje z gs://<bucket>/<obiekt> sam obiekt.
// Watchdog trzyma pelne URI, a signAudioURL oczekuje sciezki obiektu.
func objectPathFromURI(uri string) string {
	s := strings.TrimPrefix(uri, "gs://")
	if i := strings.IndexByte(s, '/'); i >= 0 {
		return s[i+1:]
	}
	return ""
}

// fallbackToDeepgram przejmuje sesje po ElevenLabs i transkrybuje ja
// synchronicznie Deepgramem — ta sama mechanika co processAudioDeepgram,
// ale bez ponownego zajmowania wiersza (wiersz juz nalezy do nas, tylko
// zmienia wlasciciela).
//
// Wiersz dostaje fallback_attempted=TRUE, wiec kolejne dostarczenia
// widza go jako ForeignProvider i nie wchodza w petle. Cena tego jest
// taka, ze porazka Deepgrama w tym miejscu nie doczeka sie redelivery —
// dlatego spadamy wtedy natychmiast na Chirpa zamiast zwracac blad.
func fallbackToDeepgram(ctx context.Context, logger *slog.Logger, sessionUUID uuid.UUID, sourceURI, bcp47Lang string) error {
	logger = logger.With("provider_fallback", providerElevenLabs+"→"+providerDeepgram)

	// Transkrypt juz istnieje → poprzednia proba umarla miedzy zapisem
	// a domknieciem wiersza. Wystarczy zamknac wiersz.
	if id, err := fetchTranscriptIDForSession(ctx, sessionUUID); err == nil && id != "" {
		logger.Info("transcript already persisted; closing ops row instead of fallback")
		_, _ = markChunkFinalized(ctx, sessionUUID, 0)
		return nil
	}

	objectPath := objectPathFromURI(sourceURI)
	if objectPath == "" {
		logger.Warn("cannot derive object path from source URI; falling back to chirp", "source_uri", sourceURI)
		return fallbackToChirp(ctx, logger, sessionUUID, sourceURI, bcp47Lang)
	}

	// Przepiecie wiersza PRZED wywolaniem — redelivery w trakcie ma
	// zobaczyc, ze wlascicielem jest juz Deepgram.
	if dbPool != nil {
		if _, err := dbPool.Exec(ctx, `
			UPDATE stt_operations
			SET provider = $2, operation_id = $3, fallback_attempted = TRUE,
			    retry_count = 0, submitted_at = now(),
			    finalize_error = 'elevenlabs fallback; prior request_id=' || COALESCE(request_id, 'n/a')
			WHERE session_id = $1 AND chunk_index = 0`,
			sessionUUID, providerDeepgram, providerDeepgram+":sync"); err != nil {
			return fmt.Errorf("fallback repoint to deepgram: %w", err)
		}
	}

	signedURL, err := signAudioURL(objectPath)
	if err != nil {
		logger.Error("signAudioURL failed during fallback; falling back to chirp", "error", err)
		return fallbackToChirp(ctx, logger, sessionUUID, sourceURI, bcp47Lang)
	}

	start := time.Now()
	res, err := dgClient.Transcribe(ctx, signedURL, deepgram.Params{
		Language: deepgramLanguage(bcp47Lang),
	})
	if err != nil {
		// Ostatni stopien lancucha. Nie zwracamy bledu, bo wiersz ma juz
		// fallback_attempted i redelivery go nie podejmie.
		logger.Warn("deepgram fallback failed; falling back to chirp", "error", err.Error())
		return fallbackToChirp(ctx, logger, sessionUUID, sourceURI, bcp47Lang)
	}
	_ = updateProviderRequestID(ctx, sessionUUID, providerDeepgram, res.RequestID)

	logger.Info("deepgram fallback transcription complete",
		"dg_request_id", res.RequestID,
		"word_count", res.WordCount,
		"speaker_count", res.SpeakerCount,
		"audio_duration_sec", res.AudioDurationSec,
		"transcribe_ms", time.Since(start).Milliseconds())

	slog.InfoContext(ctx, "analytics",
		"ae", "stt.provider_fallback",
		"session_id", sessionUUID.String(),
		"provider_from", providerElevenLabs,
		"provider_to", providerDeepgram,
		"word_count", res.WordCount,
		"speaker_count", res.SpeakerCount,
	)

	tr := &TranscriptResult{
		Words:                res.Words,
		LanguageCode:         lang.BCP47ize(firstNonEmpty(res.LanguageCode, bcp47Lang)),
		WordCount:            res.WordCount,
		ConfidenceAvg:        res.ConfidenceAvg,
		HasNativeDiarization: res.SpeakerCount > 0,
		SpeakerCount:         res.SpeakerCount,
	}

	if err := completeTranscript(ctx, logger, sessionUUID, tr, sttModelDeepgram, start); err != nil {
		if isTerminalSTTError(err) {
			return handleSTTError(ctx, logger, sessionUUID.String(), err)
		}
		logger.Error("completeTranscript transient failure after deepgram fallback; NACK", "error", err)
		return err
	}
	if _, err := markChunkFinalized(ctx, sessionUUID, 0); err != nil {
		logger.Warn("markChunkFinalized failed post-persist (harmless; guarded downstream)", "error", err)
	}
	return nil
}
