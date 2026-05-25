package outbox

import "testing"

func TestQuotaEdgeEventType(t *testing.T) {
	def := DefaultThresholds() // Warn=5, Critical=1

	tests := []struct {
		name   string
		before int32
		after  int32
		want   string
	}{
		// No edge cases
		{"no edge: well above all thresholds", 20, 19, ""},
		{"no edge: already below warning before commit", 4, 3, ""},
		{"no edge: stayed at exhausted", 0, 0, ""},

		// Warning edge
		{"edge: 6 → 5 triggers warning", 6, 5, EventQuotaWarning},
		{"edge: 10 → 4 triggers warning (skip multiple)", 10, 4, EventQuotaWarning},
		{"edge: 6 → 2 stays in warning zone (not critical yet)", 6, 2, EventQuotaWarning},

		// Critical edge — must cross threshold AND stay above 0
		{"edge: 5 → 1 triggers critical (not warning)", 5, 1, EventQuotaCritical},
		{"edge: 2 → 1 triggers critical", 2, 1, EventQuotaCritical},
		{"edge: 3 → 1 triggers critical", 3, 1, EventQuotaCritical},

		// Exhausted edge — wins over critical
		{"edge: 1 → 0 triggers exhausted (not critical)", 1, 0, EventQuotaExhausted},
		{"edge: 5 → 0 triggers exhausted (jumps multiple thresholds)", 5, 0, EventQuotaExhausted},
		{"edge: 20 → 0 triggers exhausted", 20, 0, EventQuotaExhausted},

		// No-double-notify: already past threshold, no new edge
		{"no double-notify: 1 → 1 (no movement)", 1, 1, ""},
		{"no double-notify: 4 → 3 (both already in warn zone)", 4, 3, ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := def.QuotaEdgeEventType(tt.before, tt.after)
			if got != tt.want {
				t.Errorf("QuotaEdgeEventType(%d → %d) = %q, want %q",
					tt.before, tt.after, got, tt.want)
			}
		})
	}
}

func TestQuotaEdgeEventType_CustomThresholds(t *testing.T) {
	// Klient klinika z 200 tokenami chce alert "ostatnich 20".
	custom := Thresholds{Warn: 20, Critical: 5}

	if got := custom.QuotaEdgeEventType(25, 20); got != EventQuotaWarning {
		t.Errorf("25 → 20 z Warn=20: want warning, got %q", got)
	}
	if got := custom.QuotaEdgeEventType(6, 5); got != EventQuotaCritical {
		t.Errorf("6 → 5 z Critical=5: want critical, got %q", got)
	}
	if got := custom.QuotaEdgeEventType(1, 0); got != EventQuotaExhausted {
		t.Errorf("1 → 0: want exhausted, got %q", got)
	}
}
