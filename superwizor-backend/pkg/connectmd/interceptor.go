// Package connectmd bridges Connect-RPC HTTP request headers into
// gRPC incoming metadata on the request context.
//
// Why this exists: services in this monorepo implement their RPCs
// against the generated gRPC server interface (because that's the
// transport iOS uses). They expose the SAME implementations through
// a thin ConnectAdapter so browser callers can use Connect-RPC over
// HTTP/2 with `Content-Type: application/connect+proto`.
//
// The gap: connect-go gives each handler a connect.Request whose
// HTTP headers live on `req.Header()`. The wrapped gRPC server expects
// metadata in the context via `metadata.FromIncomingContext(ctx)`.
// Connect doesn't copy headers into gRPC metadata automatically —
// the two are different libraries with different conventions.
//
// Result: any RPC that authenticates via `metadata.FromIncomingContext`
// returns Unauthenticated when called from Connect, even with a
// perfectly valid Authorization header on the HTTP request. The
// header was on req.Header() but never reached the gRPC ctx.
//
// This interceptor closes that gap. Registered once per service via
// `connect.WithInterceptors(connectmd.HeadersToGRPCMetadata())`, it
// copies every incoming HTTP header into the ctx as gRPC metadata
// (lower-cased keys per gRPC convention). The wrapped server's
// existing `requireUserFromMetadata` / `metadata.FromIncomingContext`
// calls then work identically whether the request arrived as native
// gRPC (from iOS) or as Connect (from the browser).
//
// Discovered 2026-05-28 during /pl/register/therapist signup debug:
// UpdateProfile kept returning `code = Unauthenticated desc = no gRPC
// metadata` because the Connect adapter passed ctx through unchanged.
// Marketing-site sent the Bearer token; nothing on the server saw it.
package connectmd

import (
	"context"
	"strings"

	"connectrpc.com/connect"
	"google.golang.org/grpc/metadata"
)

// HeadersToGRPCMetadata returns a Connect interceptor that copies all
// HTTP headers from the request into the ctx as gRPC IncomingMetadata.
// Headers are lower-cased to match gRPC convention (gRPC metadata
// keys are case-insensitive but canonicalised to lower-case by the
// runtime).
//
// Pseudo-headers (':authority', ':path' etc) are skipped — they
// have no gRPC equivalent and code that asks for them via metadata
// is misusing the API.
//
// The interceptor runs on both unary and streaming RPCs; the
// streaming path is included so future server-streaming endpoints
// (e.g. transcript watch) work out of the box.
func HeadersToGRPCMetadata() connect.UnaryInterceptorFunc {
	return func(next connect.UnaryFunc) connect.UnaryFunc {
		return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
			return next(injectMetadata(ctx, req.Header()), req)
		}
	}
}

// injectMetadata is the workhorse — kept exported-package-private so
// tests can drive it without spinning up a full Connect handler.
func injectMetadata(ctx context.Context, header connectHeader) context.Context {
	md := metadata.New(nil)
	for k, vv := range header {
		if strings.HasPrefix(k, ":") {
			continue
		}
		md.Set(strings.ToLower(k), vv...)
	}
	if md.Len() == 0 {
		return ctx
	}
	// If the caller already populated metadata (e.g. nested calls),
	// merge rather than replace — gRPC metadata semantics support
	// duplicate keys.
	if existing, ok := metadata.FromIncomingContext(ctx); ok {
		md = metadata.Join(existing, md)
	}
	return metadata.NewIncomingContext(ctx, md)
}

// connectHeader is the minimal shape we need from connect.Header().
// Aliased so injectMetadata is unit-testable with a plain map[string][]string
// without importing all of connect.
type connectHeader = map[string][]string
