package connectmd

import (
	"context"
	"testing"

	"google.golang.org/grpc/metadata"
)

func TestInjectMetadata_CopiesHeadersLowerCased(t *testing.T) {
	in := connectHeader{
		"Authorization":            {"Bearer abc.def.ghi"},
		"Content-Type":             {"application/connect+proto"},
		"Connect-Protocol-Version": {"1"},
		"X-User-Agent":             {"superwizor-web"},
	}

	ctx := injectMetadata(context.Background(), in)
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		t.Fatal("expected metadata in ctx")
	}

	cases := map[string]string{
		"authorization":            "Bearer abc.def.ghi",
		"content-type":             "application/connect+proto",
		"connect-protocol-version": "1",
		"x-user-agent":             "superwizor-web",
	}
	for k, want := range cases {
		got := md.Get(k)
		if len(got) != 1 || got[0] != want {
			t.Errorf("md[%q] = %v, want [%q]", k, got, want)
		}
	}
}

func TestInjectMetadata_DropsPseudoHeaders(t *testing.T) {
	in := connectHeader{
		":authority":    {"identity-svc.run.app"},
		":path":         {"/identity.v1.IdentityService/CreateUser"},
		"Authorization": {"Bearer t"},
	}

	ctx := injectMetadata(context.Background(), in)
	md, _ := metadata.FromIncomingContext(ctx)

	if got := md.Get(":authority"); len(got) != 0 {
		t.Errorf("expected :authority dropped, got %v", got)
	}
	if got := md.Get("authorization"); len(got) != 1 || got[0] != "Bearer t" {
		t.Errorf("authorization preserved: got %v", got)
	}
}

func TestInjectMetadata_EmptyHeaderReturnsOriginalCtx(t *testing.T) {
	// If the request has no headers we don't want to install an empty
	// IncomingContext — leave the ctx untouched so downstream calls
	// can tell "no MD" apart from "empty MD".
	type marker struct{}
	parent := context.WithValue(context.Background(), marker{}, "kept")

	ctx := injectMetadata(parent, connectHeader{})
	if ctx.Value(marker{}) != "kept" {
		t.Error("parent ctx values lost")
	}
	if _, ok := metadata.FromIncomingContext(ctx); ok {
		t.Error("did not expect IncomingContext to be installed on empty header")
	}
}

func TestInjectMetadata_MergesExistingMetadata(t *testing.T) {
	// If something upstream already populated metadata (e.g. nested
	// Connect-to-Connect handler chains, or test fixtures), preserve
	// what was there + add the new entries.
	prior := metadata.Pairs("x-trace-id", "trace-1")
	parent := metadata.NewIncomingContext(context.Background(), prior)

	ctx := injectMetadata(parent, connectHeader{
		"Authorization": {"Bearer t"},
	})
	md, _ := metadata.FromIncomingContext(ctx)
	if got := md.Get("x-trace-id"); len(got) != 1 || got[0] != "trace-1" {
		t.Errorf("prior md lost: %v", got)
	}
	if got := md.Get("authorization"); len(got) != 1 || got[0] != "Bearer t" {
		t.Errorf("authorization missing: %v", got)
	}
}
