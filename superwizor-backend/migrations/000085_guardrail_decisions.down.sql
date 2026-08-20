-- Reverses 000085.
--
-- WARNING: this destroys the MDR article 94 evidence pack for the AI
-- chat. Running it on an environment where the chat has served real
-- traffic is a compliance event, not a schema change. Export first.
DROP TABLE IF EXISTS guardrail_decisions;
