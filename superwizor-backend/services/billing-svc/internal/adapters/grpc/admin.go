package grpc

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// minAuditReasonChars matches identity-svc — every SUPERWIZOR_ADMIN
// mutation must explain itself in at least 10 characters so the
// audit log is actionable.
const minAuditReasonChars = 10

// adminCaller is the resolved-from-metadata identity used to gate the
// AdminReset/AdminChange RPCs. billing-svc trusts the x-superwizor-role
// (and optional x-superwizor-user-id) metadata set by an upstream
// service (identity-svc proxy, or Next.js admin client behind a
// verified Firebase token). See docs/18 §2.3 — single-role MVP, the
// existing header propagation remains sufficient.
type adminCaller struct {
	role   string
	userID *uuid.UUID
}

func resolveAdminCaller(ctx context.Context) (adminCaller, error) {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return adminCaller{}, status.Error(codes.Unauthenticated, "no gRPC metadata")
	}
	roles := md.Get("x-superwizor-role")
	if len(roles) == 0 || strings.TrimSpace(roles[0]) == "" {
		return adminCaller{}, status.Error(codes.Unauthenticated, "x-superwizor-role missing")
	}
	c := adminCaller{role: roles[0]}
	if uids := md.Get("x-superwizor-user-id"); len(uids) > 0 {
		if u, err := uuid.Parse(uids[0]); err == nil {
			c.userID = &u
		}
	}
	return c, nil
}

func (c adminCaller) requireSuperwizorAdmin() error {
	if c.role != "SUPERWIZOR_ADMIN" {
		return status.Errorf(codes.PermissionDenied,
			"role %s not authorised for admin RPC", c.role)
	}
	return nil
}

// AdminResetTokens overrides usage_counters.tokens_used and/or tokens_limit
// for the org's currently-active subscription. Used for support cases:
// manual top-ups, refunds, mid-period grants.
//
// docs/18 §13.7. Required reason >= 10 chars. Audit row written.
func (s *Server) AdminResetTokens(ctx context.Context, req *billingv1.AdminResetTokensRequest) (*billingv1.Subscription, error) {
	caller, err := resolveAdminCaller(ctx)
	if err != nil {
		return nil, err
	}
	if err := caller.requireSuperwizorAdmin(); err != nil {
		return nil, err
	}
	if len(req.Reason) < minAuditReasonChars {
		return nil, status.Errorf(codes.InvalidArgument,
			"reason must be >= %d characters", minAuditReasonChars)
	}
	orgID, err := uuid.Parse(req.OrganizationId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid organization_id")
	}
	if req.TokensUsed == -1 && req.TokensLimit == -1 {
		return nil, status.Error(codes.InvalidArgument,
			"at least one of tokens_used or tokens_limit must be set (use -1 to skip)")
	}
	if req.TokensUsed < -1 {
		return nil, status.Error(codes.InvalidArgument, "tokens_used must be >= -1")
	}
	if req.TokensLimit == 0 || req.TokensLimit < -1 {
		return nil, status.Error(codes.InvalidArgument, "tokens_limit must be -1 (skip) or > 0")
	}

	// Single tx: advisory lock → load active counter → AdminUpdateCounter
	// → write audit → commit. The advisory lock prevents a concurrent
	// ReserveCredit from racing with the reset.
	tx, err := s.tx.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	q := tx.Queries()

	sub, err := q.GetActiveSubscriptionByOrg(ctx, orgID)
	reactivated := false
	if errors.Is(err, pgx.ErrNoRows) {
		// Live-fix 2026-07-04 (wariant A): test orgs run MANUAL subs the
		// Stripe-only renewal policy cancels after every period, which
		// made this support tool die with SUBSCRIPTION_INACTIVE on any
		// non-Stripe org. For MANUAL — and ONLY MANUAL, Stripe stays the
		// source of truth for its own subs — reactivate on the spot with
		// a fresh month, then proceed as normal (the counter is minted
		// below). The whole thing is audited with a `reactivated` flag.
		latest, lerr := q.GetLatestSubscriptionByOrg(ctx, orgID)
		switch {
		case lerr == nil && latest.Provider == "MANUAL":
			if _, rerr := q.ReactivateManualSubscription(ctx, latest.ID); rerr != nil {
				return nil, status.Errorf(codes.Internal, "reactivate manual sub: %v", rerr)
			}
			reactivated = true
			sub, err = q.GetActiveSubscriptionByOrg(ctx, orgID)
		case lerr == nil, errors.Is(lerr, pgx.ErrNoRows):
			return nil, status.Error(codes.FailedPrecondition, "SUBSCRIPTION_INACTIVE")
		default:
			return nil, status.Errorf(codes.Internal, "latest subscription: %v", lerr)
		}
	}
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.FailedPrecondition, "SUBSCRIPTION_INACTIVE")
		}
		return nil, status.Errorf(codes.Internal, "load subscription: %v", err)
	}
	if err := q.AcquireSubscriptionLock(ctx, sub.ID.String()); err != nil {
		return nil, status.Errorf(codes.Internal, "advisory lock: %v", err)
	}
	// docs/38: the reset covers BOTH counter scopes. The org-level
	// counter (solo/legacy) takes tokens_used and tokens_limit; every
	// active per-therapist counter takes tokens_used only (their limits
	// come from each seat's plan). B2B orgs may have no org-level row —
	// that's fine as long as at least one counter was touched.
	var therapistUsed *int32
	if req.TokensUsed != -1 {
		v := req.TokensUsed
		therapistUsed = &v
	}
	therapistRows, err := q.AdminResetTherapistCounters(ctx, db.AdminResetTherapistCountersParams{
		SubscriptionID: sub.ID,
		TokensUsed:     therapistUsed,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "reset therapist counters: %v", err)
	}

	var updated db.UsageCounter
	orgCounterFound := true
	counter, err := q.LockActiveCounter(ctx, sub.ID)
	switch {
	case err == nil:
		params := db.AdminUpdateCounterParams{ID: counter.ID}
		if req.TokensUsed != -1 {
			v := req.TokensUsed
			params.TokensUsed = &v
		}
		if req.TokensLimit != -1 {
			v := req.TokensLimit
			params.TokensLimit = &v
		}
		updated, err = q.AdminUpdateCounter(ctx, params)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "update counter: %v", err)
		}
	case errors.Is(err, pgx.ErrNoRows):
		// MANUAL subs (incl. the just-reactivated one) get a fresh
		// org-level counter minted right here: limit from the plan
		// unless the request overrides it, usage from the request.
		if sub.Provider == "MANUAL" {
			limit := sub.PlanTokensPerPeriod
			if req.TokensLimit != -1 {
				limit = req.TokensLimit
			}
			minted, merr := q.CreateUsageCounter(ctx, db.CreateUsageCounterParams{
				SubscriptionID: sub.ID,
				PeriodStart:    sub.CurrentPeriodStart,
				PeriodEnd:      sub.CurrentPeriodEnd,
				TokensLimit:    limit,
			})
			if merr != nil {
				return nil, status.Errorf(codes.Internal, "mint counter: %v", merr)
			}
			updated = minted
			if req.TokensUsed > 0 {
				v := req.TokensUsed
				updated, merr = q.AdminUpdateCounter(ctx, db.AdminUpdateCounterParams{
					ID: minted.ID, TokensUsed: &v,
				})
				if merr != nil {
					return nil, status.Errorf(codes.Internal, "seed counter usage: %v", merr)
				}
			}
			counter = updated
			break
		}
		orgCounterFound = false
		if therapistRows == 0 {
			return nil, status.Error(codes.FailedPrecondition, "QUOTA_COUNTER_MISSING")
		}
	default:
		return nil, status.Errorf(codes.Internal, "counter lock: %v", err)
	}
	meta := map[string]any{
		"therapist_counters_reset": therapistRows,
		"idempotency_key":          req.IdempotencyKey,
		"subscription_reactivated": reactivated,
	}
	if orgCounterFound {
		meta["tokens_used_before"] = counter.TokensUsed
		meta["tokens_limit_before"] = counter.TokensLimit
		meta["tokens_used_after"] = updated.TokensUsed
		meta["tokens_limit_after"] = updated.TokensLimit
	}
	if _, err := writeBillingAudit(ctx, q, caller, orgID, sub.ID,
		"billing.reset_tokens", req.Reason, meta); err != nil {
		return nil, status.Errorf(codes.Internal, "audit: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	var canceledAt *time.Time
	if sub.CanceledAt.Valid {
		canceledAt = &sub.CanceledAt.Time
	}

	usedAfter, reservedAfter, limitAfter := updated.TokensUsed, updated.TokensReserved, updated.TokensLimit
	if !orgCounterFound {
		// B2B org without an org-level counter: snapshot = aggregate over
		// the freshly-reset per-therapist counters.
		usedAfter, reservedAfter, limitAfter, _ = s.orgCounterOrAggregate(ctx, sub.ID)
	}

	return buildSubscriptionProto(subFields{
		ID:                 sub.ID,
		PlanTier:           string(sub.PlanTier),
		PlanCycle:          string(sub.PlanCycle),
		Status:             string(sub.Status),
		CurrentPeriodStart: sub.CurrentPeriodStart,
		CurrentPeriodEnd:   sub.CurrentPeriodEnd,
		CancelAtPeriodEnd:  sub.CancelAtPeriodEnd,
		CanceledAt:         canceledAt,
	}, usedAfter, reservedAfter, limitAfter), nil
}

// AdminChangePlan switches the org's subscription to a different plan
// tier + cycle. The current counter's tokens_used + tokens_reserved
// are PRESERVED — only tokens_limit moves to the new tier's value.
// If the operator wants a usage reset they call AdminResetTokens after.
//
// docs/18 §13.7. Required reason >= 10 chars. Audit row written.
func (s *Server) AdminChangePlan(ctx context.Context, req *billingv1.AdminChangePlanRequest) (*billingv1.Subscription, error) {
	caller, err := resolveAdminCaller(ctx)
	if err != nil {
		return nil, err
	}
	if err := caller.requireSuperwizorAdmin(); err != nil {
		return nil, err
	}
	if len(req.Reason) < minAuditReasonChars {
		return nil, status.Errorf(codes.InvalidArgument,
			"reason must be >= %d characters", minAuditReasonChars)
	}
	orgID, err := uuid.Parse(req.OrganizationId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid organization_id")
	}
	if req.PlanTier == "" || req.PlanCycle == "" {
		return nil, status.Error(codes.InvalidArgument, "plan_tier and plan_cycle required")
	}

	tx, err := s.tx.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	q := tx.Queries()

	sub, err := q.GetActiveSubscriptionByOrg(ctx, orgID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.FailedPrecondition, "SUBSCRIPTION_INACTIVE")
		}
		return nil, status.Errorf(codes.Internal, "load subscription: %v", err)
	}
	if err := q.AcquireSubscriptionLock(ctx, sub.ID.String()); err != nil {
		return nil, status.Errorf(codes.Internal, "advisory lock: %v", err)
	}

	// Resolve the new plan row.
	plan, err := q.AdminGetPlanByTierCycle(ctx, db.AdminGetPlanByTierCycleParams{
		Tier:  db.PlanTier(req.PlanTier),
		Cycle: db.BillingCycle(req.PlanCycle),
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Errorf(codes.InvalidArgument,
				"no active subscription_plans row for (%s, %s)", req.PlanTier, req.PlanCycle)
		}
		return nil, status.Errorf(codes.Internal, "lookup plan: %v", err)
	}

	// Flip the subscription's plan_id.
	subAfter, err := q.AdminChangeSubscriptionPlan(ctx, db.AdminChangeSubscriptionPlanParams{
		ID:     sub.ID,
		PlanID: plan.ID,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "change plan: %v", err)
	}

	// Update the active counter's tokens_limit to the new tier — leaves
	// tokens_used + tokens_reserved alone.
	counter, err := q.LockActiveCounter(ctx, sub.ID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.FailedPrecondition, "QUOTA_COUNTER_MISSING")
		}
		return nil, status.Errorf(codes.Internal, "counter lock: %v", err)
	}
	newLimit := plan.TokensPerPeriod
	counterAfter, err := q.AdminUpdateCounter(ctx, db.AdminUpdateCounterParams{
		ID:          counter.ID,
		TokensLimit: &newLimit,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update counter limit: %v", err)
	}

	if _, err := writeBillingAudit(ctx, q, caller, orgID, sub.ID,
		"billing.change_plan", req.Reason, map[string]any{
			"plan_tier_before":    string(sub.PlanTier),
			"plan_cycle_before":   string(sub.PlanCycle),
			"plan_tier_after":     req.PlanTier,
			"plan_cycle_after":    req.PlanCycle,
			"tokens_limit_before": counter.TokensLimit,
			"tokens_limit_after":  counterAfter.TokensLimit,
			"idempotency_key":     req.IdempotencyKey,
		}); err != nil {
		return nil, status.Errorf(codes.Internal, "audit: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	// subAfter has the new plan_id but we need plan_tier + plan_cycle
	// from the new plan row to populate the proto. The subscriptions
	// table doesn't store those directly — it derives via the JOIN
	// used by GetActiveSubscriptionByOrg. For the response we know
	// the new values came from the request itself.
	_ = subAfter
	var canceledAt *time.Time
	if sub.CanceledAt.Valid {
		canceledAt = &sub.CanceledAt.Time
	}

	return buildSubscriptionProto(subFields{
		ID:                 sub.ID,
		PlanTier:           req.PlanTier,
		PlanCycle:          req.PlanCycle,
		Status:             string(sub.Status),
		CurrentPeriodStart: sub.CurrentPeriodStart,
		CurrentPeriodEnd:   sub.CurrentPeriodEnd,
		CancelAtPeriodEnd:  sub.CancelAtPeriodEnd,
		CanceledAt:         canceledAt,
	}, counterAfter.TokensUsed, counterAfter.TokensReserved, counterAfter.TokensLimit), nil
}

// writeBillingAudit records a SUPERWIZOR_ADMIN mutation. Wrapped here
// (rather than inlined per RPC) so the JSON marshaling + actor handling
// stays consistent. q is the per-tx Querier — keeps the audit row in
// the same tx as the data change.
func writeBillingAudit(
	ctx context.Context,
	q db.Querier,
	caller adminCaller,
	orgID, resourceID uuid.UUID,
	action, reason string,
	metadata map[string]any,
) (db.AuditEvent, error) {
	meta := []byte("{}")
	if metadata != nil {
		if b, err := json.Marshal(metadata); err == nil {
			meta = b
		}
	}
	params := db.CreateBillingAuditEventParams{
		Action:         action,
		ResourceType:   "subscription",
		ResourceID:     pgtype.UUID{Bytes: resourceID, Valid: true},
		OrganizationID: pgtype.UUID{Bytes: orgID, Valid: true},
		Metadata:       meta,
		Reason:         &reason,
	}
	if caller.userID != nil {
		params.ActorUserID = pgtype.UUID{Bytes: *caller.userID, Valid: true}
	}
	return q.CreateBillingAuditEvent(ctx, params)
}
