package appstore

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"math/big"
	"strings"
	"testing"
	"time"

	billinggrpc "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/grpc"
)

// Testy weryfikacji podpisu StoreKit 2 (docs/70 §7.3).
//
// Nie da się ich napisać na prawdziwym łańcuchu Apple'a — nie mamy jego
// klucza prywatnego. Budujemy więc własny łańcuch root → intermediate →
// leaf i podajemy nasz root jako zaufany. Sprawdzana logika (parsowanie
// x5c, budowa puli pośrednich, Verify, ECDSA nad "header.payload") jest
// dokładnie ta sama, którą wykona produkcja z certyfikatem Apple'a.

type testChain struct {
	rootPEM  string
	leafKey  *ecdsa.PrivateKey
	x5c      []string // leaf, intermediate, root — kolejność jak u Apple'a
	otherPEM string   // niepowiązany root, do testu odrzucenia
}

func newCert(t *testing.T, tmpl, parent *x509.Certificate, pub *ecdsa.PublicKey, signer *ecdsa.PrivateKey) (*x509.Certificate, []byte) {
	t.Helper()
	der, err := x509.CreateCertificate(rand.Reader, tmpl, parent, pub, signer)
	if err != nil {
		t.Fatalf("CreateCertificate: %v", err)
	}
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		t.Fatalf("ParseCertificate: %v", err)
	}
	return cert, der
}

func buildChain(t *testing.T) testChain {
	t.Helper()
	now := time.Now()

	mkCA := func(cn string) (*ecdsa.PrivateKey, *x509.Certificate, []byte) {
		key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
		if err != nil {
			t.Fatalf("GenerateKey: %v", err)
		}
		tmpl := &x509.Certificate{
			SerialNumber:          big.NewInt(now.UnixNano()),
			Subject:               pkix.Name{CommonName: cn},
			NotBefore:             now.Add(-time.Hour),
			NotAfter:              now.Add(24 * time.Hour),
			IsCA:                  true,
			BasicConstraintsValid: true,
			KeyUsage:              x509.KeyUsageCertSign,
		}
		cert, der := newCert(t, tmpl, tmpl, &key.PublicKey, key)
		return key, cert, der
	}

	rootKey, rootCert, rootDER := mkCA("Test Root CA")

	interKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("GenerateKey: %v", err)
	}
	interTmpl := &x509.Certificate{
		SerialNumber:          big.NewInt(2),
		Subject:               pkix.Name{CommonName: "Test Intermediate"},
		NotBefore:             now.Add(-time.Hour),
		NotAfter:              now.Add(24 * time.Hour),
		IsCA:                  true,
		BasicConstraintsValid: true,
		KeyUsage:              x509.KeyUsageCertSign,
	}
	interCert, interDER := newCert(t, interTmpl, rootCert, &interKey.PublicKey, rootKey)

	leafKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("GenerateKey: %v", err)
	}
	leafTmpl := &x509.Certificate{
		SerialNumber: big.NewInt(3),
		Subject:      pkix.Name{CommonName: "Test Leaf"},
		NotBefore:    now.Add(-time.Hour),
		NotAfter:     now.Add(24 * time.Hour),
		KeyUsage:     x509.KeyUsageDigitalSignature,
	}
	_, leafDER := newCert(t, leafTmpl, interCert, &leafKey.PublicKey, interKey)

	_, _, otherRootDER := mkCA("Unrelated Root CA")

	toPEM := func(der []byte) string {
		return string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}))
	}
	return testChain{
		rootPEM: toPEM(rootDER),
		leafKey: leafKey,
		x5c: []string{
			base64.StdEncoding.EncodeToString(leafDER),
			base64.StdEncoding.EncodeToString(interDER),
			base64.StdEncoding.EncodeToString(rootDER),
		},
		otherPEM: toPEM(otherRootDER),
	}
}

func signJWS(t *testing.T, chain testChain, payload any) string {
	t.Helper()
	header := map[string]any{"alg": "ES256", "x5c": chain.x5c}
	hb, err := json.Marshal(header)
	if err != nil {
		t.Fatalf("marshal header: %v", err)
	}
	pb, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}
	signing := base64.RawURLEncoding.EncodeToString(hb) + "." + base64.RawURLEncoding.EncodeToString(pb)
	digest := sha256.Sum256([]byte(signing))
	r, s, err := ecdsa.Sign(rand.Reader, chain.leafKey, digest[:])
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	sig := make([]byte, 64)
	r.FillBytes(sig[:32])
	s.FillBytes(sig[32:])
	return signing + "." + base64.RawURLEncoding.EncodeToString(sig)
}

func transaction(expiresIn time.Duration) map[string]any {
	now := time.Now()
	return map[string]any{
		"transactionId":         "2000000123456789",
		"originalTransactionId": "2000000000000001",
		"bundleId":              "ai.superwizor.superwizor",
		"productId":             "ai.superwizor.solo.monthly",
		"purchaseDate":          now.Add(-time.Minute).UnixMilli(),
		"expiresDate":           now.Add(expiresIn).UnixMilli(),
		"environment":           "Sandbox",
		"appAccountToken":       "9f1e4f0a-0000-4000-8000-000000000001",
		"type":                  "Auto-Renewable Subscription",
	}
}

func TestNewRequiresRootCA(t *testing.T) {
	// Bez korzenia CA nie da się niczego zweryfikować. Lepiej nie
	// zarejestrować weryfikatora niż udawać, że sprawdzamy zakupy.
	if _, err := New(Config{BundleID: "ai.superwizor.superwizor"}); err == nil {
		t.Fatal("oczekiwano błędu przy braku APPLE_ROOT_CA_PEM")
	}
}

func TestVerifyPurchase(t *testing.T) {
	chain := buildChain(t)
	v, err := New(Config{BundleID: "ai.superwizor.superwizor", RootCAPEM: chain.rootPEM})
	if err != nil {
		t.Fatalf("New: %v", err)
	}

	t.Run("bez klucza API stan wychodzi z samej transakcji", func(t *testing.T) {
		// Ścieżka degradacji: brak APPLE_PRIVATE_KEY_P8 = nie pytamy App
		// Store Server API, więc nie wychodzimy do sieci w teście.
		token := signJWS(t, chain, transaction(30*24*time.Hour))
		st, verr := v.VerifyPurchase(context.Background(), billinggrpc.StoreProof{JWSTransaction: token})
		if verr != nil {
			t.Fatalf("VerifyPurchase: %v", verr)
		}
		if st.Status != "ACTIVE" || st.ProductID != "ai.superwizor.solo.monthly" {
			t.Errorf("stan = %+v", st)
		}
		if st.AppAccountToken != "9f1e4f0a-0000-4000-8000-000000000001" {
			t.Errorf("appAccountToken = %q — bez niego nie da się przypisać zakupu do konta", st.AppAccountToken)
		}
	})

	t.Run("transakcja z cudzej aplikacji jest odrzucana", func(t *testing.T) {
		body := transaction(30 * 24 * time.Hour)
		body["bundleId"] = "com.someone.else"
		token := signJWS(t, chain, body)
		if _, verr := v.VerifyPurchase(context.Background(), billinggrpc.StoreProof{JWSTransaction: token}); verr == nil {
			t.Fatal("transakcja z innego bundle ID przeszła weryfikację")
		}
	})

	t.Run("pusty dowód zakupu", func(t *testing.T) {
		if _, verr := v.VerifyPurchase(context.Background(), billinggrpc.StoreProof{}); verr == nil {
			t.Fatal("pusty JWS przeszedł weryfikację")
		}
	})
}

func TestVerifyJWS(t *testing.T) {
	chain := buildChain(t)
	v, err := New(Config{BundleID: "ai.superwizor.superwizor", RootCAPEM: chain.rootPEM})
	if err != nil {
		t.Fatalf("New: %v", err)
	}

	t.Run("poprawnie podpisana transakcja przechodzi", func(t *testing.T) {
		token := signJWS(t, chain, transaction(30*24*time.Hour))
		payload, _, err := v.verifyJWS(token)
		if err != nil {
			t.Fatalf("verifyJWS: %v", err)
		}
		if payload.OriginalTransactionID != "2000000000000001" {
			t.Errorf("originalTransactionId = %q", payload.OriginalTransactionID)
		}
		if payload.ProductID != "ai.superwizor.solo.monthly" {
			t.Errorf("productId = %q", payload.ProductID)
		}
	})

	t.Run("podmieniony payload jest odrzucany", func(t *testing.T) {
		token := signJWS(t, chain, transaction(30*24*time.Hour))
		parts := strings.Split(token, ".")
		tampered := transaction(30 * 24 * time.Hour)
		tampered["productId"] = "ai.superwizor.pro.annual" // klient chce droższy plan za darmo
		pb, _ := json.Marshal(tampered)
		parts[1] = base64.RawURLEncoding.EncodeToString(pb)
		if _, _, err := v.verifyJWS(strings.Join(parts, ".")); err == nil {
			t.Fatal("podmieniony payload przeszedł weryfikację")
		}
	})

	t.Run("łańcuch spoza zaufanego korzenia jest odrzucany", func(t *testing.T) {
		other, err := New(Config{RootCAPEM: chain.otherPEM})
		if err != nil {
			t.Fatalf("New: %v", err)
		}
		token := signJWS(t, chain, transaction(time.Hour))
		if _, _, err := other.verifyJWS(token); err == nil {
			t.Fatal("łańcuch podpisany obcym korzeniem przeszedł weryfikację")
		}
	})

	t.Run("brak łańcucha certyfikatów", func(t *testing.T) {
		if _, _, err := v.verifyJWS("a.b.c"); err == nil {
			t.Fatal("śmieciowy token przeszedł weryfikację")
		}
	})
}

func TestStateFromPayload(t *testing.T) {
	t.Run("aktywna subskrypcja", func(t *testing.T) {
		var p transactionPayload
		raw, _ := json.Marshal(transaction(30 * 24 * time.Hour))
		if err := json.Unmarshal(raw, &p); err != nil {
			t.Fatal(err)
		}
		st := stateFromPayload(p, raw)
		if st.Status != "ACTIVE" {
			t.Errorf("status = %q, chciano ACTIVE", st.Status)
		}
		if st.Environment != "Sandbox" {
			t.Errorf("environment = %q, chciano Sandbox", st.Environment)
		}
		if st.Provider != "APPLE_IAP" {
			t.Errorf("provider = %q", st.Provider)
		}
	})

	t.Run("wygasła subskrypcja", func(t *testing.T) {
		var p transactionPayload
		raw, _ := json.Marshal(transaction(-time.Hour))
		if err := json.Unmarshal(raw, &p); err != nil {
			t.Fatal(err)
		}
		if st := stateFromPayload(p, raw); st.Status != "EXPIRED" {
			t.Errorf("status = %q, chciano EXPIRED", st.Status)
		}
	})

	t.Run("zwrot ma pierwszeństwo nad datą wygaśnięcia", func(t *testing.T) {
		body := transaction(30 * 24 * time.Hour)
		body["revocationDate"] = time.Now().UnixMilli()
		body["revocationReason"] = 1
		raw, _ := json.Marshal(body)
		var p transactionPayload
		if err := json.Unmarshal(raw, &p); err != nil {
			t.Fatal(err)
		}
		st := stateFromPayload(p, raw)
		if st.Status != "REVOKED" {
			t.Errorf("status = %q, chciano REVOKED", st.Status)
		}
		if st.RevocationDate == nil {
			t.Error("brak daty zwrotu")
		}
	})
}

func TestApplyAppleStatus(t *testing.T) {
	// Mapowanie statusów App Store Server API: 1 aktywna, 2 wygasła,
	// 3 billing retry, 4 grace, 5 cofnięta.
	cases := map[int]string{1: "ACTIVE", 2: "EXPIRED", 3: "RETRY", 4: "GRACE", 5: "REVOKED"}
	for code, want := range cases {
		var st billinggrpc.StoreState
		applyAppleStatus(&st, code)
		if st.Status != want {
			t.Errorf("status %d → %q, chciano %q", code, st.Status, want)
		}
	}
}
