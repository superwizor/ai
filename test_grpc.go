//go:build ignore

package main

import (
	"fmt"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

func main() {
	_, err := grpc.NewClient(
		"example.com:443",
		grpc.WithTransportCredentials(credentials.NewClientTLSFromCert(nil, "")),
	)
	fmt.Println(err)
}
