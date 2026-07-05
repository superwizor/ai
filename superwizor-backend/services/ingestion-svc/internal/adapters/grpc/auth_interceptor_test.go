package grpc

import (
	"context"
	"errors"
	"testing"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

// fakeValidator is a stand-in for identity-svc's ValidateToken.
type fakeValidator struct {
	res    *identityv1.UserContext
	err    error
	gotTok string
	calls  int
}

func (f *fakeValidator) ValidateToken(_ context.Context, in *identityv1.ValidateTokenRequest, _ ...grpc.CallOption) (*identityv1.UserContext, error) {
	f.calls++
	f.gotTok = in.FirebaseIdToken
	return f.res, f.err
}

func ctxWithAuth(v string) context.Context {
	md := metadata.New(map[string]string{"authorization": v})
	return metadata.NewIncomingContext(context.Background(), md)
}

const uploadMethod = "/ingestion.v1.IngestionService/CreateAudioUpload"

func TestUnaryAuth_ValidTokenPopulatesContext(t *testing.T) {
	fv := &fakeValidator{res: &identityv1.UserContext{
		UserId:         "therapist-42",
		Role:           identityv1.UserRole_USER_ROLE_THERAPIST,
		OrganizationId: "org-9",
	}}
	interceptor := UnaryAuthInterceptor(fv)

	var seen struct {
		uid, role, org string
	}
	handler := func(ctx context.Context, _ interface{}) (interface{}, error) {
		seen.uid, _ = ctx.Value(UserIDKey).(string)
		seen.role, _ = ctx.Value(UserRoleKey).(string)
		seen.org, _ = ctx.Value(OrganizationIDKey).(string)
		return "ok", nil
	}

	resp, err := interceptor(ctxWithAuth("Bearer good.token"),
		nil, &grpc.UnaryServerInfo{FullMethod: uploadMethod}, handler)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp != "ok" {
		t.Fatalf("handler not reached, resp=%v", resp)
	}
	if fv.gotTok != "good.token" {
		t.Errorf("Bearer prefix not stripped: got %q", fv.gotTok)
	}
	if seen.uid != "therapist-42" || seen.role != "THERAPIST" || seen.org != "org-9" {
		t.Errorf("ctx not populated: %+v", seen)
	}
}

func TestUnaryAuth_MissingMetadata(t *testing.T) {
	fv := &fakeValidator{}
	interceptor := UnaryAuthInterceptor(fv)

	_, err := interceptor(context.Background(),
		nil, &grpc.UnaryServerInfo{FullMethod: uploadMethod},
		func(context.Context, interface{}) (interface{}, error) { return "ok", nil })

	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", err)
	}
	if fv.calls != 0 {
		t.Errorf("validator should not be called without metadata")
	}
}

func TestUnaryAuth_MissingAuthorizationHeader(t *testing.T) {
	fv := &fakeValidator{}
	interceptor := UnaryAuthInterceptor(fv)

	ctx := metadata.NewIncomingContext(context.Background(), metadata.New(nil))
	_, err := interceptor(ctx, nil, &grpc.UnaryServerInfo{FullMethod: uploadMethod},
		func(context.Context, interface{}) (interface{}, error) { return "ok", nil })

	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", err)
	}
	if fv.calls != 0 {
		t.Errorf("validator should not be called without a token")
	}
}

func TestUnaryAuth_InvalidTokenRejected(t *testing.T) {
	fv := &fakeValidator{err: errors.New("token expired")}
	interceptor := UnaryAuthInterceptor(fv)

	called := false
	_, err := interceptor(ctxWithAuth("Bearer bad.token"),
		nil, &grpc.UnaryServerInfo{FullMethod: uploadMethod},
		func(context.Context, interface{}) (interface{}, error) { called = true; return "ok", nil })

	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("want Unauthenticated, got %v", err)
	}
	if called {
		t.Error("handler must not run when the token is invalid")
	}
}

func TestUnaryAuth_HealthCheckIsAnonymous(t *testing.T) {
	fv := &fakeValidator{err: errors.New("should not be called")}
	interceptor := UnaryAuthInterceptor(fv)

	called := false
	// No metadata at all — the health probe still passes through.
	resp, err := interceptor(context.Background(), nil,
		&grpc.UnaryServerInfo{FullMethod: "/grpc.health.v1.Health/Check"},
		func(context.Context, interface{}) (interface{}, error) { called = true; return "SERVING", nil })

	if err != nil {
		t.Fatalf("health check should not be gated: %v", err)
	}
	if !called || resp != "SERVING" {
		t.Fatalf("health handler not reached")
	}
	if fv.calls != 0 {
		t.Errorf("validator must not run for anonymous methods")
	}
}

func TestProtoRoleName(t *testing.T) {
	cases := map[identityv1.UserRole]string{
		identityv1.UserRole_USER_ROLE_THERAPIST:        "THERAPIST",
		identityv1.UserRole_USER_ROLE_PATIENT:          "PATIENT",
		identityv1.UserRole_USER_ROLE_ORG_ADMIN:        "ORG_ADMIN",
		identityv1.UserRole_USER_ROLE_SUPERWIZOR_ADMIN: "SUPERWIZOR_ADMIN",
		identityv1.UserRole_USER_ROLE_UNSPECIFIED:      "",
	}
	for in, want := range cases {
		if got := protoRoleName(in); got != want {
			t.Errorf("protoRoleName(%v) = %q, want %q", in, got, want)
		}
	}
}

func TestUserIDFromContext(t *testing.T) {
	if got := userIDFromContext(context.Background()); got != "" {
		t.Errorf("empty ctx should yield \"\", got %q", got)
	}
	ctx := context.WithValue(context.Background(), UserIDKey, "u-1")
	if got := userIDFromContext(ctx); got != "u-1" {
		t.Errorf("got %q, want u-1", got)
	}
}
