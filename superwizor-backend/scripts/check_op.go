package main

import (
	"context"
	"fmt"
	"log"
	"os"

	speech "cloud.google.com/go/speech/apiv2"
	"google.golang.org/api/option"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: go run scripts/check_op.go <operation_id>")
	}
	opID := os.Args[1]

	ctx := context.Background()
	speechClient, err := speech.NewClient(ctx, option.WithEndpoint("eu-speech.googleapis.com:443"))
	if err != nil {
		log.Fatalf("Failed to create speech client: %v", err)
	}
	defer speechClient.Close()

	fmt.Printf("🔍 Polling Speech Operation: %s...\n", opID)
	op := speechClient.BatchRecognizeOperation(opID)
	
	// Poll to update status
	if _, err := op.Poll(ctx); err != nil {
		log.Printf("Failed to poll operation: %v", err)
	}
	
	// Query metadata
	metadata, err := op.Metadata()
	if err != nil {
		log.Printf("Failed to get metadata: %v", err)
	} else if metadata != nil {
		fmt.Printf("Metadata: %+v\n", metadata)
	}

	done := op.Done()
	fmt.Printf("Done: %t\n", done)

	if done {
		resp, err := op.Wait(ctx)
		if err != nil {
			log.Fatalf("Operation finished with error: %v", err)
		}
		fmt.Printf("Response: %+v\n", resp)
		if resp != nil {
			for k, v := range resp.Results {
				fmt.Printf("Result for %s:\n", k)
				if v.Error != nil {
					fmt.Printf("  Error: Code=%d Message=%s\n", v.Error.Code, v.Error.Message)
				} else {
					fmt.Printf("  Success! Transcript metadata or inline results present.\n")
				}
			}
		}
	}
}
