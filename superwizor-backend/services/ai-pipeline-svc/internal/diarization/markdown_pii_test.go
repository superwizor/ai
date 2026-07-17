package diarization

import (
	"strings"
	"testing"
)

// docs/41: sekcja # PII w gramatyce role-only — encje wyciągnięte,
// istniejące pola nietknięte, linie śmieciowe tolerowane.
func TestParseMetadataMarkdown_PIISection(t *testing.T) {
	raw := `# Speakers

Speaker 1 — therapist (confidence 0.92)
Speaker 2 — patient (confidence 0.95)

# Metadata

Title: Sesja o pracy
Summary: Klientka opisuje konflikt w pracy.
Overall_diarization_confidence: 0.9

# PII

[NAZWISKO-1]: Nowak | Nowaka | Nowakiem
[PRACODAWCA]: Softex | Softexie
to nie jest linia PII
[]: pusta
[MIEJSCOWOŚĆ-A]: Wrocław`
	res, err := ParseMetadataMarkdown(raw)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(res.Speakers) != 2 || res.Title != "Sesja o pracy" {
		t.Fatalf("existing fields broken: %+v", res)
	}
	if len(res.PIIEntities) != 3 {
		t.Fatalf("PIIEntities = %d, want 3 (%+v)", len(res.PIIEntities), res.PIIEntities)
	}
	if res.PIIEntities[0].Placeholder != "[NAZWISKO-1]" || len(res.PIIEntities[0].Forms) != 3 {
		t.Errorf("entity 0 = %+v", res.PIIEntities[0])
	}
	if res.PIISkippedLines != 2 {
		t.Errorf("PIISkippedLines = %d, want 2 (garbage + empty token)", res.PIISkippedLines)
	}
}

// Brak sekcji # PII → pusta lista, zero błędów (fail-open kontrakt).
func TestParseMetadataMarkdown_NoPIISection(t *testing.T) {
	raw := `# Speakers

Speaker 1 — therapist (confidence 0.9)

# Metadata

Title: T
Summary: S
Overall_diarization_confidence: 0.9`
	res, err := ParseMetadataMarkdown(raw)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(res.PIIEntities) != 0 || res.PIISkippedLines != 0 {
		t.Errorf("expected empty PII state, got %+v", res)
	}
}

func TestParsePIIOnly(t *testing.T) {
	raw := `# PII
[NAZWISKO-1]: Kowalski | Kowalskiego
śmieciowa linia
[SZKOŁA]: SP 5`
	entities, skipped := ParsePIIOnly(raw)
	if len(entities) != 2 || skipped != 1 {
		t.Fatalf("entities=%d skipped=%d, want 2/1 (%+v)", len(entities), skipped, entities)
	}
	// Bez nagłówka też działa (model może pominąć).
	entities2, _ := ParsePIIOnly("[ADRES]: ul. Polna 3")
	if len(entities2) != 1 || !strings.Contains(entities2[0].Forms[0], "Polna") {
		t.Errorf("headerless parse failed: %+v", entities2)
	}
	// Pusta odpowiedź = brak PII.
	if e, s := ParsePIIOnly(""); len(e) != 0 || s != 0 {
		t.Error("empty input must yield nothing")
	}
}
