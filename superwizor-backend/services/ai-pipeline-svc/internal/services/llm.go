package services

import (
	"context"
	"fmt"
	"log"

	"cloud.google.com/go/vertexai/genai"
)

type LLMService struct {
	client    *genai.Client
	projectID string
	location  string
}

func NewLLMService(ctx context.Context, projectID string) (*LLMService, error) {
	location := "europe-west4" // Recommended region for Gemini as per ADR
	client, err := genai.NewClient(ctx, projectID, location)
	if err != nil {
		return nil, fmt.Errorf("failed to create vertex ai client: %v", err)
	}
	return &LLMService{
		client:    client,
		projectID: projectID,
		location:  location,
	}, nil
}

func (s *LLMService) GenerateReport(ctx context.Context, transcript string, prompt string) (string, error) {
	log.Printf("Generating report using Gemini 3.1 FLASH")

	model := s.client.GenerativeModel("gemini-3.1-flash")
	model.SetTemperature(0.2) // Low temp for more clinical fact-based outputs

	// Constructing the full prompt
	fullPrompt := fmt.Sprintf("%s\n\nTRANSKRYPT:\n%s", prompt, transcript)

	resp, err := model.GenerateContent(ctx, genai.Text(fullPrompt))
	if err != nil {
		return "", fmt.Errorf("generate content error: %v", err)
	}

	if len(resp.Candidates) == 0 || len(resp.Candidates[0].Content.Parts) == 0 {
		return "", fmt.Errorf("empty response from Gemini")
	}

	// For simplicity, converting first part to string
	part := resp.Candidates[0].Content.Parts[0]
	if text, ok := part.(genai.Text); ok {
		return string(text), nil
	}

	return "", fmt.Errorf("unexpected content part type")
}
