package http

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"google.golang.org/grpc"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

// fakeIdentity embeds the client interface as nil — only ValidateToken
// is implemented; any other call panics loudly (same pattern as
// clinical-svc's testdoubles).
type fakeIdentity struct {
	identityv1.IdentityServiceClient
	validateFn func(ctx context.Context, in *identityv1.ValidateTokenRequest, opts ...grpc.CallOption) (*identityv1.UserContext, error)
}

func (f *fakeIdentity) ValidateToken(ctx context.Context, in *identityv1.ValidateTokenRequest, opts ...grpc.CallOption) (*identityv1.UserContext, error) {
	return f.validateFn(ctx, in, opts...)
}

func runAuthed(t *testing.T, identity identityv1.IdentityServiceClient, authHeader string) (*httptest.ResponseRecorder, bool) {
	t.Helper()
	mw := NewAdminAuthMiddleware(identity, slog.Default())
	handlerRan := false
	h := mw.Require(func(w http.ResponseWriter, r *http.Request) {
		handlerRan = true
		w.WriteHeader(http.StatusOK)
	})
	req := httptest.NewRequest(http.MethodGet, "/admin/crm/follow-ups", nil)
	if authHeader != "" {
		req.Header.Set("Authorization", authHeader)
	}
	rec := httptest.NewRecorder()
	h(rec, req)
	return rec, handlerRan
}

func TestAdminAuth_FailClosedWithoutIdentity(t *testing.T) {
	rec, ran := runAuthed(t, nil, "Bearer whatever")
	if rec.Code != http.StatusServiceUnavailable || ran {
		t.Errorf("nil identity must 503 and never run the handler; got %d ran=%v", rec.Code, ran)
	}
}

func TestAdminAuth_MissingToken(t *testing.T) {
	id := &fakeIdentity{validateFn: func(ctx context.Context, in *identityv1.ValidateTokenRequest, _ ...grpc.CallOption) (*identityv1.UserContext, error) {
		t.Fatal("ValidateToken must not be called without a bearer token")
		return nil, nil
	}}
	rec, ran := runAuthed(t, id, "")
	if rec.Code != http.StatusUnauthorized || ran {
		t.Errorf("missing token: want 401, got %d ran=%v", rec.Code, ran)
	}
}

func TestAdminAuth_InvalidToken(t *testing.T) {
	id := &fakeIdentity{validateFn: func(ctx context.Context, in *identityv1.ValidateTokenRequest, _ ...grpc.CallOption) (*identityv1.UserContext, error) {
		return nil, errors.New("bad token")
	}}
	rec, ran := runAuthed(t, id, "Bearer nope")
	if rec.Code != http.StatusUnauthorized || ran {
		t.Errorf("invalid token: want 401, got %d ran=%v", rec.Code, ran)
	}
}

func TestAdminAuth_NonAdminRole(t *testing.T) {
	id := &fakeIdentity{validateFn: func(ctx context.Context, in *identityv1.ValidateTokenRequest, _ ...grpc.CallOption) (*identityv1.UserContext, error) {
		return &identityv1.UserContext{Role: identityv1.UserRole_USER_ROLE_THERAPIST}, nil
	}}
	rec, ran := runAuthed(t, id, "Bearer therapist-token")
	if rec.Code != http.StatusForbidden || ran {
		t.Errorf("therapist role: want 403, got %d ran=%v", rec.Code, ran)
	}
}

func TestAdminAuth_AdminPasses(t *testing.T) {
	id := &fakeIdentity{validateFn: func(ctx context.Context, in *identityv1.ValidateTokenRequest, _ ...grpc.CallOption) (*identityv1.UserContext, error) {
		if in.FirebaseIdToken != "admin-token" {
			t.Errorf("token not forwarded: %q", in.FirebaseIdToken)
		}
		return &identityv1.UserContext{Role: identityv1.UserRole_USER_ROLE_SUPERWIZOR_ADMIN}, nil
	}}
	rec, ran := runAuthed(t, id, "Bearer admin-token")
	if rec.Code != http.StatusOK || !ran {
		t.Errorf("admin: want 200 + handler run, got %d ran=%v", rec.Code, ran)
	}
}
