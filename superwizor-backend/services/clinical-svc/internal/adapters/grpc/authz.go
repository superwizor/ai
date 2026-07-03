package grpc

import (
	"context"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// requireTherapistDataAccess is the object-level authorization gate — the fix
// for the IDOR / BOLA class where a handler loaded a session / patient_file by
// a request-supplied ID and returned its (decrypted) contents without checking
// who was asking.
//
// A caller may read or act on clinical data owned by [ownerTherapistID] only
// if they are:
//   - that therapist — the owner (the overwhelmingly common path), OR
//   - an ORG_ADMIN of the SAME organization (clinic oversight, docs/38), OR
//   - a SUPERWIZOR_ADMIN (platform staff; already reaches this data via
//     the dedicated Admin* RPCs).
//
// On denial it returns codes.NotFound — never PermissionDenied — so a caller
// cannot distinguish "exists but not yours" from "does not exist" and thus
// cannot use the endpoint as an object-enumeration oracle. Callers pass the
// owning therapist_id from the row they just loaded and return the error
// verbatim.
func (s *Server) requireTherapistDataAccess(ctx context.Context, ownerTherapistID uuid.UUID) error {
	callerID, _ := ctx.Value(UserIDKey).(string)
	if callerID == "" {
		return status.Error(codes.Unauthenticated, "missing caller identity")
	}
	if callerID == ownerTherapistID.String() {
		return nil // owner
	}

	switch role, _ := ctx.Value(UserRoleKey).(string); role {
	case "SUPERWIZOR_ADMIN":
		return nil // platform staff — omnipotent via Admin* RPCs anyway
	case "ORG_ADMIN":
		callerOrg, _ := ctx.Value(OrganizationIDKey).(string)
		if callerOrg == "" {
			break // no org on the token → cannot org-scope; deny
		}
		ownerOrg, err := s.queries.GetUserOrganizationID(ctx, ownerTherapistID)
		if err != nil || !ownerOrg.Valid {
			break // owner missing / has no org → deny
		}
		if uuid.UUID(ownerOrg.Bytes).String() == callerOrg {
			return nil // ORG_ADMIN of the owning therapist's organization
		}
	}
	return status.Error(codes.NotFound, "not found")
}
