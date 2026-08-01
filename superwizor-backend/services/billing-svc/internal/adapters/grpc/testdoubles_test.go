package grpc

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// fakeQuerier — ten sam pattern co clinical-svc: nil-embedded interface,
// metody do testowanej ścieżki ustawiamy jako funkcje.
type fakeQuerier struct {
	db.Querier // nil embed — unset methods panic

	getActiveSubFn           func(ctx context.Context, orgID uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error)
	getActiveCounterFn       func(ctx context.Context, subID uuid.UUID) (db.UsageCounter, error)
	lockActiveCounterFn      func(ctx context.Context, subID uuid.UUID) (db.UsageCounter, error)
	acquireLockFn            func(ctx context.Context, key string) error
	getReservationFn         func(ctx context.Context, sessionID uuid.UUID) (db.PendingReservation, error)
	createReservationFn      func(ctx context.Context, arg db.CreateReservationParams) (db.PendingReservation, error)
	addReservedFn            func(ctx context.Context, arg db.AddReservedTokensParams) error
	releaseReservedFn        func(ctx context.Context, arg db.ReleaseReservedTokensParams) error
	commitTokensFn           func(ctx context.Context, arg db.CommitTokensParams) error
	markReservationCommitFn  func(ctx context.Context, sessionID uuid.UUID) error
	markReservationReleaseFn func(ctx context.Context, sessionID uuid.UUID) error
	getUsageEventFn          func(ctx context.Context, sessionID uuid.UUID) (db.UsageEvent, error)
	createUsageEventFn       func(ctx context.Context, arg db.CreateUsageEventParams) (db.UsageEvent, error)

	// per-therapist counter scope (docs/38)
	lockCounterForTherapistFn func(ctx context.Context, arg db.LockActiveCounterForTherapistParams) (db.UsageCounter, error)
	getCounterForTherapistFn  func(ctx context.Context, arg db.GetActiveCounterForTherapistParams) (db.UsageCounter, error)
	getSeatPlanFn             func(ctx context.Context, userID uuid.UUID) (db.GetSeatPlanForTherapistRow, error)
	createTherapistCounterFn  func(ctx context.Context, arg db.CreateTherapistUsageCounterParams) (db.UsageCounter, error)
	sumActiveCountersFn       func(ctx context.Context, subID uuid.UUID) (db.SumActiveCountersRow, error)

	// admin-path stubs (feat/tokens-exhausted)
	adminGetPlanFn       func(ctx context.Context, arg db.AdminGetPlanByTierCycleParams) (db.SubscriptionPlan, error)
	adminChangePlanFn    func(ctx context.Context, arg db.AdminChangeSubscriptionPlanParams) (db.Subscription, error)
	adminUpdateCounterFn func(ctx context.Context, arg db.AdminUpdateCounterParams) (db.UsageCounter, error)
	createAuditFn        func(ctx context.Context, arg db.CreateBillingAuditEventParams) (db.AuditEvent, error)
	createCounterFn      func(ctx context.Context, arg db.CreateUsageCounterParams) (db.UsageCounter, error)
	resetTherapistFn     func(ctx context.Context, arg db.AdminResetTherapistCountersParams) (int64, error)

	// Call recorders
	createTherapistCounterCalls []db.CreateTherapistUsageCounterParams
	createReservationCalls      []db.CreateReservationParams
	createUsageEventCalls       []db.CreateUsageEventParams
	addReservedCalls            []db.AddReservedTokensParams
	releaseReservedCalls        []db.ReleaseReservedTokensParams
	commitTokensCalls           []db.CommitTokensParams
	advisoryLockCalls           []string
	createCounterCalls          []db.CreateUsageCounterParams
	auditCalls                  []map[string]any
	adminChangePlanCalls        []db.AdminChangeSubscriptionPlanParams
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

// ---------- per-therapist counter scope (docs/38) ----------

func (f *fakeQuerier) LockActiveCounterForTherapist(ctx context.Context, arg db.LockActiveCounterForTherapistParams) (db.UsageCounter, error) {
	return f.lockCounterForTherapistFn(ctx, arg)
}

func (f *fakeQuerier) GetActiveCounterForTherapist(ctx context.Context, arg db.GetActiveCounterForTherapistParams) (db.UsageCounter, error) {
	return f.getCounterForTherapistFn(ctx, arg)
}

func (f *fakeQuerier) GetSeatPlanForTherapist(ctx context.Context, userID uuid.UUID) (db.GetSeatPlanForTherapistRow, error) {
	return f.getSeatPlanFn(ctx, userID)
}

func (f *fakeQuerier) CreateTherapistUsageCounter(ctx context.Context, arg db.CreateTherapistUsageCounterParams) (db.UsageCounter, error) {
	f.createTherapistCounterCalls = append(f.createTherapistCounterCalls, arg)
	return f.createTherapistCounterFn(ctx, arg)
}

func (f *fakeQuerier) SumActiveCounters(ctx context.Context, subID uuid.UUID) (db.SumActiveCountersRow, error) {
	if f.sumActiveCountersFn != nil {
		return f.sumActiveCountersFn(ctx, subID)
	}
	return db.SumActiveCountersRow{}, nil
}

// ---------- admin-path stubs (feat/tokens-exhausted) ----------

func (f *fakeQuerier) AdminGetPlanByTierCycle(ctx context.Context, arg db.AdminGetPlanByTierCycleParams) (db.SubscriptionPlan, error) {
	if f.adminGetPlanFn != nil {
		return f.adminGetPlanFn(ctx, arg)
	}
	return db.SubscriptionPlan{}, nil
}

func (f *fakeQuerier) AdminChangeSubscriptionPlan(ctx context.Context, arg db.AdminChangeSubscriptionPlanParams) (db.Subscription, error) {
	f.adminChangePlanCalls = append(f.adminChangePlanCalls, arg)
	if f.adminChangePlanFn != nil {
		return f.adminChangePlanFn(ctx, arg)
	}
	return db.Subscription{}, nil
}

func (f *fakeQuerier) AdminUpdateCounter(ctx context.Context, arg db.AdminUpdateCounterParams) (db.UsageCounter, error) {
	if f.adminUpdateCounterFn != nil {
		return f.adminUpdateCounterFn(ctx, arg)
	}
	return db.UsageCounter{}, nil
}

func (f *fakeQuerier) CreateBillingAuditEvent(ctx context.Context, arg db.CreateBillingAuditEventParams) (db.AuditEvent, error) {
	// Metadane audytu rozpakowujemy tutaj, żeby testy mogły asertować
	// na ich TREŚCI. Wpis "before=40, after=40" z 2026-07-05 opisywał
	// świeżo wstawiony wiersz jako stan sprzed operacji — bez zajrzenia
	// do środka metadanych taki błąd jest niewidoczny dla testów.
	if len(arg.Metadata) > 0 {
		var m map[string]any
		if err := json.Unmarshal(arg.Metadata, &m); err == nil {
			f.auditCalls = append(f.auditCalls, m)
		}
	}
	if f.createAuditFn != nil {
		return f.createAuditFn(ctx, arg)
	}
	return db.AuditEvent{}, nil
}

func (f *fakeQuerier) CreateUsageCounter(ctx context.Context, arg db.CreateUsageCounterParams) (db.UsageCounter, error) {
	f.createCounterCalls = append(f.createCounterCalls, arg)
	if f.createCounterFn != nil {
		return f.createCounterFn(ctx, arg)
	}
	return db.UsageCounter{ID: uuid.New(), SubscriptionID: arg.SubscriptionID, TokensLimit: arg.TokensLimit}, nil
}

func (f *fakeQuerier) AdminResetTherapistCounters(ctx context.Context, arg db.AdminResetTherapistCountersParams) (int64, error) {
	if f.resetTherapistFn != nil {
		return f.resetTherapistFn(ctx, arg)
	}
	return 0, nil
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
