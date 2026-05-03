package main

import (
	"fmt"
	"log/slog"
	"net"
	"os"

	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	grpcadapter "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/grpc"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))
	if err != nil {
		slog.Error("listen", "error", err)
		os.Exit(1)
	}

	gs := grpc.NewServer()
	billingv1.RegisterBillingServiceServer(gs, grpcadapter.NewServer("v0.1.0-stub"))

	hs := health.NewServer()
	hs.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(gs, hs)
	reflection.Register(gs)

	slog.Info("billing-svc (STUB) starting", "port", port)
	if err := gs.Serve(lis); err != nil {
		slog.Error("serve", "error", err)
		os.Exit(1)
	}
}
