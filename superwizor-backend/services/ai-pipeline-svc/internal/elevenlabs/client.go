// Package elevenlabs is the STT provider client for ElevenLabs Scribe v2
// (docs/59_ELEVENLABS_STT_MIGRATION.md). Pre-recorded transcription with
// native speaker diarization for Polish, called SYNCHRONOUSLY from
// stt-worker — the HTTP response IS the transcript.
//
// Deliberately a near-mirror of internal/deepgram: same seams, same error
// classification, same Result shape. The migration that produced this
// package replaced the provider, not the architecture.
//
// Privacy invariants (do not weaken):
//   - The base URL must be the EU data-residency endpoint. Enforced at
//     worker init via IsEUEndpoint, which refuses to start otherwise —
//     one typo in an env var must not send health data outside the EU.
//   - Audio is never streamed through this process. We hand ElevenLabs a
//     V4-signed GCS URL (15 min TTL) via source_url and they fetch it.
//     Verified end-to-end 2026-07-31: signed URL → HTTP 200 → 94 words,
//     99.9% coverage.
//
// OPEN (docs/59 §7.1): ElevenLabs' equivalent of Deepgram's
// mip_opt_out — opting audio out of model training — is not yet
// confirmed. There is deliberately no parameter for it here rather than
// a guessed one; until it is settled contractually and implemented, the
// no-training guarantee rests on the DPA, not on code.
package elevenlabs

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// DefaultBaseURL is the EU data-residency endpoint. The global endpoint
// (api.elevenlabs.io) is intentionally not referenced anywhere in this
// package.
const DefaultBaseURL = "https://api.eu.residency.elevenlabs.io"

// Model is pinned rather than configurable. scribe_v1 is the previous
// generation; an env-tunable model is one config mistake away from
// silently downgrading every session.
const Model = "scribe_v2"

// IsEUEndpoint reports whether rawURL points at the EU-residency API.
// Worker init refuses to start when this is false.
func IsEUEndpoint(rawURL string) bool {
	u, err := url.Parse(rawURL)
	if err != nil {
		return false
	}
	return u.Scheme == "https" &&
		(u.Host == "api.eu.residency.elevenlabs.io" ||
			strings.HasSuffix(u.Host, ".eu.residency.elevenlabs.io"))
}

// Params is the per-request configuration. Everything except Language is
// fixed by policy (docs/59 D7-D9).
type Params struct {
	// Language is an ISO-639-1/3 code ("pol"). Empty means "let the API
	// auto-detect" and is a legitimate state, not a bug: sessions
	// predating feat/llm-optimisation have no language_code, and the
	// benchmark showed Scribe transcribes correctly even when the tag
	// disagrees with the audio (docs/59 D7). A hint, never a constraint.
	Language string
}

// buildFields renders the multipart form fields. Centralized so the
// policy decisions live in exactly one place.
//
// num_speakers is deliberately NOT set (docs/59 D9): we cannot know how
// many people are in the room — individual, couples, family and
// supervision sessions all flow through here — and pinning it would bias
// exactly the cases we care about. The benchmark got 1/2/3 speakers
// right without it.
//
// tag_audio_events defaults to true upstream, which injects laughter and
// similar markers into words[] as type="audio_event". Clinically that
// may be valuable, but it changes the transcript contract and needs a
// product decision first (docs/59 D8), so v1 turns it off.
func buildFields(p Params, sourceURL string) map[string]string {
	f := map[string]string{
		"model_id":               Model,
		"source_url":             sourceURL,
		"diarize":                "true",
		"timestamps_granularity": "word",
		"tag_audio_events":       "false",
	}
	if p.Language != "" {
		f["language_code"] = p.Language
	}
	return f
}

// Client is a minimal, dependency-free REST client for
// POST /v1/speech-to-text. Safe for concurrent use.
type Client struct {
	httpc   *http.Client
	apiKey  string
	baseURL string
}

// New builds a Client. baseURL empty → DefaultBaseURL. The HTTP timeout
// covers the whole synchronous transcription. Measured 2026-07-31:
// 26 minutes of audio → 28 s, which extrapolates to ~60 s for a
// 50-minute session; 330 s leaves an internal retry inside the
// function's 540 s budget (docs/59 D1).
func New(apiKey, baseURL string) *Client {
	if baseURL == "" {
		baseURL = DefaultBaseURL
	}
	return &Client{
		httpc:   &http.Client{Timeout: 330 * time.Second},
		apiKey:  apiKey,
		baseURL: strings.TrimSuffix(baseURL, "/"),
	}
}

// Transcribe submits the audio at audioURL (a V4-signed GCS GET URL —
// ElevenLabs fetches it directly; we never stream the bytes) and returns
// the parsed transcript. Retries once on 429/5xx with a short backoff;
// every other failure surfaces immediately for the caller to classify.
func (c *Client) Transcribe(ctx context.Context, audioURL string, p Params) (*Result, error) {
	endpoint := c.baseURL + "/v1/speech-to-text"

	var lastErr error
	for attempt := 0; attempt < 2; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(2 * time.Second):
			}
		}
		// Rebuilt per attempt: the multipart body is a consumed reader.
		body, contentType, err := encodeMultipart(buildFields(p, audioURL))
		if err != nil {
			return nil, fmt.Errorf("encode request: %w", err)
		}
		res, err := c.do(ctx, endpoint, body, contentType)
		if err == nil {
			return res, nil
		}
		lastErr = err
		var apiErr *APIError
		if !isRetryable(err, &apiErr) {
			return nil, err
		}
	}
	return nil, lastErr
}

// encodeMultipart builds a multipart/form-data body of plain fields. The
// endpoint accepts only multipart — there is no JSON variant — even when
// the audio arrives by URL rather than as an uploaded file.
func encodeMultipart(fields map[string]string) ([]byte, string, error) {
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	for k, v := range fields {
		if err := w.WriteField(k, v); err != nil {
			return nil, "", err
		}
	}
	if err := w.Close(); err != nil {
		return nil, "", err
	}
	return buf.Bytes(), w.FormDataContentType(), nil
}

func (c *Client) do(ctx context.Context, endpoint string, body []byte, contentType string) (*Result, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("xi-api-key", c.apiKey)
	req.Header.Set("Content-Type", contentType)

	resp, err := c.httpc.Do(req)
	if err != nil {
		return nil, fmt.Errorf("elevenlabs request: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	// A 50-minute session's word array runs a few MB; bound the read so a
	// misbehaving response cannot OOM the function.
	const maxBody = 64 << 20
	raw, err := io.ReadAll(io.LimitReader(resp.Body, maxBody))
	if err != nil {
		return nil, fmt.Errorf("elevenlabs read body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, &APIError{StatusCode: resp.StatusCode, Body: truncate(string(raw), 512)}
	}
	return Parse(raw)
}

// isRetryable reports whether the in-flight attempt may be repeated:
// 429 / 5xx API responses and transport-level failures. 4xx config
// errors and parse failures are not — the retry would just repeat them.
func isRetryable(err error, apiErr **APIError) bool {
	if as(err, apiErr) {
		code := (*apiErr).StatusCode
		return code == http.StatusTooManyRequests || code >= 500
	}
	return true
}

func truncate(s string, n int) string {
	if len(s) > n {
		return s[:n] + "...(truncated)"
	}
	return s
}
