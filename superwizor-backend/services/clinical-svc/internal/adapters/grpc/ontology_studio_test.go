package grpc

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
)

// ── atrapy ──

type atrapaOntologyPool struct {
	execN       int64
	execErr     error
	ostatniSQL  string
	ostatniArgs []any
}

func (p *atrapaOntologyPool) Exec(_ context.Context, sql string, args ...any) (int64, error) {
	p.ostatniSQL, p.ostatniArgs = sql, args
	return p.execN, p.execErr
}
func (p *atrapaOntologyPool) Query(context.Context, string, ...any) (OntologyRows, error) {
	return nil, errors.New("nieuzywane w tym tescie")
}
func (p *atrapaOntologyPool) QueryRow(context.Context, string, ...any) OntologyRow {
	return atrapaWiersza{err: errors.New("nieuzywane w tym tescie")}
}

type atrapaWiersza struct{ err error }

func (r atrapaWiersza) Scan(...any) error { return r.err }

func ctxRola(rola string) context.Context {
	ctx := context.WithValue(context.Background(), UserRoleKey, rola)
	return context.WithValue(ctx, UserIDKey, uuid.New().String())
}

func kod(err error) codes.Code { return status.Code(err) }

// ── rozdzial rol ──

// TestRozdzialRol to sedno kontraktu Studia (plan 16 sekcja 4.1):
// ONTOLOGY_EDITOR odpowiada za TRESC, SUPERWIZOR_ADMIN za to, co
// generuje raporty. Aktywacja jest jedyna operacja, ktorej edytor nie ma.
func TestRozdzialRol(t *testing.T) {
	srv := &Server{}
	srv = srv.WithOntologyStudio(&atrapaOntologyPool{})

	t.Run("edytor NIE aktywuje na produkcji", func(t *testing.T) {
		_, err := srv.OntologyActivateVersion(ctxRola("ONTOLOGY_EDITOR"),
			&clinicalv1.OntologyTransitionRequest{
				VersionId: uuid.New().String(), Note: "probuje aktywowac"})
		if kod(err) != codes.PermissionDenied {
			t.Fatalf("kod = %v, oczekiwano PermissionDenied — aktywacja nalezy do admina", kod(err))
		}
	})

	t.Run("terapeuta nie ma dostepu do Studia", func(t *testing.T) {
		_, err := srv.OntologyLint(ctxRola("THERAPIST"),
			&clinicalv1.OntologyLintRequest{ContentYaml: "modality: x"})
		if kod(err) != codes.PermissionDenied {
			t.Fatalf("kod = %v, oczekiwano PermissionDenied", kod(err))
		}
	})

	t.Run("brak roli w kontekscie konczy sie Unauthenticated", func(t *testing.T) {
		_, err := srv.OntologyLint(context.Background(),
			&clinicalv1.OntologyLintRequest{ContentYaml: "modality: x"})
		if kod(err) != codes.Unauthenticated {
			t.Fatalf("kod = %v, oczekiwano Unauthenticated", kod(err))
		}
	})

	t.Run("admin jest nadzbiorem edytora", func(t *testing.T) {
		// Lint jest bezpiecznym dowodem: nie dotyka bazy.
		if _, err := srv.OntologyLint(ctxRola("SUPERWIZOR_ADMIN"),
			&clinicalv1.OntologyLintRequest{ContentYaml: "modality: x"}); err != nil {
			t.Fatalf("admin odrzucony w Studiu: %v", err)
		}
	})
}

// ── walidacja tresci ──

const poprawnaOntologia = `
modality: test
version: 1.0.0
constructs:
  alpha:
    label_pl: "Alfa"
    values: ["a"]
    min_evidence: {spans: 1}
epistemic_statuses: [observation, interpretation, theoretical_hypothesis,
                     open_question, insufficient_data, no_fit]
etiology_policy: strict
therapist_boundary: strict
`

func TestLintZwracaKompletProblemow(t *testing.T) {
	srv := (&Server{}).WithOntologyStudio(&atrapaOntologyPool{})

	// Autor ma zobaczyc PELNA liste, nie pierwszy blad — inaczej
	// poprawianie ontologii to seria zgadywanek.
	zly := strings.Replace(poprawnaOntologia,
		"epistemic_statuses: [observation, interpretation, theoretical_hypothesis,\n                     open_question, insufficient_data, no_fit]",
		"epistemic_statuses: [observation]", 1)
	zly = strings.Replace(zly, "etiology_policy: strict", "etiology_policy: lenient", 1)

	resp, err := srv.OntologyLint(ctxRola("ONTOLOGY_EDITOR"),
		&clinicalv1.OntologyLintRequest{ContentYaml: zly})
	if err != nil {
		t.Fatalf("lint zwrocil blad zamiast listy problemow: %v", err)
	}
	if len(resp.GetProblems()) < 3 {
		t.Errorf("problemow = %d, oczekiwano co najmniej 3 (2 statusy + polityka): %v",
			len(resp.GetProblems()), resp.GetProblems())
	}
}

func TestLintPoprawnejTresciNieZglaszaNic(t *testing.T) {
	srv := (&Server{}).WithOntologyStudio(&atrapaOntologyPool{})
	resp, err := srv.OntologyLint(ctxRola("ONTOLOGY_EDITOR"),
		&clinicalv1.OntologyLintRequest{ContentYaml: poprawnaOntologia})
	if err != nil {
		t.Fatalf("lint: %v", err)
	}
	if len(resp.GetProblems()) != 0 {
		t.Errorf("problemy: %v", resp.GetProblems())
	}
	if resp.GetConstructCount() != 1 {
		t.Errorf("construct_count = %d, oczekiwano 1", resp.GetConstructCount())
	}
}

// TestTrescNieMozeDeklarowacAutoryzacji — gdyby YAML mogl ustawic
// approved_by, autor obszedlby przeglad jednym polem. Autoryzacja zyje w
// statusie wiersza i w four-eyes, nie w tresci.
func TestTrescNieMozeDeklarowacAutoryzacji(t *testing.T) {
	zApproved := strings.Replace(poprawnaOntologia, "version: 1.0.0",
		"version: 1.0.0\napproved_by: [\"ja-sam\"]", 1)

	if _, err := validateOntologyPayload(zApproved); kod(err) != codes.InvalidArgument {
		t.Errorf("kod = %v, oczekiwano InvalidArgument", kod(err))
	}

	srv := (&Server{}).WithOntologyStudio(&atrapaOntologyPool{})
	resp, err := srv.OntologyLint(ctxRola("ONTOLOGY_EDITOR"),
		&clinicalv1.OntologyLintRequest{ContentYaml: zApproved})
	if err != nil {
		t.Fatalf("lint: %v", err)
	}
	if len(resp.GetProblems()) == 0 {
		t.Error("lint przepuscil approved_by w tresci")
	}
}

// TestNotatkaJestWymagana — wpis audytowy czyta nastepny dyzurny;
// "ok" nie jest wyjasnieniem.
func TestNotatkaJestWymagana(t *testing.T) {
	srv := (&Server{}).WithOntologyStudio(&atrapaOntologyPool{})
	ctx := ctxRola("ONTOLOGY_EDITOR")

	_, err := srv.OntologyCreateDraft(ctx, &clinicalv1.OntologyCreateDraftRequest{
		ModalityId:  uuid.New().String(),
		ContentYaml: poprawnaOntologia,
		ChangeNote:  "ok",
	})
	if kod(err) != codes.InvalidArgument {
		t.Errorf("kod = %v, oczekiwano InvalidArgument dla krotkiej notatki", kod(err))
	}
}

// TestDwaZrodlaTresciSaOdrzucane — content_yaml razem z
// copy_from_version_id to niejednoznacznosc, nie wygoda.
func TestDwaZrodlaTresciSaOdrzucane(t *testing.T) {
	srv := (&Server{}).WithOntologyStudio(&atrapaOntologyPool{})
	_, err := srv.OntologyCreateDraft(ctxRola("ONTOLOGY_EDITOR"),
		&clinicalv1.OntologyCreateDraftRequest{
			ModalityId:        uuid.New().String(),
			ContentYaml:       poprawnaOntologia,
			CopyFromVersionId: uuid.New().String(),
			ChangeNote:        "kopiuje i podaje tresc naraz",
		})
	if kod(err) != codes.InvalidArgument {
		t.Errorf("kod = %v, oczekiwano InvalidArgument", kod(err))
	}
}

// TestSemverMusiZgadzacSieZTrescia — lista w Studio pokazywalaby inna
// wersje, niz S2 dostanie w kontekscie.
func TestSemverMusiZgadzacSieZTrescia(t *testing.T) {
	srv := (&Server{}).WithOntologyStudio(&atrapaOntologyPool{})
	_, err := srv.OntologyCreateDraft(ctxRola("ONTOLOGY_EDITOR"),
		&clinicalv1.OntologyCreateDraftRequest{
			ModalityId:  uuid.New().String(),
			Version:     "2.0.0", // tresc mowi 1.0.0
			ContentYaml: poprawnaOntologia,
			ChangeNote:  "niezgodny semver",
		})
	if kod(err) != codes.InvalidArgument {
		t.Errorf("kod = %v, oczekiwano InvalidArgument", kod(err))
	}
}
