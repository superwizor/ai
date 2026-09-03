package grpc

import (
	"context"
	"encoding/json"
	"log/slog"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/metadata"

	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// requestCaller to tożsamość zwykłego (nie-administracyjnego) wywołania:
// zalogowany terapeuta z aplikacji albo z przeglądarki.
//
// Nagłówki wstrzykuje ConnectAuthInterceptor po zweryfikowaniu tokena
// Firebase w identity-svc. Wywołania server-to-server na ścieżce
// natywnego gRPC ich nie mają — i słusznie, bo tamte RPC nie działają w
// imieniu użytkownika.
type requestCaller struct {
	role           string
	userID         *uuid.UUID
	organizationID *uuid.UUID
}

func resolveRequestCaller(ctx context.Context) requestCaller {
	var c requestCaller
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return c
	}
	if v := md.Get("x-superwizor-role"); len(v) > 0 {
		c.role = v[0]
	}
	if v := md.Get("x-superwizor-user-id"); len(v) > 0 {
		if id, err := uuid.Parse(v[0]); err == nil {
			c.userID = &id
		}
	}
	if v := md.Get("x-superwizor-organization-id"); len(v) > 0 {
		if id, err := uuid.Parse(v[0]); err == nil {
			c.organizationID = &id
		}
	}
	return c
}

// auditDiscountCode zapisuje ślad operacji na kodzie rabatowym.
//
// Osobno od writeBillingAudit, bo tamten wiąże zdarzenie z organizacją i
// subskrypcją, a kod rabatowy nie należy do żadnej organizacji. Błąd
// zapisu logujemy i idziemy dalej: utrata śladu jest zła, ale wycofanie
// utworzonego już w Stripie kodu byłoby gorsze.
func (s *Server) auditDiscountCode(
	ctx context.Context, caller adminCaller, codeID uuid.UUID,
	action, reason string, meta map[string]any,
) {
	payload := []byte("{}")
	if meta != nil {
		if b, err := json.Marshal(meta); err == nil {
			payload = b
		}
	}
	params := db.CreateBillingAuditEventParams{
		Action:       action,
		ResourceType: "discount_code",
		ResourceID:   pgtype.UUID{Bytes: codeID, Valid: true},
		Metadata:     payload,
		Reason:       &reason,
	}
	if caller.userID != nil {
		params.ActorUserID = pgtype.UUID{Bytes: *caller.userID, Valid: true}
	}
	if _, err := s.queries.CreateBillingAuditEvent(ctx, params); err != nil {
		s.logWarn(ctx, "audit: nie zapisano zdarzenia kodu rabatowego",
			"action", action, "code_id", codeID.String(), "error", err)
	}
}

func (s *Server) logWarn(ctx context.Context, msg string, args ...any) {
	slog.WarnContext(ctx, msg, args...)
}
