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

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

const (
	mAdminChangePlan   = "/billing.v1.BillingService/AdminChangePlan"
	mAdminResetTokens  = "/billing.v1.BillingService/AdminResetTokens"
	mGetMyOrgSeatUsage = "/billing.v1.BillingService/GetMyOrgSeatUsage"
	mReserveCredit     = "/billing.v1.BillingService/ReserveCredit"
	mGetSubscription   = "/billing.v1.BillingService/GetSubscription"
	mHealth            = "/grpc.health.v1.Health/Check"
	mGetBillingSurface = "/billing.v1.BillingService/GetBillingSurface"
	mVerifyStore       = "/billing.v1.BillingService/VerifyStorePurchase"
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
	interceptor := NativeAuthInterceptor("", nil, nil, nil) // even unconfigured
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
	_, err := NativeAuthInterceptor("", nil, nil, nil)(
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
	_, err := NativeAuthInterceptor("", nil, nil, nil)(
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
	itc := NativeAuthInterceptor(aud, allow, fakeValid, nil)

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

// ─── RPC sklepowe na ścieżce natywnej (docs/70 §7.2) ──────────────────────
//
// Aplikacja na iOS i Androidzie rozmawia z billing-svc po natywnym gRPC.
// Do 04.09.2026 interceptor odrzucał tam KAŻDY sklepowy RPC, więc paywall
// na telefonie nie mógł zadziałać — te testy pilnują, żeby wróciło i żeby
// wróciło z uwierzytelnieniem, a nie na zaufanie do metadanych.

// fakeIdentity podszywa się pod identity-svc: token "good" należy do
// terapeuty z organizacji, każdy inny jest odrzucany.
type fakeIdentity struct {
	identityv1.IdentityServiceClient
	calls int
}

const (
	fakeUserID = "11111111-1111-4111-8111-111111111111"
	fakeOrgID  = "22222222-2222-4222-8222-222222222222"
	victimOrg  = "33333333-3333-4333-8333-333333333333"
)

func (f *fakeIdentity) ValidateToken(_ context.Context, req *identityv1.ValidateTokenRequest, _ ...grpc.CallOption) (*identityv1.UserContext, error) {
	f.calls++
	if req.GetFirebaseIdToken() != "good" {
		return nil, errors.New("token rejected")
	}
	return &identityv1.UserContext{
		UserId:         fakeUserID,
		OrganizationId: fakeOrgID,
		Role:           identityv1.UserRole_USER_ROLE_THERAPIST,
	}, nil
}

func TestNative_StoreRPC_FirebaseTokenResolvesCaller(t *testing.T) {
	id := &fakeIdentity{}
	itc := NativeAuthInterceptor("", nil, nil, id)

	var ran bool
	var seen metadata.MD
	ctx := ctxWithMD("authorization", "Bearer good")
	if _, err := itc(ctx, nil, &grpc.UnaryServerInfo{FullMethod: mGetBillingSurface},
		ranHandler(&ran, &seen)); err != nil || !ran {
		t.Fatalf("GetBillingSurface z tokenem Firebase: err=%v ran=%v", err, ran)
	}
	if got := seen.Get("x-superwizor-organization-id"); len(got) != 1 || got[0] != fakeOrgID {
		t.Errorf("organizacja = %v, chciano %s — bez niej handler zwraca Unauthenticated", got, fakeOrgID)
	}
	if got := seen.Get("x-superwizor-user-id"); len(got) != 1 || got[0] != fakeUserID {
		t.Errorf("user-id = %v, chciano %s", got, fakeUserID)
	}
	if got := seen.Get("x-superwizor-role"); len(got) != 1 || got[0] != "THERAPIST" {
		t.Errorf("rola = %v, chciano THERAPIST", got)
	}
}

func TestNative_StoreRPC_ForgedOrgCannotWin(t *testing.T) {
	// Sedno: klient podaje SWOJĄ organizację w metadanych. Musi przegrać z
	// tą, którą zwrócił identity-svc — inaczej każdy z ważnym tokenem
	// kupowałby plan cudzej firmie.
	id := &fakeIdentity{}
	var ran bool
	var seen metadata.MD
	ctx := ctxWithMD(
		"authorization", "Bearer good",
		"x-superwizor-organization-id", victimOrg,
		"x-superwizor-role", "SUPERWIZOR_ADMIN",
	)
	if _, err := NativeAuthInterceptor("", nil, nil, id)(
		ctx, nil, &grpc.UnaryServerInfo{FullMethod: mVerifyStore},
		ranHandler(&ran, &seen)); err != nil || !ran {
		t.Fatalf("VerifyStorePurchase: err=%v ran=%v", err, ran)
	}
	if got := seen.Get("x-superwizor-organization-id"); len(got) != 1 || got[0] != fakeOrgID {
		t.Errorf("organizacja = %v — podrobiona wartość przebiła identity-svc", got)
	}
	if got := seen.Get("x-superwizor-role"); len(got) != 1 || got[0] != "THERAPIST" {
		t.Errorf("rola = %v — podrobiony SUPERWIZOR_ADMIN przeszedł", got)
	}
}

func TestNative_StoreRPC_RejectsBadAndMissingToken(t *testing.T) {
	itc := NativeAuthInterceptor("", nil, nil, &fakeIdentity{})
	for name, ctx := range map[string]context.Context{
		"bez nagłówka": context.Background(),
		"zły token":    ctxWithMD("authorization", "Bearer garbage"),
	} {
		var ran bool
		var seen metadata.MD
		_, err := itc(ctx, nil, &grpc.UnaryServerInfo{FullMethod: mGetBillingSurface},
			ranHandler(&ran, &seen))
		if status.Code(err) != codes.Unauthenticated || ran {
			t.Errorf("%s: code=%v ran=%v, chciano Unauthenticated/false", name, status.Code(err), ran)
		}
	}
}

func TestNative_StoreRPC_FailsClosedWithoutIdentity(t *testing.T) {
	// identity-svc niepodpięty: nie ma jak sprawdzić tokena, więc odmawiamy.
	// Wpuszczenie „na razie" oddałoby cudzą organizację każdemu, kto zna
	// jej UUID — ta sama zasada, co FailClosedConnectInterceptor.
	var ran bool
	var seen metadata.MD
	ctx := ctxWithMD("authorization", "Bearer good")
	_, err := NativeAuthInterceptor("", nil, nil, nil)(
		ctx, nil, &grpc.UnaryServerInfo{FullMethod: mGetBillingSurface},
		ranHandler(&ran, &seen))
	if status.Code(err) != codes.Unauthenticated || ran {
		t.Fatalf("code=%v ran=%v, chciano Unauthenticated/false", status.Code(err), ran)
	}
}

func TestNative_StoreRPC_DoesNotOpenAdminMethods(t *testing.T) {
	// Wpuszczenie czterech RPC sklepowych nie może otworzyć niczego więcej:
	// ważny token Firebase to nadal nie jest przepustka do Admin*.
	var ran bool
	var seen metadata.MD
	ctx := ctxWithMD("authorization", "Bearer good")
	_, err := NativeAuthInterceptor("", nil, nil, &fakeIdentity{})(
		ctx, nil, &grpc.UnaryServerInfo{FullMethod: mAdminChangePlan},
		ranHandler(&ran, &seen))
	if status.Code(err) != codes.Unauthenticated || ran {
		t.Fatalf("AdminChangePlan: code=%v ran=%v, chciano Unauthenticated/false", status.Code(err), ran)
	}
}
