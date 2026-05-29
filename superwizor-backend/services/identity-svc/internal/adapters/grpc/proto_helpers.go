package grpc

import (
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/protobuf/types/known/timestamppb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// toProtoAddress maps a db.Address row to its proto counterpart. The
// nullable text columns (region, unit_number, directions) collapse to
// empty string on the wire — clients treat empty as unset.
func toProtoAddress(a db.Address) *identityv1.Address {
	out := &identityv1.Address{
		Id:             a.ID.String(),
		CountryCode:    a.CountryCode,
		City:           a.City,
		PostalCode:     a.PostalCode,
		StreetLine:     a.StreetLine,
		BuildingNumber: a.BuildingNumber,
	}
	if a.Region != nil {
		out.Region = *a.Region
	}
	if a.UnitNumber != nil {
		out.UnitNumber = *a.UnitNumber
	}
	if a.Directions != nil {
		out.Directions = *a.Directions
	}
	return out
}

func toProtoOrganization(o db.Organization, hq *db.Address, isBlocked bool) *identityv1.Organization {
	out := &identityv1.Organization{
		Id:        o.ID.String(),
		LegalName: o.LegalName,
		Type:      toProtoOrgType(o.Type),
		CreatedAt: timestamppb.New(o.CreatedAt),
		IsBlocked: isBlocked,
	}
	if o.TaxID != nil {
		out.TaxId = *o.TaxID
	}
	if o.VatIDEu != nil {
		out.VatIdEu = *o.VatIDEu
	}
	if o.PrimaryAdminUserID.Valid {
		out.PrimaryAdminUserId = uuid.UUID(o.PrimaryAdminUserID.Bytes).String()
	}
	if hq != nil {
		out.HeadquartersAddress = toProtoAddress(*hq)
	}
	return out
}

func toProtoOrgType(t db.OrganizationType) identityv1.OrganizationType {
	switch t {
	case "SOLO":
		return identityv1.OrganizationType_ORGANIZATION_TYPE_SOLO
	case "CLINIC":
		return identityv1.OrganizationType_ORGANIZATION_TYPE_CLINIC
	case "ENTERPRISE":
		return identityv1.OrganizationType_ORGANIZATION_TYPE_ENTERPRISE
	}
	return identityv1.OrganizationType_ORGANIZATION_TYPE_UNSPECIFIED
}

func fromProtoOrgType(t identityv1.OrganizationType) db.OrganizationType {
	switch t {
	case identityv1.OrganizationType_ORGANIZATION_TYPE_CLINIC:
		return "CLINIC"
	case identityv1.OrganizationType_ORGANIZATION_TYPE_ENTERPRISE:
		return "ENTERPRISE"
	}
	// SOLO is the default — a missing/UNSPECIFIED org type at create-time
	// goes to SOLO since that's the most-restrictive (most-aligned with
	// individual signup).
	return "SOLO"
}

// fromProtoRole maps the proto enum to the db enum. Used by AdminUpdateUser
// when promoting / demoting role.
func fromProtoRole(r identityv1.UserRole) (db.UserRole, bool) {
	switch r {
	case identityv1.UserRole_USER_ROLE_THERAPIST:
		return "THERAPIST", true
	case identityv1.UserRole_USER_ROLE_PATIENT:
		return "PATIENT", true
	case identityv1.UserRole_USER_ROLE_ORG_ADMIN:
		return db.UserRoleORGADMIN, true
	case identityv1.UserRole_USER_ROLE_SUPERWIZOR_ADMIN:
		return db.UserRoleSUPERWIZORADMIN, true
	}
	return "", false
}

func toProtoInvitation(inv db.Invitation) *identityv1.Invitation {
	out := &identityv1.Invitation{
		Id:             inv.ID.String(),
		OrganizationId: inv.OrganizationID.String(),
		InvitedByUser:  inv.InvitedByUser.String(),
		Email:          inv.Email,
		ExpiresAt:      timestamppb.New(inv.ExpiresAt),
		CreatedAt:      timestamppb.New(inv.CreatedAt),
	}
	if inv.AcceptedAt.Valid {
		out.AcceptedAt = timestamppb.New(inv.AcceptedAt.Time)
	}
	return out
}

// pgUUIDFromString is the inverse of uuid.UUID(pgtype.UUID{}.Bytes).
func pgUUIDFromString(s string) (pgtype.UUID, error) {
	u, err := uuid.Parse(s)
	if err != nil {
		return pgtype.UUID{}, err
	}
	return pgtype.UUID{Bytes: u, Valid: true}, nil
}
