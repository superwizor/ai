package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"net/url"
	"os"

	kms "cloud.google.com/go/kms/apiv1"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/api/idtoken"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/credentials/oauth"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
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

	// DB
	pool, err := pgxpool.New(ctx, dbDSN)
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
	srv := grpcadapter.NewServer(pool, queries, identityClient, crypto, sessionEvents, version)

	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))
	if err != nil {
		slog.Error("listen failed", "error", err)
		os.Exit(1)
	}

	tp := initTracer()
	defer func() { _ = tp.Shutdown(ctx) }()

	grpcServer := grpc.NewServer(
		grpc.StatsHandler(otelgrpc.NewServerHandler()),
		grpc.UnaryInterceptor(grpcadapter.UnaryAuthInterceptor(identityClient)),
	)
	clinicalv1.RegisterClinicalServiceServer(grpcServer, srv)

	// Health
	healthServer := health.NewServer()
	healthServer.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(grpcServer, healthServer)

	reflection.Register(grpcServer)

	slog.Info("clinical-svc starting", "port", port)
	if err := grpcServer.Serve(lis); err != nil {
		slog.Error("serve failed", "error", err)
		os.Exit(1)
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
