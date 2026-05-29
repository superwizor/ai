package grpc

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// GetMyOrganization returns the Organization that the caller belongs
// to. Permitted to:
//   - ORG_ADMIN (the canonical role for org management) — any org type
//   - THERAPIST whose org has type=SOLO — the SOLO model says the
//     therapist IS the org (one-person clinic), so self-service org
//     edits are allowed without ORG_ADMIN. This was opened up
//     2026-05-29 when the marketing-site /account page started
//     showing a SOLO therapist their own org data.
//   - SUPERWIZOR_ADMIN — should use AdminGetOrganization instead, but
//     allow it here too for symmetry; staff don't have a per-user
//     "my org" concept anyway.
func (s *Server) GetMyOrganization(ctx context.Context, _ *emptypb.Empty) (*identityv1.Organization, error) {
	caller, org, err := s.resolveMyOrgAccess(ctx)
	if err != nil {
		return nil, err
	}
	_ = caller
	var hq *db.Address
	if org.HeadquartersAddressID.Valid {
		a, err := s.queries.GetAddressByID(ctx, uuid.UUID(org.HeadquartersAddressID.Bytes))
		if err == nil {
			hq = &a
		}
	}
	return toProtoOrganization(org, hq, false), nil
}

// resolveMyOrgAccess is the shared gate for Get/UpdateMyOrganization.
// Loads the caller's org so the permission check can branch on its
// type. Returns the org so callers don't need a second DB roundtrip.
//
//   - role == ORG_ADMIN              → allow
//   - role == SUPERWIZOR_ADMIN       → allow (rare; mostly uses Admin*)
//   - role == THERAPIST && org.SOLO  → allow
//   - anything else                  → PermissionDenied
func (s *Server) resolveMyOrgAccess(ctx context.Context) (callerContext, db.Organization, error) {
	caller, err := s.resolveCaller(ctx)
	if err != nil {
		return callerContext{}, db.Organization{}, err
	}
	if caller.organizationID == nil {
		return callerContext{}, db.Organization{},
			status.Error(codes.FailedPrecondition, "caller has no organization")
	}
	org, err := s.queries.GetOrganizationByID(ctx, *caller.organizationID)
	if err != nil {
		return callerContext{}, db.Organization{},
			status.Errorf(codes.Internal, "load organization: %v", err)
	}
	switch caller.role {
	case db.UserRoleORGADMIN, db.UserRoleSUPERWIZORADMIN:
		return caller, org, nil
	case db.UserRoleTHERAPIST:
		if org.Type == "SOLO" {
			return caller, org, nil
		}
	}
	return callerContext{}, db.Organization{}, status.Errorf(codes.PermissionDenied,
		"role %s not authorised to manage organization of type %s", caller.role, org.Type)
}

// UpdateMyOrganization mutates the caller's own organization. Every
// field is selective — proto `optional` presence ⇔ intent to set.
// Address edits flow through upsertAddress (in-place update of the
// existing HQ row).
//
// Allowed roles: ORG_ADMIN (any org), THERAPIST (SOLO orgs only), and
// SUPERWIZOR_ADMIN. See resolveMyOrgAccess for the rationale; the
// SOLO-therapist case opens self-service org edits for the one-person
// clinic model used by the /account page on marketing-site.
//
// docs/18 §13.5.
func (s *Server) UpdateMyOrganization(ctx context.Context, req *identityv1.UpdateMyOrganizationRequest) (*identityv1.Organization, error) {
	caller, _, err := s.resolveMyOrgAccess(ctx)
	if err != nil {
		return nil, err
	}

	params := db.UpdateOrganizationParams{ID: *caller.organizationID}

	if req.LegalName != nil {
		params.LegalName = req.LegalName
	}
	if req.Type != nil {
		t := fromProtoOrgType(*req.Type)
		params.Type = &t
	}
	if req.TaxId != nil {
		params.TaxID = req.TaxId
	}
	if req.VatIdEu != nil {
		params.VatIDEu = req.VatIdEu
	}
	if req.PrimaryAdminUserId != nil {
		newAdminID, err := uuid.Parse(*req.PrimaryAdminUserId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid primary_admin_user_id")
		}
		// Scope check: the new primary admin must be a user in this
		// org with role ORG_ADMIN. Bailing out before the UPDATE
		// keeps the org_id consistent.
		target, err := s.queries.GetUserByID(ctx, newAdminID)
		if err != nil {
			return nil, status.Error(codes.NotFound, "new primary admin user not found")
		}
		if !target.OrganizationID.Valid || uuid.UUID(target.OrganizationID.Bytes) != *caller.organizationID {
			return nil, status.Error(codes.PermissionDenied,
				"new primary admin must be a user in your organization")
		}
		if target.Role != db.UserRoleORGADMIN {
			return nil, status.Error(codes.FailedPrecondition,
				"new primary admin must have role ORG_ADMIN")
		}
		params.PrimaryAdminUserID = pgtype.UUID{Bytes: newAdminID, Valid: true}
	}
	if req.HeadquartersAddress != nil {
		// Edit the existing HQ row in place if its id is on the
		// inbound proto; otherwise create a fresh address and
		// point the org at it.
		addrID, err := s.upsertAddress(ctx, req.HeadquartersAddress)
		if err != nil {
			return nil, err
		}
		params.HeadquartersAddressID = pgtype.UUID{Bytes: addrID, Valid: true}
	}

	org, err := s.queries.UpdateOrganization(ctx, params)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update organization: %v", err)
	}
	var hq *db.Address
	if org.HeadquartersAddressID.Valid {
		a, err := s.queries.GetAddressByID(ctx, uuid.UUID(org.HeadquartersAddressID.Bytes))
		if err == nil {
			hq = &a
		}
	}
	return toProtoOrganization(org, hq, false), nil
}
