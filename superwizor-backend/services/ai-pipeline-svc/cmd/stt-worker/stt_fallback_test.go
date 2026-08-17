package sttworker

import "testing"

// Sedno zmiany z 2026-07-31: ElevenLabs NIE spada juz wprost na Chirpa.
// Chirp nie diaryzuje pl-PL, wiec taki fallback oddawal transkrypt bez
// rozdzielenia terapeuty i klienta — degradacja jakosci widoczna dla
// terapeuty, nie samo opoznienie.
func TestNextFallbackProvider_ChainPrefersDeepgramOverChirp(t *testing.T) {
	withClients(t, true, true) // oba klienty wpiete
	if got := nextFallbackProvider(providerElevenLabs); got != providerDeepgram {
		t.Errorf("elevenlabs → %q, chcemy deepgram (Chirp nie diaryzuje polskiego)", got)
	}
	if got := nextFallbackProvider(providerDeepgram); got != providerChirp {
		t.Errorf("deepgram → %q, chcemy chirp", got)
	}
	if got := nextFallbackProvider(providerChirp); got != "" {
		t.Errorf("chirp → %q, chcemy pusty (koniec lancucha)", got)
	}
}

// Deepgram bez wpietego klucza nie moze byc stopniem posrednim —
// inaczej sesja spadalaby na silnik, ktorego nie ma, zamiast na Chirpa.
func TestNextFallbackProvider_SkipsUnavailableDeepgram(t *testing.T) {
	withClients(t, false, true) // deepgram NIE wpiety
	if got := nextFallbackProvider(providerElevenLabs); got != providerChirp {
		t.Errorf("elevenlabs → %q, chcemy chirp gdy deepgram nie ma klienta", got)
	}
}

func TestObjectPathFromURI(t *testing.T) {
	cases := []struct{ in, want string }{
		{"gs://bucket/terapeuta/sesja/1785482361.flac", "terapeuta/sesja/1785482361.flac"},
		{"gs://bucket/plik.flac", "plik.flac"},
		// Watchdog trzyma pelne URI; galezie providerow buduja je z
		// bucketName + ObjectPath, wiec ksztalt jest zawsze taki sam.
		{"gs://bucket", ""},
		{"", ""},
	}
	for _, c := range cases {
		if got := objectPathFromURI(c.in); got != c.want {
			t.Errorf("objectPathFromURI(%q) = %q, chcemy %q", c.in, got, c.want)
		}
	}
}
