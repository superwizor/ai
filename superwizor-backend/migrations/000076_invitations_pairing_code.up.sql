-- docs/42: autoryzacja zaproszeń klienta (kod parowania + revoke).
--
-- pairing_code_hash  SHA-256 6-cyfrowego kodu przekazywanego pacjentowi
--                    POZA e-mailem (na sesji/telefonicznie). NULL =
--                    zaproszenie sprzed featury (grandfathered — accept
--                    bez kodu aż wygaśnie) albo zaproszenie nie-PATIENT.
-- code_attempts      licznik błędnych kodów; >=5 blokuje zaproszenie
--                    (terapeuta musi zaprosić ponownie: nowy token+kod,
--                    licznik od zera).
-- revoked_at         jawne cofnięcie zaproszenia PENDING przez
--                    terapeutę; unieważnia token natychmiast.
ALTER TABLE invitations
    ADD COLUMN pairing_code_hash BYTEA,
    ADD COLUMN code_attempts     INT NOT NULL DEFAULT 0,
    ADD COLUMN revoked_at        TIMESTAMPTZ;
