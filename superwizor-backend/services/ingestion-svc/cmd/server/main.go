package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"os"

	gcs "cloud.google.com/go/storage"
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

	// Dedicated GCS client for the converter (download + upload during
	// ConvertAudio). Separate from the Signer's internal client because
	// Signer wraps a SignedURL-shaped API; the converter wants raw
	// reader/writer access. Same SA, same IAM grants — no new IAM.
	gcsClient, err := gcs.NewClient(ctx)
	if err != nil {
		slog.Error("gcs client", "error", err)
		os.Exit(1)
	}
	defer func() { _ = gcsClient.Close() }()
	converter := storage.NewConverter(gcsClient)

	publisher, err := pubsub.NewPublisher(ctx, projectID)
	if err != nil {
		slog.Error("pubsub", "error", err)
		os.Exit(1)
	}

	queries := db.New(pool)
	srv := grpcadapter.NewServer(queries, pool, signer, converter, bucketName, publisher)

	// Option F (2026-05-25, feat/refactor-stt-architecture):
	// Start the in-process Pub/Sub pull subscriber for GCS
	// OBJECT_FINALIZE events. The subscriber processes audio
	// uploads asynchronously (probe duration, fallback transcode,
	// chunk if > 19min, flip session to CREATED, publish
	// audio.uploaded). When GCS_FINALIZE_SUB_ID is unset we skip
	// boot — this lets the same binary run on environments that
	// haven't been migrated to the hybrid path yet (the synchronous
	// CompleteAudioUpload handler remains the fallback).
	subID := os.Getenv("GCS_FINALIZE_SUB_ID")
	if subID != "" {
		subscriber, subErr := pubsub.NewSubscriber(ctx, projectID, subID, queries, pool, signer, converter, bucketName, publisher)
		if subErr != nil {
			slog.Error("subscriber init", "error", subErr)
			os.Exit(1)
		}
		go subscriber.Start(ctx)
		slog.Info("ingestion-svc: GCS finalize subscriber started", "subscription", subID)
	} else {
		slog.Info("ingestion-svc: GCS_FINALIZE_SUB_ID unset, skipping background subscriber")
	}

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
