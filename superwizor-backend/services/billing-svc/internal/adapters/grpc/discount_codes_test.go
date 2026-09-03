package grpc

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/metadata"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// discountFakeQuerier — nil-embed z metodami tylko dla ścieżki wyceny.
type discountFakeQuerier struct {
	db.Querier

	plan        db.SubscriptionPlan
	planErr     error
	code        *db.DiscountCode
	codeErr     error
	redemption  *db.DiscountCodeRedemption
	committed   int64
	paidHistory bool
}

func (f *discountFakeQuerier) AdminGetPlanByTierCycle(context.Context, db.AdminGetPlanByTierCycleParams) (db.SubscriptionPlan, error) {
	return f.plan, f.planErr
}

func (f *discountFakeQuerier) GetDiscountCodeByCode(context.Context, string) (db.DiscountCode, error) {
	if f.code == nil {
		return db.DiscountCode{}, pgx.ErrNoRows
	}
	return *f.code, f.codeErr
}

func (f *discountFakeQuerier) GetRedemptionForOrg(context.Context, db.GetRedemptionForOrgParams) (db.DiscountCodeRedemption, error) {
	if f.redemption == nil {
		return db.DiscountCodeRedemption{}, pgx.ErrNoRows
	}
	return *f.redemption, nil
}

func (f *discountFakeQuerier) CountCommittedRedemptions(context.Context, uuid.UUID) (int64, error) {
	return f.committed, nil
}

func (f *discountFakeQuerier) OrgHasPaidSubscriptionHistory(context.Context, uuid.UUID) (bool, error) {
	return f.paidHistory, nil
}

func numeric(t *testing.T, v string) pgtype.Numeric {
	t.Helper()
	var n pgtype.Numeric
	if err := n.Scan(v); err != nil {
		t.Fatalf("numeric(%q): %v", v, err)
	}
	return n
}

func callerCtx(orgID uuid.UUID) context.Context {
	return metadata.NewIncomingContext(context.Background(), metadata.Pairs(
		"x-superwizor-role", "THERAPIST",
		"x-superwizor-user-id", uuid.NewString(),
		"x-superwizor-organization-id", orgID.String(),
	))
}

func validCode(t *testing.T) *db.DiscountCode {
	t.Helper()
	return &db.DiscountCode{
		ID:             uuid.New(),
		Code:           "PIONIER33",
		Name:           "Wcześni użytkownicy",
		PercentOff:     numeric(t, "33.00"),
		Duration:       "FOREVER",
		ValidFrom:      time.Now().Add(-24 * time.Hour),
		ValidUntil:     time.Now().Add(30 * 24 * time.Hour),
		MaxRedemptions: 100,
		Channels:       []string{"WEB"},
		IsActive:       true,
	}
}

func TestValidateDiscountCode(t *testing.T) {
	orgID := uuid.New()
	plan := db.SubscriptionPlan{
		ID:           uuid.New(),
		Tier:         db.PlanTierSOLO,
		Cycle:        db.BillingCycleMONTHLY,
		PriceGross:   numeric(t, "149.00"),
		CurrencyCode: "PLN",
	}

	t.Run("poprawny kod wycenia rabat", func(t *testing.T) {
		q := &discountFakeQuerier{plan: plan, code: validCode(t)}
		s := &Server{queries: q}
		got, err := s.ValidateDiscountCode(callerCtx(orgID), &billingv1.ValidateDiscountCodeRequest{
			Code: "pionier33", PlanTier: "SOLO", PlanCycle: "MONTHLY",
		})
		if err != nil {
			t.Fatalf("ValidateDiscountCode: %v", err)
		}
		if !got.Valid || got.Reason != quoteOK {
			t.Fatalf("valid=%v reason=%q", got.Valid, got.Reason)
		}
		// 149 zł − 33% = 99,83 zł. Wycena musi zgadzać się z tym, co
		// naliczy Stripe, bo użytkownik widzi ją PRZED płatnością.
		if got.PriceBefore != "149.00" || got.PriceAfter != "99.83" {
			t.Errorf("cena przed=%q po=%q, chciano 149.00 / 99.83", got.PriceBefore, got.PriceAfter)
		}
		if got.RedemptionsLeft != 100 {
			t.Errorf("pozostałe użycia = %d, chciano 100", got.RedemptionsLeft)
		}
	})

	t.Run("wygasły kod", func(t *testing.T) {
		code := validCode(t)
		code.ValidUntil = time.Now().Add(-time.Hour)
		q := &discountFakeQuerier{plan: plan, code: code}
		s := &Server{queries: q}
		got, _ := s.ValidateDiscountCode(callerCtx(orgID), &billingv1.ValidateDiscountCodeRequest{
			Code: "PIONIER33", PlanTier: "SOLO", PlanCycle: "MONTHLY",
		})
		if got.Valid || got.Reason != quoteExpired {
			t.Errorf("valid=%v reason=%q, chciano EXPIRED", got.Valid, got.Reason)
		}
	})

	t.Run("kod dezaktywowany", func(t *testing.T) {
		code := validCode(t)
		code.IsActive = false
		s := &Server{queries: &discountFakeQuerier{plan: plan, code: code}}
		got, _ := s.ValidateDiscountCode(callerCtx(orgID), &billingv1.ValidateDiscountCodeRequest{
			Code: "PIONIER33", PlanTier: "SOLO", PlanCycle: "MONTHLY",
		})
		if got.Reason != quoteInactive {
			t.Errorf("reason=%q, chciano INACTIVE", got.Reason)
		}
	})

	t.Run("kod zawężony do innego planu", func(t *testing.T) {
		code := validCode(t)
		code.AppliesToTiers = []string{"PRO"}
		s := &Server{queries: &discountFakeQuerier{plan: plan, code: code}}
		got, _ := s.ValidateDiscountCode(callerCtx(orgID), &billingv1.ValidateDiscountCodeRequest{
			Code: "PIONIER33", PlanTier: "SOLO", PlanCycle: "MONTHLY",
		})
		if got.Reason != quotePlanNotEligible {
			t.Errorf("reason=%q, chciano PLAN_NOT_ELIGIBLE", got.Reason)
		}
	})

	t.Run("kod tylko na web, pytanie ze sklepu", func(t *testing.T) {
		s := &Server{queries: &discountFakeQuerier{plan: plan, code: validCode(t)}}
		got, _ := s.ValidateDiscountCode(callerCtx(orgID), &billingv1.ValidateDiscountCodeRequest{
			Code: "PIONIER33", PlanTier: "SOLO", PlanCycle: "MONTHLY", Channel: "APPLE",
		})
		if got.Reason != quoteChannelNotElig {
			t.Errorf("reason=%q, chciano CHANNEL_NOT_ELIGIBLE", got.Reason)
		}
	})

	t.Run("organizacja już użyła kodu", func(t *testing.T) {
		q := &discountFakeQuerier{
			plan: plan, code: validCode(t),
			redemption: &db.DiscountCodeRedemption{Status: "COMMITTED"},
		}
		s := &Server{queries: q}
		got, _ := s.ValidateDiscountCode(callerCtx(orgID), &billingv1.ValidateDiscountCodeRequest{
			Code: "PIONIER33", PlanTier: "SOLO", PlanCycle: "MONTHLY",
		})
		if got.Reason != quoteAlreadyUsed {
			t.Errorf("reason=%q, chciano ALREADY_USED", got.Reason)
		}
	})

	t.Run("zwolniona rezerwacja nie blokuje ponownej próby", func(t *testing.T) {
		// Porzucony checkout zwalnia rezerwację; użytkownik musi móc
		// wejść w płatność jeszcze raz tym samym kodem.
		q := &discountFakeQuerier{
			plan: plan, code: validCode(t),
			redemption: &db.DiscountCodeRedemption{Status: "RELEASED"},
		}
		s := &Server{queries: q}
		got, _ := s.ValidateDiscountCode(callerCtx(orgID), &billingv1.ValidateDiscountCodeRequest{
			Code: "PIONIER33", PlanTier: "SOLO", PlanCycle: "MONTHLY",
		})
		if !got.Valid {
			t.Errorf("valid=false reason=%q — zwolniona rezerwacja nie powinna blokować", got.Reason)
		}
	})

	t.Run("limit wyczerpany", func(t *testing.T) {
		code := validCode(t)
		code.MaxRedemptions = 5
		s := &Server{queries: &discountFakeQuerier{plan: plan, code: code, committed: 5}}
		got, _ := s.ValidateDiscountCode(callerCtx(orgID), &billingv1.ValidateDiscountCodeRequest{
			Code: "PIONIER33", PlanTier: "SOLO", PlanCycle: "MONTHLY",
		})
		if got.Reason != quoteExhausted {
			t.Errorf("reason=%q, chciano EXHAUSTED", got.Reason)
		}
	})

	t.Run("tylko dla nowych klientów", func(t *testing.T) {
		code := validCode(t)
		code.NewCustomersOnly = true
		s := &Server{queries: &discountFakeQuerier{plan: plan, code: code, paidHistory: true}}
		got, _ := s.ValidateDiscountCode(callerCtx(orgID), &billingv1.ValidateDiscountCodeRequest{
			Code: "PIONIER33", PlanTier: "SOLO", PlanCycle: "MONTHLY",
		})
		if got.Reason != quoteNewCustomersOnly {
			t.Errorf("reason=%q, chciano NEW_CUSTOMERS_ONLY", got.Reason)
		}
	})

	t.Run("nieznany kod bez Stripe'a to NOT_FOUND", func(t *testing.T) {
		s := &Server{queries: &discountFakeQuerier{plan: plan}}
		got, _ := s.ValidateDiscountCode(callerCtx(orgID), &billingv1.ValidateDiscountCodeRequest{
			Code: "NIEISTNIEJE", PlanTier: "SOLO", PlanCycle: "MONTHLY",
		})
		if got.Valid || got.Reason != quoteNotFound {
			t.Errorf("valid=%v reason=%q, chciano NOT_FOUND", got.Valid, got.Reason)
		}
	})

	t.Run("bez organizacji w kontekście — odmowa", func(t *testing.T) {
		s := &Server{queries: &discountFakeQuerier{plan: plan}}
		if _, err := s.ValidateDiscountCode(context.Background(), &billingv1.ValidateDiscountCodeRequest{
			Code: "PIONIER33", PlanTier: "SOLO", PlanCycle: "MONTHLY",
		}); err == nil {
			t.Error("oczekiwano błędu Unauthenticated dla wywołania bez organizacji")
		}
	})
}

func TestDiscountCodeValidationHelpers(t *testing.T) {
	t.Run("format kodu", func(t *testing.T) {
		valid := []string{"ABC", "PIONIER33", "ROWNOWAGA_ROK"}
		invalid := []string{"ab", "kod z spacja", "ŁADNY", "toojlongtoolongtoolongtoolongtoolong"}
		for _, v := range valid {
			if !discountCodeRE.MatchString(v) {
				t.Errorf("%q powinno być poprawne", v)
			}
		}
		for _, v := range invalid {
			if discountCodeRE.MatchString(v) {
				t.Errorf("%q nie powinno przejść walidacji", v)
			}
		}
	})

	t.Run("procent poza zakresem", func(t *testing.T) {
		for _, v := range []string{"0", "-5", "100.5", "abc", ""} {
			if _, err := parsePercent(v); err == nil {
				t.Errorf("parsePercent(%q) powinno zwrócić błąd", v)
			}
		}
		if got, err := parsePercent("33.5"); err != nil || got != 33.5 {
			t.Errorf("parsePercent(33.5) = %v, %v", got, err)
		}
	})

	t.Run("kanały domyślnie WEB", func(t *testing.T) {
		if got := normalizeChannels(nil); len(got) != 1 || got[0] != "WEB" {
			t.Errorf("normalizeChannels(nil) = %v", got)
		}
		if got := normalizeChannels([]string{"apple", "APPLE", "śmieć"}); len(got) != 1 || got[0] != "APPLE" {
			t.Errorf("normalizeChannels odfiltrowuje duplikaty i śmieci: %v", got)
		}
	})

	t.Run("puste zawężenie znaczy brak ograniczeń", func(t *testing.T) {
		if !planAllowed(nil, "SOLO") {
			t.Error("pusta lista planów powinna przepuszczać wszystko")
		}
		if planAllowed([]string{"PRO"}, "SOLO") {
			t.Error("zawężenie do PRO nie powinno przepuszczać SOLO")
		}
	})
}
