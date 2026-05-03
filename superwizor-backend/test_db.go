package main
import (
	"context"
	"fmt"
	"os"
	"github.com/jackc/pgx/v5"
)
func main() {
	conn, err := pgx.Connect(context.Background(), os.Getenv("DATABASE_URL"))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to connect to database: %v\n", err)
		os.Exit(1)
	}
	defer conn.Close(context.Background())
	var id string
	err = conn.QueryRow(context.Background(), "SELECT id FROM patient_files LIMIT 1").Scan(&id)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Query failed: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(id)
}
