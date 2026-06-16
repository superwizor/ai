// billing-svc Phase 3 entrypoint.
//
// Jeden HTTP/2 listener na PORT (default :8080) obsługujący:
//   - gRPC requests (Content-Type: application/grpc) → BillingService
//   - HTTP/1.1 + HTTP/2 plaintext → admin cron endpoints + Stripe stub
//
// Cloud Run akceptuje jeden port per service, więc nie można rozdzielić
// na dwa listenery (jak w sample architekturze gdzie wszystko ma osobne
// rejestrowane SAs). Używamy h2c muxa: handler dispatcher patrzy na
// Content-Type i routuje do grpcServer.ServeHTTP albo zwykłego HTTP muxa.
//
// Pattern (oficjalny gRPC docs / Cloud Run docs): kompatybilny zarówno z
// `gcloud run deploy --use-http2` jak i z Cloud Scheduler OIDC POSTami.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	nethttp "net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/api/idtoken"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/credentials/oauth"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
	"net/url"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	billingv1connect "github.com/superwizor-ai/backend/gen/go/billing/v1/billingv1connect"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
	"connectrpc.com/connect"

	"github.com/superwizor-ai/backend/pkg/analytics"
	"github.com/superwizor-ai/backend/pkg/connectmd"
	"github.com/superwizor-ai/backend/pkg/cors"
	grpcadapter "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/grpc"
	httpadapter "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/http"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	port := getEnv("PORT", "8080")
	version := getEnv("VERSION", "phase3-v1")

	dbDSN := os.Getenv("DATABASE_URL")
	if dbDSN == "" {
		dbUser := os.Getenv("DB_USER")
		dbPass := os.Getenv("DB_PASSWORD")
		dbHost := os.Getenv("DB_HOST")
		dbName := os.Getenv("DB_NAME")
		if dbUser != "" && dbPass != "" && dbHost != "" && dbName != "" {
			dbDSN = fmt.Sprintf("postgres://%s:%s@%s:5432/%s?sslmode=disable",
				dbUser, dbPass, dbHost, dbName)
		}
	}
	if dbDSN == "" {
		slog.Error("DATABASE_URL (or DB_USER/PASS/HOST/NAME) required")
		os.Exit(1)
	}

	rootCtx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	// Bounded pool — billing-svc gets 2 because it runs both the gRPC
	// handlers AND an in-process outbox poller goroutine that selects
	// from outbox_events. Single-conn would starve one or the other.
	// See docs/17 §11 for the cross-service budget table.
	poolCfg, err := pgxpool.ParseConfig(dbDSN)
	if err != nil {
		slog.Error("parse db dsn", "error", err)
		os.Exit(1)
	}
	poolCfg.MaxConns = 2
	poolCfg.MinConns = 0
	poolCfg.MaxConnIdleTime = 30 * time.Second
	pool, err := pgxpool.NewWithConfig(rootCtx, poolCfg)
	if err != nil {
		slog.Error("db connect failed", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	analyticsCollector := analytics.NewCollector(pool)
	defer analyticsCollector.Shutdown()

	// Phase C of feat/billing-svc-refactor removed the outbox poller +
	// Pub/Sub publisher + edge-threshold WithThresholds wiring. The
	// client-cache model (clinical-svc.GetMyBillingState + state_after
	// on Reservation/UsageCommit) is the only way state propagates now.

	// Dial identity-svc so the Connect auth interceptor below can
	// validate the Firebase token coming from browser callers and
	// resolve role + user_id + org_id. Server-to-server callers (on
	// the native gRPC path) bypass this — they already supply the
	// x-superwizor-* metadata themselves.
	//
	// Optional: if IDENTITY_SVC_URL is unset, the interceptor is
	// skipped entirely (admin RPCs will continue to require upstream
	// metadata, which is fine for local dev / contract tests).
	identityURL := os.Getenv("IDENTITY_SVC_URL")
	var identityClient identityv1.IdentityServiceClient
	if identityURL != "" {
		identityClient = dialIdentitySvc(rootCtx, identityURL)
	}

	notificationURL := os.Getenv("NOTIFICATION_SVC_URL")
	var notificationClient notificationv1.NotificationServiceClient
	if notificationURL != "" {
		notificationClient = dialNotificationSvc(rootCtx, notificationURL)
	} else {
		slog.Warn("billing-svc: NOTIFICATION_SVC_URL unset — /contact endpoint will fail to forward submissions")
	}

	billingServer := grpcadapter.NewServer(pool, version, analyticsCollector)

	// gRPC server (in-process — handler reused via ServeHTTP).
	gs := grpc.NewServer()
	billingv1.RegisterBillingServiceServer(gs, billingServer)
	hs := health.NewServer()
	hs.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(gs, hs)
	reflection.Register(gs)

	// HTTP mux (admin crons + Stripe stub + /healthz + Connect-RPC).
	httpMux := nethttp.NewServeMux()
	// Route-level admin auth for the browser-facing CRM endpoints —
	// billing-svc is publicly invokable, so this middleware is the only
	// gate (2026-06-10 exposure fix). Fail-closed when identity-svc is
	// not wired.
	adminAuth := httpadapter.NewAdminAuthMiddleware(identityClient, logger)
	// Google OIDC auth for the Cloud Scheduler cron endpoints — same
	// exposure as the CRM fix above: allUsers invoker means Cloud Run
	// IAM never checks the scheduler's token, so the app must. Audience
	// = billing-svc's own Cloud Run URL (what billing_crons.tf mints),
	// allowed email = the cloud-scheduler-billing SA. Fail-closed: when
	// either env is unset the cron routes return 503.
	schedAudience := os.Getenv("SCHEDULER_OIDC_AUDIENCE")
	schedSAEmail := os.Getenv("SCHEDULER_SA_EMAIL")
	if schedAudience == "" || schedSAEmail == "" {
		slog.Warn("billing-svc: SCHEDULER_OIDC_AUDIENCE / SCHEDULER_SA_EMAIL unset — cron endpoints will refuse all requests (503)")
	}
	schedAuth := httpadapter.NewSchedulerAuthMiddleware(schedAudience, schedSAEmail, logger)
	httpadapter.NewAdminHandler(pool, logger).RegisterRoutes(httpMux, adminAuth, schedAuth)
	httpadapter.NewCRMHandler(pool, logger).RegisterCRMRoutes(httpMux, adminAuth)
	httpadapter.NewStripeHandler(pool, logger, identityClient).RegisterRoutes(httpMux)
	httpadapter.NewCheckoutHandler(logger).RegisterRoutes(httpMux)
	httpadapter.NewContactHandler(notificationClient, logger).RegisterRoutes(httpMux)
	// Connect-RPC surface — browser callers reach the same business
	// logic as the gRPC path via the ConnectAdapter. The connectmd
	// interceptor copies HTTP request headers into the ctx as gRPC
	// IncomingMetadata so auth helpers that read metadata.FromIncomingContext
	// see the Authorization Bearer header. Without it Connect requests
	// land at metadata-checking handlers with `code = Unauthenticated
	// desc = no gRPC metadata`. See pkg/connectmd for the writeup.
	// Connect interceptor chain (order matters):
	//   1. HeadersToGRPCMetadata: copies HTTP request headers into ctx
	//      as gRPC IncomingMetadata so the auth helpers that read
	//      metadata.FromIncomingContext keep working over Connect.
	//   2. ConnectAuthInterceptor (when identityClient is wired):
	//      validates the Firebase token and injects x-superwizor-role +
	//      x-superwizor-user-id + x-superwizor-organization-id so the
	//      existing admin handlers (resolveAdminCaller) see them.
	//      Without this, browser admin RPCs failed with
	//      "x-superwizor-role missing" — the 2026-05-29 regression.
	// ConnectErrorInterceptor MUST be last so it observes the handler's
	// raw return value and translates grpc/status errors before
	// Connect-Go wraps them as CodeUnknown. Pre-2026-05-29 every admin
	// browser RPC surfaced as "Wystąpił nieznany błąd" because the
	// status.Errorf(codes.PermissionDenied) shape was opaque to
	// Connect.
	interceptors := []connect.Interceptor{connectmd.HeadersToGRPCMetadata()}
	if identityClient != nil {
		interceptors = append(interceptors, grpcadapter.ConnectAuthInterceptor(identityClient))
	} else {
		slog.Warn("billing-svc: IDENTITY_SVC_URL unset — admin Connect RPCs require upstream x-superwizor-role metadata")
	}
	interceptors = append(interceptors, grpcadapter.ConnectErrorInterceptor())
	connectPath, connectHandler := billingv1connect.NewBillingServiceHandler(
		grpcadapter.NewConnectAdapter(billingServer),
		connect.WithInterceptors(interceptors...),
	)
	httpMux.Handle(connectPath, connectHandler)
	httpMux.HandleFunc("GET /healthz", func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		w.WriteHeader(nethttp.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	// Mixed handler dispatches by Content-Type:
	//   application/grpc           -> native gRPC server (server-to-server, iOS)
	//   application/grpc-web[+...] -> Connect handler (Flutter web speaks gRPC-Web)
	//   application/{json,connect+} -> Connect handler (marketing-site browser)
	//
	// The Connect handler is a 3-protocol multiplexer; routing gRPC-Web
	// to it gives Flutter web a working RPC channel without spinning up
	// a separate gRPC-Web proxy. Pre-fix Flutter web got 415 from the
	// plain gRPC server (see PROGRESS.md 2026-05-28).
	mixedHandler := nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		ct := r.Header.Get("Content-Type")
		if r.ProtoMajor == 2 && strings.HasPrefix(ct, "application/grpc") {
			if strings.HasPrefix(ct, "application/grpc-web") {
				httpMux.ServeHTTP(w, r)
				return
			}
			gs.ServeHTTP(w, r)
			return
		}
		httpMux.ServeHTTP(w, r)
	})

	// CORS middleware for browser-facing Connect-RPC + admin HTTP routes.
	// Origins come from CORS_ALLOWED_ORIGINS env (set by terraform on
	// staging to superwizor.ai + app.superwizor.ai + localhost dev).
	// Server-to-server callers (Cloud Scheduler OIDC) don't carry an
	// Origin header and pass through untouched. See docs/18 §5 / R2.
	corsOrigins := getEnv("CORS_ALLOWED_ORIGINS",
		// superwizor-app.web.app = Flutter web app (Firebase Hosting) — see
		// clinical-svc main.go for rationale.
		"https://superwizor.ai,https://app.superwizor.ai,https://superwizor-app.web.app,http://localhost:3000,http://localhost:8080")
	corsMW := cors.New(cors.FromEnv(corsOrigins))

	// HTTP/2 cleartext (h2c) — Cloud Run terminuje TLS przed kontenerem,
	// więc po naszej stronie ruch jest HTTP/2 plaintext. Serwer MUSI mówić
	// h2c. Używamy http.Server.Protocols (Go 1.24+, SetUnencryptedHTTP2) —
	// NIE http2.ConfigureServer, które włącza HTTP/2 tylko po TLS i
	// zostawia plaintext listener niezdolny do sparsowania preface h2c
	// (→ Cloud Run "reset reason: protocol error", gRPC UNAVAILABLE).
	// Zastępuje też przestarzały x/net/http2/h2c shim.
	protocols := new(nethttp.Protocols)
	protocols.SetHTTP1(true)            // Connect-RPC / CORS preflight / health
	protocols.SetUnencryptedHTTP2(true) // cleartext h2c dla natywnego gRPC
	httpSrv := &nethttp.Server{
		Addr:              ":" + port,
		Handler:           corsMW(mixedHandler),
		ReadHeaderTimeout: 10 * time.Second,
		Protocols:         protocols,
	}

	var wg sync.WaitGroup

	// Mixed listener goroutine.
	wg.Add(1)
	go func() {
		defer wg.Done()
		slog.Info("billing-svc starting (gRPC + HTTP mixed)",
			"port", port, "version", version)
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, nethttp.ErrServerClosed) {
			slog.Error("serve failed", "error", err)
		}
	}()

	<-rootCtx.Done()
	slog.Info("shutdown signal received")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	gs.GracefulStop()
	_ = httpSrv.Shutdown(shutdownCtx)

	wg.Wait()
	slog.Info("billing-svc stopped")
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// dialIdentitySvc mirrors the pattern from clinical-svc + ingestion-svc:
// when the URL is https, use Cloud Run idtoken auth (audience = the
// service URL itself); when it's http, plaintext + insecure creds for
// local-dev / contract tests. Fatal on dial error — billing-svc would
// boot but admin RPCs would silently break.
func dialIdentitySvc(ctx context.Context, identityURL string) identityv1.IdentityServiceClient {
	if strings.HasPrefix(identityURL, "https://") {
		tokenSource, err := idtoken.NewTokenSource(ctx, identityURL)
		if err != nil {
			slog.Error("idtoken source", "error", err)
			os.Exit(1)
		}
		u, err := url.Parse(identityURL)
		if err != nil {
			slog.Error("parse identity url", "error", err)
			os.Exit(1)
		}
		target := u.Host
		if u.Port() == "" {
			target = u.Host + ":443"
		}
		conn, err := grpc.NewClient(
			target,
			grpc.WithTransportCredentials(credentials.NewTLS(nil)),
			grpc.WithPerRPCCredentials(oauth.TokenSource{TokenSource: tokenSource}),
		)
		if err != nil {
			slog.Error("dial identity https", "error", err)
			os.Exit(1)
		}
		return identityv1.NewIdentityServiceClient(conn)
	}
	u, err := url.Parse(identityURL)
	if err != nil {
		slog.Error("parse identity url", "error", err)
		os.Exit(1)
	}
	target := u.Host
	if target == "" {
		target = identityURL
	}
	conn, err := grpc.NewClient(target, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		slog.Error("dial identity insecure", "error", err)
		os.Exit(1)
	}
	return identityv1.NewIdentityServiceClient(conn)
}

// dialNotificationSvc dial the notification-svc over gRPC.
func dialNotificationSvc(ctx context.Context, notificationURL string) notificationv1.NotificationServiceClient {
	if strings.HasPrefix(notificationURL, "https://") {
		tokenSource, err := idtoken.NewTokenSource(ctx, notificationURL)
		if err != nil {
			slog.Error("idtoken source for notification", "error", err)
			os.Exit(1)
		}
		u, err := url.Parse(notificationURL)
		if err != nil {
			slog.Error("parse notification url", "error", err)
			os.Exit(1)
		}
		target := u.Host
		if u.Port() == "" {
			target = u.Host + ":443"
		}
		conn, err := grpc.NewClient(
			target,
			grpc.WithTransportCredentials(credentials.NewTLS(nil)),
			grpc.WithPerRPCCredentials(oauth.TokenSource{TokenSource: tokenSource}),
		)
		if err != nil {
			slog.Error("dial notification https", "error", err)
			os.Exit(1)
		}
		return notificationv1.NewNotificationServiceClient(conn)
	}
	u, err := url.Parse(notificationURL)
	if err != nil {
		slog.Error("parse notification url", "error", err)
		os.Exit(1)
	}
	target := u.Host
	if target == "" {
		target = notificationURL
	}
	conn, err := grpc.NewClient(target, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		slog.Error("dial notification insecure", "error", err)
		os.Exit(1)
	}
	return notificationv1.NewNotificationServiceClient(conn)
}
