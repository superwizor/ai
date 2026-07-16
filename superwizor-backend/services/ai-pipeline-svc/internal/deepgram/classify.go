package deepgram

import (
	"errors"
	"fmt"
	"net/http"
)

// APIError is a non-200 response from Deepgram. Body is pre-truncated
// by the client; it never contains transcript text (error responses
// carry only the provider's error envelope).
type APIError struct {
	StatusCode int
	Body       string
}

func (e *APIError) Error() string {
	return fmt.Sprintf("deepgram api: status=%d body=%s", e.StatusCode, e.Body)
}

// as is a tiny errors.As adapter shared inside the package.
func as(err error, target **APIError) bool { return errors.As(err, target) }

// Classification maps a Transcribe error onto the pipeline's failure
// semantics (docs/21 via docs/39 §Faza1 pkt 5):
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

// Classify buckets err. Unknown shapes default to Transient — we'd
// rather over-retry than permanently kill a recoverable clinical
// session (same bias as isTerminalSTTError on the Chirp path).
func Classify(err error) Classification {
	var apiErr *APIError
	if !as(err, &apiErr) {
		return Transient // transport / timeout / parse-side network
	}
	switch apiErr.StatusCode {
	case http.StatusBadRequest, http.StatusUnsupportedMediaType, http.StatusUnprocessableEntity:
		return Terminal
	case http.StatusUnauthorized, http.StatusForbidden:
		return Auth
	}
	return Transient
}
