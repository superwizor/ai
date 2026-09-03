package grpc

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// storeFakeQuerier — lokalny nil-embed, żeby testy sklepowe nie
// rozbudowywały wspólnego fakeQuerier o pola, których reszta pakietu nie
// używa.
type storeFakeQuerier struct {
	db.Querier

	appConfig     map[string]string
	hasSeats      bool
	hasSeatsErr   error
	otherCheckout *db.GetOtherPendingCheckoutRow
}

func (f *storeFakeQuerier) GetGlobalAppConfig(_ context.Context, key string) (string, error) {
	if v, ok := f.appConfig[key]; ok {
		return v, nil
	}
	return "", pgx.ErrNoRows
}

func (f *storeFakeQuerier) OrgHasSeatAllocations(context.Context, uuid.UUID) (bool, error) {
	return f.hasSeats, f.hasSeatsErr
}

func (f *storeFakeQuerier) GetOtherPendingCheckout(context.Context, db.GetOtherPendingCheckoutParams) (db.GetOtherPendingCheckoutRow, error) {
	if f.otherCheckout == nil {
		return db.GetOtherPendingCheckoutRow{}, pgx.ErrNoRows
	}
	return *f.otherCheckout, nil
}

func TestMapStoreStatus(t *testing.T) {
	future := time.Now().Add(24 * time.Hour)
	cases := []struct {
		name           string
		state          StoreState
		wantStatus     string
		wantCancelFlag bool
	}{
		{
			name:       "aktywna odnawialna",
			state:      StoreState{Status: StoreStatusActive, AutoRenew: true},
			wantStatus: "ACTIVE",
		},
		{
			name:           "aktywna z wyłączonym odnawianiem = anulowana na koniec okresu",
			state:          StoreState{Status: StoreStatusActive, AutoRenew: false},
			wantStatus:     "ACTIVE",
			wantCancelFlag: true,
		},
		{
			name:       "grace period nadal daje dostęp",
			state:      StoreState{Status: StoreStatusGrace, AutoRenew: true, GraceUntil: &future},
			wantStatus: "ACTIVE",
		},
		{
			name:           "billing retry blokuje",
			state:          StoreState{Status: StoreStatusRetry},
			wantStatus:     "PAST_DUE",
			wantCancelFlag: true,
		},
		{
			name:           "pauza (Google) ma własny status",
			state:          StoreState{Status: StoreStatusPaused},
			wantStatus:     "PAUSED",
			wantCancelFlag: true,
		},
		{
			name:           "zwrot kończy subskrypcję",
			state:          StoreState{Status: StoreStatusRevoked},
			wantStatus:     "CANCELED",
			wantCancelFlag: true,
		},
		{
			name:           "wygaśnięcie kończy subskrypcję",
			state:          StoreState{Status: StoreStatusExpired},
			wantStatus:     "CANCELED",
			wantCancelFlag: true,
		},
		{
			// Nieznany stan NIE może zostać uznany za aktywny — ta sama
			// zasada co mapStripeSubStatus. Inaczej nowy stan sklepu
			// wprowadzony przez Apple'a nadawałby uprawnienie za darmo.
			name:       "nieznany stan nie nadaje uprawnienia",
			state:      StoreState{Status: "COŚ_NOWEGO"},
			wantStatus: "INCOMPLETE",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			gotStatus, gotCancel := mapStoreStatus(tc.state)
			if gotStatus != tc.wantStatus {
				t.Errorf("status = %q, chciano %q", gotStatus, tc.wantStatus)
			}
			if gotCancel != tc.wantCancelFlag {
				t.Errorf("cancel_at_period_end = %v, chciano %v", gotCancel, tc.wantCancelFlag)
			}
		})
	}
}

func TestPurchaseDecision(t *testing.T) {
	orgID := uuid.New()
	periodEnd := time.Now().Add(20 * 24 * time.Hour)
	activeSub := func(provider string) db.GetActiveSubscriptionByOrgRow {
		return db.GetActiveSubscriptionByOrgRow{
			ID:               uuid.New(),
			Provider:         db.PaymentProvider(provider),
			CurrentPeriodEnd: periodEnd,
		}
	}
	enabled := map[string]string{"IAP_ENABLED_IOS": "true", "IAP_ENABLED_ANDROID": "true"}

	cases := []struct {
		name        string
		q           *storeFakeQuerier
		provider    string
		hasSub      bool
		sub         db.GetActiveSubscriptionByOrgRow
		wantAllowed bool
		wantReason  string
	}{
		{
			// Domyślny stan po wdrożeniu: flagi wyłączone, więc paywall
			// nie sprzedaje, choćby wszystko inne było gotowe.
			name:       "flaga wyłączona blokuje sprzedaż",
			q:          &storeFakeQuerier{appConfig: map[string]string{}},
			provider:   providerApple,
			wantReason: "IAP_DISABLED",
		},
		{
			name:        "brak subskrypcji, flaga włączona — wolno kupić",
			q:           &storeFakeQuerier{appConfig: enabled},
			provider:    providerApple,
			wantAllowed: true,
		},
		{
			name:        "trial MANUAL ustępuje zakupowi",
			q:           &storeFakeQuerier{appConfig: enabled},
			provider:    providerApple,
			hasSub:      true,
			sub:         activeSub("MANUAL"),
			wantAllowed: true,
		},
		{
			name:       "aktywny Stripe blokuje zakup w aplikacji",
			q:          &storeFakeQuerier{appConfig: enabled},
			provider:   providerApple,
			hasSub:     true,
			sub:        activeSub("STRIPE"),
			wantReason: "OTHER_PROVIDER_ACTIVE",
		},
		{
			name:       "subskrypcja z drugiej platformy blokuje",
			q:          &storeFakeQuerier{appConfig: enabled},
			provider:   providerApple,
			hasSub:     true,
			sub:        activeSub(providerGoogle),
			wantReason: "OTHER_PROVIDER_ACTIVE",
		},
		{
			// Zmiana planu w obrębie tej samej platformy dzieje się w
			// sklepie — wpuszczamy, bo StoreKit/Play sam obsłuży upgrade.
			name:        "ta sama platforma — zmiana planu dozwolona",
			q:           &storeFakeQuerier{appConfig: enabled},
			provider:    providerApple,
			hasSub:      true,
			sub:         activeSub(providerApple),
			wantAllowed: true,
		},
		{
			// Klinika ma subskrypcję MANUAL wystawioną przez admina;
			// zakup terapeuty zderzyłby się z indeksem jednej aktywnej
			// subskrypcji na organizację i odebrał firmie plan.
			name:       "organizacja na miejscach nie widzi paywalla",
			q:          &storeFakeQuerier{appConfig: enabled, hasSeats: true},
			provider:   providerApple,
			hasSub:     true,
			sub:        activeSub("MANUAL"),
			wantReason: "ORG_MANAGED",
		},
		{
			name: "otwarty checkout w drugim kanale blokuje",
			q: &storeFakeQuerier{
				appConfig: enabled,
				otherCheckout: &db.GetOtherPendingCheckoutRow{
					Channel: "WEB", ExpiresAt: time.Now().Add(time.Hour),
				},
			},
			provider:   providerApple,
			wantReason: "PENDING_CHECKOUT",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			s := &Server{queries: tc.q}
			got := s.purchaseDecision(context.Background(), orgID, tc.provider, tc.hasSub, tc.sub)
			if got.allowed != tc.wantAllowed {
				t.Errorf("allowed = %v, chciano %v (reason %q)", got.allowed, tc.wantAllowed, got.reason)
			}
			if tc.wantReason != "" && got.reason != tc.wantReason {
				t.Errorf("reason = %q, chciano %q", got.reason, tc.wantReason)
			}
			if tc.wantReason == "OTHER_PROVIDER_ACTIVE" && got.blockedUntil == nil {
				t.Error("blokada z powodu innego dostawcy musi nieść datę końca okresu")
			}
		})
	}
}

func TestStoreProviderForPlatform(t *testing.T) {
	cases := map[string]string{
		"IOS":        providerApple,
		"ios":        providerApple,
		"ANDROID":    providerGoogle,
		"APPLE_IAP":  providerApple,
		"GOOGLE_IAP": providerGoogle,
		"WEB":        "",
		"":           "",
	}
	for in, want := range cases {
		if got := storeProviderForPlatform(in); got != want {
			t.Errorf("storeProviderForPlatform(%q) = %q, chciano %q", in, got, want)
		}
	}
}

func TestManageURL(t *testing.T) {
	product := "solo:monthly"
	if got := manageURL(providerApple, nil); got != "https://apps.apple.com/account/subscriptions" {
		t.Errorf("apple manage url = %q", got)
	}
	got := manageURL(providerGoogle, &product)
	if want := "https://play.google.com/store/account/subscriptions?package=ai.superwizor.superwizor&sku=solo"; got != want {
		t.Errorf("google manage url = %q, chciano %q", got, want)
	}
	// MANUAL to plan wystawiony przez organizację — nie ma czym zarządzać
	// z poziomu aplikacji.
	if got := manageURL("MANUAL", nil); got != "" {
		t.Errorf("manual manage url = %q, chciano pusty", got)
	}
}
