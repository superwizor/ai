package grpc

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// GetMyProfile returns the authenticated caller's full User row.
//
// Used by both Flutter Web (cold-start hydration of currentUserProvider)
// and Next.js (admin login → fetch self → role gate). Pure read; any
// authenticated role can call.
func (s *Server) GetMyProfile(ctx context.Context, _ *emptypb.Empty) (*identityv1.User, error) {
	c, err := s.resolveCaller(ctx)
	if err != nil {
		return nil, err
	}
	user, err := s.queries.GetUserByID(ctx, c.userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "user not found")
		}
		return nil, status.Errorf(codes.Internal, "load profile: %v", err)
	}
	resp := toProtoUser(user)
	// organization_type (docs/38): the web dashboard hides self-serve
	// billing surfaces for members of managed B2B orgs. Best-effort —
	// a failed org lookup leaves it UNSPECIFIED rather than failing
	// the whole profile read.
	if user.OrganizationID.Valid {
		if org, oerr := s.queries.GetOrganizationByID(ctx, uuid.UUID(user.OrganizationID.Bytes)); oerr == nil {
			resp.OrganizationType = toProtoOrgType(org.Type)
		}
	}
	return resp, nil
}

// UpdateProfile rewrites the existing handler to honour the docs/18 D2
// contract: every field is selectively updated based on presence, not
// raw value.
//
//   - Legacy fields 2-7 (first_name, last_name, professional_title,
//     credentials_number, biography, phone_number) — iOS may send
//     empty strings for any column the user hasn't touched. We treat
//     "" as "don't change this column" by passing a nil pointer to
//     sqlc, which makes the COALESCE preserve the existing value.
//     The "you can't blank these fields by editing them" trade-off
//     is acceptable: clearing a field is a niche action; the more
//     common iOS bug is sending blanks for untouched fields.
//
//   - New web-only fields 8-13 (avatar_url, default_modality_id,
//     ui_language, timezone, billing_address, has_marketing_consent)
//     use proto `optional` wrappers. Their presence ⇔ "intent to set".
//
// AuthN: every authenticated user can edit their own profile; we
// derive user_id from the auth context rather than the request
// payload so a caller can't update someone else's row.
func (s *Server) UpdateProfile(ctx context.Context, req *identityv1.UpdateProfileRequest) (*identityv1.User, error) {
	c, err := s.resolveCaller(ctx)
	if err != nil {
		return nil, err
	}

	// The legacy proto has a user_id field. If it's set AND doesn't
	// match the caller, reject — the iOS client used to send it
	// redundantly and we want to catch any client that's trying to
	// edit another user's row.
	if req.UserId != "" {
		parsed, err := uuid.Parse(req.UserId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid user_id")
		}
		if parsed != c.userID {
			return nil, status.Error(codes.PermissionDenied, "cannot edit another user's profile")
		}
	}

	params := db.UpdateProfileParams{ID: c.userID}

	// Legacy fields — empty string = "don't change". The existing iOS
	// client sends the full form payload every save; empty strings on
	// fields the user never edited would otherwise blank the column.
	if v := req.FirstName; v != "" {
		params.FirstName = &v
	}
	if v := req.LastName; v != "" {
		params.LastName = &v
	}
	if v := req.ProfessionalTitle; v != "" {
		params.ProfessionalTitle = &v
	}
	if v := req.CredentialsNumber; v != "" {
		params.CredentialsNumber = &v
	}
	if v := req.Biography; v != "" {
		params.Biography = &v
	}
	if v := req.PhoneNumber; v != "" {
		params.PhoneNumber = &v
	}

	// New web fields — wire presence (proto `optional`) maps cleanly
	// to "intent to set". Empty string here IS meaningful (e.g.
	// avatar_url = "" means "clear my avatar").
	if req.AvatarUrl != nil {
		params.AvatarUrl = req.AvatarUrl
	}
	if req.DefaultModalityId != nil {
		modID, err := uuid.Parse(*req.DefaultModalityId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid default_modality_id")
		}
		params.DefaultModalityID = pgtype.UUID{Bytes: modID, Valid: true}
	}
	if req.UiLanguage != nil {
		params.UiLanguage = req.UiLanguage
	}
	if req.Timezone != nil {
		params.Timezone = req.Timezone
	}
	if req.HasMarketingConsent != nil {
		params.HasMarketingConsent = req.HasMarketingConsent
	}
	if req.BillingAddress != nil {
		// Either INSERT a fresh address (no id on the inbound proto)
		// or UPDATE the existing billing-address row. Field semantics
		// follow the same "missing field" rule as the proto.
		addrID, err := s.upsertAddress(ctx, req.BillingAddress)
		if err != nil {
			return nil, err
		}
		params.BillingAddressID = pgtype.UUID{Bytes: addrID, Valid: true}
	}

	user, err := s.queries.UpdateProfile(ctx, params)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "user not found")
		}
		return nil, status.Errorf(codes.Internal, "update profile: %v", err)
	}
	return toProtoUser(user), nil
}

// upsertAddress creates a new addresses row (if proto.id is empty) or
// updates an existing one in place. Used by UpdateProfile (billing
// address) and UpdateMyOrganization (HQ address).
//
// Idempotency: callers pass in the existing row's id when editing —
// repeat calls with the same payload yield a stable address_id.
func (s *Server) upsertAddress(ctx context.Context, addr *identityv1.Address) (uuid.UUID, error) {
	if addr == nil {
		return uuid.Nil, status.Error(codes.InvalidArgument, "address required")
	}
	if addr.Id == "" {
		// Create. Required fields per the table CHECK constraint:
		// country_code (2-char ISO), city, postal_code, street_line,
		// building_number.
		if len(addr.CountryCode) != 2 {
			return uuid.Nil, status.Error(codes.InvalidArgument, "country_code must be ISO alpha-2")
		}
		if addr.City == "" || addr.PostalCode == "" || addr.StreetLine == "" || addr.BuildingNumber == "" {
			return uuid.Nil, status.Error(codes.InvalidArgument, "address fields required: city, postal_code, street_line, building_number")
		}
		params := db.CreateAddressParams{
			CountryCode:    addr.CountryCode,
			City:           addr.City,
			PostalCode:     addr.PostalCode,
			StreetLine:     addr.StreetLine,
			BuildingNumber: addr.BuildingNumber,
		}
		if addr.Region != "" {
			params.Region = &addr.Region
		}
		if addr.UnitNumber != "" {
			params.UnitNumber = &addr.UnitNumber
		}
		if addr.Directions != "" {
			params.Directions = &addr.Directions
		}
		row, err := s.queries.CreateAddress(ctx, params)
		if err != nil {
			return uuid.Nil, status.Errorf(codes.Internal, "create address: %v", err)
		}
		return row.ID, nil
	}

	// Update existing row.
	addrID, err := uuid.Parse(addr.Id)
	if err != nil {
		return uuid.Nil, status.Error(codes.InvalidArgument, "invalid address id")
	}
	params := db.UpdateAddressParams{ID: addrID}
	if addr.CountryCode != "" {
		params.CountryCode = &addr.CountryCode
	}
	if addr.Region != "" {
		params.Region = &addr.Region
	}
	if addr.City != "" {
		params.City = &addr.City
	}
	if addr.PostalCode != "" {
		params.PostalCode = &addr.PostalCode
	}
	if addr.StreetLine != "" {
		params.StreetLine = &addr.StreetLine
	}
	if addr.BuildingNumber != "" {
		params.BuildingNumber = &addr.BuildingNumber
	}
	if addr.UnitNumber != "" {
		params.UnitNumber = &addr.UnitNumber
	}
	if addr.Directions != "" {
		params.Directions = &addr.Directions
	}
	row, err := s.queries.UpdateAddress(ctx, params)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return uuid.Nil, status.Error(codes.NotFound, "address not found")
		}
		return uuid.Nil, status.Errorf(codes.Internal, "update address: %v", err)
	}
	return row.ID, nil
}
