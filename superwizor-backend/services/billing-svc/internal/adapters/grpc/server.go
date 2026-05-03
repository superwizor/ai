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
	// No-op in stub. Faza 3 będzie zapisywać do usage_quotas table.
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
