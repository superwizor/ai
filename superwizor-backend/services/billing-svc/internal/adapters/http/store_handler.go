// store_handler.go — wejścia ze sklepów: notyfikacje App Store,
// Real-time developer notifications Google Play i cron uzgadniania.
//
// docs/70 §7.3. Reguła wspólna dla wszystkich trzech ścieżek:
// **notyfikacja jest sygnałem, API sklepu jest prawdą**. Nigdy nie
// zmieniamy uprawnienia na podstawie samej treści zdarzenia — po
// każdym sygnale pytamy sklep o bieżący stan i dopiero on trafia do
// bazy. Dzięki temu zgubiona, powtórzona albo spóźniona notyfikacja nie
// wprowadza rozjazdu (E12, E21).
package http

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	billinggrpc "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/grpc"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// AppleNotificationDecoder — port na weryfikator App Store. Interfejs,
// nie konkret, żeby handler dał się testować bez certyfikatów Apple'a.
type AppleNotificationDecoder interface {
	DecodeNotificationJSON(signedPayload string) (uuid string, notificationType string, state billinggrpc.StoreState, err error)
}

// StoreStateApplier — zapis stanu do bazy. W produkcji to *grpc.Server.
type StoreStateApplier interface {
	ApplyStoreStateForSubscription(ctx context.Context, st billinggrpc.StoreState) error
}

// PlayStateFetcher odczytuje stan subskrypcji Google po purchaseToken.
type PlayStateFetcher interface {
	FetchState(ctx context.Context, purchaseToken, productID string) (billinggrpc.StoreState, error)
}

// StoreHandler obsługuje trzy endpointy sklepowe.
type StoreHandler struct {
	pool    *pgxpool.Pool
	queries *db.Queries
	logger  *slog.Logger
	apple   AppleNotificationDecoder
	play    PlayStateFetcher
	applier StoreStateApplier
}

func NewStoreHandler(
	pool *pgxpool.Pool, logger *slog.Logger,
	apple AppleNotificationDecoder, play PlayStateFetcher, applier StoreStateApplier,
) *StoreHandler {
	if logger == nil {
		logger = slog.Default()
	}
	return &StoreHandler{
		pool:    pool,
		queries: db.New(pool),
		logger:  logger,
		apple:   apple,
		play:    play,
		applier: applier,
	}
}

// RegisterRoutes wpina endpointy. Notyfikacje Apple'a NIE mają
// middleware'u OIDC — Apple nie wysyła tokena, uwierzytelnia je podpis
// JWS sprawdzany w dekoderze. RTDN Google przychodzi jako push z
// Pub/Suba, więc ma token OIDC i idzie przez ten sam middleware co crony.
func (h *StoreHandler) RegisterRoutes(mux *http.ServeMux, schedAuth *SchedulerAuthMiddleware) {
	mux.HandleFunc("POST /apple/notifications", h.handleAppleNotification)
	mux.HandleFunc("POST /google/rtdn", schedAuth.Require(h.handlePlayNotification))
	mux.HandleFunc("POST /admin/store-reconcile", schedAuth.Require(h.handleReconcile))
}

// ─── Apple ────────────────────────────────────────────────────────────

func (h *StoreHandler) handleAppleNotification(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.apple == nil || h.applier == nil {
		// Brak konfiguracji nie może wyglądać jak sukces: Apple ponawia
		// notyfikacje przez kilka dni, więc 503 daje nam czas na
		// dokończenie wdrożenia bez utraty zdarzeń.
		h.logger.ErrorContext(ctx, "apple notifications: weryfikator nieskonfigurowany")
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "apple verifier not configured"})
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 2<<20))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "cannot read body"})
		return
	}
	var envelope struct {
		SignedPayload string `json:"signedPayload"`
	}
	if err := json.Unmarshal(body, &envelope); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}

	uid, notifType, state, err := h.apple.DecodeNotificationJSON(envelope.SignedPayload)
	if err != nil {
		// Podpis jest jedynym uwierzytelnieniem tego endpointu — jego brak
		// to nie „nieprawidłowe dane", tylko odrzucone żądanie.
		h.logger.WarnContext(ctx, "apple notifications: odrzucona notyfikacja", "error", err)
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "signature verification failed"})
		return
	}

	dup, eventRowID := h.recordEvent(ctx, "APPLE_IAP", uid, notifType, body)
	if dup {
		writeJSON(w, http.StatusOK, map[string]string{"status": "duplicate"})
		return
	}

	if err := h.applier.ApplyStoreStateForSubscription(ctx, state); err != nil {
		h.logger.ErrorContext(ctx, "apple notifications: zapis stanu nieudany",
			"notification", notifType, "error", err)
		// 500 → Apple ponowi. To jest pożądane: wolimy powtórkę niż
		// cichą utratę informacji o zwrocie albo wygaśnięciu.
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "apply failed"})
		return
	}
	h.markProcessed(ctx, eventRowID)
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ─── Google Play (RTDN przez Pub/Sub push) ────────────────────────────

type pubsubPush struct {
	Message struct {
		Data      string `json:"data"`
		MessageID string `json:"messageId"`
	} `json:"message"`
	Subscription string `json:"subscription"`
}

type developerNotification struct {
	Version                  string `json:"version"`
	PackageName              string `json:"packageName"`
	EventTimeMillis          string `json:"eventTimeMillis"`
	SubscriptionNotification *struct {
		Version          string `json:"version"`
		NotificationType int    `json:"notificationType"`
		PurchaseToken    string `json:"purchaseToken"`
		SubscriptionID   string `json:"subscriptionId"`
	} `json:"subscriptionNotification"`
	TestNotification *struct {
		Version string `json:"version"`
	} `json:"testNotification"`
}

// Typy RTDN, które oznaczają cofnięcie zakupu. Reszta stanów wynika z
// odpowiedzi API, więc nie ma sensu ich tu wyliczać.
const (
	rtdnRevoked = 12 // SUBSCRIPTION_REVOKED
	rtdnExpired = 13 // SUBSCRIPTION_EXPIRED
)

func (h *StoreHandler) handlePlayNotification(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.play == nil || h.applier == nil {
		h.logger.ErrorContext(ctx, "play rtdn: weryfikator nieskonfigurowany")
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "play verifier not configured"})
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "cannot read body"})
		return
	}
	var push pubsubPush
	if err := json.Unmarshal(body, &push); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid push envelope"})
		return
	}
	raw, err := base64.StdEncoding.DecodeString(push.Message.Data)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid message data"})
		return
	}
	var dn developerNotification
	if err := json.Unmarshal(raw, &dn); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid notification json"})
		return
	}
	// Wiadomość testowa z Play Console — potwierdzamy odbiór i kończymy.
	if dn.TestNotification != nil || dn.SubscriptionNotification == nil {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ignored"})
		return
	}

	eventType := "SUBSCRIPTION_NOTIFICATION_" + strconv.Itoa(dn.SubscriptionNotification.NotificationType)
	dup, eventRowID := h.recordEvent(ctx, "GOOGLE_IAP", push.Message.MessageID, eventType, raw)
	if dup {
		writeJSON(w, http.StatusOK, map[string]string{"status": "duplicate"})
		return
	}

	state, err := h.play.FetchState(ctx,
		dn.SubscriptionNotification.PurchaseToken,
		dn.SubscriptionNotification.SubscriptionID)
	if err != nil {
		h.logger.ErrorContext(ctx, "play rtdn: odczyt stanu nieudany", "error", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "fetch failed"})
		return
	}
	// Cofnięcia API v2 wprost nie pokazuje — niesie je dopiero typ
	// notyfikacji, więc tu go nakładamy.
	switch dn.SubscriptionNotification.NotificationType {
	case rtdnRevoked:
		state.Status = billinggrpc.StoreStatusRevoked
		now := time.Now()
		state.RevocationDate = &now
		state.RevocationReason = "PLAY_REVOKED"
	case rtdnExpired:
		state.Status = billinggrpc.StoreStatusExpired
	}

	if err := h.applier.ApplyStoreStateForSubscription(ctx, state); err != nil {
		h.logger.ErrorContext(ctx, "play rtdn: zapis stanu nieudany", "error", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "apply failed"})
		return
	}
	h.markProcessed(ctx, eventRowID)
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ─── Cron uzgadniania ─────────────────────────────────────────────────

// handleReconcile domyka lukę po zgubionych notyfikacjach (docs/70 E12):
// bierze subskrypcje sklepowe, którym minął okres (albo okno łaski), i
// pyta sklep, co się z nimi naprawdę stało.
func (h *StoreHandler) handleReconcile(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	rows, err := h.queries.ListStoreSubscriptionsForReconcile(ctx)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "list failed"})
		return
	}
	if n, derr := h.queries.DeleteExpiredPendingCheckouts(ctx); derr == nil && n > 0 {
		h.logger.InfoContext(ctx, "store reconcile: sprzątnięto wygasłe blokady zakupu", "count", n)
	}

	var checked, updated, failed int
	for _, row := range rows {
		checked++
		var fetcher PlayStateFetcher
		switch string(row.Provider) {
		case "GOOGLE_IAP":
			fetcher = h.play
		case "APPLE_IAP":
			fetcher = h.appleFetcher()
		}
		if fetcher == nil {
			continue
		}
		product := ""
		if row.StoreProductID != nil {
			product = *row.StoreProductID
		}
		state, ferr := fetcher.FetchState(ctx, row.ProviderSubscriptionID, product)
		if ferr != nil {
			failed++
			h.logger.WarnContext(ctx, "store reconcile: odczyt nieudany",
				"provider", row.Provider, "subscription", row.ID.String(), "error", ferr)
			continue
		}
		if err := h.applier.ApplyStoreStateForSubscription(ctx, state); err != nil {
			failed++
			h.logger.WarnContext(ctx, "store reconcile: zapis nieudany",
				"subscription", row.ID.String(), "error", err)
			continue
		}
		updated++
	}
	writeJSON(w, http.StatusOK, map[string]int{
		"checked": checked, "updated": updated, "failed": failed,
	})
}

// appleFetcher zwraca weryfikator Apple'a jako PlayStateFetcher — obie
// implementacje mają tę samą metodę FetchState, więc cron nie musi
// rozróżniać dostawców poza wyborem obiektu.
func (h *StoreHandler) appleFetcher() PlayStateFetcher {
	if f, ok := h.apple.(PlayStateFetcher); ok {
		return f
	}
	return nil
}

// ─── payment_events ───────────────────────────────────────────────────

// recordEvent zapisuje zdarzenie i mówi, czy było już widziane.
// UNIQUE(provider, provider_event_id) na payment_events jest tym samym
// mechanizmem idempotencji, co dla Stripe'a (ADR-BL-002): przy konflikcie
// `ON CONFLICT DO NOTHING RETURNING` nie zwraca wiersza, czyli pgx daje
// ErrNoRows — to jest sygnał duplikatu, nie awaria.
func (h *StoreHandler) recordEvent(ctx context.Context, provider, eventID, eventType string, raw []byte) (duplicate bool, eventRowID uuid.UUID) {
	if eventID == "" {
		// Bez identyfikatora nie da się odróżnić powtórki od nowego
		// zdarzenia — przetwarzamy, ale zostawiamy ślad w logu.
		h.logger.WarnContext(ctx, "store notification bez identyfikatora zdarzenia", "provider", provider)
		return false, uuid.Nil
	}
	row, err := h.queries.CreatePaymentEvent(ctx, db.CreatePaymentEventParams{
		Provider:         db.PaymentProvider(provider),
		ProviderEventID:  eventID,
		EventType:        eventType,
		RawPayload:       raw,
		ProcessingStatus: "PENDING",
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return true, uuid.Nil
		}
		h.logger.WarnContext(ctx, "payment_events: zapis nieudany", "provider", provider, "error", err)
		return false, uuid.Nil
	}
	return false, row.ID
}

func (h *StoreHandler) markProcessed(ctx context.Context, eventRowID uuid.UUID) {
	if eventRowID == uuid.Nil {
		return
	}
	if err := h.queries.MarkPaymentEventProcessed(ctx, eventRowID); err != nil {
		h.logger.WarnContext(ctx, "payment_events: oznaczenie PROCESSED nieudane", "error", err)
	}
}
