package grpc

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
)

// Raporty eksperymentalne (plan 16 §2.5).
//
// Powstaja na ontologii BEZ autoryzacji ekspertow, zeby petla
// autoryzacyjna miala na czym pracowac: nikt nie kalibruje `values` ani
// `min_evidence` na sucho, a bez ogladania wynikow na prawdziwych
// transkryptach ekspert nie ma czego zatwierdzac.
//
// Bramka chroni RAPORT PRODUKCYJNY, nie zabrania patrzec na szkic.

// GenerateExperimentalReport zamawia raport eksperymentalny.
//
// Zwraca natychmiast: sama generacja idzie tym samym potokiem co
// produkcyjna (llm-worker na transcript.completed), rozni sie wylacznie
// atrybutami komunikatu. To NIE jest optymalizacja — gdyby raport
// eksperymentalny mial osobna sciezke generacji, przestal by byc
// eksperymentem na tym samym potoku i strailby caly sens.
func (s *Server) GenerateExperimentalReport(ctx context.Context,
	req *clinicalv1.GenerateExperimentalReportRequest) (
	*clinicalv1.GenerateExperimentalReportResponse, error) {

	if s.ontologyPool == nil || s.config == nil {
		return nil, status.Error(codes.Unavailable, "tryb eksperymentalny nie jest podpiety")
	}
	sessionID, err := uuid.Parse(req.SessionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid session_id")
	}
	therapistID, err := s.therapistFromCtx(ctx)
	if err != nil {
		return nil, err
	}

	// Wlasciciel sesji, modalnosc kartoteki i transkrypcja — jednym
	// zapytaniem, bo kazde z nich moze zablokowac zamowienie i nie ma
	// sensu pytac o kolejne po odmowie.
	var (
		ownerID      uuid.UUID
		orgID        *uuid.UUID
		modalityCode string
		transcriptID *uuid.UUID
	)
	err = s.ontologyPool.QueryRow(ctx, `
		SELECT s.therapist_id, u.organization_id, m.system_code,
		       (SELECT t.id FROM transcripts t WHERE t.session_id = s.id
		         ORDER BY t.created_at DESC LIMIT 1)
		  FROM sessions s
		  JOIN users u ON u.id = s.therapist_id
		  JOIN patient_files pf ON pf.id = s.patient_file_id
		  JOIN modalities m ON m.id = pf.modality_id
		 WHERE s.id = $1 AND s.deleted_at IS NULL`, sessionID).
		Scan(&ownerID, &orgID, &modalityCode, &transcriptID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "not found")
	}
	if err := s.requireTherapistDataAccess(ctx, ownerID); err != nil {
		return nil, err
	}
	if transcriptID == nil {
		// Bez transkrypcji nie ma materialu. To NIE jest blad przejsciowy:
		// sesja bez transkrypcji nie dorobi sie jej przez ponowienie.
		return nil, status.Error(codes.FailedPrecondition,
			"sesja nie ma transkrypcji — nie ma z czego zbudowac raportu")
	}

	var org uuid.UUID
	if orgID != nil {
		org = *orgID
	}
	if !s.config.ExperimentalReportsEnabled(ctx, org) {
		return nil, status.Error(codes.PermissionDenied,
			"tryb eksperymentalny nie jest wlaczony dla tej organizacji")
	}

	limit := s.config.ExperimentalDailyLimit(ctx, org)
	uzyte, err := s.experimentalUsedToday(ctx, therapistID)
	if err != nil {
		// Nieznany licznik to NIE jest zgoda. Potok wieloetapowy na Pro
		// jest drogi i awaria odczytu nie moze go otwierac.
		return nil, status.Error(codes.Unavailable, "nie udalo sie odczytac limitu")
	}
	if uzyte >= limit {
		return nil, status.Error(codes.ResourceExhausted,
			fmt.Sprintf("dobowy limit raportow eksperymentalnych wyczerpany (%d)", limit))
	}

	kod := strings.ToUpper(strings.TrimSpace(req.ModalityCode))
	if kod == "" {
		kod = modalityCode
	}
	versionID, err := s.resolveExperimentalVersion(ctx, kod, req.OntologyVersionId)
	if err != nil {
		return nil, err
	}

	origin := "on_demand"
	requestID, err := s.insertExperimentalRequest(ctx, therapistID, sessionID, kod, versionID, origin)
	if err != nil {
		return nil, status.Error(codes.Internal, "nie udalo sie zapisac zamowienia")
	}

	if s.pubsub != nil {
		if perr := s.pubsub.PublishExperimentalReportRequested(ctx, ExperimentalReportRequest{
			SessionID:         sessionID.String(),
			TranscriptID:      transcriptID.String(),
			RequestID:         requestID.String(),
			ModalityCode:      kod,
			OntologyVersionID: versionID,
			RequestedBy:       therapistID.String(),
		}); perr != nil {
			// Zamowienie juz sie policzylo do limitu i tak ma zostac:
			// inaczej nieudana publikacja dawalaby darmowa probe przy
			// kazdym ponowieniu.
			return nil, status.Error(codes.Unavailable, "nie udalo sie zlecic generacji")
		}
	}

	return &clinicalv1.GenerateExperimentalReportResponse{
		RequestId:      requestID.String(),
		RemainingToday: int32(limit - uzyte - 1),
	}, nil
}

// experimentalUsedToday liczy zamowienia terapeuty z biezacej doby.
//
// Liczone po ZAMOWIENIACH, nie po raportach: wiersz w `reports` powstaje
// dopiero po generacji, wiec licznik po nim przepuscilby dziesiec
// zamowien zlozonych, zanim skonczy sie pierwsze.
//
// Nieudane generacje TEZ sie licza — kosztowaly wywolania modelu.
func (s *Server) experimentalUsedToday(ctx context.Context, therapistID uuid.UUID) (int64, error) {
	var n int64
	// skip_reason IS NULL — pominiecie nie zuzywa limitu (migracja 000096).
	// Inaczej odmowa z powodu wyczerpanego limitu sama zuzywalaby limit.
	err := s.ontologyPool.QueryRow(ctx, `
		SELECT count(*) FROM experimental_report_requests
		 WHERE therapist_id = $1 AND created_at >= date_trunc('day', now())
		   AND skip_reason IS NULL`,
		therapistID).Scan(&n)
	return n, err
}

// resolveExperimentalVersion wybiera wersje ontologii dla zamowienia.
//
// Puste zadanie = najnowsza wersja modalnosci, TAKZE `draft`. To jest
// jedyna bramka, ktora ten tryb omija.
func (s *Server) resolveExperimentalVersion(ctx context.Context, modalityCode, wanted string) (string, error) {
	if wanted != "" {
		if _, err := uuid.Parse(wanted); err != nil {
			return "", status.Error(codes.InvalidArgument, "invalid ontology_version_id")
		}
		var exists bool
		err := s.ontologyPool.QueryRow(ctx, `
			SELECT EXISTS(
				SELECT 1 FROM ontology_versions ov
				  JOIN modalities m ON m.id = ov.modality_id
				 WHERE ov.id = $1 AND m.system_code = $2)`, wanted, modalityCode).Scan(&exists)
		if err != nil || !exists {
			return "", status.Error(codes.NotFound,
				"wskazana wersja ontologii nie nalezy do tej modalnosci")
		}
		return wanted, nil
	}

	var id uuid.UUID
	err := s.ontologyPool.QueryRow(ctx, `
		SELECT ov.id FROM ontology_versions ov
		  JOIN modalities m ON m.id = ov.modality_id
		 WHERE m.system_code = $1
		 ORDER BY ov.created_at DESC LIMIT 1`, modalityCode).Scan(&id)
	if err != nil {
		return "", status.Error(codes.FailedPrecondition,
			fmt.Sprintf("modalnosc %s nie ma zadnej wersji ontologii", modalityCode))
	}
	return id.String(), nil
}

func (s *Server) insertExperimentalRequest(ctx context.Context, therapistID, sessionID uuid.UUID,
	modalityCode, versionID, origin string) (uuid.UUID, error) {
	// Wersja idzie jako uuid.UUID, nie string: kolumna jest typu UUID, a
	// przekazanie tekstu opiera sie na niejawnej konwersji sterownika.
	// Dziala, dopoki dziala — i milczy, gdy przestanie.
	vid, err := uuid.Parse(versionID)
	if err != nil {
		return uuid.Nil, fmt.Errorf("nieprawidlowa wersja ontologii: %w", err)
	}
	var id uuid.UUID
	if err := s.ontologyPool.QueryRow(ctx, `
		INSERT INTO experimental_report_requests
		       (therapist_id, session_id, modality_code, ontology_version_id, origin)
		VALUES ($1, $2, $3, $4, $5) RETURNING id`,
		therapistID, sessionID, modalityCode, vid, origin).Scan(&id); err != nil {
		return uuid.Nil, errors.New("insert zamowienia: " + err.Error())
	}
	return id, nil
}
