package grpc

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// Zgłoszone 2026-08-03: modal zmiany planu obiecywał "Nowy okres
// rozliczeniowy startuje teraz", a backend nie dotykał
// current_period_end. AdminChangeSubscriptionPlan aktualizuje wyłącznie
// plan_id i updated_at, a ShiftSubscriptionPeriod miał tylko dwóch
// wywołujących: webhook Stripe'a i cron odnowienia.
//
// Rozstrzygnięcie jest różne dla dwóch rodzajów subskrypcji, dlatego
// testy pilnują OBU stron rozgałęzienia — pomylenie ich jest tu
// łatwiejsze niż niezaimplementowanie czegokolwiek.

func planSub(orgID uuid.UUID, provider db.PaymentProvider) db.GetActiveSubscriptionByOrgRow {
	return db.GetActiveSubscriptionByOrgRow{
		ID:                  uuid.New(),
		OrganizationID:      orgID,
		Status:              db.SubscriptionStatusACTIVE,
		Provider:            provider,
		CurrentPeriodStart:  time.Now().Add(-20 * 24 * time.Hour),
		CurrentPeriodEnd:    time.Now().Add(10 * 24 * time.Hour),
		PlanTier:            db.PlanTierSOLO,
		PlanCycle:           db.BillingCycleMONTHLY,
		PlanTokensPerPeriod: 30,
	}
}

func planChangeQuerier(sub db.GetActiveSubscriptionByOrgRow, newTokens int32, cycle db.BillingCycle) *fakeQuerier {
	existing := db.UsageCounter{
		ID: uuid.New(), SubscriptionID: sub.ID,
		TokensLimit: sub.PlanTokensPerPeriod, TokensUsed: 7,
		PeriodStart: sub.CurrentPeriodStart, PeriodEnd: sub.CurrentPeriodEnd,
	}
	return &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		adminGetPlanFn: func(_ context.Context, _ db.AdminGetPlanByTierCycleParams) (db.SubscriptionPlan, error) {
			return db.SubscriptionPlan{ID: uuid.New(), TokensPerPeriod: newTokens, Cycle: cycle}, nil
		},
		adminChangePlanFn: func(_ context.Context, _ db.AdminChangeSubscriptionPlanParams) (db.Subscription, error) {
			return db.Subscription{ID: sub.ID}, nil
		},
		lockActiveCounterFn: func(_ context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return existing, nil
		},
		adminUpdateCounterFn: func(_ context.Context, arg db.AdminUpdateCounterParams) (db.UsageCounter, error) {
			out := existing
			if arg.TokensLimit != nil {
				out.TokensLimit = *arg.TokensLimit
			}
			return out, nil
		},
	}
}

func changePlan(t *testing.T, q *fakeQuerier, org uuid.UUID) error {
	t.Helper()
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)
	_, err := s.AdminChangePlan(adminCtx(), &billingv1.AdminChangePlanRequest{
		OrganizationId: org.String(),
		PlanTier:       "PRO",
		PlanCycle:      "MONTHLY",
		Reason:         "zmiana planu na wniosek klienta",
	})
	return err
}

// MANUAL: nie ma zewnętrznego źródła prawdy dla okresu, więc obietnica
// modala musi zostać dotrzymana.
func TestAdminChangePlan_Manual_RestartsPeriod(t *testing.T) {
	org := uuid.New()
	sub := planSub(org, "MANUAL")
	q := planChangeQuerier(sub, 90, db.BillingCycleMONTHLY)

	if err := changePlan(t, q, org); err != nil {
		t.Fatalf("nieoczekiwany błąd: %v", err)
	}
	if len(q.shiftPeriodCalls) != 1 {
		t.Fatalf("okres nie został przesunięty (wywołań=%d)", len(q.shiftPeriodCalls))
	}
	got := q.shiftPeriodCalls[0]
	if !got.CurrentPeriodEnd.After(got.CurrentPeriodStart) {
		t.Error("koniec okresu musi być po jego początku")
	}
	if got.CurrentPeriodEnd.Before(time.Now().AddDate(0, 0, 27)) {
		t.Errorf("okres miesięczny za krótki: %v", got.CurrentPeriodEnd)
	}
	if len(q.createCounterCalls) != 1 {
		t.Fatalf("nowy okres musi dostać własny licznik (wywołań=%d)", len(q.createCounterCalls))
	}
	if q.createCounterCalls[0].TokensLimit != 90 {
		t.Errorf("nowy licznik ma limit %d, oczekiwano 90 (z nowego planu)",
			q.createCounterCalls[0].TokensLimit)
	}
}

// Domknięcie starych liczników musi poprzedzać utworzenie nowego —
// inaczej przez resztę starego okresu dwa wiersze naraz spełniają
// predykat aktywności, a GetActiveCounter jest zapytaniem :one.
func TestAdminChangePlan_Manual_ClosesOldCountersBeforeCreating(t *testing.T) {
	org := uuid.New()
	sub := planSub(org, "MANUAL")
	q := planChangeQuerier(sub, 90, db.BillingCycleMONTHLY)

	if err := changePlan(t, q, org); err != nil {
		t.Fatalf("nieoczekiwany błąd: %v", err)
	}
	if len(q.closeCountersCalls) != 1 {
		t.Fatalf("stare liczniki nie zostały domknięte (wywołań=%d)", len(q.closeCountersCalls))
	}
	if q.closeCountersCalls[0] != sub.ID {
		t.Error("domknięto liczniki niewłaściwej subskrypcji")
	}
}

// Cykl roczny nie może dostać miesięcznego okresu.
func TestAdminChangePlan_Manual_AnnualCycleGetsYearLongPeriod(t *testing.T) {
	org := uuid.New()
	sub := planSub(org, "MANUAL")
	q := planChangeQuerier(sub, 1080, db.BillingCycleANNUAL)

	if err := changePlan(t, q, org); err != nil {
		t.Fatalf("nieoczekiwany błąd: %v", err)
	}
	if len(q.shiftPeriodCalls) != 1 {
		t.Fatal("okres nie został przesunięty")
	}
	end := q.shiftPeriodCalls[0].CurrentPeriodEnd
	if end.Before(time.Now().AddDate(0, 11, 0)) {
		t.Errorf("plan roczny dostał okres kończący się %v — za krótki", end)
	}
}

// STRIPE: okres należy do Stripe'a. Przesunięcie go tutaj rozjechałoby
// datę odnowienia z faktycznym obciążeniem karty i tak czy owak
// zostałoby nadpisane przy customer.subscription.updated.
func TestAdminChangePlan_Stripe_LeavesPeriodAlone(t *testing.T) {
	org := uuid.New()
	sub := planSub(org, "STRIPE")
	q := planChangeQuerier(sub, 90, db.BillingCycleMONTHLY)

	if err := changePlan(t, q, org); err != nil {
		t.Fatalf("nieoczekiwany błąd: %v", err)
	}
	if len(q.shiftPeriodCalls) != 0 {
		t.Errorf("okres subskrypcji Stripe został przesunięty (%d wywołań) — to rozjeżdża odnowienie z obciążeniem karty",
			len(q.shiftPeriodCalls))
	}
	if len(q.closeCountersCalls) != 0 {
		t.Errorf("liczniki Stripe zostały domknięte (%d wywołań) — zużycie musi zostać", len(q.closeCountersCalls))
	}
	if len(q.createCounterCalls) != 0 {
		t.Errorf("dla Stripe nie tworzymy nowego licznika (%d wywołań)", len(q.createCounterCalls))
	}
}

// Limit z nowego planu obowiązuje w OBU wariantach — to jest niezmiennik.
func TestAdminChangePlan_BothProviders_ApplyNewLimit(t *testing.T) {
	for _, provider := range []db.PaymentProvider{"MANUAL", "STRIPE"} {
		org := uuid.New()
		sub := planSub(org, provider)
		q := planChangeQuerier(sub, 90, db.BillingCycleMONTHLY)

		// Limit ze ścieżki Stripe'a przechwytujemy tu — atrapa nie
		// rejestruje wywołań AdminUpdateCounter.
		var stripeLimit int32
		base := q.adminUpdateCounterFn
		q.adminUpdateCounterFn = func(ctx context.Context, arg db.AdminUpdateCounterParams) (db.UsageCounter, error) {
			if arg.TokensLimit != nil {
				stripeLimit = *arg.TokensLimit
			}
			return base(ctx, arg)
		}

		if err := changePlan(t, q, org); err != nil {
			t.Fatalf("[%s] nieoczekiwany błąd: %v", provider, err)
		}
		limit := stripeLimit
		if provider == "MANUAL" {
			limit = q.createCounterCalls[0].TokensLimit
		}
		if limit != 90 {
			t.Errorf("[%s] limit = %d, oczekiwano 90", provider, limit)
		}
	}
}
