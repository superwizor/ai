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

		// Tiny sessions still cost the 1-token minimum
		{"60s session → 1 token", 60, 1},
		{"180s session → 1 token", 180, 1},

		// Typical clinical durations — all well under one 75min token
		{"45min (2700s) → 1 token", 2700, 1},
		{"50min (3000s) → 1 token", 3000, 1},
		{"60min (3600s) → 1 token", 3600, 1},
		{"74min (4440s) → 1 token", 4440, 1},

		// Hard boundary: 75min exact — 4500/4500 = 1.0 → ceil 1
		{"75min (4500s) exact boundary → 1 token", 4500, 1},

		// No grace: one second past the quantum tips into a 2nd token
		{"75:01 (4501s) → 2 tokens (hard boundary, no grace)", 4501, 2},
		{"76min (4560s) → 2 tokens", 4560, 2},
		{"90min (5400s) → 2 tokens", 5400, 2},
		{"120min (7200s) → 2 tokens", 7200, 2},

		// Second boundary: 150min exact — 9000/4500 = 2.0 → ceil 2
		{"150min (9000s) exact boundary → 2 tokens", 9000, 2},
		{"150:01 (9001s) → 3 tokens", 9001, 3},
		{"151min (9060s) → 3 tokens", 9060, 3},

		// Third boundary: 225min exact — 13500/4500 = 3.0 → ceil 3
		{"225min (13500s) exact boundary → 3 tokens", 13500, 3},
		{"225:01 (13501s) → 4 tokens", 13501, 4},
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
