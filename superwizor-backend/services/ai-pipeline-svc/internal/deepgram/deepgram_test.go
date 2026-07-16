package deepgram

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// TestQueryAlwaysOptsOut is the privacy invariant (docs/39 §5): every
// request query MUST carry mip_opt_out=true regardless of params. If
// this test fails, therapy audio would feed Deepgram's Model
// Improvement Program — do not "fix" the test.
func TestQueryAlwaysOptsOut(t *testing.T) {
	for _, p := range []Params{{}, {Language: "pl"}, {Language: "en"}} {
		q := buildQuery(p)
		if q.Get("mip_opt_out") != "true" {
			t.Fatalf("mip_opt_out missing for params %+v: %s", p, q.Encode())
		}
		if q.Get("model") != "nova-3" {
			t.Fatalf("model pin lost for params %+v: %s", p, q.Encode())
		}
		if q.Get("diarize") != "true" {
			t.Fatalf("diarize pin lost for params %+v: %s", p, q.Encode())
		}
	}
}

func TestIsEUEndpoint(t *testing.T) {
	cases := []struct {
		url  string
		want bool
	}{
		{"https://api.eu.deepgram.com", true},
		{"https://api.eu.deepgram.com/", true},
		{"https://api.deepgram.com", false},   // US default — forbidden
		{"http://api.eu.deepgram.com", false}, // plaintext — forbidden
		{"https://evil.com/api.eu.deepgram.com", false},
		{"https://api.eu.deepgram.com.evil.com", false},
		{"", false},
	}
	for _, c := range cases {
		if got := IsEUEndpoint(c.url); got != c.want {
			t.Errorf("IsEUEndpoint(%q) = %v, want %v", c.url, got, c.want)
		}
	}
}

// fixture is a hand-built minimal /v1/listen response: two speakers,
// punctuated words, one word without a speaker field. Shape per
// https://developers.deepgram.com/docs/pre-recorded-audio.
const fixture = `{
  "metadata": {"request_id": "req-123", "duration": 12.5},
  "results": {"channels": [{
    "detected_language": "pl",
    "alternatives": [{
      "transcript": "Z czym dzisiaj przychodzisz? Trochę zmęczona.",
      "confidence": 0.97,
      "words": [
        {"word": "z", "punctuated_word": "Z", "start": 0.10, "end": 0.20, "confidence": 0.99, "speaker": 0, "speaker_confidence": 0.9},
        {"word": "czym", "punctuated_word": "czym", "start": 0.25, "end": 0.55, "confidence": 0.98, "speaker": 0, "speaker_confidence": 0.9},
        {"word": "przychodzisz", "punctuated_word": "przychodzisz?", "start": 0.60, "end": 1.30, "confidence": 0.97, "speaker": 0, "speaker_confidence": 0.9},
        {"word": "trochę", "punctuated_word": "Trochę", "start": 2.00, "end": 2.40, "confidence": 0.96, "speaker": 1, "speaker_confidence": 0.8},
        {"word": "zmęczona", "punctuated_word": "zmęczona.", "start": 2.45, "end": 3.05, "confidence": 0.95, "speaker": 1, "speaker_confidence": 0.8},
        {"word": "mhm", "start": 3.50, "end": 3.60, "confidence": 0.40}
      ]
    }]
  }]}
}`

func TestParse(t *testing.T) {
	res, err := Parse([]byte(fixture))
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if res.RequestID != "req-123" {
		t.Errorf("RequestID = %q", res.RequestID)
	}
	if res.LanguageCode != "pl" {
		t.Errorf("LanguageCode = %q", res.LanguageCode)
	}
	if res.WordCount != 6 {
		t.Fatalf("WordCount = %d, want 6", res.WordCount)
	}
	if res.SpeakerCount != 2 {
		t.Errorf("SpeakerCount = %d, want 2 (speakers 0,1 → labels 1,2)", res.SpeakerCount)
	}
	// 0-based speaker → 1-based numeric label (Chirp convention).
	if got := res.Words[0].SpeakerLabel; got != "1" {
		t.Errorf("word0 label = %q, want \"1\"", got)
	}
	if got := res.Words[3].SpeakerLabel; got != "2" {
		t.Errorf("word3 label = %q, want \"2\"", got)
	}
	// Word without a speaker field stays unlabeled.
	if got := res.Words[5].SpeakerLabel; got != "" {
		t.Errorf("word5 label = %q, want \"\"", got)
	}
	// punctuated_word preferred; fallback to word when absent.
	if got := res.Words[2].Text; got != "przychodzisz?" {
		t.Errorf("word2 text = %q", got)
	}
	if got := res.Words[5].Text; got != "mhm" {
		t.Errorf("word5 text = %q", got)
	}
	// Seconds → milliseconds.
	if res.Words[0].StartMS != 100 || res.Words[0].EndMS != 200 {
		t.Errorf("word0 offsets = %d..%d, want 100..200", res.Words[0].StartMS, res.Words[0].EndMS)
	}
	if res.AudioDurationSec != 12.5 {
		t.Errorf("AudioDurationSec = %v", res.AudioDurationSec)
	}
}

func TestParse_RejectsEmptyShape(t *testing.T) {
	if _, err := Parse([]byte(`{"results":{"channels":[]}}`)); err == nil {
		t.Fatal("expected error on empty channels")
	}
	if _, err := Parse([]byte(`not json`)); err == nil {
		t.Fatal("expected error on malformed json")
	}
}

func TestClassify(t *testing.T) {
	cases := []struct {
		err  error
		want Classification
	}{
		{&APIError{StatusCode: 400}, Terminal},
		{&APIError{StatusCode: 415}, Terminal},
		{&APIError{StatusCode: 422}, Terminal},
		{&APIError{StatusCode: 401}, Auth},
		{&APIError{StatusCode: 403}, Auth},
		{&APIError{StatusCode: 429}, Transient},
		{&APIError{StatusCode: 500}, Transient},
		{&APIError{StatusCode: 504}, Transient},
		{context.DeadlineExceeded, Transient},
	}
	for _, c := range cases {
		if got := Classify(c.err); got != c.want {
			t.Errorf("Classify(%v) = %v, want %v", c.err, got, c.want)
		}
	}
}

// TestTranscribe_EndToEnd drives the client against a local fake and
// asserts the auth header, the request body ({"url": ...}) and that
// the privacy query params reach the wire.
func TestTranscribe_EndToEnd(t *testing.T) {
	var gotAuth, gotQuery, gotBody string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		gotQuery = r.URL.RawQuery
		b := make([]byte, r.ContentLength)
		_, _ = r.Body.Read(b)
		gotBody = string(b)
		_, _ = w.Write([]byte(fixture))
	}))
	defer srv.Close()

	c := New("test-key", srv.URL)
	res, err := c.Transcribe(context.Background(), "https://signed.example/audio.flac", Params{Language: "pl"})
	if err != nil {
		t.Fatalf("Transcribe: %v", err)
	}
	if res.WordCount != 6 {
		t.Errorf("WordCount = %d", res.WordCount)
	}
	if gotAuth != "Token test-key" {
		t.Errorf("Authorization = %q", gotAuth)
	}
	if !strings.Contains(gotQuery, "mip_opt_out=true") {
		t.Errorf("query missing mip_opt_out: %s", gotQuery)
	}
	if !strings.Contains(gotQuery, "language=pl") || !strings.Contains(gotQuery, "model=nova-3") {
		t.Errorf("query missing pins: %s", gotQuery)
	}
	if !strings.Contains(gotBody, `"url":"https://signed.example/audio.flac"`) {
		t.Errorf("body = %s", gotBody)
	}
}

// TestTranscribe_RetriesOn5xx: first attempt 503, second succeeds.
func TestTranscribe_RetriesOn5xx(t *testing.T) {
	attempts := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		attempts++
		if attempts == 1 {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte(fixture))
	}))
	defer srv.Close()

	c := New("k", srv.URL)
	if _, err := c.Transcribe(context.Background(), "https://x/a.flac", Params{Language: "pl"}); err != nil {
		t.Fatalf("Transcribe after retry: %v", err)
	}
	if attempts != 2 {
		t.Errorf("attempts = %d, want 2", attempts)
	}
}

// TestTranscribe_NoRetryOnTerminal: a 400 must fail immediately
// (retrying a bad request just re-bills the provider).
func TestTranscribe_NoRetryOnTerminal(t *testing.T) {
	attempts := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		attempts++
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"err_msg":"bad"}`))
	}))
	defer srv.Close()

	c := New("k", srv.URL)
	_, err := c.Transcribe(context.Background(), "https://x/a.flac", Params{})
	if err == nil {
		t.Fatal("expected error")
	}
	if Classify(err) != Terminal {
		t.Errorf("Classify = %v, want Terminal", Classify(err))
	}
	if attempts != 1 {
		t.Errorf("attempts = %d, want 1 (no retry on 4xx)", attempts)
	}
}
