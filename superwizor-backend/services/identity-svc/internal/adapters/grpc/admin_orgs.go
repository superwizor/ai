package grpc

import (
	"context"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// AdminCreateOrganization is the SUPERWIZOR_ADMIN provisioning path
// (docs/38 §4-5): one PG tx creates the organization + headquarters
// address + an ORG_ADMIN magic-link invitation per manager e-mail.
// Unlike self-serve RegisterOrganization there is no founder user —
// managers join via the standard AcceptInvitation flow (which honours
// invitations.invited_role).
//
// Seat allocations + the subscription start date are set separately by
// billing.AdminSetSeatAllocations; the /admin/orgs/new wizard calls
// both back-to-back.
//
// Idempotency: when tax_id is provided and an organization with the
// same tax_id + legal_name already exists, the call is treated as a
// replay — the existing org and its pending ORG_ADMIN invitations are
// returned, no duplicates created.
func (s *Server) AdminCreateOrganization(ctx context.Context, req *identityv1.AdminCreateOrganizationRequest) (*identityv1.AdminCreateOrganizationResponse, error) {
	caller, err := s.requireSuperwizorAdmin(ctx)
	if err != nil {
		return nil, err
	}
	if len(req.Reason) < minAuditReasonChars {
		return nil, status.Errorf(codes.InvalidArgument,
			"reason must be >= %d characters", minAuditReasonChars)
	}
	if strings.TrimSpace(req.LegalName) == "" {
		return nil, status.Error(codes.InvalidArgument, "legal_name required")
	}
	managerEmails, err := normalizeManagerEmails(req.ManagerEmails)
	if err != nil {
		return nil, err
	}
	addrParams, err := buildCreateAddressParams(req.Headquarters)
	if err != nil {
		return nil, err
	}

	// Idempotency replay on tax_id (the admin wizard retries on network
	// blips; tax_id is the natural business key for a Polish clinic).
	if req.TaxId != "" {
		if existing, err := s.findOrgByTaxID(ctx, req.TaxId); err == nil {
			if existing.LegalName != req.LegalName {
				return nil, status.Errorf(codes.AlreadyExists,
					"an organization with tax_id %s already exists under a different name", req.TaxId)
			}
			return s.assembleAdminCreateReplay(ctx, existing)
		}
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := db.New(tx)

	addr, err := qtx.CreateAddress(ctx, addrParams)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "create address: %v", err)
	}

	orgParams := db.CreateOrganizationParams{
		LegalName:             req.LegalName,
		Type:                  fromProtoOrgType(req.Type),
		HeadquartersAddressID: pgtype.UUID{Bytes: addr.ID, Valid: true},
	}
	if req.TaxId != "" {
		orgParams.TaxID = &req.TaxId
	}
	if req.VatIdEu != "" {
		orgParams.VatIDEu = &req.VatIdEu
	}
	org, err := qtx.CreateOrganization(ctx, orgParams)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "create organization: %v", err)
	}

	// One ORG_ADMIN invitation per manager e-mail. Cleartext tokens are
	// collected for the post-commit email sends — they never touch PG.
	type mintedInvite struct {
		inv   db.Invitation
		token string
	}
	minted := make([]mintedInvite, 0, len(managerEmails))
	expiresAt := time.Now().Add(invitationTTL)
	for _, email := range managerEmails {
		token, tokenHash, err := generateInvitationToken()
		if err != nil {
			return nil, status.Errorf(codes.Internal, "generate token: %v", err)
		}
		inv, err := qtx.CreateInvitation(ctx, db.CreateInvitationParams{
			OrganizationID: org.ID,
			InvitedByUser:  caller.userID,
			Email:          email,
			TokenHash:      tokenHash,
			ExpiresAt:      expiresAt,
			InvitedRole:    db.UserRoleORGADMIN,
			// no allocation — managers don't occupy seats
		})
		if err != nil {
			return nil, status.Errorf(codes.Internal, "create manager invitation for %s: %v", email, err)
		}
		minted = append(minted, mintedInvite{inv: inv, token: token})
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	// Audit + e-mails happen post-commit: the org exists either way, and
	// a failed email send must not roll back provisioning (the admin can
	// resend from the org detail page).
	orgID := org.ID
	if err := s.writeAuditEvent(ctx, caller,
		"ADMIN_CREATE_ORGANIZATION", "organization", &orgID, &orgID,
		req.Reason, map[string]any{
			"legal_name":     org.LegalName,
			"manager_emails": managerEmails,
		}); err != nil {
		return nil, status.Errorf(codes.Internal, "audit: %v", err)
	}

	resp := &identityv1.AdminCreateOrganizationResponse{
		Organization:       toProtoOrganization(org, &addr, false),
		ManagerInvitations: make([]*identityv1.Invitation, 0, len(minted)),
	}
	for _, m := range minted {
		acceptURL := fmt.Sprintf("%s/accept-invite?token=%s",
			strings.TrimRight(s.acceptURLBase, "/"),
			url.QueryEscape(m.token),
		)
		_ = s.emailer.SendInvitation(ctx, InvitationEmailParams{
			Recipient:   m.inv.Email,
			OrgName:     org.LegalName,
			AcceptURL:   acceptURL,
			ExpiresAt:   expiresAt.Format(time.RFC3339),
			Locale:      "pl",
			InvitedRole: "ORG_ADMIN",
		})
		resp.ManagerInvitations = append(resp.ManagerInvitations, toProtoInvitation(m.inv))
	}
	return resp, nil
}

// normalizeManagerEmails lowercases, trims, dedups and validates the
// manager e-mail list. At least one address required.
func normalizeManagerEmails(in []string) ([]string, error) {
	seen := make(map[string]bool, len(in))
	out := make([]string, 0, len(in))
	for _, e := range in {
		email := strings.ToLower(strings.TrimSpace(e))
		if email == "" || seen[email] {
			continue
		}
		if !strings.Contains(email, "@") {
			return nil, status.Errorf(codes.InvalidArgument, "invalid manager e-mail %q", e)
		}
		seen[email] = true
		out = append(out, email)
	}
	if len(out) == 0 {
		return nil, status.Error(codes.InvalidArgument, "at least one manager_email required")
	}
	return out, nil
}

// findOrgByTaxID resolves an organization by tax_id for the idempotency
// replay. Raw SQL — no sqlc query exists for this lookup and it's a
// single indexed read (idx_organizations_tax_id). Column order matches
// db.Organization field order.
func (s *Server) findOrgByTaxID(ctx context.Context, taxID string) (db.Organization, error) {
	row := s.pool.QueryRow(ctx,
		`SELECT id, legal_name, tax_id, vat_id_eu,
		        headquarters_address_id, primary_admin_user_id,
		        type, created_at, deleted_at
		   FROM organizations
		  WHERE tax_id = $1 AND deleted_at IS NULL
		  LIMIT 1`, taxID)
	var o db.Organization
	err := row.Scan(&o.ID, &o.LegalName, &o.TaxID, &o.VatIDEu,
		&o.HeadquartersAddressID, &o.PrimaryAdminUserID,
		&o.Type, &o.CreatedAt, &o.DeletedAt)
	return o, err
}

// assembleAdminCreateReplay returns the response for an idempotent
// replay: the existing org + its still-pending ORG_ADMIN invitations.
func (s *Server) assembleAdminCreateReplay(ctx context.Context, org db.Organization) (*identityv1.AdminCreateOrganizationResponse, error) {
	var hq *db.Address
	if org.HeadquartersAddressID.Valid {
		a, err := s.queries.GetAddressByID(ctx, uuid.UUID(org.HeadquartersAddressID.Bytes))
		if err == nil {
			hq = &a
		}
	}
	resp := &identityv1.AdminCreateOrganizationResponse{
		Organization: toProtoOrganization(org, hq, false),
	}
	pending, err := s.queries.ListPendingInvitationsByOrg(ctx, org.ID)
	if err == nil {
		for _, inv := range pending {
			if inv.InvitedRole == db.UserRoleORGADMIN {
				resp.ManagerInvitations = append(resp.ManagerInvitations, toProtoInvitation(inv))
			}
		}
	}
	return resp, nil
}
