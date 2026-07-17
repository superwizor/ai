package sttworker

import (
	"context"
	"testing"

	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/deepgram"
)

func TestDeepgramLanguage(t *testing.T) {
	cases := []struct{ in, want string }{
		{"pl-PL", "pl"},
		{"en-US", "en"},
		{"de-DE", "de"},
		{"pl", "pl"},
		{"PL", "pl"},
		{"", "pl"}, // v1 default — Polish-only product
	}
	for _, c := range cases {
		if got := deepgramLanguage(c.in); got != c.want {
			t.Errorf("deepgramLanguage(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

// TestResolveSTTProvider covers the env-driven resolution (the
// allowlist DB path needs a live pool and is exercised in e2e).
func TestResolveSTTProvider(t *testing.T) {
	ctx := context.Background()

	// No client wired → always chirp, whatever the flag says.
	dgClient = nil
	t.Setenv("STT_PROVIDER", "deepgram")
	if got := resolveSTTProvider(ctx, "s1"); got != "chirp" {
		t.Errorf("no client: got %q, want chirp", got)
	}

	dgClient = deepgram.New("test-key", deepgram.DefaultBaseURL)
	defer func() { dgClient = nil }()

	t.Setenv("STT_PROVIDER", "deepgram")
	if got := resolveSTTProvider(ctx, "s1"); got != "deepgram" {
		t.Errorf("flag deepgram: got %q", got)
	}

	t.Setenv("STT_PROVIDER", "chirp")
	t.Setenv("STT_PROVIDER_ALLOWLIST", "")
	if got := resolveSTTProvider(ctx, "s1"); got != "chirp" {
		t.Errorf("flag chirp: got %q", got)
	}

	// Unknown value must fail safe to chirp (kill-switch semantics).
	t.Setenv("STT_PROVIDER", "nova")
	if got := resolveSTTProvider(ctx, "s1"); got != "chirp" {
		t.Errorf("unknown flag: got %q", got)
	}

	// Allowlist set but no DB pool in tests → chirp (fail-safe).
	t.Setenv("STT_PROVIDER", "")
	t.Setenv("STT_PROVIDER_ALLOWLIST", "11111111-1111-1111-1111-111111111111")
	if got := resolveSTTProvider(ctx, "s1"); got != "chirp" {
		t.Errorf("allowlist without db: got %q", got)
	}
}
