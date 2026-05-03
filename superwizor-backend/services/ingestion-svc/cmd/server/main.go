package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"

	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
	grpcadapter "github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/grpc"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/pubsub"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/storage"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	ctx := context.Background()

	port := getenv("PORT", "8080")
	projectID := os.Getenv("GCP_PROJECT_ID")
	bucketName := os.Getenv("AUDIO_BUCKET_NAME")
	dbDSN := os.Getenv("DATABASE_URL")

	if projectID == "" || bucketName == "" || dbDSN == "" {
		slog.Error("required env missing")
		os.Exit(1)
	}

	pool, err := pgxpool.New(ctx, dbDSN)
	if err != nil {
		slog.Error("db", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	signer, err := storage.NewSigner(ctx, bucketName)
	if err != nil {
		slog.Error("signer", "error", err)
		os.Exit(1)
	}

	publisher, err := pubsub.NewPublisher(ctx, projectID)
	if err != nil {
		slog.Error("pubsub", "error", err)
		os.Exit(1)
	}

	queries := db.New(pool)
	srv := grpcadapter.NewServer(queries, signer, bucketName, publisher)

	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))
	if err != nil {
		slog.Error("listen", "error", err)
		os.Exit(1)
	}

	gs := grpc.NewServer()
	ingestionv1.RegisterIngestionServiceServer(gs, srv)

	hs := health.NewServer()
	hs.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(gs, hs)
	reflection.Register(gs)

	slog.Info("ingestion-svc starting", "port", port)
	if err := gs.Serve(lis); err != nil {
		slog.Error("serve", "error", err)
		os.Exit(1)
	}
}

func getenv(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
