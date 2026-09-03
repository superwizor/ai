package grpc

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// Zakupy w aplikacji — docs/70 §7.
//
// Sklep jest trzecim dostawcą obok Stripe'a i MANUAL, a nie osobnym
// światem: kończy w tej samej tabeli `subscriptions`, z tym samym
// licznikiem tokenów i tym samym gate'em w ReserveCredit. Cała różnica
// mieści się w tym pliku i w dwóch weryfikatorach (appstore/, playstore/).
//
// Zasada bezpieczeństwa: aplikacja NIGDY nie przyznaje sobie uprawnienia.
// Przysyła dowód zakupu, my pytamy sklep, dopiero odpowiedź sklepu
// zmienia stan. Dlatego VerifyStorePurchase jest jedyną drogą, a
// StoreVerifier nie ma metody „zaufaj klientowi".

const (
	providerApple  = "APPLE_IAP"
	providerGoogle = "GOOGLE_IAP"

	// Ile czasu użytkownik ma na dokończenie zakupu w sklepie, zanim
	// zwolnimy blokadę drugiego kanału (docs/70 E22).
	storeCheckoutTTL = 30 * time.Minute
)

// Stany subskrypcji sklepowej sprowadzone do wspólnego słownika. Apple i
// Google nazywają je inaczej, ale rozstrzygamy je tak samo.
const (
	StoreStatusActive  = "ACTIVE"  // opłacona, w okresie
	StoreStatusGrace   = "GRACE"   // nieudane obciążenie, dostęp trwa
	StoreStatusRetry   = "RETRY"   // billing retry / on hold — dostęp wstrzymany
	StoreStatusPaused  = "PAUSED"  // tylko Google
	StoreStatusExpired = "EXPIRED" // wygasła
	StoreStatusRevoked = "REVOKED" // zwrot / cofnięcie zakupu
)

// StoreProof to dowód zakupu przysłany przez aplikację.
type StoreProof struct {
	JWSTransaction string // iOS (StoreKit 2)
	PurchaseToken  string // Android (Play Billing)
	ProductID      string // Android: token sam nie niesie produktu
}

// StoreState to znormalizowana odpowiedź sklepu.
type StoreState struct {
	Provider              string
	TransactionID         string
	OriginalTransactionID string
	ProductID             string
	PurchaseDate          time.Time
	ExpiresDate           time.Time
	Environment           string // Production | Sandbox
	AppAccountToken       string // UUID organizacji, jeśli sklep go zna
	AutoRenew             bool
	Status                string
	GraceUntil            *time.Time
	RevocationDate        *time.Time
	RevocationReason      string
	OfferType             string
	OfferIdentifier       string
	Raw                   []byte
}

// StoreVerifier — port na App Store Server API / Play Developer API.
type StoreVerifier interface {
	// VerifyPurchase sprawdza dowód zakupu u dostawcy i zwraca stan.
	VerifyPurchase(ctx context.Context, proof StoreProof) (StoreState, error)
	// FetchState odczytuje bieżący stan subskrypcji — używane przez
	// notyfikacje i cron uzgadniania. Notyfikacja jest sygnałem, API
	// sklepu jest prawdą (docs/70 E12, E21).
	FetchState(ctx context.Context, originalTransactionID, productID string) (StoreState, error)
	// Acknowledge potwierdza zakup. Google wymaga tego w 3 dni, inaczej
	// automatycznie zwraca pieniądze; Apple nie ma odpowiednika (no-op).
	Acknowledge(ctx context.Context, st StoreState) error
}

// ─── GetBillingSurface ────────────────────────────────────────────────

// GetBillingSurface mówi aplikacji, co wolno pokazać na paywallu.
//
// Decyzja jest po stronie serwera, nie klienta: blokady krzyżowe między
// dostawcami, organizacje rozliczane przez miejsca i flagi IAP_* muszą
// dać ten sam wynik niezależnie od wersji aplikacji, którą ktoś ma
// zainstalowaną (docs/70 §5.1, E26, E27).
func (s *Server) GetBillingSurface(ctx context.Context, _ *emptypb.Empty) (*billingv1.BillingSurface, error) {
	caller := resolveRequestCaller(ctx)
	if caller.organizationID == nil {
		return nil, status.Error(codes.Unauthenticated, "caller organization unknown")
	}
	orgID := *caller.organizationID
	platform := platformFromMetadata(ctx)

	out := &billingv1.BillingSurface{
		WebLinkMode: s.appConfig(ctx, "IAP_WEB_LINK_MODE", "NONE"),
	}

	sub, err := s.queries.GetActiveSubscriptionByOrg(ctx, orgID)
	switch {
	case err == nil:
		out.ActiveProvider = string(sub.Provider)
		out.PlanTier = string(sub.PlanTier)
		out.Status = string(sub.Status)
	case errors.Is(err, pgx.ErrNoRows):
		// Brak aktywnej subskrypcji — trial wygasł albo nigdy nie było.
	default:
		return nil, status.Errorf(codes.Internal, "subscription lookup: %v", err)
	}

	provider := storeProviderForPlatform(platform)
	decision := s.purchaseDecision(ctx, orgID, provider, err == nil, sub)
	out.CanPurchase = decision.allowed
	out.BlockReason = decision.reason
	if decision.blockedUntil != nil {
		out.BlockedUntil = timestamppb.New(*decision.blockedUntil)
	}
	out.ShowRestore = provider != "" && decision.iapEnabled
	out.ManageUrl = manageURL(string(sub.Provider), sub.StoreProductID)

	if decision.allowed && provider != "" {
		plans, perr := s.queries.ListStorePlans(ctx, provider)
		if perr != nil {
			return nil, status.Errorf(codes.Internal, "store plans: %v", perr)
		}
		for _, p := range plans {
			pid := storeProductID(provider, p.AppleProductID, p.GoogleProductID)
			if pid == "" {
				continue
			}
			out.Products = append(out.Products, &billingv1.StoreProduct{
				ProductId:           pid,
				PlanTier:            string(p.Tier),
				PlanCycle:           string(p.Cycle),
				TokensPerPeriod:     p.TokensPerPeriod,
				ReferencePriceGross: numericToString(p.StorePriceGross),
				CurrencyCode:        p.CurrencyCode,
			})
		}
	}
	return out, nil
}

type purchaseDecision struct {
	allowed      bool
	reason       string
	blockedUntil *time.Time
	iapEnabled   bool
}

// purchaseDecision zbiera w jednym miejscu całą macierz z docs/70 §5.1.
// Wołane i przez GetBillingSurface (co pokazać), i przez
// BeginStorePurchase (czy wpuścić) — żeby ekran i bramka nigdy nie
// powiedziały czegoś innego.
func (s *Server) purchaseDecision(
	ctx context.Context, orgID uuid.UUID, provider string,
	hasSub bool, sub db.GetActiveSubscriptionByOrgRow,
) purchaseDecision {
	d := purchaseDecision{}
	if provider == "" {
		d.reason = "IAP_DISABLED"
		return d
	}
	flagKey := "IAP_ENABLED_IOS"
	if provider == providerGoogle {
		flagKey = "IAP_ENABLED_ANDROID"
	}
	d.iapEnabled = s.appConfig(ctx, flagKey, "false") == "true"
	if !d.iapEnabled {
		d.reason = "IAP_DISABLED"
		return d
	}

	// Organizacja rozliczana przez miejsca ma subskrypcję MANUAL
	// wystawioną przez administratora — zakup terapeuty zderzyłby się z
	// idx_subscriptions_one_active_per_org i odebrał firmie plan.
	if hasSeats, err := s.queries.OrgHasSeatAllocations(ctx, orgID); err == nil && hasSeats {
		d.reason = "ORG_MANAGED"
		return d
	}

	if hasSub {
		switch string(sub.Provider) {
		case providerApple, providerGoogle:
			// Ta sama platforma = zmiana planu robi się w sklepie
			// (upgrade/downgrade w grupie subskrypcji), nie u nas.
			// Inna platforma = twarda blokada do końca okresu.
			if string(sub.Provider) != provider {
				d.reason = "OTHER_PROVIDER_ACTIVE"
				end := sub.CurrentPeriodEnd
				d.blockedUntil = &end
				return d
			}
			d.allowed = true
			return d
		case "STRIPE", "P24":
			d.reason = "OTHER_PROVIDER_ACTIVE"
			end := sub.CurrentPeriodEnd
			d.blockedUntil = &end
			return d
		case "MANUAL":
			// TRIAL i BETA są darmowym wejściem — zakup je zastępuje.
			// Inne MANUAL (bootstrap, pilotaże) też, bo nikt za nie nie
			// płaci kartą; wygasza je DeactivateNonStoreSubscriptions.
		}
	}

	// Równoległy checkout w drugim kanale (docs/70 E22).
	if other, err := s.queries.GetOtherPendingCheckout(ctx, db.GetOtherPendingCheckoutParams{
		OrganizationID: orgID,
		Channel:        channelForProvider(provider),
	}); err == nil {
		d.reason = "PENDING_CHECKOUT"
		exp := other.ExpiresAt
		d.blockedUntil = &exp
		return d
	}

	d.allowed = true
	return d
}

// ─── BeginStorePurchase ───────────────────────────────────────────────

func (s *Server) BeginStorePurchase(ctx context.Context, req *billingv1.BeginStorePurchaseRequest) (*billingv1.BeginStorePurchaseResponse, error) {
	caller := resolveRequestCaller(ctx)
	if caller.organizationID == nil {
		return nil, status.Error(codes.Unauthenticated, "caller organization unknown")
	}
	orgID := *caller.organizationID
	provider := storeProviderForPlatform(strings.ToUpper(strings.TrimSpace(req.GetPlatform())))
	if provider == "" {
		return nil, status.Error(codes.InvalidArgument, "platform must be IOS or ANDROID")
	}
	if strings.TrimSpace(req.GetProductId()) == "" {
		return nil, status.Error(codes.InvalidArgument, "product_id required")
	}
	reqProduct := req.GetProductId()
	if _, err := s.queries.GetPlanByStoreProductID(ctx, db.GetPlanByStoreProductIDParams{
		AppleProductID: &reqProduct,
		Column2:        provider,
	}); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Errorf(codes.InvalidArgument,
				"UNKNOWN_PRODUCT: %s nie odpowiada żadnemu aktywnemu planowi", req.GetProductId())
		}
		return nil, status.Errorf(codes.Internal, "plan lookup: %v", err)
	}

	sub, subErr := s.queries.GetActiveSubscriptionByOrg(ctx, orgID)
	if subErr != nil && !errors.Is(subErr, pgx.ErrNoRows) {
		return nil, status.Errorf(codes.Internal, "subscription lookup: %v", subErr)
	}
	d := s.purchaseDecision(ctx, orgID, provider, subErr == nil, sub)

	resp := &billingv1.BeginStorePurchaseResponse{Allowed: d.allowed, BlockReason: d.reason}
	if d.blockedUntil != nil {
		resp.BlockedUntil = timestamppb.New(*d.blockedUntil)
	}
	if !d.allowed {
		return resp, nil
	}

	// appAccountToken to jedyne wiązanie transakcji z kontem — sklep nie
	// przekaże nam ani e-maila, ani tożsamości płatniczej. Używamy
	// organization_id, bo uprawnienie żyje na organizacji.
	resp.AppAccountToken = orgID.String()

	if err := s.queries.UpsertPendingCheckout(ctx, db.UpsertPendingCheckoutParams{
		OrganizationID: orgID,
		Channel:        channelForProvider(provider),
		Reference:      req.GetProductId(),
		ExpiresAt:      time.Now().Add(storeCheckoutTTL),
	}); err != nil {
		// Blokada równoległych kanałów jest zabezpieczeniem, nie
		// warunkiem zakupu — jej brak nie może zatrzymać płacącego
		// użytkownika.
		s.logWarn(ctx, "pending checkout: zapis nieudany", "org", orgID.String(), "error", err)
	}
	return resp, nil
}

// ─── VerifyStorePurchase / RestoreStorePurchases ──────────────────────

func (s *Server) VerifyStorePurchase(ctx context.Context, req *billingv1.VerifyStorePurchaseRequest) (*billingv1.Subscription, error) {
	caller := resolveRequestCaller(ctx)
	if caller.organizationID == nil {
		return nil, status.Error(codes.Unauthenticated, "caller organization unknown")
	}
	provider := storeProviderForPlatform(strings.ToUpper(strings.TrimSpace(req.GetPlatform())))
	verifier, err := s.verifierFor(provider)
	if err != nil {
		return nil, err
	}
	st, err := verifier.VerifyPurchase(ctx, StoreProof{
		JWSTransaction: req.GetJwsTransaction(),
		PurchaseToken:  req.GetPurchaseToken(),
		ProductID:      req.GetProductId(),
	})
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "STORE_VERIFICATION_FAILED: %v", err)
	}
	return s.claimStoreState(ctx, *caller.organizationID, caller.userID, verifier, st)
}

func (s *Server) RestoreStorePurchases(ctx context.Context, req *billingv1.RestoreStorePurchasesRequest) (*billingv1.Subscription, error) {
	caller := resolveRequestCaller(ctx)
	if caller.organizationID == nil {
		return nil, status.Error(codes.Unauthenticated, "caller organization unknown")
	}
	provider := storeProviderForPlatform(strings.ToUpper(strings.TrimSpace(req.GetPlatform())))
	verifier, err := s.verifierFor(provider)
	if err != nil {
		return nil, err
	}

	proofs := make([]StoreProof, 0, len(req.GetJwsTransactions())+len(req.GetPurchaseTokens()))
	for _, jws := range req.GetJwsTransactions() {
		proofs = append(proofs, StoreProof{JWSTransaction: jws})
	}
	for _, tok := range req.GetPurchaseTokens() {
		proofs = append(proofs, StoreProof{PurchaseToken: tok, ProductID: req.GetProductId()})
	}
	if len(proofs) == 0 {
		return nil, status.Error(codes.InvalidArgument, "no transactions to restore")
	}

	// Bierzemy najpóźniej wygasającą transakcję: przywracanie ma oddać
	// aktualne uprawnienie, a nie odtworzyć historię zakupów.
	var best *StoreState
	var lastErr error
	for _, p := range proofs {
		st, verr := verifier.VerifyPurchase(ctx, p)
		if verr != nil {
			lastErr = verr
			continue
		}
		if best == nil || st.ExpiresDate.After(best.ExpiresDate) {
			cp := st
			best = &cp
		}
	}
	if best == nil {
		return nil, status.Errorf(codes.InvalidArgument, "STORE_VERIFICATION_FAILED: %v", lastErr)
	}
	return s.claimStoreState(ctx, *caller.organizationID, caller.userID, verifier, *best)
}

// claimStoreState przypisuje zweryfikowaną transakcję do organizacji
// wywołującego — i pilnuje, żeby nie przejęła cudzej.
func (s *Server) claimStoreState(
	ctx context.Context, orgID uuid.UUID, userID *uuid.UUID, verifier StoreVerifier, st StoreState,
) (*billingv1.Subscription, error) {
	if st.Environment == "Sandbox" && s.appConfig(ctx, "IAP_ALLOW_SANDBOX", "true") != "true" {
		return nil, status.Error(codes.FailedPrecondition,
			"SANDBOX_NOT_ALLOWED: zakupy testowe są wyłączone na tym środowisku")
	}

	// docs/70 E1: transakcja przypisana już do innej organizacji nie może
	// zostać przejęta przez „Przywróć zakupy" na drugim koncie.
	owner, err := s.queries.GetStoreTransactionOwner(ctx, db.GetStoreTransactionOwnerParams{
		Provider:              db.PaymentProvider(st.Provider),
		OriginalTransactionID: st.OriginalTransactionID,
	})
	if err == nil && owner.OrganizationID.Valid && uuid.UUID(owner.OrganizationID.Bytes) != orgID {
		return nil, status.Error(codes.PermissionDenied,
			"TRANSACTION_OWNED_BY_ANOTHER_ACCOUNT: ten zakup należy do innego konta SuperWizor")
	}
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, status.Errorf(codes.Internal, "transaction owner lookup: %v", err)
	}
	// To samo z drugiej strony: jeśli sklep zna appAccountToken, musi
	// wskazywać na tę organizację.
	if st.AppAccountToken != "" {
		if tokenOrg, perr := uuid.Parse(st.AppAccountToken); perr == nil && tokenOrg != orgID {
			return nil, status.Error(codes.PermissionDenied,
				"TRANSACTION_OWNED_BY_ANOTHER_ACCOUNT: zakup jest przypisany do innego konta SuperWizor")
		}
	}

	sub, err := s.applyStoreState(ctx, orgID, userID, st)
	if err != nil {
		return nil, err
	}

	// Google zwraca pieniądze automatycznie, jeśli zakup nie zostanie
	// potwierdzony w 3 dni. Potwierdzamy DOPIERO po zapisaniu
	// uprawnienia — odwrotna kolejność zostawiałaby zakup opłacony i
	// niewidoczny w aplikacji.
	if err := verifier.Acknowledge(ctx, st); err != nil {
		s.logWarn(ctx, "store acknowledge nieudane", "provider", st.Provider,
			"transaction", st.TransactionID, "error", err)
	}
	_ = s.queries.DeletePendingCheckout(ctx, db.DeletePendingCheckoutParams{
		OrganizationID: orgID,
		Channel:        channelForProvider(st.Provider),
	})
	return sub, nil
}

// applyStoreState jest JEDYNYM miejscem, w którym stan ze sklepu zmienia
// subskrypcję. Wołają je: VerifyStorePurchase, notyfikacje App Store,
// RTDN Google i cron uzgadniania — wszystkie z tym samym skutkiem.
func (s *Server) applyStoreState(
	ctx context.Context, orgID uuid.UUID, userID *uuid.UUID, st StoreState,
) (*billingv1.Subscription, error) {
	product := st.ProductID
	plan, err := s.queries.GetPlanByStoreProductID(ctx, db.GetPlanByStoreProductIDParams{
		AppleProductID: &product,
		Column2:        st.Provider,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Errorf(codes.FailedPrecondition,
				"UNKNOWN_PRODUCT: produkt %s nie jest zmapowany na plan", st.ProductID)
		}
		return nil, status.Errorf(codes.Internal, "plan lookup: %v", err)
	}

	subStatus, cancelAtPeriodEnd := mapStoreStatus(st)

	tx, err := s.tx.Begin(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "tx begin: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	q := tx.Queries()

	periodEnd := st.ExpiresDate
	if st.GraceUntil != nil && st.GraceUntil.After(periodEnd) {
		periodEnd = *st.GraceUntil
	}
	if periodEnd.IsZero() {
		periodEnd = st.PurchaseDate.AddDate(0, 1, 0)
	}

	params := db.UpsertStoreSubscriptionParams{
		OrganizationID:         orgID,
		PlanID:                 plan.ID,
		Provider:               db.PaymentProvider(st.Provider),
		ProviderSubscriptionID: st.OriginalTransactionID,
		Status:                 db.SubscriptionStatus(subStatus),
		CurrentPeriodStart:     st.PurchaseDate,
		CurrentPeriodEnd:       periodEnd,
		CancelAtPeriodEnd:      cancelAtPeriodEnd,
		StoreEnvironment:       &st.Environment,
		StoreProductID:         &st.ProductID,
		AutoRenew:              &st.AutoRenew,
	}
	if st.GraceUntil != nil {
		params.GraceUntil = pgtype.Timestamptz{Time: *st.GraceUntil, Valid: true}
	}
	if st.RevocationDate != nil {
		params.CanceledAt = pgtype.Timestamptz{Time: *st.RevocationDate, Valid: true}
	} else if subStatus == "CANCELED" {
		params.CanceledAt = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}

	row, err := q.UpsertStoreSubscription(ctx, params)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "upsert store subscription: %v", err)
	}

	// Darmowe wejście (TRIAL/BETA na MANUAL) ustępuje płatnej
	// subskrypcji. Płatnej subskrypcji innego dostawcy NIE dotykamy —
	// dwie równoległe płatności to incydent do zgłoszenia (E22), nie coś
	// do cichego nadpisania.
	if subStatus == "ACTIVE" || subStatus == "TRIALING" {
		if err := q.DeactivateNonStoreSubscriptions(ctx, db.DeactivateNonStoreSubscriptionsParams{
			OrganizationID: orgID,
			ExceptID:       pgtype.UUID{Bytes: row.ID, Valid: true},
		}); err != nil {
			return nil, status.Errorf(codes.Internal, "deactivate trial: %v", err)
		}
	}

	switch {
	case st.Status == StoreStatusRevoked:
		// Zwrot: tokeny już spalone zostają spalone (BR-5), ale dalszego
		// kredytu nie ma.
		if err := q.FreezeCounterAfterRefund(ctx, row.ID); err != nil {
			return nil, status.Errorf(codes.Internal, "freeze counter: %v", err)
		}
	case st.Status == StoreStatusGrace && st.GraceUntil != nil:
		// Grace period przedłuża BIEŻĄCY licznik. Nowa pula należy się
		// dopiero po udanym obciążeniu — inaczej nieudana płatność
		// dawałaby darmowy miesiąc (docs/70 E13).
		if err := q.SetSubscriptionGraceWindow(ctx, db.SetSubscriptionGraceWindowParams{
			SubscriptionID: row.ID,
			PeriodEnd:      *st.GraceUntil,
		}); err != nil {
			return nil, status.Errorf(codes.Internal, "extend grace counter: %v", err)
		}
	case subStatus == "ACTIVE" || subStatus == "TRIALING":
		exists, cerr := q.CheckUsageCounterExists(ctx, db.CheckUsageCounterExistsParams{
			SubscriptionID: row.ID,
			PeriodStart:    st.PurchaseDate,
		})
		if cerr != nil {
			return nil, status.Errorf(codes.Internal, "counter exists: %v", cerr)
		}
		if !exists {
			if _, cerr := q.CreateUsageCounter(ctx, db.CreateUsageCounterParams{
				SubscriptionID: row.ID,
				PeriodStart:    st.PurchaseDate,
				PeriodEnd:      periodEnd,
				TokensLimit:    plan.TokensPerPeriod,
			}); cerr != nil {
				return nil, status.Errorf(codes.Internal, "create counter: %v", cerr)
			}
		}
	}

	raw := st.Raw
	if len(raw) == 0 {
		raw = []byte("{}")
	}
	txParams := db.UpsertStoreTransactionParams{
		Provider:              db.PaymentProvider(st.Provider),
		TransactionID:         st.TransactionID,
		OriginalTransactionID: st.OriginalTransactionID,
		ProductID:             st.ProductID,
		PurchaseDate:          st.PurchaseDate,
		Environment:           st.Environment,
		RawPayload:            raw,
		OrganizationID:        pgtype.UUID{Bytes: orgID, Valid: true},
	}
	if !st.ExpiresDate.IsZero() {
		txParams.ExpiresDate = pgtype.Timestamptz{Time: st.ExpiresDate, Valid: true}
	}
	if userID != nil {
		txParams.UserID = pgtype.UUID{Bytes: *userID, Valid: true}
	}
	if st.AppAccountToken != "" {
		if tok, perr := uuid.Parse(st.AppAccountToken); perr == nil {
			txParams.AppAccountToken = pgtype.UUID{Bytes: tok, Valid: true}
		}
	}
	if st.OfferType != "" {
		txParams.OfferType = &st.OfferType
	}
	if st.OfferIdentifier != "" {
		txParams.OfferIdentifier = &st.OfferIdentifier
	}
	if st.RevocationDate != nil {
		txParams.RevocationDate = pgtype.Timestamptz{Time: *st.RevocationDate, Valid: true}
		if st.RevocationReason != "" {
			txParams.RevocationReason = &st.RevocationReason
		}
	}
	if _, err := q.UpsertStoreTransaction(ctx, txParams); err != nil {
		return nil, status.Errorf(codes.Internal, "store transaction: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	used, reserved, limit, ok := s.counterForCaller(ctx, row.ID, "")
	if !ok {
		limit = plan.TokensPerPeriod
	}
	var canceledAt *time.Time
	if row.CanceledAt.Valid {
		canceledAt = &row.CanceledAt.Time
	}
	return buildSubscriptionProto(subFields{
		ID:                 row.ID,
		PlanTier:           string(plan.Tier),
		PlanCycle:          string(plan.Cycle),
		Status:             subStatus,
		CurrentPeriodStart: row.CurrentPeriodStart,
		CurrentPeriodEnd:   row.CurrentPeriodEnd,
		CancelAtPeriodEnd:  row.CancelAtPeriodEnd,
		CanceledAt:         canceledAt,
		Provider:           st.Provider,
		GraceUntil:         st.GraceUntil,
	}, used, reserved, limit), nil
}

// ApplyStoreStateForSubscription obsługuje notyfikacje i cron
// uzgadniania: organizację bierzemy z istniejącej subskrypcji, bo
// zdarzenie ze sklepu nie zawsze niesie appAccountToken.
func (s *Server) ApplyStoreStateForSubscription(ctx context.Context, st StoreState) error {
	existing, err := s.queries.GetSubscriptionByProviderID(ctx, db.GetSubscriptionByProviderIDParams{
		Provider:               db.PaymentProvider(st.Provider),
		ProviderSubscriptionID: st.OriginalTransactionID,
	})
	var orgID uuid.UUID
	switch {
	case err == nil:
		orgID = existing.OrganizationID
	case errors.Is(err, pgx.ErrNoRows):
		// Pierwsze zdarzenie o zakupie, którego aplikacja nie zdążyła
		// zgłosić (np. zakup dokończony poza aplikacją). Ratuje nas
		// appAccountToken.
		if st.AppAccountToken == "" {
			return errors.New("nieznana subskrypcja i brak appAccountToken")
		}
		parsed, perr := uuid.Parse(st.AppAccountToken)
		if perr != nil {
			return errors.New("appAccountToken nie jest UUID organizacji")
		}
		orgID = parsed
	default:
		return err
	}
	_, err = s.applyStoreState(ctx, orgID, nil, st)
	return err
}

// ─── AdminListStoreTransactions ───────────────────────────────────────

func (s *Server) AdminListStoreTransactions(ctx context.Context, req *billingv1.AdminListStoreTransactionsRequest) (*billingv1.AdminListStoreTransactionsResponse, error) {
	caller, err := resolveAdminCaller(ctx)
	if err != nil {
		return nil, err
	}
	if err := caller.requireSuperwizorAdmin(); err != nil {
		return nil, err
	}
	orgID, err := parseUUID("organization_id", req.GetOrganizationId())
	if err != nil {
		return nil, err
	}
	limit := req.GetLimit()
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	rows, err := s.queries.ListStoreTransactionsByOrg(ctx, db.ListStoreTransactionsByOrgParams{
		OrganizationID: pgtype.UUID{Bytes: orgID, Valid: true},
		Limit:          limit,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list store transactions: %v", err)
	}
	out := make([]*billingv1.StoreTransactionInfo, 0, len(rows))
	for _, r := range rows {
		item := &billingv1.StoreTransactionInfo{
			Provider:              string(r.Provider),
			TransactionId:         r.TransactionID,
			OriginalTransactionId: r.OriginalTransactionID,
			ProductId:             r.ProductID,
			Environment:           r.Environment,
			PurchaseDate:          timestamppb.New(r.PurchaseDate),
			OfferIdentifier:       r.OfferIdentifier,
		}
		if r.ExpiresDate.Valid {
			item.ExpiresDate = timestamppb.New(r.ExpiresDate.Time)
		}
		if r.RevocationDate.Valid {
			item.RevocationDate = timestamppb.New(r.RevocationDate.Time)
		}
		out = append(out, item)
	}
	return &billingv1.AdminListStoreTransactionsResponse{Transactions: out}, nil
}

// ─── helpers ──────────────────────────────────────────────────────────

func (s *Server) verifierFor(provider string) (StoreVerifier, error) {
	if provider == "" {
		return nil, status.Error(codes.InvalidArgument, "platform must be IOS or ANDROID")
	}
	v, ok := s.stores[provider]
	if !ok || v == nil {
		return nil, status.Errorf(codes.FailedPrecondition,
			"STORE_NOT_CONFIGURED: weryfikacja zakupów %s nie jest skonfigurowana", provider)
	}
	return v, nil
}

// appConfig czyta globalną flagę z app_config. Brak wiersza albo błąd
// odczytu = wartość domyślna: flagi IAP startują wyłączone, więc awaria
// bazy nie może przypadkiem WŁĄCZYĆ sprzedaży.
func (s *Server) appConfig(ctx context.Context, key, fallback string) string {
	v, err := s.queries.GetGlobalAppConfig(ctx, key)
	if err != nil || strings.TrimSpace(v) == "" {
		return fallback
	}
	return strings.TrimSpace(v)
}

// platformFromMetadata czyta x-client-platform — ten sam nagłówek, który
// aplikacja wysyła już przy uploadach. Klucz jest na statycznej
// allowliście CORS w pkg/cors (incydent 2026-07-24: każdy własny klucz
// metadanych gRPC to osobny nagłówek CORS).
func platformFromMetadata(ctx context.Context) string {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return ""
	}
	if v := md.Get("x-client-platform"); len(v) > 0 {
		return strings.ToUpper(strings.TrimSpace(v[0]))
	}
	return ""
}

func storeProviderForPlatform(platform string) string {
	switch strings.ToUpper(strings.TrimSpace(platform)) {
	case "IOS", "IPADOS", "APPLE", providerApple:
		return providerApple
	case "ANDROID", "GOOGLE", providerGoogle:
		return providerGoogle
	default:
		return ""
	}
}

func channelForProvider(provider string) string {
	switch provider {
	case providerApple:
		return "APPLE"
	case providerGoogle:
		return "GOOGLE"
	default:
		return "WEB"
	}
}

func storeProductID(provider string, apple, google *string) string {
	if provider == providerApple && apple != nil {
		return *apple
	}
	if provider == providerGoogle && google != nil {
		return *google
	}
	return ""
}

// manageURL — gdzie użytkownik zarządza subskrypcją. Dla sklepów to
// dozwolony deep link (zarządzanie własnym IAP), dla Stripe'a portal
// otwierany z przeglądarki, dla MANUAL nic.
func manageURL(provider string, storeProductID *string) string {
	switch provider {
	case providerApple:
		return "https://apps.apple.com/account/subscriptions"
	case providerGoogle:
		u := "https://play.google.com/store/account/subscriptions?package=ai.superwizor.superwizor"
		if storeProductID != nil && *storeProductID != "" {
			u += "&sku=" + strings.SplitN(*storeProductID, ":", 2)[0]
		}
		return u
	case "STRIPE":
		return "https://superwizor.ai/account"
	default:
		return ""
	}
}

// mapStoreStatus tłumaczy stan sklepu na nasz subscription_status.
// Zwraca też cancel_at_period_end — dla sklepów to po prostu wyłączone
// automatyczne odnawianie.
func mapStoreStatus(st StoreState) (string, bool) {
	switch st.Status {
	case StoreStatusActive, StoreStatusGrace:
		return "ACTIVE", !st.AutoRenew
	case StoreStatusRetry:
		return "PAST_DUE", !st.AutoRenew
	case StoreStatusPaused:
		return "PAUSED", !st.AutoRenew
	case StoreStatusRevoked, StoreStatusExpired:
		return "CANCELED", true
	default:
		// Nieznany stan traktujemy jak niepełny zakup, nie jak aktywny —
		// ta sama zasada co mapStripeSubStatus dla nieznanych statusów.
		return "INCOMPLETE", false
	}
}
