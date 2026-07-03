package grpc

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
)

// ctxWithRoleOrg builds the ctx the auth interceptor would have produced for
// a caller with the given user_id / role / organization_id. Empty org is
// passed through as "" (interceptor sets an empty string when the token
// carries no org), mirroring production.
func ctxWithRoleOrg(userID, role, orgID string) context.Context {
	ctx := context.WithValue(context.Background(), UserIDKey, userID)
	ctx = context.WithValue(ctx, UserRoleKey, role)
	ctx = context.WithValue(ctx, OrganizationIDKey, orgID)
	return ctx
}

// TestRequireTherapistDataAccess is the regression guard for the IDOR / BOLA
// fix (docs/37 R4). It pins the object-level authorization matrix that gates
// every handler which loads clinical data by a request-supplied ID:
//
//	owner                       → allow
//	foreign therapist           → NotFound (no enumeration oracle)
//	ORG_ADMIN, same org         → allow (clinic oversight, docs/38)
//	ORG_ADMIN, different org    → NotFound
//	ORG_ADMIN, caller has no org→ NotFound
//	SUPERWIZOR_ADMIN            → allow (platform staff)
//	missing caller identity     → Unauthenticated
func TestRequireTherapistDataAccess(t *testing.T) {
	owner := uuid.New()
	orgA := uuid.New()
	orgB := uuid.New()

	// orgOf returns a Querier whose GetUserOrganizationID reports `org` for the
	// owner (or NULL when org is uuid.Nil). Set wantOrgLookup=false to assert
	// the org lookup is never reached (owner / SUPERWIZOR_ADMIN short-circuit).
	orgOf := func(t *testing.T, org uuid.UUID, wantLookup bool) *fakeQuerier {
		t.Helper()
		called := false
		t.Cleanup(func() {
			if called != wantLookup {
				t.Errorf("GetUserOrganizationID called=%v, want %v", called, wantLookup)
			}
		})
		return &fakeQuerier{
			getUserOrganizationIDFn: func(_ context.Context, id uuid.UUID) (pgtype.UUID, error) {
				called = true
				if id != owner {
					t.Errorf("org lookup for %s, want owner %s", id, owner)
				}
				if org == uuid.Nil {
					return pgtype.UUID{Valid: false}, nil
				}
				return pgtype.UUID{Bytes: org, Valid: true}, nil
			},
		}
	}

	tests := []struct {
		name     string
		ctx      context.Context
		querier  func(t *testing.T) *fakeQuerier
		wantCode codes.Code
	}{
		{
			name:     "owner is allowed",
			ctx:      ctxWithRoleOrg(owner.String(), "THERAPIST", ""),
			querier:  func(t *testing.T) *fakeQuerier { return orgOf(t, orgA, false) },
			wantCode: codes.OK,
		},
		{
			name:     "foreign therapist is NotFound",
			ctx:      ctxWithRoleOrg(uuid.NewString(), "THERAPIST", ""),
			querier:  func(t *testing.T) *fakeQuerier { return orgOf(t, orgA, false) },
			wantCode: codes.NotFound,
		},
		{
			name:     "ORG_ADMIN of same org is allowed",
			ctx:      ctxWithRoleOrg(uuid.NewString(), "ORG_ADMIN", orgA.String()),
			querier:  func(t *testing.T) *fakeQuerier { return orgOf(t, orgA, true) },
			wantCode: codes.OK,
		},
		{
			name:     "ORG_ADMIN of different org is NotFound",
			ctx:      ctxWithRoleOrg(uuid.NewString(), "ORG_ADMIN", orgB.String()),
			querier:  func(t *testing.T) *fakeQuerier { return orgOf(t, orgA, true) },
			wantCode: codes.NotFound,
		},
		{
			name:     "ORG_ADMIN with no org on token is NotFound",
			ctx:      ctxWithRoleOrg(uuid.NewString(), "ORG_ADMIN", ""),
			querier:  func(t *testing.T) *fakeQuerier { return orgOf(t, orgA, false) },
			wantCode: codes.NotFound,
		},
		{
			name:     "ORG_ADMIN when owner has no org is NotFound",
			ctx:      ctxWithRoleOrg(uuid.NewString(), "ORG_ADMIN", orgA.String()),
			querier:  func(t *testing.T) *fakeQuerier { return orgOf(t, uuid.Nil, true) },
			wantCode: codes.NotFound,
		},
		{
			name:     "SUPERWIZOR_ADMIN is allowed",
			ctx:      ctxWithRoleOrg(uuid.NewString(), "SUPERWIZOR_ADMIN", ""),
			querier:  func(t *testing.T) *fakeQuerier { return orgOf(t, orgA, false) },
			wantCode: codes.OK,
		},
		{
			name:     "missing caller identity is Unauthenticated",
			ctx:      context.Background(),
			querier:  func(t *testing.T) *fakeQuerier { return orgOf(t, orgA, false) },
			wantCode: codes.Unauthenticated,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			s := &Server{queries: tc.querier(t)}
			err := s.requireTherapistDataAccess(tc.ctx, owner)
			if got := codeOf(err); got != tc.wantCode {
				t.Fatalf("requireTherapistDataAccess code = %v, want %v (err=%v)", got, tc.wantCode, err)
			}
		})
	}
}

// TestRequireTherapistDataAccess_OrgLookupErrorDenies verifies that a failure
// to resolve the owner's organization is treated as a denial (NotFound), never
// a fail-open allow.
func TestRequireTherapistDataAccess_OrgLookupErrorDenies(t *testing.T) {
	owner := uuid.New()
	orgA := uuid.New()

	q := &fakeQuerier{
		getUserOrganizationIDFn: func(_ context.Context, _ uuid.UUID) (pgtype.UUID, error) {
			return pgtype.UUID{}, errors.New("db down")
		},
	}
	s := &Server{queries: q}

	ctx := ctxWithRoleOrg(uuid.NewString(), "ORG_ADMIN", orgA.String())
	if got := codeOf(s.requireTherapistDataAccess(ctx, owner)); got != codes.NotFound {
		t.Fatalf("org lookup error must deny with NotFound, got %v", got)
	}
}
