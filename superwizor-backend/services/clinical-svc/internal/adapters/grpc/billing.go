package grpc

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
)

// GetMyBillingState is the public-facing entry point Flutter calls to
// fetch the current quota / subscription snapshot. clinical-svc proxies
// through to billing-svc.GetSubscription because billing-svc is kept
// internal (no allUsers IAM); clinical-svc already authenticates the
// Firebase JWT for every public call so we reuse that surface here.
//
// Flow:
//  1. UnaryAuthInterceptor validated the caller's Firebase JWT and put
//     their user_id into ctx (UserIDKey).
//  2. We look up users.organization_id for that user.
//  3. We call billing-svc.GetSubscription(org_id) with the upstream
//     service-to-service OIDC token added by the BillingServiceClient.
//  4. We forward the response unchanged.
//
// Returns:
//   - Unauthenticated   — auth interceptor didn't set user_id (should
//                         never happen in production).
//   - NotFound          — caller has no organization yet (e.g. a
//                         partial trial-signup that rolled back; rare).
//   - Unavailable       — billing-svc client not wired (local dev).
//   - billing-svc errors (NotFound for no-active-subscription, etc.)
//     are forwarded as-is so Flutter can render the same dialogs.
func (s *Server) GetMyBillingState(ctx context.Context, _ *emptypb.Empty) (*billingv1.Subscription, error) {
	therapistIDStr, ok := ctx.Value(UserIDKey).(string)
	if !ok || therapistIDStr == "" {
		return nil, status.Error(codes.Unauthenticated, "missing user_id in context")
	}
	therapistID, err := uuid.Parse(therapistIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user_id in context")
	}

	orgID, err := s.queries.GetUserOrganizationID(ctx, therapistID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "user not found")
		}
		return nil, status.Errorf(codes.Internal, "user lookup failed: %v", err)
	}
	if !orgID.Valid {
		return nil, status.Error(codes.FailedPrecondition, "user has no organization")
	}
	orgIDStr := uuid.UUID(orgID.Bytes).String()

	if s.billing == nil {
		return nil, status.Error(codes.Unavailable, "billing client not wired")
	}

	// Forward the caller's incoming gRPC metadata so any tracing /
	// debugging headers propagate. The OIDC token for billing-svc is
	// injected by the BillingServiceClient itself (interceptor on the
	// outbound channel — same pattern as ingestion-svc).
	if md, mdOK := metadata.FromIncomingContext(ctx); mdOK {
		ctx = metadata.NewOutgoingContext(ctx, md)
	}

	sub, err := s.billing.GetSubscription(ctx, &billingv1.GetSubscriptionRequest{
		OrganizationId: orgIDStr,
	})
	if err != nil {
		// Forward the gRPC status verbatim so Flutter sees the same
		// NotFound / FailedPrecondition codes billing-svc emits.
		return nil, err
	}
	return sub, nil
}
