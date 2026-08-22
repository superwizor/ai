// ontology_studio.go — Ontology Studio (plan 16 v1.2, sekcja 4.1).
//
// Ontologia modalnosci przestala byc plikiem w repo pod CODEOWNERS, a
// stala sie wersjonowanym rekordem edytowanym w aplikacji (adnotacja do
// D2 w dokumencie 11). Ten plik jest miejscem, w ktorym cztery wlasnosci
// starego mechanizmu sa egzekwowane:
//
//	(a) wersja `approved` jest niemutowalna — nie ma sciezki edycji,
//	    ktora ja dotknie; "edytuj" tworzy nowy draft (CreateDraft z
//	    copy_from_version_id). Dublowane triggerem w bazie, bo ta
//	    wlasnosc zastapila niemutowalnosc commita i nie moze zalezec od
//	    tego, ktora sciezka kodu pisze;
//	(b) autor nie zatwierdza wlasnej wersji — four-eyes sprawdzane TU,
//	    a nie w UI, bo UI nie jest granica bezpieczenstwa;
//	(c) walidacja metaschematem jest twarda przy zapisie, zatwierdzeniu
//	    i aktywacji — ta sama implementacja co lint w CI (pkg/ontology);
//	(d) audyt kazdego przejscia z wymagana notatka.
//
// ROZDZIAL ROL. ONTOLOGY_EDITOR tworzy tresc i zatwierdza cudza;
// SUPERWIZOR_ADMIN dodatkowo aktywuje na produkcji. To sa dwie rozne
// decyzje: "tresc jest merytorycznie w porzadku" vs "tym generujemy
// raporty". Status != live.

package grpc

import (
	"context"
	"errors"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/pkg/ontology"
)

const (
	// minOntologyNoteChars — jak minChangeNoteChars w Prompt Studio.
	// Notatka jest tym, co nastepny dyzurny czyta o 3 w nocy.
	minOntologyNoteChars = 10
	// maxOntologyYAMLBytes bounds jednej wersji. Ontologia PPT ma dzis
	// ~6 KB; 512 KB to zapas na katalogi wielokrotnie wieksze bez
	// otwierania drogi do wrzucenia czegokolwiek do JSONB.
	maxOntologyYAMLBytes = 512 * 1024

	ontologyVersionsPageDefault = 20
	ontologyVersionsPageMax     = 50
)

// requireOntologyEditor przepuszcza ONTOLOGY_EDITOR oraz SUPERWIZOR_ADMIN.
//
// Admin jest nadzbiorem celowo: zespol wewnetrzny musi umiec odblokowac
// prace ekspercka bez nadawania sobie drugiej roli. Odwrotnie nie —
// ONTOLOGY_EDITOR nie dostaje niczego poza Studiem.
func requireOntologyEditor(ctx context.Context) error {
	role, _ := ctx.Value(UserRoleKey).(string)
	switch role {
	case "ONTOLOGY_EDITOR", "SUPERWIZOR_ADMIN":
		return nil
	case "":
		return status.Error(codes.Unauthenticated, "missing role in context")
	default:
		return status.Errorf(codes.PermissionDenied,
			"role %s not authorised for Ontology Studio", role)
	}
}

func actorFromContext(ctx context.Context) (uuid.UUID, error) {
	raw, _ := ctx.Value(UserIDKey).(string)
	id, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil, status.Error(codes.Unauthenticated, "missing user id in context")
	}
	return id, nil
}

// validateOntologyPayload jest jedyna brama, przez ktora tresc wchodzi
// do bazy. Wolana przy tworzeniu i przy kazdej edycji draftu.
func validateOntologyPayload(yamlText string) (*ontology.Ontology, error) {
	if len(yamlText) == 0 {
		return nil, status.Error(codes.InvalidArgument, "content_yaml is required")
	}
	if len(yamlText) > maxOntologyYAMLBytes {
		return nil, status.Errorf(codes.InvalidArgument,
			"content_yaml exceeds %d bytes (%d)", maxOntologyYAMLBytes, len(yamlText))
	}
	o, err := ontology.Parse([]byte(yamlText))
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "yaml: %v", err)
	}
	if problems := o.Validate(); len(problems) > 0 {
		// Pierwszy problem w komunikacie, komplet w OntologyLint —
		// klient i tak wola lint na zywo, a status.Error z 40 liniami
		// jest nieczytelny w logach.
		return nil, status.Errorf(codes.InvalidArgument,
			"metaschema: %d problem(ow), pierwszy: %s", len(problems), problems[0])
	}
	// Autoryzacja zyje w statusie wiersza i w four-eyes, nie w tresci.
	// Gdyby YAML mogl deklarowac approved_by, autor obszedlby przeglad
	// jednym polem.
	if o.IsApproved() {
		return nil, status.Error(codes.InvalidArgument,
			"approved_by must be empty — autoryzacja nalezy do przeplywu Studia, nie do tresci")
	}
	return o, nil
}

func requireNote(note string) (string, error) {
	n := strings.TrimSpace(note)
	if len(n) < minOntologyNoteChars {
		return "", status.Errorf(codes.InvalidArgument,
			"note must be at least %d characters — explain why", minOntologyNoteChars)
	}
	return n, nil
}

// ── odczyt ──

func (s *Server) OntologyListModalities(ctx context.Context, _ *emptypb.Empty) (*clinicalv1.OntologyListModalitiesResponse, error) {
	if err := requireOntologyEditor(ctx); err != nil {
		return nil, err
	}
	rows, err := s.ontologyPool.Query(ctx, sqlOntologyModalities)
	if err != nil {
		slog.ErrorContext(ctx, "ontology.list_modalities", "error", err)
		return nil, status.Error(codes.Internal, "list modalities")
	}
	defer rows.Close()

	resp := &clinicalv1.OntologyListModalitiesResponse{}
	for rows.Next() {
		var m clinicalv1.OntologyModalitySummary
		var modalityID uuid.UUID
		var activeVersion, activeVersionID, latestVersion *string
		if err := rows.Scan(&modalityID, &m.SystemCode, &m.DisplayName,
			&activeVersion, &activeVersionID, &latestVersion,
			&m.DraftCount, &m.ReviewCount); err != nil {
			slog.ErrorContext(ctx, "ontology.scan_modality", "error", err)
			return nil, status.Error(codes.Internal, "scan modality")
		}
		m.ModalityId = modalityID.String()
		m.ActiveVersion = derefStr(activeVersion)
		m.ActiveVersionId = derefStr(activeVersionID)
		m.LatestVersion = derefStr(latestVersion)
		resp.Modalities = append(resp.Modalities, &m)
	}
	return resp, rows.Err()
}

func (s *Server) OntologyListVersions(ctx context.Context, req *clinicalv1.OntologyListVersionsRequest) (*clinicalv1.OntologyListVersionsResponse, error) {
	if err := requireOntologyEditor(ctx); err != nil {
		return nil, err
	}
	modalityID, err := uuid.Parse(req.GetModalityId())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "modality_id must be a UUID")
	}
	pageSize := req.GetPageSize()
	if pageSize <= 0 {
		pageSize = ontologyVersionsPageDefault
	}
	if pageSize > ontologyVersionsPageMax {
		pageSize = ontologyVersionsPageMax
	}
	offset := req.GetPageOffset()
	if offset < 0 {
		offset = 0
	}

	// limit+1 daje has_more bez COUNT(*) — wzorzec z Prompt Studio.
	rows, err := s.ontologyPool.Query(ctx, sqlOntologyVersions, modalityID, pageSize+1, offset)
	if err != nil {
		slog.ErrorContext(ctx, "ontology.list_versions", "error", err)
		return nil, status.Error(codes.Internal, "list versions")
	}
	defer rows.Close()

	resp := &clinicalv1.OntologyListVersionsResponse{}
	for rows.Next() {
		v, err := scanOntologyVersion(rows)
		if err != nil {
			slog.ErrorContext(ctx, "ontology.scan_version", "error", err)
			return nil, status.Error(codes.Internal, "scan version")
		}
		resp.Versions = append(resp.Versions, v)
	}
	if err := rows.Err(); err != nil {
		return nil, status.Error(codes.Internal, "iterate versions")
	}
	if len(resp.Versions) > int(pageSize) {
		resp.HasMore = true
		resp.Versions = resp.Versions[:pageSize]
	}
	return resp, nil
}

func (s *Server) OntologyGetVersion(ctx context.Context, req *clinicalv1.OntologyGetVersionRequest) (*clinicalv1.OntologyVersion, error) {
	if err := requireOntologyEditor(ctx); err != nil {
		return nil, err
	}
	id, err := uuid.Parse(req.GetVersionId())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "version_id must be a UUID")
	}
	return s.loadOntologyVersion(ctx, id)
}

// OntologyLint waliduje bez zapisu.
//
// Ta sama implementacja co przy zapisie i co lint w CI. Dwa
// rozjezdzajace sie walidatory bylyby gorsze niz jeden: tresc
// przechodzaca podglad moglaby zostac odrzucona przy zapisie.
func (s *Server) OntologyLint(ctx context.Context, req *clinicalv1.OntologyLintRequest) (*clinicalv1.OntologyLintResponse, error) {
	if err := requireOntologyEditor(ctx); err != nil {
		return nil, err
	}
	o, err := ontology.Parse([]byte(req.GetContentYaml()))
	if err != nil {
		return &clinicalv1.OntologyLintResponse{Problems: []string{err.Error()}}, nil
	}
	problems := o.Validate()
	if o.IsApproved() {
		problems = append(problems,
			"approved_by musi byc puste — autoryzacja nalezy do przeplywu Studia")
	}
	return &clinicalv1.OntologyLintResponse{
		Problems:       problems,
		ConstructCount: int32(len(o.Constructs)),
	}, nil
}

func derefStr(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

func ontologyStatusToProto(s string) clinicalv1.OntologyStatus {
	switch s {
	case "draft":
		return clinicalv1.OntologyStatus_ONTOLOGY_STATUS_DRAFT
	case "ready_for_review":
		return clinicalv1.OntologyStatus_ONTOLOGY_STATUS_READY_FOR_REVIEW
	case "approved":
		return clinicalv1.OntologyStatus_ONTOLOGY_STATUS_APPROVED
	default:
		return clinicalv1.OntologyStatus_ONTOLOGY_STATUS_UNSPECIFIED
	}
}

func (s *Server) loadOntologyVersion(ctx context.Context, id uuid.UUID) (*clinicalv1.OntologyVersion, error) {
	row := s.ontologyPool.QueryRow(ctx, sqlOntologyVersionByID, id)
	v, err := scanOntologyVersion(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "ontology version not found")
		}
		slog.ErrorContext(ctx, "ontology.load_version", "error", err, "version_id", id)
		return nil, status.Error(codes.Internal, "load version")
	}
	return v, nil
}

// scanner obejmuje pgx.Row i pgx.Rows — obie maja Scan.
type scanner interface{ Scan(dest ...any) error }

func scanOntologyVersion(sc scanner) (*clinicalv1.OntologyVersion, error) {
	var (
		id, modalityID        uuid.UUID
		version, contentYAML  string
		statusStr, changeNote string
		createdByEmail        string
		createdAt             time.Time
		approvedByEmail       *string
		approvedAt            *time.Time
		approvalNote          *string
		isActive              bool
		constructCount        int32
	)
	if err := sc.Scan(&id, &modalityID, &version, &contentYAML, &statusStr,
		&createdByEmail, &createdAt, &changeNote,
		&approvedByEmail, &approvedAt, &approvalNote,
		&isActive, &constructCount); err != nil {
		return nil, err
	}
	out := &clinicalv1.OntologyVersion{
		Id:             id.String(),
		ModalityId:     modalityID.String(),
		Version:        version,
		ContentYaml:    contentYAML,
		Status:         ontologyStatusToProto(statusStr),
		CreatedByEmail: createdByEmail,
		CreatedAt:      timestamppb.New(createdAt),
		ChangeNote:     changeNote,
		IsActive:       isActive,
		ConstructCount: constructCount,
	}
	if approvedByEmail != nil {
		out.ApprovedByEmail = *approvedByEmail
	}
	if approvedAt != nil {
		out.ApprovedAt = timestamppb.New(*approvedAt)
	}
	if approvalNote != nil {
		out.ApprovalNote = *approvalNote
	}
	return out, nil
}

func ontologyAuditProps(v *clinicalv1.OntologyVersion, extra map[string]any) map[string]any {
	p := map[string]any{
		"version_id":  v.GetId(),
		"modality_id": v.GetModalityId(),
		"version":     v.GetVersion(),
		"status":      v.GetStatus().String(),
	}
	for k, val := range extra {
		p[k] = val
	}
	return p
}
