package http

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// Kontrakt POST /api/checkout.
//
// Te asercje żyły dotąd WYŁĄCZNIE w suicie E2E marketing-site
// (`register-flow.spec.ts`, `crm-onboarding-stripe.spec.ts`), która
// uderzała pod `/api/checkout` na dev-serwerze Next.js. Endpoint dawno
// przeniósł się stąd do billing-svc (rewrite Firebase Hosting), więc te
// testy sprawdzały w rzeczywistości, czy `next dev` potrafi doproxować do
// nieuruchomionego procesu na porcie 8081 — i zawodziły od miesięcy, a CI
// Playwrighta nie uruchamia, więc nikt tego nie widział.
//
// Kontrakt wraca tu, gdzie mieszka: httptest, bez sieci, bez bazy, bez
// klucza Stripe'a — dokładnie tak, jak zakłada komentarz w
// checkout_handler.go, który celowo stawia walidację wejścia PRZED
// sprawdzeniem konfiguracji Stripe'a.

// newTestCheckoutMux buduje handler bez puli i bez kodów rabatowych —
// oba są opcjonalne, a walidacja wejścia nie powinna ich potrzebować.
func newTestCheckoutMux(t *testing.T) *http.ServeMux {
	t.Helper()
	// Bez STRIPE_SECRET_KEY w środowisku: żaden przypadek poniżej nie
	// powinien dojść do Stripe'a. Gdyby doszedł, dostaniemy 503 zamiast
	// 400 i test to pokaże.
	t.Setenv("STRIPE_SECRET_KEY", "")
	mux := http.NewServeMux()
	NewCheckoutHandler(nil, nil, nil).RegisterRoutes(mux)
	return mux
}

func postCheckout(t *testing.T, mux *http.ServeMux, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/api/checkout", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

func decodeError(t *testing.T, rec *httptest.ResponseRecorder) string {
	t.Helper()
	var payload map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("odpowiedź nie jest JSON-em: %q", rec.Body.String())
	}
	return payload["error"]
}

func TestCheckoutContract(t *testing.T) {
	mux := newTestCheckoutMux(t)

	t.Run("puste ciało żądania", func(t *testing.T) {
		rec := postCheckout(t, mux, `{}`)
		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, chciano 400", rec.Code)
		}
		if msg := decodeError(t, rec); msg == "" {
			t.Error("odpowiedź musi nieść pole error — panel po nim rozpoznaje przyczynę")
		}
	})

	t.Run("niepoprawny JSON", func(t *testing.T) {
		rec := postCheckout(t, mux, `{nie-json`)
		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, chciano 400", rec.Code)
		}
	})

	t.Run("brak priceId", func(t *testing.T) {
		rec := postCheckout(t, mux, `{"organizationId":"550e8400-e29b-41d4-a716-446655440000"}`)
		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, chciano 400", rec.Code)
		}
		// Komunikat nazywa BRAKUJĄCE pole — bez tego wywołujący nie wie,
		// co poprawić, a testy E2E dopasowują się po tej treści.
		if msg := decodeError(t, rec); !strings.Contains(msg, "priceId") {
			t.Errorf("error = %q, chciano wzmianki o priceId", msg)
		}
	})

	t.Run("organizationId nie jest UUID", func(t *testing.T) {
		rec := postCheckout(t, mux, `{"priceId":"price_test_123","organizationId":"not-a-uuid"}`)
		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, chciano 400", rec.Code)
		}
		if msg := decodeError(t, rec); !strings.Contains(msg, "organizationId") {
			t.Errorf("error = %q, chciano wzmianki o organizationId", msg)
		}
	})

	t.Run("brak organizationId", func(t *testing.T) {
		rec := postCheckout(t, mux, `{"priceId":"price_test_123"}`)
		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, chciano 400", rec.Code)
		}
		if msg := decodeError(t, rec); !strings.Contains(msg, "organizationId") {
			t.Errorf("error = %q, chciano wzmianki o organizationId", msg)
		}
	})

	t.Run("poprawne wejście bez klucza Stripe daje 503, nie 400", func(t *testing.T) {
		// To jest granica, dla której walidacja stoi PRZED sprawdzeniem
		// konfiguracji: 400 znaczy "popraw żądanie", 503 znaczy "usługa
		// nie jest skonfigurowana". Zamiana tych dwóch kazała klientowi
		// szukać błędu u siebie, gdy problem był po naszej stronie.
		rec := postCheckout(t, mux,
			`{"priceId":"price_test_123","organizationId":"550e8400-e29b-41d4-a716-446655440000"}`)
		if rec.Code != http.StatusServiceUnavailable {
			t.Fatalf("status = %d, chciano 503", rec.Code)
		}
	})

	t.Run("GET nie jest dozwolony", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/checkout", nil)
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)
		if rec.Code != http.StatusMethodNotAllowed {
			t.Fatalf("status = %d, chciano 405", rec.Code)
		}
	})
}

func TestBillingPortalContract(t *testing.T) {
	mux := newTestCheckoutMux(t)

	t.Run("brak e-maila", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/billing-portal", strings.NewReader(`{}`))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)
		// Portal bez adresu klienta nie ma czego otworzyć; odpowiedź musi
		// to nazwać, a nie odsyłać ogólnego 500.
		if rec.Code != http.StatusBadRequest && rec.Code != http.StatusServiceUnavailable {
			t.Fatalf("status = %d, chciano 400 albo 503", rec.Code)
		}
	})

	t.Run("GET nie jest dozwolony", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/billing-portal", nil)
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)
		if rec.Code != http.StatusMethodNotAllowed {
			t.Fatalf("status = %d, chciano 405", rec.Code)
		}
	})
}
