package tokens

import "testing"

func TestCalculate(t *testing.T) {
	tests := []struct {
		name     string
		duration int32
		want     int32
	}{
		// Edge: zero/negative
		{"zero seconds → 1 token minimum", 0, 1},
		{"negative seconds → 1 token (defensive)", -10, 1},

		// Sub-grace
		{"60s session → 1 token", 60, 1},
		{"180s exactly grace → 1 token", 180, 1},

		// Typical clinical durations
		{"45min (2700s) → 1 token", 2700, 1},
		{"50min (3000s) → 1 token", 3000, 1},
		{"57min (3420s) → 1 token", 3420, 1},

		// Boundary: 60min exact
		{"60min (3600s) → 1 token", 3600, 1},

		// Grace zone
		{"61min (3660s) → 1 token (saved by grace)", 3660, 1},
		{"62min (3720s) → 1 token (still in grace)", 3720, 1},

		// Exact boundary: 63min — 3780s - 180 = 3600 / 3600 = 1.0 → ceil 1
		{"63min (3780s) exact boundary → 1 token", 3780, 1},

		// Past grace
		{"64min (3840s) → 2 tokens", 3840, 2},
		{"90min (5400s) → 2 tokens", 5400, 2},

		// Two-token zone
		{"120min (7200s) → 2 tokens", 7200, 2},

		// Second boundary
		{"123min (7380s) exact boundary → 2 tokens", 7380, 2},
		{"124min (7440s) → 3 tokens", 7440, 3},

		// Long sessions
		{"180min (10800s) → 3 tokens", 10800, 3},
		{"183min (10980s) exact boundary → 3 tokens", 10980, 3},
		{"184min (11040s) → 4 tokens", 11040, 4},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Calculate(tt.duration)
			if got != tt.want {
				t.Errorf("Calculate(%d) = %d, want %d", tt.duration, got, tt.want)
			}
		})
	}
}
