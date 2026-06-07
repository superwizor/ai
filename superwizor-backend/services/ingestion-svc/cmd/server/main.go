package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"net/url"
	"os"
	"time"

	gcs "cloud.google.com/go/storage"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/api/idtoken"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/credentials/oauth"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
	"github.com/superwizor-ai/backend/pkg/analytics"
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

	// Bounded pgxpool — Cloud SQL db-f1-micro caps us at 25 connections
	// total across all services. See docs/17_BILLING_IMPLEMENTATION_FLOW.md
	// §11 + the pool-budget table. ingestion-svc gets 2 because it
	// serves the gRPC handler AND runs an in-process Pub/Sub subscriber
	// (audio.uploaded) on the same instance.
	poolCfg, err := pgxpool.ParseConfig(dbDSN)
	if err != nil {
		slog.Error("parse db dsn", "error", err)
		os.Exit(1)
	}
	poolCfg.MaxConns = 2
	poolCfg.MinConns = 0
	poolCfg.MaxConnIdleTime = 30 * time.Second
	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		slog.Error("db", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	analyticsCollector := analytics.NewCollector(pool)
	defer analyticsCollector.Shutdown()

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
	srv := grpcadapter.NewServer(queries, pool, signer, converter, bucketName, publisher, analyticsCollector)

	// Billing client (Phase 3 — optional). When BILLING_SVC_URL is set,
	// CreateAudioUpload fires a fire-and-forget ReserveCredit per session.
	// Without the env var, server runs as before (no reservation, no quota
	// gate). The wiring mirrors clinical-svc's identity-svc dial.
	if billingURL := os.Getenv("BILLING_SVC_URL"); billingURL != "" {
		billingClient, bErr := newBillingClient(ctx, billingURL)
		if bErr != nil {
			slog.Error("billing client init failed", "url", billingURL, "error", bErr)
			// Fail-soft — don't exit; server can still serve without billing.
		} else {
			srv = srv.WithBilling(billingClient)
			slog.Info("ingestion-svc: billing-svc client wired", "url", billingURL)
		}
	} else {
		slog.Info("ingestion-svc: BILLING_SVC_URL unset — billing hook disabled")
	}

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
		subscriber, subErr := pubsub.NewSubscriber(ctx, projectID, subID, queries, pool, signer, converter, bucketName, publisher, analyticsCollector)
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

// newBillingClient dials billing-svc with Cloud Run service-to-service auth
// when the URL is https://… (idtoken minted by metadata server, audience =
// service URL). For http:// (local dev / docker-compose) it falls back to
// insecure credentials. Mirrors clinical-svc's identity dial wiring.
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
	// Plaintext fallback for local dev (BILLING_SVC_URL=localhost:8080 etc.)
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
