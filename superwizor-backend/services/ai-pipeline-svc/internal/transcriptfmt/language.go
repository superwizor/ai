package transcriptfmt

import "github.com/superwizor-ai/backend/pkg/i18n/lang"

// BCP47ize is re-exported from pkg/i18n/lang for callers that already
// depend on transcriptfmt. New callers should import pkg/i18n/lang
// directly. Kept here to avoid touching every llm-eval / stt-worker
// callsite in a single PR.
func BCP47ize(uiLanguage string) string { return lang.BCP47ize(uiLanguage) }

// Chirp3DiarizationLanguages — BCP47 tags where Cloud Speech-to-Text
// Chirp 3 emits per-word speaker tags. Authoritative list per Google's
// docs (2026-05-15): cmn-Hans-CN, de-DE, en-GB, en-IN, en-US, es-ES,
// es-US, fr-CA, fr-FR, hi-IN, it-IT, ja-JP, ko-KR, pt-BR.
//
// pl-PL and uk-UA are explicitly kept in the map with value=false so
// a future maintainer (or this comment block) records that they're
// NOT in the supported set. A probe on pl-PL sessions confirmed
// Chirp returned no speaker_tag despite DiarizationConfig being on.
//
// Lives in ai-pipeline-svc/internal rather than pkg/ because only
// stt-worker reads it. ingestion-svc and clinical-svc don't need to
// know about Chirp's capability matrix.
//
// IMPORTANT: stt-worker also reads this map to decide whether to
// turn on the BatchRecognize DiarizationConfig. Mutating it requires
// a stt-worker redeploy.
//
// Coverage note: BCP47ize in pkg/i18n/lang only knows how to convert
// a few 2-char ui_language codes to BCP47 tags. Patient users with
// languages outside that map (e.g. hi, ja, zh-cmn) will currently
// fall back to multi-language auto-detect and never reach this list.
// Expand defaultRegionByLanguage + the Flutter language picker
// before relying on these new entries for production traffic.
var Chirp3DiarizationLanguages = map[string]bool{
	// Polish therapy is our primary user base; Polish is NOT on
	// Google's supported list, so we explicitly stay on the LLM-
	// clustering path for pl-PL.
	"pl-PL": false,
	// Ukrainian is also not on Google's list; was speculatively true
	// in an earlier draft, fixed 2026-05-15.
	"uk-UA": false,

	// All Chirp-3-supported languages per Google's authoritative
	// docs. Enabled together 2026-05-15 — every one of these will
	// trigger native diarization once STT_NATIVE_DIARIZATION=on
	// is set on the worker AND the session's BCP47-tagged language
	// matches a key.
	"cmn-Hans-CN": true,
	"de-DE":       true,
	"en-GB":       true,
	"en-IN":       true,
	"en-US":       true,
	"es-ES":       true,
	"es-US":       true,
	"fr-CA":       true,
	"fr-FR":       true,
	"hi-IN":       true,
	"it-IT":       true,
	"ja-JP":       true,
	"ko-KR":       true,
	"pt-BR":       true,
}

// NativeDiarizationSupported reports whether the given BCP47 tag is
// flagged in Chirp3DiarizationLanguages AND set to true. Unknown
// languages return false. Centralized so the worker doesn't have to
// know the map's shape.
func NativeDiarizationSupported(bcp47 string) bool {
	return Chirp3DiarizationLanguages[bcp47]
}
