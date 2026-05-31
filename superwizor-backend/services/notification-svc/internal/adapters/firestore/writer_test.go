package firestore

import "testing"

// Tests the pure session_states write-decision logic (docs/21 §3.4):
// monotonic-rank regress guard + terminal-sticky guard. The Firestore
// transaction wrapper is exercised in e2e; this nails the rules.
func TestShouldMirror(t *testing.T) {
	cases := []struct {
		name       string
		curr, next string
		want       bool
	}{
		// Fresh doc accepts anything.
		{"fresh→uploaded", "", "uploaded", true},
		{"fresh→failed", "", "failed", true},

		// Forward progress.
		{"uploaded→transcribing", "uploaded", "transcribing", true},
		{"transcribing→analyzing", "transcribing", "analyzing", true},
		{"analyzing→done", "analyzing", "done", true},

		// Monotonic regress is skipped (backlog redelivery).
		{"analyzing→uploaded", "analyzing", "uploaded", false},
		{"done→analyzing", "done", "analyzing", false},
		{"transcribing→uploaded", "transcribing", "uploaded", false},

		// Failure can arrive at any in-progress point and outranks it.
		{"uploaded→failed", "uploaded", "failed", true},
		{"analyzing→failed", "analyzing", "failed", true},

		// Terminal-sticky: first terminal wins (same rank 4).
		{"done→failed (kept done)", "done", "failed", false},
		{"failed→done (kept failed)", "failed", "done", false},
		{"cancelled→failed (kept cancelled)", "cancelled", "failed", false},
		{"done→cancelled (kept done)", "done", "cancelled", false},

		// Same terminal re-delivered is a harmless no-op-equivalent (allowed;
		// the write is idempotent).
		{"failed→failed", "failed", "failed", true},
		{"done→done", "done", "done", true},

		// Unknown new status: allow (logged as drift elsewhere).
		{"any→unknown", "analyzing", "weird", true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := shouldMirror(tc.curr, tc.next); got != tc.want {
				t.Errorf("shouldMirror(%q,%q)=%v, want %v", tc.curr, tc.next, got, tc.want)
			}
		})
	}
}
