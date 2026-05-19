package reportprefs

import (
	"strings"
	"testing"
)

func TestRenderFragment_AllDefaults(t *testing.T) {
	// Empty preferences → empty fragment. Critical — preserves
	// byte-identical prompt for users who never configured.
	got := RenderFragment(Preferences{})
	if got != "" {
		t.Fatalf("expected empty fragment for default preferences, got:\n%s", got)
	}
}

func TestRenderFragment_StandardValuesAreImplicit(t *testing.T) {
	// Picking the "default" enum (e.g. tone=clinical_formal) is
	// indistinguishable from "no preference" — both produce empty
	// fragment. This keeps the prompt minimal.
	p := Preferences{
		Length:             "standard",
		Tone:               "clinical_formal",
		QuoteDensity:       "selective",
		DiagnosticLanguage: "descriptive",
		HypothesisHedging:  "tentative",
		StrengthsFraming:   "problem_focused",
	}
	if got := RenderFragment(p); got != "" {
		t.Fatalf("expected empty fragment when all dims are default, got:\n%s", got)
	}
}

func TestRenderFragment_SingleDimension(t *testing.T) {
	got := RenderFragment(Preferences{Length: "brief"})
	if got == "" {
		t.Fatal("expected non-empty fragment")
	}
	if !strings.Contains(got, "PREFERENCJE TERAPEUTY") {
		t.Fatalf("expected header in fragment, got:\n%s", got)
	}
	if !strings.Contains(got, "Długość raportu: krótki") {
		t.Fatalf("expected length directive, got:\n%s", got)
	}
	if !strings.Contains(got, "NIE sprzeczne") {
		t.Fatalf("expected subordination clause, got:\n%s", got)
	}
}

func TestRenderFragment_AllDimensions(t *testing.T) {
	p := Preferences{
		Length:             "brief",
		Tone:               "empathic_warm",
		QuoteDensity:       "many",
		DiagnosticLanguage: "clinical_labels",
		HypothesisHedging:  "balanced",
		SectionEmphasis:    []string{"clinical_picture", "safety_and_risk"},
		StrengthsFraming:   "strengths_first",
		FreeText:           "Preferuję terminy behawioralne zamiast diagnostycznych etykiet.",
	}
	got := RenderFragment(p)
	// Each dimension should produce one line.
	expectedSubstrings := []string{
		"krótki",
		"empatyczny-ciepły",
		"dużo",
		"etykiety kliniczne",
		"zrównoważone",
		"obraz kliniczny, bezpieczeństwo i ryzyko",
		"zasoby pacjenta na początku",
		"Preferuję terminy behawioralne",
	}
	for _, want := range expectedSubstrings {
		if !strings.Contains(got, want) {
			t.Errorf("expected fragment to contain %q, got:\n%s", want, got)
		}
	}
}

func TestRenderFragment_FreeTextOnly(t *testing.T) {
	// Only free_text set → fragment still gets the header + the
	// single bullet. This is the "I just want to give plain
	// instructions" path.
	p := Preferences{FreeText: "Skupiaj się na wzorcach przywiązania."}
	got := RenderFragment(p)
	if !strings.Contains(got, "PREFERENCJE TERAPEUTY") {
		t.Fatalf("expected header even with only free_text, got:\n%s", got)
	}
	if !strings.Contains(got, "wzorcach przywiązania") {
		t.Fatalf("expected free_text appended verbatim, got:\n%s", got)
	}
}

func TestRenderFragment_FreeTextWhitespaceOnly(t *testing.T) {
	// Whitespace-only free_text doesn't produce a bullet (would be
	// useless noise in the prompt).
	p := Preferences{FreeText: "   \t  "}
	if got := RenderFragment(p); got != "" {
		t.Fatalf("expected empty fragment for whitespace-only free_text, got:\n%s", got)
	}
}

func TestRenderFragment_UnknownEnumDropped(t *testing.T) {
	// Defensive: if identity-svc's validator was bypassed and a
	// garbage enum reached the JSONB column, the renderer must NOT
	// emit "Długość raportu: " followed by nothing. It silently
	// drops the directive.
	p := Preferences{Length: "novelistic", Tone: "empathic_warm"}
	got := RenderFragment(p)
	if strings.Contains(got, "Długość raportu") {
		t.Fatalf("expected unknown length to be dropped, got:\n%s", got)
	}
	// Tone is valid → still rendered.
	if !strings.Contains(got, "empatyczny-ciepły") {
		t.Fatalf("expected valid tone to still render, got:\n%s", got)
	}
}

func TestMaxOutputTokens(t *testing.T) {
	// 2026-05-19 cap bump: 3× headroom over the directive target
	// (caps are remote safety nets, not budgets the model races to).
	//   brief    → 6144  (was 2048, ~3-page hard ceiling)
	//   standard → 0     (caller falls through to geminiMaxOutReportDefault = 12288)
	//   detailed → 24576 (was 8192, far above expected emission)
	cases := map[string]int32{
		"brief":    6144,
		"standard": 0,
		"detailed": 24576,
		"":         0,
		"garbage":  0,
	}
	for v, want := range cases {
		t.Run(v, func(t *testing.T) {
			got := MaxOutputTokens(Preferences{Length: v})
			if got != want {
				t.Fatalf("length=%q: got %d, want %d", v, got, want)
			}
		})
	}
}

func TestMaxOutputTokens_SectionEmphasisBumpsBudget(t *testing.T) {
	// section_emphasis nudges the model to expand emphasized sections.
	// Without a matching cap bump, multi-emphasis prefs hit the cap
	// mid-section (production session 0a5523a0, 2026-05-19). Each
	// emphasized section adds 500 tok of budget headroom.
	cases := []struct {
		name      string
		length    string
		emphasis  []string
		want      int32
	}{
		{
			name:     "standard + 0 emphasis = standard default sentinel",
			length:   "standard",
			emphasis: nil,
			want:     0, // caller uses geminiMaxOutReportDefault
		},
		{
			name:     "standard + 3 emphasis = 12288 base + 1500",
			length:   "standard",
			emphasis: []string{"clinical_picture", "interventions", "safety_and_risk"},
			want:     12288 + 1500,
		},
		{
			name:     "standard + 7 emphasis = full production case",
			length:   "standard",
			emphasis: []string{"a", "b", "c", "d", "e", "f", "g"},
			want:     12288 + 3500,
		},
		{
			name:     "detailed + 7 emphasis hits the 32768 soft ceiling",
			length:   "detailed",
			emphasis: []string{"a", "b", "c", "d", "e", "f", "g"},
			// 24576 + 3500 = 28076, under 32768 ceiling → unchanged
			want: 24576 + 3500,
		},
		{
			name:     "soft ceiling clamps pathological prefs",
			length:   "detailed",
			emphasis: []string{"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r"},
			// 24576 + 9000 = 33576 → clamped to 32768
			want: 32768,
		},
		{
			name:     "brief + 3 emphasis bumps the brief cap",
			length:   "brief",
			emphasis: []string{"a", "b", "c"},
			want:     6144 + 1500,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := MaxOutputTokens(Preferences{Length: c.length, SectionEmphasis: c.emphasis})
			if got != c.want {
				t.Fatalf("got %d, want %d", got, c.want)
			}
		})
	}
}

func TestTargetLengthDirective(t *testing.T) {
	// Every length value (including default + unknown) produces a
	// non-empty directive — the prompt always needs a length budget.
	// The "brief"/"detailed" variants must mention the page count
	// matching the design doc's UI labels so therapists who configure
	// "Krótki (≈1 strona)" see consistent behavior.
	cases := map[string]string{
		"brief":    "1 strona",
		"standard": "2 strony",
		"detailed": "3 strony",
		"":         "2 strony", // default
		"garbage":  "2 strony", // fall through
	}
	for v, wantSubstr := range cases {
		t.Run(v, func(t *testing.T) {
			got := TargetLengthDirective(Preferences{Length: v})
			if got == "" {
				t.Fatalf("length=%q: expected non-empty directive", v)
			}
			if !strings.Contains(got, wantSubstr) {
				t.Fatalf("length=%q: expected %q in directive, got %q", v, wantSubstr, got)
			}
			if !strings.HasPrefix(got, "DOCELOWA DŁUGOŚĆ RAPORTU:") {
				t.Fatalf("length=%q: expected directive prefix, got %q", v, got)
			}
		})
	}
}

func TestDecode_Empty(t *testing.T) {
	cases := [][]byte{nil, []byte("{}"), {}}
	for _, raw := range cases {
		p, err := Decode(raw)
		if err != nil {
			t.Fatalf("expected empty raw to decode cleanly, got %v", err)
		}
		// Preferences contains a slice → can't use struct equality.
		// Field-check each one. Zero string + zero slice + zero int.
		if p.Length != "" || p.Tone != "" || p.QuoteDensity != "" ||
			p.DiagnosticLanguage != "" || p.HypothesisHedging != "" ||
			p.StrengthsFraming != "" || p.FreeText != "" ||
			len(p.SectionEmphasis) != 0 || p.Version != 0 {
			t.Fatalf("expected zero Preferences, got %+v", p)
		}
	}
}

func TestDecode_Roundtrip(t *testing.T) {
	raw := []byte(`{
		"version": 1,
		"length": "brief",
		"tone": "empathic_warm",
		"section_emphasis": ["clinical_picture", "safety_and_risk"],
		"free_text": "uważnie obserwuj kontakt wzrokowy"
	}`)
	p, err := Decode(raw)
	if err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if p.Length != "brief" || p.Tone != "empathic_warm" {
		t.Fatalf("unexpected: %+v", p)
	}
	if len(p.SectionEmphasis) != 2 {
		t.Fatalf("expected 2 sections, got %d", len(p.SectionEmphasis))
	}
}

func TestSummary_PHIFree(t *testing.T) {
	// Summary is meant for slog — must not leak free_text contents
	// or any other potentially-sensitive value.
	p := Preferences{
		Length:   "brief",
		FreeText: "Pacjent Jan Kowalski ma trudności z relacjami.",
	}
	got := p.Summary()
	if strings.Contains(got, "Jan") || strings.Contains(got, "Kowalski") || strings.Contains(got, "trudnoś") {
		t.Fatalf("Summary leaked free_text content: %q", got)
	}
	if !strings.Contains(got, "free_text_len=") {
		t.Fatalf("expected free_text to be summarized by length, got %q", got)
	}
}

func TestSummary_Defaults(t *testing.T) {
	if got := (Preferences{}).Summary(); got != "defaults" {
		t.Fatalf("expected 'defaults' for empty preferences, got %q", got)
	}
}
