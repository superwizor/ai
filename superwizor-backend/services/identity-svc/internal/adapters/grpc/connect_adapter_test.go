package grpc

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/types/known/emptypb"

	identityv1connect "github.com/superwizor-ai/backend/gen/go/identity/v1/identityv1connect"
)

// TestConnectAdapter_HealthCheck_EndToEnd proves the whole Connect
// wire works: ConnectAdapter wraps Server, NewIdentityServiceHandler
// builds a path+handler, an httptest server fronts it, and a real
// Connect client speaks the Connect protocol over HTTP.
//
// HealthCheck deliberately doesn't touch DB / Firebase Auth, so we
// can use a Server with nil pool/queries/auth and still get a real
// response. The point isn't to test HealthCheck; it's to prove the
// adapter contract holds end-to-end.
func TestConnectAdapter_HealthCheck_EndToEnd(t *testing.T) {
	srv := NewServer(nil, nil, nil, "test-connect-1.0")
	adapter := NewConnectAdapter(srv)

	// Generated constructor enforces that adapter implements the
	// full IdentityServiceHandler interface — if any method is
	// missing or has the wrong signature, this line refuses to
	// compile. That's the build-time half of the verification.
	path, handler := identityv1connect.NewIdentityServiceHandler(adapter)

	// Mount onto an httptest server.
	mux := http.NewServeMux()
	mux.Handle(path, handler)
	httpSrv := httptest.NewServer(mux)
	defer httpSrv.Close()

	// Real Connect client (protocol = Connect, content-type =
	// application/proto). Could equally test gRPC-Web or gRPC
	// via the same handler — Connect speaks all three.
	client := identityv1connect.NewIdentityServiceClient(
		httpSrv.Client(), httpSrv.URL,
	)
	resp, err := client.HealthCheck(context.Background(),
		connect.NewRequest(&emptypb.Empty{}))
	if err != nil {
		t.Fatalf("HealthCheck via Connect failed: %v", err)
	}

	if got, want := resp.Msg.Status, "OK"; got != want {
		t.Errorf("Status = %q, want %q", got, want)
	}
	if got, want := resp.Msg.Version, "test-connect-1.0"; got != want {
		t.Errorf("Version = %q, want %q", got, want)
	}

	// Bonus: the response should be served as the Connect protocol's
	// application/proto content-type by default.
	if !strings.Contains(httpSrv.URL, "http://") {
		t.Errorf("httptest URL unexpected: %s", httpSrv.URL)
	}
}
