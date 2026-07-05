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
	sendInvitation  = "/notification.v1.NotificationService/SendInvitationEmail"
	sendContact     = "/notification.v1.NotificationService/SendContactEmail"
	registerFCM     = "/notification.v1.NotificationService/RegisterFCMToken"
	healthCheck     = "/grpc.health.v1.Health/Check"
	allowedSAEmail  = "clinical-svc@proj.iam.gserviceaccount.com"
	strangerSAEmail = "attacker@evil.iam.gserviceaccount.com"
	notifAud        = "https://notification-svc-xyz.a.run.app"
)

func fakeValidatorOK(email string, verified bool) idTokenValidator {
	return func(_ context.Context, _, _ string) (*idtoken.Payload, error) {
		return &idtoken.Payload{Claims: map[string]interface{}{
			"email":          email,
			"email_verified": verified,
		}}, nil
	}
}

func fakeValidatorErr(err error) idTokenValidator {
	return func(_ context.Context, _, _ string) (*idtoken.Payload, error) { return nil, err }
}

func ctxWithBearer(tok string) context.Context {
	md := metadata.New(map[string]string{"authorization": "Bearer " + tok})
	return metadata.NewIncomingContext(context.Background(), md)
}

func allowSet() map[string]struct{} { return map[string]struct{}{allowedSAEmail: {}} }

func passHandler() (grpc.UnaryHandler, *bool) {
	ran := false
	return func(context.Context, interface{}) (interface{}, error) { ran = true; return "ok", nil }, &ran
}

func TestOIDC_NonInternalMethodAlwaysPasses(t *testing.T) {
	// A validator that would fail if invoked — proves it's never called.
	interceptor := InternalOIDCInterceptor(notifAud, allowSet(), fakeValidatorErr(errors.New("should not run")))
	for _, m := range []string{registerFCM, healthCheck} {
		h, ran := passHandler()
		_, err := interceptor(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: m}, h)
		if err != nil {
			t.Fatalf("%s should pass through, got %v", m, err)
		}
		if !*ran {
			t.Fatalf("%s handler not reached", m)
		}
	}
}

func TestOIDC_UnconfiguredIsTransitionSafe(t *testing.T) {
	// audience + SAs unset → internal Send* still runs (no break during rollout).
	interceptor := InternalOIDCInterceptor("", nil, fakeValidatorErr(errors.New("should not run")))
	h, ran := passHandler()
	_, err := interceptor(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: sendInvitation}, h)
	if err != nil || !*ran {
		t.Fatalf("unconfigured gate should pass internal method: err=%v ran=%v", err, *ran)
	}
}

func TestOIDC_InternalRequiresToken(t *testing.T) {
	interceptor := InternalOIDCInterceptor(notifAud, allowSet(), fakeValidatorOK(allowedSAEmail, true))
	h, ran := passHandler()
	_, err := interceptor(context.Background(), nil, &grpc.UnaryServerInfo{FullMethod: sendInvitation}, h)
	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", err)
	}
	if *ran {
		t.Error("handler must not run without a token")
	}
}

func TestOIDC_InvalidTokenRejected(t *testing.T) {
	interceptor := InternalOIDCInterceptor(notifAud, allowSet(), fakeValidatorErr(errors.New("expired")))
	h, ran := passHandler()
	_, err := interceptor(ctxWithBearer("bad"), nil, &grpc.UnaryServerInfo{FullMethod: sendContact}, h)
	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", err)
	}
	if *ran {
		t.Error("handler must not run on invalid token")
	}
}

func TestOIDC_AllowedCallerRuns(t *testing.T) {
	interceptor := InternalOIDCInterceptor(notifAud, allowSet(), fakeValidatorOK(allowedSAEmail, true))
	h, ran := passHandler()
	resp, err := interceptor(ctxWithBearer("good"), nil, &grpc.UnaryServerInfo{FullMethod: sendInvitation}, h)
	if err != nil {
		t.Fatalf("allowed caller should run: %v", err)
	}
	if !*ran || resp != "ok" {
		t.Fatalf("handler not reached")
	}
}

func TestOIDC_StrangerCallerDenied(t *testing.T) {
	interceptor := InternalOIDCInterceptor(notifAud, allowSet(), fakeValidatorOK(strangerSAEmail, true))
	h, ran := passHandler()
	_, err := interceptor(ctxWithBearer("good"), nil, &grpc.UnaryServerInfo{FullMethod: sendInvitation}, h)
	if status.Code(err) != codes.PermissionDenied {
		t.Fatalf("want PermissionDenied, got %v", err)
	}
	if *ran {
		t.Error("handler must not run for a non-allowlisted SA")
	}
}

func TestOIDC_UnverifiedEmailDenied(t *testing.T) {
	interceptor := InternalOIDCInterceptor(notifAud, allowSet(), fakeValidatorOK(allowedSAEmail, false))
	h, ran := passHandler()
	_, err := interceptor(ctxWithBearer("good"), nil, &grpc.UnaryServerInfo{FullMethod: sendInvitation}, h)
	if status.Code(err) != codes.PermissionDenied {
		t.Fatalf("want PermissionDenied for email_verified=false, got %v", err)
	}
	if *ran {
		t.Error("handler must not run when email is unverified")
	}
}

func TestParseAllowedSAs(t *testing.T) {
	got := ParseAllowedSAs("  a@x.com , b@y.com ,, ")
	if len(got) != 2 {
		t.Fatalf("want 2 SAs, got %d (%v)", len(got), got)
	}
	if _, ok := got["a@x.com"]; !ok {
		t.Error("a@x.com missing (not trimmed)")
	}
	if _, ok := got["b@y.com"]; !ok {
		t.Error("b@y.com missing")
	}
	if len(ParseAllowedSAs("")) != 0 {
		t.Error("empty string should yield empty set")
	}
}

func TestSAAllowed_CaseInsensitive(t *testing.T) {
	set := map[string]struct{}{"Svc@Proj.iam.gserviceaccount.com": {}}
	if !saAllowed(set, "svc@proj.iam.gserviceaccount.com") {
		t.Error("SA match should be case-insensitive")
	}
	if saAllowed(set, "other@proj.iam.gserviceaccount.com") {
		t.Error("non-member must not match")
	}
}
