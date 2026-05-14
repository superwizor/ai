// ai-pipeline-svc — Cloud Run health endpoint only.
//
// Historically this binary mounted /worker/stt and /worker/llm Gin
// routes that stubbed the STT and LLM workers. Those stubs were dead
// code: production routes transcript.completed / audio.uploaded
// Pub/Sub events to dedicated Cloud Functions Gen2 (cmd/llm-worker
// and cmd/stt-worker), not to this HTTP service.
//
// The stubs were removed in feat/llm-optimisation. The Cloud Run
// service still exists so health probes have something to talk to and
// so the existing terraform service-account / IAM bindings keep
// resolving; if we ever decide nothing on the platform actually dials
// it, the whole resource can be deleted in infra/.
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	router := gin.Default()
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "OK", "service": "ai-pipeline-svc"})
	})

	srv := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}
	}()

	log.Printf("ai-pipeline-svc listening on port %s", port)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal("Server forced to shutdown:", err)
	}

	log.Println("Server exiting")
}
