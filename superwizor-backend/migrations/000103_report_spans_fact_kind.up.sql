-- E4/T42a (docs/67 §3): fakt sesyjny jako atrybut istniejacego spanu.
-- NULL = zwykly span. CHECK zamyka katalog na poziomie bazy — fact_kind
-- spoza listy nie ma prawa istniec nawet przy bledzie w kodzie, bo
-- mapowanie deterministyczne (fact_kind_map) traktuje wartosc jako klucz.
ALTER TABLE report_spans ADD COLUMN fact_kind TEXT NULL
    CHECK (fact_kind IN ('agreement_client', 'agreement_therapist',
                         'agenda_next', 'agenda_unaddressed',
                         'mood_rating', 'client_metaphor'));
COMMENT ON COLUMN report_spans.fact_kind IS
    'E4/T42a: rodzaj faktu sesyjnego (NULL = zwykly span); katalog w pkg/ontology FactKinds';
