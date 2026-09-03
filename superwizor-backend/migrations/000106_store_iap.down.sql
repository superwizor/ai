DELETE FROM app_config
 WHERE organization_id IS NULL
   AND key IN ('IAP_ENABLED_IOS', 'IAP_ENABLED_ANDROID', 'IAP_WEB_LINK_MODE', 'IAP_ALLOW_SANDBOX');

UPDATE subscription_plans
   SET apple_product_id = NULL, google_product_id = NULL, store_price_gross = NULL
 WHERE tier IN ('SOLO', 'PRO');

ALTER TABLE subscription_plans DROP COLUMN IF EXISTS store_price_gross;

DROP TABLE IF EXISTS pending_checkouts;
DROP TABLE IF EXISTS store_transactions;

ALTER TABLE subscriptions
    DROP COLUMN IF EXISTS pending_plan_id,
    DROP COLUMN IF EXISTS grace_until,
    DROP COLUMN IF EXISTS auto_renew,
    DROP COLUMN IF EXISTS store_product_id,
    DROP COLUMN IF EXISTS store_environment;
