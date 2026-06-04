// Package tokens implementuje formułę BR-2 z designu billing-svc:
// 1 token = ≤75min audio (bez okresu tolerancji — granica jest twarda).
//
// Reference: docs/16_BILLING_SERVICE_PHASE_3.md §2 (Business Rules).
package tokens

// GraceSeconds to margines tolerancji dla sesji "lekko przeciągających się".
// Ustawiony na 0: zgodnie z decyzją produktową granica 75min jest twarda —
// 75:00 = 1 token, 75:01 = 2 tokeny. Stała pozostaje jako pokrętło na
// wypadek przywrócenia tolerancji w przyszłości.
const GraceSeconds = 0

// SecondsPerToken — 1 token pokrywa 75min nagrania.
const SecondsPerToken = 4500

// Calculate zwraca liczbę tokenów potrzebnych do skomitowania sesji
// o czasie trwania durationSeconds.
//
// Wzór: max(1, ceil((duration - grace) / secondsPerToken)).
//
// Przykłady (przy GraceSeconds=0, SecondsPerToken=4500):
//   - 0s → 1 token (minimum bilingowe; nawet sesja przerwana po sekundzie
//     spalila zasoby STT/LLM)
//   - 2700s (45min) → 1 token  (2700/4500 = 0.6, ceil = 1)
//   - 4440s (74min) → 1 token  (4440/4500 = 0.99, ceil = 1)
//   - 4500s (75min) → 1 token  (4500/4500 = 1.0, ceil = 1) — boundary
//   - 4501s (75:01) → 2 tokens (4501/4500 = 1.0002, ceil = 2) — twarda granica
//   - 4560s (76min) → 2 tokens (4560/4500 = 1.01, ceil = 2)
//   - 9000s (150min) → 2 tokens (9000/4500 = 2.0, ceil = 2) — boundary
//   - 9060s (151min) → 3 tokens (9060/4500 = 2.01, ceil = 3)
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
