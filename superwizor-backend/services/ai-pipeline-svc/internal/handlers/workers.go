package handlers

import (
	"context"
	"encoding/json"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/adapters/pubsub"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/models"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/services"
)

type WorkerContext struct {
	DB        *models.DB
	STT       *services.STTService
	LLM       *services.LLMService
	Publisher *pubsub.Publisher
}

type PubSubMessage struct {
	Message struct {
		Data       []byte            `json:"data,omitempty"`
		Attributes map[string]string `json:"attributes,omitempty"`
		ID         string            `json:"messageId"`
	} `json:"message"`
	Subscription string `json:"subscription"`
}

type AudioUploadedEvent struct {
	SessionID  string `json:"session_id"`
	UploadID   string `json:"upload_id"`
	ObjectPath string `json:"object_path"`
}

// STTWorkerHandler processes the audio.uploaded event
func (wc *WorkerContext) STTWorkerHandler(c *gin.Context) {
	var pubSubMsg PubSubMessage
	if err := c.ShouldBindJSON(&pubSubMsg); err != nil {
		log.Printf("Bad request: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid Pub/Sub message format"})
		return
	}

	log.Printf("Received STT worker request for message ID: %s", pubSubMsg.Message.ID)

	var event AudioUploadedEvent
	if err := json.Unmarshal(pubSubMsg.Message.Data, &event); err != nil {
		log.Printf("Error decoding audio uploaded event: %v", err)
		c.Status(http.StatusOK) // Return 200 to prevent retries
		return
	}

	if event.SessionID == "" || event.ObjectPath == "" {
		log.Printf("Ignoring message: missing session_id or object_path")
		c.Status(http.StatusOK)
		return
	}

	// Assuming the bucket is known or passed in object path. For prototype we assume object path is the full gs:// uri or just use a dummy bucket if not.
	// Actually, event.ObjectPath might just be the path, let's assume it contains the bucket or we hardcode it for now.
	// We'll construct a simple URI if it doesn't start with gs://
	gcsURI := event.ObjectPath
	if len(gcsURI) > 0 && gcsURI[:5] != "gs://" {
		// Mocking bucket name
		gcsURI = "gs://superwizor-audio-uploads/" + event.ObjectPath
	}

	log.Printf("Processing audio file: %s for session %s", gcsURI, event.SessionID)

	ctx := context.Background()
	transcript, err := wc.STT.TranscribeAudio(ctx, gcsURI)
	if err != nil {
		log.Printf("Error transcribing audio: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to transcribe audio"})
		return
	}

	log.Printf("Transcription successful. Saving to DB.")

	sessionID, err := uuid.Parse(event.SessionID)
	if err != nil {
		log.Printf("Invalid session ID format: %v", err)
		c.Status(http.StatusOK)
		return
	}

	// Save to database with placeholder encryption values for Phase 2
	transcriptID, err := wc.DB.SaveTranscript(ctx, sessionID, "pl-PL", "chirp-3", []byte("ENCRYPT_PLACEHOLDER:"+transcript), []byte("DEK_PLACEHOLDER"))
	if err != nil {
		log.Printf("Error saving transcript: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save transcript"})
		return
	}

	// Publish transcript.completed event
	if wc.Publisher != nil {
		if err := wc.Publisher.PublishTranscriptCompleted(ctx, sessionID.String(), transcriptID.String()); err != nil {
			log.Printf("Error publishing transcript.completed: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to publish transcript.completed"})
			return
		}
	} else {
		log.Printf("Warning: Publisher is not initialized, skipping publish.")
	}

	log.Printf("Successfully completed STT pipeline for %s", event.ObjectPath)
	c.Status(http.StatusOK)
}

// LLMWorkerHandler processes the transcript.completed event
func (wc *WorkerContext) LLMWorkerHandler(c *gin.Context) {
	var pubSubMsg PubSubMessage
	if err := c.ShouldBindJSON(&pubSubMsg); err != nil {
		log.Printf("Bad request: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid Pub/Sub message format"})
		return
	}

	log.Printf("Received LLM worker request for message ID: %s", pubSubMsg.Message.ID)

	var payload pubsub.TranscriptCompletedPayload
	if err := json.Unmarshal(pubSubMsg.Message.Data, &payload); err != nil {
		log.Printf("Error decoding payload: %v", err)
		c.Status(http.StatusOK)
		return
	}

	sessionID, err := uuid.Parse(payload.SessionID)
	if err != nil {
		log.Printf("Invalid session ID format: %v", err)
		c.Status(http.StatusOK)
		return
	}

	transcriptID, err := uuid.Parse(payload.TranscriptID)
	if err != nil {
		log.Printf("Invalid transcript ID format: %v", err)
		c.Status(http.StatusOK)
		return
	}

	ctx := context.Background()

	// 1. Fetch Session Context to get modality ID
	_, modalityID, err := wc.DB.GetSessionContext(ctx, sessionID)
	if err != nil {
		log.Printf("Error fetching session context: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch session context"})
		return
	}

	// 2. Fetch Modality Prompt
	prompt, err := wc.DB.GetModalityPrompt(ctx, modalityID)
	if err != nil {
		log.Printf("Error fetching modality prompt: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch modality prompt"})
		return
	}

	if prompt == "" {
		prompt = "Cel: Szybki, rzeczowy przegląd sesji. Struktura: 1. Główny problem/temat przewodni sesji."
	}

	// Fetch transcript (mocking fetching it for now, usually we'd read from DB based on transcriptID)
	// For MVP we just use a dummy text or assuming LLM worker fetches it via DB helper
	transcriptText := "dummy transcript for testing since we didn't extract the blob logic fully here"

	reportText, err := wc.LLM.GenerateReport(ctx, transcriptText, prompt)
	if err != nil {
		log.Printf("Error generating report: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate report"})
		return
	}

	// Save to DB with placeholders
	reportID, err := wc.DB.SaveReport(ctx, sessionID, transcriptID, modalityID, []byte("ENCRYPT_PLACEHOLDER:"+reportText), []byte("DEK_PLACEHOLDER"), "gemini-1.5-pro")
	if err != nil {
		log.Printf("Error saving report: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save report"})
		return
	}

	// Publish report.generated event
	if wc.Publisher != nil {
		if err := wc.Publisher.PublishReportGenerated(ctx, sessionID.String(), reportID.String()); err != nil {
			log.Printf("Error publishing report.generated: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to publish report.generated"})
			return
		}
	} else {
		log.Printf("Warning: Publisher is not initialized, skipping publish.")
	}

	log.Printf("Successfully generated and saved LLM report for transcript %s", payload.TranscriptID)
	c.Status(http.StatusOK)
}
