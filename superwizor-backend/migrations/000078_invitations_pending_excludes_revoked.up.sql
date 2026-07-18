-- 000078: cofnięte zaproszenie klienta NIE blokuje ponownego (docs/42).
--
-- Bug (zgłoszony 2026-07-18): "Cofnij zaproszenie" + "Zaproś ponownie"
-- zwracało błąd. uq_invitations_patient_file_pending (000065) ma
-- predykat `accepted_at IS NULL AND invited_role = 'PATIENT'` — NIE
-- wyklucza wierszy z revoked_at (kolumna doszła dopiero w 000076). Więc
-- cofnięte zaproszenie (revoked_at ustawione, accepted_at NULL) wciąż
-- siedzi w indeksie i kolejny InviteClient trafia w unique_violation;
-- refresh-path go nie ratuje, bo GetPendingPatientInvitationByFile
-- filtruje revoked_at IS NULL i nie widzi cofniętego wiersza.
--
-- Fix: przebuduj indeks z dodatkowym `revoked_at IS NULL`. Skutek:
--   - revoke  → wiersz wypada z indeksu,
--   - re-invite → świeży INSERT bez kolizji,
--   - zwykłe re-invite żywego PENDING → nadal kolizja → refresh-path
--     (spójne, bo GetPendingPatientInvitationByFile też filtruje revoked).

DROP INDEX IF EXISTS uq_invitations_patient_file_pending;

CREATE UNIQUE INDEX uq_invitations_patient_file_pending
    ON invitations(patient_file_id)
    WHERE accepted_at IS NULL
      AND revoked_at IS NULL
      AND invited_role = 'PATIENT';
