-- 000095: uzasadnienia ODRZUCONYCH twierdzeń (dostrajanie potoku).
--
-- ══ Zmiana decyzji z migracji 000093 ══
--
-- 000093 zakładała, że rejestr odrzuceń trzyma sam kod reguły i konstrukt:
-- „Bez tresci twierdzenia — sam kod reguly i konstrukt". Założenie padło
-- przy pierwszym prawdziwym przebiegu.
--
-- Kanarek CBT (2026-08-23) odrzucił trzy twierdzenia na wartości "2" bez
-- pokrycia w spanie. Nie dało się ustalić, czy model sfabrykował precyzję
-- („wraca 2 razy" — R9 działa poprawnie), czy odwołał się do numeracji
-- własnego modelu („ogniwo 2" — fałszywy alarm). Dwie przeciwstawne
-- diagnozy, ta sama linijka w rejestrze, zero możliwości rozstrzygnięcia.
--
-- Progi dowodowe (`min_evidence`), katalogi `values` i prompty stroi się
-- na PRZYKŁADACH. Przykład, który przepadł, nie stroi niczego — a to
-- właśnie odrzucenia niosą najwięcej informacji o tym, gdzie ontologia
-- albo prompt rozjeżdża się z materiałem.
--
-- ══ Co to zmienia dla danych ══
--
-- Tabela zaczyna nieść materiał kliniczny, więc uzasadnienie i cytaty są
-- szyfrowane kopertowo, dokładnie jak w report_claims. Retencja się NIE
-- wydłuża: wiersze kasują się kaskadowo z raportem (FK z 000093), więc
-- usunięcie raportu usuwa też jego odrzucenia — tak samo jak twierdzenia
-- zatwierdzone.
--
-- Kolumny strukturalne (kategorie, status, odnośniki do spanów) zostają
-- JAWNE: bez nich nie da się policzyć, ile razy model proponował daną
-- kategorię, a to jest właśnie pytanie, które zadaje benchmark.

ALTER TABLE report_claim_rejections
    -- Uzasadnienie modelu — dlaczego uważał, że twierdzenie jest zasadne.
    ADD COLUMN IF NOT EXISTS reasoning_ciphertext    BYTEA,
    ADD COLUMN IF NOT EXISTS reasoning_encrypted_dek BYTEA,

    -- Kategorie ZAPROPONOWANE przez model. Puste dla odrzuceń, które nie
    -- dotyczą pojedynczego twierdzenia (konstrukt spoza ontologii,
    -- degradacja `requires`).
    ADD COLUMN IF NOT EXISTS proposed_categories     TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS epistemic_status        TEXT,
    ADD COLUMN IF NOT EXISTS confidence              NUMERIC(4, 3),

    -- Odnośniki do spanów, na które model się powoływał. Jako TEXT[], nie
    -- tabela łącząca: wiersz odrzucenia jest materiałem do analizy, a nie
    -- częścią grafu raportu — nic z niego nie wychodzi klikalnym cytatem.
    ADD COLUMN IF NOT EXISTS evidence_span_refs      TEXT[] NOT NULL DEFAULT '{}';

COMMENT ON TABLE report_claim_rejections IS
    'Rejestr odrzuceń walidatora (S3) i naruszeń weryfikatora (S5). Od '
    'migracji 000095 niesie także uzasadnienie odrzuconego twierdzenia — '
    'szyfrowane, kasowane kaskadowo z raportem. Powód zmiany: progi i '
    'prompty stroi się na przykładach, a przykład bez treści nie stroi '
    'niczego (kanarek CBT 2026-08-23).';

COMMENT ON COLUMN report_claim_rejections.reasoning_ciphertext IS
    'Uzasadnienie modelu dla odrzuconego twierdzenia. NULL dla odrzuceń '
    'niezwiązanych z pojedynczym twierdzeniem.';

COMMENT ON COLUMN report_claim_rejections.evidence_span_refs IS
    'span_ref spanów, na które powoływało się odrzucone twierdzenie. Bez '
    'FK do report_spans: to materiał do analizy, nie część grafu raportu.';
