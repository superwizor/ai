-- Staging seed: 1 MANUAL PRO subscription + active counter dla pierwszej
-- istniejącej organizacji.
--
-- Idempotent — re-run nic nie zmienia jeśli subscription już istnieje
-- (constraint idx_subscriptions_one_active_per_org tego pilnuje).
--
-- Cel: pozwolić od razu po deployu testować quota flow przez grpcurl
-- bez czekania na Stripe checkout. Po slice 2 (Stripe webhook driver)
-- to przestanie być potrzebne — produkcyjne subskrypcje będą tworzone
-- automatycznie przez webhook handler.
--
-- UWAGA: migracja jest dla STAGING. W prod mamy organizations utworzone
-- przez prawdziwe ścieżki rejestracji — ten seed nigdy nie powinien tam
-- tworzyć "dziwnej" subskrypcji. Bezpieczeństwo: omijamy seed jeśli już
-- jest jakakolwiek subscription w bazie (sygnał że to prawdopodobnie
-- prod albo ktoś już ręcznie skonfigurował).

DO $$
DECLARE
    v_org_id          UUID;
    v_plan_id         UUID;
    v_subscription_id UUID;
    v_period_start    TIMESTAMPTZ := date_trunc('month', now());
    v_period_end      TIMESTAMPTZ := date_trunc('month', now()) + interval '1 month';
    v_existing_count  INT;
BEGIN
    -- Safety: jeśli już są subskrypcje w bazie, nie ruszamy.
    SELECT COUNT(*) INTO v_existing_count FROM subscriptions;
    IF v_existing_count > 0 THEN
        RAISE NOTICE 'Skipping staging seed — subscriptions table not empty (% rows)', v_existing_count;
        RETURN;
    END IF;

    -- Wybierz najstarszą (= pierwszą utworzoną) organizację. Brak orgs ⇒ skip.
    SELECT id INTO v_org_id
    FROM organizations
    WHERE deleted_at IS NULL
    ORDER BY created_at ASC
    LIMIT 1;

    IF v_org_id IS NULL THEN
        RAISE NOTICE 'Skipping staging seed — no organizations found';
        RETURN;
    END IF;

    -- PRO MONTHLY plan (40 tokens/period). Jeśli nie ma — coś poszło nie tak
    -- z 000029 i seed planu.
    SELECT id INTO v_plan_id
    FROM subscription_plans
    WHERE tier = 'PRO' AND cycle = 'MONTHLY' AND is_active = TRUE
    LIMIT 1;

    IF v_plan_id IS NULL THEN
        RAISE EXCEPTION 'PRO MONTHLY plan not found — migration 000029 not applied?';
    END IF;

    -- Subskrypcja MANUAL — provider_subscription_id musi być unikalne per provider,
    -- używamy organizacja_id jako sufiks żeby uniknąć kolizji jeśli ktoś re-run.
    INSERT INTO subscriptions (
        organization_id, plan_id, provider, provider_subscription_id,
        status, current_period_start, current_period_end
    ) VALUES (
        v_org_id, v_plan_id, 'MANUAL', 'manual-staging-' || v_org_id::text,
        'ACTIVE', v_period_start, v_period_end
    )
    RETURNING id INTO v_subscription_id;

    -- Active usage_counters dla bieżącego okresu.
    INSERT INTO usage_counters (
        subscription_id, period_start, period_end,
        tokens_used, tokens_reserved, tokens_limit
    ) VALUES (
        v_subscription_id, v_period_start, v_period_end,
        0, 0, 40
    );

    RAISE NOTICE 'Staging seed: created MANUAL PRO subscription % for org % (40 tokens, period % → %)',
        v_subscription_id, v_org_id, v_period_start, v_period_end;
END$$;
