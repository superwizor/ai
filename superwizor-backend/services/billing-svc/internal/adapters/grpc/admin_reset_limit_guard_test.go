package grpc

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// Dochodzenie 2026-08-01: organizacja na planie PRO Monthly (90 sesji)
// pokazywała limit 40 — wartość spoza katalogu planów.
//
// Źródłem był AdminResetTokens z reason "testujemy czy dziala".
// Subskrypcja B2B nie miała wiersza org-level (poprawnie — to
// organizacja na miejscach), więc gałąź mintująca założyła go z
// wartością operatora, poniżej planu, na cały okres rozliczeniowy.
// Walidacja wejścia sprawdzała tylko tokens_limit > 0, bo plan jest
// znany dopiero po załadowaniu subskrypcji.
//
// Ślad audytu tego nie pokazywał: metadane raportowały
// "tokens_limit_before" z wiersza DOPIERO CO wstawionego, więc zapis
// brzmiał "before=40, after=40" i wyglądał jak reset bez zmian.

func resetSub(orgID uuid.UUID, tier db.PlanTier, planTokens int32) db.GetActiveSubscriptionByOrgRow {
	return db.GetActiveSubscriptionByOrgRow{
		ID:                  uuid.New(),
		OrganizationID:      orgID,
		Status:              db.SubscriptionStatusACTIVE,
		Provider:            "MANUAL",
		CurrentPeriodStart:  time.Now().Add(-time.Hour),
		CurrentPeriodEnd:    time.Now().Add(29 * 24 * time.Hour),
		PlanTier:            tier,
		PlanCycle:           "MONTHLY",
		PlanTokensPerPeriod: planTokens,
	}
}

func TestAdminResetTokens_RejectsLimitBelowPlan(t *testing.T) {
	org := uuid.New()
	sub := resetSub(org, db.PlanTierPRO, 90)

	q := &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		// Nic poniżej nie powinno zostać dotknięte — walidacja wypada
		// przed advisory lockiem i przed resetem liczników.
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	_, err := s.AdminResetTokens(adminCtx(), &billingv1.AdminResetTokensRequest{
		OrganizationId: org.String(),
		TokensUsed:     -1,
		TokensLimit:    40, // dokładnie ta wartość, która trafiła na produkcję
		Reason:         "testujemy czy dziala",
	})
	if status.Code(err) != codes.InvalidArgument {
		t.Fatalf("kod = %v, oczekiwano InvalidArgument (40 < plan 90)", status.Code(err))
	}
}

// Nadania POWYŻEJ planu są świadome i mają uzasadnienie handlowe —
// reguła nie może ich blokować.
func TestAdminResetTokens_AllowsLimitAbovePlan(t *testing.T) {
	org := uuid.New()
	sub := resetSub(org, db.PlanTierSOLO, 30)
	existing := db.UsageCounter{ID: uuid.New(), SubscriptionID: sub.ID, TokensLimit: 30}

	q := &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		lockActiveCounterFn: func(_ context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return existing, nil
		},
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	_, err := s.AdminResetTokens(adminCtx(), &billingv1.AdminResetTokensRequest{
		OrganizationId: org.String(),
		TokensUsed:     -1,
		TokensLimit:    50,
		Reason:         "ustalenia handlowe z klientem",
	})
	if status.Code(err) == codes.InvalidArgument {
		t.Fatalf("nadanie powyżej planu zostało odrzucone: %v", err)
	}
}

// TRIAL musi zostać przepuszczony: liczniki próbne chodzą z realnym
// progiem (3-5), a wiersz TRIAL w katalogu niesie 10 — tam nieaktualny
// jest katalog, nie licznik.
func TestAdminResetTokens_TrialBelowCatalogStillAllowed(t *testing.T) {
	org := uuid.New()
	sub := resetSub(org, db.PlanTierTRIAL, 10)
	existing := db.UsageCounter{ID: uuid.New(), SubscriptionID: sub.ID, TokensLimit: 5}

	q := &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		lockActiveCounterFn: func(_ context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return existing, nil
		},
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	_, err := s.AdminResetTokens(adminCtx(), &billingv1.AdminResetTokensRequest{
		OrganizationId: org.String(),
		TokensUsed:     0,
		TokensLimit:    5,
		Reason:         "reset triala po teście",
	})
	if status.Code(err) == codes.InvalidArgument {
		t.Fatalf("reset triala odrzucony: %v", err)
	}
}

// Audyt nie może opisywać świeżo wstawionego wiersza jako stanu
// sprzed operacji.
func TestAdminResetTokens_MintedCounterAuditHasNoBefore(t *testing.T) {
	org := uuid.New()
	sub := resetSub(org, db.PlanTierPRO, 90)

	q := &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		lockActiveCounterFn: func(_ context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return db.UsageCounter{}, pgx.ErrNoRows // brak wiersza org-level
		},
		createCounterFn: func(_ context.Context, arg db.CreateUsageCounterParams) (db.UsageCounter, error) {
			return db.UsageCounter{
				ID: uuid.New(), SubscriptionID: arg.SubscriptionID,
				TokensLimit: arg.TokensLimit,
			}, nil
		},
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	// Limit >= planu, żeby przejść nową walidację i dotrzeć do mintu.
	_, err := s.AdminResetTokens(adminCtx(), &billingv1.AdminResetTokensRequest{
		OrganizationId: org.String(),
		TokensUsed:     -1,
		TokensLimit:    90,
		Reason:         "zalozenie licznika organizacyjnego",
	})
	if err != nil {
		t.Fatalf("nieoczekiwany błąd: %v", err)
	}
	if len(q.auditCalls) == 0 {
		t.Fatal("brak wpisu audytowego")
	}
	meta := q.auditCalls[len(q.auditCalls)-1]
	if _, has := meta["tokens_limit_before"]; has {
		t.Error("audyt mintu nie może zawierać tokens_limit_before — wiersza nie było")
	}
	if minted, _ := meta["org_counter_minted"].(bool); !minted {
		t.Error("audyt mintu musi nieść org_counter_minted=true")
	}
}
