// admin_prompts.go — Admin Prompt Studio RPCs (docs/31). SUPERWIZOR_ADMIN
// only, same role-gate pattern as admin_sessions.go.
//
// The live prompt stays in modalities.therapist_ai_general_prompt —
// llm-worker reads that column fresh on every report, so a successful
// AdminUpdateModalityPrompt changes the NEXT report with no deploys.
// modality_prompt_versions is the append-only history; the invariant
// "live column == highest version's snapshot" is maintained by doing
// both writes in one transaction, serialized per modality by the
// FOR UPDATE in GetLatestModalityPromptVersion.

package grpc

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

const (
	// maxPromptChars bounds the editable system prompt. The whole call-2
	// prompt (scaffold + this + RAG block + transcript) must stay well
	// inside the model's input budget; today's largest seed is ~2k chars,
	// so 20k is generous headroom without being abusable.
	maxPromptChars = 20000

	// maxChatPromptChars ogranicza soczewke czatu. Znacznie ciasniej niz
	// prompt raportowy, bo soczewka jedzie na KAZDYM uziemionym wywolaniu
	// generatora — dzien 20.08 pokazal, jak drogie sa nadmiarowe tokeny
	// wejscia w tym torze.
	maxChatPromptChars = 2500

	promptKeySystem = "system"
	promptKeyChat   = "chat"
	// minChangeNoteChars matches the admin panel's ActionDialog reason
	// minimum used by the other admin mutations.
	minChangeNoteChars = 10

	promptHistoryDefaultPageSize = 20
	promptHistoryMaxPageSize     = 50
)

// AdminListModalityPrompts returns every modality with its live prompt
// text and latest-version metadata. SUPERWIZOR_ADMIN only.
func (s *Server) AdminListModalityPrompts(ctx context.Context, _ *emptypb.Empty) (*clinicalv1.AdminListModalityPromptsResponse, error) {
	if err := requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}
	rows, err := s.queries.AdminListModalityPrompts(ctx)
	if err != nil {
		slog.Error("AdminListModalityPrompts query", "error", err)
		return nil, status.Error(codes.Internal, "list modality prompts")
	}
	resp := &clinicalv1.AdminListModalityPromptsResponse{}
	for _, r := range rows {
		resp.Prompts = append(resp.Prompts, toProtoAdminModalityPrompt(r))
	}
	return resp, nil
}

// AdminGetModalityPromptHistory returns a modality's version history,
// newest first, offset-paged with the limit+1 has_more pattern.
func (s *Server) AdminGetModalityPromptHistory(ctx context.Context, req *clinicalv1.AdminGetModalityPromptHistoryRequest) (*clinicalv1.AdminGetModalityPromptHistoryResponse, error) {
	if err := requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}
	modalityID, err := uuid.Parse(req.GetModalityId())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "modality_id must be a UUID")
	}
	pageSize := req.GetPageSize()
	if pageSize <= 0 {
		pageSize = promptHistoryDefaultPageSize
	}
	if pageSize > promptHistoryMaxPageSize {
		pageSize = promptHistoryMaxPageSize
	}
	offset := req.GetPageOffset()
	if offset < 0 {
		offset = 0
	}

	rows, err := s.queries.ListModalityPromptVersions(ctx, db.ListModalityPromptVersionsParams{
		ModalityID: modalityID,
		Limit:      pageSize + 1, // +1 row → has_more without COUNT(*)
		Offset:     offset,
	})
	if err != nil {
		slog.Error("ListModalityPromptVersions query", "error", err, "modality_id", modalityID)
		return nil, status.Error(codes.Internal, "list prompt versions")
	}

	resp := &clinicalv1.AdminGetModalityPromptHistoryResponse{}
	if len(rows) > int(pageSize) {
		resp.HasMore = true
		rows = rows[:pageSize]
	}
	for _, r := range rows {
		resp.Versions = append(resp.Versions, &clinicalv1.AdminModalityPromptVersion{
			Id:             r.ID.String(),
			Version:        r.Version,
			SystemPrompt:   r.SystemPrompt,
			ChatPrompt:     r.ChatPrompt,
			ChangeNote:     r.ChangeNote,
			CreatedByEmail: r.CreatedByEmail,
			CreatedAt:      timestamppb.New(r.CreatedAt),
		})
	}
	return resp, nil
}

// AdminUpdateModalityPrompt replaces the live prompt and appends a
// version snapshot, in one transaction, behind an optimistic lock.
// Restores are this same RPC with a historical version's text.
func (s *Server) AdminUpdateModalityPrompt(ctx context.Context, req *clinicalv1.AdminUpdateModalityPromptRequest) (*clinicalv1.AdminUpdateModalityPromptResponse, error) {
	if err := requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}
	actorIDStr, _ := ctx.Value(UserIDKey).(string)
	actorID, err := uuid.Parse(actorIDStr)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "missing user id in context")
	}
	modalityID, err := uuid.Parse(req.GetModalityId())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "modality_id must be a UUID")
	}
	// Pusty prompt_key = "system": kazdy istniejacy klient (Studio sprzed
	// zakladki soczewek) dalej edytuje prompt raportowy bez zmian.
	promptKey := req.GetPromptKey()
	if promptKey == "" {
		promptKey = promptKeySystem
	}
	switch promptKey {
	case promptKeySystem:
		if verr := validatePromptUpdate(req.GetSystemPrompt(), req.GetChangeNote()); verr != nil {
			return nil, verr
		}
	case promptKeyChat:
		if verr := validateChatPromptUpdate(req.GetSystemPrompt(), req.GetChangeNote()); verr != nil {
			return nil, verr
		}
	default:
		return nil, status.Errorf(codes.InvalidArgument,
			"prompt_key must be %q or %q", promptKeySystem, promptKeyChat)
	}
	prompt := strings.TrimSpace(req.GetSystemPrompt())
	note := strings.TrimSpace(req.GetChangeNote())

	tx, err := s.tx.Begin(ctx)
	if err != nil {
		slog.Error("AdminUpdateModalityPrompt begin tx", "error", err)
		return nil, status.Error(codes.Internal, "begin transaction")
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := tx.Queries()

	// FOR UPDATE on the modality row serializes concurrent saves; the
	// version comparison then rejects the stale writer deterministically.
	latest, err := qtx.GetLatestModalityPromptVersion(ctx, modalityID)
	if err != nil {
		// pgx.ErrNoRows ⇒ unknown modality id (FOR UPDATE found no row).
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "modality not found")
		}
		slog.Error("GetLatestModalityPromptVersion", "error", err, "modality_id", modalityID)
		return nil, status.Error(codes.Internal, "read current version")
	}
	if latest != req.GetExpectedVersion() {
		return nil, status.Errorf(codes.FailedPrecondition,
			"prompt was changed by someone else (current version %d, expected %d) — reload before retrying",
			latest, req.GetExpectedVersion())
	}

	newVersion := latest + 1
	if promptKey == promptKeyChat {
		if err := qtx.UpdateModalityLiveChatPrompt(ctx, db.UpdateModalityLiveChatPromptParams{
			ID:         modalityID,
			ChatPrompt: prompt,
		}); err != nil {
			slog.Error("UpdateModalityLiveChatPrompt", "error", err, "modality_id", modalityID)
			return nil, status.Error(codes.Internal, "update live prompt")
		}
	} else if err := qtx.UpdateModalityLivePrompt(ctx, db.UpdateModalityLivePromptParams{
		ID:           modalityID,
		SystemPrompt: prompt,
	}); err != nil {
		slog.Error("UpdateModalityLivePrompt", "error", err, "modality_id", modalityID)
		return nil, status.Error(codes.Internal, "update live prompt")
	}
	// Snapshot wersji pochodzi z ZYWEJ kolumny (patrz modality_prompts.sql)
	// — nie z parametru — zeby historia niosla takze klucze rownolegle do
	// 'system' (np. 'chat'). Dlatego parametr tekstu promptu tu znika.
	inserted, err := qtx.InsertModalityPromptVersion(ctx, db.InsertModalityPromptVersionParams{
		ModalityID: modalityID,
		Version:    newVersion,
		ChangeNote: note,
		CreatedBy:  actorID,
	})
	if err != nil {
		slog.Error("InsertModalityPromptVersion", "error", err, "modality_id", modalityID)
		return nil, status.Error(codes.Internal, "insert prompt version")
	}
	if err := tx.Commit(ctx); err != nil {
		slog.Error("AdminUpdateModalityPrompt commit", "error", err)
		return nil, status.Error(codes.Internal, "commit")
	}

	// Audit (post-commit, best-effort — same contract as the other
	// admin mutations: the change itself is already durable + the
	// version row carries who/when/why).
	auditMeta, _ := json.Marshal(map[string]any{
		"old_version":  latest,
		"new_version":  newVersion,
		"change_note":  note,
		"prompt_chars": len(prompt),
		"prompt_key":   promptKey,
	})
	_ = s.queries.CreateAuditEvent(ctx, db.CreateAuditEventParams{
		ActorUserID:  pgtype.UUID{Bytes: actorID, Valid: true},
		Action:       "admin.modality_prompt.update",
		ResourceType: "modality",
		ResourceID:   pgtype.UUID{Bytes: modalityID, Valid: true},
		Metadata:     auditMeta,
	})

	slog.Info("analytics",
		"ae", "admin.prompt_updated",
		"modality_id", modalityID.String(),
		"new_version", newVersion,
		"prompt_chars", len(prompt))

	// Re-read the list row for a fresh, display-ready response.
	rows, err := s.queries.AdminListModalityPrompts(ctx)
	if err == nil {
		for _, r := range rows {
			if r.ID == modalityID {
				return &clinicalv1.AdminUpdateModalityPromptResponse{
					Prompt: toProtoAdminModalityPrompt(r),
				}, nil
			}
		}
	}
	// Fallback: synthesize from what we know (list re-read failed).
	fallback := &clinicalv1.AdminModalityPrompt{
		ModalityId: modalityID.String(),
		Version:    newVersion,
		UpdatedAt:  timestamppb.New(inserted.CreatedAt),
	}
	if promptKey == promptKeyChat {
		fallback.ChatPrompt = prompt
	} else {
		fallback.SystemPrompt = prompt
	}
	return &clinicalv1.AdminUpdateModalityPromptResponse{Prompt: fallback}, nil
}

// validatePromptUpdate enforces the docs/31 §4 rules. Returns a
// status.Error suitable for direct return, nil when valid.
func validatePromptUpdate(prompt, note string) error {
	p := strings.TrimSpace(prompt)
	if p == "" {
		return status.Error(codes.InvalidArgument, "system_prompt must not be empty")
	}
	if len(p) > maxPromptChars {
		return status.Errorf(codes.InvalidArgument,
			"system_prompt exceeds %d characters (%d)", maxPromptChars, len(p))
	}
	if !utf8.ValidString(p) {
		return status.Error(codes.InvalidArgument, "system_prompt must be valid UTF-8")
	}
	if len(strings.TrimSpace(note)) < minChangeNoteChars {
		return status.Errorf(codes.InvalidArgument,
			"change_note must be at least %d characters", minChangeNoteChars)
	}
	return nil
}

// brandBannedStems to slowa ramy marki, ktore nie moga trafic do
// soczewki czatu. Rdzenie, nie pelne formy — polska fleksja ("pacjenta",
// "diagnozie") nie moze byc furtka. Celowo NIE lapiemy "diagnost..."
// (etykiety diagnostyczne to legalne slownictwo zakazow w soczewkach).
var brandBannedStems = []string{"pacjent", "kliniczn", "diagnoz", "asystent", "copilot", "chatbot", "scribe"}

// validateChatPromptUpdate to regula dla klucza 'chat'.
//
// Rozni sie od raportowej w trzech punktach i kazdy jest celowy:
//   - PUSTY tekst jest poprawny — wylacza soczewke tej modalnosci
//     (czat wraca do golych promptow per intencja);
//   - limit 2500 znakow, bo soczewka jedzie na kazdym wywolaniu
//     generatora;
//   - slowa ramy marki odrzucane serwerowo: soczewka to jedyny prompt
//     edytowalny z panelu, wiec to jedyne miejsce, gdzie taki wpis
//     moglby ominac review kodu.
func validateChatPromptUpdate(prompt, note string) error {
	if len(strings.TrimSpace(note)) < minChangeNoteChars {
		return status.Errorf(codes.InvalidArgument,
			"change_note must be at least %d characters", minChangeNoteChars)
	}
	p := strings.TrimSpace(prompt)
	if p == "" {
		return nil // wylaczenie soczewki
	}
	if len(p) > maxChatPromptChars {
		return status.Errorf(codes.InvalidArgument,
			"chat prompt exceeds %d characters (%d)", maxChatPromptChars, len(p))
	}
	if !utf8.ValidString(p) {
		return status.Error(codes.InvalidArgument, "chat prompt must be valid UTF-8")
	}
	low := strings.ToLower(p)
	for _, stem := range brandBannedStems {
		if strings.Contains(low, stem) {
			return status.Errorf(codes.InvalidArgument,
				"chat prompt contains brand-banned word stem %q", stem)
		}
	}
	return nil
}

func toProtoAdminModalityPrompt(r db.AdminListModalityPromptsRow) *clinicalv1.AdminModalityPrompt {
	p := &clinicalv1.AdminModalityPrompt{
		ModalityId:     r.ID.String(),
		SystemCode:     r.SystemCode,
		DisplayName:    r.DisplayName,
		ModalityType:   r.ModalityType,
		IsSupported:    r.IsSupported,
		SystemPrompt:   r.SystemPrompt,
		ChatPrompt:     r.ChatPrompt,
		Version:        r.Version,
		UpdatedByEmail: r.UpdatedByEmail,
	}
	// version 0 = modality predates the 000052 backfill; its epoch
	// sentinel timestamp would only confuse the UI.
	if r.Version > 0 {
		p.UpdatedAt = timestamppb.New(r.UpdatedAt)
	}
	return p
}
