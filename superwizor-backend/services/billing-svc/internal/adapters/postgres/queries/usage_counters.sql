-- name: GetActiveCounter :one
-- Pobiera bieżący usage_counters row dla subskrypcji.
-- Zakładamy że istnieje dokładnie jeden aktywny okres na timestamp now()
-- (gwarancja ze §9 — webhook/cron tworzy nowy row przy renewal).
-- W przypadku braku row (race przy renewal) zwraca pgx.ErrNoRows i handler
-- musi tworzyć fallback counter (lub fail z odpowiednim błędem).
SELECT id, subscription_id, period_start, period_end,
       tokens_used, tokens_reserved, tokens_limit, updated_at
FROM usage_counters
WHERE subscription_id = $1
  AND period_start <= now()
  AND period_end > now()
LIMIT 1;

-- name: LockActiveCounter :one
-- Wersja z FOR UPDATE — używana wewnątrz transakcji ReserveCredit / CommitUsage,
-- po pg_advisory_xact_lock. SELECT FOR UPDATE chroni przed równoległym
-- modyfikowaniem TEGO konkretnego row (advisory lock chroni przed równoległą
-- pracą per-subscription jeszcze przed dotknięciem row).
SELECT id, subscription_id, period_start, period_end,
       tokens_used, tokens_reserved, tokens_limit, updated_at
FROM usage_counters
WHERE subscription_id = $1
  AND period_start <= now()
  AND period_end > now()
FOR UPDATE;

-- name: AddReservedTokens :exec
-- Inkrementuje tokens_reserved. Wywoływane PO sprawdzeniu dostępności
-- w transakcji ReserveCredit.
UPDATE usage_counters
SET tokens_reserved = tokens_reserved + $2,
    updated_at = now()
WHERE id = $1;

-- name: ReleaseReservedTokens :exec
-- Dekrementuje tokens_reserved (clamp do 0). Wywoływane przy ReleaseCredit
-- i przy CommitUsage (transfer rezerwacja → used).
UPDATE usage_counters
SET tokens_reserved = GREATEST(0, tokens_reserved - $2),
    updated_at = now()
WHERE id = $1;

-- name: CommitTokens :exec
-- Atomic: inkrement tokens_used + dekrement tokens_reserved.
-- Używane w CommitUsage tylko jeśli usage_events INSERT zwrócił nowy row.
UPDATE usage_counters
SET tokens_used = tokens_used + $2,
    tokens_reserved = GREATEST(0, tokens_reserved - $3),
    updated_at = now()
WHERE id = $1;
