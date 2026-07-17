package sttworker

import (
	"context"
	"io"
	"log/slog"
	"testing"
	"time"
)

func TestShouldBypassOrderingGate(t *testing.T) {
	cases := []struct {
		name    string
		age     time.Duration
		maxWait time.Duration
		want    bool
	}{
		{"fresh_successor_waits", 5 * time.Minute, 12 * time.Hour, false},
		{"just_below_threshold_waits", 12*time.Hour - time.Second, 12 * time.Hour, false},
		{"at_threshold_bypasses", 12 * time.Hour, 12 * time.Hour, true},
		{"beyond_threshold_bypasses", 20 * time.Hour, 12 * time.Hour, true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := shouldBypassOrderingGate(c.age, c.maxWait); got != c.want {
				t.Errorf("shouldBypassOrderingGate(%v, %v) = %v, want %v", c.age, c.maxWait, got, c.want)
			}
		})
	}
}

// TestOrderGateMaxWait_DLQSafetyInvariant pins the DLQ-safety math from
// the file header: the default bypass window must stay strictly below
// the Eventarc subscription's retry envelope (100 attempts × ≤600 s
// ≈ 15–16 h, configured by infra/scripts/wire_dlq.sh). If this test
// fails you are about to let waiting sessions dead-letter — change both
// knobs together or not at all.
func TestOrderGateMaxWait_DLQSafetyInvariant(t *testing.T) {
	const retryEnvelope = 15 * time.Hour // conservative lower bound of the envelope
	if d := orderGateMaxWait(); d >= retryEnvelope {
		t.Fatalf("orderGateMaxWait() = %v — must stay below the ~%v Pub/Sub retry envelope (see ordering_gate.go header)", d, retryEnvelope)
	}
}

func TestOrderGateEnvParsing(t *testing.T) {
	t.Setenv("STT_ORDER_GATE", "")
	if orderingGateEnabled() {
		t.Error("gate must default to OFF")
	}
	t.Setenv("STT_ORDER_GATE", "on")
	if !orderingGateEnabled() {
		t.Error("STT_ORDER_GATE=on must enable")
	}
	t.Setenv("STT_ORDER_GATE_MAX_WAIT_H", "3")
	if orderGateMaxWait() != 3*time.Hour {
		t.Errorf("max wait override = %v, want 3h", orderGateMaxWait())
	}
	t.Setenv("STT_ORDER_GATE_MAX_WAIT_H", "garbage")
	if orderGateMaxWait() != defaultOrderGateMaxWaitHours*time.Hour {
		t.Error("garbage override must fall back to default")
	}
}

// TestApplyOrderingGate_OffAndNoDB: flag off → inert; flag on without a
// DB pool (test env) → gate passes (checkOrderingGate is inert).
func TestApplyOrderingGate_OffAndNoDB(t *testing.T) {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	t.Setenv("STT_ORDER_GATE", "")
	if err, handled := applyOrderingGate(context.Background(), logger, "00000000-0000-0000-0000-000000000001"); err != nil || handled {
		t.Errorf("gate off: err=%v handled=%v, want nil/false", err, handled)
	}
	t.Setenv("STT_ORDER_GATE", "on")
	if err, handled := applyOrderingGate(context.Background(), logger, "00000000-0000-0000-0000-000000000001"); err != nil || handled {
		t.Errorf("gate on, no db: err=%v handled=%v, want nil/false", err, handled)
	}
	// Malformed session id must not be swallowed by the gate — the
	// caller's own validation owns that path.
	if err, handled := applyOrderingGate(context.Background(), logger, "not-a-uuid"); err != nil || handled {
		t.Errorf("malformed id: err=%v handled=%v, want nil/false", err, handled)
	}
}
