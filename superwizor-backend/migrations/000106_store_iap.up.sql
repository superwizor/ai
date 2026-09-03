-- 000106_store_iap — zakupy w aplikacji (App Store / Google Play) jako
-- trzeci i czwarty dostawca płatności obok Stripe'a i MANUAL.
--
-- docs/70 §7.1. Fundament już istniał: enum payment_provider ma APPLE_IAP i
-- GOOGLE_IAP od migracji 000002, a subscription_plans ma apple_product_id /
-- google_product_id od 000028 (obie kolumny puste do dziś). Ta migracja
-- dokłada to, czego brakowało: stan subskrypcji sklepowej, dziennik
-- transakcji i zabezpieczenie przed równoległym zakupem w dwóch kanałach.
--
-- Zasada nadrzędna: idx_subscriptions_one_active_per_org zostaje nietknięty.
-- Organizacja ma najwyżej jedną aktywną subskrypcję, niezależnie od tego,
-- kto ją sprzedał — sklep jest kolejnym źródłem tego samego wiersza.

-- ── subscriptions: stan specyficzny dla sklepów ────────────────────────────
ALTER TABLE subscriptions
    -- 'Production' | 'Sandbox'. Recenzent Apple i TestFlight kupują w
    -- Sandboxie, ale uderzają w PRODUKCYJNY backend (docs/70 E19) — bez tej
    -- kolumny zakupy testowe byłyby nieodróżnialne od prawdziwych w
    -- raportach przychodu.
    ADD COLUMN IF NOT EXISTS store_environment TEXT
        CHECK (store_environment IS NULL OR store_environment IN ('Production', 'Sandbox')),
    -- Identyfikator produktu w sklepie (ai.superwizor.solo.monthly / solo:monthly).
    ADD COLUMN IF NOT EXISTS store_product_id TEXT,
    -- Czy sklep odnowi subskrypcję. NULL dla Stripe/MANUAL (tam rolę tę
    -- pełni cancel_at_period_end).
    ADD COLUMN IF NOT EXISTS auto_renew BOOLEAN,
    -- Billing grace period (Apple 3-28 dni, Google 3-30 dni). Sklep wymaga
    -- ciągłości dostępu mimo nieudanego obciążenia; trzymamy status ACTIVE
    -- i przedłużamy bieżący licznik do tej daty, BEZ nowej puli (docs/70 E13).
    ADD COLUMN IF NOT EXISTS grace_until TIMESTAMPTZ,
    -- Downgrade i zmiana cyklu w dół wchodzą dopiero od następnego
    -- odnowienia (Apple DID_CHANGE_RENEWAL_PREF, Google DEFERRED).
    ADD COLUMN IF NOT EXISTS pending_plan_id UUID REFERENCES subscription_plans(id);

COMMENT ON COLUMN subscriptions.grace_until IS
    'Koniec billing grace period ze sklepu. Status zostaje ACTIVE, licznik przedłużony do tej daty bez nowej puli (docs/70 E13).';

-- ── store_transactions — dziennik transakcji sklepowych ────────────────────
-- payment_events pozostaje surowym strumieniem zdarzeń (jak dla Stripe'a);
-- ta tabela trzyma ZWERYFIKOWANY stan pojedynczej transakcji, po którym
-- można odtworzyć uprawnienie bez ponownego odpytywania sklepu.
CREATE TABLE IF NOT EXISTS store_transactions (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider                 payment_provider NOT NULL
                             CHECK (provider IN ('APPLE_IAP', 'GOOGLE_IAP')),
    -- Apple: transactionId. Google: orderId (może być puste dla darmowych
    -- okresów — wtedy syntetyzujemy z purchaseToken + product).
    transaction_id           TEXT NOT NULL,
    -- Klucz łańcucha odnowień. Apple: originalTransactionId (stały przez całe
    -- życie subskrypcji, także po resubscribe). Google: purchaseToken korzenia
    -- łańcucha linkedPurchaseToken. To jest wartość, która ląduje w
    -- subscriptions.provider_subscription_id.
    original_transaction_id  TEXT NOT NULL,
    organization_id          UUID REFERENCES organizations(id) ON DELETE SET NULL,
    user_id                  UUID REFERENCES users(id) ON DELETE SET NULL,
    product_id               TEXT NOT NULL,
    purchase_date            TIMESTAMPTZ NOT NULL,
    expires_date             TIMESTAMPTZ,
    environment              TEXT NOT NULL DEFAULT 'Production'
                             CHECK (environment IN ('Production', 'Sandbox')),
    -- appAccountToken (Apple) / obfuscatedExternalAccountId (Google) = nasz
    -- organization_id wysłany do sklepu przy zakupie. Jedyne wiązanie
    -- transakcji z kontem — e-mail ani tożsamość płatnicza do nas nie trafiają.
    app_account_token        UUID,
    -- Oferta promocyjna (Apple offerType 1-4 + offerIdentifier, Google offerId).
    offer_type               TEXT,
    offer_identifier         TEXT,
    revocation_date          TIMESTAMPTZ,
    revocation_reason        TEXT,
    -- Zweryfikowany payload (JWS po walidacji podpisu / odpowiedź Play API).
    -- Bez danych osobowych ze sklepu.
    raw_payload              JSONB NOT NULL DEFAULT '{}'::jsonb,
    verified_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (provider, transaction_id)
);

CREATE INDEX IF NOT EXISTS ix_store_tx_org
    ON store_transactions (organization_id, purchase_date DESC);
CREATE INDEX IF NOT EXISTS ix_store_tx_original
    ON store_transactions (provider, original_transaction_id);

-- ── pending_checkouts — jeden kanał zakupu naraz ───────────────────────────
-- docs/70 E22: Checkout Stripe otwarty w przeglądarce i równoległy zakup IAP
-- kończą się dwiema płatnościami za tę samą organizację, a zwrot po stronie
-- Apple'a nie jest w naszej mocy. Wiersz żyje do expires_at (30 min dla
-- sklepu, 24 h dla sesji Stripe) i blokuje drugi kanał.
CREATE TABLE IF NOT EXISTS pending_checkouts (
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    channel         TEXT NOT NULL CHECK (channel IN ('WEB', 'APPLE', 'GOOGLE')),
    reference       TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (organization_id, channel)
);

CREATE INDEX IF NOT EXISTS ix_pending_checkouts_expiry
    ON pending_checkouts (expires_at);

-- ── subscription_plans: cena sklepowa (referencyjna) ───────────────────────
-- Aplikacja ZAWSZE wyświetla cenę zwróconą przez StoreKit/Play w walucie
-- użytkownika. Ta kolumna służy panelowi admina i analityce marży.
ALTER TABLE subscription_plans
    ADD COLUMN IF NOT EXISTS store_price_gross NUMERIC(10,2)
        CHECK (store_price_gross IS NULL OR store_price_gross >= 0);

COMMENT ON COLUMN subscription_plans.store_price_gross IS
    'Cena w sklepach = cena web +15% zaokrąglona do punktu cenowego Apple (docs/70 §3.1). Referencyjna: aplikacja pokazuje displayPrice ze StoreKit/Play.';

-- Mapowanie produktów sklepowych na plany. Identyfikatory są kontraktem z
-- App Store Connect i Play Console — muszą zgadzać się co do znaku.
-- Ceny: 149 → 174,99; 1490 → 1749; 299 → 349,99; 2990 → 3449 (docs/70 §3.1,
-- do potwierdzenia w D1 razem z punktami cenowymi Apple).
UPDATE subscription_plans SET
    apple_product_id  = 'ai.superwizor.solo.monthly',
    google_product_id = 'solo:monthly',
    store_price_gross = 174.99
WHERE tier = 'SOLO' AND cycle = 'MONTHLY' AND is_active = TRUE;

UPDATE subscription_plans SET
    apple_product_id  = 'ai.superwizor.solo.annual',
    google_product_id = 'solo:annual',
    store_price_gross = 1749.00
WHERE tier = 'SOLO' AND cycle = 'ANNUAL' AND is_active = TRUE;

UPDATE subscription_plans SET
    apple_product_id  = 'ai.superwizor.pro.monthly',
    google_product_id = 'pro:monthly',
    store_price_gross = 349.99
WHERE tier = 'PRO' AND cycle = 'MONTHLY' AND is_active = TRUE;

UPDATE subscription_plans SET
    apple_product_id  = 'ai.superwizor.pro.annual',
    google_product_id = 'pro:annual',
    store_price_gross = 3449.00
WHERE tier = 'PRO' AND cycle = 'ANNUAL' AND is_active = TRUE;

-- ── Flagi zdalne (docs/70 E26) ─────────────────────────────────────────────
-- Sprzedaż w sklepach startuje WYŁĄCZONA. Włączenie nie wymaga wydania
-- aplikacji ani deployu backendu — pkg/appconfig czyta te klucze z 30 s cache.
--
--   IAP_ENABLED_IOS / IAP_ENABLED_ANDROID — czy paywall w aplikacji sprzedaje
--   IAP_WEB_LINK_MODE — NONE | TEXT | LINK: czy aplikacja może wspominać o
--       zakupie na WWW (poza UE zabronione; w UE zależy od warunków DMA)
--   IAP_ALLOW_SANDBOX — czy akceptujemy zakupy Sandbox (recenzja Apple,
--       TestFlight, testerzy Play)
INSERT INTO app_config (key, value, note)
VALUES
    ('IAP_ENABLED_IOS',     'false', 'docs/70 E26 — sprzedaż IAP w aplikacji iOS. Włączyć dopiero po zatwierdzeniu produktów w App Store Connect.'),
    ('IAP_ENABLED_ANDROID', 'false', 'docs/70 E26 — sprzedaż IAP w aplikacji Android. Włączyć po aktywacji subskrypcji w Play Console.'),
    ('IAP_WEB_LINK_MODE',   'NONE',  'docs/70 R6 — NONE | TEXT | LINK. Wzmianka o zakupie na superwizor.ai w aplikacji. NONE jest jedynym bezpiecznym trybem bez analizy DMA.'),
    ('IAP_ALLOW_SANDBOX',   'true',  'docs/70 E19 — akceptuj zakupy Sandbox (recenzja Apple / TestFlight / testerzy Play). Subskrypcje sandbox są oznaczone i wykluczone z analityki przychodu.')
ON CONFLICT DO NOTHING;
