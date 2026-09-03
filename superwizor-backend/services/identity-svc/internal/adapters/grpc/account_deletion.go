package grpc

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// Samodzielne usunięcie konta — docs/70 R9, wymóg Apple 5.1.1(v).
//
// Apple wymaga, żeby aplikacja, w której da się ZAŁOŻYĆ konto, pozwalała
// je też USUNĄĆ z poziomu aplikacji; odesłanie użytkownika na stronę nie
// wystarcza. Wymóg staje się blokujący dopiero razem z rejestracją
// in-app, ale implementacja jest wspólna dla aplikacji i weba.
//
// Zakres operacji jest celowo wąski: soft-delete (users.deleted_at) plus
// wyłączenie konta w Firebase. Twarde czyszczenie danych klinicznych idzie
// osobnym procesem RODO — kartoteki i transkrypty mają własne terminy
// retencji, a ich natychmiastowe skasowanie jednym tapnięciem byłoby
// nieodwracalną utratą dokumentacji, nie realizacją prawa do bycia
// zapomnianym.

// deletionConfirmations to teksty, które użytkownik przepisuje, żeby
// potwierdzić zamiar. To zabezpieczenie przed przypadkowym tapnięciem,
// nie uwierzytelnienie — tożsamość potwierdza token Firebase.
var deletionConfirmations = map[string]bool{
	"USUWAM": true,
	"DELETE": true,
}

func (s *Server) DeleteMyAccount(ctx context.Context, req *identityv1.DeleteMyAccountRequest) (*emptypb.Empty, error) {
	caller, err := s.resolveCaller(ctx)
	if err != nil {
		return nil, err
	}
	if !deletionConfirmations[strings.ToUpper(strings.TrimSpace(req.GetConfirmation()))] {
		return nil, status.Error(codes.InvalidArgument,
			"CONFIRMATION_REQUIRED: wpisz USUWAM (lub DELETE), aby potwierdzić usunięcie konta")
	}

	// ORG_ADMIN kliniki nie usuwa się sam: zostawiłby organizację bez
	// właściciela, z terapeutami, których nikt nie może zdeaktywować.
	// Taki wniosek obsługuje administrator platformy.
	if caller.role == db.UserRoleORGADMIN {
		return nil, status.Error(codes.FailedPrecondition,
			"ORG_ADMIN_CANNOT_SELF_DELETE: skontaktuj się z nami, aby przekazać zarządzanie organizacją")
	}

	// Subskrypcji kupionej w sklepie NIE umiemy anulować — może to zrobić
	// wyłącznie właściciel konta Apple/Google. Gdybyśmy skasowali konto po
	// cichu, użytkownik płaciłby dalej za usługę, do której stracił
	// dostęp. Stąd twarde zatrzymanie do czasu, aż potwierdzi, że wie
	// (docs/70 E5).
	if caller.organizationID != nil && !req.GetAcknowledgedSubscription() {
		sub, serr := s.queries.GetActiveStoreSubscriptionForOrg(ctx, *caller.organizationID)
		switch {
		case serr == nil:
			store := "App Store"
			if sub.Provider == "GOOGLE_IAP" {
				store = "Google Play"
			}
			return nil, status.Errorf(codes.FailedPrecondition,
				"STORE_SUBSCRIPTION_ACTIVE: masz aktywną subskrypcję kupioną w %s — anuluj ją w ustawieniach sklepu, "+
					"inaczej opłaty będą naliczane dalej mimo usunięcia konta", store)
		case errors.Is(serr, pgx.ErrNoRows):
			// Brak subskrypcji sklepowej — nic nie stoi na przeszkodzie.
		default:
			return nil, status.Errorf(codes.Internal, "store subscription lookup: %v", serr)
		}
	}

	if err := s.queries.SoftDeleteUser(ctx, caller.userID); err != nil {
		return nil, status.Errorf(codes.Internal, "soft delete: %v", err)
	}

	// Firebase wyłączamy PO zapisie w bazie. Odwrotna kolejność zostawiłaby
	// przy błędzie zapisu konto, którym nie da się zalogować, a które u nas
	// nadal istnieje — użytkownik traci dostęp, nie dostaje potwierdzenia i
	// nie ma jak tego cofnąć samodzielnie.
	if caller.firebaseUID != "" {
		if derr := s.auth.DisableUser(ctx, caller.firebaseUID); derr != nil {
			// Konto jest już usunięte po naszej stronie — token wygaśnie
			// najdalej w godzinę, a ValidateToken odrzuci usuniętego
			// użytkownika wcześniej. Zgłaszamy w logu, nie cofamy operacji.
			s.logAccountDeletionWarning(ctx, caller.firebaseUID, derr)
		}
	}

	reason := strings.TrimSpace(req.GetReason())
	meta := map[string]any{
		"self_service":              true,
		"acknowledged_subscription": req.GetAcknowledgedSubscription(),
	}
	if reason != "" {
		meta["reason_given"] = reason
	}
	s.writeAccountDeletionAudit(ctx, caller, meta)

	return &emptypb.Empty{}, nil
}

func (s *Server) writeAccountDeletionAudit(ctx context.Context, caller callerContext, meta map[string]any) {
	payload := []byte("{}")
	if b, err := json.Marshal(meta); err == nil {
		payload = b
	}
	params := db.CreateAuditEventParams{
		Action:       "identity.account_self_deleted",
		ResourceType: "user",
		ResourceID:   pgtype.UUID{Bytes: caller.userID, Valid: true},
		ActorUserID:  pgtype.UUID{Bytes: caller.userID, Valid: true},
		Metadata:     payload,
	}
	if caller.organizationID != nil {
		params.OrganizationID = pgtype.UUID{Bytes: *caller.organizationID, Valid: true}
	}
	if _, err := s.queries.CreateAuditEvent(ctx, params); err != nil {
		s.logAccountDeletionWarning(ctx, caller.firebaseUID, err)
	}
}

// logAccountDeletionWarning — usunięcie konta już się wydarzyło, więc
// każdy błąd poboczny (Firebase, audyt) jest do odnotowania, a nie do
// zwrócenia użytkownikowi jako porażka operacji.
func (s *Server) logAccountDeletionWarning(ctx context.Context, firebaseUID string, err error) {
	slog.WarnContext(ctx, "usunięcie konta: krok poboczny nieudany",
		"firebase_uid", firebaseUID, "error", err)
}
