package llmworker

// Zasilanie semantycznego indeksu wnioskowania (F7b-1, dok. 65 §5.1).
//
// ══ Zasilamy teraz, konsumujemy pozniej ══
//
// Ten krok wylacznie ZAPISUJE. Retrieval przychodzi w F7b-2, za flaga
// organizacji. Kolejnosc jest celowa: indeks pusty w dniu wlaczenia
// wyszukiwania bylby bezuzyteczny, a jego zapelnianie wstecz wymagaloby
// przepuszczenia archiwum przez dzisiejszy model embeddingow — czyli
// wektorow, ktore udaja, ze powstaly wtedy.
//
// ══ Blad indeksowania NIE psuje raportu ══
//
// Indeks sluzy PRZYSZLYM przebiegom. Raport, ktory juz powstal i
// przeszedl walidacje, nie ma powodu paskudniec dlatego, ze nie udalo
// sie policzyc wektora. Ale cisza tez nie jest w porzadku: brak wierszy
// wygladalby pozniej jak brak historii, wiec porazka idzie do
// telemetrii pod wlasna nazwa.

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"golang.org/x/sync/errgroup"

	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/ontopipe"
)

// wpisIndeksu to jeden byt do zaindeksowania.
type wpisIndeksu struct {
	kind        string // 'claim' | 'hypothesis'
	itemRef     string
	constructID string
	status      string
	confidence  float64
	tekst       string
	claimID     *uuid.UUID
}

// zbierzWpisy sklada liste bytow do indeksu z wyniku potoku.
//
// Twierdzenia i hipotezy ida osobno i sa OZNACZONE — rozdzial poziomow
// (dok. 65 §N1) zaczyna sie tutaj, a nie dopiero w zapytaniu.
func zbierzWpisy(res ontopipe.Result, claimIDs []uuid.UUID) []wpisIndeksu {
	var out []wpisIndeksu

	for i, c := range res.Approved {
		tekst := strings.TrimSpace(c.Reasoning)
		if tekst == "" {
			// Bez uzasadnienia zostaje sama etykieta — za malo, zeby
			// wektor cokolwiek znaczyl. Pomijamy zamiast indeksowac szum.
			continue
		}
		if kat := strings.Join(c.Categories, ", "); kat != "" {
			tekst = kat + ": " + tekst
		}
		// Identyfikator twierdzenia powstaje przy ZAPISIE, wiec przychodzi
		// z zewnatrz, rownolegle do res.Approved. Jego brak nie jest
		// szczegolem: bez niego wiersz indeksu nie wskazuje twierdzenia,
		// a wyszukiwanie semantyczne (F7b-2) nie ma czego wczytac.
		var cid *uuid.UUID
		if i < len(claimIDs) {
			id := claimIDs[i]
			cid = &id
		}
		out = append(out, wpisIndeksu{
			kind: "claim",
			// Adresem jest pozycja w liscie zatwierdzonych — stabilna
			// w obrebie raportu, bo kolejnosc wynika z porzadku
			// konstruktow. Sluzy idempotencji zapisu.
			itemRef:     fmt.Sprintf("c%d", i),
			constructID: c.ConstructID,
			status:      string(c.Status),
			confidence:  c.Confidence,
			tekst:       tekst,
			claimID:     cid,
		})
	}

	for _, cr := range res.Constructsy() {
		for _, h := range cr.Hypotheses {
			tekst := strings.TrimSpace(h.Claim)
			if tekst == "" {
				continue
			}
			out = append(out, wpisIndeksu{
				kind:        "hypothesis",
				itemRef:     cr.ConstructID + "/" + h.ID,
				constructID: cr.ConstructID,
				status:      h.EpistemicStatus,
				confidence:  h.Confidence,
				tekst:       tekst,
			})
		}
	}
	return out
}

// indexInference liczy wektory i zapisuje je do report_inference_index.
func indexInference(ctx context.Context, logger *slog.Logger, session *SessionContext,
	reportID uuid.UUID, res ontopipe.Result, pipelineVersion string,
	claimIDs []uuid.UUID) {

	if dbPool == nil {
		return
	}
	wpisy := zbierzWpisy(res, claimIDs)
	if len(wpisy) == 0 {
		return
	}

	// Limit rownoleglosci jak przy pamieci RAG: Vertex znosi wiecej, ale
	// jeden raport nie ma prawa zjesc calego okna zadan.
	wektory := make([][]float32, len(wpisy))
	g, gctx := errgroup.WithContext(ctx)
	g.SetLimit(6)
	for i := range wpisy {
		i := i
		g.Go(func() error {
			v, err := generateEmbedding(gctx, wpisy[i].tekst)
			if err != nil {
				return fmt.Errorf("wektor %s/%s: %w", wpisy[i].kind, wpisy[i].itemRef, err)
			}
			wektory[i] = v
			return nil
		})
	}
	if err := g.Wait(); err != nil {
		logger.Warn("indeks wnioskowania: liczenie wektorow", "error", err,
			"session_id", session.ID)
		slog.InfoContext(ctx, "analytics", "ae", "inference_index_failed",
			"session_id", session.ID.String(), "etap", "embed")
		return
	}

	var sesjaData string
	if err := dbPool.QueryRow(ctx,
		`SELECT session_date::text FROM sessions WHERE id = $1`, session.ID).
		Scan(&sesjaData); err != nil {
		logger.Warn("indeks wnioskowania: data sesji", "error", err)
		return
	}

	zapisane := 0
	for i, w := range wpisy {
		ct, dek, err := crypto.Encrypt(ctx, []byte(w.tekst))
		if err != nil {
			logger.Warn("indeks wnioskowania: szyfrowanie", "error", err,
				"item_ref", w.itemRef)
			continue
		}
		if _, err := dbPool.Exec(ctx, `
			INSERT INTO report_inference_index (
			    patient_file_id, session_id, report_id, kind, source_claim_id,
			    item_ref, construct_id, epistemic_status, confidence,
			    pipeline_version, text_ciphertext, text_encrypted_dek,
			    embedding, embedding_model, session_at)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13::vector,$14,$15::date)
			ON CONFLICT (report_id, kind, item_ref) DO NOTHING`,
			session.PatientFileID, session.ID, reportID, w.kind, w.claimID,
			w.itemRef, w.constructID, w.status, w.confidence,
			pipelineVersion, ct, dek, vectorToString(wektory[i]),
			embeddingModel, sesjaData); err != nil {
			logger.Warn("indeks wnioskowania: zapis", "error", err,
				"item_ref", w.itemRef)
			slog.InfoContext(ctx, "analytics", "ae", "inference_index_failed",
				"session_id", session.ID.String(), "etap", "zapis")
			continue
		}
		zapisane++
	}

	logger.Info("indeks wnioskowania zasilony",
		"session_id", session.ID, "wpisow", zapisane, "z", len(wpisy),
		"model", embeddingModel, "klasa", pipelineVersion)
}
