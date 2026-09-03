// Package stripepromo jest wąskim portem na kupony i kody promocyjne
// Stripe'a — jedyne miejsce w billing-svc, które wie, jak wygląda ich API.
//
// docs/70 §6.4. Podział ról: nasza tabela `discount_codes` jest źródłem
// prawdy o TYM, co admin zdefiniował (nazwa, termin, procent, limit), a
// Stripe jest SILNIKIEM egzekwowania na webie — to on atomowo pilnuje
// `max_redemptions` przy tworzeniu sesji Checkout, więc wyścig o ostatnie
// użycie rozstrzyga się po jego stronie, nie w naszym liczniku.
//
// Handler gRPC rozmawia z interfejsem Syncer, dzięki czemu testy nie
// potrzebują klucza Stripe'a, a lokalny dev bez klucza po prostu nie
// pozwoli założyć kodu na kanał WEB (zamiast założyć martwy).
package stripepromo

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/stripe/stripe-go/v82"
	"github.com/stripe/stripe-go/v82/coupon"
	"github.com/stripe/stripe-go/v82/promotioncode"
)

// Spec opisuje kod rabatowy w kształcie, w jakim definiuje go admin.
type Spec struct {
	Code            string
	Name            string
	PercentOff      float64 // (0, 100]
	Duration        string  // ONCE | REPEATING | FOREVER
	DurationPeriods int32   // tylko dla REPEATING
	ValidUntil      time.Time
	MaxRedemptions  int32
	NewCustomers    bool
}

// Promo to para identyfikatorów po stronie Stripe'a.
type Promo struct {
	CouponID        string
	PromotionCodeID string
}

// Lookup to wynik odczytu istniejącego kodu ze Stripe'a — używany jako
// ścieżka awaryjna dla kodów założonych ręcznie w dashboardzie, zanim
// powstał panel (ROWNOWAGA, ROZKWIT, PIONIER33).
type Lookup struct {
	Found      bool
	Active     bool
	PercentOff float64 // 0 gdy rabat kwotowy
	AmountOff  int64   // w groszach; 0 gdy procentowy
	Currency   string
}

// Syncer — port używany przez handlery gRPC.
type Syncer interface {
	Create(ctx context.Context, spec Spec) (Promo, error)
	SetActive(ctx context.Context, promotionCodeID string, active bool) error
	// Recreate zakłada NOWY promotion code pod istniejącym kuponem.
	// Stripe nie pozwala zmienić `expires_at` ani `max_redemptions` na
	// istniejącym kodzie (można tylko `active` i `metadata`), więc zmiana
	// terminu albo limitu = nowy kod + wygaszenie starego (docs/70 D10).
	Recreate(ctx context.Context, couponID, code string, validUntil time.Time, maxRedemptions int32) (string, error)
	Lookup(ctx context.Context, code string) (Lookup, error)
}

// Client implementuje Syncer na prawdziwym API Stripe'a.
type Client struct {
	secretKey string
}

// New zwraca klienta albo nil, gdy klucz nie jest ustawiony. Nil jest
// poprawną wartością: handler wtedy odmawia założenia kodu na kanał WEB,
// zamiast zapisać u nas wiersz, którego Checkout nigdy nie zastosuje.
func New(secretKey string) *Client {
	if strings.TrimSpace(secretKey) == "" {
		return nil
	}
	return &Client{secretKey: secretKey}
}

func (c *Client) use() { stripe.Key = c.secretKey }

func (c *Client) Create(ctx context.Context, spec Spec) (Promo, error) {
	c.use()

	couponParams := &stripe.CouponParams{
		Name:       stripe.String(spec.Name),
		PercentOff: stripe.Float64(spec.PercentOff),
	}
	switch spec.Duration {
	case "ONCE":
		couponParams.Duration = stripe.String(string(stripe.CouponDurationOnce))
	case "REPEATING":
		couponParams.Duration = stripe.String(string(stripe.CouponDurationRepeating))
		couponParams.DurationInMonths = stripe.Int64(int64(spec.DurationPeriods))
	default:
		couponParams.Duration = stripe.String(string(stripe.CouponDurationForever))
	}
	couponParams.Context = ctx

	cpn, err := coupon.New(couponParams)
	if err != nil {
		return Promo{}, fmt.Errorf("stripe coupon create: %w", err)
	}

	promoParams := &stripe.PromotionCodeParams{
		Coupon:         stripe.String(cpn.ID),
		Code:           stripe.String(spec.Code),
		MaxRedemptions: stripe.Int64(int64(spec.MaxRedemptions)),
		ExpiresAt:      stripe.Int64(spec.ValidUntil.Unix()),
	}
	if spec.NewCustomers {
		promoParams.Restrictions = &stripe.PromotionCodeRestrictionsParams{
			FirstTimeTransaction: stripe.Bool(true),
		}
	}
	promoParams.Context = ctx

	pc, err := promotioncode.New(promoParams)
	if err != nil {
		// Kupon bez kodu jest niewidoczny dla użytkownika i nieszkodliwy,
		// ale zostawiony śmieć utrudnia potem czytanie dashboardu.
		_, _ = coupon.Del(cpn.ID, &stripe.CouponParams{})
		return Promo{}, fmt.Errorf("stripe promotion code create: %w", err)
	}
	return Promo{CouponID: cpn.ID, PromotionCodeID: pc.ID}, nil
}

func (c *Client) SetActive(ctx context.Context, promotionCodeID string, active bool) error {
	c.use()
	params := &stripe.PromotionCodeParams{Active: stripe.Bool(active)}
	params.Context = ctx
	if _, err := promotioncode.Update(promotionCodeID, params); err != nil {
		return fmt.Errorf("stripe promotion code update: %w", err)
	}
	return nil
}

func (c *Client) Recreate(ctx context.Context, couponID, code string, validUntil time.Time, maxRedemptions int32) (string, error) {
	c.use()
	params := &stripe.PromotionCodeParams{
		Coupon:         stripe.String(couponID),
		Code:           stripe.String(code),
		MaxRedemptions: stripe.Int64(int64(maxRedemptions)),
		ExpiresAt:      stripe.Int64(validUntil.Unix()),
	}
	params.Context = ctx
	pc, err := promotioncode.New(params)
	if err != nil {
		return "", fmt.Errorf("stripe promotion code recreate: %w", err)
	}
	return pc.ID, nil
}

func (c *Client) Lookup(ctx context.Context, code string) (Lookup, error) {
	c.use()
	params := &stripe.PromotionCodeListParams{}
	params.Context = ctx
	params.Filters.AddFilter("code", "", code)
	params.Filters.AddFilter("limit", "", "1")
	// Filtr `code` jest unikalny w Stripie, więc interesuje nas wyłącznie
	// pierwszy wynik — stąd brak pętli.
	iter := promotioncode.List(params)
	if !iter.Next() {
		if err := iter.Err(); err != nil {
			return Lookup{}, fmt.Errorf("stripe promotion code list: %w", err)
		}
		return Lookup{}, nil
	}
	pc := iter.PromotionCode()
	out := Lookup{Found: true, Active: pc.Active}
	if pc.Coupon != nil {
		out.PercentOff = pc.Coupon.PercentOff
		out.AmountOff = pc.Coupon.AmountOff
		out.Currency = strings.ToUpper(string(pc.Coupon.Currency))
	}
	return out, nil
}
