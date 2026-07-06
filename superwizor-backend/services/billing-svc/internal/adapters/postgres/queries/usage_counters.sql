-- name: GetActiveCounter :one
-- Pobiera bieżący usage_counters row dla subskrypcji.
-- Zakładamy że istnieje dokładnie jeden aktywny okres na timestamp now()
-- (gwarancja ze §9 — webhook/cron tworzy nowy row przy renewal).
-- W przypadku braku row (race przy renewal) zwraca pgx.ErrNoRows i handler
-- musi tworzyć fallback counter (lub fail z odpowiednim błędem).
SELECT id, subscription_id, period_start, period_end,
       tokens_used, tokens_reserved, tokens_limit, updated_at, therapist_id
FROM usage_counters
WHERE subscription_id = $1
  AND therapist_id IS NULL
  AND period_start <= now()
  AND period_end > now()
LIMIT 1;

-- name: LockActiveCounter :one
-- Wersja z FOR UPDATE — używana wewnątrz transakcji ReserveCredit / CommitUsage,
-- po pg_advisory_xact_lock. SELECT FOR UPDATE chroni przed równoległym
-- modyfikowaniem TEGO konkretnego row (advisory lock chroni przed równoległą
-- pracą per-subscription jeszcze przed dotknięciem row).
SELECT id, subscription_id, period_start, period_end,
       tokens_used, tokens_reserved, tokens_limit, updated_at, therapist_id
FROM usage_counters
WHERE subscription_id = $1
  AND therapist_id IS NULL
  AND period_start <= now()
  AND period_end > now()
FOR UPDATE;

-- name: GetActiveCounterForTherapist :one
-- Per-therapist counter (docs/38 billing model). NULL-therapist rows
-- (org-level) are matched by GetActiveCounter, not here.
SELECT id, subscription_id, period_start, period_end,
       tokens_used, tokens_reserved, tokens_limit, updated_at, therapist_id
FROM usage_counters
WHERE subscription_id = $1
  AND therapist_id = $2
  AND period_start <= now()
  AND period_end > now()
LIMIT 1;

-- name: LockActiveCounterForTherapist :one
-- FOR UPDATE wariant per-therapist — ReserveCredit/CommitUsage debit
-- path. Advisory lock per subscription is still taken first.
SELECT id, subscription_id, period_start, period_end,
       tokens_used, tokens_reserved, tokens_limit, updated_at, therapist_id
FROM usage_counters
WHERE subscription_id = $1
  AND therapist_id = $2
  AND period_start <= now()
  AND period_end > now()
FOR UPDATE;

-- name: SumActiveCounters :one
-- Org-wide aggregate across org-level + per-therapist counters for the
-- current period. GetSubscription fallback for allocation-managed orgs
-- (which may have no org-level row).
SELECT COALESCE(SUM(tokens_used), 0)::int AS tokens_used,
       COALESCE(SUM(tokens_reserved), 0)::int AS tokens_reserved,
       COALESCE(SUM(tokens_limit), 0)::int AS tokens_limit,
       COUNT(*) AS counters
FROM usage_counters
WHERE subscription_id = $1
  AND period_start <= now()
  AND period_end > now();

-- name: CreateTherapistUsageCounter :one
-- Per-seat counter, minted by AdminSetSeatAllocations for already-seated
-- therapists and lazily by the debit path for later joiners.
--
-- ON CONFLICT DO NOTHING is load-bearing, not just tidy: without it a
-- duplicate insert raises 23505, which ABORTS the enclosing pgx
-- transaction. Both callers "tolerate" the unique violation and keep
-- going, but the next statement on the poisoned tx fails with 25P02
-- ("current transaction is aborted") → codes.Internal → the caller 500s.
-- This is the AdminSetSeatAllocations 500 on EDIT: an org whose seated
-- therapists already have counters violates on the first insert and
-- poisons the tx. DO NOTHING makes the insert a no-op on conflict — no
-- error raised, tx stays healthy. On conflict RETURNING yields no row,
-- so callers get pgx.ErrNoRows (meaning "already exists"); on a fresh
-- insert they get the new row. The partial-index predicate is repeated
-- so ON CONFLICT targets uq_usage_counters_therapist_period.
INSERT INTO usage_counters (
    subscription_id, therapist_id, period_start, period_end,
    tokens_used, tokens_reserved, tokens_limit
) VALUES (
    $1, $2, $3, $4, 0, 0, $5
)
ON CONFLICT (subscription_id, therapist_id, period_start)
    WHERE therapist_id IS NOT NULL
    DO NOTHING
RETURNING id, subscription_id, period_start, period_end,
       tokens_used, tokens_reserved, tokens_limit, updated_at, therapist_id;

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

-- name: CheckUsageCounterExists :one
-- Sprawdza czy istnieje usage_counter dla danej subskrypcji i okresu.
-- Używane w upsertSubscriptionFromStripe żeby uniknąć UNIQUE violation
-- w transakcji (które by ją unieważniły w Postgresie).
SELECT EXISTS(
    SELECT 1 FROM usage_counters
    WHERE subscription_id = $1 AND period_start = $2 AND therapist_id IS NULL
) AS exists;

-- name: UpdateUsageCounterOnPlanChange :exec
-- Aktualizuje tokens_limit i period_end dla istniejącego usage_counter
-- przy zmianie planu (upgrade/downgrade). Nie resetuje tokens_used/reserved.
UPDATE usage_counters
SET tokens_limit = $3,
    period_end = $4,
    updated_at = now()
WHERE subscription_id = $1 AND period_start = $2 AND therapist_id IS NULL;
