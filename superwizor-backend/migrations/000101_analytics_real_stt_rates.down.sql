-- Przywraca widok w postaci z migracji 000045: jeden wiersz na RAPORT
-- i zaszyta stawka 0,016 USD/min. Oba te zachowania są błędne (patrz
-- komentarz w .up.sql) — down istnieje po to, żeby dało się cofnąć
-- migrację, a nie dlatego, że ta wersja jest poprawna.

DROP VIEW IF EXISTS v_analytics_session_cost CASCADE;

CREATE VIEW v_analytics_session_cost AS
SELECT r.session_id,
       s.therapist_id,
       u.organization_id,
       s.duration_seconds,
       r.llm_input_tokens,
       r.llm_output_tokens,
       r.llm_total_cost_usd AS llm_cost_usd,
       ROUND((s.duration_seconds / 60.0) * 0.016, 6) AS stt_cost_usd,
       ROUND(r.llm_total_cost_usd + (s.duration_seconds / 60.0) * 0.016, 6) AS total_cost_usd,
       s.created_at
FROM reports r
JOIN sessions s ON s.id = r.session_id
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test';
