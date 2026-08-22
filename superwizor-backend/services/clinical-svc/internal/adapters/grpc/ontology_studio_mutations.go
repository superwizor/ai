package grpc

import (
	"context"
	"errors"
	"log/slog"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
)

// OntologyCreateDraft zaklada nowa wersje roboczą.
//
// To jest rowniez jedyna sciezka "edycji" wersji zatwierdzonej:
// copy_from_version_id kopiuje tresc, a oryginal zostaje nietkniety.
// Niemutowalnosc approved zastapila niemutowalnosc commita w gicie, wiec
// nie moze miec furtki.
func (s *Server) OntologyCreateDraft(ctx context.Context, req *clinicalv1.OntologyCreateDraftRequest) (*clinicalv1.OntologyVersion, error) {
	if err := requireOntologyEditor(ctx); err != nil {
		return nil, err
	}
	actor, err := actorFromContext(ctx)
	if err != nil {
		return nil, err
	}
	modalityID, err := uuid.Parse(req.GetModalityId())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "modality_id must be a UUID")
	}
	note, err := requireNote(req.GetChangeNote())
	if err != nil {
		return nil, err
	}

	yamlText := req.GetContentYaml()
	if src := req.GetCopyFromVersionId(); src != "" {
		if yamlText != "" {
			// Dwa zrodla tresci w jednym zadaniu to niejednoznacznosc, a
			// nie wygoda — ktore z nich wygrywa, bylo by ukryta regula.
			return nil, status.Error(codes.InvalidArgument,
				"podaj content_yaml ALBO copy_from_version_id, nie oba")
		}
		srcID, perr := uuid.Parse(src)
		if perr != nil {
			return nil, status.Error(codes.InvalidArgument, "copy_from_version_id must be a UUID")
		}
		srcVer, lerr := s.loadOntologyVersion(ctx, srcID)
		if lerr != nil {
			return nil, lerr
		}
		yamlText = srcVer.GetContentYaml()
	}

	o, err := validateOntologyPayload(yamlText)
	if err != nil {
		return nil, err
	}
	version := req.GetVersion()
	if version == "" {
		version = o.Version
	}
	// Semver w tresci i w kolumnie musza sie zgadzac, inaczej lista w
	// Studio pokazuje co innego niz prompt S2 dostanie w kontekscie.
	if version != o.Version {
		return nil, status.Errorf(codes.InvalidArgument,
			"version %q nie zgadza sie z `version: %s` w tresci", version, o.Version)
	}

	var newID uuid.UUID
	err = s.ontologyPool.QueryRow(ctx, sqlOntologyInsertDraft,
		modalityID, version, yamlText, actor, note).Scan(&newID)
	if err != nil {
		if isUniqueViolation(err) {
			return nil, status.Errorf(codes.AlreadyExists,
				"wersja %s dla tej modalnosci juz istnieje", version)
		}
		slog.ErrorContext(ctx, "ontology.create_draft", "error", err)
		return nil, status.Error(codes.Internal, "create draft")
	}

	out, err := s.loadOntologyVersion(ctx, newID)
	if err != nil {
		return nil, err
	}
	s.trackOntologyEvent(ctx, "ontology_draft_created", actor, out, map[string]any{
		"copied_from": req.GetCopyFromVersionId(),
	})
	return out, nil
}

// OntologyUpdateDraft nadpisuje tresc wersji roboczej.
//
// Wylacznie `draft`: wersja w przegladzie tez jest zamrozona, bo edycja
// w jego trakcie oznaczalaby, ze zatwierdzajacy widzial co innego, niz
// zatwierdza.
func (s *Server) OntologyUpdateDraft(ctx context.Context, req *clinicalv1.OntologyUpdateDraftRequest) (*clinicalv1.OntologyVersion, error) {
	if err := requireOntologyEditor(ctx); err != nil {
		return nil, err
	}
	actor, err := actorFromContext(ctx)
	if err != nil {
		return nil, err
	}
	id, err := uuid.Parse(req.GetVersionId())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "version_id must be a UUID")
	}
	note, err := requireNote(req.GetChangeNote())
	if err != nil {
		return nil, err
	}
	if _, err := validateOntologyPayload(req.GetContentYaml()); err != nil {
		return nil, err
	}

	n, err := s.ontologyPool.Exec(ctx, sqlOntologyUpdateDraft, id, req.GetContentYaml(), note)
	if err != nil {
		slog.ErrorContext(ctx, "ontology.update_draft", "error", err, "version_id", id)
		return nil, status.Error(codes.Internal, "update draft")
	}
	if n == 0 {
		return nil, s.explainNoTransition(ctx, id, "draft")
	}

	out, err := s.loadOntologyVersion(ctx, id)
	if err != nil {
		return nil, err
	}
	s.trackOntologyEvent(ctx, "ontology_draft_updated", actor, out, nil)
	return out, nil
}

// OntologySubmitForReview: draft -> ready_for_review.
func (s *Server) OntologySubmitForReview(ctx context.Context, req *clinicalv1.OntologyTransitionRequest) (*clinicalv1.OntologyVersion, error) {
	return s.ontologyTransition(ctx, req, ontologyTransition{
		event: "ontology_submitted",
		from:  "draft",
		exec: func(ctx context.Context, id, actor uuid.UUID, note string) (int64, error) {
			return s.ontologyPool.Exec(ctx, sqlOntologySubmit, id, note)
		},
	})
}

// OntologyApprove: ready_for_review -> approved, ale NIE przez autora.
//
// Four-eyes jest sprawdzane w trzech miejscach naraz (tu, w WHERE
// zapytania i w CHECK schematu). Dublowanie jest celowe: ta wlasnosc
// zastapila approvera z CODEOWNERS, wiec nie moze zalezec od jednej
// warstwy.
func (s *Server) OntologyApprove(ctx context.Context, req *clinicalv1.OntologyTransitionRequest) (*clinicalv1.OntologyVersion, error) {
	return s.ontologyTransition(ctx, req, ontologyTransition{
		event: "ontology_approved",
		from:  "ready_for_review",
		preflight: func(ctx context.Context, id, actor uuid.UUID) error {
			var createdBy uuid.UUID
			var st, ver string
			var modID uuid.UUID
			if err := s.ontologyPool.QueryRow(ctx, sqlOntologyLockVersion, id).
				Scan(&st, &createdBy, &modID, &ver); err != nil {
				if errors.Is(err, pgx.ErrNoRows) {
					return status.Error(codes.NotFound, "ontology version not found")
				}
				return status.Error(codes.Internal, "read version")
			}
			if createdBy == actor {
				return status.Error(codes.PermissionDenied,
					"wersji nie zatwierdza jej autor — przeglad wymaga drugiej pary oczu")
			}
			return nil
		},
		exec: func(ctx context.Context, id, actor uuid.UUID, note string) (int64, error) {
			return s.ontologyPool.Exec(ctx, sqlOntologyApprove, id, actor, note)
		},
	})
}

// OntologyReject: ready_for_review -> draft, z uzasadnieniem.
func (s *Server) OntologyReject(ctx context.Context, req *clinicalv1.OntologyTransitionRequest) (*clinicalv1.OntologyVersion, error) {
	return s.ontologyTransition(ctx, req, ontologyTransition{
		event: "ontology_rejected",
		from:  "ready_for_review",
		exec: func(ctx context.Context, id, actor uuid.UUID, note string) (int64, error) {
			return s.ontologyPool.Exec(ctx, sqlOntologyReject, id, note)
		},
	})
}

// OntologyActivateVersion wskazuje wersje serwowana na produkcji.
//
// WYLACZNIE SUPERWIZOR_ADMIN. To jest ta operacja, ktora odroznia
// "tresc jest merytorycznie w porzadku" (kompetencja ONTOLOGY_EDITOR) od
// "tym generujemy raporty dla realnych klientow". Status != live.
//
// Zielony benchmark jest druga bramka i wejdzie z F3 — dzis nie ma
// jeszcze zlotego zestawu, wiec nie ma czego sprawdzac. Miejsce
// oznaczone, zeby aktywacja nie zostala uznana za domknieta.
func (s *Server) OntologyActivateVersion(ctx context.Context, req *clinicalv1.OntologyTransitionRequest) (*clinicalv1.OntologyVersion, error) {
	if err := requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}
	actor, err := actorFromContext(ctx)
	if err != nil {
		return nil, err
	}
	id, err := uuid.Parse(req.GetVersionId())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "version_id must be a UUID")
	}
	note, err := requireNote(req.GetNote())
	if err != nil {
		return nil, err
	}

	// TODO(F3): druga bramka — ostatni benchmark tej pary (ontologia,
	// prompty) musi byc zielony. Bez zlotego zestawu (T9) nie ma czego
	// odpytac; do tego czasu aktywacje chroni wylacznie status approved
	// i rola admina.
	n, err := s.ontologyPool.Exec(ctx, sqlOntologyActivate, id)
	if err != nil {
		slog.ErrorContext(ctx, "ontology.activate", "error", err, "version_id", id)
		return nil, status.Error(codes.Internal, "activate version")
	}
	if n == 0 {
		return nil, s.explainNoTransition(ctx, id, "approved")
	}

	out, err := s.loadOntologyVersion(ctx, id)
	if err != nil {
		return nil, err
	}
	s.trackOntologyEvent(ctx, "ontology_activated", actor, out, map[string]any{"note": note})
	slog.InfoContext(ctx, "ontology.activated",
		"version_id", id, "modality_id", out.GetModalityId(),
		"version", out.GetVersion(), "actor", actor)
	return out, nil
}

// ── wspolny szkielet przejscia ──

type ontologyTransition struct {
	event     string
	from      string
	preflight func(ctx context.Context, id, actor uuid.UUID) error
	exec      func(ctx context.Context, id, actor uuid.UUID, note string) (int64, error)
}

func (s *Server) ontologyTransition(ctx context.Context, req *clinicalv1.OntologyTransitionRequest, t ontologyTransition) (*clinicalv1.OntologyVersion, error) {
	if err := requireOntologyEditor(ctx); err != nil {
		return nil, err
	}
	actor, err := actorFromContext(ctx)
	if err != nil {
		return nil, err
	}
	id, err := uuid.Parse(req.GetVersionId())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "version_id must be a UUID")
	}
	note, err := requireNote(req.GetNote())
	if err != nil {
		return nil, err
	}
	if t.preflight != nil {
		if err := t.preflight(ctx, id, actor); err != nil {
			return nil, err
		}
	}
	n, err := t.exec(ctx, id, actor, note)
	if err != nil {
		slog.ErrorContext(ctx, "ontology.transition", "error", err, "event", t.event)
		return nil, status.Error(codes.Internal, t.event)
	}
	if n == 0 {
		return nil, s.explainNoTransition(ctx, id, t.from)
	}
	out, err := s.loadOntologyVersion(ctx, id)
	if err != nil {
		return nil, err
	}
	s.trackOntologyEvent(ctx, t.event, actor, out, nil)
	return out, nil
}

// explainNoTransition zamienia "zero wierszy" w komunikat, z ktorego
// wiadomo, co zrobic.
//
// Bez tego kazde nieudane przejscie wygladalo by tak samo, a przyczyny
// sa rozne: zly status, nieistniejaca wersja, proba zatwierdzenia
// wlasnej pracy. Autor w Studio ma zobaczyc ktora.
func (s *Server) explainNoTransition(ctx context.Context, id uuid.UUID, wantStatus string) error {
	var st, ver string
	var createdBy, modID uuid.UUID
	if err := s.ontologyPool.QueryRow(ctx, sqlOntologyLockVersion, id).
		Scan(&st, &createdBy, &modID, &ver); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return status.Error(codes.NotFound, "ontology version not found")
		}
		return status.Error(codes.Internal, "read version")
	}
	if st != wantStatus {
		return status.Errorf(codes.FailedPrecondition,
			"wersja ma status %q, operacja wymaga %q", st, wantStatus)
	}
	// Status sie zgadza, a wiersz i tak nie zostal zmieniony — jedyny
	// pozostaly warunek w WHERE to four-eyes.
	return status.Error(codes.PermissionDenied,
		"wersji nie zatwierdza jej autor — przeglad wymaga drugiej pary oczu")
}

func (s *Server) trackOntologyEvent(ctx context.Context, name string, actor uuid.UUID, v *clinicalv1.OntologyVersion, extra map[string]any) {
	props := ontologyAuditProps(v, extra)
	props["actor_id"] = actor.String()
	s.trackChatEvent(ctx, name, props)
}
