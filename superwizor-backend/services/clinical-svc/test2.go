package main

import (
	"fmt"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/oauth"
	"golang.org/x/oauth2"
)

type dummyTokenSource struct{}

func (d dummyTokenSource) Token() (*oauth2.Token, error) {
	return nil, nil
}

func main() {
	_, err := grpc.NewClient("test:443",
		grpc.WithTransportCredentials(credentials.NewClientTLSFromCert(nil, "")),
		grpc.WithPerRPCCredentials(oauth.TokenSource{TokenSource: dummyTokenSource{}}),
	)
	if err != nil {
		fmt.Println("Error:", err)
	} else {
		fmt.Println("Success")
	}
}
