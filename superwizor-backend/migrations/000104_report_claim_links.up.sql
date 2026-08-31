-- T42b (docs/67 §4): relacje ciaglosci i rozliczenie pracy domowej.
-- kind='continuity': biezace twierdzenie <-> przeszle twierdzenie tego
--   samego konstruktu; relation wzmacnia/oslabia (bez_zwiazku nie tworzy
--   wiersza).
-- kind='homework': rozliczenie przeszlego ustalenia "praca domowa
--   klienta"; current_claim_id NULL; relation = werdykt trojstanowy;
--   evidence_span_refs = span_ref biezacej sesji (puste przy nie_wrocono).
CREATE TABLE report_claim_links (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id          UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    kind               TEXT NOT NULL CHECK (kind IN ('continuity', 'homework')),
    current_claim_id   UUID NULL REFERENCES report_claims(id) ON DELETE CASCADE,
    past_claim_id      UUID NOT NULL REFERENCES report_claims(id) ON DELETE CASCADE,
    relation           TEXT NOT NULL,
    evidence_span_refs TEXT[] NOT NULL DEFAULT '{}',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK ((kind = 'continuity' AND relation IN ('wzmacnia', 'oslabia')
                AND current_claim_id IS NOT NULL)
        OR (kind = 'homework' AND relation IN ('omowiona_z_rezultatem',
                'wspomniana', 'nie_wrocono') AND current_claim_id IS NULL)),
    UNIQUE (report_id, kind, past_claim_id, current_claim_id)
);
CREATE INDEX report_claim_links_report_idx ON report_claim_links (report_id);
CREATE INDEX report_claim_links_past_idx ON report_claim_links (past_claim_id);
