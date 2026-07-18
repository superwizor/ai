-- 000077: inwariant "jedyny identyfikator klienta = e-mail" (docs/43 §4).
--
-- 1. patient_files.patient_email (dodane w 000040) znika: e-mail klienta
--    przestaje byc duplikowany w domenie klinicznej. Trwale kopie to od
--    teraz WYLACZNIE invitations.email (TTL, domena identity) oraz
--    users.email po aktywacji konta. Odczyt "e-mail pacjenta" w API jest
--    rozwiazywany w locie: users.email -> ostatnie niecofniete
--    zaproszenie -> brak (patrz ResolvePatientEmail w patient_files.sql).
--
-- 2. patient_notes.sent_to_email zmienia semantyke: od teraz przechowuje
--    wersje ZAMASKOWANA ("p***@example.com") - wystarcza jako slad
--    audytowy DSAR "dokad wyslano", bez utrwalania pelnego adresu.
--    Istniejace wiersze maskujemy w miejscu.

ALTER TABLE patient_files DROP COLUMN IF EXISTS patient_email;

COMMENT ON COLUMN patient_notes.sent_to_email IS
  'MASKED recipient of the action-plan e-mail (e.g. p***@example.com). '
  'Full address is resolved at send time and never persisted (000077).';

UPDATE patient_notes
SET sent_to_email =
      left(sent_to_email, 1) || '***@' || split_part(sent_to_email, '@', 2)
WHERE sent_to_email IS NOT NULL
  AND sent_to_email LIKE '%@%'
  AND sent_to_email NOT LIKE '%***@%';
