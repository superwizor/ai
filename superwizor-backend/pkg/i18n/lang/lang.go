// Package lang holds BCP47 helpers shared between services. Lives in
// pkg/ rather than a service's internal/ because ingestion-svc and
// ai-pipeline-svc both need to convert the 2-char ui_language that
// clinical-svc writes (e.g. "pl") into the regional BCP47 tag that
// Cloud Speech-to-Text v2 demands (e.g. "pl-PL").
//
// Single source of truth: every BCP47 conversion across the platform
// goes through BCP47ize. If you need a new language, add it to the
// defaultRegionByLanguage map below and pin it in lang_test.go.
package lang

import "strings"

// defaultRegionByLanguage maps the 2-char ui_language to its default
// Cloud Speech BCP47 region tag. Add languages here as patient_user
// support expands. Tests pin the exact map so a typo doesn't slip in.
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
// (future-proofing for explicit per-session overrides) and tolerates
// Flutter's current default of "pl-PL".
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
