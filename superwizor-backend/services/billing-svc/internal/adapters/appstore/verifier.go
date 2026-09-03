// Package appstore weryfikuje zakupy App Store (StoreKit 2) i odczytuje
// stan subskrypcji z App Store Server API.
//
// docs/70 §7.3. Dwie niezależne rzeczy dzieją się tutaj:
//
//  1. Kryptograficzna weryfikacja dowodu zakupu (JWS). Aplikacja przysyła
//     podpisaną transakcję; sprawdzamy łańcuch certyfikatów aż do korzenia
//     Apple'a i podpis nad payloadem. To jest ODPORNE na podrobienie przez
//     klienta i nie wymaga sieci.
//
//  2. Odczyt bieżącego stanu (auto-renew, grace period, zwrot) z App Store
//     Server API. Sam JWS mówi tylko o pojedynczej transakcji — czy
//     subskrypcja żyje DZIŚ, wie tylko Apple.
//
// Fail-closed: bez skonfigurowanego korzenia CA nie weryfikujemy niczego.
// Certyfikat (AppleRootCA-G3) publikuje Apple; wgrywamy go do Secret
// Managera jako APPLE_ROOT_CA_PEM. Bez klucza App Store Server API
// (APPLE_ISSUER_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY_P8) weryfikacja
// nadal działa, ale stan wyprowadzamy wyłącznie z samej transakcji.
package appstore

import (
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"strings"
	"time"

	billinggrpc "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/grpc"
)

const (
	productionAPI = "https://api.storekit.itunes.apple.com"
	sandboxAPI    = "https://api.storekit-sandbox.itunes.apple.com"
)

// Config to wszystko, co trzeba wstrzyknąć z env / Secret Managera.
type Config struct {
	BundleID     string // ai.superwizor.superwizor
	IssuerID     string // App Store Connect API issuer
	KeyID        string // identyfikator klucza .p8
	PrivateKeyP8 string // zawartość pliku .p8 (PEM, PKCS#8, EC P-256)
	RootCAPEM    string // AppleRootCA-G3 w PEM
}

// Verifier implementuje grpc.StoreVerifier dla App Store.
type Verifier struct {
	cfg     Config
	roots   *x509.CertPool
	signKey *ecdsa.PrivateKey
	http    *http.Client
}

// New buduje weryfikator. Zwraca błąd, gdy nie da się zweryfikować
// niczego — wtedy lepiej nie zarejestrować weryfikatora wcale niż
// udawać, że sprawdzamy zakupy.
func New(cfg Config) (*Verifier, error) {
	if strings.TrimSpace(cfg.RootCAPEM) == "" {
		return nil, errors.New("APPLE_ROOT_CA_PEM wymagany — bez korzenia CA nie da się zweryfikować podpisu Apple")
	}
	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM([]byte(cfg.RootCAPEM)) {
		return nil, errors.New("APPLE_ROOT_CA_PEM: nie udało się wczytać certyfikatu")
	}
	v := &Verifier{
		cfg:   cfg,
		roots: pool,
		http:  &http.Client{Timeout: 15 * time.Second},
	}
	if strings.TrimSpace(cfg.PrivateKeyP8) != "" {
		key, err := parseP8(cfg.PrivateKeyP8)
		if err != nil {
			return nil, fmt.Errorf("APPLE_PRIVATE_KEY_P8: %w", err)
		}
		v.signKey = key
	}
	return v, nil
}

// ─── Weryfikacja dowodu zakupu ────────────────────────────────────────

type transactionPayload struct {
	TransactionID         string `json:"transactionId"`
	OriginalTransactionID string `json:"originalTransactionId"`
	BundleID              string `json:"bundleId"`
	ProductID             string `json:"productId"`
	PurchaseDate          int64  `json:"purchaseDate"`
	OriginalPurchaseDate  int64  `json:"originalPurchaseDate"`
	ExpiresDate           int64  `json:"expiresDate"`
	Type                  string `json:"type"`
	AppAccountToken       string `json:"appAccountToken"`
	Environment           string `json:"environment"`
	RevocationDate        int64  `json:"revocationDate"`
	RevocationReason      *int   `json:"revocationReason"`
	OfferType             *int   `json:"offerType"`
	OfferIdentifier       string `json:"offerIdentifier"`
}

func (v *Verifier) VerifyPurchase(ctx context.Context, proof billinggrpc.StoreProof) (billinggrpc.StoreState, error) {
	if strings.TrimSpace(proof.JWSTransaction) == "" {
		return billinggrpc.StoreState{}, errors.New("brak jws_transaction")
	}
	payload, raw, err := v.verifyJWS(proof.JWSTransaction)
	if err != nil {
		return billinggrpc.StoreState{}, err
	}
	// Transakcja z cudzej aplikacji nigdy nie może nadać uprawnienia w
	// naszej — to najtańsza i najskuteczniejsza kontrola po weryfikacji
	// podpisu.
	if v.cfg.BundleID != "" && payload.BundleID != "" && payload.BundleID != v.cfg.BundleID {
		return billinggrpc.StoreState{}, fmt.Errorf("transakcja dotyczy innej aplikacji (%s)", payload.BundleID)
	}

	st := stateFromPayload(payload, raw)

	// Payload mówi o jednej transakcji; o tym, czy subskrypcja żyje DZIŚ
	// (auto-renew, grace, zwrot), wie tylko App Store Server API.
	if v.signKey != nil {
		if live, ferr := v.FetchState(ctx, st.OriginalTransactionID, st.ProductID); ferr == nil {
			live.AppAccountToken = firstNonEmpty(live.AppAccountToken, st.AppAccountToken)
			live.TransactionID = firstNonEmpty(live.TransactionID, st.TransactionID)
			live.PurchaseDate = st.PurchaseDate
			return live, nil
		}
	}
	return st, nil
}

func stateFromPayload(p transactionPayload, raw []byte) billinggrpc.StoreState {
	st := billinggrpc.StoreState{
		Provider:              "APPLE_IAP",
		TransactionID:         p.TransactionID,
		OriginalTransactionID: p.OriginalTransactionID,
		ProductID:             p.ProductID,
		PurchaseDate:          msToTime(p.PurchaseDate),
		ExpiresDate:           msToTime(p.ExpiresDate),
		Environment:           normalizeEnv(p.Environment),
		AppAccountToken:       p.AppAccountToken,
		OfferIdentifier:       p.OfferIdentifier,
		Raw:                   raw,
		// Bez odpowiedzi z API zakładamy, że subskrypcja się odnawia:
		// przeciwne założenie pokazałoby użytkownikowi "anulowana"
		// natychmiast po zakupie.
		AutoRenew: true,
	}
	if p.OfferType != nil {
		st.OfferType = fmt.Sprintf("%d", *p.OfferType)
	}
	switch {
	case p.RevocationDate > 0:
		st.Status = billinggrpc.StoreStatusRevoked
		t := msToTime(p.RevocationDate)
		st.RevocationDate = &t
		if p.RevocationReason != nil {
			st.RevocationReason = fmt.Sprintf("%d", *p.RevocationReason)
		}
	case p.ExpiresDate > 0 && msToTime(p.ExpiresDate).Before(time.Now()):
		st.Status = billinggrpc.StoreStatusExpired
	default:
		st.Status = billinggrpc.StoreStatusActive
	}
	return st
}

// verifyJWS sprawdza łańcuch certyfikatów i podpis ES256.
func (v *Verifier) verifyJWS(token string) (transactionPayload, []byte, error) {
	var out transactionPayload
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return out, nil, errors.New("jws: oczekiwano trzech części")
	}
	headerJSON, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return out, nil, fmt.Errorf("jws header: %w", err)
	}
	var header struct {
		Alg string   `json:"alg"`
		X5c []string `json:"x5c"`
	}
	if err := json.Unmarshal(headerJSON, &header); err != nil {
		return out, nil, fmt.Errorf("jws header json: %w", err)
	}
	if header.Alg != "ES256" {
		return out, nil, fmt.Errorf("jws: nieobsługiwany algorytm %q", header.Alg)
	}
	if len(header.X5c) < 2 {
		return out, nil, errors.New("jws: brak łańcucha certyfikatów")
	}

	certs := make([]*x509.Certificate, 0, len(header.X5c))
	for i, b64 := range header.X5c {
		der, derr := base64.StdEncoding.DecodeString(b64)
		if derr != nil {
			return out, nil, fmt.Errorf("jws x5c[%d]: %w", i, derr)
		}
		cert, cerr := x509.ParseCertificate(der)
		if cerr != nil {
			return out, nil, fmt.Errorf("jws x5c[%d]: %w", i, cerr)
		}
		certs = append(certs, cert)
	}

	intermediates := x509.NewCertPool()
	for _, c := range certs[1:] {
		intermediates.AddCert(c)
	}
	leaf := certs[0]
	if _, err := leaf.Verify(x509.VerifyOptions{
		Roots:         v.roots,
		Intermediates: intermediates,
		KeyUsages:     []x509.ExtKeyUsage{x509.ExtKeyUsageAny},
	}); err != nil {
		return out, nil, fmt.Errorf("jws: łańcuch certyfikatów nieważny: %w", err)
	}

	pub, ok := leaf.PublicKey.(*ecdsa.PublicKey)
	if !ok {
		return out, nil, errors.New("jws: certyfikat nie niesie klucza ECDSA")
	}
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return out, nil, fmt.Errorf("jws signature: %w", err)
	}
	if len(sig) != 64 {
		return out, nil, errors.New("jws: nieprawidłowa długość podpisu")
	}
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	r := new(big.Int).SetBytes(sig[:32])
	sVal := new(big.Int).SetBytes(sig[32:])
	if !ecdsa.Verify(pub, digest[:], r, sVal) {
		return out, nil, errors.New("jws: podpis nie zgadza się z certyfikatem")
	}

	payloadJSON, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return out, nil, fmt.Errorf("jws payload: %w", err)
	}
	if err := json.Unmarshal(payloadJSON, &out); err != nil {
		return out, nil, fmt.Errorf("jws payload json: %w", err)
	}
	return out, payloadJSON, nil
}

// ─── App Store Server API ─────────────────────────────────────────────

type statusResponse struct {
	Environment string `json:"environment"`
	BundleID    string `json:"bundleId"`
	Data        []struct {
		SubscriptionGroupIdentifier string `json:"subscriptionGroupIdentifier"`
		LastTransactions            []struct {
			OriginalTransactionID string `json:"originalTransactionId"`
			Status                int    `json:"status"`
			SignedTransactionInfo string `json:"signedTransactionInfo"`
			SignedRenewalInfo     string `json:"signedRenewalInfo"`
		} `json:"lastTransactions"`
	} `json:"data"`
}

type renewalPayload struct {
	AutoRenewStatus         int    `json:"autoRenewStatus"`
	AutoRenewProductID      string `json:"autoRenewProductId"`
	GracePeriodExpiresDate  int64  `json:"gracePeriodExpiresDate"`
	ExpirationIntent        int    `json:"expirationIntent"`
	IsInBillingRetryPeriod  bool   `json:"isInBillingRetryPeriod"`
	OfferIdentifier         string `json:"offerIdentifier"`
	RecentSubscriptionStart int64  `json:"recentSubscriptionStartDate"`
}

// FetchState pyta Apple o aktualny stan subskrypcji. Kolejność prób
// (produkcja → sandbox) wynika z docs/70 E19: recenzent Apple i
// TestFlight kupują w Sandboxie, ale uderzają w produkcyjny backend.
func (v *Verifier) FetchState(ctx context.Context, originalTransactionID, _ string) (billinggrpc.StoreState, error) {
	if v.signKey == nil {
		return billinggrpc.StoreState{}, errors.New("App Store Server API nie jest skonfigurowane")
	}
	var lastErr error
	for _, base := range []string{productionAPI, sandboxAPI} {
		st, err := v.fetchFrom(ctx, base, originalTransactionID)
		if err == nil {
			return st, nil
		}
		lastErr = err
	}
	return billinggrpc.StoreState{}, lastErr
}

func (v *Verifier) fetchFrom(ctx context.Context, baseURL, originalTransactionID string) (billinggrpc.StoreState, error) {
	var out billinggrpc.StoreState
	token, err := v.bearerToken()
	if err != nil {
		return out, err
	}
	url := fmt.Sprintf("%s/inApps/v1/subscriptions/%s", baseURL, originalTransactionID)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return out, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := v.http.Do(req)
	if err != nil {
		return out, err
	}
	defer func() { _ = resp.Body.Close() }()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK {
		return out, fmt.Errorf("app store api %s: %d %s", baseURL, resp.StatusCode, strings.TrimSpace(string(body)))
	}
	var sr statusResponse
	if err := json.Unmarshal(body, &sr); err != nil {
		return out, fmt.Errorf("app store api: %w", err)
	}
	for _, group := range sr.Data {
		for _, lt := range group.LastTransactions {
			if lt.OriginalTransactionID != originalTransactionID {
				continue
			}
			payload, raw, perr := v.verifyJWS(lt.SignedTransactionInfo)
			if perr != nil {
				return out, perr
			}
			st := stateFromPayload(payload, raw)
			st.Environment = normalizeEnv(firstNonEmpty(sr.Environment, st.Environment))
			applyAppleStatus(&st, lt.Status)
			if lt.SignedRenewalInfo != "" {
				if ri, rerr := v.decodeRenewal(lt.SignedRenewalInfo); rerr == nil {
					st.AutoRenew = ri.AutoRenewStatus == 1
					if ri.GracePeriodExpiresDate > 0 {
						g := msToTime(ri.GracePeriodExpiresDate)
						st.GraceUntil = &g
					}
					if ri.OfferIdentifier != "" {
						st.OfferIdentifier = ri.OfferIdentifier
					}
				}
			}
			return st, nil
		}
	}
	return out, errors.New("app store api: brak transakcji w odpowiedzi")
}

// applyAppleStatus tłumaczy status z App Store Server API. Wartości: 1 =
// aktywna, 2 = wygasła, 3 = billing retry, 4 = grace period, 5 = cofnięta.
func applyAppleStatus(st *billinggrpc.StoreState, status int) {
	switch status {
	case 1:
		st.Status = billinggrpc.StoreStatusActive
	case 2:
		st.Status = billinggrpc.StoreStatusExpired
	case 3:
		st.Status = billinggrpc.StoreStatusRetry
	case 4:
		st.Status = billinggrpc.StoreStatusGrace
	case 5:
		st.Status = billinggrpc.StoreStatusRevoked
	}
}

func (v *Verifier) decodeRenewal(jws string) (renewalPayload, error) {
	var out renewalPayload
	parts := strings.Split(jws, ".")
	if len(parts) != 3 {
		return out, errors.New("renewal jws: zły format")
	}
	// Podpis renewal info jest tym samym łańcuchem co transakcji —
	// weryfikujemy go, zamiast ufać treści.
	if _, _, err := v.verifyJWSRaw(jws); err != nil {
		return out, err
	}
	payloadJSON, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return out, err
	}
	err = json.Unmarshal(payloadJSON, &out)
	return out, err
}

// verifyJWSRaw sprawdza sam podpis, bez interpretacji payloadu.
func (v *Verifier) verifyJWSRaw(token string) ([]byte, []byte, error) {
	p, raw, err := v.verifyJWS(token)
	_ = p
	return raw, raw, err
}

// bearerToken buduje JWT wymagany przez App Store Server API.
func (v *Verifier) bearerToken() (string, error) {
	now := time.Now()
	header := map[string]any{"alg": "ES256", "kid": v.cfg.KeyID, "typ": "JWT"}
	claims := map[string]any{
		"iss": v.cfg.IssuerID,
		"iat": now.Unix(),
		"exp": now.Add(20 * time.Minute).Unix(),
		"aud": "appstoreconnect-v1",
		"bid": v.cfg.BundleID,
	}
	hb, err := json.Marshal(header)
	if err != nil {
		return "", err
	}
	cb, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}
	signingInput := base64.RawURLEncoding.EncodeToString(hb) + "." + base64.RawURLEncoding.EncodeToString(cb)
	digest := sha256.Sum256([]byte(signingInput))
	r, s, err := ecdsa.Sign(rand.Reader, v.signKey, digest[:])
	if err != nil {
		return "", err
	}
	sig := make([]byte, 64)
	r.FillBytes(sig[:32])
	s.FillBytes(sig[32:])
	return signingInput + "." + base64.RawURLEncoding.EncodeToString(sig), nil
}

// Acknowledge — Apple nie ma odpowiednika potwierdzenia zakupu; StoreKit
// finishuje transakcję po stronie klienta, dopiero po naszym OK.
func (v *Verifier) Acknowledge(context.Context, billinggrpc.StoreState) error { return nil }

// ─── helpers ──────────────────────────────────────────────────────────

func parseP8(raw string) (*ecdsa.PrivateKey, error) {
	block, _ := pem.Decode([]byte(raw))
	if block == nil {
		return nil, errors.New("nie znaleziono bloku PEM")
	}
	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	ec, ok := key.(*ecdsa.PrivateKey)
	if !ok {
		return nil, errors.New("klucz nie jest ECDSA")
	}
	return ec, nil
}

func msToTime(ms int64) time.Time {
	if ms <= 0 {
		return time.Time{}
	}
	return time.UnixMilli(ms).UTC()
}

func normalizeEnv(env string) string {
	if strings.EqualFold(env, "sandbox") {
		return "Sandbox"
	}
	return "Production"
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

// ─── App Store Server Notifications V2 ────────────────────────────────

// Notification to zdekodowana i ZWERYFIKOWANA notyfikacja z App Store.
type Notification struct {
	UUID    string
	Type    string
	Subtype string
	State   billinggrpc.StoreState
}

type notificationPayload struct {
	NotificationType string `json:"notificationType"`
	Subtype          string `json:"subtype"`
	NotificationUUID string `json:"notificationUUID"`
	Data             struct {
		BundleID              string `json:"bundleId"`
		Environment           string `json:"environment"`
		SignedTransactionInfo string `json:"signedTransactionInfo"`
		SignedRenewalInfo     string `json:"signedRenewalInfo"`
		Status                int    `json:"status"`
	} `json:"data"`
}

// DecodeNotification sprawdza podpis notyfikacji i sprowadza ją do
// wspólnego StoreState.
//
// Podpis jest tu JEDYNYM uwierzytelnieniem — endpoint notyfikacji musi
// być publiczny, bo Apple nie wysyła tokena OIDC. Dlatego weryfikacja
// łańcucha certyfikatów idzie przed jakąkolwiek interpretacją treści.
func (v *Verifier) DecodeNotification(signedPayload string) (Notification, error) {
	var out Notification
	if strings.TrimSpace(signedPayload) == "" {
		return out, errors.New("pusty signedPayload")
	}
	parts := strings.Split(signedPayload, ".")
	if len(parts) != 3 {
		return out, errors.New("notyfikacja: zły format JWS")
	}
	if _, _, err := v.verifyJWSRaw(signedPayload); err != nil {
		// verifyJWSRaw dekoduje payload do typu transakcji; dla
		// notyfikacji interesuje nas wyłącznie to, że podpis jest ważny.
		if !strings.Contains(err.Error(), "payload json") {
			return out, err
		}
	}
	body, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return out, fmt.Errorf("notyfikacja payload: %w", err)
	}
	var np notificationPayload
	if err := json.Unmarshal(body, &np); err != nil {
		return out, fmt.Errorf("notyfikacja json: %w", err)
	}
	if v.cfg.BundleID != "" && np.Data.BundleID != "" && np.Data.BundleID != v.cfg.BundleID {
		return out, fmt.Errorf("notyfikacja dotyczy innej aplikacji (%s)", np.Data.BundleID)
	}

	out.UUID = np.NotificationUUID
	out.Type = np.NotificationType
	out.Subtype = np.Subtype

	if np.Data.SignedTransactionInfo == "" {
		return out, errors.New("notyfikacja bez signedTransactionInfo")
	}
	payload, raw, err := v.verifyJWS(np.Data.SignedTransactionInfo)
	if err != nil {
		return out, err
	}
	st := stateFromPayload(payload, raw)
	st.Environment = normalizeEnv(firstNonEmpty(np.Data.Environment, st.Environment))
	if np.Data.Status != 0 {
		applyAppleStatus(&st, np.Data.Status)
	}
	if np.Data.SignedRenewalInfo != "" {
		if ri, rerr := v.decodeRenewal(np.Data.SignedRenewalInfo); rerr == nil {
			st.AutoRenew = ri.AutoRenewStatus == 1
			if ri.GracePeriodExpiresDate > 0 {
				g := msToTime(ri.GracePeriodExpiresDate)
				st.GraceUntil = &g
			}
		}
	}

	// Typ notyfikacji doprecyzowuje stan tam, gdzie sama transakcja go nie
	// niesie: REFUND/REVOKE to zwrot, GRACE_PERIOD to okno łaski,
	// EXPIRED to koniec. Reszta idzie ze statusu z API.
	switch np.NotificationType {
	case "REFUND", "REVOKE":
		st.Status = billinggrpc.StoreStatusRevoked
	case "EXPIRED":
		st.Status = billinggrpc.StoreStatusExpired
	case "DID_FAIL_TO_RENEW":
		if np.Subtype == "GRACE_PERIOD" {
			st.Status = billinggrpc.StoreStatusGrace
		} else {
			st.Status = billinggrpc.StoreStatusRetry
		}
	case "DID_RENEW", "SUBSCRIBED", "DID_CHANGE_RENEWAL_PREF", "OFFER_REDEEMED":
		if st.Status == "" {
			st.Status = billinggrpc.StoreStatusActive
		}
	}
	out.State = st
	return out, nil
}

// DecodeNotificationJSON to płaski wariant DecodeNotification używany
// przez warstwę HTTP. Handler nie musi wtedy importować tego pakietu ani
// znać jego typów — wystarczy mu interfejs o prymitywnych zwrotkach,
// który da się w teście podmienić bez certyfikatów Apple'a.
func (v *Verifier) DecodeNotificationJSON(signedPayload string) (string, string, billinggrpc.StoreState, error) {
	n, err := v.DecodeNotification(signedPayload)
	if err != nil {
		return "", "", billinggrpc.StoreState{}, err
	}
	return n.UUID, n.Type, n.State, nil
}
