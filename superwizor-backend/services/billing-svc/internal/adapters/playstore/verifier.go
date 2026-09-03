// Package playstore weryfikuje subskrypcje Google Play przez Play
// Developer API (purchases.subscriptionsv2).
//
// docs/70 §7.3. W odróżnieniu od Apple'a nie ma tu podpisu do sprawdzenia
// lokalnie: purchaseToken sam w sobie niczego nie dowodzi, dowodem jest
// dopiero odpowiedź Google'a. Dlatego KAŻDA weryfikacja to wyjście do
// API — nie da się tego zrobić offline i nie należy próbować.
//
// Uwierzytelnienie: Application Default Credentials z zakresem
// androidpublisher. Na Cloud Run to konto usługi billing-svc; w Play
// Console musi mieć uprawnienie „Zarządzanie zamówieniami i
// subskrypcjami" dla ai.superwizor.superwizor (tak samo jak
// google-play-deployer@ ma „Kierownik wydań" — patrz docs/40 §2.12).
package playstore

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	androidpublisher "google.golang.org/api/androidpublisher/v3"
	"google.golang.org/api/option"

	billinggrpc "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/grpc"
)

// Verifier implementuje grpc.StoreVerifier dla Google Play.
type Verifier struct {
	packageName string
	svc         *androidpublisher.Service
}

// New tworzy weryfikator na domyślnych poświadczeniach.
func New(ctx context.Context, packageName string, opts ...option.ClientOption) (*Verifier, error) {
	if strings.TrimSpace(packageName) == "" {
		return nil, errors.New("PLAY_PACKAGE_NAME wymagany")
	}
	opts = append([]option.ClientOption{
		option.WithScopes(androidpublisher.AndroidpublisherScope),
	}, opts...)
	svc, err := androidpublisher.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("android publisher: %w", err)
	}
	return &Verifier{packageName: packageName, svc: svc}, nil
}

func (v *Verifier) VerifyPurchase(ctx context.Context, proof billinggrpc.StoreProof) (billinggrpc.StoreState, error) {
	if strings.TrimSpace(proof.PurchaseToken) == "" {
		return billinggrpc.StoreState{}, errors.New("brak purchase_token")
	}
	return v.FetchState(ctx, proof.PurchaseToken, proof.ProductID)
}

// FetchState pyta Google o stan subskrypcji spod purchaseToken.
func (v *Verifier) FetchState(ctx context.Context, purchaseToken, fallbackProductID string) (billinggrpc.StoreState, error) {
	var out billinggrpc.StoreState
	resp, err := v.svc.Purchases.Subscriptionsv2.
		Get(v.packageName, purchaseToken).
		Context(ctx).
		Do()
	if err != nil {
		return out, fmt.Errorf("play subscriptionsv2.get: %w", err)
	}

	raw, _ := json.Marshal(resp)
	out = billinggrpc.StoreState{
		Provider: "GOOGLE_IAP",
		// Google nie ma odpowiednika originalTransactionId. Kluczem
		// łańcucha jest purchaseToken: przy wznowieniu subskrypcji token
		// jest nowy, a poprzedni wskazuje linkedPurchaseToken — stary
		// wiersz jest wtedy już EXPIRED, więc częściowy indeks
		// jedno-aktywnej-subskrypcji na to pozwala.
		OriginalTransactionID: purchaseToken,
		TransactionID:         firstNonEmpty(resp.LatestOrderId, purchaseToken),
		ProductID:             fallbackProductID,
		Environment:           "Production",
		Raw:                   raw,
	}
	if resp.TestPurchase != nil {
		out.Environment = "Sandbox"
	}
	if resp.ExternalAccountIdentifiers != nil {
		out.AppAccountToken = resp.ExternalAccountIdentifiers.ObfuscatedExternalAccountId
	}
	out.PurchaseDate = parseRFC3339(resp.StartTime)

	if len(resp.LineItems) > 0 {
		li := resp.LineItems[0]
		out.ExpiresDate = parseRFC3339(li.ExpiryTime)
		if li.AutoRenewingPlan != nil {
			out.AutoRenew = li.AutoRenewingPlan.AutoRenewEnabled
		}
		if li.OfferDetails != nil {
			// Nasz identyfikator produktu to "subskrypcja:planBazowy" —
			// tak samo, jak siedzi w subscription_plans.google_product_id.
			if li.ProductId != "" && li.OfferDetails.BasePlanId != "" {
				out.ProductID = li.ProductId + ":" + li.OfferDetails.BasePlanId
			}
			out.OfferIdentifier = li.OfferDetails.OfferId
		} else if li.ProductId != "" {
			out.ProductID = li.ProductId
		}
	}
	if out.PurchaseDate.IsZero() {
		out.PurchaseDate = time.Now()
	}

	switch resp.SubscriptionState {
	case "SUBSCRIPTION_STATE_ACTIVE":
		out.Status = billinggrpc.StoreStatusActive
	case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
		out.Status = billinggrpc.StoreStatusGrace
		// W grace period expiryTime jest końcem okna łaski — dostęp trwa
		// do tej chwili, ale nowej puli tokenów nie ma (docs/70 E13).
		if !out.ExpiresDate.IsZero() {
			g := out.ExpiresDate
			out.GraceUntil = &g
		}
	case "SUBSCRIPTION_STATE_ON_HOLD", "SUBSCRIPTION_STATE_PENDING":
		out.Status = billinggrpc.StoreStatusRetry
	case "SUBSCRIPTION_STATE_PAUSED":
		out.Status = billinggrpc.StoreStatusPaused
	case "SUBSCRIPTION_STATE_CANCELED":
		// „Canceled" u Google znaczy „nie odnowi się", a nie „już nie
		// działa" — dostęp trwa do końca opłaconego okresu.
		out.AutoRenew = false
		if !out.ExpiresDate.IsZero() && out.ExpiresDate.After(time.Now()) {
			out.Status = billinggrpc.StoreStatusActive
		} else {
			out.Status = billinggrpc.StoreStatusExpired
		}
	case "SUBSCRIPTION_STATE_EXPIRED":
		out.Status = billinggrpc.StoreStatusExpired
	default:
		// Nieznany stan zostawiamy pusty: applyStoreState zapisze wtedy
		// INCOMPLETE, zamiast zgadywać uprawnienie.
	}
	return out, nil
}

// Acknowledge potwierdza zakup. Google zwraca pieniądze automatycznie,
// jeśli nie zrobimy tego w 3 dni — dlatego wołamy to zaraz po zapisaniu
// uprawnienia, a nie przed.
func (v *Verifier) Acknowledge(ctx context.Context, st billinggrpc.StoreState) error {
	if st.OriginalTransactionID == "" || st.ProductID == "" {
		return nil
	}
	// google_product_id ma postać "subskrypcja:planBazowy"; API
	// potwierdzenia oczekuje samej subskrypcji.
	subscriptionID := strings.SplitN(st.ProductID, ":", 2)[0]
	err := v.svc.Purchases.Subscriptions.
		Acknowledge(v.packageName, subscriptionID, st.OriginalTransactionID,
			&androidpublisher.SubscriptionPurchasesAcknowledgeRequest{}).
		Context(ctx).
		Do()
	if err != nil {
		// Powtórne potwierdzenie tego samego zakupu jest bezpieczne i
		// zwraca błąd — nie ma sensu go eskalować.
		if strings.Contains(err.Error(), "alreadyAcknowledged") ||
			strings.Contains(err.Error(), "already been acknowledged") {
			return nil
		}
		return fmt.Errorf("play acknowledge: %w", err)
	}
	return nil
}

func parseRFC3339(v string) time.Time {
	if strings.TrimSpace(v) == "" {
		return time.Time{}
	}
	t, err := time.Parse(time.RFC3339, v)
	if err != nil {
		return time.Time{}
	}
	return t.UTC()
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}
