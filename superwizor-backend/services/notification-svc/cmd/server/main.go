// Cloud Run entrypoint for notification-svc.
//
// Hosts the gRPC NotificationService for Flutter:
//   - RegisterFCMToken / RemoveFCMToken — token lifecycle
//   - GetUnreadCount                    — diagnostic badge support
//   - HealthCheck                       — Cloud Run probe
//
// Environment:
//   PORT             default 8080
//   DATABASE_URL     postgres DSN (required)
//   GCP_PROJECT_ID   for Firebase Auth verification (required in prod)
//   VERSION          shown in HealthCheck (CI passes git sha)
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"os"
	"time"

	firebase "firebase.google.com/go/v4"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"

	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
	grpcadapter "github.com/superwizor-ai/backend/services/notification-svc/internal/adapters/grpc"
	"github.com/superwizor-ai/backend/services/notification-svc/internal/adapters/fcm"
	pgstore "github.com/superwizor-ai/backend/services/notification-svc/internal/adapters/postgres"
	emailpkg "github.com/superwizor-ai/backend/services/notification-svc/internal/email"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	port := getenv("PORT", "8080")
	version := getenv("VERSION", "dev")
	dsn := os.Getenv("DATABASE_URL")
	projectID := os.Getenv("GCP_PROJECT_ID")

	if dsn == "" {
		slog.Error("DATABASE_URL required")
		os.Exit(1)
	}

	ctx := context.Background()

	// Bounded pool (see docs/17 §11). gRPC surface is light:
	// RegisterFCMToken / RemoveFCMToken / GetUnreadCount.
	poolCfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		slog.Error("parse db dsn", "error", err)
		os.Exit(1)
	}
	poolCfg.MaxConns = 1
	poolCfg.MinConns = 0
	poolCfg.MaxConnIdleTime = 30 * time.Second
	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		slog.Error("db connect", "error", err)
		os.Exit(1)
	}
	defer pool.Close()
	store := pgstore.New(pool)

	// Firebase Admin Auth — used to verify Flutter ID tokens.
	// In dev (no project), we still bring up the server so contract
	// tests / local smoke can exercise the gRPC surface; the auth
	// interceptor will refuse requests until a project is configured.
	var srv *grpcadapter.Server

	if projectID == "" {
		slog.Warn("GCP_PROJECT_ID not set — Firebase Auth disabled (DEV ONLY)")
		srv = grpcadapter.NewServer(store, nil, version)
	} else {
		app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID})
		if err != nil {
			slog.Error("firebase app", "error", err)
			os.Exit(1)
		}
		auth, err := app.Auth(ctx)
		if err != nil {
			slog.Error("firebase auth client", "error", err)
			os.Exit(1)
		}
		srv = grpcadapter.NewServer(store, auth, version)

		// FCM sender for the client_note_received push (docs/39 PR11).
		// Same firebase app as auth; best-effort — a messaging-client
		// failure leaves the server e-mail-only rather than crashing.
		if mc, mErr := app.Messaging(ctx); mErr != nil {
			slog.Warn("firebase messaging client unavailable — client-note FCM push disabled", "error", mErr)
		} else {
			srv = srv.WithFCM(fcm.NewSender(mc))
			slog.Info("notification-svc: FCM sender wired for client-note pushes")
		}
	}

	// Resend-backed email sender (per docs/18 D1). Falls back to the
	// MockSender default in NewServer when RESEND_API_KEY is unset —
	// safe for local dev and contract tests, so the binary still
	// boots without the secret.
	if apiKey := os.Getenv("RESEND_API_KEY"); apiKey != "" {
		from := getenv("RESEND_FROM", "Superwizor <noreply@client.superwizor.ai>")
		srv = srv.WithEmailer(emailpkg.NewResendSender(apiKey, from))
		slog.Info("notification-svc: Resend sender enabled", "from", from)
	} else {
		slog.Warn("RESEND_API_KEY unset — using MockSender (no real emails sent)")
	}

	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))
	if err != nil {
		slog.Error("listen", "error", err)
		os.Exit(1)
	}

	gs := grpc.NewServer()
	notificationv1.RegisterNotificationServiceServer(gs, srv)

	hs := health.NewServer()
	hs.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(gs, hs)
	reflection.Register(gs)

	slog.Info("notification-svc starting", "port", port, "version", version)
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
