package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/firebase"
	grpcadapter "github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/grpc"
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

	// gRPC server
	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))
	if err != nil {
		slog.Error("listen failed", "error", err)
		os.Exit(1)
	}

	tp := initTracer()
	defer func() { _ = tp.Shutdown(ctx) }()

	grpcServer := grpc.NewServer(
		grpc.StatsHandler(otelgrpc.NewServerHandler()),
	)

	// Register identity service
	identityv1.RegisterIdentityServiceServer(grpcServer, grpcadapter.NewServer(pool, queries, authClient, version))

	// Health checks (Cloud Run probe)
	healthServer := health.NewServer()
	healthServer.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(grpcServer, healthServer)

	// Reflection (dla grpcurl debug)
	reflection.Register(grpcServer)

	// NB: Connect-RPC handler registration is deferred to Slice 2 of
	// the web-app workstream. The generated identityv1connect handler
	// expects connect.Request[T] / connect.Response[T] shapes while
	// our Server implements the bare gRPC shape; bridging requires
	// ~20 mechanical adapter methods (one per RPC). Generated code in
	// gen/go/identity/v1/identityv1connect/ is compiled-but-unwired —
	// the Slice 2 PR that lands the Next.js client will also land
	// the adapter alongside its first browser call. gRPC + gRPC-Web
	// callers still work today via grpcServer.ServeHTTP.
	slog.Info("identity-svc starting", "port", port, "version", version)
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
