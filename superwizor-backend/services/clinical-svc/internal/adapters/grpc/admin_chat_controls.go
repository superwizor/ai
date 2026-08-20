// admin_chat_controls.go — the AI chat kill switch, operated from the
// admin panel (ADR 62 section 11, plan F5).
//
// docs/64 also documents a direct SQL path. That one is break-glass: it
// works when the panel is down, which is when it matters, but it writes
// no audit row. This RPC is the normal route precisely because it does.
// A switch flipped with no record of who flipped it and why is half a
// safety mechanism.

package grpc

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strconv"
	"time"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/pkg/analytics"
	"github.com/superwizor-ai/backend/pkg/appconfig"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/chat"
)

// AdminGetChatControls reports the effective chat configuration.
func (s *Server) AdminGetChatControls(ctx context.Context, req *clinicalv1.AdminGetChatControlsRequest) (*clinicalv1.AdminChatControls, error) {
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

	// Read through the same reader the request path uses. Querying the
	// table directly here would report what is stored while the running
	// service still serves a cached snapshot — the one discrepancy an
	// operator checking a kill switch must never be shown.
	if err := s.config.Refresh(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "refresh config: %v", err)
	}
	return s.readControls(ctx, org), nil
}

// AdminSetChatControls changes the configuration and records who did it.
func (s *Server) AdminSetChatControls(ctx context.Context, req *clinicalv1.AdminSetChatControlsRequest) (*clinicalv1.AdminChatControls, error) {
	if err := requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}
	if s.config == nil || s.pool == nil {
		return nil, status.Error(codes.Unavailable, "app config not wired")
	}
	if req.GetNote() == "" {
		// Required, not optional. The note is what the next responder
		// reads at 3am; an audit row saying only "someone disabled the
		// chat" answers none of the questions that will be asked.
		return nil, status.Error(codes.InvalidArgument, "note is required — explain why")
	}
	org, err := optionalUUID(req.GetOrganizationId())
	if err != nil {
		return nil, err
	}
	actorID, _ := ctx.Value(UserIDKey).(string)
	actorUUID, _ := uuid.Parse(actorID)

	before := s.readControls(ctx, org)

	updates := map[string]string{}
	if req.Enabled != nil {
		updates[appconfig.KeyAIChatEnabled] = strconv.FormatBool(req.GetEnabled())
	}
	if req.Mode != nil {
		mode := req.GetMode()
		if mode != appconfig.ModeFull && mode != appconfig.ModeDefinedOps {
			return nil, status.Errorf(codes.InvalidArgument,
				"mode must be %q or %q", appconfig.ModeFull, appconfig.ModeDefinedOps)
		}
		updates[appconfig.KeyAIChatMode] = mode
	}
	if req.ClassifierTau != nil {
		tau := req.GetClassifierTau()
		if tau <= 0 || tau > 1 {
			return nil, status.Error(codes.InvalidArgument, "classifier_tau must be in (0, 1]")
		}
		updates[appconfig.KeyAIChatClassifierTau] = strconv.FormatFloat(tau, 'f', -1, 64)
	}
	if req.QuotaMicroUsd != nil {
		if req.GetQuotaMicroUsd() < 0 {
			return nil, status.Error(codes.InvalidArgument, "quota_micro_usd must be >= 0")
		}
		updates[appconfig.KeyAIChatQuotaMicroUSD] = strconv.FormatInt(req.GetQuotaMicroUsd(), 10)
	}
	if len(updates) == 0 {
		return nil, status.Error(codes.InvalidArgument, "no fields to update")
	}

	for key, value := range updates {
		if err := s.upsertConfig(ctx, key, value, org, req.GetNote(), actorUUID); err != nil {
			return nil, status.Errorf(codes.Internal, "update %s: %v", key, err)
		}
	}

	// Make the change visible to this instance immediately. Other
	// instances pick it up within the reader's 30 s TTL — which is the
	// propagation bound the runbook measures.
	if err := s.config.Refresh(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "refresh config: %v", err)
	}
	after := s.readControls(ctx, org)

	s.recordKillSwitchChange(ctx, actorUUID, org, before, after, req.GetNote(), updates)
	return after, nil
}

const sqlUpsertConfigGlobal = `
INSERT INTO app_config (key, value, organization_id, note, updated_by)
VALUES ($1, $2, NULL, $3, $4)
ON CONFLICT (key) WHERE organization_id IS NULL
DO UPDATE SET value = EXCLUDED.value, note = EXCLUDED.note,
              updated_by = EXCLUDED.updated_by, updated_at = now()`

const sqlUpsertConfigOrg = `
INSERT INTO app_config (key, value, organization_id, note, updated_by)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (key, organization_id) WHERE organization_id IS NOT NULL
DO UPDATE SET value = EXCLUDED.value, note = EXCLUDED.note,
              updated_by = EXCLUDED.updated_by, updated_at = now()`

func (s *Server) upsertConfig(ctx context.Context, key, value string, org uuid.UUID, note string, actor uuid.UUID) error {
	var actorArg any
	if actor != uuid.Nil {
		actorArg = actor
	}
	if org == uuid.Nil {
		_, err := s.pool.Exec(ctx, sqlUpsertConfigGlobal, key, value, note, actorArg)
		return err
	}
	_, err := s.pool.Exec(ctx, sqlUpsertConfigOrg, key, value, org, note, actorArg)
	return err
}

func (s *Server) readControls(ctx context.Context, org uuid.UUID) *clinicalv1.AdminChatControls {
	return &clinicalv1.AdminChatControls{
		Enabled:       s.config.ChatEnabled(ctx, org),
		Mode:          s.config.ChatMode(ctx, org),
		ClassifierTau: s.config.Float64(ctx, appconfig.KeyAIChatClassifierTau, org),
		QuotaMicroUsd: s.config.Int64(ctx, appconfig.KeyAIChatQuotaMicroUSD, org),
		IsOrgOverride: org != uuid.Nil,
		UpdatedAt:     timestamppb.New(time.Now()),
	}
}

// recordKillSwitchChange writes the audit row and the telemetry event.
//
// Both, not either: audit_events is the durable record for a compliance
// reader, the telemetry event is what a dashboard can alert on. They
// answer different questions and neither substitutes for the other.
func (s *Server) recordKillSwitchChange(ctx context.Context, actor, org uuid.UUID, before, after *clinicalv1.AdminChatControls, note string, updates map[string]string) {
	changed := make([]string, 0, len(updates))
	for k := range updates {
		changed = append(changed, k)
	}
	meta := map[string]any{
		"keys_changed":   changed,
		"before_enabled": before.GetEnabled(),
		"after_enabled":  after.GetEnabled(),
		"before_mode":    before.GetMode(),
		"after_mode":     after.GetMode(),
		"note":           note,
		"scope":          scopeLabel(org),
	}
	metaJSON, _ := json.Marshal(meta)

	if err := s.writeAuditEvent(ctx, actor, org, "ai_chat.controls_changed", "app_config", metaJSON); err != nil {
		// Loud, but not fatal: the change is already applied and
		// reverting it because the audit write failed would leave the
		// operator unable to switch a misbehaving chat off.
		auditLogFailure(ctx, err)
	}

	s.trackChatEvent(ctx, chat.EventKillSwitchChanged, map[string]any{
		"scope":         scopeLabel(org),
		"after_enabled": after.GetEnabled(),
		"after_mode":    after.GetMode(),
		"keys_changed":  changed,
	})
}

func scopeLabel(org uuid.UUID) string {
	if org == uuid.Nil {
		return "global"
	}
	return "organization"
}

func optionalUUID(raw string) (uuid.UUID, error) {
	if raw == "" {
		return uuid.Nil, nil
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil, status.Errorf(codes.InvalidArgument, "invalid organization_id: %v", err)
	}
	return id, nil
}

func (s *Server) writeAuditEvent(ctx context.Context, actor, org uuid.UUID, action, resourceType string, metadata []byte) error {
	if s.pool == nil {
		return fmt.Errorf("no pool")
	}
	var actorArg, orgArg any
	if actor != uuid.Nil {
		actorArg = actor
	}
	if org != uuid.Nil {
		orgArg = org
	}
	_, err := s.pool.Exec(ctx,
		`INSERT INTO audit_events (actor_user_id, organization_id, action, resource_type, resource_id, metadata)
		 VALUES ($1, $2, $3, $4, NULL, $5)`,
		actorArg, orgArg, action, resourceType, metadata)
	return err
}

// auditLogFailure reports a failed audit write. Separated so the failure
// is greppable: a gap in audit_events is the kind of thing an
// investigation needs to be able to find.
func auditLogFailure(ctx context.Context, err error) {
	slog.ErrorContext(ctx, "audit.write_failed",
		"error", err, "action", "ai_chat.controls_changed",
		"consequence", "config change applied but not recorded in audit_events")
}

// trackChatEvent forwards a chat telemetry event through the collector.
func (s *Server) trackChatEvent(ctx context.Context, name string, props map[string]any) {
	if s.collector == nil {
		return
	}
	s.collector.Track(ctx, analytics.Event{
		Name:       name,
		Properties: props,
		Source:     "server",
		OccurredAt: time.Now(),
	})
}
