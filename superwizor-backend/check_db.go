package main

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5"
)

type FixedCost struct {
	ID            string
	Name          string
	Provider      string
	AmountUSD     float64
	BillingPeriod string
}

func main() {
	url := "postgres://superwizor_app:Zjee%21ZoYyd78%25%26lCk-%7D47N74J-9OE%21M%21@127.0.0.1:5433/superwizor?sslmode=disable"
	ctx := context.Background()

	conn, err := pgx.Connect(ctx, url)
	if err != nil {
		fmt.Printf("Connect error: %v\n", err)
		os.Exit(1)
	}
	defer conn.Close(ctx)

	fmt.Println("=== Initial Platform Fixed Costs ===")
	printCosts(ctx, conn)

	// Updates to match the real GCP invoice (~180 USD = 720 PLN)
	updates := map[string]float64{
		"Cloud SQL db-f1-micro instance":             110.00,
		"Cloud SQL 10GB Storage":                      10.00,
		"Cloud Run baseline (CPU/Memory allocation)":  50.00,
		"KMS Keyring & Keys baseline active usage":    8.00,
		"Artifact Registry baseline storage":          2.00,
	}

	for name, amount := range updates {
		_, err := conn.Exec(ctx, "UPDATE platform_fixed_costs SET amount_usd = $1 WHERE name = $2", amount, name)
		if err != nil {
			fmt.Printf("Error updating %s: %v\n", name, err)
		} else {
			fmt.Printf("Updated '%s' to $%.2f\n", name, amount)
		}
	}

	fmt.Println("\n=== Updated Platform Fixed Costs ===")
	printCosts(ctx, conn)
}

func printCosts(ctx context.Context, conn *pgx.Conn) {
	rows, err := conn.Query(ctx, "SELECT name, provider, amount_usd, billing_period FROM platform_fixed_costs ORDER BY amount_usd DESC")
	if err != nil {
		fmt.Printf("Query error: %v\n", err)
		return
	}
	defer rows.Close()

	var total float64
	for rows.Next() {
		var name, provider, period string
		var amount float64
		if err := rows.Scan(&name, &provider, &amount, &period); err != nil {
			fmt.Printf("Scan error: %v\n", err)
			return
		}
		fmt.Printf("- %-45s [%s]: $%-6.2f (%s)\n", name, provider, amount, period)
		total += amount
	}
	fmt.Printf("Total: $%.2f\n\n", total)
}
