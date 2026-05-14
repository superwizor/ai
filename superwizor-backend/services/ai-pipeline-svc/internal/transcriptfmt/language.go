package transcriptfmt

import "github.com/superwizor-ai/backend/pkg/i18n/lang"

// BCP47ize is re-exported from pkg/i18n/lang for callers that already
// depend on transcriptfmt. New callers should import pkg/i18n/lang
// directly. Kept here to avoid touching every llm-eval / stt-worker
// callsite in a single PR.
func BCP47ize(uiLanguage string) string { return lang.BCP47ize(uiLanguage) }

// Chirp3DiarizationLanguages — BCP47 tags where Cloud Speech-to-Text
// Chirp 3 emits per-word speaker tags reliably enough to skip LLM
// clustering. Every entry starts at `false`; we flip per-language
// only after probe evidence on real staging sessions confirms the
// tags are clean (boundary accuracy + cross-speaker confusion within
// our acceptance budget). See ADR-IMPL-007 in
// docs/agents/05_ai-pipeline-svc.md.
//
// Lives in ai-pipeline-svc/internal rather than pkg/ because only
// stt-worker reads it. ingestion-svc and clinical-svc don't need to
// know about Chirp's capability matrix.
//
// IMPORTANT: stt-worker also reads this map to decide whether to
// turn on the BatchRecognize DiarizationConfig. Mutating it requires
// a stt-worker redeploy.
var Chirp3DiarizationLanguages = map[string]bool{
	"pl-PL": false, // primary user base, NOT yet enabled
	"en-US": true,  // verified Chirp 3 support; enabled 2026-05-14
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
