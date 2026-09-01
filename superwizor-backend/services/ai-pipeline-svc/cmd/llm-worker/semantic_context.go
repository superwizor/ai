package llmworker

// Wyszukiwanie semantyczne w kontekscie miedzysesyjnym (F7b-2, dok. 65 §5.2).
//
// ══ Rozszerzacz, nie zamiennik ══
//
// Okno deterministyczne (F7a) zostaje bramka podstawowa i dziala ZAWSZE.
// Semantyka dokłada wylacznie to, czego okno z definicji nie widzi:
// ustalenie z sesji trzeciej, ktore wraca w dziewietnastej. Kolejnosc
// jest wazna — gdyby semantyka byla jedynym kanalem, jeden zly prog
// odcinalby caly kontekst po cichu.
//
// ══ Za flaga organizacji ══
//
// Okno da sie odtworzyc z parametrow (data, W). Doboru sasiadow w
// przestrzeni wektorowej — nie. Dopoki nie ma zmierzonej powtarzalnosci
// (F7b-4), niedeterministyczna bramka nie ma prawa decydowac o tresci
// raportu klinicznego bez jawnej zgody organizacji.
//
// ══ Czym pytamy ══
//
// Wektorem streszczenia sesji i jej tematow z call-1. Trzy powody:
// powstaja PRZED potokiem (wiec nie trzeba przebudowywac Run), opisuja
// dokladnie te sesje (czyli to, o co pytamy), i sa juz
// spseudonimizowane (docs/41) — do embeddingu nie idzie material
// surowy.

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/pkg/ontology"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/ontopipe"
)

const (
	// kSemantyczne to liczba sasiadow branych pod uwage. Osiem: tyle,
	// zeby watek sprzed miesiecy mial szanse wrocic, i na tyle malo, by
	// blok ustalen nie przestal byc czytelny dla modelu.
	kSemantyczne = 8
	// progPodobienstwa odcina szum. Wartosc STARTOWA, do kalibracji na
	// benchmarku (F7b-4) — dlatego kazdy odrzucony sasiad jest liczony,
	// a kazdy przyjety zapisuje swoje podobienstwo. Bez tych liczb
	// „zero trafien" bylo by nieodroznialne od „prog za wysoki".
	progPodobienstwa = 0.55
	// Limit sesji-zrodel: watek moze wracac przez lata, ale raport
	// czyta sie dzis. Bez tego jeden konstrukt sciagalby cala historie.
	maxSesjiSemantycznych = 6
)

// dolaczSemantyczne rozszerza kontekst o ustalenia spoza okna.
//
// Zwraca kontekst nietkniety, gdy flaga jest wylaczona, gdy nie ma
// czym pytac albo gdy indeks nic nie zwrocil — brak trafien jest
// normalnym wynikiem, nie awaria.
func dolaczSemantyczne(ctx context.Context, logger *slog.Logger, session *SessionContext,
	past *ontopipe.PastContext, streszczenie string, tematy []string,
	klasaPotoku string, eksperymentalny bool) *ontopipe.PastContext {

	if past == nil || dbPool == nil {
		return past
	}
	if pipelineConfig == nil {
		return past
	}
	if !semantykaWlaczona(ctx, session.OrganizationID, eksperymentalny) {
		return past
	}
	past.Stats.SemanticEnabled = true

	kwerenda := strings.TrimSpace(streszczenie)
	if len(tematy) > 0 {
		kwerenda = strings.TrimSpace(kwerenda + " " + strings.Join(tematy, ", "))
	}
	if kwerenda == "" {
		logger.Info("semantyka: brak streszczenia i tematow — pomijam")
		return past
	}

	wektor, err := generateEmbedding(ctx, kwerenda)
	if err != nil {
		// Wzmocnienie, nie bramka: brak wektora oznacza kontekst
		// wylacznie z okna, czyli zachowanie sprzed F7b.
		logger.Warn("semantyka: wektor zapytania", "error", err)
		return past
	}

	juzMamy := map[uuid.UUID]bool{}
	for _, c := range past.Claims {
		juzMamy[c.ID] = true
	}

	// Semantyka doklada WYLACZNIE to, czego okno nie widzi (docs/65
	// §5.2) — wiec sesje JUZ obecne w oknie sa wykluczone z retrievalu
	// razem z biezaca. Do 2026-09-01 wykluczana byla tylko biezaca:
	// indeks niesie wpisy z KAZDEGO przebiegu, wiec starszy raport
	// sesji okiennej wracal kanalem semantycznym jako 8 "trafien" o
	// innych ID i tej samej tresci (kanarek 8051c235 — pierwsze uzycie
	// sekcji audytu po naprawie okna). Dedupe po ID tego nie lapie z
	// definicji; wykluczenie sesji lapie z definicji.
	wykluczone := []uuid.UUID{session.ID}
	widzianeSesje := map[uuid.UUID]bool{session.ID: true}
	for _, c := range past.Claims {
		if !widzianeSesje[c.SessionID] {
			widzianeSesje[c.SessionID] = true
			wykluczone = append(wykluczone, c.SessionID)
		}
	}

	rows, err := dbPool.Query(ctx, `
		SELECT i.source_claim_id, i.session_id, i.session_at, i.construct_id,
		       1 - (i.embedding <=> $1::vector) AS podobienstwo
		  FROM report_inference_index i
		 WHERE i.patient_file_id = $2
		   AND i.kind = 'claim'
		   AND i.pipeline_version = $3
		   AND i.embedding_model = $4
		   AND i.session_id <> ALL($5)
		   AND i.source_claim_id IS NOT NULL
		 ORDER BY i.embedding <=> $1::vector, i.session_at DESC, i.id
		 LIMIT $6`,
		vectorToString(wektor), session.PatientFileID, klasaPotoku,
		embeddingModel, wykluczone, kSemantyczne*3)
	if err != nil {
		logger.Warn("semantyka: zapytanie do indeksu", "error", err)
		return past
	}
	defer rows.Close()

	type trafienie struct {
		claimID      uuid.UUID
		sesja        uuid.UUID
		data         time.Time
		construct    string
		podobienstwo float64
	}
	var kandydaci []trafienie
	ponizejProgu := 0
	for rows.Next() {
		var t trafienie
		var cid *uuid.UUID
		if err := rows.Scan(&cid, &t.sesja, &t.data, &t.construct, &t.podobienstwo); err != nil {
			logger.Warn("semantyka: odczyt trafienia", "error", err)
			continue
		}
		if cid == nil {
			continue
		}
		t.claimID = *cid
		if t.podobienstwo < progPodobienstwa {
			ponizejProgu++
			continue
		}
		// Twierdzenie juz pokazane oknem nie jest nowa informacja.
		if juzMamy[t.claimID] {
			continue
		}
		kandydaci = append(kandydaci, t)
	}
	past.Stats.SemanticBelowThreshold = ponizejProgu

	// Limit sesji-zrodel liczony PO progu: inaczej odrzucony sasiad
	// zajmowalby miejsce sesji, ktora do raportu i tak nie wejdzie.
	sesje := map[uuid.UUID]bool{}
	var wybrane []trafienie
	for _, t := range kandydaci {
		if len(wybrane) == kSemantyczne {
			break
		}
		if !sesje[t.sesja] && len(sesje) >= maxSesjiSemantycznych {
			continue
		}
		sesje[t.sesja] = true
		wybrane = append(wybrane, t)
	}
	if len(wybrane) == 0 {
		logger.Info("semantyka: brak trafien nad progiem",
			"ponizej_progu", ponizejProgu, "prog", progPodobienstwa)
		return past
	}

	idClaims := make([]uuid.UUID, 0, len(wybrane))
	dataSesji := map[uuid.UUID]time.Time{}
	podobienstwa := map[uuid.UUID]float64{}
	for _, t := range wybrane {
		idClaims = append(idClaims, t.claimID)
		dataSesji[t.sesja] = t.data
		podobienstwa[t.claimID] = t.podobienstwo
	}

	claims, err := wczytajTwierdzeniaPoID(ctx, idClaims, dataSesji)
	if err != nil {
		logger.Warn("semantyka: wczytanie twierdzen", "error", err)
		return past
	}
	spany, poClaimach, err := wczytajSpanyDowodowe(ctx, claims, dataSesji)
	if err != nil {
		logger.Warn("semantyka: wczytanie spanow", "error", err)
		return past
	}

	dodane := 0
	znaneSpany := map[string]bool{}
	for _, sp := range past.Spans {
		znaneSpany[sp.Addr] = true
	}
	for i := range claims {
		claims[i].Evidence = poClaimach[claims[i].ID]
		if len(claims[i].Evidence) == 0 {
			// Ustalenie bez ani jednego czytelnego cytatu nie ma czego
			// wniesc — ta sama zasada co w oknie.
			continue
		}
		claims[i].Channel = "semantic"
		claims[i].Similarity = podobienstwa[claims[i].ID]
		past.Claims = append(past.Claims, claims[i])
		dodane++
	}
	for _, sp := range spany {
		if znaneSpany[sp.Addr] {
			continue
		}
		sp.Channel = "semantic"
		past.Spans = append(past.Spans, sp)
	}

	past.Stats.SemanticFound = dodane
	past.Stats.ClaimsShown = len(past.Claims)
	past.Stats.SpansShown = len(past.Spans)
	logger.Info("semantyka: kontekst rozszerzony",
		"dodane_ustalenia", dodane, "ponizej_progu", ponizejProgu,
		"sesji_zrodlowych", len(sesje), "prog", progPodobienstwa)
	return past
}

// semantykaWlaczona rozstrzyga, czy przebieg moze pytac indeks.
//
// ══ Dwie drogi, celowo nierowne ══
//
// 1. Jawna flaga organizacji — obowiazuje ZAWSZE, takze dla raportow
//    produkcyjnych. To jest decyzja o materiale klinicznym i musi byc
//    podjeta przez czlowieka.
//
// 2. Domyslnie WLACZONA na powierzchni eksperymentalnej: organizacja,
//    ktora ma raporty eksperymentalne, ma tez wyszukiwanie semantyczne
//    w TYCH raportach, bez osobnego wpisu w konfiguracji.
//
// Dlaczego druga droga jest bezpieczna, a pierwsza nadal potrzebna:
// raport eksperymentalny z definicji NIE SLUZY do pracy klinicznej —
// powstaje na ontologii bez autoryzacji ekspertow wlasnie po to, zeby
// bylo co kalibrowac. Organizacja, ktora go wlaczyla, juz zgodzila sie
// ogladac wyniki niezautoryzowanego wnioskowania; dolozenie tam
// niedeterministycznej selekcji nie zmienia charakteru tej zgody.
// Raport produkcyjny to co innego i zostaje przy jawnej decyzji.
//
// Bez tego rozroznienia byloby odwrotnie do intencji: kazda nowa
// organizacja eksperymentalna wymagalaby PAMIETANIA o drugim wpisie,
// a zapomniany wpis wygladalby jak „semantyka nic nie znajduje".
func semantykaWlaczona(ctx context.Context, org uuid.UUID, eksperymentalny bool) bool {
	if pipelineConfig.SemanticContextEnabled(ctx, org) {
		return true
	}
	return eksperymentalny && pipelineConfig.ExperimentalReportsEnabled(ctx, org)
}

// wczytajTwierdzeniaPoID czyta wskazane twierdzenia razem z data ich
// sesji. Klasa potoku jest juz rozstrzygnieta przez indeks, wiec tutaj
// nie powtarzamy filtra — powtorzenie sugerowaloby, ze indeks moze
// zwrocic obca klase.
func wczytajTwierdzeniaPoID(ctx context.Context, idClaims []uuid.UUID,
	dataSesji map[uuid.UUID]time.Time) ([]ontopipe.PastClaim, error) {

	rows, err := dbPool.Query(ctx, `
		SELECT c.id, r.session_id, c.construct_id, c.categories,
		       c.epistemic_status, COALESCE(c.confidence, 0)::float8
		  FROM report_claims c
		  JOIN reports r ON r.id = c.report_id
		 WHERE c.id = ANY($1)`, idClaims)
	if err != nil {
		return nil, fmt.Errorf("twierdzenia po id: %w", err)
	}
	defer rows.Close()

	var out []ontopipe.PastClaim
	for rows.Next() {
		var c ontopipe.PastClaim
		var status string
		if err := rows.Scan(&c.ID, &c.SessionID, &c.ConstructID, &c.Categories,
			&status, &c.Confidence); err != nil {
			return nil, err
		}
		c.Status = ontology.EpistemicStatus(status)
		c.SessionDate = dataSesji[c.SessionID]
		out = append(out, c)
	}
	return out, rows.Err()
}
