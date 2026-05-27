// Package tokens implementuje formułę BR-2 z designu billing-svc:
// 1 token = ≤60min audio + 180s grace period.
//
// Reference: docs/16_BILLING_SERVICE_PHASE_3.md §2 (Business Rules).
package tokens

// GraceSeconds to margines tolerancji dla sesji "lekko przeciągających się"
// (180s = 3min). Sesje krótsze niż grace nie liczą się jako dodatkowy token.
const GraceSeconds = 180

// SecondsPerToken — 1 token pokrywa 60min nagrania.
const SecondsPerToken = 3600

// Calculate zwraca liczbę tokenów potrzebnych do skomitowania sesji
// o czasie trwania durationSeconds.
//
// Wzór: max(1, ceil((duration - grace) / secondsPerToken)).
//
// Przykłady (przy GraceSeconds=180, SecondsPerToken=3600):
//   - 0s → 1 token (minimum bilingowe; nawet sesja przerwana po sekundzie
//     spalila zasoby STT/LLM)
//   - 2700s (45min) → 1 token  (2520/3600 = 0.7, ceil = 1)
//   - 3420s (57min) → 1 token  (3240/3600 = 0.9, ceil = 1)
//   - 3600s (60min) → 1 token  (3420/3600 = 0.95, ceil = 1)
//   - 3660s (61min) → 1 token  (3480/3600 = 0.97, ceil = 1) — grace saves
//   - 3780s (63min) → 1 token  (3600/3600 = 1.0, ceil = 1) — boundary
//   - 3840s (64min) → 2 tokens (3660/3600 = 1.02, ceil = 2)
//   - 7200s (120min) → 2 tokens (7020/3600 = 1.95, ceil = 2)
//   - 7380s (123min) → 2 tokens (7200/3600 = 2.0, ceil = 2) — boundary
//
// Wartości ujemne (defensywnie — clinical-svc nie powinien ich wysyłać)
// są traktowane jak 0: zwracamy minimum 1 token.
func Calculate(durationSeconds int32) int32 {
	if durationSeconds <= 0 {
		return 1
	}
	billable := int64(durationSeconds) - GraceSeconds
	if billable <= 0 {
		return 1
	}
	// Integer ceil: (a + b - 1) / b
	tokens := (billable + SecondsPerToken - 1) / SecondsPerToken
	if tokens < 1 {
		return 1
	}
	return int32(tokens)
}
