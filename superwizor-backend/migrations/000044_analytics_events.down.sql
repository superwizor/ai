-- Migracja w dół: Usuwanie widoków i tabeli analitycznej

DROP VIEW IF EXISTS v_analytics_token_util;
DROP VIEW IF EXISTS v_analytics_activation;
DROP VIEW IF EXISTS v_analytics_satisfaction;
DROP VIEW IF EXISTS v_analytics_session_cost;
DROP VIEW IF EXISTS v_analytics_pipeline_latency;
DROP VIEW IF EXISTS v_analytics_session_freq;
DROP VIEW IF EXISTS v_analytics_wau;

DROP TABLE IF EXISTS analytics_events;
