// Package reportprefs renders per-therapist report style preferences
// (stored as JSONB on users.report_preferences by identity-svc) into
// a Polish prompt fragment that llm-worker slots into call 2.
//
// Design constraints (from docs/10_REPORT_CUSTOMIZATION.md §8):
//
//   1. Output is ALWAYS subordinate to the modality baseline.
//      The fragment text starts with "PREFERENCJE TERAPEUTY
//      (uzupełnienia stylu, NIE sprzeczne z powyższymi zasadami
//      klinicznymi)" so the LLM treats it as supplementary, not
//      overriding.
//   2. Empty/missing preferences → empty fragment. Call 2 prompt
//      stays byte-identical to today's behavior for users who
//      haven't configured anything.
//   3. Free-text is treated as opaque guidance and appended verbatim
//      after server-side sanitization (which happens in identity-svc
//      before it ever reaches the DB).
//   4. MaxOutputTokens nudge for length=brief lives on the caller
//      (llm-worker), not here — this package only emits prompt text.
//
// The full enum surface mirrors identity-svc's preferencesPayload
// struct. If a new dimension is added there, ADD IT HERE too +
// extend the corresponding label maps.
package reportprefs

import (
	"encoding/json"
	"fmt"
	"strings"
)

// Preferences is the on-disk JSONB shape from
// users.report_preferences. Field tags match identity-svc's
// preferencesPayload exactly so we can json.Unmarshal directly off
// a query result.
type Preferences struct {
	Version            int32    `json:"version"`
	Length             string   `json:"length,omitempty"`
	Tone               string   `json:"tone,omitempty"`
	QuoteDensity       string   `json:"quote_density,omitempty"`
	DiagnosticLanguage string   `json:"diagnostic_language,omitempty"`
	HypothesisHedging  string   `json:"hypothesis_hedging,omitempty"`
	SectionEmphasis    []string `json:"section_emphasis,omitempty"`
	StrengthsFraming   string   `json:"strengths_framing,omitempty"`
	FreeText           string   `json:"free_text,omitempty"`
}

// Decode unmarshals the raw JSONB column. Empty / "{}" / nil → zero
// Preferences (which renders to ""), per design constraint #2.
func Decode(raw []byte) (Preferences, error) {
	if len(raw) == 0 || string(raw) == "{}" {
		return Preferences{}, nil
	}
	var p Preferences
	if err := json.Unmarshal(raw, &p); err != nil {
		return Preferences{}, err
	}
	return p, nil
}

// RenderFragment returns the Polish prompt fragment to inject
// between the modality baseline and the universal zasady-zwięzłości
// block. Returns "" when no dimension is set — caller skips
// inclusion entirely in that case so the prompt is byte-identical to
// the pre-feature behavior.
//
// Output shape (example, full preferences):
//
//	PREFERENCJE TERAPEUTY (uzupełnienia stylu, NIE sprzeczne z
//	powyższymi zasadami klinicznymi):
//
//	- Długość raportu: krótki (≈1 strona)
//	- Ton: empatyczny-ciepły
//	- Cytaty z transkryptu: wybiórczo (3-5)
//	- Język diagnostyczny: opisowo
//	- Pewność hipotez: ostrożnie (możliwe / sugeruje)
//	- Mocniej rozwiń: obraz kliniczny, interwencje
//	- Framing: zrównoważony (problemy i zasoby)
//	- Dodatkowe wskazówki terapeuty: <free_text verbatim>
func RenderFragment(p Preferences) string {
	var lines []string
	if s := lengthLabel(p.Length); s != "" {
		lines = append(lines, "- Długość raportu: "+s)
	}
	if s := toneLabel(p.Tone); s != "" {
		lines = append(lines, "- Ton: "+s)
	}
	if s := quoteDensityLabel(p.QuoteDensity); s != "" {
		lines = append(lines, "- Cytaty z transkryptu: "+s)
	}
	if s := diagnosticLanguageLabel(p.DiagnosticLanguage); s != "" {
		lines = append(lines, "- Język diagnostyczny: "+s)
	}
	if s := hypothesisHedgingLabel(p.HypothesisHedging); s != "" {
		lines = append(lines, "- Pewność hipotez: "+s)
	}
	if s := sectionEmphasisLabel(p.SectionEmphasis); s != "" {
		lines = append(lines, "- Mocniej rozwiń: "+s)
	}
	if s := strengthsFramingLabel(p.StrengthsFraming); s != "" {
		lines = append(lines, "- Framing: "+s)
	}
	if ft := strings.TrimSpace(p.FreeText); ft != "" {
		lines = append(lines, "- Dodatkowe wskazówki terapeuty: "+ft)
	}

	if len(lines) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString("PREFERENCJE TERAPEUTY (uzupełnienia stylu, NIE sprzeczne z powyższymi\n")
	sb.WriteString("zasadami klinicznymi):\n\n")
	for _, l := range lines {
		sb.WriteString(l)
		sb.WriteByte('\n')
	}
	return sb.String()
}

// MaxOutputTokens returns the recommended cap for call 2's
// GenerationConfig.MaxOutputTokens based on the length preference.
// llm-worker reads this and overrides its default 65535 cap.
// Returns 0 when the caller should keep its default — empty length
// preference means "no opinion".
func MaxOutputTokens(p Preferences) int32 {
	switch p.Length {
	case "brief":
		return 16384
	case "standard":
		// Same as today's default (we don't override).
		return 0
	case "detailed":
		return 65535
	}
	return 0
}

// ─── label maps ─────────────────────────────────────────────
//
// Each enum value maps to a polished Polish phrase the LLM will
// honor. Empty enum → empty label → dimension omitted from fragment.
// Unknown values (shouldn't happen — identity-svc validates) also
// produce empty so the fragment never carries garbage.

func lengthLabel(v string) string {
	switch v {
	case "brief":
		return "krótki (≈1 strona)"
	case "standard":
		// Standard is the implicit baseline; don't emit a directive
		// when the user picked it explicitly either — keeps the
		// prompt minimal and avoids "standard standard" noise.
		return ""
	case "detailed":
		return "szczegółowy (3+ strony)"
	}
	return ""
}

func toneLabel(v string) string {
	switch v {
	case "clinical_formal":
		// Same logic as standard length: this is the implicit
		// modality baseline. No directive needed.
		return ""
	case "empathic_warm":
		return "empatyczny-ciepły"
	case "pragmatic_direct":
		return "pragmatyczny-bezpośredni"
	case "academic_rigorous":
		return "akademicki-rygorystyczny"
	}
	return ""
}

func quoteDensityLabel(v string) string {
	switch v {
	case "few":
		return "mało (max 2 cytaty verbatim)"
	case "selective":
		return ""
	case "many":
		return "dużo (≥5 cytatów verbatim ilustrujących obserwacje)"
	}
	return ""
}

func diagnosticLanguageLabel(v string) string {
	switch v {
	case "descriptive":
		// Default; matches the base modality prompt.
		return ""
	case "clinical_labels":
		return "etykiety kliniczne (np. „unikanie społeczne”)"
	case "dsm_icd":
		return "pełne etykiety DSM-5 / ICD-11 gdy uzasadnione"
	}
	return ""
}

func hypothesisHedgingLabel(v string) string {
	switch v {
	case "tentative":
		// Default.
		return ""
	case "balanced":
		return "zrównoważone (ostrożne, ale konkretne)"
	case "assertive":
		return "pewne (jest / wskazuje na — nie nadużywaj „możliwe”)"
	}
	return ""
}

// sectionEmphasisLabel translates enum IDs to readable Polish names
// and concatenates them. Returns "" when no sections selected.
func sectionEmphasisLabel(sections []string) string {
	if len(sections) == 0 {
		return ""
	}
	out := make([]string, 0, len(sections))
	for _, s := range sections {
		switch s {
		case "clinical_picture":
			out = append(out, "obraz kliniczny")
		case "interventions":
			out = append(out, "interwencje")
		case "case_formulation":
			out = append(out, "formułowanie przypadku")
		case "supervisory_recommendations":
			out = append(out, "rekomendacje superwizyjne")
		case "homework_between_sessions":
			out = append(out, "zalecenia między-sesyjne")
		case "cultural_context":
			out = append(out, "kontekst kulturowy")
		case "safety_and_risk":
			out = append(out, "bezpieczeństwo i ryzyko")
		}
	}
	if len(out) == 0 {
		return ""
	}
	return strings.Join(out, ", ")
}

func strengthsFramingLabel(v string) string {
	switch v {
	case "problem_focused":
		// Default.
		return ""
	case "balanced":
		return "zrównoważony (problemy i zasoby pacjenta — równowaga)"
	case "strengths_first":
		return "zasoby pacjenta na początku, problemy w drugiej kolejności"
	}
	return ""
}

// ─── debug helpers ──────────────────────────────────────────

// Summary returns a compact one-line string for slog fields. PHI-
// free by construction (preferences are style metadata; the
// free_text may contain therapy-language but no patient identifiers,
// which is the relevant PHI definition here).
func (p Preferences) Summary() string {
	parts := make([]string, 0, 8)
	add := func(k, v string) {
		if v != "" {
			parts = append(parts, fmt.Sprintf("%s=%s", k, v))
		}
	}
	add("length", p.Length)
	add("tone", p.Tone)
	add("quote_density", p.QuoteDensity)
	add("diagnostic_language", p.DiagnosticLanguage)
	add("hypothesis_hedging", p.HypothesisHedging)
	add("strengths_framing", p.StrengthsFraming)
	if len(p.SectionEmphasis) > 0 {
		add("section_emphasis", strings.Join(p.SectionEmphasis, "+"))
	}
	if p.FreeText != "" {
		add("free_text_len", fmt.Sprintf("%d", len(p.FreeText)))
	}
	if len(parts) == 0 {
		return "defaults"
	}
	return strings.Join(parts, " ")
}
