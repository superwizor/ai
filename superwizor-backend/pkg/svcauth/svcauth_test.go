package svcauth

import (
	"context"
	"errors"
	"log/slog"
	"testing"

	"google.golang.org/api/idtoken"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

const (
	calleeAud   = "https://billing-svc-test.a.run.app"
	allowedSA   = "clinical-svc@proj.iam.gserviceaccount.com"
	unknownSA   = "attacker@evil.iam.gserviceaccount.com"
	someMethod  = "/billing.v1.BillingService/ReserveCredit"
	adminMethod = "/billing.v1.BillingService/AdminResetTokens"
)

func ctxWithToken(token string) context.Context {
	md := metadata.New(map[string]string{"authorization": "Bearer " + token})
	return metadata.NewIncomingContext(context.Background(), md)
}

func payload(email string, verified bool, aud string) *idtoken.Payload {
	return &idtoken.Payload{
		Audience: aud,
		Claims: map[string]any{
			"email":          email,
			"email_verified": verified,
		},
	}
}

func newValidator(t *testing.T, fn validateFunc, audiences ...string) *OIDCValidator {
	t.Helper()
	v := NewOIDCValidator([]string{allowedSA}, audiences)
	v.validate = fn
	return v
}

func okPayload(context.Context, string, string) (*idtoken.Payload, error) {
	return payload(allowedSA, true, calleeAud), nil
}

// --- Check() ---

func TestCheck_FailClosedWhenUnconfigured(t *testing.T) {
	v := NewOIDCValidator(nil, nil) // no SA allowlist
	v.validate = func(context.Context, string, string) (*idtoken.Payload, error) {
		t.Fatal("validate must not be called when unconfigured")
		return nil, nil
	}
	if err := v.Check(ctxWithToken("x")); status.Code(err) != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", err)
	}
}

func TestCheck_MissingMetadata(t *testing.T) {
	v := newValidator(t, okPayload)
	if err := v.Check(context.Background()); status.Code(err) != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", err)
	}
}

func TestCheck_MissingAuthorization(t *testing.T) {
	v := newValidator(t, okPayload)
	ctx := metadata.NewIncomingContext(context.Background(), metadata.New(nil))
	if err := v.Check(ctx); status.Code(err) != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", err)
	}
}

func TestCheck_InvalidToken(t *testing.T) {
	v := newValidator(t, func(context.Context, string, string) (*idtoken.Payload, error) {
		return nil, errors.New("idtoken: expired")
	})
	if err := v.Check(ctxWithToken("bad")); status.Code(err) != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", err)
	}
}

func TestCheck_UnknownServiceAccount(t *testing.T) {
	v := newValidator(t, func(context.Context, string, string) (*idtoken.Payload, error) {
		return payload(unknownSA, true, calleeAud), nil
	})
	if err := v.Check(ctxWithToken("t")); status.Code(err) != codes.PermissionDenied {
		t.Fatalf("want PermissionDenied, got %v", err)
	}
}

func TestCheck_UnverifiedEmail(t *testing.T) {
	v := newValidator(t, func(context.Context, string, string) (*idtoken.Payload, error) {
		return payload(allowedSA, false, calleeAud), nil
	})
	if err := v.Check(ctxWithToken("t")); status.Code(err) != codes.PermissionDenied {
		t.Fatalf("want PermissionDenied, got %v", err)
	}
}

func TestCheck_WrongAudienceRejectedWhenPinned(t *testing.T) {
	v := newValidator(t, func(context.Context, string, string) (*idtoken.Payload, error) {
		return payload(allowedSA, true, "https://evil.run.app"), nil
	}, calleeAud)
	if err := v.Check(ctxWithToken("t")); status.Code(err) != codes.PermissionDenied {
		t.Fatalf("want PermissionDenied for wrong audience, got %v", err)
	}
}

func TestCheck_AllowedSADifferentCasePasses(t *testing.T) {
	v := newValidator(t, func(context.Context, string, string) (*idtoken.Payload, error) {
		return payload("Clinical-SVC@Proj.iam.gserviceaccount.com", true, calleeAud), nil
	})
	if err := v.Check(ctxWithToken("t")); err != nil {
		t.Fatalf("case-insensitive SA match should pass, got %v", err)
	}
}

func TestCheck_HappyPath(t *testing.T) {
	v := newValidator(t, okPayload, calleeAud)
	if err := v.Check(ctxWithToken("good")); err != nil {
		t.Fatalf("valid internal call should pass, got %v", err)
	}
}

// --- interceptor policy ---

func runInterceptor(t *testing.T, v *OIDCValidator, policies map[string]Policy, method string, ctx context.Context) (bool, error) {
	t.Helper()
	ran := false
	h := func(ctx context.Context, req any) (any, error) { ran = true; return "ok", nil }
	interceptor := InternalAuthUnaryInterceptor(v, policies, slog.Default())
	_, err := interceptor(ctx, nil, &grpc.UnaryServerInfo{FullMethod: method}, h)
	return ran, err
}

func TestInterceptor_DenyMethodRejectedRegardlessOfToken(t *testing.T) {
	v := newValidator(t, okPayload) // even a perfectly valid SA token...
	policies := map[string]Policy{adminMethod: PolicyDeny}
	ran, err := runInterceptor(t, v, policies, adminMethod, ctxWithToken("valid"))
	if ran || status.Code(err) != codes.Unauthenticated {
		t.Fatalf("admin method must be denied on native transport; ran=%v err=%v", ran, err)
	}
}

func TestInterceptor_OIDCAllowsValidInternalCaller(t *testing.T) {
	v := newValidator(t, okPayload)
	policies := map[string]Policy{someMethod: PolicyOIDCInternal}
	ran, err := runInterceptor(t, v, policies, someMethod, ctxWithToken("valid"))
	if !ran || err != nil {
		t.Fatalf("valid internal caller should pass; ran=%v err=%v", ran, err)
	}
}

func TestInterceptor_OIDCRejectsUnknownCaller(t *testing.T) {
	v := newValidator(t, func(context.Context, string, string) (*idtoken.Payload, error) {
		return payload(unknownSA, true, calleeAud), nil
	})
	policies := map[string]Policy{someMethod: PolicyOIDCInternal}
	ran, err := runInterceptor(t, v, policies, someMethod, ctxWithToken("t"))
	if ran || status.Code(err) != codes.PermissionDenied {
		t.Fatalf("unknown SA must be rejected; ran=%v err=%v", ran, err)
	}
}

func TestInterceptor_UnlistedMethodFailsClosed(t *testing.T) {
	v := newValidator(t, okPayload)
	ran, err := runInterceptor(t, v, map[string]Policy{}, "/billing.v1.BillingService/SomethingNew", ctxWithToken("valid"))
	if ran || status.Code(err) != codes.Unauthenticated {
		t.Fatalf("unlisted method must fail closed; ran=%v err=%v", ran, err)
	}
}

func TestInterceptor_PassthroughRunsHandler(t *testing.T) {
	v := newValidator(t, okPayload)
	policies := map[string]Policy{"/notification.v1.NotificationService/RegisterFCMToken": PolicyPassthrough}
	ran, err := runInterceptor(t, v, policies, "/notification.v1.NotificationService/RegisterFCMToken", context.Background())
	if !ran || err != nil {
		t.Fatalf("passthrough should run handler without interceptor auth; ran=%v err=%v", ran, err)
	}
}

func TestInterceptor_InfraMethodsAlwaysPass(t *testing.T) {
	v := newValidator(t, okPayload)
	for _, m := range []string{"/grpc.health.v1.Health/Check", "/grpc.reflection.v1.ServerReflection/ServerReflectionInfo"} {
		ran, err := runInterceptor(t, v, map[string]Policy{}, m, context.Background())
		if !ran || err != nil {
			t.Fatalf("infra method %s must pass; ran=%v err=%v", m, ran, err)
		}
	}
}
