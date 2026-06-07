// Package grpc implementuje BillingService Phase 3.
//
// Reference: docs/16_BILLING_SERVICE_PHASE_3.md
//
// Flow:
//   - CheckQuota:   read-only check pozostałych tokenów.
//   - ReserveCredit: dwufazowy debit (ADR-BL-001), pre-bookuje token na sesję.
//   - CommitUsage:  finalizuje debit po STT, używa duration_seconds (1 token = ≤75min).
//   - ReleaseCredit: jawne anulowanie rezerwacji.
//   - IncrementUsage: legacy alias do CommitUsage z amount→tokens 1:1.
//
// Transakcyjność: każda mutating RPC bierze pg_advisory_xact_lock per
// subscription_id przed dotknięciem tabel. Idempotencja podwójna:
// session_id UNIQUE w pending_reservations + usage_events broni przed
// double-debit nawet jeśli klient nie wysłał idempotency_key.
package grpc

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/pkg/analytics"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/domain/tokens"
)

// DefaultReservationTTL — patrz design §16.1.
//
// docs/21 WS0E: bumped 4h → 26h to cover the pipeline's transient-retry
// window. A session can now retry a Chirp/Vertex outage for up to ~24h
// (objectFinalized.sub / Eventarc subs: 100 delivery attempts), and a
// retry that finally succeeds must still be able to CommitUsage — which
// it can't if the reservation already expired. 26h sits just beyond the
// retry window + the stuck-session backstop, so a genuinely dead session
// still releases its token via the 5-min reservation-expiry cron. The
// authoritative failure paths (terminal classify, DLQ give-up reaper,
// CancelSession) release sooner.
const DefaultReservationTTL = 26 * time.Hour

// TxOpener / Tx — ten sam pattern co clinical-svc, żeby handlery były
// testowalne bez prawdziwej bazy.
type TxOpener interface {
	Begin(ctx context.Context) (Tx, error)
}

type Tx interface {
	Queries() db.Querier
	Commit(ctx context.Context) error
	Rollback(ctx context.Context) error
}

// pgxTxOpener — produkcyjne wiring: pgxpool + sqlc.WithTx.
type pgxTxOpener struct {
	pool *pgxpool.Pool
	base *db.Queries
}

func NewPgxTxOpener(pool *pgxpool.Pool) TxOpener {
	return &pgxTxOpener{pool: pool, base: db.New(pool)}
}

func (p *pgxTxOpener) Begin(ctx context.Context) (Tx, error) {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	return &pgxTx{tx: tx, q: p.base.WithTx(tx)}, nil
}

type pgxTx struct {
	tx pgx.Tx
	q  *db.Queries
}

func (t *pgxTx) Queries() db.Querier              { return t.q }
func (t *pgxTx) Commit(ctx context.Context) error { return t.tx.Commit(ctx) }
func (t *pgxTx) Rollback(ctx context.Context) error {
	return t.tx.Rollback(ctx)
}

// Server implementuje billingv1.BillingServiceServer.
type Server struct {
	billingv1.UnimplementedBillingServiceServer
	queries        db.Querier
	tx             TxOpener
	reservationTTL time.Duration
	version        string
	collector      *analytics.Collector
}

// NewServer — produkcyjny konstruktor.
func NewServer(pool *pgxpool.Pool, version string, collector *analytics.Collector) *Server {
	return &Server{
		queries:        db.New(pool),
		tx:             NewPgxTxOpener(pool),
		reservationTTL: DefaultReservationTTL,
		version:        version,
		collector:      collector,
	}
}

// NewServerWithDeps — test-friendly: każda zależność interfejsowa.
func NewServerWithDeps(q db.Querier, tx TxOpener, ttl time.Duration, version string, collector *analytics.Collector) *Server {
	if ttl == 0 {
		ttl = DefaultReservationTTL
	}
	return &Server{
		queries:        q,
		tx:             tx,
		reservationTTL: ttl,
		version:        version,
		collector:      collector,
	}
}

// ---------- helpers ----------

func parseUUID(field, raw string) (uuid.UUID, error) {
	if raw == "" {
		return uuid.Nil, status.Errorf(codes.InvalidArgument, "%s required", field)
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil, status.Errorf(codes.InvalidArgument, "%s invalid uuid: %v", field, err)
	}
	return id, nil
}

// remainingTokens — pozostałe tokeny BEZ rezerwacji
// (czyli to co można jeszcze zarezerwować lub spalić).
func remainingTokens(c db.UsageCounter) int32 {
	rem := c.TokensLimit - c.TokensUsed - c.TokensReserved
	if rem < 0 {
		return 0
	}
	return rem
}

// isUniqueViolation — race detection na inserts (pending_reservations,
// usage_events). pgx zwraca *pgconn.PgError z kodem 23505 przy unique-violation.
func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return pgErr.Code == pgerrcode.UniqueViolation
	}
	return false
}

// ---------- CheckQuota ----------

func (s *Server) CheckQuota(ctx context.Context, req *billingv1.CheckQuotaRequest) (*billingv1.QuotaDecision, error) {
	orgID, err := parseUUID("organization_id", req.GetOrganizationId())
	if err != nil {
		return nil, err
	}

	amount := req.GetAmount()
	if amount <= 0 {
		amount = 1
	}

	sub, err := s.queries.GetActiveSubscriptionByOrg(ctx, orgID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			s.trackQuotaDenied(ctx, orgID, 0, 0)
			return &billingv1.QuotaDecision{
				Allowed: false,
				Reason:  "SUBSCRIPTION_INACTIVE",
			}, nil
		}
		slog.ErrorContext(ctx, "CheckQuota: GetActiveSubscriptionByOrg", "error", err, "org_id", orgID)
		return nil, status.Errorf(codes.Internal, "subscription lookup failed")
	}

	// PAST_DUE blokuje nowe rezerwacje per UX-design (sticky modal Flutter).
	if sub.Status == db.SubscriptionStatusPASTDUE {
		s.trackQuotaDenied(ctx, orgID, 0, 0)
		return &billingv1.QuotaDecision{
			Allowed: false,
			Reason:  "SUBSCRIPTION_PAST_DUE",
		}, nil
	}

	counter, err := s.queries.GetActiveCounter(ctx, sub.ID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Brak counter to znaczy że webhook handler (lub cron) nie zdążył
			// utworzyć nowego okresu. Zwracamy "denied" defensywnie — alert
			// na missing_counter w monitoring (§9.4) złapie to.
			slog.WarnContext(ctx, "CheckQuota: missing usage_counter for active subscription",
				"subscription_id", sub.ID, "org_id", orgID)
			s.trackQuotaDenied(ctx, orgID, 0, 0)
			return &billingv1.QuotaDecision{
				Allowed: false,
				Reason:  "QUOTA_COUNTER_MISSING",
			}, nil
		}
		slog.ErrorContext(ctx, "CheckQuota: GetActiveCounter", "error", err, "sub_id", sub.ID)
		return nil, status.Errorf(codes.Internal, "counter lookup failed")
	}

	remaining := remainingTokens(counter)
	allowed := remaining >= amount
	reason := "OK"
	if !allowed {
		reason = "QUOTA_EXHAUSTED"
		s.trackQuotaDenied(ctx, orgID, remaining, counter.TokensLimit)
	}

	return &billingv1.QuotaDecision{
		Allowed:         allowed,
		Reason:          reason,
		Remaining:       remaining,
		Limit:           counter.TokensLimit,
		RemainingTokens: remaining,
		LimitTokens:     counter.TokensLimit,
		PeriodEnd:       timestamppb.New(counter.PeriodEnd),
	}, nil
}

// ---------- ReserveCredit ----------

func (s *Server) ReserveCredit(ctx context.Context, req *billingv1.ReserveCreditRequest) (*billingv1.Reservation, error) {
	sessionID, err := parseUUID("session_id", req.GetSessionId())
	if err != nil {
		return nil, err
	}
	orgID, err := parseUUID("organization_id", req.GetOrganizationId())
	if err != nil {
		return nil, err
	}

	estTokens := req.GetEstimatedTokens()
	if estTokens <= 0 {
		estTokens = 1
	}

	// Pre-check poza transakcją — szybki idempotent path bez locka.
	// On hit we still want to return state_after for the client cache,
	// so we fetch sub + counter (s.subscriptionStateNow) only then.
	// The common case (fresh session_id) skips both extra queries.
	if existing, err := s.queries.GetReservationBySession(ctx, sessionID); err == nil {
		sub, serr := s.queries.GetActiveSubscriptionByOrg(ctx, orgID)
		if serr != nil {
			// Reservation exists without an active sub — anomalous but
			// not worth blocking the idempotent return on. Send the
			// reservation back with no state_after; client can call
			// GetSubscription if it cares.
			slog.WarnContext(ctx, "ReserveCredit: existing reservation but no active sub", "error", serr)
			return reservationToProto(existing, nil), nil
		}
		return reservationToProto(existing, s.subscriptionStateNow(ctx, sub)), nil
	} else if !errors.Is(err, pgx.ErrNoRows) {
		slog.ErrorContext(ctx, "ReserveCredit: pre-check", "error", err, "session_id", sessionID)
		return nil, status.Errorf(codes.Internal, "reservation lookup failed")
	}

	sub, err := s.queries.GetActiveSubscriptionByOrg(ctx, orgID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.FailedPrecondition, "SUBSCRIPTION_INACTIVE")
		}
		return nil, status.Errorf(codes.Internal, "subscription lookup failed")
	}
	if sub.Status == db.SubscriptionStatusPASTDUE {
		return nil, status.Error(codes.FailedPrecondition, "SUBSCRIPTION_PAST_DUE")
	}

	// Transakcja: advisory lock → lock counter row → sprawdź dostępność →
	// INSERT reservation → UPDATE counter.tokens_reserved.
	tx, err := s.tx.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin failed")
	}
	defer func() { _ = tx.Rollback(ctx) }()
	q := tx.Queries()

	if err := q.AcquireSubscriptionLock(ctx, sub.ID.String()); err != nil {
		slog.ErrorContext(ctx, "ReserveCredit: advisory lock", "error", err)
		return nil, status.Errorf(codes.Internal, "lock failed")
	}

	counter, err := q.LockActiveCounter(ctx, sub.ID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.FailedPrecondition, "QUOTA_COUNTER_MISSING")
		}
		return nil, status.Errorf(codes.Internal, "counter lock failed")
	}

	if remainingTokens(counter) < estTokens {
		return nil, status.Error(codes.ResourceExhausted, "QUOTA_EXHAUSTED")
	}

	expiresAt := time.Now().Add(s.reservationTTL)
	res, err := q.CreateReservation(ctx, db.CreateReservationParams{
		SessionID:      sessionID,
		SubscriptionID: sub.ID,
		OrganizationID: orgID,
		TokensReserved: estTokens,
		ExpiresAt:      expiresAt,
	})
	if err != nil {
		if isUniqueViolation(err) {
			// Race: równolegle wjechał drugi ReserveCredit dla tej samej sesji.
			// Rollback tx żeby nie trzymać advisory lock, refetch poza tx.
			_ = tx.Rollback(ctx)
			existing, qerr := s.queries.GetReservationBySession(ctx, sessionID)
			if qerr != nil {
				slog.ErrorContext(ctx, "ReserveCredit: race refetch failed", "error", qerr)
				return nil, status.Errorf(codes.Internal, "reservation race failed")
			}
			// Race winner already wrote the counter; reading it now
			// reflects the same state the client would see if they
			// called GetSubscription immediately after.
			return reservationToProto(existing, s.subscriptionStateNow(ctx, sub)), nil
		}
		slog.ErrorContext(ctx, "ReserveCredit: CreateReservation", "error", err)
		return nil, status.Errorf(codes.Internal, "reservation create failed")
	}

	if err := q.AddReservedTokens(ctx, db.AddReservedTokensParams{
		ID:             counter.ID,
		TokensReserved: estTokens,
	}); err != nil {
		slog.ErrorContext(ctx, "ReserveCredit: AddReservedTokens", "error", err)
		return nil, status.Errorf(codes.Internal, "counter update failed")
	}

	// Compute post-write counter snapshot to embed in the response
	// (state_after on the Reservation proto). Clients use this to
	// refresh their local cache without a follow-up GetSubscription.
	tokensUsedAfter := counter.TokensUsed
	tokensReservedAfter := counter.TokensReserved + estTokens
	tokensLimitAfter := counter.TokensLimit

	// Phase C of the client-cache refactor removed the outbox / Firestore-
	// mirror branch entirely. Clients now read counter state via
	// clinical-svc.GetMyBillingState (cold start) and via Reservation.
	// state_after on the response below — no async fanout needed.

	if err := tx.Commit(ctx); err != nil {
		slog.ErrorContext(ctx, "ReserveCredit: commit", "error", err)
		return nil, status.Errorf(codes.Internal, "commit failed")
	}

	stateAfter := buildSubscriptionProto(subFields{
		ID:                 sub.ID,
		PlanTier:           string(sub.PlanTier),
		PlanCycle:          string(sub.PlanCycle),
		Status:             string(sub.Status),
		CurrentPeriodStart: sub.CurrentPeriodStart,
		CurrentPeriodEnd:   sub.CurrentPeriodEnd,
	}, tokensUsedAfter, tokensReservedAfter, tokensLimitAfter)
	return reservationToProto(res, stateAfter), nil
}

// subscriptionStateNow fetches the current usage_counter for the given
// subscription and returns it as a *billingv1.Subscription. Used by
// the idempotent ReserveCredit pre-check + race-refetch paths where
// we want to populate state_after but didn't go through a write tx
// in this call. Falls back to a "limit-only" view if the counter row
// is unexpectedly missing (defensive — shouldn't happen for an active
// subscription).
func (s *Server) subscriptionStateNow(ctx context.Context, sub db.GetActiveSubscriptionByOrgRow) *billingv1.Subscription {
	counter, err := s.queries.GetActiveCounter(ctx, sub.ID)
	tokensUsed := int32(0)
	tokensReserved := int32(0)
	tokensLimit := sub.PlanTokensPerPeriod
	if err == nil {
		tokensUsed = counter.TokensUsed
		tokensReserved = counter.TokensReserved
		tokensLimit = counter.TokensLimit
	}
	return buildSubscriptionProto(subFields{
		ID:                 sub.ID,
		PlanTier:           string(sub.PlanTier),
		PlanCycle:          string(sub.PlanCycle),
		Status:             string(sub.Status),
		CurrentPeriodStart: sub.CurrentPeriodStart,
		CurrentPeriodEnd:   sub.CurrentPeriodEnd,
	}, tokensUsed, tokensReserved, tokensLimit)
}

func reservationToProto(r db.PendingReservation, stateAfter *billingv1.Subscription) *billingv1.Reservation {
	return &billingv1.Reservation{
		ReservationId:  r.ID.String(),
		SessionId:      r.SessionID.String(),
		TokensReserved: r.TokensReserved,
		StateAfter:     stateAfter,
		ExpiresAt:      timestamppb.New(r.ExpiresAt),
	}
}

// ---------- CommitUsage ----------

func (s *Server) CommitUsage(ctx context.Context, req *billingv1.CommitUsageRequest) (*billingv1.UsageCommit, error) {
	return s.commitInternal(ctx, commitInput{
		sessionIDRaw:    req.GetSessionId(),
		orgIDRaw:        req.GetOrganizationId(),
		durationSeconds: req.GetDurationSeconds(),
		usageType:       req.GetUsageType(),
		legacyAmount:    0,
	})
}

// IncrementUsage — legacy alias. amount → tokens 1:1, brak duration ⇒
// brak weryfikacji formuły token-duration.
//
//nolint:staticcheck // SA1019: IncrementUsageRequest jest jawnie deprecated, ale
// musimy zachować implementację dla Phase 2 callerów (proto marked deprecated
// jako sygnał migracyjny, nie jako "do not use server-side").
func (s *Server) IncrementUsage(ctx context.Context, req *billingv1.IncrementUsageRequest) (*emptypb.Empty, error) {
	_, err := s.commitInternal(ctx, commitInput{
		sessionIDRaw:    req.GetSessionId(),
		orgIDRaw:        req.GetOrganizationId(),
		durationSeconds: 0,
		usageType:       req.GetUsageType(),
		legacyAmount:    req.GetAmount(),
	})
	if err != nil {
		return nil, err
	}
	return &emptypb.Empty{}, nil
}

type commitInput struct {
	sessionIDRaw    string
	orgIDRaw        string
	durationSeconds int32
	usageType       string
	legacyAmount    int32
}

func (s *Server) commitInternal(ctx context.Context, in commitInput) (*billingv1.UsageCommit, error) {
	sessionID, err := parseUUID("session_id", in.sessionIDRaw)
	if err != nil {
		return nil, err
	}
	orgID, err := parseUUID("organization_id", in.orgIDRaw)
	if err != nil {
		return nil, err
	}

	usageType := in.usageType
	if usageType == "" {
		usageType = "session_analysis"
	}

	// Wylicz tokeny z duration_seconds; legacy ścieżka używa amount.
	var tokensToCharge int32
	if in.durationSeconds > 0 {
		tokensToCharge = tokens.Calculate(in.durationSeconds)
	} else if in.legacyAmount > 0 {
		tokensToCharge = in.legacyAmount
	} else {
		tokensToCharge = 1
	}

	// Pre-check idempotency poza tx.
	if existing, err := s.queries.GetUsageEventBySession(ctx, sessionID); err == nil {
		// No-op path: zwróć aktualny snapshot countera.
		return s.snapshotAfterCommit(ctx, orgID, existing.TokensConsumed)
	} else if !errors.Is(err, pgx.ErrNoRows) {
		slog.ErrorContext(ctx, "CommitUsage: pre-check", "error", err, "session_id", sessionID)
		return nil, status.Errorf(codes.Internal, "usage_event lookup failed")
	}

	sub, err := s.queries.GetActiveSubscriptionByOrg(ctx, orgID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.FailedPrecondition, "SUBSCRIPTION_INACTIVE")
		}
		return nil, status.Errorf(codes.Internal, "subscription lookup failed")
	}

	tx, err := s.tx.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin failed")
	}
	defer func() { _ = tx.Rollback(ctx) }()
	q := tx.Queries()

	if err := q.AcquireSubscriptionLock(ctx, sub.ID.String()); err != nil {
		return nil, status.Errorf(codes.Internal, "lock failed")
	}

	counter, err := q.LockActiveCounter(ctx, sub.ID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.FailedPrecondition, "QUOTA_COUNTER_MISSING")
		}
		return nil, status.Errorf(codes.Internal, "counter lock failed")
	}

	// Idempotent insert. Jeśli równolegle wjedzie inny commit dla tej samej
	// sesji — unique-violation, my refetch i no-op (po rollback).
	createdEvent, err := q.CreateUsageEvent(ctx, db.CreateUsageEventParams{
		SessionID:       sessionID,
		SubscriptionID:  sub.ID,
		OrganizationID:  orgID,
		TokensConsumed:  tokensToCharge,
		DurationSeconds: in.durationSeconds,
		UsageType:       usageType,
	})
	if err != nil {
		if isUniqueViolation(err) {
			_ = tx.Rollback(ctx)
			existing, qerr := s.queries.GetUsageEventBySession(ctx, sessionID)
			if qerr != nil {
				return nil, status.Errorf(codes.Internal, "usage race refetch failed")
			}
			return s.snapshotAfterCommit(ctx, orgID, existing.TokensConsumed)
		}
		slog.ErrorContext(ctx, "CommitUsage: CreateUsageEvent", "error", err)
		return nil, status.Errorf(codes.Internal, "usage_event create failed")
	}

	// Sprawdź czy była rezerwacja — jeśli tak, transfer tokens_reserved → tokens_used.
	reservedToRelease := int32(0)
	if existingRes, err := q.GetReservationBySession(ctx, sessionID); err == nil {
		if existingRes.Status == db.ReservationStatusACTIVE {
			reservedToRelease = existingRes.TokensReserved
			if err := q.MarkReservationCommitted(ctx, sessionID); err != nil {
				slog.ErrorContext(ctx, "CommitUsage: MarkReservationCommitted", "error", err)
				return nil, status.Errorf(codes.Internal, "reservation finalize failed")
			}
		}
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return nil, status.Errorf(codes.Internal, "reservation lookup failed")
	}

	if err := q.CommitTokens(ctx, db.CommitTokensParams{
		ID:              counter.ID,
		TokensUsed:      tokensToCharge,
		TokensReserved:  reservedToRelease,
	}); err != nil {
		slog.ErrorContext(ctx, "CommitUsage: CommitTokens", "error", err)
		return nil, status.Errorf(codes.Internal, "counter commit failed")
	}

	// Edge-triggered quota notification (§16.1). remainingBefore liczone
	// z locked counter PRZED UPDATE-em; remainingAfter to remainingBefore
	// minus tokens skonsumowanych + tokens zwolnionych z rezerwacji
	// (które już były w "reserved" więc nie są nową konsumpcją widoczną
	// dla terapeuty — patrz definicja remainingTokens).
	//
	// Definicja remaining = limit - used - reserved.
	// Po commit: used' = used + tokensToCharge, reserved' = reserved - reservedToRelease.
	// Phase C: the outbox + Firestore-mirror branch is gone. CommitUsage
	// is async w.r.t. the client (stt-finalize calls it after STT
	// completes), so we don't even need to return state_after timely —
	// the client's next cold-start GetMyBillingState picks up the new
	// tokens_used count. UsageCommit.state_after is still populated
	// below from the post-tx counter for any caller that wants it.

	if err := tx.Commit(ctx); err != nil {
		slog.ErrorContext(ctx, "CommitUsage: commit", "error", err)
		return nil, status.Errorf(codes.Internal, "commit failed")
	}

	// Post-commit snapshot (re-read counter).
	freshCounter, err := s.queries.GetActiveCounter(ctx, sub.ID)
	if err != nil {
		// Commit się udał, więc zwracamy success z best-effort snapshotem
		// (klient retry tak czy inaczej dostanie no-op path).
		return &billingv1.UsageCommit{
			TokensConsumed:  createdEvent.TokensConsumed,
			RemainingTokens: 0,
			LimitTokens:     counter.TokensLimit,
		}, nil
	}
	return &billingv1.UsageCommit{
		TokensConsumed:  createdEvent.TokensConsumed,
		RemainingTokens: remainingTokens(freshCounter),
		LimitTokens:     freshCounter.TokensLimit,
		StateAfter: buildSubscriptionProto(subFields{
			ID:                 sub.ID,
			PlanTier:           string(sub.PlanTier),
			PlanCycle:          string(sub.PlanCycle),
			Status:             string(sub.Status),
			CurrentPeriodStart: sub.CurrentPeriodStart,
			CurrentPeriodEnd:   sub.CurrentPeriodEnd,
		}, freshCounter.TokensUsed, freshCounter.TokensReserved, freshCounter.TokensLimit),
	}, nil
}

func (s *Server) snapshotAfterCommit(ctx context.Context, orgID uuid.UUID, alreadyCharged int32) (*billingv1.UsageCommit, error) {
	sub, err := s.queries.GetActiveSubscriptionByOrg(ctx, orgID)
	if err != nil {
		return &billingv1.UsageCommit{TokensConsumed: alreadyCharged}, nil
	}
	counter, err := s.queries.GetActiveCounter(ctx, sub.ID)
	if err != nil {
		return &billingv1.UsageCommit{TokensConsumed: alreadyCharged}, nil
	}
	return &billingv1.UsageCommit{
		TokensConsumed:  alreadyCharged,
		RemainingTokens: remainingTokens(counter),
		LimitTokens:     counter.TokensLimit,
		StateAfter: buildSubscriptionProto(subFields{
			ID:                 sub.ID,
			PlanTier:           string(sub.PlanTier),
			PlanCycle:          string(sub.PlanCycle),
			Status:             string(sub.Status),
			CurrentPeriodStart: sub.CurrentPeriodStart,
			CurrentPeriodEnd:   sub.CurrentPeriodEnd,
		}, counter.TokensUsed, counter.TokensReserved, counter.TokensLimit),
	}, nil
}

// ---------- ReleaseCredit ----------

func (s *Server) ReleaseCredit(ctx context.Context, req *billingv1.ReleaseCreditRequest) (*emptypb.Empty, error) {
	sessionID, err := parseUUID("session_id", req.GetSessionId())
	if err != nil {
		return nil, err
	}

	// Idempotent: jeśli już RELEASED/COMMITTED/EXPIRED — no-op.
	existing, err := s.queries.GetReservationBySession(ctx, sessionID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Brak rezerwacji = nic do zwolnienia, success.
			return &emptypb.Empty{}, nil
		}
		return nil, status.Errorf(codes.Internal, "reservation lookup failed")
	}
	if existing.Status != db.ReservationStatusACTIVE {
		return &emptypb.Empty{}, nil
	}

	tx, err := s.tx.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin failed")
	}
	defer func() { _ = tx.Rollback(ctx) }()
	q := tx.Queries()

	if err := q.AcquireSubscriptionLock(ctx, existing.SubscriptionID.String()); err != nil {
		return nil, status.Errorf(codes.Internal, "lock failed")
	}

	counter, err := q.LockActiveCounter(ctx, existing.SubscriptionID)
	if err != nil {
		// Brak counter — rezerwacja zostaje "zawieszona", ale to nie
		// powinno się zdarzyć (counter musi istnieć żeby kiedyś
		// rezerwację utworzono). Defensive: mark released, brak update countera.
		if errors.Is(err, pgx.ErrNoRows) {
			if err := q.MarkReservationReleased(ctx, sessionID); err != nil {
				return nil, status.Errorf(codes.Internal, "release without counter failed")
			}
			if err := tx.Commit(ctx); err != nil {
				return nil, status.Errorf(codes.Internal, "commit failed")
			}
			return &emptypb.Empty{}, nil
		}
		return nil, status.Errorf(codes.Internal, "counter lock failed")
	}

	if err := q.ReleaseReservedTokens(ctx, db.ReleaseReservedTokensParams{
		ID:             counter.ID,
		TokensReserved: existing.TokensReserved,
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "release tokens failed")
	}

	if err := q.MarkReservationReleased(ctx, sessionID); err != nil {
		return nil, status.Errorf(codes.Internal, "mark released failed")
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit failed")
	}

	return &emptypb.Empty{}, nil
}

// ---------- GetSubscription ----------

func (s *Server) GetSubscription(ctx context.Context, req *billingv1.GetSubscriptionRequest) (*billingv1.Subscription, error) {
	orgID, err := parseUUID("organization_id", req.GetOrganizationId())
	if err != nil {
		return nil, err
	}

	// Browser-caller scope check. The Connect interceptor populates
	// x-superwizor-organization-id from the validated Firebase token —
	// when present, the requested org_id MUST match (or the caller must
	// be SUPERWIZOR_ADMIN). Server-to-server callers (clinical-svc,
	// ingestion-svc, stt-worker, Cloud Scheduler) on the native-gRPC
	// path don't pass these headers, so the check is a no-op for them
	// and the existing trusted-caller contract is preserved.
	if md, ok := metadata.FromIncomingContext(ctx); ok {
		var callerRole, callerOrgID string
		if v := md.Get("x-superwizor-role"); len(v) > 0 {
			callerRole = v[0]
		}
		if v := md.Get("x-superwizor-organization-id"); len(v) > 0 {
			callerOrgID = v[0]
		}
		if callerOrgID != "" && callerOrgID != req.GetOrganizationId() && callerRole != "SUPERWIZOR_ADMIN" {
			return nil, status.Errorf(codes.PermissionDenied,
				"caller's organization does not match requested organization_id")
		}
	}

	sub, err := s.queries.GetActiveSubscriptionByOrg(ctx, orgID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "no active subscription")
		}
		return nil, status.Errorf(codes.Internal, "subscription lookup failed")
	}

	counter, cerr := s.queries.GetActiveCounter(ctx, sub.ID)
	tokensUsed := int32(0)
	tokensReserved := int32(0)
	tokensLimit := sub.PlanTokensPerPeriod
	if cerr == nil {
		tokensUsed = counter.TokensUsed
		tokensReserved = counter.TokensReserved
		tokensLimit = counter.TokensLimit
	}

	return buildSubscriptionProto(subFields{
		ID:                 sub.ID,
		PlanTier:           string(sub.PlanTier),
		PlanCycle:          string(sub.PlanCycle),
		Status:             string(sub.Status),
		CurrentPeriodStart: sub.CurrentPeriodStart,
		CurrentPeriodEnd:   sub.CurrentPeriodEnd,
	}, tokensUsed, tokensReserved, tokensLimit), nil
}

// subFields collects the subset of sqlc-generated subscription row
// fields we need to populate the proto Subscription message. Defined
// as its own type so the same builder works for both the GetActive*
// shape (used by GetSubscription) and the join-lite shape some other
// queries return — only the fields below are required.
type subFields struct {
	ID                 uuid.UUID
	PlanTier           string
	PlanCycle          string
	Status             string
	CurrentPeriodStart time.Time
	CurrentPeriodEnd   time.Time
}

// buildSubscriptionProto is the single source of truth for converting a
// (subscription, counter) pair into the proto Subscription message.
// Used by GetSubscription AND by ReserveCredit / CommitUsage to populate
// the Reservation.state_after / UsageCommit.state_after fields so
// clients can refresh their local billing cache from one round trip.
//
// tokens_remaining is server-computed as max(0, limit - used - reserved)
// per the proto contract — clients should not re-derive it.
func buildSubscriptionProto(s subFields, tokensUsed, tokensReserved, tokensLimit int32) *billingv1.Subscription {
	remaining := tokensLimit - tokensUsed - tokensReserved
	if remaining < 0 {
		remaining = 0
	}
	return &billingv1.Subscription{
		Id:                       s.ID.String(),
		PlanTier:                 s.PlanTier,
		PlanCycle:                s.PlanCycle,
		Status:                   s.Status,
		SessionsPerMonthLimit:    tokensLimit,
		SessionsUsedThisPeriod:   tokensUsed,
		TokensPerPeriod:          tokensLimit,
		TokensUsedThisPeriod:     tokensUsed,
		TokensReservedThisPeriod: tokensReserved,
		TokensRemaining:          remaining,
		CurrentPeriodStart:       timestamppb.New(s.CurrentPeriodStart),
		CurrentPeriodEnd:         timestamppb.New(s.CurrentPeriodEnd),
	}
}

func (s *Server) trackQuotaDenied(ctx context.Context, orgID uuid.UUID, remaining, limit int32) {
	if s.collector == nil {
		return
	}
	s.collector.Track(ctx, analytics.Event{
		Name:           "quota.denied",
		OrganizationID: &orgID,
		Properties: map[string]any{
			"tokens_remaining": remaining,
			"tokens_limit":     limit,
		},
		Source: "server",
	})
}
