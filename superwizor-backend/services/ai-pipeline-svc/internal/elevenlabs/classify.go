package elevenlabs

import (
	"errors"
	"fmt"
	"net/http"
)

// APIError is a non-200 response. Body is pre-truncated by the client;
// it never contains transcript text (error responses carry only the
// provider's error envelope).
type APIError struct {
	StatusCode int
	Body       string
}

func (e *APIError) Error() string {
	return fmt.Sprintf("elevenlabs api: status=%d body=%s", e.StatusCode, e.Body)
}

// as is a tiny errors.As adapter shared inside the package.
func as(err error, target **APIError) bool { return errors.As(err, target) }

// Classification maps a Transcribe error onto the pipeline's failure
// semantics (docs/21, same table as the Deepgram path):
//
//	Terminal  → the input/config is bad; every retry returns the same
//	            answer. Session FAILED, ack.
//	Auth      → credential problem (rotated/revoked key). NEVER the
//	            session's fault: NACK + alert, the session waits.
//	Transient → provider/network hiccup. NACK; Pub/Sub retries ≤24 h
//	            (audio lives 48 h), watchdog fallback is the backstop.
type Classification int

const (
	Transient Classification = iota
	Terminal
	Auth
)

// Classify buckets err. Unknown shapes default to Transient — we would
// rather over-retry than permanently kill a recoverable clinical
// session (same bias as the Chirp and Deepgram paths).
//
// One provider-specific wrinkle: a signed URL that has expired, or an
// object that has been reaped, surfaces as 400 "Failed to download the
// file from the provided URL". That is genuinely terminal for THIS
// attempt's URL but not for the session — the watchdog mints a fresh
// URL on resubmit. Classifying it Terminal would fail sessions whose
// only sin was sitting in the queue past the 15-minute TTL, so
// LooksLikeFetchFailure lets the caller keep it Transient.
func Classify(err error) Classification {
	var apiErr *APIError
	if !as(err, &apiErr) {
		return Transient // transport / timeout / parse-side network
	}
	switch apiErr.StatusCode {
	case http.StatusBadRequest, http.StatusUnsupportedMediaType, http.StatusUnprocessableEntity:
		if LooksLikeFetchFailure(apiErr) {
			return Transient
		}
		return Terminal
	case http.StatusUnauthorized, http.StatusForbidden:
		return Auth
	}
	return Transient
}

// LooksLikeFetchFailure reports whether a 4xx is the provider telling us
// it could not download source_url, rather than that our request was
// malformed. Matched on the stable part of the message observed
// 2026-07-31: "Failed to download the file from the provided URL".
func LooksLikeFetchFailure(err error) bool {
	var apiErr *APIError
	if !as(err, &apiErr) {
		return false
	}
	return containsFold(apiErr.Body, "failed to download the file")
}

// containsFold is a tiny case-insensitive substring check; avoids
// pulling strings.ToLower over a 512-byte body twice.
func containsFold(haystack, needleLower string) bool {
	h := []byte(haystack)
	n := []byte(needleLower)
	if len(n) == 0 || len(h) < len(n) {
		return false
	}
	lower := func(b byte) byte {
		if b >= 'A' && b <= 'Z' {
			return b + 32
		}
		return b
	}
	for i := 0; i+len(n) <= len(h); i++ {
		ok := true
		for j := range n {
			if lower(h[i+j]) != n[j] {
				ok = false
				break
			}
		}
		if ok {
			return true
		}
	}
	return false
}
