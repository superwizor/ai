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

// GetMyOrganization returns the Organization that the caller is the
// admin of. Org-admin only — therapists don't see this view.
func (s *Server) GetMyOrganization(ctx context.Context, _ *emptypb.Empty) (*identityv1.Organization, error) {
	caller, err := s.requireOrgAdmin(ctx)
	if err != nil {
		return nil, err
	}
	if caller.organizationID == nil {
		return nil, status.Error(codes.FailedPrecondition, "caller has no organization")
	}
	org, err := s.queries.GetOrganizationByID(ctx, *caller.organizationID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load organization: %v", err)
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

// UpdateMyOrganization mutates the caller's own organization. Org-admin
// only. Every field is selective — proto `optional` presence ⇔ intent
// to set. Address edits flow through upsertAddress (in-place update
// of the existing HQ row).
//
// docs/18 §13.5.
func (s *Server) UpdateMyOrganization(ctx context.Context, req *identityv1.UpdateMyOrganizationRequest) (*identityv1.Organization, error) {
	caller, err := s.requireOrgAdmin(ctx)
	if err != nil {
		return nil, err
	}
	if caller.organizationID == nil {
		return nil, status.Error(codes.FailedPrecondition, "caller has no organization")
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
