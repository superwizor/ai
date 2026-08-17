package elevenlabs

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
)

// ── kontrakt prywatnosci ──────────────────────────────────────────────

func TestIsEUEndpoint(t *testing.T) {
	cases := []struct {
		url  string
		want bool
	}{
		{"https://api.eu.residency.elevenlabs.io", true},
		{"https://eu.residency.elevenlabs.io", false}, // nie ten host
		{"https://api.elevenlabs.io", false},          // globalny — dane wyjda poza UE
		{"http://api.eu.residency.elevenlabs.io", false}, // bez TLS
		{"https://api.eu.residency.elevenlabs.io.evil.tld", false},
		{"", false},
		{"://broken", false},
	}
	for _, c := range cases {
		if got := IsEUEndpoint(c.url); got != c.want {
			t.Errorf("IsEUEndpoint(%q) = %v, chcemy %v", c.url, got, c.want)
		}
	}
}

func TestDefaultBaseURLIsEUResident(t *testing.T) {
	if !IsEUEndpoint(DefaultBaseURL) {
		t.Fatalf("DefaultBaseURL %q nie przechodzi wlasnej bramki EU", DefaultBaseURL)
	}
}

// TestBuildFields pilnuje decyzji z docs/59 D8/D9. Kazda z nich znika
// przy nieuwaznym refaktorze i zadna nie objawia sie bledem — tylko
// cichsza zmiana zachowania na produkcji.
func TestBuildFields(t *testing.T) {
	f := buildFields(Params{Language: "pol"}, "https://signed.example/a.flac")

	if f["model_id"] != "scribe_v2" {
		t.Errorf("model_id = %q, chcemy scribe_v2", f["model_id"])
	}
	if f["diarize"] != "true" {
		t.Errorf("diarize = %q — bez tego nie ma rozdzielenia terapeuty i klienta", f["diarize"])
	}
	if f["timestamps_granularity"] != "word" {
		t.Errorf("timestamps_granularity = %q, chcemy word", f["timestamps_granularity"])
	}
	if f["tag_audio_events"] != "false" {
		t.Errorf("tag_audio_events = %q — D8 mowi false do czasu decyzji produktowej", f["tag_audio_events"])
	}
	if _, ok := f["num_speakers"]; ok {
		t.Error("num_speakers nie moze byc ustawiane (D9): nie wiemy, ile osob jest w gabinecie")
	}
	if f["source_url"] != "https://signed.example/a.flac" {
		t.Errorf("source_url = %q", f["source_url"])
	}
	if f["language_code"] != "pol" {
		t.Errorf("language_code = %q", f["language_code"])
	}

	// Pusty jezyk to prawidlowy stan (D7), a nie pole do wyslania pustkiem.
	if _, ok := buildFields(Params{}, "u")["language_code"]; ok {
		t.Error("puste Language nie moze trafic do zadania jako pusty language_code")
	}
}

// ── parser ────────────────────────────────────────────────────────────

// TestParse_IgnoresNonWordEntries to najwazniejszy test parsera.
// words[] miesza slowa z wpisami "spacing" (w 26-minutowym nagraniu bylo
// ich 3252 obok 3256 slow) i "audio_event". Brak filtra podwaja kazdy
// licznik i wstrzykuje puste tokeny do transkryptu.
func TestParse_IgnoresNonWordEntries(t *testing.T) {
	raw := []byte(`{
	  "language_code":"pol","language_probability":1.0,
	  "transcription_id":"tid-1","audio_duration_secs":10.0,
	  "words":[
	    {"text":"Dzień","start":1.0,"end":1.4,"type":"word","speaker_id":"speaker_0","logprob":-0.01},
	    {"text":" ","start":1.4,"end":1.45,"type":"spacing","speaker_id":"speaker_0","logprob":-0.0},
	    {"text":"dobry","start":1.45,"end":1.9,"type":"word","speaker_id":"speaker_0","logprob":-0.02},
	    {"text":"(śmiech)","start":2.0,"end":2.5,"type":"audio_event","speaker_id":"speaker_1","logprob":-0.3}
	  ]}`)

	res, err := Parse(raw)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if res.WordCount != 2 {
		t.Fatalf("WordCount = %d, chcemy 2 (spacing i audio_event nie sa slowami)", res.WordCount)
	}
	for _, w := range res.Words {
		if strings.TrimSpace(w.Text) == "" {
			t.Errorf("pusty token trafil do transkryptu: %+v", w)
		}
		if w.Text == "(śmiech)" {
			t.Error("audio_event trafil do transkryptu mimo tag_audio_events=false")
		}
	}
	// audio_event nalezal do speaker_1 — nie moze podbic liczby mowcow.
	if res.SpeakerCount != 1 {
		t.Errorf("SpeakerCount = %d, chcemy 1", res.SpeakerCount)
	}
}

func TestParse_RealResponseFixture(t *testing.T) {
	raw, err := os.ReadFile("testdata/scribe_pl_2speakers.json")
	if err != nil {
		t.Fatalf("fixture: %v", err)
	}
	res, err := Parse(raw)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if res.WordCount == 0 {
		t.Fatal("prawdziwa odpowiedz dala zero slow")
	}
	if res.RequestID == "" {
		t.Error("RequestID pusty — bez niego nie ma czego wpisac w stt_operations.request_id")
	}
	if res.AudioDurationSec <= 0 {
		t.Error("AudioDurationSec <= 0 — straznik pokrycia nie ma mianownika")
	}
	if res.LanguageCode != "pol" {
		t.Errorf("LanguageCode = %q, chcemy pol", res.LanguageCode)
	}
	// Kazde slowo musi miec sensowna ramke czasowa i etykiete 1-based.
	for _, w := range res.Words {
		if w.EndMS < w.StartMS {
			t.Errorf("odwrocona ramka: %+v", w)
		}
		if w.SpeakerLabel != "" && w.SpeakerLabel[0] == '0' {
			t.Errorf("etykieta mowcy 0-based przeciekla do wyjscia: %q", w.SpeakerLabel)
		}
	}
}

func TestParse_SpeakerLabelMapping(t *testing.T) {
	cases := []struct{ in, want string }{
		{"speaker_0", "1"},
		{"speaker_1", "2"},
		{"speaker_11", "12"},
		{"", ""},
		{"nonsense", ""},   // nieznany ksztalt → brak etykiety
		{"speaker_-1", ""}, // ujemny → brak etykiety
	}
	for _, c := range cases {
		if got := speakerLabel(c.in); got != c.want {
			t.Errorf("speakerLabel(%q) = %q, chcemy %q", c.in, got, c.want)
		}
	}
}

func TestParse_DropsImplausibleTimestamps(t *testing.T) {
	raw := []byte(`{"audio_duration_secs":10,"words":[
	  {"text":"ok","start":1,"end":2,"type":"word","speaker_id":"speaker_0"},
	  {"text":"zly","start":5,"end":4,"type":"word","speaker_id":"speaker_0"},
	  {"text":"kosmos","start":0,"end":90000,"type":"word","speaker_id":"speaker_0"}
	]}`)
	res, err := Parse(raw)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if res.WordCount != 1 {
		t.Errorf("WordCount = %d, chcemy 1", res.WordCount)
	}
	if res.DroppedWords() != 2 {
		t.Errorf("DroppedWords = %d, chcemy 2", res.DroppedWords())
	}
}

func TestParse_RejectsResponseWithoutWordsArray(t *testing.T) {
	if _, err := Parse([]byte(`{"audio_duration_secs":10}`)); err == nil {
		t.Fatal("odpowiedz bez words[] musi byc bledem parsowania, nie pustym transkryptem")
	}
	// Pusta, ale obecna tablica to legalna odpowiedz "cisza" — o jej
	// losie decyduje straznik pokrycia, nie parser.
	if _, err := Parse([]byte(`{"audio_duration_secs":10,"words":[]}`)); err != nil {
		t.Fatalf("pusta tablica words[] nie moze byc bledem parsowania: %v", err)
	}
}

func TestParse_ConfidenceInRange(t *testing.T) {
	raw := []byte(`{"audio_duration_secs":10,"words":[
	  {"text":"a","start":1,"end":2,"type":"word","logprob":-0.001},
	  {"text":"b","start":2,"end":3,"type":"word","logprob":-200},
	  {"text":"c","start":3,"end":4,"type":"word","logprob":0.5}
	]}`)
	res, err := Parse(raw)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	for _, w := range res.Words {
		if w.Confidence < 0 || w.Confidence > 1 {
			t.Errorf("Confidence poza [0,1]: %v dla %q", w.Confidence, w.Text)
		}
	}
	if res.ConfidenceAvg < 0 || res.ConfidenceAvg > 1 {
		t.Errorf("ConfidenceAvg poza [0,1]: %v", res.ConfidenceAvg)
	}
}

// ── straznik pokrycia (docs/59 §6.1) ──────────────────────────────────

func mkResult(durSec float64, endsMS ...int64) *Result {
	r := &Result{AudioDurationSec: durSec}
	for _, e := range endsMS {
		r.Words = append(r.Words, chunker.Word{Text: "x", StartMS: e - 100, EndMS: e})
	}
	r.WordCount = len(r.Words)
	return r
}

// To jest scenariusz, ktory wysadzil Deepgrama: 62,07 s nagrania,
// 13 slow, ostatnie na 15,2 s. Pipeline zapisal to jako COMPLETED.
func TestCheckCoverage_Nova3TruncationIsRejected(t *testing.T) {
	r := mkResult(62.07, 15200)
	v, c := r.CheckCoverage()
	if v != CoverageReject {
		t.Fatalf("verdict = %v (pokrycie %.3f), chcemy reject — to dokladnie ten ksztalt awarii, "+
			"ktory przeszedl przez cala walidacje Fazy 2 niezauwazony", v, c)
	}
}

func TestCheckCoverage_Verdicts(t *testing.T) {
	cases := []struct {
		name    string
		r       *Result
		want    CoverageVerdict
		wantMin float64
	}{
		{"pelne pokrycie", mkResult(62.07, 62000), CoverageAccept, 0.95},
		{"na progu 95%", mkResult(100, 95000), CoverageAccept, 0.95},
		{"tuz pod progiem", mkResult(100, 94000), CoverageDegraded, 0.50},
		{"polowa nagrania", mkResult(100, 50000), CoverageDegraded, 0.50},
		{"cwierc nagrania", mkResult(100, 25000), CoverageReject, 0},
		{"zero slow", mkResult(820.3), CoverageReject, 0},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			v, got := c.r.CheckCoverage()
			if v != c.want {
				t.Errorf("verdict = %v, chcemy %v (pokrycie %.3f)", v, c.want, got)
			}
			if got < c.wantMin {
				t.Errorf("pokrycie %.3f < %.3f", got, c.wantMin)
			}
		})
	}
}

// Pusta transkrypcja dla 13-minutowego nagrania to dokladnie to, co
// nova-3 zwrocil przy niezgodnym language_code: HTTP 200, poprawna
// dlugosc, zero slow. Nie wolno tego uznac za sukces.
func TestCheckCoverage_EmptyTranscriptForLongAudioIsRejected(t *testing.T) {
	if v, _ := mkResult(820.3).CheckCoverage(); v != CoverageReject {
		t.Fatalf("verdict = %v, chcemy reject", v)
	}
}

// Krotki klip moze byc naprawde cichy — nie zapetlamy sie na nim.
func TestCheckCoverage_VeryShortAudioIsExempt(t *testing.T) {
	if v, _ := mkResult(2.0).CheckCoverage(); v != CoverageAccept {
		t.Fatalf("verdict = %v, chcemy accept dla klipu < 5 s", v)
	}
}

// Brak dlugosci od dostawcy = brak mianownika. Nie blokujemy sesji na
// metryce, ktorej nie udalo sie zdobyc.
func TestCheckCoverage_NoDurationDoesNotBlock(t *testing.T) {
	r := &Result{Words: []chunker.Word{{EndMS: 1000}}, WordCount: 1}
	if v, _ := r.CheckCoverage(); v != CoverageAccept {
		t.Fatalf("verdict = %v, chcemy accept gdy brak audio_duration_secs", v)
	}
}

// Chirp wyemitowal jedno slowo konczace sie o 8486,92 s w nagraniu
// trwajacym 820 s. Regula oparta na maksimum dala 1034% pokrycia
// i zamaskowalaby transkrypcje uciета do polowy.
func TestCoverage_SingleCorruptTimestampDoesNotInflate(t *testing.T) {
	r := mkResult(820.3, 600_000, 8_486_920)
	if c := r.Coverage(); c > 1.02 {
		t.Fatalf("pokrycie %.3f — pojedynczy uszkodzony znacznik nie moze zawyzac metryki", c)
	}
	if n := r.BogusTimestamps(); n != 1 {
		t.Errorf("BogusTimestamps = %d, chcemy 1", n)
	}
	// 600 s z 820,3 s to 73% — bez odsiania uszkodzonego znacznika
	// metryka pokazalaby 1034% i wyszlaby "accept", maskujac fakt, ze
	// brakuje ostatnich czterech minut nagrania.
	if v, _ := r.CheckCoverage(); v != CoverageDegraded {
		t.Errorf("verdict = %v, chcemy degraded", v)
	}
}

func TestWordsPerSecond(t *testing.T) {
	// Speechmatics na zle otagowanym nagraniu: 99% pokrycia, 0,81 slowa/s.
	r := &Result{AudioDurationSec: 820.3, WordCount: 665}
	if wps := r.WordsPerSecond(); wps < 0.7 || wps > 0.9 {
		t.Errorf("WordsPerSecond = %.2f, chcemy ~0,81", wps)
	}
}

// ── klasyfikacja bledow ───────────────────────────────────────────────

func TestClassify(t *testing.T) {
	cases := []struct {
		name string
		err  error
		want Classification
	}{
		{"400 zla konfiguracja", &APIError{StatusCode: 400, Body: `{"detail":"bad model"}`}, Terminal},
		{"415", &APIError{StatusCode: 415}, Terminal},
		{"422", &APIError{StatusCode: 422}, Terminal},
		{"401 klucz", &APIError{StatusCode: 401}, Auth},
		{"403 klucz", &APIError{StatusCode: 403}, Auth},
		{"429", &APIError{StatusCode: 429}, Transient},
		{"500", &APIError{StatusCode: 500}, Transient},
		{"504", &APIError{StatusCode: 504}, Transient},
		{"blad transportu", fmt.Errorf("dial tcp: timeout"), Transient},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := Classify(c.err); got != c.want {
				t.Errorf("Classify = %v, chcemy %v", got, c.want)
			}
		})
	}
}

// Wygasly signed URL (TTL 15 min) wraca jako 400. Jest terminalny dla
// TEGO url-a, ale nie dla sesji — watchdog podpisze nowy. Uznanie go za
// Terminal zabijaloby sesje, ktorych jedyna wina bylo czekanie w kolejce.
func TestClassify_FetchFailureStaysTransient(t *testing.T) {
	err := &APIError{
		StatusCode: 400,
		Body: `{"detail":{"type":"invalid_request","message":"Failed to download the file ` +
			`from the provided URL (upstream status 400)."}}`,
	}
	if got := Classify(err); got != Transient {
		t.Fatalf("Classify = %v, chcemy Transient — inaczej wygasly URL konczy sesje jako FAILED", got)
	}
	if !LooksLikeFetchFailure(err) {
		t.Error("LooksLikeFetchFailure = false dla komunikatu o nieudanym pobraniu")
	}
}

// ── klient HTTP ───────────────────────────────────────────────────────

func TestTranscribe_SendsExpectedRequest(t *testing.T) {
	var gotKey, gotCT, gotBody string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotKey = r.Header.Get("xi-api-key")
		gotCT = r.Header.Get("Content-Type")
		b, _ := readAll(r)
		gotBody = b
		if r.URL.Path != "/v1/speech-to-text" {
			t.Errorf("sciezka = %q", r.URL.Path)
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"audio_duration_secs": 10.0,
			"transcription_id":    "tid",
			"words": []map[string]any{
				{"text": "test", "start": 0.1, "end": 9.9, "type": "word", "speaker_id": "speaker_0"},
			},
		})
	}))
	defer srv.Close()

	c := New("sekret", srv.URL)
	res, err := c.Transcribe(context.Background(), "https://signed/a.flac", Params{Language: "pol"})
	if err != nil {
		t.Fatalf("Transcribe: %v", err)
	}
	if gotKey != "sekret" {
		t.Errorf("naglowek xi-api-key = %q", gotKey)
	}
	if !strings.HasPrefix(gotCT, "multipart/form-data") {
		t.Errorf("Content-Type = %q, chcemy multipart/form-data", gotCT)
	}
	for _, want := range []string{"scribe_v2", "https://signed/a.flac", "tag_audio_events", "pol"} {
		if !strings.Contains(gotBody, want) {
			t.Errorf("body nie zawiera %q", want)
		}
	}
	if res.WordCount != 1 || res.RequestID != "tid" {
		t.Errorf("Result = %+v", res)
	}
	if v, _ := res.CheckCoverage(); v != CoverageAccept {
		t.Errorf("verdict = %v, chcemy accept", v)
	}
}

func TestTranscribe_RetriesOnceOn5xx(t *testing.T) {
	var calls int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if atomic.AddInt32(&calls, 1) == 1 {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"audio_duration_secs": 10.0,
			"words": []map[string]any{
				{"text": "ok", "start": 0.1, "end": 9.9, "type": "word"},
			},
		})
	}))
	defer srv.Close()

	if _, err := New("k", srv.URL).Transcribe(context.Background(), "u", Params{}); err != nil {
		t.Fatalf("Transcribe: %v", err)
	}
	if got := atomic.LoadInt32(&calls); got != 2 {
		t.Errorf("wywolan = %d, chcemy 2 (jeden retry)", got)
	}
}

func TestTranscribe_DoesNotRetryOn400(t *testing.T) {
	var calls int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&calls, 1)
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"detail":"bad"}`))
	}))
	defer srv.Close()

	_, err := New("k", srv.URL).Transcribe(context.Background(), "u", Params{})
	if err == nil {
		t.Fatal("chcemy blad")
	}
	if got := atomic.LoadInt32(&calls); got != 1 {
		t.Errorf("wywolan = %d, chcemy 1 — powtorka zwrocilaby to samo", got)
	}
	if Classify(err) != Terminal {
		t.Errorf("Classify = %v, chcemy Terminal", Classify(err))
	}
}

// Klucz nie moze wyciec do komunikatu bledu — ten trafia do logow.
func TestAPIError_DoesNotLeakKey(t *testing.T) {
	e := &APIError{StatusCode: 401, Body: `{"detail":"unauthorized"}`}
	if strings.Contains(e.Error(), "sk_") {
		t.Error("komunikat bledu zawiera cos, co wyglada na klucz")
	}
}

func readAll(r *http.Request) (string, error) {
	b := make([]byte, 0, 4096)
	buf := make([]byte, 1024)
	for {
		n, err := r.Body.Read(buf)
		b = append(b, buf[:n]...)
		if err != nil {
			return string(b), nil
		}
	}
}
