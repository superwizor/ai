package handlers

import (
	"context"
	"encoding/json"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/models"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/services"
)

type WorkerContext struct {
	DB  *models.DB
	STT *services.STTService
	LLM *services.LLMService
}

type PubSubMessage struct {
	Message struct {
		Data       []byte            `json:"data,omitempty"`
		Attributes map[string]string `json:"attributes,omitempty"`
		ID         string            `json:"messageId"`
	} `json:"message"`
	Subscription string `json:"subscription"`
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

	// In GCS notifications, Data is a base64 encoded JSON representation of the Storage Object.
	// For simplicity, we assume we extract the bucket and name from attributes or data.
	// Actually, GCS Pub/Sub notifications put bucketId and objectId in Attributes.
	bucketId := pubSubMsg.Message.Attributes["bucketId"]
	objectId := pubSubMsg.Message.Attributes["objectId"]

	if bucketId == "" || objectId == "" {
		log.Printf("Ignoring message: missing bucketId or objectId in attributes")
		c.Status(http.StatusOK)
		return
	}

	gcsURI := "gs://" + bucketId + "/" + objectId
	log.Printf("Processing audio file: %s", gcsURI)

	ctx := context.Background()
	transcript, err := wc.STT.TranscribeAudio(ctx, gcsURI)
	if err != nil {
		log.Printf("Error transcribing audio: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to transcribe audio"})
		return
	}

	log.Printf("Transcription successful. Saving to DB.")

	// Extract PatientFileID from object metadata or attributes.
	// For this prototype, we'll assume patientFileId is in attributes, 
	// or we mock it if it's missing just so the flow works.
	patientFileIdStr := pubSubMsg.Message.Attributes["patientFileId"]
	var patientFileId uuid.UUID
	if patientFileIdStr == "" {
		// Mock ID if not provided by upload metadata
		patientFileId = uuid.New()
	} else {
		parsed, err := uuid.Parse(patientFileIdStr)
		if err == nil {
			patientFileId = parsed
		}
	}

	_, err = wc.DB.SaveTranscript(ctx, patientFileId, gcsURI, transcript)
	if err != nil {
		log.Printf("Error saving transcript: %v", err)
		// Return 500 to retry
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save transcript"})
		return
	}

	log.Printf("Successfully completed STT pipeline for %s", objectId)
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

	// Decode the data payload
	var payload struct {
		TranscriptID  string `json:"transcriptId"`
		PatientFileID string `json:"patientFileId"`
		Transcript    string `json:"transcript"`
	}
	if err := json.Unmarshal(pubSubMsg.Message.Data, &payload); err != nil {
		log.Printf("Error decoding payload: %v", err)
		c.Status(http.StatusOK) // Return 200 so it doesn't retry a bad payload
		return
	}

	ctx := context.Background()
	prompt := "Cel: Szybki, rzeczowy przegląd sesji. Struktura: 1. Główny problem/temat przewodni sesji."
	
	reportText, err := wc.LLM.GenerateReport(ctx, payload.Transcript, prompt)
	if err != nil {
		log.Printf("Error generating report: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate report"})
		return
	}

	patientFileID, _ := uuid.Parse(payload.PatientFileID)
	transcriptID, _ := uuid.Parse(payload.TranscriptID)

	_, err = wc.DB.SaveReport(ctx, patientFileID, transcriptID, reportText)
	if err != nil {
		log.Printf("Error saving report: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save report"})
		return
	}

	log.Printf("Successfully generated and saved LLM report for transcript %s", payload.TranscriptID)
	c.Status(http.StatusOK)
}
