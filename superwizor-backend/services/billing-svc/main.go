package main

import (
	"context"
	"log"
	"net"
	"os"

	"google.golang.org/grpc"

	pb "github.com/superwizor-ai/backend/gen/go/billing/v1"
)

type billingServer struct {
	pb.UnimplementedBillingServiceServer
}

func (s *billingServer) CheckQuota(ctx context.Context, req *pb.CheckQuotaRequest) (*pb.CheckQuotaResponse, error) {
	log.Printf("Received CheckQuota for therapist: %s, quota_type: %s. Returning ALLOWED (stub)", req.TherapistId, req.QuotaType)
	return &pb.CheckQuotaResponse{
		Allowed: true,
		Reason:  "stub",
	}, nil
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	s := grpc.NewServer()
	pb.RegisterBillingServiceServer(s, &billingServer{})

	log.Printf("Billing stub server listening on :%s", port)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
