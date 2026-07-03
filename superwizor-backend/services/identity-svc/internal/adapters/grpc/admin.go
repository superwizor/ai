package grpc

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

const minAuditReasonChars = 10

// ─── Audit helper ──────────────────────────────────────────────

// writeAuditEvent records a SUPERWIZOR_ADMIN mutation. Required `reason`
// is validated upstream (>=10 chars). metadata holds before/after
// payloads as JSONB so the admin log can answer "what did X change?".
func (s *Server) writeAuditEvent(
	ctx context.Context,
	actor callerContext,
	action, resourceType string,
	resourceID *uuid.UUID,
	orgID *uuid.UUID,
	reason string,
	metadata map[string]any,
) error {
	if len(reason) < minAuditReasonChars {
		return status.Errorf(codes.InvalidArgument,
			"reason must be >= %d characters", minAuditReasonChars)
	}
	meta := []byte("{}")
	if metadata != nil {
		b, err := json.Marshal(metadata)
		if err == nil {
			meta = b
		}
	}
	params := db.CreateAuditEventParams{
		ActorUserID:  pgtype.UUID{Bytes: actor.userID, Valid: true},
		Action:       action,
		ResourceType: resourceType,
		Metadata:     meta,
		Reason:       &reason,
	}
	if orgID != nil {
		params.OrganizationID = pgtype.UUID{Bytes: *orgID, Valid: true}
	}
	if resourceID != nil {
		params.ResourceID = pgtype.UUID{Bytes: *resourceID, Valid: true}
	}
	_, err := s.queries.CreateAuditEvent(ctx, params)
	return err
}

// ─── Organisations ─────────────────────────────────────────────

func (s *Server) AdminListOrganizations(ctx context.Context, req *identityv1.AdminListOrganizationsRequest) (*identityv1.AdminListOrganizationsResponse, error) {
	if _, err := s.requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}
	pageSize := req.PageSize
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}

	params := db.ListOrganizationsParams{PageSize: pageSize}
	if req.Search != "" {
		s := req.Search
		params.SearchTerm = &s
	}
	if req.PageToken != "" {
		ts, id, err := parsePageToken(req.PageToken)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid page_token")
		}
		params.AfterCreatedAt = pgtype.Timestamptz{Time: ts, Valid: true}
		params.AfterID = pgtype.UUID{Bytes: id, Valid: true}
	}

	orgs, err := s.queries.ListOrganizations(ctx, params)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list organizations: %v", err)
	}

	out := &identityv1.AdminListOrganizationsResponse{
		Organizations: make([]*identityv1.OrganizationSummary, 0, len(orgs)),
	}
	for _, o := range orgs {
		// HQ + therapists count — best-effort, skip on error.
		var hq *db.Address
		if o.HeadquartersAddressID.Valid {
			a, err := s.queries.GetAddressByID(ctx, uuid.UUID(o.HeadquartersAddressID.Bytes))
			if err == nil {
				hq = &a
			}
		}
		count, _ := s.queries.CountTherapistsInOrg(ctx, pgtype.UUID{Bytes: o.ID, Valid: true})
		out.Organizations = append(out.Organizations, &identityv1.OrganizationSummary{
			Organization:    toProtoOrganization(o, hq, false),
			TherapistsCount: int32(count),
		})
	}
	if int32(len(orgs)) == pageSize && len(orgs) > 0 {
		last := orgs[len(orgs)-1]
		out.NextPageToken = formatPageToken(last.CreatedAt, last.ID)
	}
	return out, nil
}

func (s *Server) AdminGetOrganization(ctx context.Context, req *identityv1.AdminGetOrganizationRequest) (*identityv1.OrganizationDetails, error) {
	if _, err := s.requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}
	orgID, err := uuid.Parse(req.OrganizationId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid organization_id")
	}
	org, err := s.queries.GetOrganizationByID(ctx, orgID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "organization not found")
		}
		return nil, status.Errorf(codes.Internal, "load org: %v", err)
	}
	var hq *db.Address
	if org.HeadquartersAddressID.Valid {
		a, err := s.queries.GetAddressByID(ctx, uuid.UUID(org.HeadquartersAddressID.Bytes))
		if err == nil {
			hq = &a
		}
	}
	therapists, _ := s.queries.ListTherapistsByOrganization(ctx,
		pgtype.UUID{Bytes: orgID, Valid: true})
	managers, _ := s.queries.ListManagersByOrganization(ctx,
		pgtype.UUID{Bytes: orgID, Valid: true})
	auditRows, _ := s.queries.ListAuditEventsByOrg(ctx, db.ListAuditEventsByOrgParams{
		OrganizationID: pgtype.UUID{Bytes: orgID, Valid: true},
		Limit:          20,
	})

	out := &identityv1.OrganizationDetails{
		Organization: toProtoOrganization(org, hq, false),
		Therapists:   make([]*identityv1.User, 0, len(therapists)),
		RecentAudit:  make([]*identityv1.AuditEntry, 0, len(auditRows)),
	}
	for _, t := range therapists {
		out.Therapists = append(out.Therapists, toProtoUser(t))
	}
	for _, m := range managers {
		out.Managers = append(out.Managers, toProtoUser(m))
	}
	for _, a := range auditRows {
		entry := &identityv1.AuditEntry{
			Id:           a.ID.String(),
			OccurredAt:   timestamppb.New(a.OccurredAt),
			Action:       a.Action,
			ResourceType: a.ResourceType,
		}
		if a.Reason != nil {
			entry.Reason = *a.Reason
		}
		if a.ResourceID.Valid {
			entry.ResourceId = uuid.UUID(a.ResourceID.Bytes).String()
		}
		if a.ActorUserID.Valid {
			actor, err := s.queries.GetUserByID(ctx, uuid.UUID(a.ActorUserID.Bytes))
			if err == nil {
				entry.ActorEmail = derefString(actor.Email)
			}
		}
		out.RecentAudit = append(out.RecentAudit, entry)
	}
	return out, nil
}

func (s *Server) AdminSetOrganizationStatus(ctx context.Context, req *identityv1.AdminSetOrganizationStatusRequest) (*emptypb.Empty, error) {
	caller, err := s.requireSuperwizorAdmin(ctx)
	if err != nil {
		return nil, err
	}
	orgID, err := uuid.Parse(req.OrganizationId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid organization_id")
	}
	if len(req.Reason) < minAuditReasonChars {
		return nil, status.Errorf(codes.InvalidArgument,
			"reason must be >= %d characters", minAuditReasonChars)
	}
	var newStatus string
	switch strings.ToLower(req.DesiredStatus) {
	case "active":
		newStatus = "ACTIVE"
	case "blocked":
		newStatus = "PAST_DUE" // single-value block — billing's existing gate
	default:
		return nil, status.Error(codes.InvalidArgument,
			"desired_status must be 'active' or 'blocked'")
	}

	// Direct SQL on subscriptions — owned by billing-svc semantically
	// but co-resident in the same PG instance. Updates the ACTIVE
	// subscription row for this org.
	if _, err := s.pool.Exec(ctx,
		`UPDATE subscriptions
		    SET status = $2::subscription_status
		  WHERE organization_id = $1
		    AND status IN ('ACTIVE', 'TRIALING', 'PAST_DUE')`,
		orgID, newStatus,
	); err != nil {
		return nil, status.Errorf(codes.Internal, "update subscription status: %v", err)
	}

	if err := s.writeAuditEvent(ctx, caller,
		"organization.set_status", "organization",
		&orgID, &orgID, req.Reason,
		map[string]any{"desired_status": req.DesiredStatus, "applied_status": newStatus},
	); err != nil {
		return nil, status.Errorf(codes.Internal, "audit: %v", err)
	}
	return &emptypb.Empty{}, nil
}

func (s *Server) AdminUpdateOrganization(ctx context.Context, req *identityv1.AdminUpdateOrganizationRequest) (*identityv1.Organization, error) {
	caller, err := s.requireSuperwizorAdmin(ctx)
	if err != nil {
		return nil, err
	}
	orgID, err := uuid.Parse(req.OrganizationId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid organization_id")
	}
	if len(req.Reason) < minAuditReasonChars {
		return nil, status.Errorf(codes.InvalidArgument,
			"reason must be >= %d characters", minAuditReasonChars)
	}

	params := db.UpdateOrganizationParams{ID: orgID}
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
		uid, err := uuid.Parse(*req.PrimaryAdminUserId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid primary_admin_user_id")
		}
		params.PrimaryAdminUserID = pgtype.UUID{Bytes: uid, Valid: true}
	}
	if req.HeadquartersAddress != nil {
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
	if err := s.writeAuditEvent(ctx, caller,
		"organization.update", "organization",
		&orgID, &orgID, req.Reason,
		map[string]any{"fields_present": adminUpdateOrgFieldsPresent(req)},
	); err != nil {
		return nil, status.Errorf(codes.Internal, "audit: %v", err)
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

// ─── Users ─────────────────────────────────────────────────────

func (s *Server) AdminListUsers(ctx context.Context, req *identityv1.AdminListUsersRequest) (*identityv1.AdminListUsersResponse, error) {
	if _, err := s.requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}
	pageSize := req.PageSize
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}
	params := db.AdminListUsersParams{PageSize: pageSize}
	if req.OrganizationId != "" {
		orgID, err := uuid.Parse(req.OrganizationId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid organization_id")
		}
		params.OrganizationID = pgtype.UUID{Bytes: orgID, Valid: true}
	}
	if req.Role != identityv1.UserRole_USER_ROLE_UNSPECIFIED {
		if r, ok := fromProtoRole(req.Role); ok {
			params.RoleFilter = &r
		}
	}
	if req.Search != "" {
		s := req.Search
		params.SearchTerm = &s
	}
	if req.PageToken != "" {
		ts, id, err := parsePageToken(req.PageToken)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid page_token")
		}
		params.AfterCreatedAt = pgtype.Timestamptz{Time: ts, Valid: true}
		params.AfterID = pgtype.UUID{Bytes: id, Valid: true}
	}
	users, err := s.queries.AdminListUsers(ctx, params)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list users: %v", err)
	}
	out := &identityv1.AdminListUsersResponse{Users: make([]*identityv1.User, 0, len(users))}
	for _, u := range users {
		out.Users = append(out.Users, toProtoUser(u))
	}
	if int32(len(users)) == pageSize && len(users) > 0 {
		last := users[len(users)-1]
		out.NextPageToken = formatPageToken(last.CreatedAt, last.ID)
	}
	return out, nil
}

func (s *Server) AdminGetUser(ctx context.Context, req *identityv1.AdminGetUserRequest) (*identityv1.User, error) {
	if _, err := s.requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}
	uid, err := uuid.Parse(req.UserId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user_id")
	}
	u, err := s.queries.GetUserByID(ctx, uid)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "user not found")
		}
		return nil, status.Errorf(codes.Internal, "load user: %v", err)
	}
	return toProtoUser(u), nil
}

func (s *Server) AdminUpdateUser(ctx context.Context, req *identityv1.AdminUpdateUserRequest) (*identityv1.User, error) {
	caller, err := s.requireSuperwizorAdmin(ctx)
	if err != nil {
		return nil, err
	}
	if len(req.Reason) < minAuditReasonChars {
		return nil, status.Errorf(codes.InvalidArgument,
			"reason must be >= %d characters", minAuditReasonChars)
	}
	uid, err := uuid.Parse(req.UserId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user_id")
	}

	params := db.AdminUpdateUserParams{ID: uid}
	if req.Email != nil {
		params.Email = req.Email
	}
	if req.Role != nil {
		if r, ok := fromProtoRole(*req.Role); ok {
			params.Role = &r
		}
	}
	if req.OrganizationId != nil {
		orgID, err := uuid.Parse(*req.OrganizationId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid organization_id")
		}
		params.OrganizationID = pgtype.UUID{Bytes: orgID, Valid: true}
	}
	if req.IsEmailVerified != nil {
		params.IsEmailVerified = req.IsEmailVerified
	}
	if req.FirstName != nil {
		params.FirstName = req.FirstName
	}
	if req.LastName != nil {
		params.LastName = req.LastName
	}
	if req.PhoneNumber != nil {
		params.PhoneNumber = req.PhoneNumber
	}
	if req.ProfessionalTitle != nil {
		params.ProfessionalTitle = req.ProfessionalTitle
	}
	if req.CredentialsNumber != nil {
		params.CredentialsNumber = req.CredentialsNumber
	}
	if req.Biography != nil {
		params.Biography = req.Biography
	}
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
	if req.BillingAddress != nil {
		addrID, err := s.upsertAddress(ctx, req.BillingAddress)
		if err != nil {
			return nil, err
		}
		params.BillingAddressID = pgtype.UUID{Bytes: addrID, Valid: true}
	}

	u, err := s.queries.AdminUpdateUser(ctx, params)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "admin update user: %v", err)
	}
	var orgID *uuid.UUID
	if u.OrganizationID.Valid {
		o := uuid.UUID(u.OrganizationID.Bytes)
		orgID = &o
	}
	if err := s.writeAuditEvent(ctx, caller,
		"user.admin_update", "user",
		&uid, orgID, req.Reason,
		map[string]any{"fields_present": adminUpdateUserFieldsPresent(req)},
	); err != nil {
		return nil, status.Errorf(codes.Internal, "audit: %v", err)
	}
	return toProtoUser(u), nil
}

// ─── Global audit log ──────────────────────────────────────────

// AdminListAuditEvents returns the cross-org audit feed for the
// /admin/audit page (docs/18 §8.2). Cursor-paginated on (occurred_at,
// id) DESC; optional filters (actor_email ILIKE, action exact, since /
// until window) AND together. The underlying sqlc query LEFT JOINs
// users so the actor email comes back with the row — no N+1 lookup.
func (s *Server) AdminListAuditEvents(ctx context.Context, req *identityv1.AdminListAuditEventsRequest) (*identityv1.AdminListAuditEventsResponse, error) {
	if _, err := s.requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}
	pageSize := req.PageSize
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}

	params := db.AdminListAuditEventsParams{PageSize: pageSize}
	if req.ActorEmail != "" {
		s := req.ActorEmail
		params.ActorEmailSearch = &s
	}
	if req.Action != "" {
		a := req.Action
		params.ActionFilter = &a
	}
	if req.Since != nil {
		params.SinceTs = pgtype.Timestamptz{Time: req.Since.AsTime(), Valid: true}
	}
	if req.Until != nil {
		params.UntilTs = pgtype.Timestamptz{Time: req.Until.AsTime(), Valid: true}
	}
	if req.PageToken != "" {
		ts, id, err := parsePageToken(req.PageToken)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid page_token")
		}
		params.AfterOccurredAt = pgtype.Timestamptz{Time: ts, Valid: true}
		params.AfterID = pgtype.UUID{Bytes: id, Valid: true}
	}

	rows, err := s.queries.AdminListAuditEvents(ctx, params)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list audit events: %v", err)
	}

	out := &identityv1.AdminListAuditEventsResponse{
		Events: make([]*identityv1.AuditEntry, 0, len(rows)),
	}
	for _, r := range rows {
		entry := &identityv1.AuditEntry{
			Id:           r.ID.String(),
			OccurredAt:   timestamppb.New(r.OccurredAt),
			Action:       r.Action,
			ResourceType: r.ResourceType,
		}
		if r.ActorEmail != nil {
			entry.ActorEmail = *r.ActorEmail
		}
		if r.Reason != nil {
			entry.Reason = *r.Reason
		}
		if r.ResourceID.Valid {
			entry.ResourceId = uuid.UUID(r.ResourceID.Bytes).String()
		}
		out.Events = append(out.Events, entry)
	}
	if int32(len(rows)) == pageSize && len(rows) > 0 {
		last := rows[len(rows)-1]
		out.NextPageToken = formatPageToken(last.OccurredAt, last.ID)
	}
	return out, nil
}

func (s *Server) AdminDeleteUser(ctx context.Context, req *identityv1.AdminDeleteUserRequest) (*emptypb.Empty, error) {
	caller, err := s.requireSuperwizorAdmin(ctx)
	if err != nil {
		return nil, err
	}
	if len(req.Reason) < minAuditReasonChars {
		return nil, status.Errorf(codes.InvalidArgument,
			"reason must be >= %d characters", minAuditReasonChars)
	}
	uid, err := uuid.Parse(req.UserId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user_id")
	}
	target, err := s.queries.GetUserByID(ctx, uid)
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}
	if err := s.queries.SoftDeleteUser(ctx, uid); err != nil {
		return nil, status.Errorf(codes.Internal, "soft delete: %v", err)
	}
	var orgID *uuid.UUID
	if target.OrganizationID.Valid {
		o := uuid.UUID(target.OrganizationID.Bytes)
		orgID = &o
	}
	if err := s.writeAuditEvent(ctx, caller,
		"user.admin_delete", "user",
		&uid, orgID, req.Reason,
		map[string]any{"email": derefString(target.Email), "role": string(target.Role)},
	); err != nil {
		return nil, status.Errorf(codes.Internal, "audit: %v", err)
	}
	return &emptypb.Empty{}, nil
}

// ─── Helpers ───────────────────────────────────────────────────

// parsePageToken / formatPageToken use a simple "RFC3339|uuid" string
// format. Sufficient for the admin lists; if we ever surface them
// publicly we'd want to encrypt for opacity.
func parsePageToken(tok string) (time.Time, uuid.UUID, error) {
	parts := strings.SplitN(tok, "|", 2)
	if len(parts) != 2 {
		return time.Time{}, uuid.Nil, errors.New("bad token format")
	}
	ts, err := time.Parse(time.RFC3339Nano, parts[0])
	if err != nil {
		return time.Time{}, uuid.Nil, err
	}
	id, err := uuid.Parse(parts[1])
	if err != nil {
		return time.Time{}, uuid.Nil, err
	}
	return ts, id, nil
}

func formatPageToken(ts time.Time, id uuid.UUID) string {
	return ts.Format(time.RFC3339Nano) + "|" + id.String()
}

// adminUpdateOrgFieldsPresent emits a small JSON-friendly summary of
// which fields were on the inbound payload — gets serialised into
// audit_events.metadata so the log entry says "changed legal_name +
// tax_id" without us having to log the actual values.
func adminUpdateOrgFieldsPresent(req *identityv1.AdminUpdateOrganizationRequest) []string {
	var fields []string
	if req.LegalName != nil {
		fields = append(fields, "legal_name")
	}
	if req.Type != nil {
		fields = append(fields, "type")
	}
	if req.TaxId != nil {
		fields = append(fields, "tax_id")
	}
	if req.VatIdEu != nil {
		fields = append(fields, "vat_id_eu")
	}
	if req.PrimaryAdminUserId != nil {
		fields = append(fields, "primary_admin_user_id")
	}
	if req.HeadquartersAddress != nil {
		fields = append(fields, "headquarters_address")
	}
	return fields
}

func adminUpdateUserFieldsPresent(req *identityv1.AdminUpdateUserRequest) []string {
	var fields []string
	if req.Email != nil {
		fields = append(fields, "email")
	}
	if req.Role != nil {
		fields = append(fields, "role")
	}
	if req.OrganizationId != nil {
		fields = append(fields, "organization_id")
	}
	if req.IsEmailVerified != nil {
		fields = append(fields, "is_email_verified")
	}
	if req.FirstName != nil {
		fields = append(fields, "first_name")
	}
	if req.LastName != nil {
		fields = append(fields, "last_name")
	}
	if req.PhoneNumber != nil {
		fields = append(fields, "phone_number")
	}
	if req.ProfessionalTitle != nil {
		fields = append(fields, "professional_title")
	}
	if req.CredentialsNumber != nil {
		fields = append(fields, "credentials_number")
	}
	if req.Biography != nil {
		fields = append(fields, "biography")
	}
	if req.AvatarUrl != nil {
		fields = append(fields, "avatar_url")
	}
	if req.DefaultModalityId != nil {
		fields = append(fields, "default_modality_id")
	}
	if req.UiLanguage != nil {
		fields = append(fields, "ui_language")
	}
	if req.Timezone != nil {
		fields = append(fields, "timezone")
	}
	if req.BillingAddress != nil {
		fields = append(fields, "billing_address")
	}
	return fields
}
