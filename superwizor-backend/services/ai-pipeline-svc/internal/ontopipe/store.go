package ontopipe

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// Utrwalenie wyniku potoku (migracja 000093).
//
// Raport przestaje byc blokiem tekstu, a staje sie GRAFEM TWIERDZEN z
// proweniencja do zrodla. Bez tego nie ma ani klikalnych cytatow w UI,
// ani odtwarzalnosci do audytu, ani benchmarku porownujacego wersje
// ontologii na tym samym materiale.
//
// CO JEST SZYFROWANE: cytaty i uzasadnienia, bo to doslowny material
// kliniczny. Metadane strukturalne (kind, observed_by, about_past,
// risk_content) zostaja jawne — walidator musialby inaczej deszyfrowac
// kazdy span, zeby sprawdzic prog dowodowy.

// DB to waskie wejscie do bazy, zeby pakiet nie ciagnal pgxpool i dal
// sie testowac bez Postgresa.
type DB interface {
	Exec(ctx context.Context, sql string, args ...any) error
	QueryUUID(ctx context.Context, sql string, args ...any) (uuid.UUID, error)
}

// Crypto szyfruje kopertowo, tak samo jak transcript_segments.
type Crypto interface {
	Encrypt(ctx context.Context, plaintext []byte) (ciphertext, encryptedDEK []byte, err error)
}

// PersistInput to komplet identyfikatorow potrzebnych do zapisu.
type PersistInput struct {
	ReportID     uuid.UUID
	SessionID    uuid.UUID
	TranscriptID uuid.UUID
	// Past to kontekst miedzysesyjny POKAZANY temu przebiegowi.
	// Zapisujemy go razem z grafem twierdzen, bo to ta sama sprawa:
	// z czego powstal ten raport (dok. 65 §N2).
	Past *PastContext
}

// Persist zapisuje spany, twierdzenia, wzorce i odrzucenia.
//
// SPANY RYZYKA SA ZAPISYWANE (z risk_content = TRUE), choc nie zasilaja
// wnioskowania. Roznica jest istotna: wykluczenie ma byc ZAPISANE, a nie
// liczone od nowa przy kazdym odczycie — inaczej zmiana progu detekcji
// po cichu zmienia historyczne raporty.
//
// Odrzucenia ida do bazy nawet gdy raport sie udal: progi przegladu z
// dok. 11 sekcja 8.3 (R5 > 5% miesiecznie, no_fit > 10% kwartalnie) to
// zapytanie SQL, nie grep po Cloud Logging.
// PersistResult niesie to, co powstalo dopiero PRZY ZAPISIE.
//
// ClaimIDs sa ulozone rownolegle do res.Approved: i-te twierdzenie
// dostalo i-ty identyfikator. Wolajacy potrzebuje ich, zeby cokolwiek
// mogl do twierdzenia dowiazac — indeks semantyczny (F7b) bez tego
// odsylal do nikad i wyszukiwanie nie znajdowaloby NICZEGO, wygladajac
// przy tym na „brak historii".
type PersistResult struct {
	ClaimIDs []uuid.UUID
}

func Persist(ctx context.Context, db DB, crypto Crypto, in PersistInput, res Result) (PersistResult, error) {
	var wynik PersistResult
	spanUUID := map[string]uuid.UUID{}
	for _, s := range res.Spans {
		ct, dek, err := crypto.Encrypt(ctx, []byte(s.QuoteVerbatim))
		if err != nil {
			return wynik, fmt.Errorf("ontopipe: szyfrowanie cytatu %s: %w", s.ID, err)
		}
		// Hasla tematyczne ida do bazy od migracji 000097: rekurencja
		// MIEDZYSESYJNA liczy sie na sumie sesji, wiec material, z ktorego
		// S1.5 liczy wzorce, musi przetrwac przebieg. Wczesniej zostawaly
		// wylacznie wzorce wynikowe — a z nich nie da sie policzyc niczego
		// nowego, gdy dojdzie kolejna sesja.
		tematy := s.Topics
		if tematy == nil {
			tematy = []string{}
		}
		id, err := db.QueryUUID(ctx, `
			INSERT INTO report_spans (session_id, transcript_id, span_ref,
			       quote_ciphertext, quote_encrypted_dek, speaker, kind,
			       observed_by, about_past, risk_content, silence_before_ms,
			       topics, fact_kind)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,NULLIF($13,''))
			ON CONFLICT (transcript_id, span_ref) DO UPDATE
			   SET quote_ciphertext = EXCLUDED.quote_ciphertext,
			       quote_encrypted_dek = EXCLUDED.quote_encrypted_dek,
			       topics = EXCLUDED.topics,
			       fact_kind = EXCLUDED.fact_kind
			RETURNING id`,
			in.SessionID, in.TranscriptID, s.ID, ct, dek, s.Speaker, string(s.Kind),
			string(s.ObservedBy), s.AboutPast, s.RiskContent, s.SilenceBeforeMs,
			tematy, s.FactKind)
		if err != nil {
			return wynik, fmt.Errorf("ontopipe: zapis spanu %s: %w", s.ID, err)
		}
		spanUUID[s.ID] = id
	}

	// Rozwiazywanie adresow miedzysesyjnych (F7a-3).
	//
	// Twierdzenie moze cytowac span z WCZESNIEJSZEJ sesji (`s0820:s42`).
	// Taki span ma juz swoj wiersz w report_spans — zapisany przy
	// przebiegu tamtej sesji — wiec proweniencja wskazuje na ORYGINAL,
	// nie na kopie. Bez tego Persist konczyl bledem „span spoza
	// zapisanych", a Pub/Sub ponawial CALY przebieg co szesc minut,
	// zostawiajac za kazdym razem kolejny raport (kanarek F7a-5).
	historyczne := historyczneSpany(ctx, db, in.Past)

	for _, c := range res.Approved {
		var rct, rdek []byte
		if c.Reasoning != "" {
			var err error
			rct, rdek, err = crypto.Encrypt(ctx, []byte(c.Reasoning))
			if err != nil {
				return wynik, fmt.Errorf("ontopipe: szyfrowanie uzasadnienia %s: %w", c.ConstructID, err)
			}
		}
		kat := c.Categories
		if kat == nil {
			kat = []string{}
		}
		claimID, err := db.QueryUUID(ctx, `
			INSERT INTO report_claims (report_id, construct_id, categories,
			       epistemic_status, confidence, reasoning_ciphertext,
			       reasoning_encrypted_dek, is_etiological)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
			in.ReportID, c.ConstructID, kat, string(c.Status), c.Confidence,
			rct, rdek, c.Etiological)
		if err != nil {
			return wynik, fmt.Errorf("ontopipe: zapis twierdzenia %s: %w", c.ConstructID, err)
		}
		wynik.ClaimIDs = append(wynik.ClaimIDs, claimID)

		for _, q := range c.Evidence {
			if err := linkEvidence(ctx, db, claimID, spanUUID, historyczne, q.SpanID, "support"); err != nil {
				return wynik, err
			}
		}
		for _, q := range c.CounterEvidence {
			if err := linkEvidence(ctx, db, claimID, spanUUID, historyczne, q.SpanID, "counter"); err != nil {
				return wynik, err
			}
		}
	}

	// ── T42b: relacje ciaglosci i rozliczenie pracy domowej ──
	// ClaimIdx tlumaczony na uuid DOPIERO tutaj, po zapisie twierdzen:
	// indeks jest nosny wylacznie w obrebie tego przebiegu.
	for _, l := range res.ContinuityLinks {
		if l.ClaimIdx < 0 || l.ClaimIdx >= len(wynik.ClaimIDs) {
			continue
		}
		if err := db.Exec(ctx, `
			INSERT INTO report_claim_links (report_id, kind, current_claim_id,
			       past_claim_id, relation, evidence_span_refs)
			VALUES ($1,'continuity',$2,$3,$4,$5)
			ON CONFLICT DO NOTHING`,
			in.ReportID, wynik.ClaimIDs[l.ClaimIdx], l.PastClaimID, l.Relation,
			[]string{}); err != nil {
			return wynik, fmt.Errorf("ontopipe: zapis linku ciaglosci: %w", err)
		}
	}
	for _, h := range res.HomeworkVerdicts {
		ev := h.EvidenceSpanIDs
		if ev == nil {
			ev = []string{}
		}
		if err := db.Exec(ctx, `
			INSERT INTO report_claim_links (report_id, kind, current_claim_id,
			       past_claim_id, relation, evidence_span_refs)
			VALUES ($1,'homework',NULL,$2,$3,$4)
			ON CONFLICT DO NOTHING`,
			in.ReportID, h.PastClaimID, h.Verdict, ev); err != nil {
			return wynik, fmt.Errorf("ontopipe: zapis rozliczenia: %w", err)
		}
	}

	for _, p := range res.Patterns {
		pid, err := db.QueryUUID(ctx, `
			INSERT INTO report_patterns (report_id, pattern_ref, pattern_type,
			       topics, method, method_version, sessions_count)
			VALUES ($1,$2,$3,$4,$5,$6,$7)
			ON CONFLICT (report_id, pattern_ref) DO UPDATE SET method = EXCLUDED.method
			RETURNING id`,
			in.ReportID, p.ID, string(p.Type), p.Topics, p.Method, p.MethodVersion, p.Sessions)
		if err != nil {
			return wynik, fmt.Errorf("ontopipe: zapis wzorca %s: %w", p.ID, err)
		}
		for _, sid := range p.SpanIDs {
			u, ok := spanUUID[sid]
			if !ok {
				continue
			}
			if err := db.Exec(ctx, `
				INSERT INTO report_pattern_spans (pattern_id, span_id)
				VALUES ($1,$2) ON CONFLICT DO NOTHING`, pid, u); err != nil {
				return wynik, fmt.Errorf("ontopipe: proweniencja wzorca %s: %w", p.ID, err)
			}
		}
	}

	// Odrzucenia ida do bazy WRAZ Z TRESCIA (migracja 000095).
	//
	// Progi dowodowe i prompty stroi sie na przykladach, wiec przyklad
	// musi przetrwac: sam kod reguly nie mowi, czy model sfabrykowal
	// precyzje, czy odwolal sie do numeracji wlasnego modelu. To sa dwie
	// przeciwstawne diagnozy i az do 000095 byly nierozroznialne.
	for _, r := range res.Rejected {
		if err := zapiszOdrzucenie(ctx, db, crypto, in.ReportID,
			r.ConstructID, string(r.Reason), r.Detail, r.Claim); err != nil {
			return wynik, fmt.Errorf("ontopipe: zapis odrzucenia %s: %w", r.Reason, err)
		}
	}
	// Degradacje i naruszenia wyjscia ida do tego samego rejestru: to
	// tez sa powody, dla ktorych raport wyglada tak, a nie inaczej, a
	// osobna tabela na kazdy rodzaj rozbilaby jedno zapytanie progowe
	// na trzy.
	for _, d := range res.Degraded {
		// Degradacja dotyczy KONSTRUKTU, nie pojedynczego twierdzenia —
		// stad brak tresci.
		if err := zapiszOdrzucenie(ctx, db, crypto, in.ReportID, d.ConstructID,
			string(ontology.ReasonRequires),
			"degradacja -> "+d.To+"; "+d.Detail, nil); err != nil {
			return wynik, fmt.Errorf("ontopipe: zapis degradacji %s: %w", d.ConstructID, err)
		}
	}
	if err := zapiszKontekstPrzebiegu(ctx, db, in); err != nil {
		return wynik, err
	}
	for _, v := range res.Violations {
		// Naruszenie S5 dotyczy PROZY, wiec tresc bierzemy z hipotezy.
		var jakoClaim *ontology.Claim
		if v.HypothesisText != "" {
			jakoClaim = &ontology.Claim{
				ConstructID: v.ConstructID,
				Reasoning:   v.HypothesisText,
				Status:      ontology.EpistemicStatus(v.HypothesisStatus),
			}
			for _, id := range v.HypothesisSpans {
				jakoClaim.Evidence = append(jakoClaim.Evidence, ontology.QuoteRef{SpanID: id})
			}
		}
		if err := zapiszOdrzucenie(ctx, db, crypto, in.ReportID,
			v.ConstructID, string(v.Rule), v.Detail, jakoClaim); err != nil {
			return wynik, fmt.Errorf("ontopipe: zapis naruszenia %s: %w", v.Rule, err)
		}
	}
	return wynik, nil
}

// zapiszKontekstPrzebiegu utrwala, CO ten przebieg zobaczyl z sesji
// wczesniejszych (dok. 65 §N2, migracja 000098).
//
// Zapis idzie w tej samej sciezce co graf twierdzen, bo odpowiada na to
// samo pytanie: z czego powstal ten raport. Rozdzielenie ich oznaczaloby,
// ze raport moze istniec bez zapisu swojego wejscia — a wtedy audyt
// konczy sie na „model widzial cos z poprzednich sesji".
//
// ON CONFLICT DO NOTHING, bo caly Persist jest idempotentny: Pub/Sub
// potrafi dostarczyc to samo zdarzenie drugi raz.
func zapiszKontekstPrzebiegu(ctx context.Context, db DB, in PersistInput) error {
	past := in.Past
	if past == nil {
		return nil
	}
	for _, c := range past.Claims {
		var podobienstwo any
		if c.Similarity > 0 {
			podobienstwo = c.Similarity
		}
		if err := db.Exec(ctx, `
			INSERT INTO report_run_context (report_id, item_kind, channel,
			       source_session_id, item_ref, construct_id, similarity)
			VALUES ($1,'claim',$2,$3,$4,$5,$6)
			ON CONFLICT (report_id, item_kind, item_ref) DO NOTHING`,
			in.ReportID, kanal(c.Channel), c.SessionID, c.ID.String(),
			c.ConstructID, podobienstwo); err != nil {
			return fmt.Errorf("ontopipe: zapis kontekstu (twierdzenie %s): %w", c.ID, err)
		}
	}
	for _, sp := range past.Spans {
		if err := db.Exec(ctx, `
			INSERT INTO report_run_context (report_id, item_kind, channel,
			       source_session_id, item_ref)
			VALUES ($1,'span',$2,$3,$4)
			ON CONFLICT (report_id, item_kind, item_ref) DO NOTHING`,
			in.ReportID, kanal(sp.Channel), sp.SessionID, sp.Addr); err != nil {
			return fmt.Errorf("ontopipe: zapis kontekstu (span %s): %w", sp.Addr, err)
		}
	}
	// Liczniki ida ZAWSZE, takze gdy okno nic nie znalazlo: zero
	// zaladowanych sesji przy dwoch pominietych nieukonczonych to inna
	// historia niz zero, bo kartoteka nie ma przeszlosci.
	st := past.Stats
	if err := db.Exec(ctx, `
		INSERT INTO report_run_context_stats (report_id, window_size,
		       sessions_loaded, sessions_skipped_unfinished,
		       claims_shown, claims_dropped_budget,
		       spans_shown, spans_dropped_budget,
		       semantic_enabled, semantic_found, semantic_below_threshold)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
		ON CONFLICT (report_id) DO UPDATE
		   SET sessions_loaded = EXCLUDED.sessions_loaded,
		       sessions_skipped_unfinished = EXCLUDED.sessions_skipped_unfinished,
		       claims_shown = EXCLUDED.claims_shown,
		       claims_dropped_budget = EXCLUDED.claims_dropped_budget,
		       spans_shown = EXCLUDED.spans_shown,
		       spans_dropped_budget = EXCLUDED.spans_dropped_budget,
		       semantic_enabled = EXCLUDED.semantic_enabled,
		       semantic_found = EXCLUDED.semantic_found,
		       semantic_below_threshold = EXCLUDED.semantic_below_threshold`,
		in.ReportID, st.WindowSize, st.SessionsLoaded, st.SessionsSkippedUnfinished,
		st.ClaimsShown, st.ClaimsDropped, st.SpansShown, st.SpansDropped,
		st.SemanticEnabled, st.SemanticFound, st.SemanticBelowThreshold); err != nil {
		return fmt.Errorf("ontopipe: zapis licznikow kontekstu: %w", err)
	}
	return nil
}

// kanal domysla sie "window" dla wpisow bez jawnego kanalu.
//
// Zgodnosc wsteczna: wpisy sprzed F7b nie niosly tej informacji, bo
// kanal byl jeden. Milczenie znaczy wiec okno, a nie „nieznany".
func kanal(k string) string {
	if k == "" {
		return "window"
	}
	return k
}

// zapiszOdrzucenie zapisuje jeden wpis rejestru wraz z trescia.
//
// Uzasadnienie szyfrowane kopertowo jak w report_claims; kolumny
// strukturalne (kategorie, status, odnosniki) JAWNE, bo bez nich nie da
// sie policzyc, ile razy model proponowal dana kategorie — a to jest
// pytanie, ktore zadaje benchmark.
func zapiszOdrzucenie(ctx context.Context, db DB, crypto Crypto, reportID uuid.UUID,
	constructID, rule, detail string, cl *ontology.Claim) error {

	var (
		ct, dek    []byte
		kategorie  = []string{}
		spany      = []string{}
		statusStr  *string
		confidence *float64
	)
	if cl != nil {
		if cl.Reasoning != "" {
			var err error
			ct, dek, err = crypto.Encrypt(ctx, []byte(cl.Reasoning))
			if err != nil {
				return fmt.Errorf("szyfrowanie uzasadnienia: %w", err)
			}
		}
		if len(cl.Categories) > 0 {
			kategorie = cl.Categories
		}
		for _, q := range cl.Evidence {
			spany = append(spany, q.SpanID)
		}
		if cl.Status != "" {
			s := string(cl.Status)
			statusStr = &s
		}
		if cl.Confidence > 0 {
			c := cl.Confidence
			confidence = &c
		}
	}

	return db.Exec(ctx, `
		INSERT INTO report_claim_rejections
		       (report_id, construct_id, rule, detail,
		        reasoning_ciphertext, reasoning_encrypted_dek,
		        proposed_categories, epistemic_status, confidence, evidence_span_refs)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
		reportID, constructID, rule, detail, ct, dek,
		kategorie, statusStr, confidence, spany)
}

// historyczneSpany zwraca funkcje odwzorowujaca adres miedzysesyjny na
// istniejacy wiersz report_spans.
//
// Wyniki sa zapamietywane: jedno twierdzenie potrafi cytowac ten sam
// span co drugie, a zapytanie do bazy na kazde wystapienie byloby
// czystym marnotrawstwem.
func historyczneSpany(ctx context.Context, db DB, past *PastContext) func(string) (uuid.UUID, bool) {
	cache := map[string]uuid.UUID{}
	return func(addr string) (uuid.UUID, bool) {
		if past == nil {
			return uuid.Nil, false
		}
		if id, ok := cache[addr]; ok {
			return id, true
		}
		i := strings.Index(addr, ":")
		if i < 0 {
			return uuid.Nil, false
		}
		var sesja uuid.UUID
		znaleziony := false
		for _, ps := range past.Spans {
			if ps.Addr == addr {
				sesja, znaleziony = ps.SessionID, true
				break
			}
		}
		if !znaleziony {
			// Adres spoza kontekstu POKAZANEGO temu przebiegowi. To nie
			// jest span historyczny, tylko wymyslony — blad nizej jest
			// wtedy wlasciwa reakcja.
			return uuid.Nil, false
		}
		id, err := db.QueryUUID(ctx, `
			SELECT id FROM report_spans
			 WHERE session_id = $1 AND span_ref = $2
			 ORDER BY created_at DESC LIMIT 1`, sesja, addr[i+1:])
		if err != nil {
			return uuid.Nil, false
		}
		cache[addr] = id
		return id, true
	}
}

func linkEvidence(ctx context.Context, db DB, claimID uuid.UUID,
	spanUUID map[string]uuid.UUID, historyczny func(string) (uuid.UUID, bool),
	spanRef, rola string) error {
	u, ok := spanUUID[spanRef]
	if !ok {
		u, ok = historyczny(spanRef)
	}
	if !ok {
		// Walidator juz odrzuca twierdzenia wskazujace nieznany span
		// (R2_unknown_span), wiec tutaj to nie moze sie zdarzyc — ale
		// gdyby sie zdarzylo, brak proweniencji jest gorszy niz blad.
		return fmt.Errorf("ontopipe: twierdzenie wskazuje span %q spoza zapisanych", spanRef)
	}
	if err := db.Exec(ctx, `
		INSERT INTO report_claim_evidence (claim_id, span_id, role)
		VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`, claimID, u, rola); err != nil {
		return fmt.Errorf("ontopipe: proweniencja twierdzenia: %w", err)
	}
	return nil
}
