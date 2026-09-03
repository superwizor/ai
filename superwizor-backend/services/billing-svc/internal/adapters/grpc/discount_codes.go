package grpc

import (
	"context"
	"errors"
	"fmt"
	"math"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/stripepromo"
)

// Kody rabatowe — docs/70 §6.
//
// Podział odpowiedzialności (świadomy, opisany w §6.4): nasza tabela
// trzyma definicję kodu i historię użyć, Stripe egzekwuje limit na
// webie. Nigdy nie rozstrzygamy wyścigu o ostatnie użycie sami —
// `redemptions_count` jest lustrem, a nie zamkiem.

var discountCodeRE = regexp.MustCompile(`^[A-Z0-9_]{3,32}$`)

// Kody odmowy zwracane w DiscountCodeQuote.reason. Interfejs mapuje je
// na komunikaty, więc są częścią kontraktu — nie zmieniaj bez zmiany
// tłumaczeń w marketing-site.
const (
	quoteOK                = "OK"
	quoteNotFound          = "NOT_FOUND"
	quoteInactive          = "INACTIVE"
	quoteExpired           = "EXPIRED"
	quoteNotStarted        = "NOT_STARTED"
	quoteExhausted         = "EXHAUSTED"
	quoteAlreadyUsed       = "ALREADY_USED"
	quotePlanNotEligible   = "PLAN_NOT_ELIGIBLE"
	quoteChannelNotElig    = "CHANNEL_NOT_ELIGIBLE"
	quoteNewCustomersOnly  = "NEW_CUSTOMERS_ONLY"
	discountReservationTTL = 24 * time.Hour
)

// ─── AdminCreateDiscountCode ──────────────────────────────────────────

func (s *Server) AdminCreateDiscountCode(ctx context.Context, req *billingv1.AdminCreateDiscountCodeRequest) (*billingv1.DiscountCode, error) {
	caller, err := resolveAdminCaller(ctx)
	if err != nil {
		return nil, err
	}
	if err := caller.requireSuperwizorAdmin(); err != nil {
		return nil, err
	}
	if len(req.GetReason()) < minAuditReasonChars {
		return nil, status.Errorf(codes.InvalidArgument,
			"reason must be >= %d characters", minAuditReasonChars)
	}

	code := strings.ToUpper(strings.TrimSpace(req.GetCode()))
	if !discountCodeRE.MatchString(code) {
		return nil, status.Error(codes.InvalidArgument,
			"DISCOUNT_CODE_FORMAT: kod może zawierać tylko A-Z, 0-9 i _, długość 3-32 znaki")
	}
	if strings.TrimSpace(req.GetName()) == "" {
		return nil, status.Error(codes.InvalidArgument, "name required")
	}
	percent, err := parsePercent(req.GetPercentOff())
	if err != nil {
		return nil, err
	}
	duration := strings.ToUpper(strings.TrimSpace(req.GetDuration()))
	if duration == "" {
		duration = "FOREVER"
	}
	switch duration {
	case "ONCE", "FOREVER":
	case "REPEATING":
		if req.GetDurationPeriods() <= 0 {
			return nil, status.Error(codes.InvalidArgument,
				"duration_periods must be > 0 for REPEATING")
		}
	default:
		return nil, status.Error(codes.InvalidArgument, "duration must be ONCE, REPEATING or FOREVER")
	}
	if req.GetValidUntil() == nil {
		return nil, status.Error(codes.InvalidArgument, "valid_until required")
	}
	validUntil := req.GetValidUntil().AsTime()
	if !validUntil.After(time.Now()) {
		return nil, status.Error(codes.InvalidArgument,
			"DISCOUNT_CODE_EXPIRED_ON_CREATE: termin ważności musi być w przyszłości")
	}
	if req.GetMaxRedemptions() <= 0 {
		return nil, status.Error(codes.InvalidArgument, "max_redemptions must be > 0")
	}

	channels := normalizeChannels(req.GetChannels())
	tiers, err := normalizeUpper(req.GetAppliesToTiers(), map[string]bool{
		"SOLO": true, "PRO": true, "CLINIC": true, "TRIAL": true, "BETA": true,
	}, "applies_to_tiers")
	if err != nil {
		return nil, err
	}
	cycles, err := normalizeUpper(req.GetAppliesToCycles(), map[string]bool{
		"MONTHLY": true, "ANNUAL": true, "SEMI_ANNUAL": true,
	}, "applies_to_cycles")
	if err != nil {
		return nil, err
	}

	// Kolizję kodu wychwytujemy PRZED wyjściem do Stripe'a — inaczej
	// zostawialibyśmy tam kupon i kod bez odpowiednika u nas, przy każdej
	// pomyłce operatora.
	if _, err := s.queries.GetDiscountCodeByCode(ctx, code); err == nil {
		return nil, status.Errorf(codes.AlreadyExists,
			"DISCOUNT_CODE_EXISTS: kod %s już istnieje", code)
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return nil, status.Errorf(codes.Internal, "code lookup: %v", err)
	}

	// Stripe idzie PIERWSZY, bo to on egzekwuje limit. Wiersz u nas bez
	// odpowiednika w Stripie oznaczałby kod, który panel pokazuje jako
	// działający, a Checkout po cichu ignoruje.
	var promo stripepromo.Promo
	wantsWeb := containsString(channels, "WEB")
	if wantsWeb {
		if s.promo == nil {
			return nil, status.Error(codes.FailedPrecondition,
				"STRIPE_NOT_CONFIGURED: kod na kanał WEB wymaga skonfigurowanego STRIPE_SECRET_KEY")
		}
		promo, err = s.promo.Create(ctx, stripepromo.Spec{
			Code:            code,
			Name:            req.GetName(),
			PercentOff:      percent,
			Duration:        duration,
			DurationPeriods: req.GetDurationPeriods(),
			ValidUntil:      validUntil,
			MaxRedemptions:  req.GetMaxRedemptions(),
			NewCustomers:    req.GetNewCustomersOnly(),
		})
		if err != nil {
			return nil, status.Errorf(codes.Internal, "stripe sync: %v", err)
		}
	}

	var pct pgtype.Numeric
	if err := pct.Scan(req.GetPercentOff()); err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "percent_off: %v", err)
	}

	params := db.CreateDiscountCodeParams{
		Code:             code,
		Name:             strings.TrimSpace(req.GetName()),
		PercentOff:       pct,
		Duration:         duration,
		ValidUntil:       validUntil,
		MaxRedemptions:   req.GetMaxRedemptions(),
		NewCustomersOnly: req.GetNewCustomersOnly(),
		Channels:         channels,
		Reason:           req.GetReason(),
		AppliesToTiers:   tiers,
		AppliesToCycles:  cycles,
	}
	if duration == "REPEATING" {
		v := req.GetDurationPeriods()
		params.DurationPeriods = &v
	}
	if caller.userID != nil {
		params.CreatedBy = pgtype.UUID{Bytes: *caller.userID, Valid: true}
	}

	row, err := s.queries.CreateDiscountCode(ctx, params)
	if err != nil {
		// Wycofujemy kod w Stripie, żeby nie został aktywny rabat bez
		// definicji po naszej stronie.
		if promo.PromotionCodeID != "" && s.promo != nil {
			_ = s.promo.SetActive(ctx, promo.PromotionCodeID, false)
		}
		return nil, status.Errorf(codes.Internal, "create discount code: %v", err)
	}

	if promo.PromotionCodeID != "" {
		if err := s.queries.SetDiscountCodeStripeIDs(ctx, db.SetDiscountCodeStripeIDsParams{
			ID:                    row.ID,
			StripeCouponID:        &promo.CouponID,
			StripePromotionCodeID: &promo.PromotionCodeID,
		}); err != nil {
			return nil, status.Errorf(codes.Internal, "store stripe ids: %v", err)
		}
		row.StripeCouponID = &promo.CouponID
		row.StripePromotionCodeID = &promo.PromotionCodeID
	}

	s.auditDiscountCode(ctx, caller, row.ID, "billing.discount_code_created", req.GetReason(), map[string]any{
		"code":            code,
		"percent_off":     req.GetPercentOff(),
		"valid_until":     validUntil.Format(time.RFC3339),
		"max_redemptions": req.GetMaxRedemptions(),
		"channels":        channels,
		"idempotency_key": req.GetIdempotencyKey(),
	})

	return discountCodeProto(row), nil
}

// ─── AdminUpdateDiscountCode ──────────────────────────────────────────

func (s *Server) AdminUpdateDiscountCode(ctx context.Context, req *billingv1.AdminUpdateDiscountCodeRequest) (*billingv1.DiscountCode, error) {
	caller, err := resolveAdminCaller(ctx)
	if err != nil {
		return nil, err
	}
	if err := caller.requireSuperwizorAdmin(); err != nil {
		return nil, err
	}
	if len(req.GetReason()) < minAuditReasonChars {
		return nil, status.Errorf(codes.InvalidArgument,
			"reason must be >= %d characters", minAuditReasonChars)
	}
	id, err := parseUUID("id", req.GetId())
	if err != nil {
		return nil, err
	}
	existing, err := s.queries.GetDiscountCodeByID(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "discount code not found")
		}
		return nil, status.Errorf(codes.Internal, "load discount code: %v", err)
	}

	params := db.UpdateDiscountCodeParams{ID: id}
	if n := strings.TrimSpace(req.GetName()); n != "" {
		params.Name = &n
	}
	newValidUntil := existing.ValidUntil
	if req.GetValidUntil() != nil {
		newValidUntil = req.GetValidUntil().AsTime()
		params.ValidUntil = pgtype.Timestamptz{Time: newValidUntil, Valid: true}
	}
	newMax := existing.MaxRedemptions
	if req.GetMaxRedemptions() > 0 {
		newMax = req.GetMaxRedemptions()
		params.MaxRedemptions = &newMax
	}
	switch req.GetSetActive() {
	case 0:
		f := false
		params.IsActive = &f
	case 1:
		t := true
		params.IsActive = &t
	case -1:
		// bez zmian
	default:
		return nil, status.Error(codes.InvalidArgument, "set_active must be -1, 0 or 1")
	}

	// Stripe nie pozwala przesunąć terminu ani limitu na istniejącym
	// promotion code'zie — trzeba założyć nowy pod tym samym kuponem i
	// wygasić stary (docs/70 D10). Robimy to PRZED zapisem u siebie, żeby
	// nie obiecać operatorowi zmiany, której Checkout nie widzi.
	needsRecreate := (req.GetValidUntil() != nil || req.GetMaxRedemptions() > 0) &&
		existing.StripePromotionCodeID != nil && existing.StripeCouponID != nil
	var recreatedID string
	if needsRecreate {
		if s.promo == nil {
			return nil, status.Error(codes.FailedPrecondition,
				"STRIPE_NOT_CONFIGURED: zmiana terminu lub limitu wymaga połączenia ze Stripe")
		}
		recreatedID, err = s.promo.Recreate(ctx, *existing.StripeCouponID, existing.Code, newValidUntil, newMax)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "stripe recreate: %v", err)
		}
		if err := s.promo.SetActive(ctx, *existing.StripePromotionCodeID, false); err != nil {
			// Nowy kod już działa; stary został aktywny. To jest stan do
			// posprzątania ręcznie, ale nie unieważnia zmiany.
			s.logWarn(ctx, "stripe: nie udało się wygasić starego promotion code", "id", *existing.StripePromotionCodeID, "error", err)
		}
	} else if req.GetSetActive() != -1 && existing.StripePromotionCodeID != nil && s.promo != nil {
		if err := s.promo.SetActive(ctx, *existing.StripePromotionCodeID, req.GetSetActive() == 1); err != nil {
			return nil, status.Errorf(codes.Internal, "stripe set active: %v", err)
		}
	}

	row, err := s.queries.UpdateDiscountCode(ctx, params)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update discount code: %v", err)
	}
	if recreatedID != "" {
		if err := s.queries.SetDiscountCodeStripeIDs(ctx, db.SetDiscountCodeStripeIDsParams{
			ID:                    row.ID,
			StripeCouponID:        existing.StripeCouponID,
			StripePromotionCodeID: &recreatedID,
		}); err != nil {
			return nil, status.Errorf(codes.Internal, "store stripe ids: %v", err)
		}
		row.StripePromotionCodeID = &recreatedID
	}

	s.auditDiscountCode(ctx, caller, row.ID, "billing.discount_code_updated", req.GetReason(), map[string]any{
		"code":               existing.Code,
		"set_active":         req.GetSetActive(),
		"valid_until_before": existing.ValidUntil.Format(time.RFC3339),
		"valid_until_after":  row.ValidUntil.Format(time.RFC3339),
		"max_before":         existing.MaxRedemptions,
		"max_after":          row.MaxRedemptions,
		"stripe_recreated":   recreatedID != "",
		"idempotency_key":    req.GetIdempotencyKey(),
	})

	return discountCodeProto(row), nil
}

// ─── AdminListDiscountCodes / AdminGetDiscountCode ────────────────────

func (s *Server) AdminListDiscountCodes(ctx context.Context, req *billingv1.AdminListDiscountCodesRequest) (*billingv1.AdminListDiscountCodesResponse, error) {
	caller, err := resolveAdminCaller(ctx)
	if err != nil {
		return nil, err
	}
	if err := caller.requireSuperwizorAdmin(); err != nil {
		return nil, err
	}
	rows, err := s.queries.ListDiscountCodes(ctx, req.GetIncludeInactive())
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list discount codes: %v", err)
	}
	out := make([]*billingv1.DiscountCode, 0, len(rows))
	for _, r := range rows {
		out = append(out, discountCodeProto(r))
	}
	return &billingv1.AdminListDiscountCodesResponse{Codes: out}, nil
}

func (s *Server) AdminGetDiscountCode(ctx context.Context, req *billingv1.AdminGetDiscountCodeRequest) (*billingv1.DiscountCodeDetails, error) {
	caller, err := resolveAdminCaller(ctx)
	if err != nil {
		return nil, err
	}
	if err := caller.requireSuperwizorAdmin(); err != nil {
		return nil, err
	}
	id, err := parseUUID("id", req.GetId())
	if err != nil {
		return nil, err
	}
	row, err := s.queries.GetDiscountCodeByID(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "discount code not found")
		}
		return nil, status.Errorf(codes.Internal, "load discount code: %v", err)
	}
	redemptions, err := s.queries.ListRedemptionsByCode(ctx, id)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list redemptions: %v", err)
	}
	out := make([]*billingv1.DiscountCodeRedemption, 0, len(redemptions))
	for _, r := range redemptions {
		item := &billingv1.DiscountCodeRedemption{
			OrganizationId:   r.OrganizationID.String(),
			OrganizationName: r.OrganizationName,
			Channel:          r.Channel,
			Status:           r.Status,
			ReservedAt:       timestamppb.New(r.ReservedAt),
		}
		if r.CommittedAt.Valid {
			item.CommittedAt = timestamppb.New(r.CommittedAt.Time)
		}
		out = append(out, item)
	}
	return &billingv1.DiscountCodeDetails{Code: discountCodeProto(row), Redemptions: out}, nil
}

// ─── ValidateDiscountCode ─────────────────────────────────────────────

// ValidateDiscountCode sprawdza kod przed checkoutem i wycenia rabat.
// NIE rezerwuje użycia — rezerwacja powstaje dopiero przy tworzeniu sesji
// Checkout (ReserveDiscountRedemption), bo dopiero wtedy wiadomo, że
// użytkownik naprawdę idzie płacić.
func (s *Server) ValidateDiscountCode(ctx context.Context, req *billingv1.ValidateDiscountCodeRequest) (*billingv1.DiscountCodeQuote, error) {
	caller := resolveRequestCaller(ctx)
	if caller.organizationID == nil {
		return nil, status.Error(codes.Unauthenticated, "caller organization unknown")
	}
	code := strings.ToUpper(strings.TrimSpace(req.GetCode()))
	if code == "" {
		return nil, status.Error(codes.InvalidArgument, "code required")
	}
	channel := strings.ToUpper(strings.TrimSpace(req.GetChannel()))
	if channel == "" {
		channel = "WEB"
	}

	tier := strings.ToUpper(strings.TrimSpace(req.GetPlanTier()))
	cycle := strings.ToUpper(strings.TrimSpace(req.GetPlanCycle()))
	if tier == "" || cycle == "" {
		return nil, status.Error(codes.InvalidArgument, "plan_tier and plan_cycle required")
	}
	plan, err := s.queries.AdminGetPlanByTierCycle(ctx, db.AdminGetPlanByTierCycleParams{
		Tier:  db.PlanTier(tier),
		Cycle: db.BillingCycle(cycle),
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Errorf(codes.InvalidArgument, "no active plan for (%s, %s)", tier, cycle)
		}
		return nil, status.Errorf(codes.Internal, "lookup plan: %v", err)
	}
	priceBefore := numericToFloat(plan.PriceGross)

	row, err := s.queries.GetDiscountCodeByCode(ctx, code)
	if errors.Is(err, pgx.ErrNoRows) {
		// Kody założone ręcznie w dashboardzie Stripe'a, zanim powstał
		// panel (ROWNOWAGA, ROZKWIT, PIONIER33), nie mają u nas wiersza.
		// Odesłanie "nieprawidłowy kod" byłoby nieprawdą — Checkout je
		// przyjmuje. Pytamy więc Stripe'a i wyceniamy z jego kuponu.
		return s.quoteFromStripe(ctx, code, plan.CurrencyCode, priceBefore), nil
	}
	if err != nil {
		return nil, status.Errorf(codes.Internal, "lookup code: %v", err)
	}

	quote := &billingv1.DiscountCodeQuote{
		Code:            row.Code,
		Name:            row.Name,
		PercentOff:      numericToString(row.PercentOff),
		PriceBefore:     formatMoney(priceBefore),
		CurrencyCode:    plan.CurrencyCode,
		Duration:        row.Duration,
		DurationPeriods: derefInt32(row.DurationPeriods),
	}

	now := time.Now()
	switch {
	case !row.IsActive:
		quote.Reason = quoteInactive
	case now.Before(row.ValidFrom):
		quote.Reason = quoteNotStarted
	case now.After(row.ValidUntil):
		quote.Reason = quoteExpired
	case !channelAllowed(row.Channels, channel):
		quote.Reason = quoteChannelNotElig
	case !planAllowed(row.AppliesToTiers, tier) || !planAllowed(row.AppliesToCycles, cycle):
		quote.Reason = quotePlanNotEligible
	}
	if quote.Reason != "" {
		return quote, nil
	}

	// Użycie przez tę samą organizację drugi raz — UNIQUE(code, org) i tak
	// by je odrzucił przy rezerwacji, ale wolimy powiedzieć to od razu.
	if red, rerr := s.queries.GetRedemptionForOrg(ctx, db.GetRedemptionForOrgParams{
		CodeID:         row.ID,
		OrganizationID: *caller.organizationID,
	}); rerr == nil && red.Status != "RELEASED" {
		quote.Reason = quoteAlreadyUsed
		return quote, nil
	} else if rerr != nil && !errors.Is(rerr, pgx.ErrNoRows) {
		return nil, status.Errorf(codes.Internal, "redemption lookup: %v", rerr)
	}

	if row.NewCustomersOnly {
		hasHistory, herr := s.queries.OrgHasPaidSubscriptionHistory(ctx, *caller.organizationID)
		if herr != nil {
			return nil, status.Errorf(codes.Internal, "history lookup: %v", herr)
		}
		if hasHistory {
			quote.Reason = quoteNewCustomersOnly
			return quote, nil
		}
	}

	used, err := s.queries.CountCommittedRedemptions(ctx, row.ID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "count redemptions: %v", err)
	}
	left := row.MaxRedemptions - int32(used)
	if left <= 0 {
		quote.Reason = quoteExhausted
		return quote, nil
	}

	percent := numericToFloat(row.PercentOff)
	quote.Valid = true
	quote.Reason = quoteOK
	quote.PriceAfter = formatMoney(roundMoney(priceBefore * (1 - percent/100)))
	quote.RedemptionsLeft = left
	return quote, nil
}

// quoteFromStripe wycenia kod, którego nie ma w naszym katalogu. Zwraca
// wycenę tylko wtedy, gdy Stripe potwierdzi, że kod istnieje i jest
// aktywny — inaczej NOT_FOUND.
func (s *Server) quoteFromStripe(ctx context.Context, code, currency string, priceBefore float64) *billingv1.DiscountCodeQuote {
	quote := &billingv1.DiscountCodeQuote{
		Code:         code,
		Reason:       quoteNotFound,
		PriceBefore:  formatMoney(priceBefore),
		CurrencyCode: currency,
	}
	if s.promo == nil {
		return quote
	}
	lk, err := s.promo.Lookup(ctx, code)
	if err != nil || !lk.Found {
		return quote
	}
	if !lk.Active {
		quote.Reason = quoteInactive
		return quote
	}
	var after float64
	switch {
	case lk.PercentOff > 0:
		after = priceBefore * (1 - lk.PercentOff/100)
		quote.PercentOff = formatMoney(lk.PercentOff)
	case lk.AmountOff > 0:
		after = priceBefore - float64(lk.AmountOff)/100
	default:
		return quote
	}
	if after < 0 {
		after = 0
	}
	quote.Valid = true
	quote.Reason = quoteOK
	quote.PriceAfter = formatMoney(roundMoney(after))
	return quote
}

// ─── helpers ──────────────────────────────────────────────────────────

func discountCodeProto(r db.DiscountCode) *billingv1.DiscountCode {
	out := &billingv1.DiscountCode{
		Id:               r.ID.String(),
		Code:             r.Code,
		Name:             r.Name,
		PercentOff:       numericToString(r.PercentOff),
		Duration:         r.Duration,
		DurationPeriods:  derefInt32(r.DurationPeriods),
		ValidFrom:        timestamppb.New(r.ValidFrom),
		ValidUntil:       timestamppb.New(r.ValidUntil),
		MaxRedemptions:   r.MaxRedemptions,
		RedemptionsCount: r.RedemptionsCount,
		AppliesToTiers:   r.AppliesToTiers,
		AppliesToCycles:  r.AppliesToCycles,
		NewCustomersOnly: r.NewCustomersOnly,
		Channels:         r.Channels,
		IsActive:         r.IsActive,
		CreatedAt:        timestamppb.New(r.CreatedAt),
	}
	if r.StripePromotionCodeID != nil {
		out.StripePromotionCodeId = *r.StripePromotionCodeID
	}
	return out
}

func parsePercent(raw string) (float64, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, status.Error(codes.InvalidArgument, "percent_off required")
	}
	var v float64
	if _, err := fmt.Sscanf(raw, "%f", &v); err != nil {
		return 0, status.Errorf(codes.InvalidArgument, "percent_off invalid: %v", err)
	}
	if v <= 0 || v > 100 {
		return 0, status.Error(codes.InvalidArgument, "percent_off must be in (0, 100]")
	}
	return v, nil
}

func normalizeChannels(in []string) []string {
	allowed := map[string]bool{"WEB": true, "APPLE": true, "GOOGLE": true}
	out := make([]string, 0, len(in))
	for _, c := range in {
		c = strings.ToUpper(strings.TrimSpace(c))
		if allowed[c] && !containsString(out, c) {
			out = append(out, c)
		}
	}
	if len(out) == 0 {
		out = []string{"WEB"}
	}
	return out
}

func normalizeUpper(in []string, allowed map[string]bool, field string) ([]string, error) {
	if len(in) == 0 {
		return nil, nil
	}
	out := make([]string, 0, len(in))
	for _, v := range in {
		v = strings.ToUpper(strings.TrimSpace(v))
		if !allowed[v] {
			return nil, status.Errorf(codes.InvalidArgument, "%s: unknown value %q", field, v)
		}
		if !containsString(out, v) {
			out = append(out, v)
		}
	}
	return out, nil
}

func containsString(hay []string, needle string) bool {
	for _, v := range hay {
		if v == needle {
			return true
		}
	}
	return false
}

// channelAllowed / planAllowed — pusta lista znaczy "bez ograniczeń".
func channelAllowed(channels []string, want string) bool {
	if len(channels) == 0 {
		return true
	}
	return containsString(channels, want)
}

func planAllowed(list []string, want string) bool {
	if len(list) == 0 {
		return true
	}
	return containsString(list, want)
}

func derefInt32(v *int32) int32 {
	if v == nil {
		return 0
	}
	return *v
}

func numericToFloat(n pgtype.Numeric) float64 {
	f, err := n.Float64Value()
	if err != nil || !f.Valid {
		return 0
	}
	return f.Float64
}

func numericToString(n pgtype.Numeric) string {
	return formatMoney(numericToFloat(n))
}

func formatMoney(v float64) string {
	return fmt.Sprintf("%.2f", v)
}

func roundMoney(v float64) float64 {
	return math.Round(v*100) / 100
}

// ReserveDiscountRedemption jest wołane z handlera Checkoutu tuż przed
// utworzeniem sesji Stripe. Zwraca promotion code ID do podpięcia oraz
// identyfikator kodu, żeby webhook mógł domknąć rezerwację.
func (s *Server) ReserveDiscountRedemption(
	ctx context.Context, code string, orgID uuid.UUID, userID *uuid.UUID, channel, reference string,
) (codeID uuid.UUID, promotionCodeID string, err error) {
	row, err := s.queries.GetDiscountCodeByCode(ctx, strings.ToUpper(strings.TrimSpace(code)))
	if err != nil {
		return uuid.Nil, "", err
	}
	params := db.ReserveRedemptionParams{
		CodeID:         row.ID,
		OrganizationID: orgID,
		Channel:        channel,
	}
	if userID != nil {
		params.UserID = pgtype.UUID{Bytes: *userID, Valid: true}
	}
	if reference != "" {
		params.ProviderReference = &reference
	}
	if _, err := s.queries.ReserveRedemption(ctx, params); err != nil {
		return uuid.Nil, "", err
	}
	if row.StripePromotionCodeID != nil {
		promotionCodeID = *row.StripePromotionCodeID
	}
	return row.ID, promotionCodeID, nil
}
