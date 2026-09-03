-- 000105_discount_codes — katalog kodów rabatowych definiowanych w panelu admina.
--
-- docs/70 §6. Do tej pory rabaty istniały WYŁĄCZNIE jako Stripe Promotion
-- Codes zakładane ręcznie w dashboardzie, z nazwami zaszytymi w
-- marketing-site/src/lib/billing/plans.ts. Nie było ani listy, ani licznika
-- użyć, ani terminu po naszej stronie — panel nie miał czego pokazać.
--
-- Model: nasz katalog jest źródłem prawdy o TYM, co admin zdefiniował
-- (nazwa, termin, procent, limit użyć), a Stripe pozostaje SILNIKIEM
-- egzekwowania na webie: dla każdego kodu zakładamy coupon + promotion code
-- przez API i to Stripe atomowo pilnuje max_redemptions przy checkoucie.
-- `redemptions_count` u nas jest lustrem do panelu ("pozostało ok. N"),
-- nigdy nie rozstrzyga wyścigu o ostatnie użycie (docs/70 §6.4 D2).

CREATE TABLE IF NOT EXISTS discount_codes (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Kod wpisywany przez użytkownika. Normalizowany do wielkich liter w
    -- aplikacji; unikalność wymuszona indeksem na upper(code) poniżej.
    code                TEXT NOT NULL,
    -- Nazwa kampanii widoczna tylko w panelu ("Wczesni użytkownicy Q3").
    name                TEXT NOT NULL,

    percent_off         NUMERIC(5,2) NOT NULL
                        CHECK (percent_off > 0 AND percent_off <= 100),

    -- Jak długo rabat obowiązuje na subskrypcji (semantyka Stripe coupon):
    -- ONCE = pierwszy okres, REPEATING = duration_periods okresów,
    -- FOREVER = każde odnowienie. Domyślnie FOREVER — tak działają
    -- dzisiejsze ROWNOWAGA/ROZKWIT ("na zawsze").
    duration            TEXT NOT NULL DEFAULT 'FOREVER'
                        CHECK (duration IN ('ONCE', 'REPEATING', 'FOREVER')),
    duration_periods    INT
                        CHECK (duration <> 'REPEATING' OR duration_periods > 0),

    valid_from          TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until         TIMESTAMPTZ NOT NULL,
    max_redemptions     INT NOT NULL CHECK (max_redemptions > 0),
    -- Lustro liczby użyć COMMITTED. Nie jest ograniczeniem — patrz nagłówek.
    redemptions_count   INT NOT NULL DEFAULT 0 CHECK (redemptions_count >= 0),

    -- Zawężenie do planów/cykli. NULL = wszystkie. TEXT[] zamiast
    -- plan_tier[]/billing_cycle[]: tablice enumów wymuszają na sqlc/pgx
    -- własne typy kompozytowe, a wartości i tak walidujemy w handlerze
    -- przeciwko subscription_plans.
    applies_to_tiers    TEXT[],
    applies_to_cycles   TEXT[],
    new_customers_only  BOOLEAN NOT NULL DEFAULT FALSE,

    -- Kanały, w których kod działa. v1 = WEB (Stripe Checkout). APPLE /
    -- GOOGLE dochodzą razem z Apple Offer Codes i ofertami Play (docs/70
    -- §6.5) — w sklepach procent nie zmienia ceny produktu, więc kod musi
    -- się wtedy zmapować na przygotowaną ofertę, stąd kolumny *_offer_*.
    channels            TEXT[] NOT NULL DEFAULT ARRAY['WEB'],

    stripe_coupon_id          TEXT,
    stripe_promotion_code_id  TEXT,
    apple_offer_code_id       TEXT,
    google_offer_id           TEXT,

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_by          UUID REFERENCES users(id),
    -- Powód utworzenia (>= 10 znaków, jak każda mutacja SUPERWIZOR_ADMIN).
    reason              TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    deactivated_at      TIMESTAMPTZ
);

-- Kod jest case-insensitive: "rownowaga" i "ROWNOWAGA" to ten sam rabat.
CREATE UNIQUE INDEX IF NOT EXISTS ux_discount_codes_code
    ON discount_codes (upper(code));

CREATE INDEX IF NOT EXISTS ix_discount_codes_active
    ON discount_codes (valid_until DESC)
    WHERE is_active = TRUE;

-- Rezerwacja → potwierdzenie, ten sam dwufazowy wzorzec co
-- pending_reservations w kwotach: RESERVED przy tworzeniu sesji Checkout,
-- COMMITTED gdy webhook potwierdzi zapłatę, RELEASED gdy sesja wygaśnie.
CREATE TABLE IF NOT EXISTS discount_code_redemptions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code_id             UUID NOT NULL REFERENCES discount_codes(id) ON DELETE CASCADE,
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id             UUID REFERENCES users(id),
    channel             TEXT NOT NULL CHECK (channel IN ('WEB', 'APPLE', 'GOOGLE')),
    status              TEXT NOT NULL DEFAULT 'RESERVED'
                        CHECK (status IN ('RESERVED', 'COMMITTED', 'RELEASED')),
    -- checkout session id / subscription id / store transaction id
    provider_reference  TEXT,
    reserved_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    committed_at        TIMESTAMPTZ,

    -- Jedna organizacja = jedno użycie danego kodu (docs/70 §6.4 D3).
    UNIQUE (code_id, organization_id)
);

CREATE INDEX IF NOT EXISTS ix_discount_redemptions_org
    ON discount_code_redemptions (organization_id, reserved_at DESC);
