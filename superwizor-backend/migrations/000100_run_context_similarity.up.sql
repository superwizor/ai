-- 000100: podobieństwo przy wpisie kontekstu (plan F7b-2, dok. 65 §N2).
--
-- Okno deterministyczne nie ma czego zapisywać poza faktem wyboru: sesja
-- albo mieści się w oknie, albo nie. Wyszukiwanie semantyczne wybiera
-- inaczej — bierze N najbliższych sąsiadów i odcina progiem — więc bez
-- zapisanej odległości nie da się później odpowiedzieć na jedyne pytanie,
-- które przy strojeniu ma sens: „czy próg był za wysoki, czy materiału
-- naprawdę nie było".
--
-- NULL dla kanału `window`: tam liczba nie znaczy nic i udawanie, że
-- znaczy, byłoby gorsze niż jej brak.

ALTER TABLE report_run_context
    ADD COLUMN IF NOT EXISTS similarity REAL;

COMMENT ON COLUMN report_run_context.similarity IS
    'Podobieństwo kosinusowe (1 - odległość) dla kanału semantycznego. '
    'NULL dla okna deterministycznego — tam selekcja nie ma miary.';

-- Liczniki kanału semantycznego. „Zero trafień" ma trzy różne
-- znaczenia — flaga wyłączona, brak materiału, próg za wysoki — i bez
-- tych kolumn są nieodróżnialne.
ALTER TABLE report_run_context_stats
    ADD COLUMN IF NOT EXISTS semantic_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS semantic_found INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS semantic_below_threshold INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN report_run_context_stats.semantic_below_threshold IS
    'Sąsiedzi odrzuceni progiem. Materiał do kalibracji (F7b-4): dużo '
    'odrzuconych przy zerze przyjętych znaczy „próg za wysoki", a nie '
    '„brak historii".';
