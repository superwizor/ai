package grpc

import (
	"context"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// fakeQuerier — ten sam pattern co clinical-svc: nil-embedded interface,
// metody do testowanej ścieżki ustawiamy jako funkcje.
type fakeQuerier struct {
	db.Querier // nil embed — unset methods panic

	getActiveSubFn         func(ctx context.Context, orgID uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error)
	getActiveCounterFn     func(ctx context.Context, subID uuid.UUID) (db.UsageCounter, error)
	lockActiveCounterFn    func(ctx context.Context, subID uuid.UUID) (db.UsageCounter, error)
	acquireLockFn          func(ctx context.Context, key string) error
	getReservationFn       func(ctx context.Context, sessionID uuid.UUID) (db.PendingReservation, error)
	createReservationFn    func(ctx context.Context, arg db.CreateReservationParams) (db.PendingReservation, error)
	addReservedFn          func(ctx context.Context, arg db.AddReservedTokensParams) error
	releaseReservedFn      func(ctx context.Context, arg db.ReleaseReservedTokensParams) error
	commitTokensFn         func(ctx context.Context, arg db.CommitTokensParams) error
	markReservationCommitFn func(ctx context.Context, sessionID uuid.UUID) error
	markReservationReleaseFn func(ctx context.Context, sessionID uuid.UUID) error
	getUsageEventFn        func(ctx context.Context, sessionID uuid.UUID) (db.UsageEvent, error)
	createUsageEventFn     func(ctx context.Context, arg db.CreateUsageEventParams) (db.UsageEvent, error)
	appendOutboxFn         func(ctx context.Context, arg db.AppendOutboxEventParams) (db.OutboxEvent, error)

	// Call recorders
	createReservationCalls []db.CreateReservationParams
	createUsageEventCalls  []db.CreateUsageEventParams
	addReservedCalls       []db.AddReservedTokensParams
	releaseReservedCalls   []db.ReleaseReservedTokensParams
	commitTokensCalls      []db.CommitTokensParams
	advisoryLockCalls      []string
	appendOutboxCalls      []db.AppendOutboxEventParams
}

func (f *fakeQuerier) GetActiveSubscriptionByOrg(ctx context.Context, orgID uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
	return f.getActiveSubFn(ctx, orgID)
}

func (f *fakeQuerier) GetActiveCounter(ctx context.Context, subID uuid.UUID) (db.UsageCounter, error) {
	return f.getActiveCounterFn(ctx, subID)
}

func (f *fakeQuerier) LockActiveCounter(ctx context.Context, subID uuid.UUID) (db.UsageCounter, error) {
	if f.lockActiveCounterFn != nil {
		return f.lockActiveCounterFn(ctx, subID)
	}
	return f.getActiveCounterFn(ctx, subID)
}

func (f *fakeQuerier) AcquireSubscriptionLock(ctx context.Context, key string) error {
	f.advisoryLockCalls = append(f.advisoryLockCalls, key)
	if f.acquireLockFn != nil {
		return f.acquireLockFn(ctx, key)
	}
	return nil
}

func (f *fakeQuerier) GetReservationBySession(ctx context.Context, sessionID uuid.UUID) (db.PendingReservation, error) {
	return f.getReservationFn(ctx, sessionID)
}

func (f *fakeQuerier) CreateReservation(ctx context.Context, arg db.CreateReservationParams) (db.PendingReservation, error) {
	f.createReservationCalls = append(f.createReservationCalls, arg)
	return f.createReservationFn(ctx, arg)
}

func (f *fakeQuerier) AddReservedTokens(ctx context.Context, arg db.AddReservedTokensParams) error {
	f.addReservedCalls = append(f.addReservedCalls, arg)
	if f.addReservedFn != nil {
		return f.addReservedFn(ctx, arg)
	}
	return nil
}

func (f *fakeQuerier) ReleaseReservedTokens(ctx context.Context, arg db.ReleaseReservedTokensParams) error {
	f.releaseReservedCalls = append(f.releaseReservedCalls, arg)
	if f.releaseReservedFn != nil {
		return f.releaseReservedFn(ctx, arg)
	}
	return nil
}

func (f *fakeQuerier) CommitTokens(ctx context.Context, arg db.CommitTokensParams) error {
	f.commitTokensCalls = append(f.commitTokensCalls, arg)
	if f.commitTokensFn != nil {
		return f.commitTokensFn(ctx, arg)
	}
	return nil
}

func (f *fakeQuerier) MarkReservationCommitted(ctx context.Context, sessionID uuid.UUID) error {
	if f.markReservationCommitFn != nil {
		return f.markReservationCommitFn(ctx, sessionID)
	}
	return nil
}

func (f *fakeQuerier) MarkReservationReleased(ctx context.Context, sessionID uuid.UUID) error {
	if f.markReservationReleaseFn != nil {
		return f.markReservationReleaseFn(ctx, sessionID)
	}
	return nil
}

func (f *fakeQuerier) GetUsageEventBySession(ctx context.Context, sessionID uuid.UUID) (db.UsageEvent, error) {
	return f.getUsageEventFn(ctx, sessionID)
}

func (f *fakeQuerier) CreateUsageEvent(ctx context.Context, arg db.CreateUsageEventParams) (db.UsageEvent, error) {
	f.createUsageEventCalls = append(f.createUsageEventCalls, arg)
	return f.createUsageEventFn(ctx, arg)
}

func (f *fakeQuerier) AppendOutboxEvent(ctx context.Context, arg db.AppendOutboxEventParams) (db.OutboxEvent, error) {
	f.appendOutboxCalls = append(f.appendOutboxCalls, arg)
	if f.appendOutboxFn != nil {
		return f.appendOutboxFn(ctx, arg)
	}
	return db.OutboxEvent{}, nil
}

// ---------- fakeTxOpener ----------

type fakeTxOpener struct {
	q             *fakeQuerier // tx-scoped Querier
	beginErr      error
	commitErr     error
	beginCalls    int
	commitCalls   int
	rollbackCalls int
}

func (o *fakeTxOpener) Begin(ctx context.Context) (Tx, error) {
	o.beginCalls++
	if o.beginErr != nil {
		return nil, o.beginErr
	}
	return &fakeTx{parent: o}, nil
}

type fakeTx struct {
	parent *fakeTxOpener
}

func (t *fakeTx) Queries() db.Querier { return t.parent.q }

func (t *fakeTx) Commit(ctx context.Context) error {
	t.parent.commitCalls++
	return t.parent.commitErr
}

func (t *fakeTx) Rollback(ctx context.Context) error {
	t.parent.rollbackCalls++
	return nil
}
