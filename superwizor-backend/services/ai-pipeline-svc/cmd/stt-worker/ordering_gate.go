package sttworker

// ordering_gate.go — per-patient-file session ordering gate
// (docs/40_STT_ORDERING_GATE.md).
//
// Problem: two short sessions of the same patient could be analyzed out
// of chronological order (variable STT latency, historically Chirp's
// 1–30+ min tail). RAG memory is written in COMPLETION order and the
// retrieval anchor is "the most recent prior session's summary", so an
// out-of-order finish permanently corrupts the patient's clinical
// context chain.
//
// Invariant enforced here: for a given patient_file at most ONE session
// is inside the pipeline (CREATED → … → ANALYZING) at a time; successors
// wait at the STT entry, BEFORE the TRANSCRIBING flip.
//
// Mechanism — INTENTIONAL NACK-AS-WAIT: when an earlier session of the
// same patient_file is still active, ProcessAudio returns a non-nil
// error. That is NOT a failure: it is the only way a CloudEvent handler
// can tell Pub/Sub "redeliver later". The Eventarc subscription's retry
// policy (10–600 s backoff, max_delivery_attempts=100 via
// infra/scripts/wire_dlq.sh) becomes the polling loop. The Cloud
// Functions framework will log these returns at ERROR severity — filter
// them out by the errOrderingGateWait message; they are expected.
//
// HARD INVARIANT (DLQ safety): the bypass window
// (STT_ORDER_GATE_MAX_WAIT_H, default 12 h) MUST stay strictly below the
// subscription's retry envelope (~15–16 h at 100 attempts × ≤600 s
// backoff). If the bypass were longer, a waiting successor would exhaust
// its delivery attempts, dead-letter, and the DLQ reaper would FAIL a
// perfectly healthy session. Change either knob only together with the
// other (wire_dlq.sh + this file + docs/40).

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// errOrderingGateWait is the sentinel returned to NACK a message whose
// predecessor session is still in the pipeline. Distinctive message so
// log-based filters can exclude it from error alerting.
var errOrderingGateWait = errors.New("ordering gate: waiting for predecessor session of the same patient file (intentional NACK, not a failure)")

// defaultOrderGateMaxWaitHours bounds how long a successor may be held.
// See the DLQ-safety invariant in the file header before changing.
const defaultOrderGateMaxWaitHours = 12

func orderingGateEnabled() bool {
	return os.Getenv("STT_ORDER_GATE") == "on"
}

func orderGateMaxWait() time.Duration {
	if v := os.Getenv("STT_ORDER_GATE_MAX_WAIT_H"); v != "" {
		if h, err := strconv.Atoi(v); err == nil && h > 0 {
			return time.Duration(h) * time.Hour
		}
	}
	return defaultOrderGateMaxWaitHours * time.Hour
}

// shouldBypassOrderingGate is the pure decision: a successor older than
// maxWait proceeds even with an active predecessor. Ordering yields to
// liveness — at that point the predecessor is pathological (the ~26 h
// reapStuckSessions backstop hasn't fired yet) and holding the successor
// longer risks its own DLQ budget.
func shouldBypassOrderingGate(successorAge, maxWait time.Duration) bool {
	return successorAge >= maxWait
}

// orderingGateResult describes why the gate did (not) hold a session.
type orderingGateResult struct {
	Wait            bool
	Bypassed        bool
	PredecessorID   string
	PredecessorStat string
	SuccessorAge    time.Duration
}

// checkOrderingGate decides whether the session must wait for an
// earlier sibling. Total order between sessions of one patient_file is
// (session_number, created_at, id) — session_number is assigned
// transactionally at CreateAudioUpload, the tuple tie-breaker makes the
// order strict, so two concurrent arrivals can never block each other.
//
// Only actively-processing statuses block:
//   - CREATED, TRANSCRIBING, MERGING, ANALYZING → wait.
//   - COMPLETED / FAILED / CANCELLED_BY_USER    → terminal, pass.
//   - PENDING_UPLOAD  → pass. The audio never arrived (abandoned upload
//     from another device); blocking on it would freeze the patient
//     file until orphan-cleanup. If that audio shows up later it is the
//     pre-existing "historical import" ordering problem, out of scope.
//
// Fail-open on "session row missing" (deleted mid-flight); fail-closed
// (returns the DB error → NACK) on transient DB failures — the rest of
// ProcessAudio needs the DB anyway.
func checkOrderingGate(ctx context.Context, sessionUUID uuid.UUID) (orderingGateResult, error) {
	var res orderingGateResult
	if dbPool == nil {
		return res, nil // tests / local: gate inert
	}

	var (
		patientFileID uuid.UUID
		sessionNumber int64
		createdAt     time.Time
	)
	err := dbPool.QueryRow(ctx, `
		SELECT patient_file_id, session_number, created_at
		FROM sessions WHERE id = $1`,
		sessionUUID).Scan(&patientFileID, &sessionNumber, &createdAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return res, nil // session deleted; nothing to order
		}
		return res, err
	}

	res.SuccessorAge = time.Since(createdAt)
	if shouldBypassOrderingGate(res.SuccessorAge, orderGateMaxWait()) {
		res.Bypassed = true
		return res, nil
	}

	var predID uuid.UUID
	var predStatus string
	err = dbPool.QueryRow(ctx, `
		SELECT id, status FROM sessions
		WHERE patient_file_id = $1
		  AND deleted_at IS NULL
		  AND status IN ('CREATED','TRANSCRIBING','MERGING','ANALYZING')
		  AND (session_number, created_at, id) < ($2, $3, $4)
		ORDER BY session_number DESC, created_at DESC, id DESC
		LIMIT 1`,
		patientFileID, sessionNumber, createdAt, sessionUUID).Scan(&predID, &predStatus)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return res, nil // no active predecessor — pass
		}
		return res, err
	}

	res.Wait = true
	res.PredecessorID = predID.String()
	res.PredecessorStat = predStatus
	return res, nil
}

// applyOrderingGate runs the gate and translates the result into the
// ProcessAudio contract: (nil, false) = proceed, (err, true) = handled
// (NACK now). Called BEFORE the TRANSCRIBING status flip so a waiting
// session honestly stays in CREATED ("uploaded" on the client stepper).
func applyOrderingGate(ctx context.Context, logger *slog.Logger, sessionID string) (error, bool) {
	if !orderingGateEnabled() {
		return nil, false
	}
	sessionUUID, err := uuid.Parse(sessionID)
	if err != nil {
		return nil, false // malformed id is handled later by the caller
	}

	res, err := checkOrderingGate(ctx, sessionUUID)
	if err != nil {
		logger.Warn("ordering gate: check failed; NACK for retry", "error", err)
		return err, true
	}
	if res.Bypassed {
		// Loud: ordering is being sacrificed for liveness. Investigate
		// the predecessor whenever this fires.
		logger.Warn("ordering_gate_bypass — successor exceeded max wait; proceeding out of order",
			"successor_age_min", int(res.SuccessorAge.Minutes()),
			"max_wait_h", int(orderGateMaxWait().Hours()))
		slog.InfoContext(ctx, "analytics",
			"ae", "stt.ordering_gate_bypass",
			"session_id", sessionID,
			"successor_age_min", int(res.SuccessorAge.Minutes()))
		return nil, false
	}
	if res.Wait {
		logger.Info("ordering_gate_waiting — predecessor still in pipeline; intentional NACK",
			"predecessor_id", res.PredecessorID,
			"predecessor_status", res.PredecessorStat,
			"successor_age_min", int(res.SuccessorAge.Minutes()))
		slog.InfoContext(ctx, "analytics",
			"ae", "stt.ordering_gate_wait",
			"session_id", sessionID,
			"predecessor_id", res.PredecessorID,
			"predecessor_status", res.PredecessorStat,
			"successor_age_min", int(res.SuccessorAge.Minutes()))
		return errOrderingGateWait, true
	}
	return nil, false
}
