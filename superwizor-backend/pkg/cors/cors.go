// Package cors provides the shared CORS middleware used by every Cloud Run
// service that fronts a browser-reachable HTTP listener.
//
// Reference: docs/18_WEB_APP_DESIGN.md §5 (R2 — without this middleware the
// browser rejects every Connect-RPC pre-flight).
//
// Design choices:
//
//   - Allowed-origins list is an explicit allowlist, never wildcarded.
//     We accept the maintenance overhead of adding new origins by hand —
//     the alternative ("Access-Control-Allow-Origin: *") forbids cookies
//     and credentials, and we deliberately want auth headers on these
//     requests.
//
//   - Allowed methods are POST + OPTIONS only. Connect-RPC and gRPC-Web
//     are both POST-shaped. Admin HTTP endpoints (e.g. billing-svc
//     /admin/*) are also POST.  GET is not in the allowlist because the
//     browser would only ever GET via XHR for things like health checks,
//     which can use a simple-request path that bypasses pre-flight.
//
//   - Allowed headers cover what Connect-RPC, gRPC-Web, and Firebase
//     auth pre-flight checks need. Anything else triggers a fresh
//     pre-flight which is a clear signal something is misconfigured.
//
//   - Pre-flight responses are cached for an hour (Access-Control-Max-Age:
//     3600). Browsers cap this at 7200; we stay conservative.
//
//   - Vary: Origin is always set so a downstream cache (CDN, browser
//     intermediate) doesn't serve a response for origin A back to a
//     request from origin B.
package cors

import (
	"net/http"
	"strings"
)

// Default headers a Connect-RPC + Firebase auth client sends on a
// cross-origin request. Each entry triggers a pre-flight on first
// request from the origin.
var defaultAllowedHeaders = []string{
	"Authorization",
	"Content-Type",
	// Connect protocol headers (https://connectrpc.com/docs/protocol/).
	"Connect-Protocol-Version",
	"Connect-Timeout-Ms",
	// gRPC-Web protocol marker (Flutter Web's
	// GrpcOrGrpcWebClientChannel sends it).
	"X-Grpc-Web",
	// Per-platform user-agent (the existing Flutter app sends this).
	"X-User-Agent",
	// Idempotency-Key header used on mutation RPCs (pkg/idempotency).
	"Idempotency-Key",
}

// Default headers we expose to the browser so the Connect client can
// read trailers and status without a follow-up request.
var defaultExposedHeaders = []string{
	"Grpc-Status",
	"Grpc-Message",
}

// Config controls the middleware behaviour.
type Config struct {
	// AllowedOrigins lists exact-match origins the middleware
	// approves. An empty list rejects everything except same-origin
	// (which the browser doesn't pre-flight anyway).
	AllowedOrigins []string

	// AllowedHeaders, if nil, defaults to the package-level
	// defaultAllowedHeaders.
	AllowedHeaders []string

	// ExposedHeaders, if nil, defaults to the package-level
	// defaultExposedHeaders.
	ExposedHeaders []string

	// AllowCredentials controls Access-Control-Allow-Credentials.
	// We default to true because the Connect client sends
	// `Authorization: Bearer …` and that counts as a credential.
	AllowCredentials bool

	// MaxAgeSeconds is the Access-Control-Max-Age value on
	// preflight responses. Browsers cap at 7200; we default to 3600.
	MaxAgeSeconds int
}

// New returns an http.Handler middleware that applies CORS headers to
// every response and short-circuits OPTIONS pre-flight requests with a
// 204 No Content.
func New(cfg Config) func(http.Handler) http.Handler {
	if cfg.AllowedHeaders == nil {
		cfg.AllowedHeaders = defaultAllowedHeaders
	}
	if cfg.ExposedHeaders == nil {
		cfg.ExposedHeaders = defaultExposedHeaders
	}
	if cfg.MaxAgeSeconds == 0 {
		cfg.MaxAgeSeconds = 3600
	}

	allowedOriginsSet := make(map[string]struct{}, len(cfg.AllowedOrigins))
	for _, o := range cfg.AllowedOrigins {
		allowedOriginsSet[o] = struct{}{}
	}

	allowedHeadersJoined := strings.Join(cfg.AllowedHeaders, ", ")
	exposedHeadersJoined := strings.Join(cfg.ExposedHeaders, ", ")

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")

			// Same-origin requests never include an Origin header
			// (or send the page's own origin). The browser doesn't
			// enforce CORS on those — pass through.
			if origin == "" {
				next.ServeHTTP(w, r)
				return
			}

			// Vary on Origin so caches don't blend responses
			// across origins.
			w.Header().Add("Vary", "Origin")

			if _, ok := allowedOriginsSet[origin]; !ok {
				// Disallowed origin. Don't emit ACAO headers; the
				// browser will reject the response. We still
				// forward the request to the handler so the
				// observability layer can record the rejection,
				// but the response will fail at the browser side.
				// Pre-flight gets a 403 to make the failure
				// obvious in DevTools.
				if r.Method == http.MethodOptions &&
					r.Header.Get("Access-Control-Request-Method") != "" {
					http.Error(w, "origin not allowed", http.StatusForbidden)
					return
				}
				next.ServeHTTP(w, r)
				return
			}

			w.Header().Set("Access-Control-Allow-Origin", origin)
			if cfg.AllowCredentials {
				w.Header().Set("Access-Control-Allow-Credentials", "true")
			}
			if exposedHeadersJoined != "" {
				w.Header().Set("Access-Control-Expose-Headers", exposedHeadersJoined)
			}

			// Pre-flight. Browser asks "can I send X to this origin?"
			// before sending the real request. We answer yes if the
			// origin is allowed and short-circuit the response.
			if r.Method == http.MethodOptions &&
				r.Header.Get("Access-Control-Request-Method") != "" {
				w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
				w.Header().Set("Access-Control-Allow-Headers", allowedHeadersJoined)
				if cfg.MaxAgeSeconds > 0 {
					w.Header().Set("Access-Control-Max-Age",
						itoa(cfg.MaxAgeSeconds))
				}
				w.WriteHeader(http.StatusNoContent)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// FromEnv parses a comma-separated CORS_ALLOWED_ORIGINS env var into a
// Config with all other fields at defaults (credentials on, 1-hour
// cache). Use this in cmd/server/main.go to keep wiring trivial.
func FromEnv(envValue string) Config {
	parts := strings.Split(envValue, ",")
	origins := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			origins = append(origins, p)
		}
	}
	return Config{
		AllowedOrigins:   origins,
		AllowCredentials: true,
	}
}

// itoa is a tiny stdlib-free integer to ASCII so we don't drag strconv
// into this package's API surface. CORS_MAX_AGE is always small (<=
// 7200) so the conversion is trivial.
func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}
