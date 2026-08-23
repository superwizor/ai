package notificationworker

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/cloudevents/sdk-go/v2/event"
	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/services/notification-svc/internal/adapters/firestore"
	pgstore "github.com/superwizor-ai/backend/services/notification-svc/internal/adapters/postgres"
)

// Konsument report.experimental_ready (plan 16 §2.5).
//
// OSOBNA FUNKCJA, nie galaz w ProcessSessionStatusChanged. Tamten
// strumien jest lustrem produkcyjnym: na "done" wysyla push "Raport
// gotowy" i przestawia stan sesji w panelu klienta. Raport
// eksperymentalny nie jest materialem klinicznym i nie ma prawa
// uruchomic zadnej z tych rzeczy.
//
// CO ROBI: wylacznie dokument inbox, ktory odswieza liste raportow w
// aplikacji. ZERO pusha — ekspert zamowil ten raport swiadomie i nie
// potrzebuje dzwonka, a dzwonek "Raport gotowy" o eksperymencie bylby
// dokladnie tym pomyleniem, przed ktorym broni caly ten tryb.

type experimentalReadyEvent struct {
	SessionID   string `json:"session_id"`
	ReportID    string `json:"report_id"`
	TherapistID string `json:"therapist_id"`
}

func init() {
	functions.CloudEvent("ProcessExperimentalReportReady", ProcessExperimentalReportReady)
}

func ProcessExperimentalReportReady(ctx context.Context, e event.Event) error {
	logger := slog.With("function", "notification-worker",
		"trigger", "report.experimental_ready")

	var msgData MessagePublishedData
	if err := e.DataAs(&msgData); err != nil {
		logger.Error("decode cloudevent", "error", err)
		return err
	}
	var ev experimentalReadyEvent
	if err := json.Unmarshal(msgData.Message.Data, &ev); err != nil {
		logger.Error("parse payload", "error", err, "raw", string(msgData.Message.Data))
		return err
	}
	logger = logger.With("session_id", ev.SessionID, "report_id", ev.ReportID)

	if store == nil || fsWriter == nil {
		logger.Warn("no store/firestore — skipping (mock mode)")
		return nil
	}
	sessionID, err := uuid.Parse(ev.SessionID)
	if err != nil {
		logger.Error("invalid session_id", "error", err)
		return err
	}
	session, err := store.LoadSessionForNotification(ctx, sessionID)
	if err != nil {
		logger.Error("load session", "error", err)
		return fmt.Errorf("load session: %w", err)
	}

	// Klucz idempotencji po RAPORCIE, nie po sesji: jedna sesja moze
	// miec wiele raportow eksperymentalnych (rozne modalnosci, rozne
	// wersje ontologii), a klucz po sesji zjadalby wszystkie poza
	// pierwszym.
	deliveryID, err := store.InsertNotificationDelivery(ctx, pgstore.InsertDeliveryParams{
		UserID:           session.TherapistID,
		SessionID:        &session.SessionID,
		NotificationType: "experimental_report_ready",
		IdempotencyKey:   ev.ReportID + ":experimental_report_ready",
	})
	if err != nil {
		if isAlreadyDelivered(err) {
			logger.Info("duplikat — dokument inbox juz zapisany")
			return nil
		}
		logger.Error("insert notification_delivery", "error", err)
		return err
	}

	title, body := localizeExperimentalReady(session.TherapistLocale)
	if werr := fsWriter.WriteInboxNotification(ctx, firestore.InboxNotification{
		NotificationID:   deliveryID.String(),
		FirebaseUID:      session.TherapistFirebaseUID,
		NotificationType: "experimental_report_ready",
		Title:            title,
		Body:             body,
		SessionID:        ev.SessionID,
	}); werr != nil {
		logger.Error("write inbox", "error", werr)
		return werr
	}

	logger.Info("dokument inbox zapisany", "delivery_id", deliveryID)
	return nil
}

// localizeExperimentalReady zwraca tresc dokumentu inbox.
//
// Oznaczenie "EKSPERYMENT" jest juz w TYTULE, nie tylko w tresci raportu:
// lista raportow pokazuje tytul, a ekspert ma widziec roznice zanim
// otworzy dokument.
func localizeExperimentalReady(locale string) (title, body string) {
	if locale == "en" {
		return "Experimental report ready",
			"Generated on an unapproved ontology. Not for clinical use."
	}
	return "Raport eksperymentalny gotowy",
		"Powstał na niezautoryzowanej ontologii. Nie służy do pracy klinicznej."
}
