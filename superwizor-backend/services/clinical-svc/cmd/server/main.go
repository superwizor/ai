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

	kms "cloud.google.com/go/kms/apiv1"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/api/idtoken"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/credentials/oauth"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/keepalive"
	"google.golang.org/grpc/reflection"

	"connectrpc.com/connect"
	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	clinicalv1connect "github.com/superwizor-ai/backend/gen/go/clinical/v1/clinicalv1connect"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"

	"github.com/superwizor-ai/backend/pkg/analytics"
	"github.com/superwizor-ai/backend/pkg/appconfig"
	"github.com/superwizor-ai/backend/pkg/connectmd"
	"github.com/superwizor-ai/backend/pkg/cors"
	"github.com/superwizor-ai/backend/pkg/cryptobox"
	"github.com/superwizor-ai/backend/pkg/logging"
	grpcadapter "github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/grpc"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
	psadapter "github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/pubsub"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/chat"

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
		resource.WithAttributes(semconv.ServiceName("clinical-svc")),
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
	// pkg/logging: bez mapowania level→severity Cloud Logging widzi
	// wszystko jako DEFAULT.
	logging.SetupDefault()

	port := getEnv("PORT", "8080")
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
	identityURL := os.Getenv("IDENTITY_SVC_URL")
	version := getEnv("VERSION", "dev")

	if dbDSN == "" || identityURL == "" {
		slog.Error("DATABASE_URL (or DB_USER/PASS/HOST/NAME) and IDENTITY_SVC_URL required")
		os.Exit(1)
	}

	ctx := context.Background()

	// DB — bounded pool (see docs/17 §11). clinical-svc gets 1 because
	// GetSessionDetails / Get*Reports are read-heavy with one tx per
	// request; concurrent gRPC handlers serialize through pgxpool's
	// internal Acquire wait queue when the slot is busy.
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
		slog.Error("db connect failed", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	analyticsCollector := analytics.NewCollector(pool)
	defer analyticsCollector.Shutdown()

	// gRPC client → identity-svc with Cloud Run service-to-service auth (if https)
	var identityConn *grpc.ClientConn

	if len(identityURL) >= 5 && identityURL[:5] == "https" {
		tokenSource, err := idtoken.NewTokenSource(ctx, identityURL)
		if err != nil {
			slog.Error("token source failed", "error", err)
			os.Exit(1)
		}

		u, err := url.Parse(identityURL)
		if err != nil {
			slog.Error("invalid identity URL", "error", err)
			os.Exit(1)
		}
		target := u.Host + ":443"

		identityConn, err = grpc.NewClient(
			target,
			grpc.WithTransportCredentials(credentials.NewTLS(nil)),
			grpc.WithPerRPCCredentials(oauth.TokenSource{TokenSource: tokenSource}),
			grpc.WithStatsHandler(otelgrpc.NewClientHandler()),
		)
		if err != nil {
			slog.Error("identity dial failed", "error", err)
			os.Exit(1)
		}
	} else {
		u, err := url.Parse(identityURL)
		if err != nil {
			slog.Error("invalid identity URL", "error", err)
			os.Exit(1)
		}

		target := u.Host
		if target == "" {
			target = identityURL // fallback if it's just host:port
		}

		identityConn, err = grpc.NewClient(
			target,
			grpc.WithTransportCredentials(insecure.NewCredentials()),
			grpc.WithStatsHandler(otelgrpc.NewClientHandler()),
		)
		if err != nil {
			slog.Error("identity dial insecure failed", "error", err)
			os.Exit(1)
		}
	}
	defer func() { _ = identityConn.Close() }()

	identityClient := identityv1.NewIdentityServiceClient(identityConn)

	// Crypto
	kmsKeyURI := os.Getenv("KMS_KEY_URI")
	var crypto cryptobox.CryptoBox
	if kmsKeyURI != "" {
		kmsClient, err := kms.NewKeyManagementClient(ctx)
		if err != nil {
			slog.Error("kms client", "error", err)
			os.Exit(1)
		}
		crypto = cryptobox.NewCloudKMSBox(kmsClient, kmsKeyURI)
	} else {
		crypto = cryptobox.NewMockBox()
	}

	// Pub/Sub publisher for cross-service events (currently only
	// session.deleted). If GCP_PROJECT_ID isn't set (local dev),
	// we pass nil and the handler short-circuits the publish.
	var pubsubPublisher *psadapter.Publisher
	if projectID := os.Getenv("GCP_PROJECT_ID"); projectID != "" {
		var err error
		pubsubPublisher, err = psadapter.NewPublisher(ctx, projectID)
		if err != nil {
			slog.Error("pubsub publisher init failed", "error", err)
			os.Exit(1)
		}
	} else {
		slog.Warn("GCP_PROJECT_ID unset — session.deleted events will NOT be published; Firestore mirror will drift")
	}

	// Server
	queries := db.New(pool)
	// Compile-time nil-safe — psadapter.Publisher pointer satisfies
	// the SessionEventPublisher interface; passing a typed nil here
	// means the handler's `if s.pubsub != nil` check correctly skips.
	var sessionEvents grpcadapter.SessionEventPublisher
	if pubsubPublisher != nil {
		sessionEvents = pubsubPublisher
	}
	// Billing client (Phase 3 refactor — optional). When BILLING_SVC_URL
	// is set, GetMyBillingState proxies through to billing-svc.
	// GetSubscription. Without the env var, GetMyBillingState responds
	// Unavailable. Same wiring pattern as ingestion-svc.
	var billingClient billingv1.BillingServiceClient
	if billingURL := os.Getenv("BILLING_SVC_URL"); billingURL != "" {
		c, bErr := newBillingClient(ctx, billingURL)
		if bErr != nil {
			slog.Error("billing client init failed", "url", billingURL, "error", bErr)
			// Fail-soft — the rest of clinical-svc works without it.
		} else {
			billingClient = c
			slog.Info("clinical-svc: billing-svc client wired", "url", billingURL)
		}
	} else {
		slog.Info("clinical-svc: BILLING_SVC_URL unset — GetMyBillingState will return Unavailable")
	}

	// Notification client (docs/22). When NOTIFICATION_SVC_URL is set,
	// SavePatientNote's send-to-patient path proxies to
	// notification-svc.SendActionPlanEmail. Without it, the send leg
	// returns Unavailable("EMAIL_NOT_CONFIGURED") — the note is still
	// saved. Same OIDC+TLS wiring as the billing client.
	var notificationClient notificationv1.NotificationServiceClient
	if notificationURL := os.Getenv("NOTIFICATION_SVC_URL"); notificationURL != "" {
		c, nErr := newNotificationClient(ctx, notificationURL)
		if nErr != nil {
			slog.Error("notification client init failed", "url", notificationURL, "error", nErr)
			// Fail-soft — the rest of clinical-svc works without it.
		} else {
			notificationClient = c
			slog.Info("clinical-svc: notification-svc client wired", "url", notificationURL)
		}
	} else {
		slog.Info("clinical-svc: NOTIFICATION_SVC_URL unset — SavePatientNote send path returns EMAIL_NOT_CONFIGURED")
	}

	srv := grpcadapter.NewServer(pool, queries, identityClient, billingClient, notificationClient, crypto, sessionEvents, version, analyticsCollector).
		WithPanelURL(os.Getenv("PANEL_URL_BASE")) // docs/39 PR9; empty keeps the default app URL

	// ── AI chat (ADR docs/kronikarz/62, plan docs/63) ──────────────
	//
	// Always wired; whether it ANSWERS is decided at request time by
	// app_config, which is what makes the kill switch a row update
	// instead of a deploy. The seed in migration 000084 has it off, so a
	// fresh environment starts silent.
	//
	// With no Vertex project configured, NewVertexLLM returns a backend
	// that fails every call — local dev and CI run the whole service
	// with the chat present and inert.
	configReader := appconfig.NewReader(appconfigPool{pool})
	vertexCfg := chat.VertexConfigFromEnv()
	chatLLM, err := chat.NewVertexLLM(ctx, vertexCfg)
	if err != nil {
		slog.Error("clinical-svc: vertex client", "error", err)
		os.Exit(1)
	}
	slog.Info("clinical-svc: ai chat wired",
		"vertex_project_set", vertexCfg.ProjectID != "",
		"vertex_location", vertexCfg.Location)

	chatSvc := &chat.Service{
		LLM:       chatLLM,
		Retriever: chat.Retriever{Pool: chatPool{pool}, Crypto: crypto},
		Quota:     chat.Quota{DB: chatPool{pool}},
		Config:    configReader,
		Decisions: chat.PostgresDecisionLog{DB: chatPool{pool}},
		// Pamiec rozmowy. Bez niej kazda tura jest samotna i odniesienia
		// typu "na ten temat" nie maja do czego sie odniesc.
		History:   chat.HistoryStore{DB: chatPool{pool}, Pool: chatPool{pool}, Crypto: crypto},
		Telemetry: chatTracker{analyticsCollector},
	}
	srv = srv.WithChat(chatSvc).WithChatConfig(configReader, chatPool{pool})

	tp := initTracer()
	defer func() { _ = tp.Shutdown(ctx) }()

	// gRPC surface — iOS + server-to-server callers.
	grpcServer := grpc.NewServer(
		grpc.StatsHandler(otelgrpc.NewServerHandler()),
		grpc.UnaryInterceptor(grpcadapter.UnaryAuthInterceptor(identityClient)),
	)
	clinicalv1.RegisterClinicalServiceServer(grpcServer, srv)
	healthServer := health.NewServer()
	healthServer.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(grpcServer, healthServer)
	reflection.Register(grpcServer)

	// Connect-RPC surface — browser callers via ConnectAdapter.
	// Three interceptors run in declaration order:
	//   1. HeadersToGRPCMetadata: copies HTTP request headers into ctx
	//      as gRPC IncomingMetadata so handlers reading
	//      metadata.FromIncomingContext keep working over Connect (see
	//      pkg/connectmd).
	//   2. ConnectAuthInterceptor: mirrors UnaryAuthInterceptor for the
	//      Connect path — validates the Firebase token via identity-svc
	//      and injects UserIDKey into ctx, so every handler that reads
	//      `ctx.Value(UserIDKey)` works the same regardless of whether
	//      the request came in as native gRPC (iOS) or gRPC-Web/
	//      Connect (browsers). Without this, Flutter web RPCs returned
	//      "missing user ID in context" — the 2026-05-28 regression
	//      surfaced after routing gRPC-Web to this handler.
	httpMux := nethttp.NewServeMux()
	connectPath, connectHandler := clinicalv1connect.NewClinicalServiceHandler(
		grpcadapter.NewConnectAdapter(srv),
		connect.WithInterceptors(
			connectmd.HeadersToGRPCMetadata(),
			grpcadapter.ConnectAuthInterceptor(identityClient),
			// Map wrapped gRPC status codes → Connect codes (else they all
			// surface to the browser as CodeUnknown). See connectmd docs.
			connectmd.TranslateGRPCError(),
		),
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
	// Pre-fix Flutter web's gRPC-Web traffic was being routed to the
	// plain gRPC server (because Content-Type starts with the same
	// prefix), which doesn't speak gRPC-Web framing → 415.
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

	corsOrigins := getEnv("CORS_ALLOWED_ORIGINS",
		// superwizor-app.web.app = Flutter web app (Firebase Hosting). The
		// browser build calls clinical/identity/billing directly; without
		// this origin the CORS preflight is 403'd and the web view can't
		// load data (native app is unaffected — it uses native gRPC).
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
		slog.Info("clinical-svc starting (gRPC + Connect + HTTP mixed)",
			"port", port)
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, nethttp.ErrServerClosed) {
			slog.Error("serve failed", "error", err)
		}
	}()

	<-rootCtx.Done()
	slog.Info("clinical-svc shutdown signal received")
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()
	grpcServer.GracefulStop()
	_ = httpSrv.Shutdown(shutdownCtx)
	wg.Wait()
	slog.Info("clinical-svc stopped")
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// newBillingClient dials billing-svc with Cloud Run service-to-service
// OIDC auth when the URL is https://… (idtoken minted by metadata
// server, audience = service URL). Falls back to insecure credentials
// for http:// (local dev). Same wiring pattern as ingestion-svc.
func newBillingClient(ctx context.Context, serviceURL string) (billingv1.BillingServiceClient, error) {
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
			// Cloud Run drops idle HTTP/2 connections after ~15 minutes.
			// Without client keepalive we don't notice until next write,
			// which then surfaces as
			//   rpc error: code = Internal desc = stream terminated by
			//   RST_STREAM with error code: PROTOCOL_ERROR
			// for the user — first call after idle 500s, retry succeeds
			// because grpc-go silently dials a fresh conn. 30s PING +
			// 10s timeout keeps the conn warm without spamming the
			// server; PermitWithoutStream=true lets us send PINGs when
			// no RPC is active (which is the actual idle case).
			grpc.WithKeepaliveParams(keepalive.ClientParameters{
				Time:                30 * time.Second,
				Timeout:             10 * time.Second,
				PermitWithoutStream: true,
			}),
		)
		if err != nil {
			return nil, fmt.Errorf("dial: %w", err)
		}
		return billingv1.NewBillingServiceClient(conn), nil
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
	return billingv1.NewBillingServiceClient(conn), nil
}

// newNotificationClient dials notification-svc with the same OIDC+TLS
// (https) / insecure (http) wiring as newBillingClient. Used by
// SavePatientNote to deliver action-plan e-mails (docs/22).
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
			// See newBillingClient for the Cloud Run keepalive rationale.
			grpc.WithKeepaliveParams(keepalive.ClientParameters{
				Time:                30 * time.Second,
				Timeout:             10 * time.Second,
				PermitWithoutStream: true,
			}),
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
