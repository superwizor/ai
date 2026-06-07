# Sesja: Integracja Stripe, Uruchomienie Analityki i Zgodność RODO (Faza P0)

**Data:** 2026-06-07  
**Cel sesji:** Dokończenie integracji systemu płatności Stripe (Sandbox), wdrożenie logiki przejścia między subskrypcjami (dezaktywacja starych), poprawki modułu analitycznego Terraform/BigQuery na środowisku staging oraz weryfikacja i testy E2E mechanizmów zgodności z RODO/GDPR (Faza P0).

---

## 🛠 Zmiany w kodzie i plikach

### Warstwa Bilingu i Płatności (`billing-svc`)
*   `superwizor-backend/services/billing-svc/internal/adapters/http/stripe_handler.go` - Zaktualizowano metodę `upsertSubscriptionFromStripe` tak, aby cała operacja (wyszukanie planu, deaktywacja innych subskrypcji, upsert nowej subskrypcji Stripe oraz utworzenie pierwszego licznika użycia `usage_counters`) odbywała się w ramach jednej transakcji bazodanowej.
*   `superwizor-backend/services/billing-svc/internal/adapters/postgres/queries/subscriptions.sql` - Dodano zapytanie `DeactivateOtherActiveSubscriptions` dezaktywujące (zmieniające status na `CANCELED`) inne dotychczas aktywne subskrypcje danej organizacji w bazie w celu spełnienia warunku unikalności.
*   `superwizor-backend/services/billing-svc/internal/adapters/postgres/db/` - Zregenerowano kod dostępu do bazy danych za pomocą `sqlc generate` (nowe zapytanie i parametry).

### Dokumentacja i Skrypty Testowe
*   `docs/27_STRIPE_INTEGRATION_AND_FUTURE_WORK.md` - Utworzono szczegółowy dokument opisujący mechanizmy bilingu, konfigurację webhooków, gwarancje bezpieczeństwa, weryfikację sygnatur oraz plan dalszych prac produkcyjnych (VAT, Customer Portal, B2B).
*   `superwizor-backend/brain/.../scratch/test_stripe_webhook.go` - Zaktualizowano lokalny skrypt testujący webhooki pod kątem lokalnej instancji serwera (port 8081).

---

## 🏗 Architektura i Decyzje (Stripe / RODO / Backend)

*   **Bezpieczna logika migracji planów (Transition Logic):** Unikalny indeks `idx_subscriptions_one_active_per_org` zabezpiecza bazę danych przed posiadaniem więcej niż jednej aktywnej subskrypcji per organizacja. Wprowadziliśmy zasadę, że nadejście zdarzenia `customer.subscription.created` (lub analogicznego) ze Stripe automatycznie, transakcyjnie anuluje (`CANCELED`) starsze subskrypcje (np. domyślnie przyznany `TRIAL` lub `MANUAL`). Zapobiega to rzucaniu błędów naruszenia klucza w bazie.
*   **RODO (GDPR) Faza P0:** Zweryfikowaliśmy wdrożenie mechanizmów usuwania danych (hard-delete za pomocą codziennego Joba `/purger` w Cloud Run), soft-deletowania kartotek i użytkowników-pacjentów oraz deszyfrowania i eksportu danych DSAR przy użyciu kluczy KMS (`pkg/cryptobox`).
*   **Poprawność analityk (Pub/Sub → BigQuery):** Wdrożyliśmy poprawki w modułach Terraform analityki (naprawa literówki `drop_unknown_metadata` -> `drop_unknown_fields` oraz aktywacja `use_table_schema = true`), co pozwoliło na prawidłowe przepływanie zdarzeń JSON bezpośrednio do tabel BigQuery.

---

## 🚨 Znane problemy i Dług Technologiczny

*   [ ] Zintegrowanie oficjalnego Stripe Go SDK w `billing-svc` zamiast ręcznego parsowania JSON w przyszłych etapach (obsługa zwrotów, kuponów).
*   [ ] Konfiguracja Stripe Tax (23% VAT) i automatycznego fakturowania EU VAT.
*   [ ] Wprowadzenie Restricted API Keys zamiast standardowych Secret Keys dla środowiska produkcyjnego.

---

## 🎯 Następne kroki (Next Actions)

1.  **Stripe Customer Portal:** Dodanie na frontendzie (marketing-site / admin) przycisku pozwalającego użytkownikowi na samodzielne wejście do portalu billingowego Stripe w celu zarządzania subskrypcją.
2.  **Podpięcie i wdrożenie na Staging:** Wdrożenie nowej wersji `billing-svc` na Cloud Run Staging i przetestowanie e2e rejestracji i zakupu planu z przekierowaniem do rzeczywistej aplikacji (`https://app.superwizor.ai/`).
