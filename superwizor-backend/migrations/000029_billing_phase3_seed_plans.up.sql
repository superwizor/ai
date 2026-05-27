-- Seed katalogu planów dla Phase 3.
--
-- Wartości tokens_per_period są wstępne — finalne mogą zostać zmienione
-- przed launchem komercyjnym przez UPDATE bez kodu (ADR-DM-017).
--
-- stripe_price_id zostawiamy NULL — będą wstrzyknięte ręcznie per
-- środowisko (staging vs prod) po utworzeniu produktów w Stripe Dashboard.
-- Brak stripe_price_id w staging = nie da się przejść checkout flow,
-- ale wszystkie wewnętrzne ścieżki (CheckQuota, ReserveCredit, CommitUsage)
-- są niezależne od Stripe i działają z planami w trybie MANUAL.

INSERT INTO subscription_plans (
    tier, cycle, display_name, price_gross, currency_code,
    tokens_per_period, licenses_limit, has_b2b_dashboard,
    marketing_description, is_active
) VALUES
    -- SOLO: solo therapist, monthly
    ('SOLO', 'MONTHLY', 'Solo Monthly', 149.00, 'PLN',
     20, 1, FALSE,
     'Plan dla terapeutów indywidualnych — 20 sesji miesięcznie.', TRUE),

    -- SOLO: solo therapist, annual (~17% discount)
    ('SOLO', 'ANNUAL', 'Solo Annual', 1490.00, 'PLN',
     240, 1, FALSE,
     'Plan roczny dla terapeutów indywidualnych — 240 sesji rocznie (oszczędność ~2 miesięcy).', TRUE),

    -- PRO: power user, monthly
    ('PRO', 'MONTHLY', 'Pro Monthly', 249.00, 'PLN',
     40, 1, FALSE,
     'Plan dla terapeutów intensywnie korzystających — 40 sesji miesięcznie.', TRUE),

    -- PRO: power user, annual
    ('PRO', 'ANNUAL', 'Pro Annual', 2490.00, 'PLN',
     480, 1, FALSE,
     'Plan roczny PRO — 480 sesji rocznie.', TRUE),

    -- CLINIC: small clinic (5 licenses)
    ('CLINIC', 'MONTHLY', 'Clinic Monthly (5 licenses)', 999.00, 'PLN',
     150, 5, TRUE,
     'Plan dla małych klinik — pula 150 sesji miesięcznie dzielona między 5 terapeutów.', TRUE),

    ('CLINIC', 'ANNUAL', 'Clinic Annual (5 licenses)', 9990.00, 'PLN',
     1800, 5, TRUE,
     'Plan roczny dla małych klinik — pula 1800 sesji rocznie + dashboard B2B.', TRUE);
