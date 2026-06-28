package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	nethttp "net/http"
	"net/url"
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

	"connectrpc.com/connect"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	identityv1connect "github.com/superwizor-ai/backend/gen/go/identity/v1/identityv1connect"
	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
	"github.com/superwizor-ai/backend/pkg/analytics"
	"github.com/superwizor-ai/backend/pkg/connectmd"
	"github.com/superwizor-ai/backend/pkg/cors"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/firebase"
	grpcadapter "github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/grpc"
	httpadapter "github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/http"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"

	"go.opentelemetry.io/contrib/detectors/gcp"
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
)

func initTracer() *sdktrace.TracerProvider {
	ctx := context.Background()
	exp, err := otlptracegrpc.New(ctx)
	if err != nil {
		slog.Error("failed to create exporter", "error", err)
	}
	res, err := resource.New(ctx,
		resource.WithDetectors(gcp.NewDetector()),
		resource.WithAttributes(semconv.ServiceName("identity-svc")),
	)
	if err != nil {
		slog.Error("failed to init otel resource", "error", err)
	}
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.TraceContext{})
	return tp
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	port := getEnv("PORT", "8080")
	projectID := getEnv("GCP_PROJECT_ID", "superwizor-staging")
	dbDSN := os.Getenv("DATABASE_URL")
	if dbDSN == "" {
		dbUser := os.Getenv("DB_USER")
		dbPass := os.Getenv("DB_PASSWORD")
		dbHost := os.Getenv("DB_HOST")
		dbName := os.Getenv("DB_NAME")
		if dbUser != "" && dbPass != "" && dbHost != "" && dbName != "" {
			dbDSN = fmt.Sprintf("postgres://%s:%s@%s:5432/%s?sslmode=disable", dbUser, dbPass, dbHost, dbName)
		}
	}
	version := getEnv("VERSION", "dev")

	if dbDSN == "" {
		slog.Error("DATABASE_URL or DB_USER/PASSWORD/HOST/NAME is required")
		os.Exit(1)
	}

	ctx := context.Background()

	// DB pool — bounded (see docs/17 §11). Identity has light DB usage
	// (one query per ValidateToken / GetUser), single conn is sufficient.
	poolCfg, err := pgxpool.ParseConfig(dbDSN)
	if err != nil {
		slog.Error("parse db dsn", "error", err)
		os.Exit(1)
	}
	poolCfg.MaxConns = 1
	poolCfg.MinConns = 0
	poolCfg.MaxConnIdleTime = 30 * time.Second
	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		slog.Error("failed to connect to db", "error", err)
		os.Exit(1)
	}
	defer pool.Close()
	
	analyticsCollector := analytics.NewCollector(pool)
	defer analyticsCollector.Shutdown()

	if err := pool.Ping(ctx); err != nil {
		slog.Error("db ping failed", "error", err)
		os.Exit(1)
	}

	queries := db.New(pool)

	// Firebase
	authClient, err := firebase.NewAuthClient(ctx, projectID)
	if err != nil {
		slog.Error("firebase init failed", "error", err)
		os.Exit(1)
	}

	tp := initTracer()
	defer func() { _ = tp.Shutdown(ctx) }()

	// Build identity-svc Server. If NOTIFICATION_SVC_URL is set, dial
	// notification-svc and wire the real InvitationEmailer so
	// InviteTherapist sends actual emails via Resend. Without the env
	// var the default NoopEmailSender just logs — fine for local dev
	// and contract tests.
	identityServer := grpcadapter.NewServer(pool, queries, authClient, version, analyticsCollector)
	if notifURL := os.Getenv("NOTIFICATION_SVC_URL"); notifURL != "" {
		notifClient, err := newNotificationClient(ctx, notifURL)
		if err != nil {
			slog.Warn("identity-svc: could not dial notification-svc; staying on NoopEmailSender",
				"url", notifURL, "error", err)
		} else {
			identityServer = identityServer.WithEmailer(
				grpcadapter.NewNotificationServiceEmailer(notifClient))
			slog.Info("identity-svc: invitation emails via notification-svc enabled",
				"url", notifURL)
		}
	} else {
		slog.Warn("NOTIFICATION_SVC_URL unset — invitation emails are NoopEmailSender only")
	}
	if acceptBase := os.Getenv("ACCEPT_URL_BASE"); acceptBase != "" {
		identityServer = identityServer.WithAcceptURLBase(acceptBase)
	}

	// gRPC surface — used by iOS + server-to-server callers via
	// the application/grpc content-type path.
	grpcServer := grpc.NewServer(
		grpc.StatsHandler(otelgrpc.NewServerHandler()),
	)
	identityv1.RegisterIdentityServiceServer(grpcServer, identityServer)
	healthServer := health.NewServer()
	healthServer.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(grpcServer, healthServer)
	reflection.Register(grpcServer)

	// Connect-RPC surface — same business logic, exposed as the
	// connect/gRPC-Web/Connect family of protocols for browser
	// callers. ConnectAdapter wraps each gRPC method 1:1.
	//
	// The HeadersToGRPCMetadata interceptor copies the HTTP request
	// headers into the ctx as gRPC IncomingMetadata so handlers that
	// read `metadata.FromIncomingContext(ctx)` (the auth helpers,
	// etc.) work identically whether the request arrived as native
	// gRPC (iOS) or as Connect (browser). Without this every browser
	// RPC that requires auth returns "Unauthenticated: no gRPC
	// metadata" — the bug behind the 2026-05-28 marketing-site signup
	// regression. See pkg/connectmd for the writeup.
	httpMux := nethttp.NewServeMux()
	connectPath, connectHandler := identityv1connect.NewIdentityServiceHandler(
		grpcadapter.NewConnectAdapter(identityServer),
		connect.WithInterceptors(
			connectmd.HeadersToGRPCMetadata(),
			// Map the wrapped gRPC handler's status codes (NotFound,
			// Unauthenticated, …) to the equivalent Connect codes; without
			// this they all reach the browser as CodeUnknown and clients
			// can't branch on them (e.g. NotFound → finish registration).
			connectmd.TranslateGRPCError(),
		),
	)
	httpMux.Handle(connectPath, connectHandler)
	httpadapter.NewNIPHandler(logger).RegisterRoutes(httpMux)
	httpMux.HandleFunc("GET /healthz", func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		w.WriteHeader(nethttp.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	// Mixed handler: dispatch on Content-Type so a single listener
	// serves all three protocols (native gRPC, gRPC-Web, Connect).
	//
	//   application/grpc            -> standard gRPC server (iOS, server-to-server)
	//   application/grpc-web[+...]  -> Connect handler (Flutter web)
	//   application/{json,connect+}  -> Connect handler (marketing-site)
	//
	// The Connect handler is a 3-protocol multiplexer — registering a
	// Connect handler implicitly exposes the same RPCs over gRPC-Web
	// without any extra wrapping. Before this dispatch, gRPC-Web
	// requests landed at the plain gRPC server which doesn't speak
	// gRPC-Web framing, so it rejected with 415. The 2026-05-28
	// Flutter-web login probe exposed this — see PROGRESS.md.
	mixedHandler := nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		ct := r.Header.Get("Content-Type")
		if r.ProtoMajor == 2 && strings.HasPrefix(ct, "application/grpc") {
			if strings.HasPrefix(ct, "application/grpc-web") {
				httpMux.ServeHTTP(w, r)
				return
			}
			grpcServer.ServeHTTP(w, r)
			return
		}
		httpMux.ServeHTTP(w, r)
	})

	// CORS for browser-facing Connect-RPC. Server-to-server callers
	// (iOS, clinical-svc proxy, Cloud Scheduler) don't send Origin
	// and pass through untouched.
	corsOrigins := getEnv("CORS_ALLOWED_ORIGINS",
		// superwizor-app.web.app = Flutter web app (Firebase Hosting) — see
		// clinical-svc main.go for rationale.
		"https://superwizor.ai,https://app.superwizor.ai,https://superwizor-app.web.app,http://localhost:3000,http://localhost:8080")
	corsMW := cors.New(cors.FromEnv(corsOrigins))

	// Serve cleartext HTTP/2 (h2c) for gRPC. Cloud Run terminates TLS at
	// the edge and forwards cleartext HTTP/2 to the container (container
	// port named "h2c"), so this server MUST speak h2c. We use Go 1.24+'s
	// http.Server.Protocols (SetUnencryptedHTTP2) — NOT
	// http2.ConfigureServer, which only enables HTTP/2 *over TLS* and
	// leaves a plaintext listener unable to parse the h2c connection
	// preface (→ Cloud Run "reset reason: protocol error", gRPC
	// UNAVAILABLE). This also avoids the deprecated x/net/http2/h2c shim.
	protocols := new(nethttp.Protocols)
	protocols.SetHTTP1(true)            // Connect-RPC / CORS preflight / health
	protocols.SetUnencryptedHTTP2(true) // cleartext h2c for native gRPC
	httpSrv := &nethttp.Server{
		Addr:              ":" + port,
		Handler:           corsMW(mixedHandler),
		ReadHeaderTimeout: 10 * time.Second,
		Protocols:         protocols,
	}

	rootCtx, cancel := signal.NotifyContext(ctx, syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		slog.Info("identity-svc starting (gRPC + Connect + HTTP mixed)",
			"port", port, "version", version)
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, nethttp.ErrServerClosed) {
			slog.Error("serve failed", "error", err)
		}
	}()

	<-rootCtx.Done()
	slog.Info("identity-svc shutdown signal received")
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()
	grpcServer.GracefulStop()
	_ = httpSrv.Shutdown(shutdownCtx)
	wg.Wait()
	slog.Info("identity-svc stopped")
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// newNotificationClient dials notification-svc with Cloud Run
// service-to-service OIDC auth when the URL is https:// (idtoken
// minted by metadata server, audience = service URL). Falls back to
// insecure credentials for http:// (local dev). Same pattern as
// ingestion-svc / clinical-svc.
func newNotificationClient(ctx context.Context, serviceURL string) (notificationv1.NotificationServiceClient, error) {
	if len(serviceURL) >= 5 && serviceURL[:5] == "https" {
		tokenSource, err := idtoken.NewTokenSource(ctx, serviceURL)
		if err != nil {
			return nil, fmt.Errorf("idtoken: %w", err)
		}
		u, err := url.Parse(serviceURL)
		if err != nil {
			return nil, fmt.Errorf("parse url: %w", err)
		}
		target := u.Host
		if u.Port() == "" {
			target = u.Host + ":443"
		}
		conn, err := grpc.NewClient(target,
			grpc.WithTransportCredentials(credentials.NewTLS(nil)),
			grpc.WithPerRPCCredentials(oauth.TokenSource{TokenSource: tokenSource}),
		)
		if err != nil {
			return nil, fmt.Errorf("dial: %w", err)
		}
		return notificationv1.NewNotificationServiceClient(conn), nil
	}
	u, err := url.Parse(serviceURL)
	if err != nil {
		return nil, err
	}
	target := u.Host
	if target == "" {
		target = serviceURL
	}
	conn, err := grpc.NewClient(target, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, err
	}
	return notificationv1.NewNotificationServiceClient(conn), nil
}
