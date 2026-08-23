package llmworker

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"cloud.google.com/go/pubsub/v2"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// Tryb eksperymentalny (plan 16 §2.5).
//
// PO CO: eksperci nie autoryzuja `values` ani `min_evidence` na sucho.
// Kalibracja wymaga ogladania, co potok S1-S5 realnie produkuje na
// prawdziwych transkryptach ZANIM ontologia dostanie `approved_by`. Bez
// tego petla F1 -> F2 nie ma na czym pracowac.
//
// CZYM RAPORT EKSPERYMENTALNY NIE JEST: nie zastepuje produkcyjnego, nie
// pojawia sie w panelu klienta, nie wchodzi do session.status_changed
// (zero powiadomien "Raport gotowy" — to lustro produkcyjne), nie jest
// materialem klinicznym.
//
// CZEGO NIE ZMIENIA: nic z warstwy bezpieczenstwa. Walidator dziedzinowy
// R1-R9, granica terapeuty R10, wylaczenie spanow ryzyka T22 i
// weryfikator wyjscia V1-V6 dzialaja identycznie jak w produkcji. To nie
// jest przedmiot eksperymentu, tylko jego WARUNEK — obchodzimy wylacznie
// bramke AKTYWNEJ wersji.

// PipelineExperimental stempluje raport eksperymentalny.
//
// Osobna wartosc, nie flaga obok `ontology_s1s5`: filtr statystyk
// (ReportsAvailable w czacie A2/A6) idzie po tej kolumnie, a warunek
// "potok ontologiczny ORAZ nie eksperymentalny" rozsypalby sie przy
// pierwszym zapytaniu, ktore o nim zapomni.
const PipelineExperimental = "ontology_s1s5_experimental"

// experimentalRequest to zamowienie odczytane z atrybutow zdarzenia.
type experimentalRequest struct {
	// RequestID wskazuje wiersz experimental_report_requests, ktory
	// policzyl sie juz do dobowego limitu w clinical-svc.
	RequestID uuid.UUID
	// ModalityOverride pozwala wygenerowac "raport CBT dla kartoteki
	// PPT". Puste = modalnosc kartoteki.
	ModalityOverride string
	// OntologyVersionID wskazuje KONKRETNA wersje, takze `draft`. Puste =
	// najnowsza wersja modalnosci.
	OntologyVersionID string
	RequestedBy       string
}

// experimentalFromAttributes czyta zamowienie z atrybutow Pub/Suba.
//
// Zwraca nil dla zwyklego przebiegu. Rozpoznanie idzie po JEDNYM
// atrybucie (`pipeline`), zeby nie dalo sie wpasc w tryb eksperymentalny
// przez czesciowo wypelniony komunikat.
func experimentalFromAttributes(attrs map[string]string) *experimentalRequest {
	if attrs["pipeline"] != "experimental" {
		return nil
	}
	req := &experimentalRequest{
		ModalityOverride:  strings.ToUpper(strings.TrimSpace(attrs["modality_override"])),
		OntologyVersionID: strings.TrimSpace(attrs["ontology_version_id"]),
		RequestedBy:       strings.TrimSpace(attrs["requested_by"]),
	}
	if id, err := uuid.Parse(strings.TrimSpace(attrs["request_id"])); err == nil {
		req.RequestID = id
	}
	return req
}

// loadExperimentalOntology wybiera wersje dla przebiegu eksperymentalnego.
//
// W przeciwienstwie do produkcji NIE pyta o active_ontology_version_id —
// to jest jedyna bramka, ktora ten tryb omija. Wersja moze byc `draft`,
// bo bez ogladania szkicu na prawdziwym materiale nie ma czego
// autoryzowac.
//
// Nadal jednak uzywamy ontology.Load, nie Parse: tresc, ktora nie
// przechodzi metaschematu, nie ma prawa wejsc do potoku niezaleznie od
// statusu. Szkic to co innego niz plik uszkodzony.
func loadExperimentalOntology(ctx context.Context, modalityID uuid.UUID, versionID string) (
	*ontology.Ontology, uuid.UUID, string, error) {

	var (
		id      uuid.UUID
		content string
		version string
		status  string
		err     error
	)
	if versionID != "" {
		vid, perr := uuid.Parse(versionID)
		if perr != nil {
			return nil, uuid.Nil, "", fmt.Errorf("nieprawidlowy identyfikator wersji: %w", perr)
		}
		err = dbPool.QueryRow(ctx, `
			SELECT id, content, version, status FROM ontology_versions
			 WHERE id = $1 AND modality_id = $2`, vid, modalityID).
			Scan(&id, &content, &version, &status)
	} else {
		// Najnowsza wersja modalnosci — dual-run bierze wlasnie ja, bo
		// ekspert kalibruje to, nad czym wlasnie pracuje.
		err = dbPool.QueryRow(ctx, `
			SELECT id, content, version, status FROM ontology_versions
			 WHERE modality_id = $1
			 ORDER BY created_at DESC LIMIT 1`, modalityID).
			Scan(&id, &content, &version, &status)
	}
	if err != nil {
		return nil, uuid.Nil, "", err
	}

	o, lerr := ontology.Load([]byte(content))
	if lerr != nil {
		return nil, id, version, fmt.Errorf("wersja %s (%s) nie przechodzi metaschematu: %w",
			version, status, lerr)
	}
	return o, id, version, nil
}

// resolveExperimentalModality tlumaczy kod modalnosci na jej wiersz.
//
// Zwraca identyfikator modalnosci, ktorej ontologia obsluzy przebieg.
// Kartoteka pozostaje nietknieta: nadpisanie dotyczy WYLACZNIE tego
// jednego raportu, bo porownanie miedzymodalnosciowe nie moze zmieniac
// prowadzenia kartoteki.
func resolveExperimentalModality(ctx context.Context, sc *SessionContext, code string) (uuid.UUID, string, error) {
	if code == "" || code == sc.SystemCode {
		return sc.ModalityID, sc.SystemCode, nil
	}
	var id uuid.UUID
	err := dbPool.QueryRow(ctx,
		`SELECT id FROM modalities WHERE system_code = $1`, code).Scan(&id)
	if err != nil {
		return uuid.Nil, "", fmt.Errorf("nieznany kod modalnosci %q: %w", code, err)
	}
	return id, code, nil
}

// linkExperimentalReport wiaze zamowienie z powstalym raportem.
//
// Best-effort: raport juz istnieje, a brak dowiazania psuje slad
// audytowy, nie artefakt. Zamowienie i tak policzylo sie do limitu w
// chwili zlozenia — i ma sie liczyc takze wtedy, gdy generacja padla,
// bo kosztowala wywolania modelu.
func linkExperimentalReport(ctx context.Context, requestID uuid.UUID, reportID string) error {
	if requestID == uuid.Nil {
		return nil
	}
	rid, err := uuid.Parse(reportID)
	if err != nil {
		return err
	}
	_, err = dbPool.Exec(ctx,
		`UPDATE experimental_report_requests SET report_id = $1 WHERE id = $2`, rid, requestID)
	return err
}

// experimentalBanner tworzy twarde oznaczenie na poczatku raportu.
//
// Baner jest czescia ARTEFAKTU, nie warstwy UI. Raport bywa kopiowany,
// eksportowany do PDF i ogladany poza aplikacja — oznaczenie, ktore zyje
// tylko w widoku, w tych sytuacjach nie istnieje. A to jest dokladnie
// sytuacja, w ktorej pomylenie eksperymentu z materialem klinicznym
// kosztuje najwiecej.
func experimentalBanner(modalityCode, ontologyVersion string) string {
	return fmt.Sprintf(
		"> **⚠ EKSPERYMENT — ontologia niezautoryzowana (szkic %s, modalność %s).**\n"+
			"> Ten raport powstał na wersji ontologii, której eksperci jeszcze nie "+
			"zatwierdzili. **Nie służy do pracy klinicznej.**\n"+
			"> Treść wygenerowana przez system sztucznej inteligencji (art. 50 AI Act).\n\n",
		ontologyVersion, modalityCode)
}

// publishExperimentalReady zawiadamia o gotowym raporcie eksperymentalnym.
//
// OSOBNY TEMAT, nie session.status_changed. Tamten strumien jest lustrem
// produkcyjnym: konsument na "done" wysyla push "Raport gotowy" i
// przestawia stan sesji w panelu klienta. Raport eksperymentalny nie jest
// materialem klinicznym i nie ma prawa uruchomic zadnej z tych rzeczy.
func publishExperimentalReady(ctx context.Context, sc *SessionContext, reportID string) error {
	if pubsubClient == nil {
		return nil
	}
	topic := pubsubClient.Publisher("report.experimental_ready")
	defer topic.Stop()

	payload, _ := json.Marshal(map[string]string{
		"session_id":   sc.ID.String(),
		"report_id":    reportID,
		"therapist_id": sc.TherapistID.String(),
	})
	res := topic.Publish(ctx, &pubsub.Message{
		Data: payload,
		Attributes: map[string]string{
			"event_type": "report.experimental_ready",
			"session_id": sc.ID.String(),
		},
	})
	_, err := res.Get(ctx)
	return err
}
