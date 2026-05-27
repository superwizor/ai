package cors

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// passthrough is the inner handler used by every test. It records
// whether the chain reached it, so we can assert on pass-through vs
// short-circuit behaviour.
type passthrough struct {
	called bool
}

func (p *passthrough) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	p.called = true
	w.WriteHeader(http.StatusOK)
}

func TestNew_AllowsExactMatchOrigin(t *testing.T) {
	mw := New(Config{
		AllowedOrigins: []string{"https://app.superwizor.ai"},
	})
	inner := &passthrough{}
	h := mw(inner)

	req := httptest.NewRequest(http.MethodPost, "/identity.v1.IdentityService/HealthCheck", nil)
	req.Header.Set("Origin", "https://app.superwizor.ai")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "https://app.superwizor.ai" {
		t.Errorf("ACAO header = %q, want %q", got, "https://app.superwizor.ai")
	}
	if !inner.called {
		t.Error("inner handler should have been called on allowed origin")
	}
	if !strings.Contains(rec.Header().Get("Vary"), "Origin") {
		t.Errorf("Vary header should include Origin, got %q", rec.Header().Get("Vary"))
	}
}

func TestNew_PreflightShortCircuits(t *testing.T) {
	mw := New(Config{
		AllowedOrigins: []string{"https://app.superwizor.ai"},
	})
	inner := &passthrough{}
	h := mw(inner)

	req := httptest.NewRequest(http.MethodOptions, "/identity.v1.IdentityService/Anything", nil)
	req.Header.Set("Origin", "https://app.superwizor.ai")
	req.Header.Set("Access-Control-Request-Method", "POST")
	req.Header.Set("Access-Control-Request-Headers", "Authorization, Connect-Protocol-Version")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("preflight should return 204, got %d", rec.Code)
	}
	if inner.called {
		t.Error("inner handler should NOT be called on preflight")
	}
	if got := rec.Header().Get("Access-Control-Allow-Methods"); !strings.Contains(got, "POST") {
		t.Errorf("Allow-Methods missing POST: %q", got)
	}
	if got := rec.Header().Get("Access-Control-Allow-Headers"); !strings.Contains(got, "Authorization") {
		t.Errorf("Allow-Headers missing Authorization: %q", got)
	}
	if got := rec.Header().Get("Access-Control-Max-Age"); got != "3600" {
		t.Errorf("Max-Age = %q, want 3600", got)
	}
}

func TestNew_DisallowedOriginPreflightReturns403(t *testing.T) {
	mw := New(Config{
		AllowedOrigins: []string{"https://app.superwizor.ai"},
	})
	inner := &passthrough{}
	h := mw(inner)

	req := httptest.NewRequest(http.MethodOptions, "/foo", nil)
	req.Header.Set("Origin", "https://evil.example.com")
	req.Header.Set("Access-Control-Request-Method", "POST")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("disallowed preflight should return 403, got %d", rec.Code)
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Errorf("ACAO must NOT be set for disallowed origin, got %q", got)
	}
}

func TestNew_DisallowedOriginNonPreflightStillPassesThrough(t *testing.T) {
	// Server-to-server callers (no Origin) or unknown Origins that send
	// real requests still get processed by the handler; the browser
	// blocks the response client-side via the missing ACAO header.
	// This lets observability record the call.
	mw := New(Config{
		AllowedOrigins: []string{"https://app.superwizor.ai"},
	})
	inner := &passthrough{}
	h := mw(inner)

	req := httptest.NewRequest(http.MethodPost, "/foo", nil)
	req.Header.Set("Origin", "https://evil.example.com")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if !inner.called {
		t.Error("inner handler should still run on disallowed origin non-preflight")
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Errorf("ACAO must be empty for disallowed origin, got %q", got)
	}
}

func TestNew_NoOriginPassesThroughUntouched(t *testing.T) {
	// Same-origin requests (and server-to-server calls from Cloud Run)
	// don't include an Origin header. Middleware must not interfere.
	mw := New(Config{
		AllowedOrigins: []string{"https://app.superwizor.ai"},
	})
	inner := &passthrough{}
	h := mw(inner)

	req := httptest.NewRequest(http.MethodPost, "/grpc.health.v1.Health/Check", nil)
	// No Origin header.
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if !inner.called {
		t.Error("inner handler should run when no Origin present")
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Errorf("ACAO must not be set when no Origin present, got %q", got)
	}
	if got := rec.Header().Get("Vary"); strings.Contains(got, "Origin") {
		t.Errorf("Vary header should not include Origin when no Origin sent")
	}
}

func TestNew_CredentialsHeaderRespected(t *testing.T) {
	mw := New(Config{
		AllowedOrigins:   []string{"https://app.superwizor.ai"},
		AllowCredentials: true,
	})
	inner := &passthrough{}
	h := mw(inner)

	req := httptest.NewRequest(http.MethodPost, "/foo", nil)
	req.Header.Set("Origin", "https://app.superwizor.ai")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if got := rec.Header().Get("Access-Control-Allow-Credentials"); got != "true" {
		t.Errorf("Allow-Credentials = %q, want true", got)
	}
}

func TestFromEnv_ParsesCommaSeparated(t *testing.T) {
	cfg := FromEnv("https://superwizor.ai, https://app.superwizor.ai ,  http://localhost:3000")
	want := []string{"https://superwizor.ai", "https://app.superwizor.ai", "http://localhost:3000"}
	if len(cfg.AllowedOrigins) != len(want) {
		t.Fatalf("got %d origins, want %d", len(cfg.AllowedOrigins), len(want))
	}
	for i, w := range want {
		if cfg.AllowedOrigins[i] != w {
			t.Errorf("origin %d = %q, want %q", i, cfg.AllowedOrigins[i], w)
		}
	}
	if !cfg.AllowCredentials {
		t.Error("AllowCredentials should default to true")
	}
}

func TestFromEnv_EmptyString(t *testing.T) {
	cfg := FromEnv("")
	if len(cfg.AllowedOrigins) != 0 {
		t.Errorf("empty env should yield zero origins, got %v", cfg.AllowedOrigins)
	}
}

func TestItoa(t *testing.T) {
	cases := []struct {
		in   int
		want string
	}{
		{0, "0"},
		{1, "1"},
		{3600, "3600"},
		{7200, "7200"},
	}
	for _, c := range cases {
		if got := itoa(c.in); got != c.want {
			t.Errorf("itoa(%d) = %q, want %q", c.in, got, c.want)
		}
	}
}
