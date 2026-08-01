-- Odwrócenie 000082: przywraca przed-000070 wartości katalogowe tym
-- licznikom, które dziś niosą wartość bieżącą.
--
-- UWAGA: to jest odwrócenie NIEDOKŁADNE i takie musi być. Po migracji
-- w górę licznik z limitem 90 na planie PRO Monthly jest nieodróżnialny
-- od licznika, który miał 90 od początku (utworzonego po 000070).
-- Cofnięcie obniży oba. Zejście w dół jest tu operacją awaryjną —
-- obniża limit, więc klient z zużyciem powyżej starej wartości znajdzie
-- się nad limitem. Warunek tokens_used <= stara wartość chroni przed
-- tym najgorszym skutkiem, kosztem tego, że część wierszy nie wróci.

UPDATE usage_counters c
SET tokens_limit = v.old_limit,
    updated_at   = now()
FROM subscriptions s
JOIN subscription_plans p ON p.id = s.plan_id
JOIN (VALUES
        ('PRO',  'MONTHLY', 90,   40),
        ('PRO',  'ANNUAL',  1080, 480),
        ('SOLO', 'ANNUAL',  360,  240)
     ) AS v(tier, cycle, new_limit, old_limit)
  ON v.tier = p.tier::text AND v.cycle = p.cycle::text
WHERE c.subscription_id = s.id
  AND c.period_end > now()
  AND c.tokens_limit = v.new_limit
  AND c.tokens_used <= v.old_limit;
