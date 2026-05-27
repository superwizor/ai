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
	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
	"google.golang.org/api/idtoken"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/credentials/oauth"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	clinicalv1connect "github.com/superwizor-ai/backend/gen/go/clinical/v1/clinicalv1connect"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/pkg/cors"
	"github.com/superwizor-ai/backend/pkg/cryptobox"
	grpcadapter "github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/grpc"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
	psadapter "github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/pubsub"

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
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

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

	srv := grpcadapter.NewServer(pool, queries, identityClient, billingClient, crypto, sessionEvents, version)

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

	// Connect-RPC surface — browser callers via ConnectAdapter. Note:
	// the UnaryAuthInterceptor above only applies to the gRPC path.
	// Browser callers will need an equivalent interceptor wired through
	// connect.WithInterceptors when the first browser-facing RPC ships
	// in Slice 2 — for now the only authenticated browser RPC paths
	// (RegisterOrganization, AcceptInvitation) hit identity-svc, not
	// clinical-svc, so this is fine.
	httpMux := nethttp.NewServeMux()
	connectPath, connectHandler := clinicalv1connect.NewClinicalServiceHandler(
		grpcadapter.NewConnectAdapter(srv))
	httpMux.Handle(connectPath, connectHandler)
	httpMux.HandleFunc("GET /healthz", func(w nethttp.ResponseWriter, _ *nethttp.Request) {
		w.WriteHeader(nethttp.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	mixedHandler := nethttp.HandlerFunc(func(w nethttp.ResponseWriter, r *nethttp.Request) {
		if r.ProtoMajor == 2 && strings.HasPrefix(r.Header.Get("Content-Type"), "application/grpc") {
			grpcServer.ServeHTTP(w, r)
			return
		}
		httpMux.ServeHTTP(w, r)
	})

	corsOrigins := getEnv("CORS_ALLOWED_ORIGINS",
		"https://superwizor.ai,https://app.superwizor.ai,http://localhost:3000,http://localhost:8080")
	corsMW := cors.New(cors.FromEnv(corsOrigins))

	h2s := &http2.Server{}
	httpSrv := &nethttp.Server{
		Addr:              ":" + port,
		Handler:           h2c.NewHandler(corsMW(mixedHandler), h2s),
		ReadHeaderTimeout: 10 * time.Second,
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
