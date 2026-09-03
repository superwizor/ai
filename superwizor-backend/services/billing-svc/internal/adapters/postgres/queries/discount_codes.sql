-- Kody rabatowe (docs/70 §6). Katalog jest nasz, egzekwowanie na webie
-- należy do Stripe'a — dlatego limit użyć nigdy nie jest tu sprawdzany
-- pod blokadą: `redemptions_count` to lustro do panelu, a o ostatnie
-- użycie rozstrzyga `max_redemptions` na promotion code'zie Stripe'a.

-- name: CreateDiscountCode :one
-- Wszystkie parametry nazwane: mieszanie sqlc.arg() z pozycyjnymi $n w
-- jednym zapytaniu uniemożliwia sqlc wywnioskowanie typu (kod wracał
-- wtedy jako interface{}).
INSERT INTO discount_codes (
    code, name, percent_off, duration, duration_periods,
    valid_from, valid_until, max_redemptions,
    applies_to_tiers, applies_to_cycles, new_customers_only,
    channels, created_by, reason
) VALUES (
    upper(sqlc.arg('code')::text),
    sqlc.arg('name')::text,
    sqlc.arg('percent_off')::numeric,
    sqlc.arg('duration')::text,
    sqlc.narg('duration_periods')::int,
    COALESCE(sqlc.narg('valid_from')::timestamptz, now()),
    sqlc.arg('valid_until')::timestamptz,
    sqlc.arg('max_redemptions')::int,
    sqlc.narg('applies_to_tiers')::text[],
    sqlc.narg('applies_to_cycles')::text[],
    sqlc.arg('new_customers_only')::bool,
    sqlc.arg('channels')::text[],
    sqlc.narg('created_by')::uuid,
    sqlc.arg('reason')::text
)
RETURNING *;

-- name: GetDiscountCodeByCode :one
SELECT * FROM discount_codes
WHERE upper(code) = upper(sqlc.arg('code')::text);

-- name: GetDiscountCodeByID :one
SELECT * FROM discount_codes WHERE id = $1;

-- name: ListDiscountCodes :many
-- @include_inactive = false zwraca tylko aktywne (niezależnie od terminu —
-- wygasłe kody zostają na liście, panel pokazuje je jako "wygasł").
SELECT * FROM discount_codes
WHERE (sqlc.arg('include_inactive')::bool OR is_active = TRUE)
ORDER BY created_at DESC
LIMIT 500;

-- name: SetDiscountCodeStripeIDs :exec
UPDATE discount_codes
   SET stripe_coupon_id = $2,
       stripe_promotion_code_id = $3,
       updated_at = now()
 WHERE id = $1;

-- name: UpdateDiscountCode :one
-- Pola nieustawione (NULL) zostają bez zmian — ta sama semantyka co
-- UpdateProfile w identity-svc.
UPDATE discount_codes
   SET name            = COALESCE(sqlc.narg('name')::text, name),
       valid_until     = COALESCE(sqlc.narg('valid_until')::timestamptz, valid_until),
       max_redemptions = COALESCE(sqlc.narg('max_redemptions')::int, max_redemptions),
       is_active       = COALESCE(sqlc.narg('is_active')::bool, is_active),
       deactivated_at  = CASE
                            WHEN sqlc.narg('is_active')::bool IS FALSE THEN now()
                            WHEN sqlc.narg('is_active')::bool IS TRUE  THEN NULL
                            ELSE deactivated_at
                         END,
       updated_at      = now()
 WHERE id = sqlc.arg('id')
RETURNING *;

-- name: CountCommittedRedemptions :one
SELECT COUNT(*) FROM discount_code_redemptions
WHERE code_id = $1 AND status IN ('RESERVED', 'COMMITTED');

-- name: GetRedemptionForOrg :one
SELECT * FROM discount_code_redemptions
WHERE code_id = $1 AND organization_id = $2;

-- name: ReserveRedemption :one
-- Idempotentne po (code_id, organization_id): ponowne wejście w checkout
-- z tym samym kodem nie tworzy drugiego wiersza. RELEASED wraca do
-- RESERVED, bo poprzednia sesja wygasła, a użytkownik próbuje znowu.
INSERT INTO discount_code_redemptions (
    code_id, organization_id, user_id, channel, provider_reference
) VALUES ($1, $2, sqlc.narg('user_id')::uuid, $3, sqlc.narg('provider_reference')::text)
ON CONFLICT (code_id, organization_id) DO UPDATE
    SET status = CASE WHEN discount_code_redemptions.status = 'RELEASED'
                      THEN 'RESERVED' ELSE discount_code_redemptions.status END,
        provider_reference = COALESCE(EXCLUDED.provider_reference, discount_code_redemptions.provider_reference),
        reserved_at = CASE WHEN discount_code_redemptions.status = 'RELEASED'
                           THEN now() ELSE discount_code_redemptions.reserved_at END
RETURNING *;

-- name: CommitRedemptionByReference :execrows
-- Wywoływane z webhooka Stripe'a po potwierdzeniu płatności.
UPDATE discount_code_redemptions
   SET status = 'COMMITTED', committed_at = now()
 WHERE code_id = $1 AND organization_id = $2 AND status = 'RESERVED';

-- name: ReleaseRedemption :execrows
UPDATE discount_code_redemptions
   SET status = 'RELEASED'
 WHERE code_id = $1 AND organization_id = $2 AND status = 'RESERVED';

-- name: SyncRedemptionsCount :exec
UPDATE discount_codes
   SET redemptions_count = (
        SELECT COUNT(*) FROM discount_code_redemptions
         WHERE code_id = discount_codes.id AND status = 'COMMITTED'
       ),
       updated_at = now()
 WHERE discount_codes.id = $1;

-- name: ListRedemptionsByCode :many
SELECT r.organization_id, r.channel, r.status, r.reserved_at, r.committed_at,
       COALESCE(o.legal_name, '') AS organization_name
  FROM discount_code_redemptions r
  LEFT JOIN organizations o ON o.id = r.organization_id
 WHERE r.code_id = $1
 ORDER BY r.reserved_at DESC
 LIMIT 200;

-- name: OrgHasPaidSubscriptionHistory :one
-- Dla `new_customers_only`: czy organizacja miała KIEDYKOLWIEK płatną
-- subskrypcję (dowolny status). Sam trial/beta nie dyskwalifikuje.
SELECT EXISTS (
    SELECT 1 FROM subscriptions s
     JOIN subscription_plans p ON p.id = s.plan_id
    WHERE s.organization_id = $1
      AND s.provider <> 'MANUAL'
) AS has_history;

-- name: ListReservedRedemptionCodesForOrg :many
-- Kody, których użycie ta organizacja zarezerwowała i jeszcze nie
-- domknęła. W praktyce zero albo jeden — checkout dopuszcza jeden kod.
SELECT code_id FROM discount_code_redemptions
WHERE organization_id = $1 AND status = 'RESERVED';
