-- Zakupy w aplikacji: App Store / Google Play (docs/70 §7).
--
-- Subskrypcja sklepowa ląduje w tej samej tabeli `subscriptions` co Stripe
-- i MANUAL — zmienia się tylko `provider` i klucz zewnętrzny
-- (`provider_subscription_id` = Apple originalTransactionId / Google
-- purchaseToken korzenia łańcucha). Dzięki temu ReserveCredit, liczniki i
-- cały gate tokenów działają bez zmian.

-- name: GetPlanByStoreProductID :one
-- Jedno zapytanie dla obu sklepów: aplikacja przysyła product_id, my
-- rozstrzygamy plan po kolumnie właściwej dla platformy.
SELECT id, tier, cycle, tokens_per_period, licenses_limit,
       price_gross, store_price_gross, currency_code,
       apple_product_id, google_product_id
  FROM subscription_plans
 WHERE is_active = TRUE
   AND (($2::text = 'APPLE_IAP'  AND apple_product_id  = $1)
     OR ($2::text = 'GOOGLE_IAP' AND google_product_id = $1))
 LIMIT 1;

-- name: ListStorePlans :many
-- Katalog na paywall. Zwraca tylko plany, które mają produkt w danym
-- sklepie — bez tego aplikacja pokazałaby kartę, której StoreKit/Play
-- nie potrafi wycenić.
SELECT id, tier, cycle, tokens_per_period,
       price_gross, store_price_gross, currency_code,
       apple_product_id, google_product_id
  FROM subscription_plans
 WHERE is_active = TRUE
   AND (($1::text = 'APPLE_IAP'  AND apple_product_id  IS NOT NULL AND apple_product_id  <> '')
     OR ($1::text = 'GOOGLE_IAP' AND google_product_id IS NOT NULL AND google_product_id <> ''))
 ORDER BY tier, cycle;

-- name: UpsertStoreSubscription :one
-- Odpowiednik UpsertStripeSubscription dla sklepów. Klucz konfliktu ten
-- sam: UNIQUE (provider, provider_subscription_id).
INSERT INTO subscriptions (
    organization_id, plan_id,
    provider, provider_subscription_id,
    status,
    current_period_start, current_period_end,
    cancel_at_period_end, canceled_at,
    store_environment, store_product_id, auto_renew, grace_until
) VALUES (
    $1, $2,
    $3, $4,
    $5,
    $6, $7,
    $8, sqlc.narg('canceled_at')::timestamptz,
    $9, $10, $11, sqlc.narg('grace_until')::timestamptz
)
ON CONFLICT (provider, provider_subscription_id) DO UPDATE
    SET plan_id              = EXCLUDED.plan_id,
        organization_id      = EXCLUDED.organization_id,
        status               = EXCLUDED.status,
        current_period_start = EXCLUDED.current_period_start,
        current_period_end   = EXCLUDED.current_period_end,
        cancel_at_period_end = EXCLUDED.cancel_at_period_end,
        canceled_at          = EXCLUDED.canceled_at,
        store_environment    = EXCLUDED.store_environment,
        store_product_id     = EXCLUDED.store_product_id,
        auto_renew           = EXCLUDED.auto_renew,
        grace_until          = EXCLUDED.grace_until,
        updated_at           = now()
RETURNING id, organization_id, plan_id, provider, provider_subscription_id,
          status, current_period_start, current_period_end,
          cancel_at_period_end, canceled_at, store_environment,
          store_product_id, auto_renew, grace_until;

-- name: GetSubscriptionByProviderID :one
SELECT s.id, s.organization_id, s.plan_id, s.provider, s.provider_subscription_id,
       s.status, s.current_period_start, s.current_period_end,
       s.cancel_at_period_end, s.canceled_at,
       s.store_environment, s.store_product_id, s.auto_renew, s.grace_until,
       p.tier AS plan_tier, p.cycle AS plan_cycle, p.tokens_per_period AS plan_tokens_per_period
  FROM subscriptions s
  JOIN subscription_plans p ON p.id = s.plan_id
 WHERE s.provider = $1 AND s.provider_subscription_id = $2;

-- name: DeactivateNonStoreSubscriptions :exec
-- Zakup w sklepie wygasza WYŁĄCZNIE darmowe wejście (TRIAL/BETA na
-- providerze MANUAL). Płatnej subskrypcji innego dostawcy NIE ruszamy —
-- to jest dokładnie sytuacja z docs/70 E22 (dwie płatności za tę samą
-- organizację), którą trzeba zgłosić, a nie po cichu przykryć.
UPDATE subscriptions
   SET status = 'CANCELED', canceled_at = now(), updated_at = now()
 WHERE organization_id = $1
   AND provider = 'MANUAL'
   AND status IN ('ACTIVE', 'TRIALING', 'PAST_DUE')
   AND id <> COALESCE(sqlc.narg('except_id')::uuid, '00000000-0000-0000-0000-000000000000'::uuid);

-- name: SetSubscriptionGraceWindow :exec
-- Grace period ze sklepu: dostęp trwa, ale nowej puli nie ma. Przedłużamy
-- bieżący licznik zamiast tworzyć następny (docs/70 E13).
UPDATE usage_counters
   SET period_end = $2
 WHERE subscription_id = $1
   AND period_start <= now()
   AND period_end > now() - INTERVAL '1 day';

-- name: FreezeCounterAfterRefund :exec
-- Zwrot (Apple REFUND / Google REVOKED): tokeny już spalone nie wracają
-- (BR-5), ale dalszego kredytu nie ma. Limit schodzi do zużycia.
UPDATE usage_counters
   SET tokens_limit = tokens_used
 WHERE subscription_id = $1
   AND period_start <= now() AND period_end > now();

-- name: SetSubscriptionPendingPlan :exec
UPDATE subscriptions
   SET pending_plan_id = sqlc.narg('pending_plan_id')::uuid, updated_at = now()
 WHERE id = $1;

-- name: ListStoreSubscriptionsForReconcile :many
-- Cron uzgadniania (docs/70 E12): notyfikacja bywa zgubiona lub
-- opóźniona, więc raz na dobę pytamy sklep o stan każdej subskrypcji,
-- której okres (lub grace) właśnie minął.
SELECT id, organization_id, provider, provider_subscription_id,
       store_product_id, status, current_period_end, grace_until
  FROM subscriptions
 WHERE provider IN ('APPLE_IAP', 'GOOGLE_IAP')
   AND status IN ('ACTIVE', 'TRIALING', 'PAST_DUE')
   AND COALESCE(grace_until, current_period_end) < now()
 ORDER BY current_period_end
 LIMIT 200;

-- ── store_transactions ─────────────────────────────────────────────────

-- name: UpsertStoreTransaction :one
INSERT INTO store_transactions (
    provider, transaction_id, original_transaction_id,
    organization_id, user_id, product_id,
    purchase_date, expires_date, environment,
    app_account_token, offer_type, offer_identifier,
    revocation_date, revocation_reason, raw_payload
) VALUES (
    $1, $2, $3,
    sqlc.narg('organization_id')::uuid, sqlc.narg('user_id')::uuid, $4,
    $5, sqlc.narg('expires_date')::timestamptz, $6,
    sqlc.narg('app_account_token')::uuid, sqlc.narg('offer_type')::text, sqlc.narg('offer_identifier')::text,
    sqlc.narg('revocation_date')::timestamptz, sqlc.narg('revocation_reason')::text, $7
)
ON CONFLICT (provider, transaction_id) DO UPDATE
    SET expires_date      = EXCLUDED.expires_date,
        revocation_date   = EXCLUDED.revocation_date,
        revocation_reason = EXCLUDED.revocation_reason,
        organization_id   = COALESCE(store_transactions.organization_id, EXCLUDED.organization_id),
        raw_payload       = EXCLUDED.raw_payload,
        verified_at       = now()
RETURNING *;

-- name: GetStoreTransactionOwner :one
-- docs/70 E1: "Przywróć zakupy" nie może przenieść subskrypcji na inne
-- konto. Zwraca organizację, do której transakcja została przypisana
-- przy pierwszym zakupie.
SELECT organization_id, app_account_token, product_id, environment
  FROM store_transactions
 WHERE provider = $1 AND original_transaction_id = $2
   AND organization_id IS NOT NULL
 ORDER BY purchase_date DESC
 LIMIT 1;

-- name: ListStoreTransactionsByOrg :many
SELECT provider, transaction_id, original_transaction_id, product_id,
       environment, purchase_date, expires_date, revocation_date,
       COALESCE(offer_identifier, '') AS offer_identifier
  FROM store_transactions
 WHERE organization_id = $1
 ORDER BY purchase_date DESC
 LIMIT $2;

-- ── pending_checkouts (docs/70 E22) ────────────────────────────────────

-- name: UpsertPendingCheckout :exec
INSERT INTO pending_checkouts (organization_id, channel, reference, expires_at)
VALUES ($1, $2, $3, $4)
ON CONFLICT (organization_id, channel) DO UPDATE
    SET reference = EXCLUDED.reference,
        expires_at = EXCLUDED.expires_at,
        created_at = now();

-- name: GetOtherPendingCheckout :one
-- Czy trwa zakup w INNYM kanale niż ten, o który pytamy.
SELECT channel, reference, expires_at
  FROM pending_checkouts
 WHERE organization_id = $1
   AND channel <> $2
   AND expires_at > now()
 LIMIT 1;

-- name: DeletePendingCheckout :exec
DELETE FROM pending_checkouts
 WHERE organization_id = $1 AND channel = $2;

-- name: DeleteExpiredPendingCheckouts :execrows
DELETE FROM pending_checkouts WHERE expires_at < now();

-- ── app_config (flagi IAP) ─────────────────────────────────────────────

-- name: GetGlobalAppConfig :one
SELECT value FROM app_config
 WHERE key = $1 AND organization_id IS NULL;
