package grpc

// Menedżer organizacji, który sam prowadzi terapię.
//
// Do tej pory ORG_ADMIN i THERAPIST wykluczały się w praktyce: konto ma
// jedną rolę, a wszystko, co dotyczy praktykowania, filtrowało po
// role = 'THERAPIST'. W małych gabinetach właściciel bywa jednocześnie
// menedżerem i praktykiem, więc musiał zakładać drugie konto na inny
// adres — tekst "jedno konto może mieć tylko jedną rolę i organizację"
// z panelu opisywał to ograniczenie wprost.
//
// Rozwiązanie NIE zmienia roli. Prawem do praktykowania jest MIEJSCE
// w planie, i tak już jest w systemie:
//
//   - billing-svc wyprowadza licznik zużycia z miejsca, nie z roli —
//     GetSeatPlanForTherapist i ListSeatedTherapistsByOrg nie mają
//     predykatu na users.role;
//   - aplikacja kieruje na powierzchnię terapeuty każdego, kto nie jest
//     pacjentem (main.dart — rozgałęzienie tylko na USER_ROLE_PATIENT),
//     więc ORG_ADMIN już dziś się tam dostaje;
//   - ORG_ADMIN ma już wgląd w kartoteki swojej organizacji w ramach
//     nadzoru klinicznego (docs/38), więc nadanie miejsca NIE poszerza
//     dostępu do danych — daje tylko własny limit i widoczność w zespole.
//
// Alternatywa — zmiana roli na THERAPIST albo czwarta wartość enuma —
// wymagałaby ruszenia kilkunastu miejsc bramkujących rolę i odebrałaby
// (albo zduplikowała) uprawnienia menedżerskie. Miejsce jest już
// źródłem prawdy dla rozliczeń; rozszerzamy je na widoczność.

import (
	"context"
	"errors"
	"log/slog"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// SetManagerTherapistSeat nadaje menedżerowi miejsce w planie albo je
// zwalnia. ORG_ADMIN only; cel musi być ORG_ADMINem w organizacji
// wywołującego.
//
// practicing=true  — zajmuje miejsce we wskazanej alokacji, pod blokadą
// wiersza alokacji i z tym samym testem zajętości co zaproszenia
// (SEATS_EXHAUSTED liczy również zaproszenia oczekujące).
//
// practicing=false — zwalnia miejsce. NIE rusza users.is_active: to jest
// odebranie praktyki, nie dezaktywacja konta. Menedżer zachowuje dostęp
// do panelu, a jego licznik zużycia w otwartym okresie zostaje —
// historia rozliczeniowa nie jest do przepisywania.
func (s *Server) SetManagerTherapistSeat(
	ctx context.Context,
	req *identityv1.SetManagerTherapistSeatRequest,
) (*identityv1.User, error) {
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

	target, err := s.queries.GetUserByID(ctx, userID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}
	if !target.OrganizationID.Valid ||
		uuid.UUID(target.OrganizationID.Bytes) != *caller.organizationID {
		return nil, status.Error(codes.PermissionDenied, "user is not in your organization")
	}
	// Terapeuci mają własną ścieżkę (SetTherapistStatus + zaproszenia).
	// Ten RPC istnieje wyłącznie dla menedżerów i nie może być obejściem
	// tamtych reguł.
	if target.Role != db.UserRoleORGADMIN {
		return nil, status.Error(codes.FailedPrecondition, "MANAGER_ROLE_REQUIRED")
	}
	if target.DeletedAt.Valid {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	// Wejście walidujemy PRZED otwarciem transakcji — nie ma powodu
	// trzymać połączenia na źle sformułowane żądanie.
	var allocationID uuid.UUID
	if req.Practicing {
		allocationID, err = uuid.Parse(req.AllocationId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid allocation_id")
		}
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := db.New(tx)

	if req.Practicing {
		alloc, err := qtx.GetSeatAllocationForUpdate(ctx, allocationID)
		if err != nil {
			return nil, status.Error(codes.NotFound, "seat allocation not found")
		}
		// Alokacja z cudzej organizacji to NotFound, nie PermissionDenied
		// — nie potwierdzamy istnienia obcych zasobów.
		if alloc.OrganizationID != *caller.organizationID {
			return nil, status.Error(codes.NotFound, "seat allocation not found")
		}
		if err := checkSeatAvailable(ctx, qtx, alloc); err != nil {
			return nil, err
		}
		// uq_one_active_seat_per_user dopuszcza jeden otwarty wiersz na
		// użytkownika, więc powtórne wywołanie (albo przeniesienie na inny
		// plan) musi najpierw zamknąć poprzednie miejsce. Bez tego drugie
		// kliknięcie kończyłoby się surowym 23505.
		if err := qtx.CloseActiveSeatAssignmentForUser(ctx, userID); err != nil {
			return nil, status.Errorf(codes.Internal, "close previous seat: %v", err)
		}
		if _, err := qtx.CreateSeatAssignment(ctx, db.CreateSeatAssignmentParams{
			UserID:       userID,
			AllocationID: alloc.ID,
		}); err != nil {
			return nil, status.Errorf(codes.Internal, "create seat assignment: %v", err)
		}
	} else {
		if err := qtx.CloseActiveSeatAssignmentForUser(ctx, userID); err != nil {
			return nil, status.Errorf(codes.Internal, "close seat assignment: %v", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	slog.InfoContext(ctx, "manager therapist seat changed",
		"organization_id", caller.organizationID.String(),
		"user_id", userID.String(),
		"practicing", req.Practicing,
		"allocation_id", req.AllocationId,
		"reason", req.Reason)

	updated, err := s.queries.GetUserByID(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "user not found")
		}
		return nil, status.Errorf(codes.Internal, "reload user: %v", err)
	}
	return toProtoUser(updated), nil
}
