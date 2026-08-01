package logging

import (
	"encoding/json"
	"log/slog"
	"testing"
)

func TestCloudSeverity(t *testing.T) {
	cases := []struct {
		lvl  slog.Level
		want string
	}{
		{slog.LevelDebug, "DEBUG"},
		{slog.LevelInfo, "INFO"},
		{slog.LevelWarn, "WARNING"},
		{slog.LevelError, "ERROR"},
		// Poziomy niestandardowe nie moga wypasc poza mape — inaczej
		// wracamy do stanu "brak severity", ktory naprawiamy.
		{slog.LevelInfo + 1, "INFO"},
		{slog.LevelWarn + 1, "WARNING"},
		{slog.LevelError + 8, "CRITICAL"},
	}
	for _, c := range cases {
		if got := cloudSeverity(c.lvl); got != c.want {
			t.Errorf("cloudSeverity(%v) = %q, chcemy %q", c.lvl, got, c.want)
		}
	}
}

// Test kontraktu z Cloud Logging: pole musi nazywac sie dokladnie
// "severity", a "level" ma zniknac. Kazde inne nazewnictwo jest przez
// Cloud Logging ignorowane, wiec logger.Error laduje jako DEFAULT.
func TestReplace_EmitsSeverityNotLevel(t *testing.T) {
	a := replace(nil, slog.Any(slog.LevelKey, slog.LevelError))
	if a.Key != "severity" {
		t.Fatalf("klucz = %q, chcemy severity", a.Key)
	}
	if a.Value.String() != "ERROR" {
		t.Errorf("wartosc = %q, chcemy ERROR", a.Value.String())
	}
}

// Pole msg MUSI zostac nietkniete. infra/modules/monitoring dopasowuje
// alerty po jsonPayload.msg ("status mirror written", "invalidating fcm
// token"); przemianowanie na Cloud-Loggingowe "message" zepsulo by je po
// cichu — czyli dokladnie ta sama klasa bledu, ktora naprawiamy.
func TestReplace_LeavesMessageKeyAlone(t *testing.T) {
	a := replace(nil, slog.String(slog.MessageKey, "status mirror written"))
	if a.Key != slog.MessageKey {
		t.Fatalf("klucz wiadomosci zmieniony na %q — alerty w monitoringu przestana dzialac", a.Key)
	}
}

func TestReplace_PassesThroughOtherAttrs(t *testing.T) {
	a := replace(nil, slog.Int("word_count", 8535))
	if a.Key != "word_count" || a.Value.Int64() != 8535 {
		t.Errorf("atrybut zmieniony: %+v", a)
	}
}

// Pelny obieg: to, co faktycznie leci na stdout, musi byc JSON-em
// z severity i msg jednoczesnie.
func TestHandlerOutputShape(t *testing.T) {
	var buf []byte
	h := slog.NewJSONHandler(writerFunc(func(p []byte) (int, error) {
		buf = append(buf, p...)
		return len(p), nil
	}), &slog.HandlerOptions{ReplaceAttr: replace})

	slog.New(h).Error("stt_low_coverage", "coverage", 0.245, "session_id", "abc")

	var m map[string]any
	if err := json.Unmarshal(buf, &m); err != nil {
		t.Fatalf("wyjscie nie jest JSON-em: %v (%s)", err, buf)
	}
	if m["severity"] != "ERROR" {
		t.Errorf("severity = %v, chcemy ERROR — bez tego alert na straznika pokrycia nie odpali", m["severity"])
	}
	if _, ok := m["level"]; ok {
		t.Error("pole level zostalo — Cloud Logging je zignoruje, a my dublujemy informacje")
	}
	if m["msg"] != "stt_low_coverage" {
		t.Errorf("msg = %v", m["msg"])
	}
	if m["coverage"] != 0.245 {
		t.Errorf("atrybut coverage zgubiony: %v", m["coverage"])
	}
}

type writerFunc func([]byte) (int, error)

func (f writerFunc) Write(p []byte) (int, error) { return f(p) }
