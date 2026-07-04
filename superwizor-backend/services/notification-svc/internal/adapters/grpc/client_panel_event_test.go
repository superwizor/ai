package grpc

import "testing"

// The client-panel inbox copy is PHI-free by contract (docs/39): it must
// never interpolate a client name, note title, or content — only a generic
// localized signal. These tests pin the copy and the pl-default fallback.

func TestLocalizeItemShared(t *testing.T) {
	cases := []struct {
		locale, kind   string
		wantTitle      string
		wantBodySubstr string
	}{
		{"pl", "SESSION", "Nowość w Twoim panelu", "nową sesję"},
		{"pl", "NOTE", "Nowość w Twoim panelu", "nową notatkę"},
		{"pl", "", "Nowość w Twoim panelu", "nową pozycję"},
		{"en", "SESSION", "New in your panel", "a new session"},
		{"en-US", "NOTE", "New in your panel", "a new note"},
		{"", "SESSION", "Nowość w Twoim panelu", "nową sesję"}, // empty locale → pl
	}
	for _, c := range cases {
		title, body := localizeItemShared(c.locale, c.kind)
		if title != c.wantTitle {
			t.Errorf("localizeItemShared(%q,%q) title = %q, want %q", c.locale, c.kind, title, c.wantTitle)
		}
		if !contains(body, c.wantBodySubstr) {
			t.Errorf("localizeItemShared(%q,%q) body = %q, want substring %q", c.locale, c.kind, body, c.wantBodySubstr)
		}
	}
}

func TestLocalizeClientNoteReceived(t *testing.T) {
	if title, _ := localizeClientNoteReceived("pl"); title != "Nowa notatka klienta" {
		t.Errorf("pl title = %q", title)
	}
	if title, _ := localizeClientNoteReceived("en"); title != "New client note" {
		t.Errorf("en title = %q", title)
	}
	// Empty locale falls back to pl.
	if title, _ := localizeClientNoteReceived(""); title != "Nowa notatka klienta" {
		t.Errorf("default title = %q", title)
	}
}

func contains(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
