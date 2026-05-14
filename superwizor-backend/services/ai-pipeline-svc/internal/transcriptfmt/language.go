package transcriptfmt

import "strings"

// BCP47 helpers.
//
// patient_user.ui_language stores 2-char codes (pl, en, de). Cloud
// Speech-to-Text v2 wants regional BCP47 tags (pl-PL, en-US, de-DE).
// There's exactly one place that does this conversion — here — so
// changing the default region per base language is a one-line edit.
//
// Coverage is deliberately small: only what Chirp 3 actually supports
// AND what we serve patient_user with. Unknown inputs return "" so
// callers can detect "we don't know this language" and fall back to
// the multi-language auto-detect list (preserves backwards-compat
// for sessions without a populated patient_user.ui_language).

// defaultRegionByLanguage maps the 2-char ui_language to its default
// Cloud Speech BCP47 region tag. Add languages here as patient_user
// support expands. Tests pin the exact map.
var defaultRegionByLanguage = map[string]string{
	"pl": "pl-PL",
	"en": "en-US",
	"de": "de-DE",
	"es": "es-ES",
	"fr": "fr-FR",
	"uk": "uk-UA",
}

// BCP47ize converts a 2-char ui_language code to a Cloud Speech BCP47
// tag. Empty input or unknown language returns empty string — caller
// should fall back to multi-language auto-detection in that case.
//
// If the input already looks like a BCP47 tag (e.g. "pl-PL" or
// "en-GB" — anything containing a "-"), it's returned as-is after a
// case-normalize: language part lowercase, region part uppercase.
// This lets callers pass through richer tags when they have them
// (future-proofing for explicit per-session overrides).
func BCP47ize(uiLanguage string) string {
	s := strings.TrimSpace(uiLanguage)
	if s == "" {
		return ""
	}
	if strings.Contains(s, "-") {
		parts := strings.SplitN(s, "-", 2)
		return strings.ToLower(parts[0]) + "-" + strings.ToUpper(parts[1])
	}
	return defaultRegionByLanguage[strings.ToLower(s)]
}

// Chirp3DiarizationLanguages — BCP47 tags where Cloud Speech-to-Text
// Chirp 3 emits per-word speaker tags reliably enough to skip LLM
// clustering. Every entry starts at `false`; we flip per-language
// only after probe evidence on real staging sessions confirms the
// tags are clean (boundary accuracy + cross-speaker confusion within
// our acceptance budget). See ADR-IMPL-007 in
// docs/agents/05_ai-pipeline-svc.md.
//
// IMPORTANT: stt-worker also reads this map to decide whether to
// turn on the BatchRecognize DiarizationConfig. Mutating it requires
// a stt-worker redeploy.
var Chirp3DiarizationLanguages = map[string]bool{
	"pl-PL": false, // primary user base, NOT yet enabled
	"en-US": false, // pending verification
	"en-GB": false,
	"de-DE": false,
	"es-ES": false,
	"fr-FR": false,
	"uk-UA": false,
}

// NativeDiarizationSupported reports whether the given BCP47 tag is
// flagged in Chirp3DiarizationLanguages AND set to true. Unknown
// languages return false. Centralized so the worker doesn't have to
// know the map's shape.
func NativeDiarizationSupported(bcp47 string) bool {
	return Chirp3DiarizationLanguages[bcp47]
}
