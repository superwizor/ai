// Package deepgram is the STT provider client for Deepgram Nova-3
// (docs/39_DEEPGRAM_STT_MIGRATION.md). Pre-recorded transcription with
// native speaker diarization, called SYNCHRONOUSLY from stt-worker —
// Deepgram does not store results, so there is no job/poll model; the
// HTTP response IS the transcript.
//
// Privacy invariants (do not weaken):
//   - mip_opt_out=true is hardcoded into every request query. Therapy
//     audio is special-category health data (GDPR art. 9); it must never
//     feed Deepgram's Model Improvement Program. Guarded by a unit test.
//   - The base URL must be the EU-resident endpoint. Enforced at worker
//     init (refuses to start otherwise), mirroring the pinned
//     europe-west4 Vertex region from ADR-IMPL-003.
package deepgram

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// DefaultBaseURL is the EU-resident endpoint (AWS EU, full data
// residency — see docs/39 §1). The US endpoint is intentionally not
// referenced anywhere in this package.
const DefaultBaseURL = "https://api.eu.deepgram.com"

// IsEUEndpoint reports whether rawURL points at Deepgram's EU-resident
// API. Worker init refuses to start when this is false (P3 exception is
// scoped to the EU, not to "wherever the env var points").
func IsEUEndpoint(rawURL string) bool {
	u, err := url.Parse(rawURL)
	if err != nil {
		return false
	}
	return u.Scheme == "https" &&
		(u.Host == "api.eu.deepgram.com" || strings.HasSuffix(u.Host, ".eu.deepgram.com"))
}

// Params is the per-request transcription configuration. Model and the
// privacy/diarization flags are fixed by policy; only language varies
// per session today.
type Params struct {
	// Language is Deepgram's short code ("pl", "en", "de"). The caller
	// maps from the session's BCP47 tag. Empty pins nothing and lets
	// the API default (not recommended — always pass one).
	Language string
}

// buildQuery renders the request query string. Centralized so the
// privacy invariant lives in exactly one place: mip_opt_out=true is
// unconditional and NOT configurable (an env flag able to disable it
// would be one typo away from leaking PHI into model training).
func buildQuery(p Params) url.Values {
	q := url.Values{}
	q.Set("model", "nova-3")
	if p.Language != "" {
		q.Set("language", p.Language)
	}
	q.Set("diarize", "true")
	q.Set("punctuate", "true")
	q.Set("smart_format", "true")
	q.Set("mip_opt_out", "true")
	return q
}

// Client is a minimal, dependency-free REST client for POST /v1/listen.
// Safe for concurrent use.
type Client struct {
	httpc   *http.Client
	apiKey  string
	baseURL string
}

// New builds a Client. baseURL empty → DefaultBaseURL. The HTTP timeout
// covers the whole synchronous transcription: Deepgram processes at
// >100× realtime and hard-caps processing at 10 min server-side; 330 s
// client-side leaves one internal retry inside the function's 540 s
// budget (docs/39 D1).
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
// Deepgram fetches it directly; we never stream the bytes) and returns
// the parsed transcript. Retries once on 429/5xx with a short backoff;
// every other failure surfaces immediately for the caller to classify.
func (c *Client) Transcribe(ctx context.Context, audioURL string, p Params) (*Result, error) {
	body, err := json.Marshal(map[string]string{"url": audioURL})
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}
	endpoint := c.baseURL + "/v1/listen?" + buildQuery(p).Encode()

	var lastErr error
	for attempt := 0; attempt < 2; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(2 * time.Second):
			}
		}
		res, err := c.do(ctx, endpoint, body)
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

func (c *Client) do(ctx context.Context, endpoint string, body []byte) (*Result, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Token "+c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpc.Do(req)
	if err != nil {
		return nil, fmt.Errorf("deepgram request: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	// Transcript payloads for a 60-min session run low single-digit MB;
	// bound the read anyway so a misbehaving response can't OOM the
	// function.
	const maxBody = 64 << 20
	raw, err := io.ReadAll(io.LimitReader(resp.Body, maxBody))
	if err != nil {
		return nil, fmt.Errorf("deepgram read body: %w", err)
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
	// Transport error (timeout, connection reset). One retry is cheap
	// relative to failing the whole Pub/Sub attempt.
	return true
}

func truncate(s string, n int) string {
	if len(s) > n {
		return s[:n] + "...(truncated)"
	}
	return s
}
