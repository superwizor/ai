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
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/handlers"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/models"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/services"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	router := gin.Default()

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "OK", "service": "ai-pipeline-svc"})
	})

	// Setup DB
	dbUrl := os.Getenv("DATABASE_URL")
	if dbUrl == "" {
		log.Println("DATABASE_URL not set, DB ops will fail")
	}
	db, err := models.NewDB(context.Background(), dbUrl)
	if err != nil {
		log.Printf("DB connection error: %v", err)
	}

	projectID := os.Getenv("GCP_PROJECT_ID")
	if projectID == "" {
		projectID = "superwizor-staging" // default fallback
	}

	sttService, _ := services.NewSTTService(context.Background(), projectID)
	llmService, _ := services.NewLLMService(context.Background(), projectID)

	workerCtx := &handlers.WorkerContext{
		DB:  db,
		STT: sttService,
		LLM: llmService,
	}

	// Pub/Sub Push endpoints
	router.POST("/worker/stt", workerCtx.STTWorkerHandler)
	router.POST("/worker/llm", workerCtx.LLMWorkerHandler)

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
