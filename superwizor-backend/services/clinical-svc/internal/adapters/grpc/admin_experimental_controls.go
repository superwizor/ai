package grpc

import (
	"context"
	"encoding/json"
	"sort"
	"strconv"
	"time"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/pkg/appconfig"
)

// Kontrola trybu eksperymentalnego (plan 16 §2.5).
//
// Ten sam wzorzec co kontrola czatu — i celowo ta sama maszyneria:
// `upsertConfig`, wymagana notatka, wpis audytowy, Refresh dla tej
// instancji i 30 s TTL dla pozostalych. Drugi mechanizm konfiguracji
// obok istniejacego bylby drugim miejscem, w ktorym cos moze sie
// rozjechac.
//
// OSOBNE RPC, nie pola w AdminSetChatControls: to sa dwa przelaczniki o
// roznym ryzyku i roznym cyklu zycia. Czat wylacza sie w kryzysie, tryb
// eksperymentalny wlacza na czas kalibracji ontologii. Zlanie ich w
// jedno wywolanie oznaczaloby, ze pomylka w jednym polu rusza drugi
// mechanizm.

func (s *Server) AdminGetExperimentalControls(ctx context.Context,
	req *clinicalv1.AdminGetExperimentalControlsRequest) (
	*clinicalv1.AdminExperimentalControls, error) {

	if err := requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}
	if s.config == nil {
		return nil, status.Error(codes.Unavailable, "app config not wired")
	}
	org, err := optionalUUID(req.GetOrganizationId())
	if err != nil {
		return nil, err
	}
	return s.readExperimentalControls(ctx, org), nil
}

func (s *Server) AdminSetExperimentalControls(ctx context.Context,
	req *clinicalv1.AdminSetExperimentalControlsRequest) (
	*clinicalv1.AdminExperimentalControls, error) {

	if err := requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}
	if s.config == nil || s.pool == nil {
		return nil, status.Error(codes.Unavailable, "app config not wired")
	}
	if req.GetNote() == "" {
		return nil, status.Error(codes.InvalidArgument,
			"notatka jest wymagana — napisz, po co ta zmiana")
	}
	org, err := optionalUUID(req.GetOrganizationId())
	if err != nil {
		return nil, err
	}
	actorID, _ := ctx.Value(UserIDKey).(string)
	actorUUID, _ := uuid.Parse(actorID)

	before := s.readExperimentalControls(ctx, org)

	updates := map[string]string{}
	if req.Enabled != nil {
		updates[appconfig.KeyReportExperimentalEnabled] = strconv.FormatBool(req.GetEnabled())
	}
	if req.DailyLimit != nil {
		limit := req.GetDailyLimit()
		if limit < 0 {
			return nil, status.Error(codes.InvalidArgument, "daily_limit musi byc >= 0")
		}
		// Gorna granica nie jest kaprysem: jeden raport eksperymentalny
		// to kilkanascie wywolan Pro, a dual-run mnozy to przez liczbe
		// sesji. Literowka w polu limitu nie moze byc rachunkiem.
		if limit > 50 {
			return nil, status.Error(codes.InvalidArgument,
				"daily_limit > 50 — potok wieloetapowy na Pro jest drogi; "+
					"jesli naprawde tyle trzeba, zmien to swiadomie w bazie")
		}
		updates[appconfig.KeyReportExperimentalDailyLimit] = strconv.FormatInt(limit, 10)
	}
	if len(updates) == 0 {
		return nil, status.Error(codes.InvalidArgument, "brak pol do zmiany")
	}

	for key, value := range updates {
		if err := s.upsertConfig(ctx, key, value, org, req.GetNote(), actorUUID); err != nil {
			return nil, status.Errorf(codes.Internal, "zapis %s: %v", key, err)
		}
	}
	if err := s.config.Refresh(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "odswiezenie konfiguracji: %v", err)
	}
	after := s.readExperimentalControls(ctx, org)

	s.recordExperimentalChange(ctx, actorUUID, org, before, after, req.GetNote(), updates)
	return after, nil
}

func (s *Server) readExperimentalControls(ctx context.Context, org uuid.UUID) *clinicalv1.AdminExperimentalControls {
	return &clinicalv1.AdminExperimentalControls{
		Enabled:       s.config.ExperimentalReportsEnabled(ctx, org),
		DailyLimit:    s.config.ExperimentalDailyLimit(ctx, org),
		IsOrgOverride: org != uuid.Nil,
		UpdatedAt:     timestamppb.New(time.Now()),
	}
}

// recordExperimentalChange zapisuje wpis audytowy.
//
// Wpis, nie tylko log: raport eksperymentalny powstaje na ontologii BEZ
// autoryzacji ekspertow, wiec pytanie "kto i kiedy to wlaczyl dla tej
// organizacji" jest pytaniem zgodnosciowym, nie operacyjnym. Blad zapisu
// jest GLOSNY, ale nie cofa zmiany — inaczej awaria audytu blokowalaby
// wylaczenie trybu, ktory wlasnie trzeba wylaczyc.
func (s *Server) recordExperimentalChange(ctx context.Context, actor, org uuid.UUID,
	before, after *clinicalv1.AdminExperimentalControls, note string, updates map[string]string) {

	changed := make([]string, 0, len(updates))
	for k := range updates {
		changed = append(changed, k)
	}
	sort.Strings(changed) // determinizm — wpis audytowy ma sie porownywac

	meta := map[string]any{
		"keys_changed":       changed,
		"before_enabled":     before.GetEnabled(),
		"after_enabled":      after.GetEnabled(),
		"before_daily_limit": before.GetDailyLimit(),
		"after_daily_limit":  after.GetDailyLimit(),
		"note":               note,
		"scope":              scopeLabel(org),
	}
	metaJSON, _ := json.Marshal(meta)

	if err := s.writeAuditEvent(ctx, actor, org,
		"report.experimental_controls_changed", "app_config", metaJSON); err != nil {
		auditLogFailure(ctx, err)
	}
}
