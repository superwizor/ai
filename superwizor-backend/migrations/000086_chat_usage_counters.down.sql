-- Reverses 000086. Drops in dependency order.
--
-- Operational note: dropping the counters removes the AI chat budget
-- ceiling. The quota reserver treats a missing counter row as "create a
-- fresh period", so the immediate effect is every therapist starting from
-- zero spend, not unlimited spend — but the historical usage is gone.
DROP TABLE IF EXISTS chat_usage_reservations;
DROP TABLE IF EXISTS chat_usage_counters;
