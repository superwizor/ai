package sttworker

import (
	"context"
	"testing"

	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/deepgram"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/elevenlabs"
)

func withClients(t *testing.T, dg, el bool) {
	t.Helper()
	if dg {
		dgClient = deepgram.New("k", deepgram.DefaultBaseURL)
	} else {
		dgClient = nil
	}
	if el {
		elClient = elevenlabs.New("k", elevenlabs.DefaultBaseURL)
	} else {
		elClient = nil
	}
	t.Cleanup(func() { dgClient, elClient = nil, nil })
}

func TestResolveSTTProvider_ElevenLabs(t *testing.T) {
	ctx := context.Background()

	t.Run("flaga elevenlabs bez klienta wraca na chirp", func(t *testing.T) {
		withClients(t, false, false)
		t.Setenv("STT_PROVIDER", "elevenlabs")
		if got := resolveSTTProvider(ctx, "s1"); got != providerChirp {
			t.Errorf("got %q, want chirp — flaga nie moze byc powodem, ze sesja sie nie transkrybuje", got)
		}
	})

	t.Run("flaga elevenlabs z klientem", func(t *testing.T) {
		withClients(t, false, true)
		t.Setenv("STT_PROVIDER", "elevenlabs")
		t.Setenv("STT_PROVIDER_ALLOWLIST", "")
		if got := resolveSTTProvider(ctx, "s1"); got != providerElevenLabs {
			t.Errorf("got %q, want elevenlabs", got)
		}
	})

	t.Run("wielkosc liter i spacje bez znaczenia", func(t *testing.T) {
		withClients(t, false, true)
		t.Setenv("STT_PROVIDER", "  ElevenLabs  ")
		t.Setenv("STT_PROVIDER_ALLOWLIST", "")
		if got := resolveSTTProvider(ctx, "s1"); got != providerElevenLabs {
			t.Errorf("got %q, want elevenlabs", got)
		}
	})
}

// To jest pulapka opisana w docs/59 Faza 1 krok 7. Stara implementacja
// miala w galezi allowlisty doslowne `return "deepgram"`, wiec canary
// dla ElevenLabs wysylalby ruch do Deepgrama — czyli do silnika, od
// ktorego uciekamy. Cel canary jest teraz jawny.
func TestResolveSTTProvider_CanaryTargetIsExplicit(t *testing.T) {
	ctx := context.Background()

	t.Run("allowlista bez canary jest bezczynna", func(t *testing.T) {
		withClients(t, true, true)
		t.Setenv("STT_PROVIDER", "chirp")
		t.Setenv("STT_PROVIDER_ALLOWLIST", "11111111-1111-1111-1111-111111111111")
		t.Setenv("STT_PROVIDER_CANARY", "")
		if got := resolveSTTProvider(ctx, "s1"); got != providerChirp {
			t.Errorf("got %q — sama allowlista nie moze nikogo nigdzie przekierowac", got)
		}
	})

	t.Run("nieznany canary jest ignorowany, nie zgadywany", func(t *testing.T) {
		withClients(t, true, true)
		t.Setenv("STT_PROVIDER", "chirp")
		t.Setenv("STT_PROVIDER_ALLOWLIST", "11111111-1111-1111-1111-111111111111")
		t.Setenv("STT_PROVIDER_CANARY", "nova")
		if got := resolveSTTProvider(ctx, "s1"); got != providerChirp {
			t.Errorf("got %q, want chirp", got)
		}
	})

	t.Run("canary bez wpietego klienta jest ignorowany", func(t *testing.T) {
		withClients(t, true, false) // elevenlabs NIE wpiety
		t.Setenv("STT_PROVIDER", "deepgram")
		t.Setenv("STT_PROVIDER_ALLOWLIST", "11111111-1111-1111-1111-111111111111")
		t.Setenv("STT_PROVIDER_CANARY", "elevenlabs")
		if got := resolveSTTProvider(ctx, "s1"); got != providerDeepgram {
			t.Errorf("got %q, want deepgram (default) — canary bez klucza nie moze przejac ruchu", got)
		}
	})

	// Bez puli DB nie da sie sprawdzic, czy sesja jest na liscie, wiec
	// wracamy do DEFAULTA — a nie do chirpa. Stara implementacja twardo
	// wracala na chirp, co przy defaultzie elevenlabs oznaczaloby ciche
	// zdegradowanie kazdej sesji do silnika bez diaryzacji polskiego.
	t.Run("brak DB wraca do defaulta, nie do chirpa", func(t *testing.T) {
		withClients(t, false, true)
		t.Setenv("STT_PROVIDER", "elevenlabs")
		t.Setenv("STT_PROVIDER_ALLOWLIST", "11111111-1111-1111-1111-111111111111")
		t.Setenv("STT_PROVIDER_CANARY", "deepgram")
		if got := resolveSTTProvider(ctx, "s1"); got != providerElevenLabs {
			t.Errorf("got %q, want elevenlabs", got)
		}
	})
}

func TestNormalizeProvider(t *testing.T) {
	cases := []struct{ in, want string }{
		{"", providerChirp},
		{"chirp", providerChirp},
		{"deepgram", providerDeepgram},
		{"elevenlabs", providerElevenLabs},
		{"ELEVENLABS", providerElevenLabs},
		{" deepgram ", providerDeepgram},
		{"chirp3", ""}, // czesta pomylka — musi byc odrzucona, nie zgadnieta
		{"nova", ""},
		{"scribe", ""},
	}
	for _, c := range cases {
		if got := normalizeProvider(c.in); got != c.want {
			t.Errorf("normalizeProvider(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestElevenLabsLanguage(t *testing.T) {
	cases := []struct{ in, want string }{
		{"pl-PL", "pol"},
		{"pl", "pol"},
		{"PL", "pol"},
		{"en-US", "eng"},
		{"de-DE", "deu"},
		{"uk-UA", "ukr"},
		// Pusty tag NIE domysla sie polskiego (docs/59 D7): sesje sprzed
		// feat/llm-optimisation nie maja language_code, a wymuszenie zlego
		// jezyka to dokladnie to, co kazalo nova-3 zwrocic zero slow na
		// angielskim nagraniu. Puste = autodetekcja.
		{"", ""},
		{"zz-ZZ", ""}, // nieznany — lepiej nic niz zla podpowiedz
	}
	for _, c := range cases {
		if got := elevenLabsLanguage(c.in); got != c.want {
			t.Errorf("elevenLabsLanguage(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}
