package grpc

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"net/url"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// Client (patient) panel invitations — docs/39. Same magic-link
// machinery as the docs/38 manager flow; the invite is BOUND to a
// kartoteka (invitations.patient_file_id) and acceptance attaches the
// auth identity to the EXISTING users(role=PATIENT) row (D1) instead
// of creating one.

// requireKartotekaAccess gates the client-invite RPCs: the caller must
// be the kartoteka's owning therapist or an ORG_ADMIN of the owner's
// organization (mirrors clinical-svc's requireTherapistDataAccess).
// Denial = NotFound, never PermissionDenied (no enumeration oracle).
func (s *Server) requireKartotekaAccess(ctx context.Context, pf db.GetPatientFileForInviteRow) (callerContext, error) {
	caller, err := s.resolveCaller(ctx)
	if err != nil {
		return callerContext{}, err
	}
	if caller.userID == pf.TherapistID {
		return caller, nil
	}
	if caller.role == db.UserRoleORGADMIN && caller.organizationID != nil {
		owner, err := s.queries.GetUserByID(ctx, pf.TherapistID)
		if err == nil && owner.OrganizationID.Valid &&
			uuid.UUID(owner.OrganizationID.Bytes) == *caller.organizationID {
			return caller, nil
		}
	}
	return callerContext{}, status.Error(codes.NotFound, "patient file not found")
}

// InviteClient — "Zaproś klienta" from the kartoteka. Re-inviting the
// same kartoteka refreshes the pending invitation's token/e-mail
// (uq_invitations_patient_file_pending guarantees at most one).
func (s *Server) InviteClient(ctx context.Context, req *identityv1.InviteClientRequest) (*identityv1.Invitation, error) {
	pfID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}
	pf, err := s.queries.GetPatientFileForInvite(ctx, pfID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	caller, err := s.requireKartotekaAccess(ctx, pf)
	if err != nil {
		return nil, err
	}

	// Resolve the recipient: explicit e-mail wins (and is persisted),
	// else the kartoteka's stored patient_email.
	email := strings.ToLower(strings.TrimSpace(req.Email))
	if email != "" && !strings.Contains(email, "@") {
		return nil, status.Error(codes.InvalidArgument, "invalid email")
	}
	if email == "" {
		if pf.PatientEmail != nil {
			email = strings.ToLower(strings.TrimSpace(*pf.PatientEmail))
		}
		if email == "" {
			return nil, status.Error(codes.FailedPrecondition,
				"CLIENT_EMAIL_MISSING: kartoteka has no patient e-mail — provide one")
		}
	} else if pf.PatientEmail == nil || !strings.EqualFold(*pf.PatientEmail, email) {
		if err := s.queries.SetPatientFileEmail(ctx, db.SetPatientFileEmailParams{
			ID:           pfID,
			PatientEmail: &email,
		}); err != nil {
			return nil, status.Errorf(codes.Internal, "persist patient email: %v", err)
		}
	}

	// Guard: the e-mail must not belong to a non-PATIENT account
	// (single-role MVP, docs/39 §8a).
	if existing, err := s.queries.GetUserByEmail(ctx, &email); err == nil && existing.Role != "PATIENT" {
		return nil, status.Error(codes.FailedPrecondition,
			"CLIENT_EMAIL_TAKEN: this e-mail belongs to a therapist/manager account")
	}

	if caller.organizationID == nil {
		return nil, status.Error(codes.FailedPrecondition, "caller has no organization")
	}

	token, tokenHash, err := generateInvitationToken()
	if err != nil {
		return nil, status.Errorf(codes.Internal, "generate token: %v", err)
	}
	// docs/42 O1: kod parowania przekazywany pacjentowi POZA e-mailem.
	pairingCode, pairingHash, err := generatePairingCode()
	if err != nil {
		return nil, status.Errorf(codes.Internal, "generate pairing code: %v", err)
	}
	expiresAt := time.Now().Add(clientInvitationTTL)

	inv, err := s.queries.CreateInvitation(ctx, db.CreateInvitationParams{
		OrganizationID: *caller.organizationID,
		InvitedByUser:  caller.userID,
		Email:          email,
		TokenHash:      tokenHash,
		ExpiresAt:      expiresAt,
		InvitedRole:    "PATIENT",
		PatientFileID:  pgtype.UUID{Bytes: pfID, Valid: true},
	})
	if err == nil {
		// Stamp the pairing hash on the fresh row. Osobny UPDATE zamiast
		// zmiany współdzielonego CreateInvitation (jego sygnatury używają
		// też zaproszenia zespołowe/managerskie). Okno awarii między
		// INSERT a UPDATE zamyka refresh path poniżej — re-invite zawsze
		// nadpisuje hash.
		if uerr := s.queries.SetInvitationPairingCode(ctx, db.SetInvitationPairingCodeParams{
			ID:              inv.ID,
			PairingCodeHash: pairingHash,
		}); uerr != nil {
			return nil, status.Errorf(codes.Internal, "stamp pairing code: %v", uerr)
		}
	} else {
		// Refresh path — a pending invite for this kartoteka (or the
		// same (org,email) pair) already exists. Rotacja tokenu I kodu
		// zeruje licznik prób i zdejmuje ewentualne revoked_at (świadome
		// ponowne zaproszenie po cofnięciu).
		existing, lookupErr := s.queries.GetPendingPatientInvitationByFile(ctx,
			pgtype.UUID{Bytes: pfID, Valid: true})
		if lookupErr != nil {
			return nil, status.Errorf(codes.Internal, "create invitation: %v", err)
		}
		if _, err := s.pool.Exec(ctx,
			`UPDATE invitations
			    SET token_hash = $2, expires_at = $3, invited_by_user = $4,
			        email = $5, created_at = now(),
			        pairing_code_hash = $6, code_attempts = 0, revoked_at = NULL
			  WHERE id = $1`,
			existing.ID, tokenHash, expiresAt, caller.userID, email, pairingHash,
		); err != nil {
			return nil, status.Errorf(codes.Internal, "refresh invitation: %v", err)
		}
		inv = existing
		inv.TokenHash = tokenHash
		inv.ExpiresAt = expiresAt
		inv.Email = email
	}
	slog.InfoContext(ctx, "analytics",
		"ae", "client_invite.sent",
		"patient_file_id", pfID.String(),
		"by_user", caller.userID.String())

	// Post-create e-mail (patient_invite template via invited_role).
	therapistName := ""
	if u, err := s.queries.GetUserByID(ctx, pf.TherapistID); err == nil {
		therapistName = u.FirstName
	}
	// Clients get the dedicated onboarding page (docs/39 C-PR10):
	// social login or password, then straight into the client panel —
	// NOT the org-flavoured /accept-invite used by therapist/manager
	// invitations.
	acceptURL := fmt.Sprintf("%s/register/client?token=%s",
		strings.TrimRight(s.acceptURLBase, "/"),
		url.QueryEscape(token),
	)
	_ = s.emailer.SendInvitation(ctx, InvitationEmailParams{
		Recipient:        email,
		OrgName:          therapistName, // template uses the therapist's name, not the org
		InviterFirstName: therapistName,
		AcceptURL:        acceptURL,
		ExpiresAt:        expiresAt.Format(time.RFC3339),
		Locale:           "pl",
		InvitedRole:      "PATIENT",
	})

	out := toProtoInvitation(inv)
	// docs/42: plaintext kodu wyłącznie w TEJ odpowiedzi — pokazywany
	// terapeucie jeden raz; każdy inny odczyt Invitation zwraca puste.
	out.PairingCode = pairingCode
	return out, nil
}

// GetClientInviteStatus feeds the kartoteka header chip
// (NONE / PENDING / ACTIVE / INACTIVE).
func (s *Server) GetClientInviteStatus(ctx context.Context, req *identityv1.GetClientInviteStatusRequest) (*identityv1.ClientInviteStatus, error) {
	pfID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}
	pf, err := s.queries.GetPatientFileForInvite(ctx, pfID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	if _, err := s.requireKartotekaAccess(ctx, pf); err != nil {
		return nil, err
	}

	out := &identityv1.ClientInviteStatus{Status: "NONE"}
	if pf.PatientEmail != nil {
		out.Email = *pf.PatientEmail
	}

	// Activated? The kartoteka's patient user carries a firebase_uid
	// once the client accepted.
	if pf.PatientID.Valid {
		if u, err := s.queries.GetUserByID(ctx, uuid.UUID(pf.PatientID.Bytes)); err == nil &&
			u.FirebaseUid != nil && *u.FirebaseUid != "" {
			if u.IsActive {
				out.Status = "ACTIVE"
			} else {
				out.Status = "INACTIVE"
			}
			if u.Email != nil {
				out.Email = *u.Email
			}
			return out, nil
		}
	}

	inv, err := s.queries.GetPendingPatientInvitationByFile(ctx,
		pgtype.UUID{Bytes: pfID, Valid: true})
	switch {
	case err == nil:
		if inv.ExpiresAt.After(time.Now()) {
			out.Status = "PENDING"
			out.Email = inv.Email
			out.ExpiresAt = timestamppb.New(inv.ExpiresAt)
		}
	case errors.Is(err, pgx.ErrNoRows):
		// stays NONE
	default:
		return nil, status.Errorf(codes.Internal, "invite lookup: %v", err)
	}
	return out, nil
}

// acceptClientInvitation — the PATIENT branch of AcceptInvitation
// (docs/39 D1/D4). Attach-not-create:
//
//  1. caller's firebase_uid already owns a PATIENT account → point the
//     kartoteka at it (same client, another therapist — D4);
//  2. kartoteka has a patient row → fill in firebase_uid/email/ToS;
//     if the e-mail already belongs to a DIFFERENT patient account,
//     re-point the kartoteka at that account instead (D4 by e-mail);
//  3. pseudonymous kartoteka (patient_id NULL) → create the patient
//     user now and link it.
//
// Never: org linking, seat assignment, trial provisioning.
func (s *Server) acceptClientInvitation(ctx context.Context, inv db.Invitation, req *identityv1.AcceptInvitationRequest, verifiedUID string) (*identityv1.AcceptInvitationResponse, error) {
	if !inv.PatientFileID.Valid {
		return nil, status.Error(codes.Internal, "patient invitation without kartoteka binding")
	}
	pfID := uuid.UUID(inv.PatientFileID.Bytes)
	pf, err := s.queries.GetPatientFileForInvite(ctx, pfID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	emailLC := strings.ToLower(strings.TrimSpace(inv.Email))

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := db.New(tx)

	var user db.User
	switch existing, lookupErr := qtx.GetUserByFirebaseUID(ctx, &verifiedUID); {
	case lookupErr == nil:
		// (1) returning client on another kartoteka.
		if existing.Role != "PATIENT" {
			return nil, status.Error(codes.FailedPrecondition,
				"CLIENT_EMAIL_TAKEN: this account is not a client account")
		}
		if err := qtx.SetPatientFilePatientID(ctx, db.SetPatientFilePatientIDParams{
			ID:        pfID,
			PatientID: pgtype.UUID{Bytes: existing.ID, Valid: true},
		}); err != nil {
			return nil, status.Errorf(codes.Internal, "link kartoteka: %v", err)
		}
		user = existing

	case errors.Is(lookupErr, pgx.ErrNoRows) && pf.PatientID.Valid:
		// (2) activate the kartoteka's own patient row.
		user, err = qtx.ActivatePatientUser(ctx, db.ActivatePatientUserParams{
			ID:          uuid.UUID(pf.PatientID.Bytes),
			FirebaseUid: &verifiedUID,
			Email:       &emailLC,
			Column4:     req.FirstName,
			Column5:     req.LastName,
		})
		if err != nil {
			if isUniqueViolationErr(err) {
				// e-mail already owned by another patient account → D4.
				other, oerr := qtx.GetUserByEmail(ctx, &emailLC)
				if oerr != nil || other.Role != "PATIENT" {
					return nil, status.Error(codes.FailedPrecondition,
						"CLIENT_EMAIL_TAKEN: e-mail already used by another account")
				}
				if err := qtx.SetPatientFilePatientID(ctx, db.SetPatientFilePatientIDParams{
					ID:        pfID,
					PatientID: pgtype.UUID{Bytes: other.ID, Valid: true},
				}); err != nil {
					return nil, status.Errorf(codes.Internal, "relink kartoteka: %v", err)
				}
				// Attach the fresh firebase_uid iff that account has none.
				if other.FirebaseUid == nil || *other.FirebaseUid == "" {
					other, err = qtx.ActivatePatientUser(ctx, db.ActivatePatientUserParams{
						ID:          other.ID,
						FirebaseUid: &verifiedUID,
						Email:       &emailLC,
						Column4:     req.FirstName,
						Column5:     req.LastName,
					})
					if err != nil {
						return nil, status.Errorf(codes.Internal, "activate patient: %v", err)
					}
				}
				user = other
			} else {
				return nil, status.Errorf(codes.Internal, "activate patient: %v", err)
			}
		}

	case errors.Is(lookupErr, pgx.ErrNoRows):
		// (3) pseudonymous kartoteka — mint the patient user now.
		user, err = qtx.CreateUser(ctx, db.CreateUserParams{
			Role:           "PATIENT",
			FirebaseUid:    &verifiedUID,
			Email:          &emailLC,
			FirstName:      req.FirstName,
			LastName:       req.LastName,
			UiLanguage:     defaultStr(req.UiLanguage, "pl"),
			Timezone:       defaultStr(req.Timezone, "Europe/Warsaw"),
			HasAcceptedTos: req.HasAcceptedTos,
		})
		if err != nil {
			return nil, status.Errorf(codes.Internal, "create patient user: %v", err)
		}
		if err := qtx.SetPatientFilePatientID(ctx, db.SetPatientFilePatientIDParams{
			ID:        pfID,
			PatientID: pgtype.UUID{Bytes: user.ID, Valid: true},
		}); err != nil {
			return nil, status.Errorf(codes.Internal, "link kartoteka: %v", err)
		}

	default:
		return nil, status.Errorf(codes.Internal, "lookup caller: %v", lookupErr)
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
	slog.InfoContext(ctx, "analytics",
		"ae", "client_invite.accepted",
		"invitation_id", inv.ID.String(),
		"patient_file_id", pfID.String())

	org, err := s.queries.GetOrganizationByID(ctx, inv.OrganizationID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load org: %v", err)
	}
	return &identityv1.AcceptInvitationResponse{
		User:         toProtoUser(user),
		Organization: toProtoOrganization(org, nil, false),
	}, nil
}

// isUniqueViolationErr — 23505 detection (local copy; billing has its
// own; identity previously matched on CreateInvitation errors ad hoc).
func isUniqueViolationErr(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == pgerrcode.UniqueViolation
}

// GetInvitationPreview — public, token-as-capability read used by the
// accept-invite page to adapt its form BEFORE signup (docs/39): a
// PATIENT invite hides the therapist-only fields and routes to the
// client panel afterwards. Reveals only what the e-mail already told
// the recipient.
func (s *Server) GetInvitationPreview(ctx context.Context, req *identityv1.GetInvitationPreviewRequest) (*identityv1.InvitationPreview, error) {
	if req.Token == "" {
		return nil, status.Error(codes.InvalidArgument, "token required")
	}
	inv, err := s.queries.GetUnacceptedInvitationByTokenHash(ctx, hashToken(req.Token))
	if err != nil {
		return nil, status.Error(codes.NotFound, "invitation not found, expired, or already accepted")
	}
	out := &identityv1.InvitationPreview{
		InvitedRole:         toProtoRole(inv.InvitedRole),
		Email:               inv.Email,
		RequiresPairingCode: len(inv.PairingCodeHash) > 0,
	}
	if inv.InvitedFirstName != nil {
		out.FirstName = *inv.InvitedFirstName
	}
	if inv.InvitedLastName != nil {
		out.LastName = *inv.InvitedLastName
	}
	if org, err := s.queries.GetOrganizationByID(ctx, inv.OrganizationID); err == nil {
		out.OrganizationName = org.LegalName
	}
	if u, err := s.queries.GetUserByID(ctx, inv.InvitedByUser); err == nil {
		out.InviterFirstName = u.FirstName
	}
	return out, nil
}


// clientInvitationTTL — docs/42 O0: link klienta prowadzi do danych
// klinicznych, więc żyje krócej niż zaproszenia zespołowe (7 d).
const clientInvitationTTL = 72 * time.Hour

// pairingCodeMaxAttempts blokuje zaproszenie po serii błędnych kodów.
const pairingCodeMaxAttempts = 5

// generatePairingCode zwraca 6-cyfrowy kod (crypto/rand) + jego hash.
// Przestrzeń 10^6 jest wystarczająca, bo próby są limitowane server-side
// (pairingCodeMaxAttempts), a hash nigdy nie opuszcza bazy.
func generatePairingCode() (cleartext string, hash []byte, err error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1_000_000))
	if err != nil {
		return "", nil, err
	}
	cleartext = fmt.Sprintf("%06d", n.Int64())
	return cleartext, hashPairingCode(cleartext), nil
}

// hashPairingCode — SHA-256 znormalizowanego kodu (bez spacji).
func hashPairingCode(code string) []byte {
	sum := sha256.Sum256([]byte(normalizePairingCode(code)))
	return sum[:]
}

func normalizePairingCode(code string) string {
	return strings.ReplaceAll(strings.TrimSpace(code), " ", "")
}

// RevokeClientInvite — docs/42 O0: jawne cofnięcie wiszącego
// zaproszenia klienta. Token umiera natychmiast; idempotentne.
func (s *Server) RevokeClientInvite(ctx context.Context, req *identityv1.RevokeClientInviteRequest) (*identityv1.ClientInviteStatus, error) {
	pfID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}
	pf, err := s.queries.GetPatientFileForInvite(ctx, pfID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "patient file not found")
	}
	caller, err := s.requireKartotekaAccess(ctx, pf)
	if err != nil {
		return nil, err
	}
	affected, err := s.queries.RevokePatientInvitation(ctx,
		pgtype.UUID{Bytes: pfID, Valid: true})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "revoke invitation: %v", err)
	}
	slog.InfoContext(ctx, "analytics",
		"ae", "client_invite.revoked",
		"patient_file_id", pfID.String(),
		"by_user", caller.userID.String(),
		"had_pending", affected > 0)
	return s.GetClientInviteStatus(ctx, &identityv1.GetClientInviteStatusRequest{
		PatientFileId: req.PatientFileId,
	})
}
