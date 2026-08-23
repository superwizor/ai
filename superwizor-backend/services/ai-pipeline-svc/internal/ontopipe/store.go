package ontopipe

import (
	"context"
	"fmt"

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
func Persist(ctx context.Context, db DB, crypto Crypto, in PersistInput, res Result) error {
	spanUUID := map[string]uuid.UUID{}
	for _, s := range res.Spans {
		ct, dek, err := crypto.Encrypt(ctx, []byte(s.QuoteVerbatim))
		if err != nil {
			return fmt.Errorf("ontopipe: szyfrowanie cytatu %s: %w", s.ID, err)
		}
		id, err := db.QueryUUID(ctx, `
			INSERT INTO report_spans (session_id, transcript_id, span_ref,
			       quote_ciphertext, quote_encrypted_dek, speaker, kind,
			       observed_by, about_past, risk_content, silence_before_ms)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
			ON CONFLICT (transcript_id, span_ref) DO UPDATE
			   SET quote_ciphertext = EXCLUDED.quote_ciphertext,
			       quote_encrypted_dek = EXCLUDED.quote_encrypted_dek
			RETURNING id`,
			in.SessionID, in.TranscriptID, s.ID, ct, dek, s.Speaker, string(s.Kind),
			string(s.ObservedBy), s.AboutPast, s.RiskContent, s.SilenceBeforeMs)
		if err != nil {
			return fmt.Errorf("ontopipe: zapis spanu %s: %w", s.ID, err)
		}
		spanUUID[s.ID] = id
	}

	for _, c := range res.Approved {
		var rct, rdek []byte
		if c.Reasoning != "" {
			var err error
			rct, rdek, err = crypto.Encrypt(ctx, []byte(c.Reasoning))
			if err != nil {
				return fmt.Errorf("ontopipe: szyfrowanie uzasadnienia %s: %w", c.ConstructID, err)
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
			return fmt.Errorf("ontopipe: zapis twierdzenia %s: %w", c.ConstructID, err)
		}

		for _, q := range c.Evidence {
			if err := linkEvidence(ctx, db, claimID, spanUUID, q.SpanID, "support"); err != nil {
				return err
			}
		}
		for _, q := range c.CounterEvidence {
			if err := linkEvidence(ctx, db, claimID, spanUUID, q.SpanID, "counter"); err != nil {
				return err
			}
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
			return fmt.Errorf("ontopipe: zapis wzorca %s: %w", p.ID, err)
		}
		for _, sid := range p.SpanIDs {
			u, ok := spanUUID[sid]
			if !ok {
				continue
			}
			if err := db.Exec(ctx, `
				INSERT INTO report_pattern_spans (pattern_id, span_id)
				VALUES ($1,$2) ON CONFLICT DO NOTHING`, pid, u); err != nil {
				return fmt.Errorf("ontopipe: proweniencja wzorca %s: %w", p.ID, err)
			}
		}
	}

	for _, r := range res.Rejected {
		if err := db.Exec(ctx, `
			INSERT INTO report_claim_rejections (report_id, construct_id, rule, detail)
			VALUES ($1,$2,$3,$4)`,
			in.ReportID, r.ConstructID, string(r.Reason), r.Detail); err != nil {
			return fmt.Errorf("ontopipe: zapis odrzucenia %s: %w", r.Reason, err)
		}
	}
	// Degradacje i naruszenia wyjscia ida do tego samego rejestru: to
	// tez sa powody, dla ktorych raport wyglada tak, a nie inaczej, a
	// osobna tabela na kazdy rodzaj rozbilaby jedno zapytanie progowe
	// na trzy.
	for _, d := range res.Degraded {
		if err := db.Exec(ctx, `
			INSERT INTO report_claim_rejections (report_id, construct_id, rule, detail)
			VALUES ($1,$2,$3,$4)`,
			in.ReportID, d.ConstructID, string(ontology.ReasonRequires),
			"degradacja -> "+d.To+"; "+d.Detail); err != nil {
			return fmt.Errorf("ontopipe: zapis degradacji %s: %w", d.ConstructID, err)
		}
	}
	for _, v := range res.Violations {
		if err := db.Exec(ctx, `
			INSERT INTO report_claim_rejections (report_id, construct_id, rule, detail)
			VALUES ($1,$2,$3,$4)`,
			in.ReportID, v.ConstructID, string(v.Rule), v.Detail); err != nil {
			return fmt.Errorf("ontopipe: zapis naruszenia %s: %w", v.Rule, err)
		}
	}
	return nil
}

func linkEvidence(ctx context.Context, db DB, claimID uuid.UUID,
	spanUUID map[string]uuid.UUID, spanRef, rola string) error {
	u, ok := spanUUID[spanRef]
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
