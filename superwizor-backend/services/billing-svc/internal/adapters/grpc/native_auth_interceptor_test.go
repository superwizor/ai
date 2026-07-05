package grpc

import (
	"context"
	"errors"
	"testing"

	"google.golang.org/api/idtoken"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

const (
	mAdminChangePlan   = "/billing.v1.BillingService/AdminChangePlan"
	mAdminResetTokens  = "/billing.v1.BillingService/AdminResetTokens"
	mGetMyOrgSeatUsage = "/billing.v1.BillingService/GetMyOrgSeatUsage"
	mReserveCredit     = "/billing.v1.BillingService/ReserveCredit"
	mGetSubscription   = "/billing.v1.BillingService/GetSubscription"
	mHealth            = "/grpc.health.v1.Health/Check"
	clinicalSA         = "clinical-svc@superwizor-ai-25ecd.iam.gserviceaccount.com"
	strangerSA         = "attacker@evil.example.com"
)

// ranHandler returns a handler that records that it ran + the metadata it saw.
func ranHandler(ran *bool, seen *metadata.MD) grpc.UnaryHandler {
	return func(ctx context.Context, req interface{}) (interface{}, error) {
		*ran = true
		if md, ok := metadata.FromIncomingContext(ctx); ok {
			*seen = md
		}
		return "ok", nil
	}
}

func ctxWithMD(kv ...string) context.Context {
	return metadata.NewIncomingContext(context.Background(), metadata.Pairs(kv...))
}


// #2 (the Critical): Admin* / org-admin browser RPCs have NO native caller —
// they must be rejected on the native path regardless of any forged role
// header, so the escalation is impossible.
func TestNative_RejectsAdminAndBrowserOnlyMethods(t *testing.T) {
	interceptor := NativeAuthInterceptor("", nil, nil) // even unconfigured
	for _, m := range []string{mAdminChangePlan, mAdminResetTokens, mGetMyOrgSeatUsage} {
		var ran bool
		var seen metadata.MD
		// Attacker forges an admin role on the native path:
		ctx := ctxWithMD("x-superwizor-role", "SUPERWIZOR_ADMIN")
		_, err := interceptor(ctx, nil, &grpc.UnaryServerInfo{FullMethod: m}, ranHandler(&ran, &seen))
		if status.Code(err) != codes.Unauthenticated {
			t.Errorf("%s: code = %v, want Unauthenticated", m, status.Code(err))
		}
		if ran {
			t.Errorf("%s: handler ran but should have been rejected", m)
		}
	}
}

func TestNative_HealthIsAnonymous(t *testing.T) {
	var ran bool
	var seen metadata.MD
	_, err := NativeAuthInterceptor("", nil, nil)(
		context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: mHealth}, ranHandler(&ran, &seen))
	if err != nil || !ran {
		t.Fatalf("health should pass: err=%v ran=%v", err, ran)
	}
}

// OIDC unconfigured: the S2S quota RPCs still run (no pipeline breakage) but
// any client-supplied x-superwizor-* is stripped before the handler.
func TestNative_QuotaRPC_UnconfiguredStripsForgedIdentity(t *testing.T) {
	var ran bool
	var seen metadata.MD
	ctx := ctxWithMD(
		"x-superwizor-role", "SUPERWIZOR_ADMIN",
		"x-superwizor-organization-id", "victim-org",
		"authorization", "Bearer whatever",
	)
	_, err := NativeAuthInterceptor("", nil, nil)(
		ctx, nil, &grpc.UnaryServerInfo{FullMethod: mReserveCredit}, ranHandler(&ran, &seen))
	if err != nil || !ran {
		t.Fatalf("quota RPC should run when OIDC unconfigured: err=%v ran=%v", err, ran)
	}
	if got := seen.Get("x-superwizor-role"); len(got) != 0 {
		t.Errorf("forged x-superwizor-role leaked to handler: %v", got)
	}
	if got := seen.Get("x-superwizor-organization-id"); len(got) != 0 {
		t.Errorf("forged x-superwizor-organization-id leaked to handler: %v", got)
	}
}

// OIDC configured: quota RPCs require a valid, allow-listed OIDC caller.
func TestNative_QuotaRPC_OIDCConfigured(t *testing.T) {
	aud := "https://billing-svc.run.app"
	allow := ParseAllowedSAs(clinicalSA)

	fakeValid := func(_ context.Context, token, audience string) (*idtoken.Payload, error) {
		if audience != aud {
			return nil, errors.New("bad audience")
		}
		if token == "good" {
			return &idtoken.Payload{Claims: map[string]interface{}{"email": clinicalSA, "email_verified": true}}, nil
		}
		if token == "stranger" {
			return &idtoken.Payload{Claims: map[string]interface{}{"email": strangerSA, "email_verified": true}}, nil
		}
		return nil, errors.New("invalid token")
	}
	itc := NativeAuthInterceptor(aud, allow, fakeValid)

	t.Run("allow: valid allow-listed SA", func(t *testing.T) {
		var ran bool
		var seen metadata.MD
		ctx := ctxWithMD("authorization", "Bearer good")
		if _, err := itc(ctx, nil, &grpc.UnaryServerInfo{FullMethod: mGetSubscription}, ranHandler(&ran, &seen)); err != nil || !ran {
			t.Fatalf("valid allow-listed OIDC should pass: err=%v ran=%v", err, ran)
		}
	})
	t.Run("deny: no token", func(t *testing.T) {
		var ran bool
		var seen metadata.MD
		_, err := itc(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: mReserveCredit}, ranHandler(&ran, &seen))
		if status.Code(err) != codes.Unauthenticated || ran {
			t.Fatalf("missing token: code=%v ran=%v, want Unauthenticated/false", status.Code(err), ran)
		}
	})
	t.Run("deny: non-allowlisted caller", func(t *testing.T) {
		var ran bool
		var seen metadata.MD
		ctx := ctxWithMD("authorization", "Bearer stranger")
		_, err := itc(ctx, nil, &grpc.UnaryServerInfo{FullMethod: mReserveCredit}, ranHandler(&ran, &seen))
		if status.Code(err) != codes.PermissionDenied || ran {
			t.Fatalf("stranger SA: code=%v ran=%v, want PermissionDenied/false", status.Code(err), ran)
		}
	})
	t.Run("deny: invalid token", func(t *testing.T) {
		var ran bool
		var seen metadata.MD
		ctx := ctxWithMD("authorization", "Bearer garbage")
		_, err := itc(ctx, nil, &grpc.UnaryServerInfo{FullMethod: mReserveCredit}, ranHandler(&ran, &seen))
		if status.Code(err) != codes.Unauthenticated || ran {
			t.Fatalf("invalid token: code=%v ran=%v, want Unauthenticated/false", status.Code(err), ran)
		}
	})
	t.Run("deny: Admin* still rejected even when OIDC configured", func(t *testing.T) {
		var ran bool
		var seen metadata.MD
		ctx := ctxWithMD("authorization", "Bearer good") // valid SA token, but Admin* has no native caller
		_, err := itc(ctx, nil, &grpc.UnaryServerInfo{FullMethod: mAdminChangePlan}, ranHandler(&ran, &seen))
		if status.Code(err) != codes.Unauthenticated || ran {
			t.Fatalf("Admin* over native: code=%v ran=%v, want Unauthenticated/false", status.Code(err), ran)
		}
	})
}
