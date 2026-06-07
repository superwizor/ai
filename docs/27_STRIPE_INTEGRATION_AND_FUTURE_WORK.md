# 27. Integracja ze Stripe — Status Wdrożenia i Prace Przyszłe

Dokument podsumowuje wykonane prace nad integracją płatności Stripe w systemie SuperWizor AI (środowisko Staging/Sandbox) oraz definiuje mapę drogową (roadmap) kolejnych kroków przed wejściem na produkcję.

---

## 1. Wykonane Prace i Zaimplementowane Mechanizmy

Zakończyliśmy kluczowy etap integracji Stripe z usługą `billing-svc` na poziomie backendu oraz bazy danych. Zaimplementowane funkcjonalności obejmują:

### A. Konfiguracja Bezpieczeństwa (GCP Secret Manager)
*   **Zarządzanie kluczami:** Webhook secret dla środowiska testowego (`whsec_...`) został bezpiecznie wdrożony do GCP Secret Manager jako `stripe-webhook-secret`.
*   **Uprawnienia IAM:** Dodaliśmy reguły Terraform przyznające tożsamości `billing-svc` rolę `roles/secretmanager.secretAccessor`.
*   **Montowanie sekretu:** W usłudze Cloud Run sekret jest wstrzykiwany jako zmienna środowiskowa `STRIPE_WEBHOOK_SECRET` w kontenerze, dzięki czemu kod nie zawiera żadnych twardo zakodowanych kluczy.

### B. Ręczna Weryfikacja Sygnatury (Zero-Deps Signature Verification)
*   **Bezpieczeństwo webhooka:** Zaimplementowaliśmy walidację nagłówka `Stripe-Signature` (zawierającego timestamp `t` i sygnatury `v1`) w Go, bezpośrednio na strumieniu bajtów body, bez zewnętrznych zależności SDK.
*   **Zgodność ze specyfikacją Stripe:** Obliczamy HMAC-SHA256 z payloadu `timestamp.body` przy użyciu klucza webhooka i porównujemy go z sygnaturą w nagłówku, zapewniając ochronę przed atakami typu Replay (maksymalne odchylenie czasu: 300 sekund).

### C. Gwarancja Idempotentności (Zero Data Loss)
*   **Ochrona przed duplikatami:** Każde przychodzące zdarzenie Stripe jest logowane w tabeli `payment_events`. Założony klucz unikalny `UNIQUE(provider, provider_event_id)` w połączeniu z klauzulą `ON CONFLICT DO NOTHING` gwarantuje, że podwójne wysłanie tego samego zdarzenia przez Stripe zostanie zignorowane i zwróci status `200 OK`.

### D. Logika Przejścia i Rozwiązywanie Konfliktów (Transition Logic)
*   **Problem:** Indeks unikalny bazy danych `idx_subscriptions_one_active_per_org` gwarantuje, że organizacja może posiadać maksymalnie jedną aktywną (`ACTIVE`, `TRIALING` lub `PAST_DUE`) subskrypcję w danym momencie.
*   **Rozwiązanie:** W metodzie `upsertSubscriptionFromStripe` dodaliśmy transakcyjną operację deaktywacji. Zanim nowa subskrypcja Stripe zostanie wprowadzona w stan aktywny, zapytanie SQL `DeactivateOtherActiveSubscriptions` automatycznie przenosi dotychczasowe subskrypcje (np. domyślnie przypisywany przy rejestracji okres próbny `TRIAL` lub subskrypcję `MANUAL`) w stan `CANCELED`. Chroni to system przed przerwaniem transakcji i rzuceniem błędu unikalności bazy.

### E. Mapowanie Planów i Reset Limitów
*   **Zsynchronizowane ceny:** Skonfigurowaliśmy cztery taryfy w bazie i na Stripe:
    *   **Solo Monthly** (`price_1TclVgE5jzWcAIgeT6ec0HDh`) – limit 20 tokenów
    *   **Solo Annual** (`price_1TclVhE5jzWcAIge7YjI49Hs`) – limit 20 tokenów
    *   **Pro Monthly** (`price_1TclVhE5jzWcAIgeMQTPps4i`) – limit 40 tokenów
    *   **Pro Annual** (`price_1TclViE5jzWcAIgehEFNihUP`) – limit 40 tokenów
*   **Reset limitu (ADR-BL-003):** Obsługa zdarzenia `invoice.paid` resetuje zużycie na początku nowego okresu rozliczeniowego poprzez automatyczne utworzenie nowego wiersza w tabeli `usage_counters` z zerowym licznikiem zużytych tokenów (`tokens_used = 0`).

---

## 2. Status Weryfikacji (Testy)

*   **Testy E2E (Go):** Uruchomienie `go test -tags=e2e ./e2e/... -run TestBilling` potwierdza poprawność zliczania tokenów, rezerwowania limitu przed wysłaniem audio (`ReserveCredit`) i ostatecznego zatwierdzania zużycia po transkrypcji (`CommitUsage`). Wszystkie 14 testów kończy się wynikiem **PASS**.
*   **Symulacja Webhooka:** Przeprowadziliśmy pomyślny test integracyjny za pomocą skryptu [test_stripe_webhook.go](file:///Users/maciekckoklormam91/.gemini/antigravity-ide/brain/2aa0f425-edb8-4917-87e4-a279accb8ac7/scratch/test_stripe_webhook.go), symulując nadejście zdarzenia `customer.subscription.created`. Baza danych prawidłowo dokonała przejścia z planu `MANUAL` na `STRIPE` (Solo), dezaktywując poprzednią subskrypcję.

---

## 3. Prace Przyszłe (Roadmap do Produkcji)

Przed oficjalnym uruchomieniem produkcyjnym (go-live) należy zaadresować następujące kwestie:

### A. Wdrożenie Oficjalnego Stripe Go SDK
*   **Powód:** Do prostej weryfikacji webhooków i podstawowych statusów surowy JSON był wystarczający i lekki. Jednak w przyszłości (tworzenie sesji checkoutu z poziomu backendu, obsługa kuponów, podatków czy zwrotów) korzystanie z oficjalnej biblioteki `github.com/stripe/stripe-go/v78` ułatwi utrzymanie kodu i uchroni przed błędami parsowania.

### B. Integracja z Portalem Klienta (Customer Portal)
*   **Cel:** Zapewnienie terapeutom możliwości samodzielnego zarządzania płatnościami (anulowanie subskrypcji, zmiana karty płatniczej, pobieranie faktur).
*   **Zadanie:** Dodanie w `billing-svc` endpointu generującego link do sesji Stripe Customer Portal (metoda `stripe.billingportal.session.create`) i wyświetlenie go w ustawieniach konta na frontendzie.

### C. Obsługa Podatków i Faktur (EU VAT Compliance)
*   **Cel:** Zgodność z przepisami Rzeczypospolitej Polskiej i Unii Europejskiej w zakresie podatku VAT (B2B i B2C).
*   **Zadanie:** 
    *   Włączenie i konfiguracja **Stripe Tax** w panelu produkcyjnym Stripe.
    *   Dostosowanie formularza rejestracji / checkoutu, aby zbierał i walidował NIP firmy (EU VAT Number) dla klientów B2B (terapeuci prowadzący jednoosobową działalność gospodarczą).
    *   Ustawienie automatycznego wystawiania faktur uproszczonych/pełnych po stronie Stripe i wysyłki na maila klienta.

### D. Obsługa Subskrypcji B2B (Multi-license / Zespoły)
*   **Problem:** Obecne mapowanie zakłada model jednoosobowy (Solo/Pro). Wersja dla klinik i centrów terapeutycznych (B2B Dashboard) będzie wymagała zakupu wielu licencji.
*   **Zadanie:** Rozbudowa handlera webhooka o odczyt liczby subskrybowanych stanowisk (`quantity` w subskrypcji Stripe) i aktualizacja pola `licenses_limit` w tabeli `subscriptions`.

### E. Monitoring i Obsługa Błędów Webhooków
*   **Zadanie:** 
    *   Skonfigurowanie powiadomień Slack / Sentry w przypadku, gdy handler webhooka zwróci status błędu (np. `500 Internal Server Error`).
    *   Zaprojektowanie jasnego przepływu dla statusu `PAST_DUE` (np. wysłanie maila z ostrzeżeniem za pośrednictwem `notification-svc` przed całkowitym zablokowaniem dostępu do aplikacji).

### F. Procedura Przejścia na Produkcję (Go-Live Runbook)
*   **Klucze produkcyjne:** Zastąpienie kluczy `pk_test_...` oraz `sk_test_...` kluczami produkcyjnymi w Secret Managerze na środowisku produkcyjnym (GCP Prod). *Uwaga:* Należy bezwzględnie używać kluczy o ograniczonym dostępie (**Restricted API Keys**) zamiast kluczy głównych (*Secret API Keys*).
*   **Wymiana ID cen:** Ceny produkcyjne wygenerowane w panelu Stripe Live Mode będą miały inne identyfikatory `price_...`. Należy zaktualizować tabelę `subscription_plans` w bazie produkcyjnej za pomocą skryptu migracyjnego lub nasiona startowego (seed).
