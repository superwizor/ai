// checkout_handler.go — browser-facing Stripe Checkout + Billing Portal endpoints.
//
// Replaces the broken Next.js API routes (marketing-site/src/app/api/checkout/
// and billing-portal/) which returned 404 on production because Next.js
// `output: "export"` doesn't support API routes on static hosting.
//
// Endpoints:
//
//	POST /api/checkout       — creates a Stripe Checkout Session
//	POST /api/billing-portal — creates a Stripe Billing Portal session
//
// Auth: none (same as the old Next.js routes — the Stripe session is the
// authorization). The frontend passes organizationId + email from its own
// Firebase auth context.
//
// STRIPE_SECRET_KEY must be set via env (Secret Manager on Cloud Run).
// Without it, both endpoints return 503.
package http

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"

	"github.com/stripe/stripe-go/v82"
	billingportal "github.com/stripe/stripe-go/v82/billingportal/session"
	"github.com/stripe/stripe-go/v82/checkout/session"
	stripecustomer "github.com/stripe/stripe-go/v82/customer"
	"github.com/stripe/stripe-go/v82/promotioncode"
	"github.com/stripe/stripe-go/v82/subscription"
	"github.com/stripe/stripe-go/v82/taxid"
)

var uuidRE = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

// DiscountReserver rezerwuje użycie kodu rabatowego z naszego katalogu i
// zwraca odpowiadający mu promotion code Stripe'a (docs/70 §6.4).
// Interfejs, nie konkret — handler nie musi znać warstwy gRPC.
type DiscountReserver interface {
	ReserveDiscountRedemption(
		ctx context.Context, code string, orgID uuid.UUID, userID *uuid.UUID,
		channel, reference string,
	) (uuid.UUID, string, error)
}

// CheckoutHandler serves /api/checkout and /api/billing-portal.
type CheckoutHandler struct {
	logger    *slog.Logger
	secretKey string
	queries   *db.Queries
	discounts DiscountReserver
}

// NewCheckoutHandler creates the handler. Reads STRIPE_SECRET_KEY from env.
//
// pool i discounts są opcjonalne (mogą być nil w testach kontraktowych):
// bez nich endpoint działa jak dotąd, tyle że bez blokady krzyżowej
// dostawców i bez rezerwacji użycia kodu.
func NewCheckoutHandler(logger *slog.Logger, pool *pgxpool.Pool, discounts DiscountReserver) *CheckoutHandler {
	if logger == nil {
		logger = slog.Default()
	}
	sk := os.Getenv("STRIPE_SECRET_KEY")
	if sk == "" {
		logger.Warn("STRIPE_SECRET_KEY not set — /api/checkout and /api/billing-portal will return 503")
	}
	h := &CheckoutHandler{logger: logger, secretKey: sk, discounts: discounts}
	if pool != nil {
		h.queries = db.New(pool)
	}
	return h
}

// RegisterRoutes wires the handler into the mux.
func (h *CheckoutHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/checkout", h.handleCheckout)
	mux.HandleFunc("POST /api/billing-portal", h.handleBillingPortal)
}

// ─── Checkout ──────────────────────────────────────────────────────────────────

type checkoutRequest struct {
	PriceID        string           `json:"priceId"`
	OrganizationID string           `json:"organizationId"`
	Email          string           `json:"email,omitempty"`
	PhoneNumber    string           `json:"phoneNumber,omitempty"`
	Name           string           `json:"name,omitempty"`
	PromoCode      string           `json:"promoCode,omitempty"`
	ReturnURL      string           `json:"returnUrl,omitempty"`
	TaxID          string           `json:"taxId,omitempty"`
	VatIDEU        string           `json:"vatIdEu,omitempty"`
	Address        *checkoutAddress `json:"address,omitempty"`
}

type checkoutAddress struct {
	Line1      string `json:"line1,omitempty"`
	Line2      string `json:"line2,omitempty"`
	City       string `json:"city,omitempty"`
	PostalCode string `json:"postal_code,omitempty"`
	State      string `json:"state,omitempty"`
	Country    string `json:"country,omitempty"`
}

func (h *CheckoutHandler) handleCheckout(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Walidacja wejścia idzie PRZED sprawdzeniem konfiguracji Stripe'a.
	//
	// Odwrotna kolejność sprawiała, że źle sformułowane żądanie dostawało
	// 503 "payment service not configured" zamiast 400 z powodem — czyli
	// odpowiedź mówiła o stanie serwera, choć błąd był po stronie
	// klienta. Wywołujący nie miał jak odróżnić "wysłałem śmieci" od
	// "płatności są chwilowo niedostępne" i widział to drugie.
	//
	// Praktyczny skutek: kontraktu tego endpointu nie dało się
	// przetestować bez klucza Stripe, a klucz w Secret Managerze jest
	// PRODUKCYJNY (sk_live_) — uruchamianie testów E2E z nim znaczyłoby
	// dobijanie się do prawdziwego Stripe'a.
	var req checkoutRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	if req.PriceID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "priceId is required"})
		return
	}
	if !uuidRE.MatchString(req.OrganizationID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "valid organizationId is required"})
		return
	}

	// Dopiero teraz potrzebujemy Stripe'a naprawdę.
	if h.secretKey == "" {
		h.logger.ErrorContext(ctx, "checkout: STRIPE_SECRET_KEY not configured")
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "payment service not configured"})
		return
	}
	stripe.Key = h.secretKey

	// Determine success/cancel URLs.
	// Firebase Hosting rewrite sends these requests to billing-svc but the
	// Origin header still carries the marketing site origin. We use the
	// Referer or Origin header to derive the base URL.
	origin := deriveOrigin(r)
	successURL := origin + "/register/therapist/success?session_id={CHECKOUT_SESSION_ID}"
	cancelURL := origin + "/register/therapist?plan=cancelled"
	if req.ReturnURL != "" {
		successURL = origin + req.ReturnURL + "?session_id={CHECKOUT_SESSION_ID}&upgraded=1"
		cancelURL = origin + req.ReturnURL + "?plan=cancelled"
	}

	orgUUID, orgErr := uuid.Parse(req.OrganizationID)

	// ── Blokada krzyżowa dostawców (docs/70 §5.1, E22) ───────────────────
	// Organizacja z aktywną subskrypcją ze sklepu nie może kupić drugiej
	// przez Stripe'a: skończyłoby się to dwiema płatnościami za to samo, a
	// zwrotu po stronie Apple'a nie jesteśmy w stanie wykonać.
	if h.queries != nil && orgErr == nil {
		sub, serr := h.queries.GetActiveSubscriptionByOrg(ctx, orgUUID)
		switch {
		case serr == nil && (sub.Provider == "APPLE_IAP" || sub.Provider == "GOOGLE_IAP"):
			store := "App Store"
			if sub.Provider == "GOOGLE_IAP" {
				store = "Google Play"
			}
			writeJSON(w, http.StatusConflict, map[string]string{
				"error":         "OTHER_PROVIDER_ACTIVE",
				"provider":      string(sub.Provider),
				"blocked_until": sub.CurrentPeriodEnd.Format(time.RFC3339),
				"message":       "Subskrypcja jest aktywna w " + store + " — zarządzasz nią w ustawieniach sklepu.",
			})
			return
		case serr != nil && !errors.Is(serr, pgx.ErrNoRows):
			h.logger.WarnContext(ctx, "checkout: nie udało się sprawdzić aktywnej subskrypcji", "error", serr)
		}
	}

	// ── Promo code resolution ────────────────────────────────────────────
	//
	// Najpierw nasz katalog (docs/70 §6): rezerwuje użycie kodu dla tej
	// organizacji i zwraca powiązany promotion code Stripe'a. Kody
	// założone ręcznie w dashboardzie, zanim powstał panel, nie mają u nas
	// wiersza — dla nich zostaje wyszukiwanie po nazwie, jak dotąd.
	var resolvedPromoID *string
	if req.PromoCode != "" {
		if h.discounts != nil && orgErr == nil {
			if _, promoID, derr := h.discounts.ReserveDiscountRedemption(
				ctx, req.PromoCode, orgUUID, nil, "WEB", "",
			); derr == nil && promoID != "" {
				resolvedPromoID = &promoID
			} else if derr != nil && !errors.Is(derr, pgx.ErrNoRows) {
				// Kod istnieje, ale rezerwacja się nie udała (np. ta
				// organizacja już go użyła). Nie przerywamy checkoutu —
				// Stripe i tak odrzuci nieuprawnione użycie, a użytkownik
				// ma zapłacić.
				h.logger.WarnContext(ctx, "checkout: rezerwacja kodu rabatowego nieudana",
					"code", req.PromoCode, "error", derr)
			}
		}
		if resolvedPromoID == nil {
			params := &stripe.PromotionCodeListParams{}
			params.Filters.AddFilter("code", "", req.PromoCode)
			params.Filters.AddFilter("active", "", "true")
			params.Filters.AddFilter("limit", "", "1")
			iter := promotioncode.List(params)
			if iter.Next() {
				id := iter.PromotionCode().ID
				resolvedPromoID = &id
			}
		}
	}

	// ── Customer lookup / create ─────────────────────────────────────────
	var customerID string
	if req.Email != "" {
		custParams := &stripe.CustomerListParams{}
		custParams.Filters.AddFilter("email", "", req.Email)
		custParams.Filters.AddFilter("limit", "", "1")
		iter := stripecustomer.List(custParams)
		if iter.Next() {
			existing := iter.Customer()
			customerID = existing.ID

			// Check for active subscription → redirect to billing portal.
			subParams := &stripe.SubscriptionListParams{
				Customer: stripe.String(existing.ID),
				Status:   stripe.String("active"),
			}
			subParams.Filters.AddFilter("limit", "", "1")
			subIter := subscription.List(subParams)
			if subIter.Next() {
				returnURL := origin + "/account"
				if req.ReturnURL != "" {
					returnURL = origin + req.ReturnURL
				}
				portalParams := &stripe.BillingPortalSessionParams{
					Customer:  stripe.String(existing.ID),
					ReturnURL: stripe.String(returnURL),
					Locale:    stripe.String("pl"),
				}
				portalSess, err := billingportal.New(portalParams)
				if err != nil {
					h.logger.ErrorContext(ctx, "checkout: create portal for existing sub failed", "error", err)
					writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "Failed to create billing portal"})
					return
				}
				writeJSON(w, http.StatusOK, map[string]string{"url": portalSess.URL})
				return
			}

			// Sync name/phone/address if changed.
			updateParams := &stripe.CustomerParams{}
			needsUpdate := false
			if req.PhoneNumber != "" && existing.Phone != req.PhoneNumber {
				updateParams.Phone = stripe.String(req.PhoneNumber)
				needsUpdate = true
			}
			if req.Name != "" && existing.Name != req.Name {
				updateParams.Name = stripe.String(req.Name)
				needsUpdate = true
			}
			if req.Address != nil && existing.Address == nil {
				updateParams.Address = &stripe.AddressParams{
					Line1:      stripe.String(req.Address.Line1),
					Line2:      stripe.String(req.Address.Line2),
					City:       stripe.String(req.Address.City),
					PostalCode: stripe.String(req.Address.PostalCode),
					State:      stripe.String(req.Address.State),
					Country:    stripe.String(req.Address.Country),
				}
				needsUpdate = true
			}
			if needsUpdate {
				if _, err := stripecustomer.Update(existing.ID, updateParams); err != nil {
					h.logger.WarnContext(ctx, "checkout: update existing customer failed", "error", err)
				}
			}

			// Assign tax ID.
			h.assignTaxID(ctx, existing.ID, req.TaxID, req.VatIDEU)
		}
	}

	// Create customer if needed.
	if customerID == "" && req.Email != "" {
		newParams := &stripe.CustomerParams{
			Email: stripe.String(req.Email),
		}
		if req.PhoneNumber != "" {
			newParams.Phone = stripe.String(req.PhoneNumber)
		}
		if req.Name != "" {
			newParams.Name = stripe.String(req.Name)
		}
		if req.Address != nil {
			newParams.Address = &stripe.AddressParams{
				Line1:      stripe.String(req.Address.Line1),
				Line2:      stripe.String(req.Address.Line2),
				City:       stripe.String(req.Address.City),
				PostalCode: stripe.String(req.Address.PostalCode),
				State:      stripe.String(req.Address.State),
				Country:    stripe.String(req.Address.Country),
			}
		}
		newParams.AddMetadata("organization_id", req.OrganizationID)
		newCust, err := stripecustomer.New(newParams)
		if err != nil {
			h.logger.WarnContext(ctx, "checkout: create customer failed", "error", err)
		} else {
			customerID = newCust.ID
			h.assignTaxID(ctx, newCust.ID, req.TaxID, req.VatIDEU)
		}
	}

	// ── Build Checkout Session params ────────────────────────────────────
	sessParams := &stripe.CheckoutSessionParams{
		Mode: stripe.String(string(stripe.CheckoutSessionModeSubscription)),
		LineItems: []*stripe.CheckoutSessionLineItemParams{
			{Price: stripe.String(req.PriceID), Quantity: stripe.Int64(1)},
		},
		SuccessURL: stripe.String(successURL),
		CancelURL:  stripe.String(cancelURL),
		Locale:     stripe.String("pl"),
		PhoneNumberCollection: &stripe.CheckoutSessionPhoneNumberCollectionParams{
			Enabled: stripe.Bool(true),
		},
		TaxIDCollection: &stripe.CheckoutSessionTaxIDCollectionParams{
			Enabled: stripe.Bool(true),
		},
		BillingAddressCollection: stripe.String("required"),
		AutomaticTax:             &stripe.CheckoutSessionAutomaticTaxParams{Enabled: stripe.Bool(true)},
		SubscriptionData: &stripe.CheckoutSessionSubscriptionDataParams{
			Metadata: map[string]string{
				"organization_id": req.OrganizationID,
			},
		},
	}
	sessParams.AddMetadata("organization_id", req.OrganizationID)

	if resolvedPromoID != nil {
		sessParams.Discounts = []*stripe.CheckoutSessionDiscountParams{
			{PromotionCode: resolvedPromoID},
		}
	} else {
		sessParams.AllowPromotionCodes = stripe.Bool(true)
	}

	if customerID != "" {
		sessParams.Customer = stripe.String(customerID)
		sessParams.CustomerUpdate = &stripe.CheckoutSessionCustomerUpdateParams{
			Name:    stripe.String("auto"),
			Address: stripe.String("auto"),
		}
	} else if req.Email != "" {
		sessParams.CustomerEmail = stripe.String(req.Email)
	}

	sess, err := session.New(sessParams)
	if err != nil {
		h.logger.ErrorContext(ctx, "checkout: create session failed", "error", err)
		if stripeErr, ok := err.(*stripe.Error); ok {
			writeJSON(w, int(stripeErr.HTTPStatusCode), map[string]string{"error": stripeErr.Msg})
		} else {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "Failed to create checkout session"})
		}
		return
	}

	h.logger.InfoContext(ctx, "checkout: session created",
		"session_id", sess.ID,
		"org_id", req.OrganizationID)
	// Otwarta sesja Checkout blokuje zakup w sklepie do czasu wygaśnięcia
	// (sesje Stripe żyją 24 h). Bez tego użytkownik z otwartą kartą
	// przeglądarki mógłby równolegle kupić IAP — docs/70 E22.
	if h.queries != nil && orgErr == nil {
		if perr := h.queries.UpsertPendingCheckout(ctx, db.UpsertPendingCheckoutParams{
			OrganizationID: orgUUID,
			Channel:        "WEB",
			Reference:      sess.ID,
			ExpiresAt:      time.Now().Add(24 * time.Hour),
		}); perr != nil {
			h.logger.WarnContext(ctx, "checkout: nie zapisano blokady kanału", "error", perr)
		}
	}

	writeJSON(w, http.StatusOK, map[string]string{"url": sess.URL})
}

// ─── Billing Portal ────────────────────────────────────────────────────────────

type billingPortalRequest struct {
	Email     string `json:"email"`
	ReturnURL string `json:"returnUrl,omitempty"`
}

func (h *CheckoutHandler) handleBillingPortal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	if h.secretKey == "" {
		h.logger.ErrorContext(ctx, "billing-portal: STRIPE_SECRET_KEY not configured")
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "payment service not configured"})
		return
	}
	stripe.Key = h.secretKey

	var req billingPortalRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	if req.Email == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "email is required"})
		return
	}

	// Look up customer by email.
	custParams := &stripe.CustomerListParams{}
	custParams.Filters.AddFilter("email", "", req.Email)
	custParams.Filters.AddFilter("limit", "", "1")
	iter := stripecustomer.List(custParams)
	if !iter.Next() {
		writeJSON(w, http.StatusNotFound, map[string]string{
			"error": "No Stripe customer found for this email. Please complete a payment first.",
		})
		return
	}
	customer := iter.Customer()

	origin := deriveOrigin(r)
	returnURL := origin + "/account"
	if req.ReturnURL != "" {
		returnURL = origin + req.ReturnURL
	}

	portalParams := &stripe.BillingPortalSessionParams{
		Customer:  stripe.String(customer.ID),
		ReturnURL: stripe.String(returnURL),
		Locale:    stripe.String("pl"),
	}
	portalSess, err := billingportal.New(portalParams)
	if err != nil {
		h.logger.ErrorContext(ctx, "billing-portal: create session failed", "error", err)
		if stripeErr, ok := err.(*stripe.Error); ok {
			writeJSON(w, int(stripeErr.HTTPStatusCode), map[string]string{"error": stripeErr.Msg})
		} else {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "Failed to create billing portal session"})
		}
		return
	}

	h.logger.InfoContext(ctx, "billing-portal: session created",
		"customer_id", customer.ID)
	writeJSON(w, http.StatusOK, map[string]string{"url": portalSess.URL})
}

// ─── Helpers ───────────────────────────────────────────────────────────────────

// assignTaxID adds a pl_nip or eu_vat tax ID to a Stripe customer (best-effort).
func (h *CheckoutHandler) assignTaxID(ctx context.Context, customerID, nipVal, vatVal string) {
	if vatVal != "" {
		clean := strings.ToUpper(strings.Map(func(r rune) rune {
			if (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') {
				return r
			}
			return -1
		}, vatVal))
		if strings.HasPrefix(clean, "PL") && len(clean) == 12 {
			params := &stripe.TaxIDParams{
				Customer: stripe.String(customerID),
				Type:     stripe.String("eu_vat"),
				Value:    stripe.String(clean),
			}
			if _, err := taxid.New(params); err != nil {
				h.logger.WarnContext(ctx, "checkout: assign eu_vat failed", "error", err)
			}
		}
	} else if nipVal != "" {
		clean := strings.Map(func(r rune) rune {
			if r >= '0' && r <= '9' {
				return r
			}
			return -1
		}, nipVal)
		if len(clean) == 10 {
			params := &stripe.TaxIDParams{
				Customer: stripe.String(customerID),
				Type:     stripe.String("pl_nip"),
				Value:    stripe.String(clean),
			}
			if _, err := taxid.New(params); err != nil {
				h.logger.WarnContext(ctx, "checkout: assign pl_nip failed", "error", err)
			}
		}
	}
}

// deriveOrigin extracts the origin (scheme + host) from the request.
// Firebase Hosting rewrite preserves the original Host header, so we can
// derive it from there. Falls back to "https://superwizor.ai".
func deriveOrigin(r *http.Request) string {
	// Try Origin header first (set on POST by browsers).
	if origin := r.Header.Get("Origin"); origin != "" {
		return strings.TrimRight(origin, "/")
	}
	// Try Referer.
	if ref := r.Header.Get("Referer"); ref != "" {
		// Extract scheme://host from the Referer.
		parts := strings.SplitN(ref, "//", 2)
		if len(parts) == 2 {
			hostEnd := strings.IndexByte(parts[1], '/')
			if hostEnd > 0 {
				return parts[0] + "//" + parts[1][:hostEnd]
			}
			return parts[0] + "//" + parts[1]
		}
	}
	// Try X-Forwarded-Host (set by Firebase Hosting).
	if fh := r.Header.Get("X-Forwarded-Host"); fh != "" {
		scheme := "https"
		if fp := r.Header.Get("X-Forwarded-Proto"); fp != "" {
			scheme = fp
		}
		return fmt.Sprintf("%s://%s", scheme, fh)
	}
	// Safe default.
	return "https://superwizor.ai"
}
