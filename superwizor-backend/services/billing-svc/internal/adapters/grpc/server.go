package grpc

import (
	"context"

	"google.golang.org/protobuf/types/known/emptypb"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
)

// Server is a STUB implementation. Always returns "allowed" for any quota check.
// Replaced with full Stripe integration in Faza 3.
type Server struct {
	billingv1.UnimplementedBillingServiceServer
	version string
}

func NewServer(version string) *Server {
	return &Server{version: version}
}

func (s *Server) CheckQuota(ctx context.Context, req *billingv1.CheckQuotaRequest) (*billingv1.QuotaDecision, error) {
	return &billingv1.QuotaDecision{
		Allowed:   true,
		Reason:    "stub: always allowed in Faza 2",
		Remaining: 999,
		Limit:     1000,
	}, nil
}

func (s *Server) IncrementUsage(ctx context.Context, req *billingv1.IncrementUsageRequest) (*emptypb.Empty, error) {
	// STUB. No-op until Faza 3 wires usage_events + counter denormalization.
	//
	// IDEMPOTENCY NOTE (preserves the Faza 3 implementor's life):
	// `req.IdempotencyKey` is currently ignored. When the real handler
	// lands it MUST honor the key because IncrementUsage is the
	// entitlement-gate write path — a Cloud Run retry without
	// idempotency double-counts billable usage. Reference plan:
	// docs/agents/TODO.md "Idempotency keys are silently ignored…"
	// (the IncrementUsage row is flagged "higher stakes").
	//
	// Required shape for the real handler:
	//
	//   - Schema (new migration, e.g. 000019_usage_events.up.sql):
	//     CREATE TABLE usage_events (
	//       id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	//       therapist_id    UUID NOT NULL REFERENCES users(id),
	//       kind            VARCHAR(64) NOT NULL,
	//       quantity        INTEGER NOT NULL DEFAULT 1,
	//       idempotency_key VARCHAR(128),
	//       created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
	//     );
	//     CREATE UNIQUE INDEX ux_usage_events_idempotency
	//       ON usage_events (therapist_id, idempotency_key)
	//       WHERE idempotency_key IS NOT NULL;
	//
	//   - Handler pattern (same as CreatePatientFile + CreateAudioUpload
	//     in this PR): pre-check by (therapist_id, key); if hit, short-
	//     circuit return Empty WITHOUT incrementing the
	//     usage_counters denormalization. INSERT wrapped with
	//     unique-violation catch on ux_usage_events_idempotency for
	//     the cache-miss race window — loser re-fetches and returns
	//     the cached row's Empty response.
	//
	//   - Counter denormalization MUST be gated by `isNewlyCreated`
	//     so replay doesn't double-bump the counter.
	//
	//   - Empty/NULL key = opt-out (matches the pattern for the other
	//     two RPCs); but for billing specifically, the Faza 3 plan
	//     should consider whether to REQUIRE non-empty key (the
	//     financial risk argues for stricter validation here).
	//
	// Until this lands, IncrementUsage is a no-op so the gRPC contract
	// stays compatible. Do NOT add idempotency storage here as a
	// "head start" — the table doesn't exist, and a half-implemented
	// idempotency layer is worse than none.
	return &emptypb.Empty{}, nil
}

func (s *Server) GetSubscription(ctx context.Context, req *billingv1.GetSubscriptionRequest) (*billingv1.Subscription, error) {
	return &billingv1.Subscription{
		Id:                     "sub_stub_123",
		PlanTier:               "PRO",
		Status:                 "active",
		SessionsPerMonthLimit:  1000,
		SessionsUsedThisPeriod: 1,
	}, nil
}
