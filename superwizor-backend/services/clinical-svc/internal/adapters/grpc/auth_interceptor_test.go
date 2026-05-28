package grpc

import (
	"context"
	"errors"
	"testing"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Verify the pre-auth allowlist: HealthCheck and ListModalities run the
// handler without a token, every other method demands metadata + a valid
// Firebase JWT.
//
// The interceptor takes an identityv1.IdentityServiceClient — we pass nil
// here because allowlisted methods never reach the validate-token branch,
// and for the negative cases we trip the earlier "missing metadata" /
// "missing authorization" checks before any client call.

func TestAuthInterceptor_AllowlistRunsHandler(t *testing.T) {
	interceptor := UnaryAuthInterceptor(nil)

	called := false
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		called = true
		return "ok", nil
	}

	allowlisted := []string{
		"/clinical.v1.ClinicalService/HealthCheck",
		"/clinical.v1.ClinicalService/ListModalities",
	}
	for _, method := range allowlisted {
		called = false
		info := &grpc.UnaryServerInfo{FullMethod: method}
		resp, err := interceptor(context.Background(), nil, info, handler)
		if err != nil {
			t.Fatalf("%s: expected nil error, got %v", method, err)
		}
		if resp != "ok" {
			t.Fatalf("%s: handler return not propagated, got %v", method, resp)
		}
		if !called {
			t.Fatalf("%s: handler was not invoked", method)
		}
	}
}

func TestAuthInterceptor_NonAllowlistedRequiresMetadata(t *testing.T) {
	interceptor := UnaryAuthInterceptor(nil)

	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		t.Fatalf("handler should not run when auth fails")
		return nil, errors.New("unreachable")
	}

	info := &grpc.UnaryServerInfo{FullMethod: "/clinical.v1.ClinicalService/ListPatientFiles"}
	_, err := interceptor(context.Background(), nil, info, handler)
	if err == nil {
		t.Fatalf("expected Unauthenticated error, got nil")
	}
	if got := status.Code(err); got != codes.Unauthenticated {
		t.Fatalf("expected Unauthenticated, got %s", got)
	}
}
