package main
import (
	"fmt"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)
func main() {
	_, err := grpc.NewClient(":443", grpc.WithTransportCredentials(credentials.NewTLS(nil)))
	fmt.Println(err)
}
