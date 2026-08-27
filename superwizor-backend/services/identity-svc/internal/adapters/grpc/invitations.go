package grpc

import (
	"context"
	"crypto/subtle"
	"log/slog"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// invitationTTL = 7 days. Long enough for "I missed the email last
// Friday, re-checking on Monday" but short enough that abandoned
// invites don't pile up forever.
const invitationTTL = 7 * 24 * time.Hour

// InviteTherapist creates a magic-link invitation for an email address.
// Org-admin only. Sends the email via the configured InvitationEmailer
// (NoopEmailSender in 5b; ResendSender in commit 7).
//
// Idempotency: if a pending invitation already exists for (org_id,
// email), the existing row is returned with a fresh token + email
// re-sent. This lets the org-admin "Resend invite" button work
// without manual token plumbing.
func (s *Server) InviteTherapist(ctx context.Context, req *identityv1.InviteTherapistRequest) (*identityv1.Invitation, error) {
	caller, err := s.requireOrgAdmin(ctx)
	if err != nil {
		return nil, err
	}
	if caller.organizationID == nil {
		return nil, status.Error(codes.FailedPrecondition, "caller has no organization")
	}
	email := strings.ToLower(strings.TrimSpace(req.Email))
	if email == "" {
		return nil, status.Error(codes.InvalidArgument, "email required")
	}

	// Guard: the invited e-mail must not already own an account
	// (single-role/single-org MVP). Without this the manager sends an
	// invite the recipient can never accept — AcceptInvitation rejects
	// only AFTER a successful social login, which reads as "connected ✓"
	// followed by a contradictory error (live-feedback 2026-07-19).
	if code := s.staffInviteEmailConflict(ctx, email, *caller.organizationID); code != "" {
		return nil, status.Error(codes.FailedPrecondition, code)
	}

	// Optional seat pinning (docs/38 §3): when the org uses seat
	// allocations the invite names one, and the pending invitation
	// reserves a seat there. Orgs without allocations (self-serve,
	// legacy) keep the allocation-less flow.
	var allocationID pgtype.UUID
	if req.AllocationId != "" {
		aid, err := uuid.Parse(req.AllocationId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid allocation_id")
		}
		allocationID = pgtype.UUID{Bytes: aid, Valid: true}
	}

	// Generate the cleartext token + SHA-256 hash. Per docs/18 R5,
	// NOT Argon2 — high-entropy random tokens don't need slow KDFs
	// and Argon2 on the AcceptInvitation hot path would be a CPU
	// DoS vector.
	token, tokenHash, err := generateInvitationToken()
	if err != nil {
		return nil, status.Errorf(codes.Internal, "generate token: %v", err)
	}
	expiresAt := time.Now().Add(invitationTTL)

	createParams := db.CreateInvitationParams{
		OrganizationID: *caller.organizationID,
		InvitedByUser:  caller.userID,
		Email:          email,
		TokenHash:      tokenHash,
		ExpiresAt:      expiresAt,
		InvitedRole:    "THERAPIST",
		AllocationID:   allocationID,
	}
	if fn := strings.TrimSpace(req.FirstName); fn != "" {
		createParams.InvitedFirstName = &fn
	}
	if ln := strings.TrimSpace(req.LastName); ln != "" {
		createParams.InvitedLastName = &ln
	}

	var inv db.Invitation
	if allocationID.Valid {
		// Seat-pinned invite: the free-seat check and the INSERT must be
		// one atomic unit, or two concurrent invites could both grab the
		// last seat. FOR UPDATE on the allocation row serializes them.
		tx, err := s.pool.Begin(ctx)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "tx begin: %v", err)
		}
		defer func() { _ = tx.Rollback(ctx) }()
		qtx := db.New(tx)

		alloc, err := qtx.GetSeatAllocationForUpdate(ctx, uuid.UUID(allocationID.Bytes))
		if err != nil {
			return nil, status.Error(codes.NotFound, "seat allocation not found")
		}
		if alloc.OrganizationID != *caller.organizationID {
			return nil, status.Error(codes.NotFound, "seat allocation not found")
		}
		// Re-invite (live-feedback 2026-07-04): a PENDING invitation for
		// this e-mail refreshes in place — new token/expiry AND possibly
		// a NEW seat allocation (the manager can move the invitee to a
		// different plan before activation). The old row's reservation
		// dissolves with the same UPDATE, so exclude it from the
		// availability count.
		existing, lookupErr := qtx.GetInvitationByOrgEmail(ctx, db.GetInvitationByOrgEmailParams{
			OrganizationID: *caller.organizationID,
			Email:          email,
		})
		switch {
		case lookupErr == nil:
			if err := checkSeatAvailableExcluding(ctx, qtx, alloc, existing.ID); err != nil {
				return nil, err
			}
			// invited_role='THERAPIST' is REQUIRED: the (org,email)
			// pending row might be an ORG_ADMIN invitation (one non-PATIENT
			// invite per (org,email) since 000067). Stamping an allocation
			// onto an ORG_ADMIN row violates chk_invitations_allocation_by_role
			// (allocation ⇒ THERAPIST) — the live "Błąd serwera" on resend
			// (2026-07-04). Inviting-as-therapist converts the pending
			// invite to a therapist one, which is the intended effect.
			if _, err := tx.Exec(ctx,
				`UPDATE invitations
				    SET token_hash = $2, expires_at = $3, invited_by_user = $4,
				        invited_role = 'THERAPIST', allocation_id = $5,
				        invited_first_name = $6, invited_last_name = $7,
				        created_at = now()
				  WHERE id = $1`,
				existing.ID, tokenHash, expiresAt, caller.userID,
				allocationID, createParams.InvitedFirstName, createParams.InvitedLastName,
			); err != nil {
				return nil, status.Errorf(codes.Internal, "refresh invitation: %v", err)
			}
			inv = existing
			inv.TokenHash = tokenHash
			inv.ExpiresAt = expiresAt
			inv.AllocationID = allocationID
			inv.InvitedRole = "THERAPIST"
		case errors.Is(lookupErr, pgx.ErrNoRows):
			if err := checkSeatAvailable(ctx, qtx, alloc); err != nil {
				return nil, err
			}
			inv, err = qtx.CreateInvitation(ctx, createParams)
			if err != nil {
				return nil, status.Errorf(codes.Internal, "create invitation: %v", err)
			}
		default:
			return nil, status.Errorf(codes.Internal, "invitation lookup: %v", lookupErr)
		}
		if err := tx.Commit(ctx); err != nil {
			return nil, status.Errorf(codes.Internal, "commit: %v", err)
		}
	} else {
		// Try CREATE first; on (org_id, email) unique violation, fall
		// back to refreshing the existing pending row.
		inv, err = s.queries.CreateInvitation(ctx, createParams)
		if err != nil {
			// Refresh path: same email re-invited. Look up the existing
			// row and update its token+expiry inline. The original
			// allocation (if any) is kept — a refresh must not change
			// the seat math.
			existing, lookupErr := s.queries.GetInvitationByOrgEmail(ctx, db.GetInvitationByOrgEmailParams{
				OrganizationID: *caller.organizationID,
				Email:          email,
			})
			if lookupErr != nil {
				return nil, status.Errorf(codes.Internal, "create invitation: %v", err)
			}
			// Allocation-less therapist invite (org without seat
			// allocations). Convert any stale same-email row to THERAPIST
			// with no allocation — THERAPIST+NULL satisfies the CHECK
			// whether the prior role was ORG_ADMIN or THERAPIST.
			if _, err := s.pool.Exec(ctx,
				`UPDATE invitations
				    SET token_hash = $2, expires_at = $3, invited_by_user = $4,
				        invited_role = 'THERAPIST', allocation_id = NULL,
				        created_at = now()
				  WHERE id = $1`,
				existing.ID, tokenHash, expiresAt, caller.userID,
			); err != nil {
				return nil, status.Errorf(codes.Internal, "refresh invitation: %v", err)
			}
			inv = existing
			inv.TokenHash = tokenHash
			inv.ExpiresAt = expiresAt
			inv.InvitedRole = "THERAPIST"
			inv.AllocationID = pgtype.UUID{}
		}
	}

	// Look up the inviter's org name + first_name for the email template.
	// Best-effort — if these fail we still create the invite, the email
	// will just have less context.
	orgName := ""
	if org, err := s.queries.GetOrganizationByID(ctx, *caller.organizationID); err == nil {
		orgName = org.LegalName
	}
	inviterFirstName := ""
	if u, err := s.queries.GetUserByID(ctx, caller.userID); err == nil {
		inviterFirstName = u.FirstName
	}

	// Build the accept URL with the cleartext token. The token NEVER
	// touches PG in cleartext (only its SHA-256 hash) — it only
	// exists in the URL and the recipient's inbox.
	acceptURL := fmt.Sprintf("%s/accept-invite?token=%s",
		strings.TrimRight(s.acceptURLBase, "/"),
		url.QueryEscape(token),
	)

	// Best-effort email send. Locale = inviter's ui_language (we look
	// it up); falls back to "pl".
	locale := "pl"
	if u, err := s.queries.GetUserByID(ctx, caller.userID); err == nil && u.UiLanguage != "" {
		locale = u.UiLanguage
	}
	_ = s.emailer.SendInvitation(ctx, InvitationEmailParams{
		Recipient:        email,
		OrgName:          orgName,
		InviterFirstName: inviterFirstName,
		AcceptURL:        acceptURL,
		ExpiresAt:        expiresAt.Format(time.RFC3339),
		Locale:           locale,
	})

	return toProtoInvitation(inv), nil
}

// staffInviteEmailConflict pre-checks a therapist/manager invite
// against existing accounts (single-role/single-org MVP). Returns a
// stable error code ("" = no conflict):
//   - EMAIL_ALREADY_IN_ORG        — the e-mail belongs to a member of
//     the inviter's own organisation (the invite is pointless);
//   - EMAIL_ALREADY_REGISTERED    — the e-mail owns an account
//     elsewhere (any role, incl. PATIENT), so accepting would be
//     rejected at CreateUser anyway.
//
// Best-effort: a lookup error (other than no-rows) does NOT block the
// invite — AcceptInvitation's unique-violation path stays the backstop,
// same pattern as the CLIENT_EMAIL_TAKEN guard in client_invites.go.
// PENDING invitations are unaffected: their e-mail has no users row
// until acceptance, so "Zaproś ponownie" keeps working.
func (s *Server) staffInviteEmailConflict(ctx context.Context, email string, orgID uuid.UUID) string {
	existing, err := s.queries.GetUserByEmail(ctx, &email)
	if err != nil {
		return ""
	}
	if existing.OrganizationID.Valid && uuid.UUID(existing.OrganizationID.Bytes) == orgID {
		return "EMAIL_ALREADY_IN_ORG: this e-mail already belongs to a member of your organisation"
	}
	return "EMAIL_ALREADY_REGISTERED: this e-mail already has a Superwizor account — a staff invitation needs a different e-mail address"
}

// AcceptInvitation is the invitee-side endpoint. Public — the caller
// is authenticated to Firebase (just created the account via
// createUserWithEmailAndPassword or via social OAuth) but has no User
// row yet. The token in the URL proves they received the email.
//
// On success: a THERAPIST User row is created and attached to the
// inviting organisation; the invitation is marked accepted.
//
// Replay safety: a second call with the same token (after accepted_at
// is set) returns NotFound — the partial index excludes accepted rows.
// Client should treat NotFound as "already accepted, sign in
// normally".
func (s *Server) AcceptInvitation(ctx context.Context, req *identityv1.AcceptInvitationRequest) (*identityv1.AcceptInvitationResponse, error) {
	if req.Token == "" {
		return nil, status.Error(codes.InvalidArgument, "token required")
	}
	if req.FirebaseUid == "" {
		return nil, status.Error(codes.InvalidArgument, "firebase_uid required")
	}
	if !req.HasAcceptedTos {
		return nil, status.Error(codes.FailedPrecondition, "must accept ToS")
	}
	// Names are NOT validated here: the invited role is known only after
	// the token lookup, and PATIENT accepts are name-free (docs/43 §4 —
	// the client account is pseudonymous; the old blanket check 400'd
	// every client registration once the web form stopped collecting
	// names, 2026-07-18). Staff invites re-check below.

	verifiedUID, err := s.verifyFirebaseTokenFromContext(ctx)
	if err != nil {
		return nil, err
	}
	if verifiedUID != req.FirebaseUid {
		return nil, status.Error(codes.InvalidArgument,
			"firebase_uid in payload does not match the authenticated token")
	}

	// Hash the incoming token + look up the matching invitation row.
	// Partial index idx_invitations_token_hash gives us the fast path.
	tokenHash := hashToken(req.Token)
	inv, err := s.queries.GetUnacceptedInvitationByTokenHash(ctx, tokenHash)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound,
				"invitation not found, expired, or already accepted")
		}
		return nil, status.Errorf(codes.Internal, "lookup invitation: %v", err)
	}

	// Client-panel invites (docs/39) take a dedicated path: acceptance
	// ATTACHES the auth identity to the kartoteka's existing
	// users(role=PATIENT) row — no user/org/seat creation.
	//
	// MUST dispatch BEFORE the pool.Begin below: acceptClientInvitation
	// opens its own transaction, and with MaxConns=1 an already-open
	// outer tx starves it — the request then hangs until the Cloud Run
	// 300s timeout (caught live by the magic-link e2e).
	if inv.InvitedRole == "PATIENT" {
		// docs/42 O1: zaproszenia z kodem parowania (hash != NULL)
		// wymagają drugiego czynnika. Stare zaproszenia (hash NULL,
		// sprzed migracji 000076) przechodzą po staremu aż wygasną.
		if len(inv.PairingCodeHash) > 0 {
			if inv.CodeAttempts >= pairingCodeMaxAttempts {
				return nil, status.Error(codes.FailedPrecondition,
					"INVITATION_BLOCKED: too many wrong pairing codes — ask the therapist for a new invitation")
			}
			if subtle.ConstantTimeCompare(
				hashPairingCode(req.PairingCode), inv.PairingCodeHash) != 1 {
				attempts, aerr := s.queries.IncrementInvitationCodeAttempts(ctx, inv.ID)
				if aerr != nil {
					return nil, status.Errorf(codes.Internal, "count attempt: %v", aerr)
				}
				slog.InfoContext(ctx, "analytics",
					"ae", "client_invite.code_rejected",
					"invitation_id", inv.ID.String(),
					"attempts", attempts)
				if attempts >= pairingCodeMaxAttempts {
					slog.WarnContext(ctx, "analytics",
						"ae", "client_invite.blocked",
						"invitation_id", inv.ID.String())
					return nil, status.Error(codes.FailedPrecondition,
						"INVITATION_BLOCKED: too many wrong pairing codes — ask the therapist for a new invitation")
				}
				return nil, status.Error(codes.InvalidArgument,
					"PAIRING_CODE_INVALID: wrong pairing code")
			}
		}
		return s.acceptClientInvitation(ctx, inv, req, verifiedUID)
	}

	// Staff (therapist/manager) accounts DO carry names — enforce the
	// pre-docs/43 requirement for every non-PATIENT role.
	if req.FirstName == "" || req.LastName == "" {
		return nil, status.Error(codes.InvalidArgument, "first_name and last_name required")
	}

	// Tx: create User, link to org, mark invitation accepted.
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := db.New(tx)

	// Role comes from the invitation (docs/38): THERAPIST for team
	// invites, ORG_ADMIN for manager invites minted by
	// AdminCreateOrganization. The DB CHECK constraint guarantees no
	// other value can be stored; still, never trust it for
	// SUPERWIZOR_ADMIN (defence in depth).
	role := inv.InvitedRole
	if role != "THERAPIST" && role != db.UserRoleORGADMIN {
		return nil, status.Errorf(codes.Internal, "invitation carries non-invitable role %q", role)
	}

	emailLC := strings.ToLower(strings.TrimSpace(inv.Email))
	user, err := qtx.CreateUser(ctx, db.CreateUserParams{
		Role:           role,
		FirebaseUid:    &verifiedUID,
		Email:          &emailLC,
		FirstName:      req.FirstName,
		LastName:       req.LastName,
		UiLanguage:     defaultStr(req.UiLanguage, "pl"),
		Timezone:       defaultStr(req.Timezone, "Europe/Warsaw"),
		HasAcceptedTos: req.HasAcceptedTos,
	})
	if err != nil {
		// Single-role MVP: the invited e-mail (or the accepting Firebase
		// identity) already owns an account, so a second role can't be
		// minted. Stable code instead of a raw 500 — live-tested
		// 2026-07-04: an existing THERAPIST accepting their own
		// ORG_ADMIN invite got "Coś poszło nie tak".
		if isUniqueViolationErr(err) {
			return nil, status.Errorf(codes.FailedPrecondition,
				"EMAIL_ALREADY_REGISTERED: this e-mail (or signed-in account) already has a Superwizor account — a %s invitation needs a different e-mail address", string(role))
		}
		return nil, status.Errorf(codes.Internal, "create user: %v", err)
	}
	if err := qtx.LinkUserToOrganization(ctx, db.LinkUserToOrganizationParams{
		ID:             user.ID,
		OrganizationID: pgtype.UUID{Bytes: inv.OrganizationID, Valid: true},
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "link user→org: %v", err)
	}
	user.OrganizationID = pgtype.UUID{Bytes: inv.OrganizationID, Valid: true}

	// Seat-pinned therapist invite → occupy the reserved seat (docs/38
	// §3: the pending invitation held the reservation; the assignment
	// makes it permanent). Same tx — a failure rolls back the user too.
	if role == "THERAPIST" && inv.AllocationID.Valid {
		if _, err := qtx.CreateSeatAssignment(ctx, db.CreateSeatAssignmentParams{
			UserID:       user.ID,
			AllocationID: uuid.UUID(inv.AllocationID.Bytes),
		}); err != nil {
			return nil, status.Errorf(codes.Internal, "create seat assignment: %v", err)
		}
	}

	// Numer telefonu dla zaproszeń personelu. PATIENT go nie dostaje —
	// konto klienta jest pseudonimowe (docs/43 §4), więc tu obowiązuje
	// ta sama zasada co dla first_name/last_name wyżej: pole jest
	// ignorowane, a nie odrzucane, żeby stary klient nie wywracał
	// akceptacji.
	phone := strings.TrimSpace(req.PhoneNumber)
	if inv.InvitedRole == "PATIENT" {
		phone = ""
	}

	// Marketing consent + optional default modality + telefon.
	if req.HasMarketingConsent || req.DefaultModalityId != "" || phone != "" {
		updParams := db.UpdateProfileParams{ID: user.ID}
		if phone != "" {
			updParams.PhoneNumber = &phone
		}
		if req.HasMarketingConsent {
			t := true
			updParams.HasMarketingConsent = &t
		}
		if req.DefaultModalityId != "" {
			modID, err := uuid.Parse(req.DefaultModalityId)
			if err != nil {
				return nil, status.Error(codes.InvalidArgument, "invalid default_modality_id")
			}
			updParams.DefaultModalityID = pgtype.UUID{Bytes: modID, Valid: true}
		}
		if updated, err := qtx.UpdateProfile(ctx, updParams); err == nil {
			user = updated
		}
	}

	if err := qtx.MarkInvitationAccepted(ctx, db.MarkInvitationAcceptedParams{
		ID:             inv.ID,
		AcceptedUserID: pgtype.UUID{Bytes: user.ID, Valid: true},
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "mark accepted: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	// Load the org for the response so the welcome page can greet the
	// user with the clinic name.
	org, err := s.queries.GetOrganizationByID(ctx, inv.OrganizationID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load org for response: %v", err)
	}
	var hq *db.Address
	if org.HeadquartersAddressID.Valid {
		a, err := s.queries.GetAddressByID(ctx, uuid.UUID(org.HeadquartersAddressID.Bytes))
		if err == nil {
			hq = &a
		}
	}

	return &identityv1.AcceptInvitationResponse{
		User:         toProtoUser(user),
		Organization: toProtoOrganization(org, hq, false),
	}, nil
}

// ListTherapistsInMyOrg returns active + pending therapists for the
// caller's org. Org-admin only.
func (s *Server) ListTherapistsInMyOrg(ctx context.Context, _ *emptypb.Empty) (*identityv1.ListTherapistsResponse, error) {
	caller, err := s.requireOrgAdmin(ctx)
	if err != nil {
		return nil, err
	}
	if caller.organizationID == nil {
		return nil, status.Error(codes.FailedPrecondition, "caller has no organization")
	}

	active, err := s.queries.ListTherapistsByOrganization(ctx, pgtype.UUID{Bytes: *caller.organizationID, Valid: true})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list active therapists: %v", err)
	}
	pending, err := s.queries.ListPendingInvitationsByOrg(ctx, *caller.organizationID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list pending invitations: %v", err)
	}

	out := &identityv1.ListTherapistsResponse{
		Therapists: make([]*identityv1.TherapistEntry, 0, len(active)+len(pending)),
	}
	for _, u := range active {
		out.Therapists = append(out.Therapists, &identityv1.TherapistEntry{
			User: toProtoUser(u),
		})
	}
	for _, inv := range pending {
		out.Therapists = append(out.Therapists, &identityv1.TherapistEntry{
			PendingInvitation: toProtoInvitation(inv),
		})
	}
	return out, nil
}

// RemoveTherapist soft-deletes a therapist from the caller's org.
// Org-admin only. The therapist's data stays — kartoteki and sessions
// they created are NOT cascaded; another therapist in the org can be
// assigned ownership later (out of Slice 1 scope).
func (s *Server) RemoveTherapist(ctx context.Context, req *identityv1.RemoveTherapistRequest) (*emptypb.Empty, error) {
	caller, err := s.requireOrgAdmin(ctx)
	if err != nil {
		return nil, err
	}
	if caller.organizationID == nil {
		return nil, status.Error(codes.FailedPrecondition, "caller has no organization")
	}
	userID, err := uuid.Parse(req.UserId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user_id")
	}
	// Scope check: target must be in the caller's org.
	target, err := s.queries.GetUserByID(ctx, userID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}
	if !target.OrganizationID.Valid || uuid.UUID(target.OrganizationID.Bytes) != *caller.organizationID {
		return nil, status.Error(codes.PermissionDenied, "user is not in your organization")
	}
	if target.Role != "THERAPIST" {
		return nil, status.Error(codes.FailedPrecondition, "can only remove THERAPISTs from the org")
	}
	if err := s.queries.SoftDeleteUser(ctx, userID); err != nil {
		return nil, status.Errorf(codes.Internal, "soft delete: %v", err)
	}
	return &emptypb.Empty{}, nil
}

// ─── Token helpers ─────────────────────────────────────────────

// generateInvitationToken returns:
//   - a URL-safe base64 cleartext token (32 bytes of crypto/rand)
//   - its SHA-256 hash (32 bytes) — what we store in PG
//
// The cleartext NEVER touches PG; only the hash. The token lives in
// the email + the recipient's inbox.
func generateInvitationToken() (cleartext string, hash []byte, err error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", nil, fmt.Errorf("crypto/rand: %w", err)
	}
	cleartext = base64.RawURLEncoding.EncodeToString(raw)
	h := sha256.Sum256([]byte(cleartext))
	return cleartext, h[:], nil
}

// hashToken matches generateInvitationToken's hash — SHA-256 of the
// URL-safe base64 cleartext. Used by AcceptInvitation.
func hashToken(token string) []byte {
	h := sha256.Sum256([]byte(token))
	return h[:]
}
