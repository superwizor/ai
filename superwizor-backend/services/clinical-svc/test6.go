package main

import (
	"context"
	"fmt"
	"net/url"

	"google.golang.org/api/idtoken"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/oauth"
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
)

func main() {
	identityURL := "https://identity-svc-qcmcx-ew.a.run.app"
	ctx := context.Background()

	tokenSource, _ := idtoken.NewTokenSource(ctx, identityURL)

	u, _ := url.Parse(identityURL)
	target := u.Host + ":443"

	identityConn, err := grpc.NewClient(
		target,
		grpc.WithTransportCredentials(credentials.NewClientTLSFromCert(nil, "")),
		grpc.WithPerRPCCredentials(oauth.TokenSource{TokenSource: tokenSource}),
		grpc.WithStatsHandler(otelgrpc.NewClientHandler()),
	)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
	} else {
		fmt.Println("Success", identityConn)
	}
}
