-- Rola ONTOLOGY_EDITOR — ekspert kliniczny pracujacy w Ontology Studio.
--
-- Zakres: tworzy i edytuje wersje `draft`, zglasza je do przegladu,
-- zatwierdza CUDZE wersje (four-eyes). NIE aktywuje wersji na produkcji
-- — to zostaje wylacznie przy SUPERWIZOR_ADMIN (plan 16 sekcja 4.1,
-- adnotacja do D2 w dok. 11). Rozdzielenie jest celowe: ekspert
-- odpowiada za tresc, admin za to, co generuje raporty.
--
-- Dostep do panelu: wylacznie sekcja /admin/ontologies (wyjatek sekcyjny
-- w AdminGuard); reszta /admin/* pozostaje dla SUPERWIZOR_ADMIN.
--
-- Migracja jest SAMODZIELNA — bez innych instrukcji. Powod jak w
-- 000037: ALTER TYPE ADD VALUE nie znosi towarzystwa w jednej
-- transakcji, a golang-migrate stosuje kazdy plik .up.sql jako wlasna.

ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'ONTOLOGY_EDITOR';
