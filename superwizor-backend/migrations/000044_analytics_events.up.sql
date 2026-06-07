-- Migracja w górę: Tworzenie tabeli analytics_events i powiązanych widoków analitycznych

-- 1. Tabela analytics_events (product analytics)
-- Zgodnie z GDPR/RODO i P1/P2: brak PHI, brak szyfrowania, tylko pseudonimizowane UUID-y.
CREATE TABLE analytics_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_name      TEXT NOT NULL,

    -- Kontekst aktora (opcjonalny — niektóre zdarzenia są generowane przez system)
    therapist_id    UUID REFERENCES users(id) ON DELETE SET NULL,
    organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,

    -- Kontekst encji (opcjonalny — zależy od typu zdarzenia)
    session_id      UUID,
    patient_file_id UUID,
    report_id       UUID,

    -- Schemaless payload
    properties      JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- Rozróżnienie źródła
    source          TEXT NOT NULL DEFAULT 'server'
                    CHECK (source IN ('server', 'client')),

    -- Metadane klienta (NULL dla zdarzeń serwerowych)
    client_platform TEXT,   -- 'ios', 'android', 'web'
    client_version  TEXT,

    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indeksy dla zapytań czasowych i filtrowania po terapeucie/zdarzeniu
CREATE INDEX idx_ae_time ON analytics_events(occurred_at DESC);
CREATE INDEX idx_ae_therapist ON analytics_events(therapist_id, occurred_at DESC) WHERE therapist_id IS NOT NULL;
CREATE INDEX idx_ae_name ON analytics_events(event_name, occurred_at DESC);

COMMENT ON TABLE analytics_events IS 'Product analytics. No PHI. Safe to TRUNCATE. Cloud Function events go to Cloud Logging, not here.';

-- 2. Widoki analityczne działające na istniejących tabelach (metodyka 3)

-- V1: Tygodniowa liczba aktywnych terapeutów (WAU)
CREATE VIEW v_analytics_wau AS
SELECT date_trunc('week', s.created_at) AS week,
       COUNT(DISTINCT s.therapist_id) AS active_therapists
FROM sessions s 
WHERE s.deleted_at IS NULL
GROUP BY 1;

-- V2: Częstotliwość sesji na terapeutę na tydzień
CREATE VIEW v_analytics_session_freq AS
SELECT s.therapist_id,
       date_trunc('week', s.created_at) AS week,
       COUNT(*) AS session_count,
       AVG(s.duration_seconds) AS avg_duration_s,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.duration_seconds) AS median_duration_s
FROM sessions s 
WHERE s.deleted_at IS NULL
GROUP BY 1, 2;

-- V3: Opóźnienie potoku przetwarzania (pipeline latency: upload → raport)
CREATE VIEW v_analytics_pipeline_latency AS
SELECT s.id AS session_id,
       s.therapist_id,
       EXTRACT(EPOCH FROM (r.created_at - s.created_at)) AS e2e_seconds,
       t.stt_processing_seconds,
       r.llm_processing_seconds,
       s.created_at AS session_at
FROM sessions s
JOIN transcripts t ON t.session_id = s.id
JOIN reports r ON r.session_id = s.id
WHERE s.status = 'COMPLETED' AND s.deleted_at IS NULL;

-- V4: Koszt jednostkowy sesji (koszt biznesowy)
CREATE VIEW v_analytics_session_cost AS
SELECT r.session_id,
       s.therapist_id,
       u.organization_id,
       s.duration_seconds,
       r.llm_input_tokens,
       r.llm_output_tokens,
       r.llm_total_cost_usd AS llm_cost_usd,
       -- Chirp 3 HD: $0.016/min (przeliczane w locie)
       ROUND((s.duration_seconds / 60.0) * 0.016, 6) AS stt_cost_usd,
       ROUND(r.llm_total_cost_usd + (s.duration_seconds / 60.0) * 0.016, 6) AS total_cost_usd,
       s.created_at
FROM reports r
JOIN sessions s ON s.id = r.session_id
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL;

-- V5: Satysfakcja z raportów (tygodniowa)
CREATE VIEW v_analytics_satisfaction AS
SELECT date_trunc('week', rr.created_at) AS week,
       COUNT(*) AS total_ratings,
       COUNT(*) FILTER (WHERE rr.rating = 'positive') AS positive,
       COUNT(*) FILTER (WHERE rr.rating = 'negative') AS negative,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rr.rating = 'positive')
             / NULLIF(COUNT(*), 0), 1) AS satisfaction_pct
FROM report_ratings rr
GROUP BY 1;

-- V6: Lejek aktywacyjny użytkowników (onboarding)
CREATE VIEW v_analytics_activation AS
SELECT u.id AS therapist_id,
       u.created_at AS signup_at,
       MIN(pf.created_at) AS first_patient_at,
       MIN(s.created_at) AS first_session_at,
       MIN(r.created_at) AS first_report_at,
       MIN(rr.created_at) AS first_rating_at,
       EXTRACT(EPOCH FROM (MIN(s.created_at) - u.created_at)) / 3600
           AS hours_to_first_session
FROM users u
LEFT JOIN patient_files pf ON pf.therapist_id = u.id AND pf.deleted_at IS NULL
LEFT JOIN sessions s ON s.therapist_id = u.id AND s.deleted_at IS NULL AND s.status = 'COMPLETED'
LEFT JOIN reports r ON r.session_id = s.id
LEFT JOIN report_ratings rr ON rr.therapist_id = u.id
WHERE u.role = 'THERAPIST' AND u.deleted_at IS NULL
GROUP BY 1, 2;

-- V7: Użycie tokenów na organizację w okresie abonamentowym
CREATE VIEW v_analytics_token_util AS
SELECT uc.subscription_id,
       sub.organization_id,
       uc.period_start,
       uc.period_end,
       uc.tokens_limit,
       uc.tokens_used,
       ROUND(100.0 * uc.tokens_used / NULLIF(uc.tokens_limit, 0), 1)
           AS utilization_pct
FROM usage_counters uc
JOIN subscriptions sub ON sub.id = uc.subscription_id;
