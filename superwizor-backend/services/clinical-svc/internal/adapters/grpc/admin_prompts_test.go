package grpc

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

func adminPromptCtx(userID uuid.UUID) context.Context {
	ctx := context.WithValue(context.Background(), UserRoleKey, "SUPERWIZOR_ADMIN")
	return context.WithValue(ctx, UserIDKey, userID.String())
}

func validUpdateReq(modalityID uuid.UUID, expected int32) *clinicalv1.AdminUpdateModalityPromptRequest {
	return &clinicalv1.AdminUpdateModalityPromptRequest{
		ModalityId:      modalityID.String(),
		SystemPrompt:    "You are a refined clinical supervision assistant.",
		ChangeNote:      "tighter clinical framing for CBT",
		ExpectedVersion: expected,
	}
}

func TestAdminPrompts_RoleGate(t *testing.T) {
	s := &Server{}
	ctx := context.WithValue(context.Background(), UserRoleKey, "THERAPIST")

	if _, err := s.AdminListModalityPrompts(ctx, &emptypb.Empty{}); status.Code(err) != codes.PermissionDenied {
		t.Errorf("list: want PermissionDenied, got %v", err)
	}
	if _, err := s.AdminGetModalityPromptHistory(ctx, &clinicalv1.AdminGetModalityPromptHistoryRequest{}); status.Code(err) != codes.PermissionDenied {
		t.Errorf("history: want PermissionDenied, got %v", err)
	}
	if _, err := s.AdminUpdateModalityPrompt(ctx, validUpdateReq(uuid.New(), 1)); status.Code(err) != codes.PermissionDenied {
		t.Errorf("update: want PermissionDenied, got %v", err)
	}
}

func TestAdminUpdateModalityPrompt_Validation(t *testing.T) {
	s := &Server{}
	ctx := adminPromptCtx(uuid.New())
	modalityID := uuid.New()

	tests := []struct {
		name   string
		mutate func(*clinicalv1.AdminUpdateModalityPromptRequest)
		want   codes.Code
	}{
		{"bad uuid", func(r *clinicalv1.AdminUpdateModalityPromptRequest) { r.ModalityId = "not-a-uuid" }, codes.InvalidArgument},
		{"empty prompt", func(r *clinicalv1.AdminUpdateModalityPromptRequest) { r.SystemPrompt = "   " }, codes.InvalidArgument},
		{"oversize prompt", func(r *clinicalv1.AdminUpdateModalityPromptRequest) {
			r.SystemPrompt = strings.Repeat("x", maxPromptChars+1)
		}, codes.InvalidArgument},
		{"short note", func(r *clinicalv1.AdminUpdateModalityPromptRequest) { r.ChangeNote = "short" }, codes.InvalidArgument},
		{"invalid utf8", func(r *clinicalv1.AdminUpdateModalityPromptRequest) { r.SystemPrompt = string([]byte{0xff, 0xfe, 'a'}) }, codes.InvalidArgument},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := validUpdateReq(modalityID, 1)
			tt.mutate(req)
			_, err := s.AdminUpdateModalityPrompt(ctx, req)
			if status.Code(err) != tt.want {
				t.Errorf("want %v, got %v", tt.want, err)
			}
		})
	}
}

func TestAdminUpdateModalityPrompt_OptimisticLock(t *testing.T) {
	modalityID := uuid.New()
	var liveWrites, versionWrites int
	q := &fakeQuerier{
		getLatestModalityPromptVersionFn: func(ctx context.Context, id uuid.UUID) (int32, error) {
			return 4, nil // someone saved v4 since the admin loaded v3
		},
		updateModalityLivePromptFn: func(ctx context.Context, arg db.UpdateModalityLivePromptParams) error {
			liveWrites++
			return nil
		},
		insertModalityPromptVersionFn: func(ctx context.Context, arg db.InsertModalityPromptVersionParams) (db.InsertModalityPromptVersionRow, error) {
			versionWrites++
			return db.InsertModalityPromptVersionRow{}, nil
		},
	}
	opener := &fakeTxOpener{q: q}
	s := &Server{queries: q, tx: opener}

	_, err := s.AdminUpdateModalityPrompt(adminPromptCtx(uuid.New()), validUpdateReq(modalityID, 3))
	if status.Code(err) != codes.FailedPrecondition {
		t.Fatalf("want FailedPrecondition, got %v", err)
	}
	if liveWrites != 0 || versionWrites != 0 {
		t.Errorf("stale save must not write (live=%d version=%d)", liveWrites, versionWrites)
	}
	if opener.commitCalls != 0 {
		t.Errorf("stale save must not commit (commits=%d)", opener.commitCalls)
	}
	if opener.rollbackCalls == 0 {
		t.Errorf("tx must be rolled back on the lock failure")
	}
}

func TestAdminUpdateModalityPrompt_HappyPath(t *testing.T) {
	modalityID := uuid.New()
	actorID := uuid.New()
	var gotLive db.UpdateModalityLivePromptParams
	var gotVersion db.InsertModalityPromptVersionParams
	var auditCalls int

	q := &fakeQuerier{
		getLatestModalityPromptVersionFn: func(ctx context.Context, id uuid.UUID) (int32, error) {
			if id != modalityID {
				t.Errorf("lock read on wrong modality: %s", id)
			}
			return 3, nil
		},
		updateModalityLivePromptFn: func(ctx context.Context, arg db.UpdateModalityLivePromptParams) error {
			gotLive = arg
			return nil
		},
		insertModalityPromptVersionFn: func(ctx context.Context, arg db.InsertModalityPromptVersionParams) (db.InsertModalityPromptVersionRow, error) {
			gotVersion = arg
			return db.InsertModalityPromptVersionRow{ID: uuid.New(), CreatedAt: time.Now()}, nil
		},
		createAuditEventFn: func(ctx context.Context, arg db.CreateAuditEventParams) error {
			auditCalls++
			if arg.Action != "admin.modality_prompt.update" {
				t.Errorf("audit action = %q", arg.Action)
			}
			return nil
		},
		adminListModalityPromptsFn: func(ctx context.Context) ([]db.AdminListModalityPromptsRow, error) {
			return []db.AdminListModalityPromptsRow{{
				ID: modalityID, SystemCode: "CBT", DisplayName: "CBT",
				SystemPrompt: "You are a refined clinical supervision assistant.",
				Version:      4, UpdatedByEmail: "admin@superwizor.ai", UpdatedAt: time.Now(),
			}}, nil
		},
	}
	opener := &fakeTxOpener{q: q}
	s := &Server{queries: q, tx: opener}

	resp, err := s.AdminUpdateModalityPrompt(adminPromptCtx(actorID), validUpdateReq(modalityID, 3))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if opener.commitCalls != 1 {
		t.Errorf("want exactly 1 commit, got %d", opener.commitCalls)
	}
	if gotLive.ID != modalityID || gotLive.SystemPrompt == "" {
		t.Errorf("live write args: %+v", gotLive)
	}
	if gotVersion.Version != 4 {
		t.Errorf("version bump: want 4 (latest 3 + 1), got %d", gotVersion.Version)
	}
	if gotVersion.CreatedBy != actorID {
		t.Errorf("version author: want %s, got %s", actorID, gotVersion.CreatedBy)
	}
	// Wlasnosc "snapshot = stan zywy" nie jest juz przekazywana przez
	// parametr: od 20.08.2026 InsertModalityPromptVersion CZYTA zywa
	// kolumne w SQL (INSERT ... SELECT), zeby historia niosla takze
	// klucze rownolegle do 'system' (np. 'chat' — soczewke czatu).
	// Ksztaltu zapytania pilnuje zrodlowy
	// TestPromptStudioWritesDoNotDropSiblingKeys.
	if auditCalls != 1 {
		t.Errorf("want 1 audit event, got %d", auditCalls)
	}
	if resp.GetPrompt().GetVersion() != 4 {
		t.Errorf("response version: want 4, got %d", resp.GetPrompt().GetVersion())
	}
}

func TestAdminGetModalityPromptHistory_PagingHasMore(t *testing.T) {
	modalityID := uuid.New()
	q := &fakeQuerier{
		listModalityPromptVersionsFn: func(ctx context.Context, arg db.ListModalityPromptVersionsParams) ([]db.ListModalityPromptVersionsRow, error) {
			if arg.Limit != 3 { // page_size 2 → limit+1
				t.Errorf("limit+1 pattern: want 3, got %d", arg.Limit)
			}
			rows := make([]db.ListModalityPromptVersionsRow, 3)
			for i := range rows {
				rows[i] = db.ListModalityPromptVersionsRow{
					ID: uuid.New(), Version: int32(5 - i),
					SystemPrompt: "p", ChangeNote: "note text long enough",
					CreatedAt: time.Now(),
				}
			}
			return rows, nil
		},
	}
	s := &Server{queries: q}

	resp, err := s.AdminGetModalityPromptHistory(adminPromptCtx(uuid.New()),
		&clinicalv1.AdminGetModalityPromptHistoryRequest{ModalityId: modalityID.String(), PageSize: 2})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Versions) != 2 || !resp.HasMore {
		t.Errorf("want 2 versions + has_more, got %d / %v", len(resp.Versions), resp.HasMore)
	}
}

func TestAdminListModalityPrompts_VersionZeroOmitsTimestamp(t *testing.T) {
	q := &fakeQuerier{
		adminListModalityPromptsFn: func(ctx context.Context) ([]db.AdminListModalityPromptsRow, error) {
			return []db.AdminListModalityPromptsRow{{
				ID: uuid.New(), SystemCode: "NEW", DisplayName: "Pre-backfill",
				Version: 0, UpdatedAt: time.Unix(0, 0), // epoch sentinel
			}}, nil
		},
	}
	s := &Server{queries: q}

	resp, err := s.AdminListModalityPrompts(adminPromptCtx(uuid.New()), &emptypb.Empty{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Prompts[0].GetUpdatedAt() != nil {
		t.Errorf("version-0 row must omit updated_at, got %v", resp.Prompts[0].GetUpdatedAt())
	}
}

// ── Klucz 'chat' (soczewka modalnosci) ────────────────────────────────

func chatUpdateReq(modalityID uuid.UUID, expected int32, text string) *clinicalv1.AdminUpdateModalityPromptRequest {
	return &clinicalv1.AdminUpdateModalityPromptRequest{
		ModalityId:      modalityID.String(),
		SystemPrompt:    text,
		ChangeNote:      "aktualizacja soczewki czatu",
		ExpectedVersion: expected,
		PromptKey:       "chat",
	}
}

// Zapis soczewki idzie WYLACZNIE przez UpdateModalityLiveChatPrompt —
// dotkniecie promptu raportowego przy edycji soczewki byloby ta sama
// klasa bledu, co skasowanie soczewki przy edycji raportu.
func TestAdminUpdateChatPromptWritesOnlyTheChatKey(t *testing.T) {
	modalityID := uuid.New()
	actorID := uuid.New()

	var chatWrites, systemWrites int
	var gotChat db.UpdateModalityLiveChatPromptParams
	q := &fakeQuerier{
		getLatestModalityPromptVersionFn: func(ctx context.Context, id uuid.UUID) (int32, error) {
			return 3, nil
		},
		updateModalityLiveChatPromptFn: func(ctx context.Context, arg db.UpdateModalityLiveChatPromptParams) error {
			chatWrites++
			gotChat = arg
			return nil
		},
		updateModalityLivePromptFn: func(ctx context.Context, arg db.UpdateModalityLivePromptParams) error {
			systemWrites++
			return nil
		},
		insertModalityPromptVersionFn: func(ctx context.Context, arg db.InsertModalityPromptVersionParams) (db.InsertModalityPromptVersionRow, error) {
			return db.InsertModalityPromptVersionRow{ID: uuid.New(), CreatedAt: time.Now()}, nil
		},
		createAuditEventFn: func(ctx context.Context, arg db.CreateAuditEventParams) error { return nil },
		adminListModalityPromptsFn: func(ctx context.Context) ([]db.AdminListModalityPromptsRow, error) {
			// Pusta lista wymusza sciezke fallbacku odpowiedzi — te sama,
			// ktora weryfikuje mapowanie ChatPrompt bez reread-u.
			return nil, nil
		},
	}
	opener := &fakeTxOpener{q: q}
	s := NewServerWithDeps(q, opener, nil, nil, nil, nil, "test", nil)

	resp, err := s.AdminUpdateModalityPrompt(adminPromptCtx(actorID),
		chatUpdateReq(modalityID, 3, "Prowadzisz analizę w ujęciu testowym."))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if chatWrites != 1 || systemWrites != 0 {
		t.Errorf("zapisy: chat=%d system=%d — soczewka nie moze dotykac raportu", chatWrites, systemWrites)
	}
	if gotChat.ChatPrompt == "" || gotChat.ID != modalityID {
		t.Errorf("parametry zapisu: %+v", gotChat)
	}
	if resp.GetPrompt().GetVersion() != 4 {
		t.Errorf("wersja: want 4, got %d", resp.GetPrompt().GetVersion())
	}
	if resp.GetPrompt().GetChatPrompt() == "" || resp.GetPrompt().GetSystemPrompt() != "" {
		t.Errorf("fallback odpowiedzi pomylil klucze: chat=%q system=%q",
			resp.GetPrompt().GetChatPrompt(), resp.GetPrompt().GetSystemPrompt())
	}
}

// Pusty tekst soczewki jest POPRAWNY: wylacza soczewke tej modalnosci.
// Prompt raportowy pusty byc nie moze — te dwie reguly musza sie roznic.
func TestChatPromptMayBeEmptySystemMayNot(t *testing.T) {
	if err := validateChatPromptUpdate("   ", "wylaczenie soczewki na czas testow"); err != nil {
		t.Errorf("pusta soczewka odrzucona: %v", err)
	}
	if err := validatePromptUpdate("   ", "notatka odpowiednio dluga tutaj"); err == nil {
		t.Error("pusty prompt raportowy przeszedl")
	}
}

// Soczewka to jedyny prompt edytowalny z panelu — slowa ramy marki musza
// byc odrzucane serwerowo, bo to jedyne miejsce, gdzie ominelyby review.
func TestChatPromptRejectsBrandBannedStems(t *testing.T) {
	for _, txt := range []string{
		"Jesteś zaawansowanym asystentem AI.",
		"Analizuj objawy Pacjenta uważnie.",
		"Postaw wstępną diagnozę na bazie cytatów.",
		"Kliniczny obraz ma pierwszeństwo.",
	} {
		if err := validateChatPromptUpdate(txt, "notatka odpowiednio dluga"); err == nil {
			t.Errorf("przeszlo mimo slowa zakazanego: %q", txt)
		}
	}
	// Legalne slownictwo zakazow NIE moze wpadac w filtr.
	if err := validateChatPromptUpdate(
		"Bez etykiet diagnostycznych; opisuj wzorce.", "notatka odpowiednio dluga"); err != nil {
		t.Errorf("legalny tekst odrzucony: %v", err)
	}
}

func TestChatPromptLengthCap(t *testing.T) {
	long := strings.Repeat("a", maxChatPromptChars+1)
	if err := validateChatPromptUpdate(long, "notatka odpowiednio dluga"); err == nil {
		t.Error("soczewka ponad limit przeszla")
	}
}

func TestUnknownPromptKeyIsRejected(t *testing.T) {
	modalityID := uuid.New()
	q := &fakeQuerier{}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, nil, nil, nil, nil, "test", nil)
	req := chatUpdateReq(modalityID, 1, "x")
	req.PromptKey = "verifier" // proba dobrania sie do warstwy kontroli
	if _, err := s.AdminUpdateModalityPrompt(adminPromptCtx(uuid.New()), req); err == nil {
		t.Fatal("nieznany prompt_key przeszedl")
	}
}
