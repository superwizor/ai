-- name: AcquireSubscriptionLock :exec
-- pg_advisory_xact_lock per subscription_id — serializuje wszystkie operacje
-- billingowe dotyczące tej samej subskrypcji. Lock zwalniany automatycznie
-- na koniec transakcji (xact = transaction-scoped).
--
-- hashtextextended(text, 0) daje bigint hash z UUID-stringa — pg_advisory_xact_lock
-- wymaga bigint, a my chcemy klucza pochodzącego z subscription_id.
-- Collision risk z innych advisory locks: niski (przestrzeń bigint, my
-- używamy advisory_xact_lock tylko w tym miejscu w całym systemie billingowym).
SELECT pg_advisory_xact_lock(hashtextextended($1::text, 0));
