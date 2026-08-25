package llmworker

// S0 — ladowanie kontekstu miedzysesyjnego (plan F7a-2, dok. 65).
//
// Loader mieszka po stronie workera, nie w ontopipe, z tego samego
// powodu co ladowanie ontologii: to on ma baze i klucze. Potok dostaje
// gotowy `ontopipe.PastContext` i wylacznie go konsumuje.
//
// ══ Dwie granice, ktorych ten plik pilnuje ══
//
// 1. T22 — spany ryzyka nie wchodza NIGDY. Warunek jest w kazdym
//    zapytaniu, nie w filtrze po stronie Go: wykluczenie ma byc
//    wlasnoscia odczytu, a nie czyms, o czym trzeba pamietac.
//
// 2. Klasa potoku — przebieg produkcyjny widzi wylacznie twierdzenia
//    z raportow produkcyjnych, eksperymentalny wylacznie z
//    eksperymentalnych. Twierdzenia niosa `construct_id` ze SWOJEJ
//    ontologii, wiec mieszanie klas wpuszczaloby do raportu klinicznego
//    slownictwo wersji, ktorej eksperci nie zatwierdzili — ta sama
//    granica, ktora trzyma pamiec RAG z dala od eksperymentow.

import (
	"context"
	"log/slog"
	"sort"
	"time"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/pkg/ontology"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/ontopipe"
)

const (
	// oknoSesjiF7a to W z dok. 65: ile WCZESNIEJSZYCH sesji wchodzi do
	// kontekstu. Trzy, bo tyle wystarcza na ciaglosc ustalen i prog
	// `min_evidence.sessions`, a kazda kolejna sesja to caly jej zestaw
	// twierdzen w prompcie S2.
	oknoSesjiF7a = 3
	// Budzety K i S. Nie sa ostroznoscia, tylko granica dlugosci
	// promptu: sesja produkuje kilkadziesiat twierdzen i setki spanow,
	// wiec trzy sesje bez zacisku potrafia przekroczyc wejscie S2.
	budzetTwierdzen = 60
	budzetSpanow    = 120
	// Ile sesji-kandydatow ogladamy, zeby przeskoczyc nieukonczone i
	// nieudane. Bez limitu kartoteka z historia dwustu sesji ciagnelaby
	// caly ogon przy kazdym raporcie.
	maxKandydatow = 12
)

// statusyWToku to sesje, ktore MOGA jeszcze dac raport.
//
// Sesja w tym stanie jest pomijana i LICZONA (N4) — nie czekamy na nia.
// Czekanie brzmi lepiej, dopoki sesja nie utknie: wtedy kazdy kolejny
// raport tej kartoteki czekalby na cos, co nigdy nie przyjdzie. Postep
// z jawnym zapisem bije zakleszczenie z dobrymi intencjami.
var statusyWToku = map[string]bool{
	"CREATED": true, "RECORDING": true, "PENDING_UPLOAD": true,
	"UPLOADING": true, "TRANSCRIBING": true, "MERGING": true, "ANALYZING": true,
}

type kandydatSesji struct {
	ID     uuid.UUID
	Data   time.Time
	Numer  int
	Status string
}

// wybierzOkno wybiera sesje wchodzace do kontekstu.
//
// Kandydaci przychodza posortowani od najnowszego. Sesje w toku sa
// pomijane i liczone; sesje zakonczone bez raportu (FAILED, CANCELED)
// sa pomijane po cichu — nigdy zadnego twierdzenia nie wniosly i nie
// wniosa, wiec nie sa "brakiem", ktory trzeba tlumaczyc.
func wybierzOkno(kandydaci []kandydatSesji, okno int) (wybrane []kandydatSesji, pominieteWToku int) {
	for _, k := range kandydaci {
		if len(wybrane) == okno {
			break
		}
		if statusyWToku[k.Status] {
			pominieteWToku++
			continue
		}
		if k.Status != "COMPLETED" {
			continue
		}
		wybrane = append(wybrane, k)
	}
	return wybrane, pominieteWToku
}

// przytnijBudzet ogranicza kontekst do K twierdzen i S spanow.
//
// Kolejnosc przycinania jest TRESCIA decyzji, nie szczegolem: najnowsze
// sesje pierwsze (ciaglosc pracy liczy sie bardziej niz archeologia),
// w obrebie sesji twierdzenia o wyzszej pewnosci. Remisy rozstrzyga
// identyfikator, zeby dwa przebiegi na tym samym materiale dostaly ten
// sam kontekst — inaczej benchmark porownywalby szum.
//
// Spany schodza razem ze swoimi twierdzeniami: span bez twierdzenia,
// ktore go cytuje, jest w prompcie samotnym cytatem bez tezy.
func przytnijBudzet(claims []ontopipe.PastClaim, spany []ontopipe.PastSpan,
	maxTwierdzen, maxSpanow int) ([]ontopipe.PastClaim, []ontopipe.PastSpan, int, int) {

	sort.SliceStable(claims, func(i, j int) bool {
		if !claims[i].SessionDate.Equal(claims[j].SessionDate) {
			return claims[i].SessionDate.After(claims[j].SessionDate)
		}
		if claims[i].Confidence != claims[j].Confidence {
			return claims[i].Confidence > claims[j].Confidence
		}
		return claims[i].ID.String() < claims[j].ID.String()
	})
	odrzuconeTwierdzenia := 0
	if len(claims) > maxTwierdzen {
		odrzuconeTwierdzenia = len(claims) - maxTwierdzen
		claims = claims[:maxTwierdzen]
	}

	// Spany zawezone do faktycznie cytowanych przez to, co zostalo.
	potrzebne := map[string]bool{}
	for _, c := range claims {
		for _, addr := range c.Evidence {
			potrzebne[addr] = true
		}
	}
	var zostawione []ontopipe.PastSpan
	for _, s := range spany {
		if potrzebne[s.Addr] {
			zostawione = append(zostawione, s)
		}
	}
	sort.SliceStable(zostawione, func(i, j int) bool {
		if !zostawione[i].SessionDate.Equal(zostawione[j].SessionDate) {
			return zostawione[i].SessionDate.After(zostawione[j].SessionDate)
		}
		return zostawione[i].Addr < zostawione[j].Addr
	})
	odrzuconeSpany := 0
	if len(zostawione) > maxSpanow {
		odrzuconeSpany = len(zostawione) - maxSpanow
		zostawione = zostawione[:maxSpanow]
	}

	// Twierdzenie, ktorego wszystkie spany wypadly z budzetu, traci
	// uziemienie — zostawiamy je bez cytatow tylko wtedy, gdy nadal ma
	// choc jeden pokazany. Inaczej S2 dostalby "ustalenie" bez zadnego
	// dowodu, czyli dokladnie to, czego caly potok zabrania.
	pokazane := map[string]bool{}
	for _, s := range zostawione {
		pokazane[s.Addr] = true
	}
	var zTwierdzeniami []ontopipe.PastClaim
	for _, c := range claims {
		var ma []string
		for _, addr := range c.Evidence {
			if pokazane[addr] {
				ma = append(ma, addr)
			}
		}
		if len(ma) == 0 {
			odrzuconeTwierdzenia++
			continue
		}
		c.Evidence = ma
		zTwierdzeniami = append(zTwierdzeniami, c)
	}

	return zTwierdzeniami, zostawione, odrzuconeTwierdzenia, odrzuconeSpany
}

// loadPastContext sklada kontekst miedzysesyjny dla biezacej sesji.
//
// Blad ladowania NIE przerywa raportu: kontekst jest wzmocnieniem, nie
// bramka walidacyjna. Fail-closed obowiazuje tam, gdzie chodzi o prawde
// twierdzen (R1-R10, V1-V6); tutaj utrata kontekstu oznacza raport
// jednosesyjny, czyli dokladnie to, co potok robil przed F7a.
func loadPastContext(ctx context.Context, logger *slog.Logger, session *SessionContext,
	eksperymentalny bool) *ontopipe.PastContext {

	if dbPool == nil {
		return nil
	}
	past, err := zbierzKontekst(ctx, session, eksperymentalny)
	if err != nil {
		logger.Warn("S0: kontekst miedzysesyjny niedostepny — raport jednosesyjny",
			"session_id", session.ID, "error", err)
		slog.InfoContext(ctx, "analytics", "ae", "report_past_context_failed",
			"session_id", session.ID.String())
		return nil
	}
	logger.Info("S0: kontekst miedzysesyjny",
		"sesje", past.Stats.SessionsLoaded,
		"pominiete_w_toku", past.Stats.SessionsSkippedUnfinished,
		"twierdzenia", past.Stats.ClaimsShown,
		"spany", past.Stats.SpansShown)
	return past
}

func zbierzKontekst(ctx context.Context, session *SessionContext,
	eksperymentalny bool) (*ontopipe.PastContext, error) {

	var dataBiezacej time.Time
	var numerBiezacej int
	if err := dbPool.QueryRow(ctx, `
		SELECT session_date, session_number FROM sessions WHERE id = $1`,
		session.ID).Scan(&dataBiezacej, &numerBiezacej); err != nil {
		return nil, err
	}

	// Porzadek (data, numer) daje porzadek calkowity takze dla dwoch
	// sesji tego samego dnia — data jest typu DATE, wiec sama nie
	// rozstrzyga kolejnosci w obrebie dnia.
	rows, err := dbPool.Query(ctx, `
		SELECT s.id, s.session_date, s.session_number, s.status::text
		  FROM sessions s
		 WHERE s.patient_file_id = $1
		   AND s.deleted_at IS NULL
		   AND (s.session_date, s.session_number) < ($2, $3)
		 ORDER BY s.session_date DESC, s.session_number DESC
		 LIMIT $4`,
		session.PatientFileID, dataBiezacej, numerBiezacej, maxKandydatow)
	if err != nil {
		return nil, err
	}
	var kandydaci []kandydatSesji
	for rows.Next() {
		var k kandydatSesji
		if err := rows.Scan(&k.ID, &k.Data, &k.Numer, &k.Status); err != nil {
			rows.Close()
			return nil, err
		}
		kandydaci = append(kandydaci, k)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}

	wybrane, pominieteWToku := wybierzOkno(kandydaci, oknoSesjiF7a)
	past := &ontopipe.PastContext{Stats: ontopipe.PastStats{
		WindowSize:                oknoSesjiF7a,
		SessionsLoaded:            len(wybrane),
		SessionsSkippedUnfinished: pominieteWToku,
	}}
	if len(wybrane) == 0 {
		return past, nil
	}

	idSesji := make([]uuid.UUID, 0, len(wybrane))
	dataSesji := map[uuid.UUID]time.Time{}
	for _, w := range wybrane {
		idSesji = append(idSesji, w.ID)
		dataSesji[w.ID] = w.Data
	}

	claims, err := wczytajTwierdzenia(ctx, idSesji, dataSesji, eksperymentalny)
	if err != nil {
		return nil, err
	}
	spany, poClaimach, err := wczytajSpanyDowodowe(ctx, claims, dataSesji)
	if err != nil {
		return nil, err
	}
	for i := range claims {
		claims[i].Evidence = poClaimach[claims[i].ID]
	}
	// Twierdzenie bez ANI JEDNEGO czytelnego spanu nie ma czego wniesc
	// do kontekstu — w prompcie bylo by teza bez dowodu.
	var zDowodami []ontopipe.PastClaim
	for _, c := range claims {
		if len(c.Evidence) > 0 {
			zDowodami = append(zDowodami, c)
		}
	}

	tematy, err := wczytajTematySesji(ctx, idSesji, dataSesji)
	if err != nil {
		return nil, err
	}

	przycieteClaims, przycieteSpany, odrzC, odrzS :=
		przytnijBudzet(zDowodami, spany, budzetTwierdzen, budzetSpanow)

	past.Claims = przycieteClaims
	past.Spans = przycieteSpany
	past.SessionTopics = tematy
	past.Stats.ClaimsShown = len(przycieteClaims)
	past.Stats.ClaimsDropped = odrzC + (len(claims) - len(zDowodami))
	past.Stats.SpansShown = len(przycieteSpany)
	past.Stats.SpansDropped = odrzS
	return past, nil
}

func wczytajTwierdzenia(ctx context.Context, idSesji []uuid.UUID,
	dataSesji map[uuid.UUID]time.Time, eksperymentalny bool) ([]ontopipe.PastClaim, error) {

	// Klasa potoku rozstrzyga o widocznosci (patrz naglowek pliku).
	// Stempel bierzemy ze STALEJ, nie z literalu: ten sam napis zyje
	// juz w clinical-svc i w kolumnie reports.pipeline_version, a
	// trzecia kopia rozjechalaby sie po cichu — filtr przestalby
	// znajdowac cokolwiek i wygladaloby to jak brak historii.
	rows, err := dbPool.Query(ctx, `
		SELECT c.id, r.session_id, c.construct_id, c.categories,
		       c.epistemic_status, COALESCE(c.confidence, 0)::float8
		  FROM report_claims c
		  JOIN reports r ON r.id = c.report_id
		 WHERE r.session_id = ANY($1)
		   AND (r.pipeline_version = $3) = $2`,
		idSesji, eksperymentalny, PipelineExperimental)
	if err != nil {
		return nil, err
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

// wczytajSpanyDowodowe czyta spany popierajace wskazane twierdzenia.
//
// Wylacznie role='support': kontrdowody poprzednich sesji sa materialem
// tamtego raportu, a przeniesione bez swojej tezy staja sie cytatem
// przeczacym nie wiadomo czemu.
func wczytajSpanyDowodowe(ctx context.Context, claims []ontopipe.PastClaim,
	dataSesji map[uuid.UUID]time.Time) ([]ontopipe.PastSpan, map[uuid.UUID][]string, error) {

	if len(claims) == 0 {
		return nil, map[uuid.UUID][]string{}, nil
	}
	idClaims := make([]uuid.UUID, 0, len(claims))
	for _, c := range claims {
		idClaims = append(idClaims, c.ID)
	}

	rows, err := dbPool.Query(ctx, `
		SELECT e.claim_id, sp.session_id, sp.span_ref, sp.quote_ciphertext,
		       sp.quote_encrypted_dek, COALESCE(sp.speaker,''), sp.kind,
		       sp.observed_by, sp.about_past, sp.topics
		  FROM report_claim_evidence e
		  JOIN report_spans sp ON sp.id = e.span_id
		 WHERE e.claim_id = ANY($1)
		   AND e.role = 'support'
		   AND sp.risk_content = FALSE`, idClaims)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()

	poClaimach := map[uuid.UUID][]string{}
	widziane := map[string]bool{}
	var spany []ontopipe.PastSpan
	for rows.Next() {
		var claimID, sesja uuid.UUID
		var ref, mowca, kind, observedBy string
		var ct, dek []byte
		var aboutPast bool
		var tematy []string
		if err := rows.Scan(&claimID, &sesja, &ref, &ct, &dek, &mowca,
			&kind, &observedBy, &aboutPast, &tematy); err != nil {
			return nil, nil, err
		}
		addr := ontopipe.SpanAddr(dataSesji[sesja], ref)
		poClaimach[claimID] = append(poClaimach[claimID], addr)
		if widziane[addr] {
			continue
		}
		widziane[addr] = true

		plain, derr := crypto.Decrypt(ctx, ct, dek)
		if derr != nil {
			// Pojedynczy nieodszyfrowalny span nie moze zabrac calego
			// kontekstu — ale twierdzenie bez ani jednego czytelnego
			// dowodu wypada wyzej, w zbierzKontekst.
			slog.WarnContext(ctx, "S0: span nie do odszyfrowania", "addr", addr)
			continue
		}
		spany = append(spany, ontopipe.PastSpan{
			Addr:        addr,
			SessionID:   sesja,
			SessionDate: dataSesji[sesja],
			Quote:       string(plain),
			Speaker:     mowca,
			Kind:        ontology.SpanKind(kind),
			ObservedBy:  ontology.ObservedBy(observedBy),
			AboutPast:   aboutPast,
			Topics:      tematy,
		})
	}
	if err := rows.Err(); err != nil {
		return nil, nil, err
	}

	// Adresy nieodszyfrowanych spanow znikaja z list dowodow — inaczej
	// twierdzenie wskazywaloby na cytat, ktorego w prompcie nie ma.
	// Rozstrzyga OBECNOSC w wyniku, nie sam fakt zobaczenia wiersza:
	// `widziane` znaczy „adres juz przetwarzany", a to co innego niz
	// „cytat jest czytelny".
	czytelneAdresy := make(map[string]bool, len(spany))
	for _, s := range spany {
		czytelneAdresy[s.Addr] = true
	}
	for id, adresy := range poClaimach {
		var czytelne []string
		for _, a := range adresy {
			if czytelneAdresy[a] {
				czytelne = append(czytelne, a)
			}
		}
		poClaimach[id] = czytelne
	}
	return spany, poClaimach, nil
}

// wczytajTematySesji zbiera hasla wszystkich uzytecznych spanow okna.
//
// Hasla nie ida do promptu — sa wejsciem rekurencji miedzysesyjnej
// (S1.5), wiec ich liczba nie obciaza budzetu tekstu i nie podlega
// przycinaniu.
func wczytajTematySesji(ctx context.Context, idSesji []uuid.UUID,
	dataSesji map[uuid.UUID]time.Time) ([]ontopipe.PastSessionTopics, error) {

	rows, err := dbPool.Query(ctx, `
		SELECT session_id, topics FROM report_spans
		 WHERE session_id = ANY($1)
		   AND risk_content = FALSE
		   AND cardinality(topics) > 0`, idSesji)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	poSesji := map[uuid.UUID][]string{}
	for rows.Next() {
		var sesja uuid.UUID
		var tematy []string
		if err := rows.Scan(&sesja, &tematy); err != nil {
			return nil, err
		}
		poSesji[sesja] = append(poSesji[sesja], tematy...)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	out := make([]ontopipe.PastSessionTopics, 0, len(poSesji))
	for _, id := range idSesji {
		if tematy, ok := poSesji[id]; ok {
			out = append(out, ontopipe.PastSessionTopics{
				SessionID: id, SessionDate: dataSesji[id], Topics: tematy,
			})
		}
	}
	return out, nil
}
