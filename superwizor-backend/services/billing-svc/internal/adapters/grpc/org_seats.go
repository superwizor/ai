package grpc

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// Seat allocations + org seat usage (docs/38 §4).

// AdminSetSeatAllocations provisions/updates the org's seat allocations
// (plan × seats × negotiated price) and ensures a MANUAL subscription
// exists. SUPERWIZOR_ADMIN only; reason >= 10 chars → audit_events.
//
// Counter provisioning: per-therapist counters are created for
// ALREADY-SEATED therapists right away (so the dashboard shows rows
// immediately); therapists who join later get theirs lazily on first
// ReserveCredit (counter_scope.go). Existing counters are never reset.
//
// MVP simplification (docs/38 §3): all counters share the SUBSCRIPTION
// period. Mixed-cycle allocations (MONTHLY + ANNUAL) renew together on
// the subscription's cadence; tokens_limit still comes from each seat's
// own plan.
func (s *Server) AdminSetSeatAllocations(ctx context.Context, req *billingv1.AdminSetSeatAllocationsRequest) (*billingv1.OrgSeatSummary, error) {
	caller, err := resolveAdminCaller(ctx)
	if err != nil {
		return nil, err
	}
	if err := caller.requireSuperwizorAdmin(); err != nil {
		return nil, err
	}
	if len(req.GetReason()) < minAuditReasonChars {
		return nil, status.Errorf(codes.InvalidArgument,
			"reason must be >= %d characters", minAuditReasonChars)
	}
	orgID, err := parseUUID("organization_id", req.GetOrganizationId())
	if err != nil {
		return nil, err
	}
	if len(req.GetAllocations()) == 0 {
		return nil, status.Error(codes.InvalidArgument, "at least one allocation required")
	}

	// Validate specs up-front (plan exists, seats >= 0, price parses).
	type allocSpec struct {
		planID uuid.UUID
		seats  int32
		price  pgtype.Numeric // NULL = catalog price
		plan   db.GetPlanByIDRow
	}
	specs := make([]allocSpec, 0, len(req.GetAllocations()))
	for _, a := range req.GetAllocations() {
		planID, err := parseUUID("plan_id", a.GetPlanId())
		if err != nil {
			return nil, err
		}
		if a.GetSeats() < 0 {
			return nil, status.Error(codes.InvalidArgument, "seats must be >= 0")
		}
		plan, err := s.queries.GetPlanByID(ctx, planID)
		if err != nil {
			return nil, status.Errorf(codes.NotFound, "plan %s not found", planID)
		}
		spec := allocSpec{planID: planID, seats: a.GetSeats(), plan: plan}
		if p := strings.TrimSpace(a.GetPriceGrossPerSeat()); p != "" {
			// NUMERIC(10,2)-shaped, non-negative decimal string. Scan
			// validates the syntax; the regex-free prefix check rejects
			// signs/exponents that Scan would accept.
			if strings.HasPrefix(p, "-") || strings.HasPrefix(p, "+") ||
				strings.ContainsAny(p, "eE ") {
				return nil, status.Errorf(codes.InvalidArgument,
					"invalid price_gross_per_seat %q", p)
			}
			if err := spec.price.Scan(p); err != nil {
				return nil, status.Errorf(codes.InvalidArgument,
					"invalid price_gross_per_seat %q", p)
			}
		}
		specs = append(specs, spec)
	}

	tx, err := s.tx.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin failed")
	}
	defer func() { _ = tx.Rollback(ctx) }()
	q := tx.Queries()

	// Subscription: reuse the running one; create MANUAL if absent.
	sub, err := s.queries.GetActiveSubscriptionByOrg(ctx, orgID)
	var subID uuid.UUID
	var periodStart, periodEnd time.Time
	switch {
	case err == nil:
		subID = sub.ID
		periodStart, periodEnd = sub.CurrentPeriodStart, sub.CurrentPeriodEnd
	case errors.Is(err, pgx.ErrNoRows):
		start := time.Now()
		if ts := req.GetSubscriptionStart(); ts != nil {
			start = ts.AsTime()
		}
		end := start.AddDate(0, 1, 0) // monthly cadence (docs/38 MVP)
		// Primary plan for the subscription row = the largest allocation.
		// Enforcement no longer reads it (per-seat counters do), but the
		// admin UI and legacy paths show its tier.
		primary := specs[0]
		for _, sp := range specs {
			if sp.seats > primary.seats {
				primary = sp
			}
		}
		created, cerr := q.CreateManualSubscription(ctx, db.CreateManualSubscriptionParams{
			OrganizationID:         orgID,
			PlanID:                 primary.planID,
			ProviderSubscriptionID: "b2b-" + orgID.String(),
			CurrentPeriodStart:     start,
			CurrentPeriodEnd:       end,
		})
		if cerr != nil {
			return nil, status.Errorf(codes.Internal, "create subscription: %v", cerr)
		}
		subID = created.ID
		periodStart, periodEnd = created.CurrentPeriodStart, created.CurrentPeriodEnd
	default:
		return nil, status.Errorf(codes.Internal, "subscription lookup failed")
	}

	if err := q.AcquireSubscriptionLock(ctx, subID.String()); err != nil {
		return nil, status.Errorf(codes.Internal, "lock failed")
	}

	for _, sp := range specs {
		if _, err := q.UpsertSeatAllocation(ctx, db.UpsertSeatAllocationParams{
			OrganizationID:    orgID,
			PlanID:            sp.planID,
			Seats:             sp.seats,
			PriceGrossPerSeat: sp.price,
			CurrencyCode:      "PLN",
		}); err != nil {
			return nil, status.Errorf(codes.Internal, "upsert allocation: %v", err)
		}
	}

	// Eager counters for already-seated therapists (idempotent — the
	// partial unique index absorbs re-runs; existing counters keep
	// their usage).
	seated, err := q.ListSeatedTherapistsByOrg(ctx, orgID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list seated therapists: %v", err)
	}
	for _, t := range seated {
		_, err := q.CreateTherapistUsageCounter(ctx, db.CreateTherapistUsageCounterParams{
			SubscriptionID: subID,
			TherapistID:    pgtype.UUID{Bytes: t.TherapistID, Valid: true},
			PeriodStart:    periodStart,
			PeriodEnd:      periodEnd,
			TokensLimit:    t.TokensPerPeriod,
		})
		if err != nil && !isUniqueViolation(err) {
			return nil, status.Errorf(codes.Internal, "create counter for %s: %v", t.TherapistID, err)
		}
	}

	if _, err := writeBillingAudit(ctx, q, caller, orgID, subID,
		"ADMIN_SET_SEAT_ALLOCATIONS", req.GetReason(), map[string]any{
			"allocations": len(specs),
		}); err != nil {
		return nil, status.Errorf(codes.Internal, "audit: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit failed")
	}

	return s.buildOrgSeatSummary(ctx, orgID)
}

// GetMyOrgSeatUsage returns seat occupancy + per-therapist usage for
// the caller's own organization. ORG_ADMIN only; the org is resolved
// from the authenticated context (never from a request field).
func (s *Server) GetMyOrgSeatUsage(ctx context.Context, _ *emptypb.Empty) (*billingv1.OrgSeatSummary, error) {
	caller, err := resolveAdminCaller(ctx)
	if err != nil {
		return nil, err
	}
	if caller.role != "ORG_ADMIN" && caller.role != "SUPERWIZOR_ADMIN" {
		return nil, status.Errorf(codes.PermissionDenied,
			"role %s not authorised for org seat usage", caller.role)
	}
	orgID, err := orgIDFromContext(ctx)
	if err != nil {
		return nil, err
	}
	return s.buildOrgSeatSummary(ctx, orgID)
}

func (s *Server) buildOrgSeatSummary(ctx context.Context, orgID uuid.UUID) (*billingv1.OrgSeatSummary, error) {
	out := &billingv1.OrgSeatSummary{OrganizationId: orgID.String()}

	allocs, err := s.queries.ListSeatAllocationsByOrg(ctx, orgID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list allocations: %v", err)
	}
	for _, a := range allocs {
		info := &billingv1.SeatAllocationInfo{
			AllocationId:  a.ID.String(),
			PlanId:        a.PlanID.String(),
			PlanTier:      string(a.PlanTier),
			PlanCycle:     string(a.PlanCycle),
			Seats:         a.Seats,
			SeatsAssigned: int32(a.SeatsAssigned),
			SeatsPending:  int32(a.SeatsPending),
			CurrencyCode:  strings.TrimSpace(a.CurrencyCode),
			TokensPerSeat: a.TokensPerPeriod,
		}
		info.PriceGrossPerSeat = numericToDecimalString(a.PriceGrossPerSeat)
		if info.PriceGrossPerSeat == "" {
			info.PriceGrossPerSeat = numericToDecimalString(a.CatalogPriceGross)
		}
		out.Allocations = append(out.Allocations, info)
	}

	sub, err := s.queries.GetActiveSubscriptionByOrg(ctx, orgID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return out, nil // allocations set but no subscription yet
		}
		return nil, status.Errorf(codes.Internal, "subscription lookup failed")
	}
	out.SubscriptionStatus = string(sub.Status)
	out.PeriodStart = timestamppb.New(sub.CurrentPeriodStart)
	out.PeriodEnd = timestamppb.New(sub.CurrentPeriodEnd)

	counters, err := s.queries.ListActiveTherapistCounters(ctx, sub.ID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list therapist counters: %v", err)
	}
	seatedByID := map[uuid.UUID]db.ListSeatedTherapistsByOrgRow{}
	if seated, err := s.queries.ListSeatedTherapistsByOrg(ctx, orgID); err == nil {
		for _, t := range seated {
			seatedByID[t.TherapistID] = t
		}
	}
	counterByID := map[uuid.UUID]bool{}
	for _, c := range counters {
		tid := uuid.UUID(c.TherapistID.Bytes)
		counterByID[tid] = true
		usage := &billingv1.TherapistSeatUsage{
			TherapistId:    tid.String(),
			FirstName:      c.FirstName,
			LastName:       c.LastName,
			TokensUsed:     c.TokensUsed,
			TokensReserved: c.TokensReserved,
			TokensLimit:    c.TokensLimit,
			IsActive:       c.IsActive,
		}
		if t, ok := seatedByID[tid]; ok {
			usage.PlanTier = string(t.PlanTier)
		}
		out.TherapistUsage = append(out.TherapistUsage, usage)
	}
	// Seated therapists without a counter yet (lazy minting hasn't
	// fired this period) — show them with zero usage at full limit.
	for tid, t := range seatedByID {
		if counterByID[tid] {
			continue
		}
		out.TherapistUsage = append(out.TherapistUsage, &billingv1.TherapistSeatUsage{
			TherapistId: tid.String(),
			FirstName:   t.FirstName,
			LastName:    t.LastName,
			PlanTier:    string(t.PlanTier),
			TokensLimit: t.TokensPerPeriod,
			IsActive:    t.IsActive,
		})
	}

	return out, nil
}

// orgIDFromContext reads x-superwizor-organization-id — set by the
// billing auth interceptor from the verified token (never trusted from
// the request payload).
func orgIDFromContext(ctx context.Context) (uuid.UUID, error) {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return uuid.Nil, status.Error(codes.Unauthenticated, "no gRPC metadata")
	}
	vals := md.Get("x-superwizor-organization-id")
	if len(vals) == 0 || strings.TrimSpace(vals[0]) == "" {
		return uuid.Nil, status.Error(codes.FailedPrecondition, "caller has no organization")
	}
	orgID, err := uuid.Parse(vals[0])
	if err != nil {
		return uuid.Nil, status.Error(codes.Unauthenticated, "invalid organization id in context")
	}
	return orgID, nil
}

// numericToDecimalString renders a pgtype.Numeric as a plain decimal
// string ("79.99"); empty for NULL.
func numericToDecimalString(n pgtype.Numeric) string {
	if !n.Valid {
		return ""
	}
	d, err := n.Value()
	if err != nil || d == nil {
		return ""
	}
	if s, ok := d.(string); ok {
		return s
	}
	return ""
}

// AdminListPlans returns the active plan catalog for the seat-allocation
// wizard. SUPERWIZOR_ADMIN only.
func (s *Server) AdminListPlans(ctx context.Context, _ *emptypb.Empty) (*billingv1.AdminListPlansResponse, error) {
	caller, err := resolveAdminCaller(ctx)
	if err != nil {
		return nil, err
	}
	if err := caller.requireSuperwizorAdmin(); err != nil {
		return nil, err
	}
	plans, err := s.queries.ListActivePlans(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list plans: %v", err)
	}
	out := &billingv1.AdminListPlansResponse{}
	for _, p := range plans {
		out.Plans = append(out.Plans, &billingv1.PlanInfo{
			PlanId:          p.ID.String(),
			Tier:            string(p.Tier),
			Cycle:           string(p.Cycle),
			DisplayName:     p.DisplayName,
			PriceGross:      numericToDecimalString(p.PriceGross),
			CurrencyCode:    strings.TrimSpace(p.CurrencyCode),
			TokensPerPeriod: p.TokensPerPeriod,
		})
	}
	return out, nil
}

// AdminGetOrgSeatUsage — the SUPERWIZOR_ADMIN read of any org's seat
// state (/admin/orgs/[id] edit surface). Same summary builder as
// GetMyOrgSeatUsage; org comes from the request, role-gated.
func (s *Server) AdminGetOrgSeatUsage(ctx context.Context, req *billingv1.AdminGetOrgSeatUsageRequest) (*billingv1.OrgSeatSummary, error) {
	caller, err := resolveAdminCaller(ctx)
	if err != nil {
		return nil, err
	}
	if err := caller.requireSuperwizorAdmin(); err != nil {
		return nil, err
	}
	orgID, err := parseUUID("organization_id", req.GetOrganizationId())
	if err != nil {
		return nil, err
	}
	return s.buildOrgSeatSummary(ctx, orgID)
}
