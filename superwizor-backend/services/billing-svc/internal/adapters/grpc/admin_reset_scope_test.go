package grpc

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// Dwie wady wykryte 2026-08-11 przy opisywaniu, jak reset działa dla
// organizacji z kilkoma terapeutami.
//
// 1. Karta użytkownika w panelu wołała reset obejmujący CAŁĄ organizację,
//    a powód zapisywany w audycie wymieniał jedną osobę. Operacja robiła
//    więcej, niż mówił jej ślad.
// 2. tokens_limit trafia wyłącznie do licznika organizacyjnego. Gdy go
//    nie było, wartość albo znikała bez śladu (sukces bez skutku), albo —
//    przy MANUAL — zakładała wiersz organizacyjny z wartością operatora.
//    To druga z tych ścieżek wyprodukowała 40 na planie 90.

// ─── 1. Zakres per-terapeuta ─────────────────────────────────────────

func TestAdminResetTokens_ScopedTouchesOnlyThatTherapist(t *testing.T) {
	org := uuid.New()
	terapeuta := uuid.New()
	sub := resetSub(org, db.PlanTierPRO, 90)

	q := &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		resetOneTherapistFn: func(_ context.Context, _ db.AdminResetSingleTherapistCounterParams) (int64, error) {
			return 1, nil
		},
		getActiveCounterFn: func(_ context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return db.UsageCounter{TokensUsed: 0, TokensLimit: 90}, nil
		},
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	_, err := s.AdminResetTokens(adminCtx(), &billingv1.AdminResetTokensRequest{
		OrganizationId: org.String(),
		TherapistId:    terapeuta.String(),
		TokensUsed:     0,
		TokensLimit:    -1,
		Reason:         "reset zuzycia dla jednego terapeuty",
	})
	if err != nil {
		t.Fatalf("nieoczekiwany błąd: %v", err)
	}

	// Sedno: wariant zbiorczy NIE mógł zostać wywołany.
	if len(q.resetOneCalls) != 1 {
		t.Fatalf("wywołań zawężonych = %d, oczekiwano 1", len(q.resetOneCalls))
	}
	if got := uuid.UUID(q.resetOneCalls[0].TherapistID.Bytes); got != terapeuta {
		t.Errorf("zresetowano %s, oczekiwano %s", got, terapeuta)
	}
	if len(q.auditCalls) == 0 {
		t.Fatal("brak wpisu audytowego")
	}
	meta := q.auditCalls[len(q.auditCalls)-1]
	if meta["scope"] != "therapist" {
		t.Errorf("audyt nie odnotował zakresu: %v", meta["scope"])
	}
	if meta["therapist_id"] != terapeuta.String() {
		t.Errorf("audyt bez therapist_id: %v", meta["therapist_id"])
	}
}

func TestAdminResetTokens_ScopedRejectsLimit(t *testing.T) {
	org := uuid.New()
	sub := resetSub(org, db.PlanTierPRO, 90)

	q := &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	_, err := s.AdminResetTokens(adminCtx(), &billingv1.AdminResetTokensRequest{
		OrganizationId: org.String(),
		TherapistId:    uuid.New().String(),
		TokensUsed:     0,
		TokensLimit:    120, // limit miejsca pochodzi z planu przydziału
		Reason:         "proba nadpisania limitu miejsca",
	})
	if status.Code(err) != codes.InvalidArgument {
		t.Fatalf("kod = %v, oczekiwano InvalidArgument", status.Code(err))
	}
	if !strings.Contains(err.Error(), "TOKENS_LIMIT_PER_SEAT") {
		t.Fatalf("brak stabilnego kodu w komunikacie: %q", err.Error())
	}
	if len(q.resetOneCalls) != 0 {
		t.Error("odrzucone żądanie nie może niczego dotknąć")
	}
}

func TestAdminResetTokens_ScopedMissingCounterIsNotSilentSuccess(t *testing.T) {
	org := uuid.New()
	sub := resetSub(org, db.PlanTierPRO, 90)

	q := &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		resetOneTherapistFn: func(_ context.Context, _ db.AdminResetSingleTherapistCounterParams) (int64, error) {
			return 0, nil // terapeuta bez licznika w tym okresie
		},
		hasSeatAllocFn: func(_ context.Context, _ uuid.UUID) (bool, error) {
			// Organizacja NA MIEJSCACH: brak licznika znaczy tu "nic jeszcze
			// nie zużył albo nie należy do tej subskrypcji". Zejście na całą
			// organizację wyzerowałoby wszystkich — właśnie ta wada.
			return true, nil
		},
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	_, err := s.AdminResetTokens(adminCtx(), &billingv1.AdminResetTokensRequest{
		OrganizationId: org.String(),
		TherapistId:    uuid.New().String(),
		TokensUsed:     0,
		TokensLimit:    -1,
		Reason:         "reset terapeuty bez licznika",
	})
	if status.Code(err) != codes.FailedPrecondition {
		t.Fatalf("kod = %v, oczekiwano FailedPrecondition", status.Code(err))
	}
	if !strings.Contains(err.Error(), "THERAPIST_COUNTER_MISSING") {
		t.Fatalf("komunikat: %q", err.Error())
	}
}

// Domyślny (pusty) therapist_id musi zachować dotychczasowe zachowanie —
// istniejące wywołania panelu i skrypty nie mogą się wywrócić.
func TestAdminResetTokens_EmptyScopeStaysOrgWide(t *testing.T) {
	org := uuid.New()
	sub := resetSub(org, db.PlanTierSOLO, 30)
	existing := db.UsageCounter{ID: uuid.New(), SubscriptionID: sub.ID, TokensLimit: 30}

	zbiorczy := 0
	q := &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		resetTherapistFn: func(_ context.Context, _ db.AdminResetTherapistCountersParams) (int64, error) {
			zbiorczy++
			return 3, nil
		},
		lockActiveCounterFn: func(_ context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return existing, nil
		},
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	_, err := s.AdminResetTokens(adminCtx(), &billingv1.AdminResetTokensRequest{
		OrganizationId: org.String(),
		TokensUsed:     0,
		TokensLimit:    -1,
		Reason:         "zbiorczy reset calej organizacji",
	})
	if err != nil {
		t.Fatalf("nieoczekiwany błąd: %v", err)
	}
	if zbiorczy != 1 {
		t.Errorf("wariant zbiorczy wywołany %d razy, oczekiwano 1", zbiorczy)
	}
	if len(q.resetOneCalls) != 0 {
		t.Error("bez therapist_id wariant zawężony nie może zostać użyty")
	}
}

// ─── 2. Limit wobec organizacji na miejscach ─────────────────────────

// Ścieżka, która wyprodukowała 40 na planie 90: MANUAL bez licznika
// organizacyjnego mintował wiersz z wartością operatora. Organizacja na
// miejscach nie powinna w ogóle dostać licznika organizacyjnego z ręki.
func TestAdminResetTokens_SeatOrgRejectsLimitInsteadOfMinting(t *testing.T) {
	org := uuid.New()
	sub := resetSub(org, db.PlanTierPRO, 90)

	q := &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		resetTherapistFn: func(_ context.Context, _ db.AdminResetTherapistCountersParams) (int64, error) {
			return 3, nil
		},
		lockActiveCounterFn: func(_ context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return db.UsageCounter{}, pgx.ErrNoRows // brak wiersza org-level
		},
		hasSeatAllocFn: func(_ context.Context, _ uuid.UUID) (bool, error) {
			return true, nil // organizacja rozlicza się przez miejsca
		},
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	_, err := s.AdminResetTokens(adminCtx(), &billingv1.AdminResetTokensRequest{
		OrganizationId: org.String(),
		TokensUsed:     -1,
		TokensLimit:    200, // powyżej planu, więc stary strażnik to przepuszczał
		Reason:         "proba ustawienia limitu organizacji na miejscach",
	})
	if status.Code(err) != codes.InvalidArgument {
		t.Fatalf("kod = %v, oczekiwano InvalidArgument", status.Code(err))
	}
	if !strings.Contains(err.Error(), "TOKENS_LIMIT_NOT_APPLICABLE") {
		t.Fatalf("komunikat: %q", err.Error())
	}
	if len(q.createCounterCalls) != 0 {
		t.Error("nie wolno założyć licznika organizacyjnego dla organizacji na miejscach")
	}
}

// Bez licznika organizacyjnego i bez mintu limit przepadał po cichu —
// operator dostawał sukces, a wartość nie trafiała nigdzie.
func TestAdminResetTokens_NoOrgCounterRejectsLimitInsteadOfSwallowing(t *testing.T) {
	org := uuid.New()
	sub := resetSub(org, db.PlanTierPRO, 90)
	sub.Provider = "STRIPE" // brak gałęzi mintującej

	q := &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		resetTherapistFn: func(_ context.Context, _ db.AdminResetTherapistCountersParams) (int64, error) {
			return 2, nil
		},
		lockActiveCounterFn: func(_ context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return db.UsageCounter{}, pgx.ErrNoRows
		},
		hasSeatAllocFn: func(_ context.Context, _ uuid.UUID) (bool, error) {
			return false, nil
		},
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	_, err := s.AdminResetTokens(adminCtx(), &billingv1.AdminResetTokensRequest{
		OrganizationId: org.String(),
		TokensUsed:     -1,
		TokensLimit:    120,
		Reason:         "limit bez licznika organizacyjnego",
	})
	if status.Code(err) != codes.InvalidArgument {
		t.Fatalf("kod = %v, oczekiwano InvalidArgument", status.Code(err))
	}
	if !strings.Contains(err.Error(), "TOKENS_LIMIT_NOT_APPLICABLE") {
		t.Fatalf("komunikat: %q", err.Error())
	}
}

// Reset samego zużycia (bez limitu) w organizacji na miejscach ma dalej
// działać — to najczęstsza operacja wsparcia.
func TestAdminResetTokens_SeatOrgUsageOnlyStillWorks(t *testing.T) {
	org := uuid.New()
	sub := resetSub(org, db.PlanTierPRO, 90)
	sub.Provider = "STRIPE"

	q := &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		resetTherapistFn: func(_ context.Context, _ db.AdminResetTherapistCountersParams) (int64, error) {
			return 3, nil
		},
		lockActiveCounterFn: func(_ context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return db.UsageCounter{}, pgx.ErrNoRows
		},
		sumActiveCountersFn: func(_ context.Context, _ uuid.UUID) (db.SumActiveCountersRow, error) {
			return db.SumActiveCountersRow{TokensUsed: 0, TokensLimit: 270, Counters: 3}, nil
		},
		getActiveCounterFn: func(_ context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return db.UsageCounter{}, pgx.ErrNoRows
		},
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	_, err := s.AdminResetTokens(adminCtx(), &billingv1.AdminResetTokensRequest{
		OrganizationId: org.String(),
		TokensUsed:     0,
		TokensLimit:    -1,
		Reason:         "wyzerowanie zuzycia calej organizacji",
	})
	if err != nil {
		t.Fatalf("reset samego zużycia odrzucony: %v", err)
	}
}

// Organizacja jednoosobowa nie ma liczników per-terapeuta — jej licznik
// organizacyjny JEST licznikiem tego terapeuty. Karta użytkownika musi
// tam dalej działać, a audyt ma powiedzieć, że zakres się rozszerzył.
func TestAdminResetTokens_ScopedFallsBackToOrgForSolo(t *testing.T) {
	org := uuid.New()
	terapeuta := uuid.New()
	sub := resetSub(org, db.PlanTierSOLO, 30)
	existing := db.UsageCounter{ID: uuid.New(), SubscriptionID: sub.ID, TokensLimit: 30, TokensUsed: 12}

	q := &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		resetOneTherapistFn: func(_ context.Context, _ db.AdminResetSingleTherapistCounterParams) (int64, error) {
			return 0, nil // solo: licznika per-terapeuta nie ma
		},
		hasSeatAllocFn: func(_ context.Context, _ uuid.UUID) (bool, error) {
			return false, nil // i nie ma przydziałów miejsc
		},
		resetTherapistFn: func(_ context.Context, _ db.AdminResetTherapistCountersParams) (int64, error) {
			return 0, nil
		},
		lockActiveCounterFn: func(_ context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return existing, nil
		},
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	_, err := s.AdminResetTokens(adminCtx(), &billingv1.AdminResetTokensRequest{
		OrganizationId: org.String(),
		TherapistId:    terapeuta.String(),
		TokensUsed:     0,
		TokensLimit:    -1,
		Reason:         "reset zuzycia terapeuty solo",
	})
	if err != nil {
		t.Fatalf("reset w organizacji jednoosobowej odrzucony: %v", err)
	}
	meta := q.auditCalls[len(q.auditCalls)-1]
	if meta["scope"] != "organization_fallback" {
		t.Errorf("audyt nie odnotował zejścia na zakres organizacji: %v", meta["scope"])
	}
	if meta["therapist_id"] != terapeuta.String() {
		t.Errorf("audyt bez therapist_id: %v", meta["therapist_id"])
	}
}
