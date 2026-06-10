package http

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"strings"

	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
)

// ContactHandler handles contact submissions from the marketing website.
type ContactHandler struct {
	notificationClient notificationv1.NotificationServiceClient
	logger             *slog.Logger
}

// NewContactHandler returns a new ContactHandler instance.
func NewContactHandler(notificationClient notificationv1.NotificationServiceClient, logger *slog.Logger) *ContactHandler {
	if logger == nil {
		logger = slog.Default()
	}
	return &ContactHandler{
		notificationClient: notificationClient,
		logger:             logger,
	}
}

// RegisterRoutes registers the contact handler endpoint with the router.
func (h *ContactHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /contact", h.handleContact)
}

type contactRequest struct {
	Name    string `json:"name"`
	Email   string `json:"email"`
	Subject string `json:"subject"`
	Message string `json:"message"`
}

type contactResponse struct {
	Status  string `json:"status"`
	Message string `json:"message"`
}

func (h *ContactHandler) handleContact(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Parse JSON body
	var req contactRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.logger.WarnContext(ctx, "contact handler: decode body failed", "error", err)
		writeError(w, http.StatusBadRequest, "Invalid JSON payload", err)
		return
	}

	// Basic validation
	if strings.TrimSpace(req.Name) == "" {
		h.logger.WarnContext(ctx, "contact handler: empty name")
		writeJSON(w, http.StatusBadRequest, contactResponse{Status: "error", Message: "Name is required"})
		return
	}
	if strings.TrimSpace(req.Email) == "" || !strings.Contains(req.Email, "@") {
		h.logger.WarnContext(ctx, "contact handler: invalid email", "email", req.Email)
		writeJSON(w, http.StatusBadRequest, contactResponse{Status: "error", Message: "A valid email is required"})
		return
	}
	if strings.TrimSpace(req.Message) == "" {
		h.logger.WarnContext(ctx, "contact handler: empty message")
		writeJSON(w, http.StatusBadRequest, contactResponse{Status: "error", Message: "Message is required"})
		return
	}

	// Call notification-svc via gRPC
	if h.notificationClient == nil {
		h.logger.ErrorContext(ctx, "contact handler: notification service client not initialized")
		writeJSON(w, http.StatusInternalServerError, contactResponse{Status: "error", Message: "Email service temporarily unavailable"})
		return
	}

	h.logger.InfoContext(ctx, "contact handler: forwarding request to notification-svc", "sender_email", req.Email)
	_, err := h.notificationClient.SendContactEmail(ctx, &notificationv1.SendContactEmailRequest{
		Name:    req.Name,
		Email:   req.Email,
		Subject: req.Subject,
		Message: req.Message,
	})
	if err != nil {
		h.logger.ErrorContext(ctx, "contact handler: failed to send email via notification-svc", "error", err)
		writeError(w, http.StatusInternalServerError, "Failed to send message", err)
		return
	}

	h.logger.InfoContext(ctx, "contact handler: message sent successfully")
	writeJSON(w, http.StatusOK, contactResponse{
		Status:  "ok",
		Message: "Message sent successfully",
	})
}
