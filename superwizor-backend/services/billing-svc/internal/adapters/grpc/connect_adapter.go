package grpc

import (
	"context"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/types/known/emptypb"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
)

// ConnectAdapter wraps *Server (the gRPC BillingServiceServer) as a
// Connect-RPC handler. Same pattern as identity-svc + clinical-svc
// adapters — see identity-svc/internal/adapters/grpc/connect_adapter.go
// for the design rationale.
//
// docs/18 §5 (R1). docs/19 commit 6.
type ConnectAdapter struct {
	s *Server
}

func NewConnectAdapter(s *Server) *ConnectAdapter { return &ConnectAdapter{s: s} }

func (a *ConnectAdapter) CheckQuota(ctx context.Context, req *connect.Request[billingv1.CheckQuotaRequest]) (*connect.Response[billingv1.QuotaDecision], error) {
	resp, err := a.s.CheckQuota(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ReserveCredit(ctx context.Context, req *connect.Request[billingv1.ReserveCreditRequest]) (*connect.Response[billingv1.Reservation], error) {
	resp, err := a.s.ReserveCredit(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) CommitUsage(ctx context.Context, req *connect.Request[billingv1.CommitUsageRequest]) (*connect.Response[billingv1.UsageCommit], error) {
	resp, err := a.s.CommitUsage(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ReleaseCredit(ctx context.Context, req *connect.Request[billingv1.ReleaseCreditRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.ReleaseCredit(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

//nolint:staticcheck // SA1019: IncrementUsageRequest is deprecated but connect adapter must mirror server.go.
func (a *ConnectAdapter) IncrementUsage(ctx context.Context, req *connect.Request[billingv1.IncrementUsageRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.IncrementUsage(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetSubscription(ctx context.Context, req *connect.Request[billingv1.GetSubscriptionRequest]) (*connect.Response[billingv1.Subscription], error) {
	resp, err := a.s.GetSubscription(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminResetTokens(ctx context.Context, req *connect.Request[billingv1.AdminResetTokensRequest]) (*connect.Response[billingv1.Subscription], error) {
	resp, err := a.s.AdminResetTokens(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminSetSeatAllocations(ctx context.Context, req *connect.Request[billingv1.AdminSetSeatAllocationsRequest]) (*connect.Response[billingv1.OrgSeatSummary], error) {
	resp, err := a.s.AdminSetSeatAllocations(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetMyOrgSeatUsage(ctx context.Context, req *connect.Request[emptypb.Empty]) (*connect.Response[billingv1.OrgSeatSummary], error) {
	resp, err := a.s.GetMyOrgSeatUsage(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminChangePlan(ctx context.Context, req *connect.Request[billingv1.AdminChangePlanRequest]) (*connect.Response[billingv1.Subscription], error) {
	resp, err := a.s.AdminChangePlan(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ListInvoices(ctx context.Context, req *connect.Request[billingv1.ListInvoicesRequest]) (*connect.Response[billingv1.ListInvoicesResponse], error) {
	resp, err := a.s.ListInvoices(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}
