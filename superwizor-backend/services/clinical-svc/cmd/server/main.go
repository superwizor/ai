package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/oauth"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
	"google.golang.org/api/idtoken"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	grpcadapter "github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/grpc"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

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

	// gRPC client → identity-svc with Cloud Run service-to-service auth
	tokenSource, err := idtoken.NewTokenSource(ctx, identityURL)
	if err != nil {
		slog.Error("token source failed", "error", err)
		os.Exit(1)
	}

	identityConn, err := grpc.NewClient(
		identityURL,
		grpc.WithPerRPCCredentials(oauth.TokenSource{TokenSource: tokenSource}),
	)
	if err != nil {
		slog.Error("identity dial failed", "error", err)
		os.Exit(1)
	}
	defer func() { _ = identityConn.Close() }()

	identityClient := identityv1.NewIdentityServiceClient(identityConn)

	// Server
	queries := db.New(pool)
	srv := grpcadapter.NewServer(queries, identityClient, version)

	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))
	if err != nil {
		slog.Error("listen failed", "error", err)
		os.Exit(1)
	}

	grpcServer := grpc.NewServer()
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
