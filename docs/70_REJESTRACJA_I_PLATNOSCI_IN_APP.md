---
type: Technical Design
title: "70. Rejestracja terapeuty i płatności in-app (Apple / Google) — analiza przypadków, kody rabatowe"
description: "Analiza ścieżki rejestracji i zakupu w aplikacji (StoreKit / Play Billing) obok subskrypcji web (Stripe): scenariusze, edge-cases web↔in-app, kody rabatowe z panelu admina, projekt delty."
resource: file:///Users/dpiotrak/supervisorai_v2/ai/docs/70_REJESTRACJA_I_PLATNOSCI_IN_APP.md
tags: [billing, iap, apple, google, stripe, flutter, admin, identity, onboarding, design]
timestamp: 2026-09-03T12:00:00+02:00
---

# 70. Rejestracja terapeuty i płatności in-app (Apple / Google) — analiza przypadków, kody rabatowe

Status: **WDROŻENIE W TOKU (2026-09-03)** — analiza z tego dokumentu jest
realizowana na branchu `feat/iap-and-discount-codes`. Co już jest w kodzie,
a czego brakuje, opisuje §11. Dokument jest deltą względem działającego
systemu billingowego (docs/17, 18, 29, 32, 43). Nie zmienia zasad P1–P5 ani ADR-BL-*.
Wymagania wejściowe (Darek, 2026-09-03):

1. Ścieżka „simple": instalacja → rejestracja w aplikacji → wybór planu (w tym darmowy) → „Kup" → płatność Apple / Google.
2. Po wygaśnięciu darmowego okresu, wyczerpaniu tokenów lub braku płatności — w aplikacji pojawia się opcja zakupu in-app.
3. Istniejąca subskrypcja na stronie (Stripe) pozostaje dostępna równolegle.
4. Ceny in-app = ceny ze strony **+15 %**.
5. Kody rabatowe definiowane w panelu admina: nazwa, termin, procent, maksymalna liczba użyć.

---

## 0. TL;DR — rekomendacje

| # | Rekomendacja | Dlaczego |
|---|---|---|
| R1 | **Jedna subskrypcja per organizacja, trzy providery** (`STRIPE`, `APPLE_IAP`, `GOOGLE_IAP`) w istniejącej tabeli `subscriptions`. Enum `payment_provider` i kolumny `apple_product_id` / `google_product_id` już istnieją (migracje 000002, 000028). | Zero zmian w gate'cie `ReserveCredit` / licznikach. Sklepy stają się kolejnym „webhookiem" obok Stripe. |
| R2 | **Weryfikacja zakupów po stronie serwera** (billing-svc): StoreKit 2 JWS + App Store Server API; Google Play Developer API `subscriptionsv2.get` + RTDN przez Pub/Sub. Aplikacja nigdy sama nie przyznaje uprawnień. | Spójne z ADR-BL-002 (`payment_events` jako brama) i P1 (idempotencja). RTDN przez Pub/Sub nie wymaga publicznego endpointu. |
| R3 | **Darmowa opcja = istniejący TRIAL (10 tokenów / 30 dni) provisionowany przez `CreateUser`**, bez produktu sklepowego i bez store-trialu. | Unikamy podwójnego triala (serwerowy + sklepowy) i karty w trialu. |
| R4 | **Ceny sklepowe = cena web × 1,15, zaokrąglona w górę do dostępnego punktu cenowego** i identyczna w obu sklepach. Parytet marży wymaga **Apple Small Business Program (prowizja 15 %)** — bez niego +15 % nie pokrywa prowizji 30 % (§3.2). | Matematyka w §3.2. |
| R5 | **Kody rabatowe: nasz katalog w DB + Stripe jako silnik egzekwowania na web** (coupon + promotion code tworzone przez API z panelu admina, `max_redemptions` i `expires_at` natywnie). W sklepach kody procentowe **nie mogą** zmieniać ceny produktu — faza 2 mapuje je na Apple Offer Codes / Google developer-determined offers (§6.5). | Pełna zgodność ze spec (nazwa, termin, procent, limit) od razu na web; sklepy mają własne, dyskretne mechanizmy. |
| R6 | **W aplikacji iOS/Android nie wspominamy o zakupie na WWW** (tryb `NONE`), a zdalna flaga `IAP_WEB_LINK_MODE` w `app_config` pozwala włączyć tekst/link, gdy prawnie potwierdzimy warunki DMA (UE). Subskrypcje kupione na web są honorowane w aplikacji (Apple 3.1.3(b)). | Steering poza IAP to najczęstsza przyczyna odrzuceń. Flaga = zmiana bez wydania aplikacji. |
| R7 | **Blokada krzyżowa providerów**: zakup in-app niemożliwy przy aktywnej subskrypcji Stripe (i odwrotnie) — do końca bieżącego okresu. Przełączenie „natychmiast z proporcjonalnym zwrotem" odkładamy do v2. | Jedyny sposób, by nie podwójnie obciążać terapeuty; Apple nie daje API do zwrotów. |
| R8 | **Organizacje B2B (seat allocations, `MANUAL`) i konta z miejscem w klinice nie widzą paywalla w ogóle.** | Sub MANUAL jest aktywna; zakup terapeuty zderzyłby się z `idx_subscriptions_one_active_per_org`. |
| R9 | **Rejestracja in-app tylko dla terapeutów solo** (auto-org `SOLO` jak dziś na web), **maksymalnie uproszczona pod konwersję**: social login (Apple/Google) bez weryfikacji e-mail, weryfikacja tylko dla e-mail+hasło i nieblokująca; profil = **imię, nazwisko, nurt**, reszta opcjonalnie (S1). Zaproszeni do klinik nadal przez magic-link. Wymaga dodania w aplikacji **usuwania konta** (Apple 5.1.1(v)). | Sign in with Apple już jest (`login_screen.dart`); Firebase zwraca `emailVerified=true` dla Apple/Google, więc krok weryfikacji jest dla nich zbędny. Brakuje rejestracji i usuwania konta. |
| R10 | Kolejność wdrożenia: **(1) kody rabatowe web** (niezależne, ~1 tydz.) → **(2) backend IAP** → **(3) Flutter: rejestracja + paywall** → **(4) web/admin provider-aware** → (5) opcjonalnie kody w sklepach, top-up, przełączanie z proratą. | §8. |

Decyzje wymagające potwierdzenia biznesowego: §9.

---

## 1. Stan obecny (co reużywamy)

| Obszar | Stan | Gdzie |
|---|---|---|
| Rejestracja terapeuty | **Tylko web**: `/register/therapist` → Firebase → `identity.CreateUser` (auto-org `SOLO` „Imię Nazwisko - Praktyka" + sub `TRIAL`/`TRIALING`/`MANUAL` + licznik 10 tokenów, `NOW()+30 dni`) → wizard 7 kroków. Krok 7 mówi wprost: „Subskrypcje kupujesz na WWW". | `identity-svc/internal/adapters/grpc/server.go:485-644`, `marketing-site/.../OnboardingWizard.tsx` |
| Aplikacja Flutter | Login (e-mail, Google, **Apple**), brak rejestracji („Konto terapeuty założysz na superwizor.ai"), brak usuwania konta, **brak jakiegokolwiek commerce** (celowo: `quota_exhausted_dialog.dart:8-15` „ZERO upgrade buttons, ZERO pricing links"). Ekran „Subskrypcja" tylko do odczytu. Brak `in_app_purchase` w `pubspec.yaml`. | `flutter-app/superwizor/lib/screens/login_screen.dart`, `subscription_plan_screen.dart`, `widgets/quota_*` |
| Cennik (LIVE od 2026-07-12) | Poznanie (TRIAL) 0 zł / 10 sesji / 30 dni; Równowaga (SOLO) 149 zł mies. / 1490 zł rok (30 / 360 tokenów); Rozkwit (PRO) 299 zł / 2990 zł (90 / 1080). Brutto z VAT 23 %. Kupony Stripe: ROWNOWAGA 99 zł, ROZKWIT 199 zł („na zawsze"). CLINIC nieaktywny. | `migrations/000070`, `000079`, `marketing-site/src/lib/billing/plans.ts` |
| Stripe | Checkout (`POST /api/checkout` przez rewrite Firebase Hosting → billing-svc), portal, webhook z ręczną weryfikacją HMAC, `payment_events` UNIQUE(provider, event id), `upsertSubscriptionFromStripe` dezaktywuje trial. `invoice.paid` = nowy `usage_counters`. | `billing-svc/internal/adapters/http/checkout_handler.go`, `stripe_handler.go` |
| Gate tokenów | `ingestion-svc.CreateAudioUpload` → `billing.ReserveCredit`: `QUOTA_EXHAUSTED` (ResourceExhausted), `SUBSCRIPTION_INACTIVE` / `SUBSCRIPTION_PAST_DUE` (FailedPrecondition). Reguła UX-1: brak tokenów **nigdy** nie blokuje nagrania (audio lokalnie). | `ingestion-svc/.../server.go:620-680`, `billing-svc/.../grpc/server.go:279-427` |
| Polityka odnowień (2026-07) | Okresy darmowe **nie odnawiają się**: TRIAL → `CANCELED` po 30 dniach; BETA 2 okresy; B2B z seat allocations odnawia cron; płatne odnowienie **wyłącznie** przez Stripe `invoice.paid`. `PAST_DUE` blokuje natychmiast, brak grace. | `billing-svc/.../http/admin_handler.go:200-264` |
| Jedna aktywna sub per org | `idx_subscriptions_one_active_per_org` (ACTIVE / TRIALING / PAST_DUE). | `migrations/000028:85-87` |
| Model B2B | Org + `org_seat_allocations` + `seat_assignments`; liczniki per terapeuta; terapeuta należy do **dokładnie jednej** organizacji (`users.organization_id`). | docs/43, `migrations/000061-000064` |
| Panel admina | Next.js `/admin/*` (orgs, users, crm, audit, stripe-test); RPC admin w billing-svc: rola `SUPERWIZOR_ADMIN` + `reason ≥ 10 zn.` + `idempotency_key` + `audit_events`. | `billing-svc/.../grpc/admin.go`, `marketing-site/src/components/admin/*` |
| Kody rabatowe | **Brak modelu**. Stripe Promotion Codes tworzone ręcznie w dashboardzie; nazwy zaszyte w `plans.ts`; `/admin/stripe-test` to tester, nie manager. | `checkout_handler.go:138-150` |
| Zdalna konfiguracja | `app_config (key, value, organization_id)` + `pkg/appconfig` z cache 30 s (kill switch AI Chat, docs/64). | `migrations/000084` |
| Android / iOS | `targetSdk = 36` (już w kodzie), iOS 1.0.8 (57) w recenzji od 2026-08-25. Sign in with Apple wdrożone. | `android/app/build.gradle.kts:42` |

Wniosek: **fundament billingowy jest gotowy na drugiego i trzeciego providera** — brakuje warstwy sklepowej (weryfikacja, notyfikacje, produkty), rejestracji in-app, paywalla i modelu kodów.

---

## 2. Ramy narzucone przez sklepy (kształtują projekt)

Poniższe reguły są stanem na 2026-09 według wytycznych Apple App Store Review Guidelines i Google Play Payments / Subscriptions policy. **Przed wdrożeniem potwierdzić aktualne brzmienie** — obszar zmienia się szybko (DMA w UE, spory Epic w USA).

### 2.1 Apple

| Reguła | Skutek dla nas |
|---|---|
| **3.1.1** — treści/funkcje cyfrowe odblokowywane w aplikacji muszą używać IAP; zakaz przycisków/linków/CTA do innych mechanizmów zakupu; zakaz własnych mechanizmów odblokowania (klucze licencyjne, kody). | Plan kupowany w aplikacji = produkt auto-renewable IAP. Żadnych linków do `superwizor.ai/pricing`. **Własne kody rabatowe nie mogą być wpisywane w aplikacji iOS** (ani obniżać ceny, ani odblokowywać funkcji) — §6.5. |
| **3.1.2** — subskrypcje: jasna cena, okres, auto-odnawianie, link do regulaminu i polityki prywatności na paywallu; działanie na wszystkich urządzeniach użytkownika; **Restore Purchases**. | Paywall z pełnym tekstem prawnym; przycisk „Przywróć zakupy"; entitlement po stronie serwera (org), więc iPad/iPhone/web widzą to samo. |
| **3.1.3(b) Multiplatform Services** — aplikacja może honorować subskrypcje kupione na innych platformach / web, **pod warunkiem że te same plany są dostępne jako IAP**. | Po wdrożeniu IAP subskrypcja Stripe jest legalnie honorowana w aplikacji. Dziś app opiera się na 3.1.3(f) (darmowy companion bez zakupów) — komentarze w kodzie mówią „Reader App", ale to (f). Po dodaniu IAP (f) przestaje obowiązywać. |
| **Steering** — poza UE/USA: brak wzmianek o tańszej ofercie na WWW. W UE (DMA, decyzja KE 04/2025 i warunki Apple 2025/2026) link-out jest możliwy, ale na warunkach alternatywnych Apple z własnymi opłatami (Core Technology Commission, Initial Acquisition Fee, Store Services Fee). | Tryb `NONE` na start; `TEXT`/`LINK` za flagą po analizie prawno-finansowej. E-maile (drip `trial_exhausted` z linkiem `/upgrade`) pozostają legalne — komunikacja poza aplikacją. |
| **4.8** — logowanie zewnętrzne ⇒ Sign in with Apple. | Wdrożone. |
| **5.1.1(v)** — aplikacja z zakładaniem konta musi oferować usuwanie konta w aplikacji. | **Nowy wymóg** po dodaniu rejestracji in-app: ekran „Usuń konto" (identity `AdminDeleteUser` istnieje tylko dla admina — potrzebny self-service RPC). |
| **App Store Server Notifications V2 + App Store Server API** — JWS, `originalTransactionId`, `appAccountToken` (UUID), Billing Grace Period (konfigurowalny w ASC), Billing Retry do 60 dni, zwroty decyduje Apple (`CONSUMPTION_REQUEST` → możemy przesłać dane o zużyciu), brak API do anulowania/zwrotu przez developera. | Endpoint `POST /apple/notifications` w billing-svc, reconcile cron, mapowanie stanów (§7.3). |
| Ceny — 900 punktów cenowych; cena bazowa w jednej walucie, reszta storefrontów automatycznie lub ręcznie; podwyżka ceny wymaga zgody subskrybenta. | Cena PLN ustawiona ręcznie po zaokrągleniu; inne storefronty (EUR itd.) z automatu. |
| Sandbox — recenzent Apple i TestFlight kupują w środowisku Sandbox, ale uderzają w **produkcyjny backend**. | Backend akceptuje `environment=Sandbox` (weryfikacja przez sandbox API), oznacza sub jako sandbox, nie liczy do przychodu (E19). |

### 2.2 Google Play

| Reguła | Skutek |
|---|---|
| Payments policy — dobra cyfrowe w aplikacji przez Google Play Billing; steering do innych metod zabroniony poza programami: **External offers program (EOG)** i **User Choice Billing** (opłaty niewiele niższe niż standard). | Play Billing dla Androida; identyczny tryb `NONE` wzmianek o WWW; UCB nieopłacalne (~11 % zamiast 15 %). |
| Play Billing Library ≥ 7 (od 08/2025 dla nowych wydań), PBL 8 od 08/2026; `targetSdk` 36 od 08/2026. | Flutter `in_app_purchase_android` w aktualnej wersji; targetSdk 36 już w kodzie. |
| RTDN (Real-time developer notifications) przez **Pub/Sub** + Play Developer API `purchases.subscriptionsv2.get`; **acknowledge w 3 dni** albo automatyczny zwrot; grace period (3/7/14/30 dni), account hold (30 dni), pauza, `PENDING` purchases; developer może `revoke` / `refund` przez API. | Subscriber Pub/Sub w billing-svc (wzór z ingestion-svc); acknowledge **po** zapisie entitlementu po stronie serwera. |
| Subscription offers: base plans + offers; **developer-determined eligibility** (offer tags) — aplikacja decyduje, komu pokazać ofertę. | Podstawa dla kodów rabatowych na Androidzie w fazie 2 (§6.5). |
| Prowizja: 15 % dla subskrypcji od pierwszego dnia; Google jest merchant of record w UE (VAT rozlicza Google). | §3.2. |

### 2.3 Wspólne konsekwencje

- **Sklep jest merchant of record**: terapeuta dostaje rachunek od Apple/Google, **nie fakturę VAT z NIP od Euphire**. Dla JDG i klinik to realna wada (koszt uzyskania przychodu). Tabela `invoices` jest Stripe-only (`stripe_invoice_id NOT NULL`) — w aplikacji dla IAP pokazujemy „historia zakupów w sklepie", nie faktury. (E23)
- **Tożsamość płatnicza zostaje w sklepie**; my przechowujemy wyłącznie opaque ID (`originalTransactionId`, `purchaseToken`) — korzystne dla RODO, zgodne z docs/52.
- Anulowanie subskrypcji sklepowej możliwe tylko z poziomu ustawień sklepu (Apple) lub sklepu / naszego API (Google). „Zarządzaj subskrypcją" w aplikacji = deep link (`showManageSubscriptions` / `play.google.com/store/account/subscriptions?sku=…&package=…`).

---

## 3. Cennik in-app (+15 %)

### 3.1 Produkty i ceny

Reguła: `store_price = ceil_to_price_point(price_gross_web × 1.15)`; ta sama liczba w App Store i Google Play (Google przyjmuje dowolne kwoty, Apple tylko punkty cenowe — dopasowujemy Google do Apple). Kwoty poniżej są **przykładowe** — ostateczne punkty cenowe potwierdzić w App Store Connect.

| Plan | Cykl | Web brutto | ×1,15 | Cena sklepowa (przykład) | Product ID (propozycja) | Tokeny / okres |
|---|---|---|---|---|---|---|
| Równowaga (SOLO) | miesięczny | 149,00 zł | 171,35 | **174,99 zł** | `ai.superwizor.solo.monthly` / Play: sub `solo`, base plan `monthly` | 30 |
| Równowaga (SOLO) | roczny | 1 490,00 zł | 1 713,50 | **≈1 749 zł** | `ai.superwizor.solo.annual` / `solo` + `annual` | 360 |
| Rozkwit (PRO) | miesięczny | 299,00 zł | 343,85 | **349,99 zł** | `ai.superwizor.pro.monthly` / `pro` + `monthly` | 90 |
| Rozkwit (PRO) | roczny | 2 990,00 zł | 3 438,50 | **≈3 449 zł** | `ai.superwizor.pro.annual` / `pro` + `annual` | 1 080 |
| Poznanie (TRIAL) | — | 0 zł | — | brak produktu (serwerowy trial) | — | 10 / 30 dni |

- Apple: **jedna grupa subskrypcyjna** „SuperWizor" z poziomami: Rozkwit (1) > Równowaga (2). Upgrade w grupie = natychmiast z proratą; downgrade i zmiana cyklu w dół = od następnego odnowienia. Family Sharing **wyłączone**.
- Google: dwie subskrypcje (`solo`, `pro`) po dwa base plany; tryb zamiany: upgrade `CHARGE_PRORATED_PRICE`, downgrade `DEFERRED`.
- Aplikacja wyświetla **wyłącznie ceny zwrócone przez StoreKit / Play** (`displayPrice`, lokalna waluta użytkownika). Kolumna `subscription_plans.store_price_gross` służy tylko panelowi admina i analityce.
- **Brak odpowiednika kuponów web** (99 zł / 199 zł „dla wczesnych użytkowników"): w aplikacji Równowaga kosztuje 174,99 zł, na web z kodem 99 zł (+77 %). To największa luka UX/biznesowa tego projektu — decyzja D2 w §9 (opcje: introductory offer w sklepach, brak, wygaszenie kuponów web).

### 3.2 Matematyka +15 % (Równowaga miesięczna, kwoty netto dla Euphire)

| Kanał | Cena brutto | Po VAT 23 % | Prowizja | Netto dla Euphire |
|---|---|---|---|---|
| Web (Stripe) | 149,00 | 121,14 | Stripe ~1,5 % + ~1 zł ≈ 2,8 zł | **≈118,3 zł** |
| App Store, Small Business Program (15 %) | 174,99 | 142,27 | 21,34 | **≈120,9 zł** |
| App Store, stawka standardowa (30 %) | 174,99 | 142,27 | 42,68 | **≈99,6 zł** |
| Google Play (15 % dla subskrypcji) | 174,99 | 142,27 | 21,34 | **≈120,9 zł** |

Wniosek: **+15 % daje parytet z web tylko przy prowizji 15 %.** Wymagane działania: zgłoszenie Euphire sp. z o.o. do Apple Small Business Program (przychód < 1 mln USD/rok) przed startem sprzedaży; Google 15 % obowiązuje automatycznie dla subskrypcji. Przy 30 % tracimy ~16 % względem web — wtedy uzasadnione byłoby +30 %.

---

## 4. Scenariusze główne

Notacja stanów: `sub(provider, plan, status)`; licznik = `usage_counters` bieżącego okresu.

### S1. „Simple": instalacja → rejestracja → wybór planu → zakup

```
Instalacja → ekran startowy: [Zaloguj się] [Załóż konto]
  │
  ├─ Załóż konto (maksymalnie uproszczone — 3 ekrany przy social loginie, 4 przy e-mail+hasło):
  │     ├─ 1. Ekran startowy: [Kontynuuj z Apple] [Kontynuuj z Google] | e-mail + hasło (Firebase)
  │     │      Apple/Google zwracają zweryfikowany adres (emailVerified=true; „Hide My Email" też) i imię/nazwisko do prefill.
  │     │      Apple podaje imię i nazwisko TYLKO przy pierwszym logowaniu — zapisać z credentiala od razu, zanim przepadnie.
  │     ├─ 2. Profil — jeden ekran: Imię, Nazwisko (prefill z providera), Nurt (defaultModalityId — wymagany przez raporty)
  │     │      + jeden checkbox zgód (Regulamin, Polityka prywatności; DPA w regulaminie) → identity.RecordConsent
  │     │      → identity.CreateUser(THERAPIST, first_name, last_name) → org SOLO „Imię Nazwisko - Praktyka" + sub(MANUAL, TRIAL, TRIALING)
  │     │        + licznik 10 tokenów  [istniejące — bez zmian w backendzie]
  │     │      Tytuł, telefon, rozmiar praktyki, język raportów — opcjonalne, później w Ustawieniach (progressive profiling).
  │     ├─ 3. Weryfikacja e-mail — TYLKO gdy Firebase emailVerified=false, czyli w praktyce tylko e-mail+hasło:
  │     │      ekran „Sprawdź skrzynkę" (polling reload(), [Wyślij ponownie], [Zrobię to później]) — NIEBLOKUJĄCA:
  │     │      użytkownik idzie dalej, sticky baner do czasu weryfikacji; egzekwowana dopiero przy pierwszym uploadzie
  │     │      (nagranie nigdy nie jest blokowane — UX-1). Social login pomija ten ekran całkowicie.
  │     └─ 4. PlanPicker (poniżej)
  │
  ├─ PlanPicker: [Poznanie — bezpłatnie, 10 sesji/30 dni]  [Równowaga 174,99 zł/mies.]  [Rozkwit 349,99 zł/mies.]  (toggle mies./rok)
  │     ├─ Poznanie → „Dalej" → home (trial już aktywny — nic do zrobienia)
  │     └─ Płatny → billing.BeginStorePurchase(plan) → {allowed, app_account_token=org_id}
  │            → StoreKit / Play purchase(product, appAccountToken / obfuscatedAccountId)
  │            → sukces → billing.VerifyStorePurchase(jws | purchaseToken)
  │                 → serwer: weryfikacja u Apple/Google → tx: DeactivateOtherActiveSubscriptions(tylko MANUAL/TRIAL/BETA)
  │                   → upsert sub(APPLE_IAP|GOOGLE_IAP, SOLO|PRO, ACTIVE, period = purchase→expires) → nowy licznik (30|90)
  │                 → state_after → BillingQuotaCache → home z pełną pulą
  │            → anulowanie / błąd → zostaje trial (brak ślepej uliczki)
  └─ Zaloguj się (konto z web) → GetMyBillingState → stan jak na web
```

Efekt DB (zakup Równowagi na iOS): `subscriptions`: trial → `CANCELED`; nowa `(APPLE_IAP, provider_subscription_id = originalTransactionId, plan SOLO MONTHLY, ACTIVE, current_period_end = expiresDate)`; `store_transactions` + `payment_events` (`SUBSCRIBED/INITIAL_BUY`); `usage_counters` 30 tokenów; niewykorzystane tokeny trialu przepadają (BR-4, tak jak przy Stripe) — decyzja D4.

### S2. Wybór darmowy → wyczerpanie 10 tokenów → zakup z dialogu

`ReserveCredit` → `QUOTA_EXHAUSTED` → `QuotaExhaustedDialog` z **trzema** akcjami: `[Nagrywaj lokalnie]` (UX-1 nienaruszone) `[Wybierz plan]` `[Anuluj]`. `[Wybierz plan]` → PlanPicker → jak S1. Po zakupie listener `tokensRemaining 0 → >0` budzi zaparkowane uploady (`eee4ef2`) — sesje lokalne wymagają jawnego „Wznów" (UX-3).

### S3. Trial wygasł (30 dni) → `SUBSCRIPTION_INACTIVE`

Cron odnowień ustawia `CANCELED`; `GetMyBillingState` → `FailedPrecondition`. Aplikacja: **miękki paywall** — sticky baner „Okres próbny zakończony" + PlanPicker przy próbie nagrania; odczyt kartotek i raportów działa. Zakup → nowa sub sklepowa (bez dezaktywacji — brak aktywnej).

### S4. Użytkownik web (Stripe) loguje się w aplikacji

`GetBillingSurface` → `provider=STRIPE` → ekran Subskrypcja: plan, tokeny, „Subskrypcja zarządzana przez Twoje konto na superwizor.ai" (**tekst bez linku** w trybie `NONE`), brak przycisków zakupu. Dialog wyczerpania tokenów bez `[Wybierz plan]` (upgrade w Stripe to portal — poza aplikacją; e-mail `quota_warning`/`trial_exhausted` prowadzi na web).

### S5. Użytkownik IAP wchodzi na web `/account`

Karta Subskrypcja: „Zarządzasz w App Store / Google Play", brak przycisku Stripe, `ListInvoices` puste → „Rachunki znajdziesz w sklepie". `/api/checkout` odrzuca (`409 OTHER_PROVIDER_ACTIVE`) z datą końca okresu.

### S6. Odnowienie, nieudana płatność, grace, odzyskanie (sklep)

| Zdarzenie sklepu | Nasz stan | Aplikacja |
|---|---|---|
| `DID_RENEW` / `SUBSCRIPTION_RENEWED` | nowy okres, nowy licznik (jak `invoice.paid`), `payment_events` | pula odnowiona przy następnym refresh |
| `DID_FAIL_TO_RENEW` + `GRACE_PERIOD` / `IN_GRACE_PERIOD` | `ACTIVE`, `grace_until`, bieżący licznik **przedłużony** do końca grace (bez nowej puli — D5) | baner „Problem z płatnością — zaktualizuj w App Store/Google Play" + deep link (dozwolony: to zarządzanie IAP) |
| `GRACE_PERIOD_EXPIRED` / `EXPIRED(BILLING_RETRY)` / `ON_HOLD` | `PAST_DUE` (blokada jak dziś) | modal „Problem z płatnością" z deep linkiem |
| `DID_RENEW(BILLING_RECOVERY)` / `SUBSCRIPTION_RECOVERED` | `ACTIVE` + nowy okres i licznik | odblokowanie |

### S7. Anulowanie → wygaśnięcie → ponowny zakup

Auto-renew off (`DID_CHANGE_RENEWAL_STATUS` / `CANCELED`) → `cancel_at_period_end=true`, dostęp do końca okresu → `EXPIRED(VOLUNTARY)` → `CANCELED` → jak S3. Resubscribe w sklepie (`SUBSCRIBED/RESUBSCRIBE` / `RESTARTED`) → `ACTIVE` na tym samym `originalTransactionId` (Apple) lub nowym `purchaseToken` z `linkedPurchaseToken` (Google) — upsert po `UNIQUE(provider, provider_subscription_id)` z obsługą łańcucha tokenów.

### S8. Upgrade / downgrade / zmiana cyklu w sklepie

| Zmiana | Sklep | My |
|---|---|---|
| Równowaga → Rozkwit (mies.) | natychmiast, prorata | `plan_id` → PRO, `tokens_limit` 30 → 90 w bieżącym liczniku, `tokens_used` zostaje (docs/17 §9.3) |
| mies. → rok (ten sam plan) | Apple: natychmiast; Google: wg trybu (`CHARGE_FULL_PRICE` / `WITH_TIME_PRORATION`) | nowy okres roczny + nowy licznik 360/1080 (jak `AdminChangePlan`) |
| Rozkwit → Równowaga, rok → mies. | od następnego odnowienia (`DID_CHANGE_RENEWAL_PREF/DOWNGRADE`, `DEFERRED`) | `pending_plan_id` + realizacja przy `DID_RENEW` |

### S9. Nowe urządzenie, drugi system, „Przywróć zakupy"

Entitlement jest na organizacji, więc logowanie na iPadzie/Androidzie/web wystarcza. „Przywróć zakupy" (wymóg Apple) → `Transaction.currentEntitlements` / `queryPurchases` → `RestoreStorePurchases` → serwer sprawdza `appAccountToken` = org zalogowanego (E1). Zakup na Androidzie przy aktywnej sub Apple → `BeginStorePurchase` → `OTHER_PROVIDER_ACTIVE` („Subskrypcja aktywna w App Store do {data}").

---

## 5. Edge-cases web ↔ in-app

### 5.1 Macierz: stan organizacji × akcja

| Aktywna subskrypcja org | Zakup w aplikacji (iOS / Android) | Zakup na web (Stripe) |
|---|---|---|
| `TRIAL` / `BETA` (MANUAL, TRIALING/ACTIVE) | ✅ dezaktywuje trial/betę, nowa sub sklepowa | ✅ jak dziś |
| brak / `CANCELED` (trial wygasł, sub zakończona) | ✅ | ✅ |
| `STRIPE ACTIVE` | ⛔ „zarządzana na superwizor.ai" (bez linku, `NONE`) | n/d — portal (zmiana planu, karta) |
| `STRIPE ACTIVE` + `cancel_at_period_end` | ⛔ do `current_period_end`, potem ✅ (v2: natychmiast + zwrot proporcjonalny przez Stripe) | portal: „wznów" |
| `STRIPE PAST_DUE` | ⛔ + komunikat o płatności (bez linku na iOS/Android) | portal / dunning e-mail |
| `APPLE_IAP` / `GOOGLE_IAP ACTIVE` | własna platforma: „zarządzaj" (deep link); druga platforma: ⛔ „aktywna w App Store/Google Play" | ⛔ `409` z datą końca; v2: start Stripe od `expires_date` (`subscription_data.trial_end`) |
| sklep: grace / billing retry (`grace_until`) | ⛔ nowy zakup; „napraw płatność" → deep link | ⛔ |
| sklep: auto-renew OFF (wygasa {data}) | „wznów w sklepie" | v1 ⛔ do {data}; v2 ✅ z `trial_end={data}` |
| `GOOGLE_IAP PAUSED` | „wznów w Google Play" | ⛔ |
| `MANUAL` z seat allocations (B2B) / konto z miejscem w klinice | ⛔ paywall **ukryty**: „planem zarządza Twoja organizacja" | ⛔ (checkout tylko dla org SOLO bez alokacji) |

Reguła serwerowa (jedno miejsce — `BeginStorePurchase` i `/api/checkout`): zakup dozwolony ⇔ org `type=SOLO` **i** brak `org_seat_allocations` **i** aktywna sub ∈ {brak, `TRIAL`, `BETA`, ten sam provider (upgrade)} **i** flaga `IAP_ENABLED_<platforma>` = on.

### 5.2 Katalog przypadków brzegowych

**A. Tożsamość i konta**

| # | Przypadek | Obsługa |
|---|---|---|
| E1 | „Przywróć zakupy" zwraca transakcję z `appAccountToken` innej organizacji (drugie konto SuperWizor, cudzy Apple ID na urządzeniu). | Odmowa: „Ten zakup jest przypisany do innego konta SuperWizor" + kontakt. Przeniesienie tylko przez admina (`AdminTransferStoreSubscription`, audyt). Transakcje bez tokenu (zakup sprzed logowania — nie występuje, bo paywall wymaga zalogowania) → odmowa. |
| E2 | Ten sam terapeuta ma dwa konta (e-mail + Google, docs/44). | Trial ×2 bez zmian; sub sklepowa wiąże się z org, w której kupiono. Unifikacja kont poza zakresem. |
| E3 | Family Sharing / współdzielony Apple ID. | Family Sharing wyłączone w ASC; `REVOKE` obsługiwany jak zwrot. |
| E4 | Zakup przed weryfikacją e-maila (tylko konta e-mail+hasło — social login jest zweryfikowany przez providera). | Dozwolony: uprawnienie wisi na organizacji, a transakcja na `appAccountToken`, nie na e-mailu. Weryfikacja jest nieblokująca (S1 krok 3) i egzekwowana dopiero przy pierwszym uploadzie — to zamyka „farmę triali" na fikcyjne adresy (bez weryfikacji nie da się spalić tokenów STT/LLM). Ryzyko literówki w adresie: `UpdateMyEmail` + ponowna weryfikacja z ekranu Ustawień. |
| E4b | Social login bez imienia/nazwiska (Apple zwraca `fullName` tylko przy pierwszym logowaniu; użytkownik może odmówić; „Hide My Email"). | Prefill, gdy provider dał dane; inaczej puste pola na ekranie profilu. Imię i nazwisko z credentiala Apple zapisujemy lokalnie przy pierwszym logowaniu i przekazujemy do `CreateUser`. Adres relay Apple działa z Firebase i drip e-mailami. |
| E5 | Usunięcie konta (RODO) z aktywną subskrypcją sklepową. | Apple: nie możemy anulować — ekran usuwania konta wymaga potwierdzenia „anulowałem subskrypcję" + deep link; Google: opcjonalnie `purchases.subscriptions.revoke` (zwrot proporcjonalny) przez API. Notyfikacje po usunięciu org → `payment_events` `IGNORED`. |
| E6 | Terapeuta solo z IAP przeniesiony przez admina do kliniki (`AdminAssignTherapistToOrg`). | Sub zostaje na starym org solo → RPC blokuje, jeśli aktywna sub sklepowa (`FAILED_PRECONDITION STORE_SUBSCRIPTION_ACTIVE`) — admin prosi terapeutę o anulowanie (Google: możliwy revoke z API). |
| E7 | ORG_ADMIN kliniki (bez miejsca) w aplikacji. | Brak uprawnień do nagrywania i tak; paywall ukryty. |

**B. Subskrypcja i tokeny**

| # | Przypadek | Obsługa |
|---|---|---|
| E8 | Trial: 10 tokenów zużyte przed 30 dniami. | S2. |
| E9 | Trial: 30 dni minęło z niewykorzystanymi tokenami. | S3 (bez zmian polityki — darmowe okresy nie odnawiają się). |
| E10 | Zakup przy trialu z resztą tokenów. | Przepadają (BR-4), jak przy Stripe. Alternatywa D4: dopisać resztę do nowego licznika (`tokens_limit += remaining_trial`). |
| E11 | Płatny plan, limit wyczerpany w połowie okresu. | Dialog: `[Rozszerz do Rozkwitu]` (upgrade w sklepie, natychmiast; licznik 30→90, used zostaje) / faza 2: `[Dokup 10 sesji]` (consumable, `token_grants`). Dla Stripe: portal (poza aplikacją) — e-mail z linkiem. |
| E12 | Odnowienie sklepowe nie doszło (webhook zgubiony, opóźniony). | Cron `store-reconcile` (codziennie): sub sklepowa z `current_period_end < now()` bez zdarzenia → `Get All Subscription Statuses` / `subscriptionsv2.get` → upsert. Notyfikacja = sygnał, **API sklepu = prawda**. |
| E13 | Grace period (Apple 3–28 dni, Google 3–30 dni) — sklep wymaga ciągłości dostępu. | `ACTIVE` + `grace_until`; bieżący licznik przedłużony (`period_end = grace_until`), **bez** nowej puli (limit ekspozycji ≤ 30 tokenów). Po `DID_RENEW` — normalny nowy licznik. |
| E14 | Account hold / billing retry po grace. | `PAST_DUE` (blokada jak dziś); `RECOVERED` → `ACTIVE`. Wymaga zmiany: `PAST_DUE` z providerem sklepowym pokazuje deep link do sklepu, nie „ustawienia płatności" web. |
| E15 | Zwrot (Apple `REFUND`, Google `REVOKED`). | Sub → `CANCELED` natychmiast, licznik zamrożony (`tokens_limit = tokens_used`), sesje w toku dokończone. Tokeny już spalone nie wracają (BR-5). `CONSUMPTION_REQUEST` → wysyłamy „Send Consumption Information" (zużyte tokeny, czas od zakupu) — potrzebna zgoda w regulaminie. |
| E16 | Zwrot i natychmiastowy ponowny zakup (nadużycie). | Licznik zakupów/zwrotów per org w `store_transactions`; alert po 2. zwrocie; dalsze zakupy dozwolone (sklep decyduje o zwrotach). |
| E17 | Zmiana cyklu / planu w sklepie. | S8; upgrade w grupie Apple generuje nową transakcję z tym samym `originalTransactionId` — upsert po tym kluczu. |
| E18 | Podwyżka ceny w sklepie. | `PRICE_INCREASE` (PENDING/ACCEPTED) tylko log; brak zgody = `EXPIRED(PRICE_INCREASE)` → jak S7. |
| E19 | Sandbox / TestFlight / recenzent Apple na produkcyjnym backendzie. | Weryfikacja JWS z `environment=Sandbox` przez sandbox API; sub oznaczona `store_environment='Sandbox'`; wykluczona z analityki przychodów; dozwolona tylko dla allowlisty e-maili testowych (`apple-test*@superwizor.ai`, `demo@…`) lub flagi `IAP_ALLOW_SANDBOX`. |
| E20 | `PENDING` (Google, metody odroczone) / „Ask to Buy" (Apple, deferred). | Nie przyznajemy; UI „oczekuje na potwierdzenie"; RTDN / `Transaction.updates` domyka. |
| E21 | Duplikaty i kolejność notyfikacji. | `payment_events UNIQUE(provider, provider_event_id)` (`notificationUUID` / `messageId`); każda notyfikacja kończy się odczytem statusu z API (E12). |
| E22 | Dwa zakupy „naraz": Checkout Stripe otwarty w przeglądarce + IAP w aplikacji (lub iOS + Android). | Prewencja: `BeginStorePurchase` i `/api/checkout` odrzucają przy aktywnej sub innego providera **lub** otwartej sesji Checkout < 24 h (`pending_checkouts`). Gdy mimo to dojdą oba webhooki: `DeactivateOtherActiveSubscriptions` **nie dotyka** płatnych subów innego providera → druga ląduje jako `INCOMPLETE` + alert (Slack/e-mail admin) + ręczny zwrot (Google API; Apple — użytkownik). |
| E23 | Faktura VAT z NIP dla IAP. | Niemożliwa (MoR = sklep). FAQ + komunikat na paywallu w wersji neutralnej („Rachunek wystawia App Store/Google Play"). Dla JDG/klinik rekomendacja web pozostaje w komunikacji **poza** aplikacją. |
| E24 | Kod rabatowy na web, potem przejście na IAP. | Rabat przepada; komunikat przy przełączaniu (v2). |
| E25 | Cena w innej walucie (zagraniczny storefront). | Aplikacja pokazuje `displayPrice` ze sklepu; `store_price_gross` tylko referencyjnie. |
| E26 | Awaria / odrzucenie / zmiana polityki. | `app_config`: `IAP_ENABLED_IOS`, `IAP_ENABLED_ANDROID`, `IAP_WEB_LINK_MODE` (`NONE`/`TEXT`/`LINK`), `IAP_ALLOW_SANDBOX` — cache 30 s, bez wydania aplikacji. |
| E27 | Stary build bez IAP. | Bez zmian — stan przez `GetMyBillingState`; komunikaty ogólne. |
| E28 | Zakup potwierdzony przez sklep, `VerifyStorePurchase` nie doszedł (brak sieci, crash). | Transakcja **nie jest** finishowana/acknowledge'owana przed potwierdzeniem serwera; przy starcie aplikacji `Transaction.unfinished` / `queryPurchases` → ponowna weryfikacja. Google: acknowledge serwerowy (`purchases.subscriptions.acknowledge`) po zapisie — brak acknowledge w 3 dni = automatyczny zwrot. |
| E29 | Zmiana e-maila (`UpdateMyEmail`) a Stripe (lookup klienta po e-mailu w `checkout_handler.go`). | Istniejący dług (poza zakresem); IAP nie zależy od e-maila (klucz = `appAccountToken`). |
| E30 | Terapeuta z miejscem w klinice traci miejsce (deaktywacja). | `ACCOUNT_DEACTIVATED` blokuje logowanie — nie kupi sam; poprawne. |
| E31 | Rejestracja in-app z linku zaproszenia (klinika) lub `RegisterOrganization`. | Poza zakresem v1: zaproszeni idą magic-linkiem web (universal link może otworzyć aplikację w v2). |

---

## 6. Kody rabatowe (panel admina)

### 6.1 Wymaganie i interpretacja

Kod = `{nazwa, termin ważności, procent, maksymalna liczba użyć}`. Doprecyzowania (do potwierdzenia, §9):

- **Czas trwania rabatu** — dzisiejsze kupony działają „na zawsze"; proponujemy pole `duration` (`ONCE` / `REPEATING n` / `FOREVER`, domyślnie `FOREVER`).
- **Zakres** — opcjonalnie ograniczenie do planów/cykli (`applies_to`) i „tylko nowi klienci".
- **Jedno użycie na organizację** (`UNIQUE(code_id, organization_id)`).
- **Kanały** — v1: `WEB`; v2: `APPLE`, `GOOGLE` (§6.5).

### 6.2 Model danych

```sql
-- 0001NN_discount_codes.up.sql
CREATE TABLE discount_codes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code                TEXT NOT NULL,                       -- znormalizowany: UPPER, bez spacji
  name                TEXT NOT NULL,                       -- nazwa kampanii w panelu
  percent_off         NUMERIC(5,2) NOT NULL CHECK (percent_off > 0 AND percent_off <= 100),
  duration            TEXT NOT NULL DEFAULT 'FOREVER' CHECK (duration IN ('ONCE','REPEATING','FOREVER')),
  duration_periods    INT CHECK (duration <> 'REPEATING' OR duration_periods > 0),
  valid_from          TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_until         TIMESTAMPTZ NOT NULL,                -- termin
  max_redemptions     INT NOT NULL CHECK (max_redemptions > 0),
  redemptions_count   INT NOT NULL DEFAULT 0,              -- lustro (źródło: redemptions COMMITTED)
  applies_to_tiers    plan_tier[],                         -- NULL = wszystkie
  applies_to_cycles   billing_cycle[],
  new_customers_only  BOOLEAN NOT NULL DEFAULT FALSE,
  channels            TEXT[] NOT NULL DEFAULT '{WEB}',     -- WEB | APPLE | GOOGLE
  stripe_coupon_id          TEXT,
  stripe_promotion_code_id  TEXT,
  apple_offer_code_id       TEXT,                          -- faza 2
  google_offer_id           TEXT,                          -- faza 2
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_by          UUID REFERENCES users(id),
  reason              TEXT NOT NULL,                       -- audyt (≥10 zn., jak inne RPC admina)
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  deactivated_at      TIMESTAMPTZ
);
CREATE UNIQUE INDEX ux_discount_codes_code ON discount_codes (upper(code));

CREATE TABLE discount_code_redemptions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code_id             UUID NOT NULL REFERENCES discount_codes(id),
  organization_id     UUID NOT NULL REFERENCES organizations(id),
  user_id             UUID REFERENCES users(id),
  channel             TEXT NOT NULL,                        -- WEB | APPLE | GOOGLE
  status              TEXT NOT NULL DEFAULT 'RESERVED' CHECK (status IN ('RESERVED','COMMITTED','RELEASED')),
  provider_reference  TEXT,                                 -- checkout session / subscription id / transaction id
  reserved_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  committed_at        TIMESTAMPTZ,
  UNIQUE (code_id, organization_id)
);
```

Seed: import istniejących kodów Stripe (`ROWNOWAGA`, `ROWNOWAGA_ROK`, `ROZKWIT`, `ROZKWIT_ROK`, `PIONIER33`, `DEVFREE`) z ich `promotion_code_id`, aby panel pokazywał komplet od pierwszego dnia.

### 6.3 API (billing-svc) i panel

```protobuf
// SUPERWIZOR_ADMIN — wzór admin.go: rola + reason ≥10 + idempotency_key + audit_events
rpc AdminCreateDiscountCode(AdminCreateDiscountCodeRequest) returns (DiscountCode);
rpc AdminUpdateDiscountCode(AdminUpdateDiscountCodeRequest) returns (DiscountCode);   // name, valid_until, max_redemptions, is_active
rpc AdminListDiscountCodes(AdminListDiscountCodesRequest) returns (AdminListDiscountCodesResponse);
rpc AdminGetDiscountCode(AdminGetDiscountCodeRequest) returns (DiscountCodeDetails);  // + lista redemptions

// publiczne (Firebase auth, ConnectAuthInterceptor) — walidacja przed checkoutem
rpc ValidateDiscountCode(ValidateDiscountCodeRequest) returns (DiscountCodeQuote);
// {code, plan_tier, plan_cycle} → {valid, reason, percent_off, price_before, price_after, duration}
```

`AdminCreateDiscountCode` (transakcja aplikacyjna, idempotentna po `idempotency_key`):
1. walidacja: `percent_off ∈ (0,100]`, `valid_until > now()`, kod unikalny (case-insensitive);
2. Stripe: `coupon.create{percent_off, duration, applies_to.products}` → `promotioncode.create{code, coupon, max_redemptions, expires_at, restrictions.first_time_transaction}` (klucz idempotencji Stripe = `idempotency_key`);
3. INSERT `discount_codes` z ID Stripe; błąd Stripe → brak wiersza (albo wiersz `PENDING_SYNC` z retry — prostsze: brak wiersza + komunikat).

Panel `/admin/discount-codes`: tabela (kod, nazwa, %, termin, użyte/limit, kanały, status) + `ActionDialog` (wzór) do tworzenia/dezaktywacji; szczegóły z listą redemptions (org, data, kanał). Kopiuje wzorce `OrgsList.tsx` + `OrgCreateWizard.tsx`.

### 6.4 Egzekwowanie na web (Stripe jako silnik)

```
/pricing lub /upgrade: pole „Kod rabatowy" → ValidateDiscountCode → podgląd ceny
   → POST /api/checkout {price_id, promo_code}
        → serwer: ValidateDiscountCode (ponownie) → rezerwacja redemption (RESERVED, UNIQUE(code, org))
        → Stripe Checkout z Discounts=[promotion_code_id]  (istniejący kod)
   → webhook checkout.session.completed: total_details.breakdown.discounts[].promotion_code
        → redemption COMMITTED (+1 redemptions_count) — źródłem prawdy o limicie jest Stripe (max_redemptions atomowo)
   → checkout.session.expired / cancel → redemption RELEASED
```

Dwufazowość (RESERVED → COMMITTED/RELEASED) to ten sam wzorzec, co `pending_reservations`. Nie liczymy limitu „u siebie" wyścigowo — Stripe odrzuci nadmiarowe użycie; nasze `redemptions_count` jest lustrem do panelu („pozostało ok. N").

Edge-cases kodów:

| # | Przypadek | Obsługa |
|---|---|---|
| D1 | Kod wygasł między walidacją a płatnością. | Stripe waliduje przy tworzeniu sesji; sesja żyje ≤ 24 h — akceptujemy. |
| D2 | Wyścig o ostatnie użycie. | Stripe `max_redemptions` atomowo; nasz RESERVED nie gwarantuje — UI „ok. N". |
| D3 | Ta sama org używa kodu drugi raz (nowy checkout po anulowaniu). | `UNIQUE(code_id, organization_id)` → odrzucenie w `ValidateDiscountCode`; `new_customers_only` → Stripe `first_time_transaction`. |
| D4 | Kod dla Równowagi użyty na Rozkwicie. | `applies_to` u nas + `coupon.applies_to.products` w Stripe. |
| D5 | Dezaktywacja kodu. | `promotioncode.update{active:false}` + `is_active=false`; istniejące subskrypcje **zachowują** rabat (kupon na subskrypcji) — zgodne z oczekiwaniem; zdjęcie rabatu = osobna, ręczna akcja. |
| D6 | 100 % (jak `DEVFREE`). | Dozwolone tylko z ostrzeżeniem w panelu; Checkout `payment_method_collection: if_required`. |
| D7 | `FOREVER` na planie rocznym. | Rabat na każde odnowienie — OK. |
| D8 | Kod użyty przez org B2B / z alokacjami. | Checkout niedostępny dla takich org (§5.1) — nie dotyczy. |
| D9 | Wielkość liter, spacje, znaki diakrytyczne. | Normalizacja `UPPER`, `[A-Z0-9_]{3,32}`. |
| D10 | Zmiana `max_redemptions` / `valid_until` po utworzeniu. | `promotioncode.update` nie pozwala zmienić `max_redemptions` ani `expires_at` (tylko `active`, `metadata`) → panel tworzy nowy promotion code pod tym samym kuponem i podmienia `stripe_promotion_code_id` (stary → inactive). |

### 6.5 Kody w aplikacji (faza 2 — ograniczenia sklepów)

W sklepach **nie da się** zastosować dowolnego procentu do ceny produktu, a wpisywanie własnych kodów w aplikacji iOS narusza 3.1.1. Dostępne mechanizmy:

| Sklep | Mechanizm | Co się mapuje | Ograniczenia |
|---|---|---|---|
| Apple | **Offer Codes** (custom codes) — konfigurowane w App Store Connect lub przez **App Store Connect API** (`subscriptionOfferCodes`, `…CustomCodes` z `expirationDate` i limitem użyć); realizacja przez arkusz `presentCodeRedemptionSheet()` lub URL `apps.apple.com/redeem?ctx=offercodes…`. Transakcja niesie `offerType=3`, `offerIdentifier`. | nazwa → custom code; termin → `expirationDate`; limit → redemption limit; procent → **cena oferty z punktów cenowych** (najbliższa ≤ cena×(1−p)) na **1–12 okresów** (pay-as-you-go) lub pay-up-front / free. | Brak „na zawsze"; procent tylko przybliżony; recenzowany klucz API ASC (mamy: `scripts/update_app_metadata.go`). |
| Google | **Developer-determined offers** na base planie (Play Developer API `monetization.subscriptions.basePlans.offers` — tworzenie programowo) z ceną absolutną; aplikacja pokazuje ofertę **dopiero po** `ValidateDiscountCode` na naszym backendzie (pole kodu w aplikacji Android jest dopuszczalne, bo wynikowa cena nadal idzie przez Play Billing). Zakup niesie `offerId` w `lineItems[].offerDetails`. | wszystkie cztery atrybuty egzekwujemy **my** (walidacja + redemption), Play tylko liczy cenę. | Play promo codes (konsola) nie mają API — nie używamy. |
| Alternatywa | Kod → **korzyść po stronie serwera** (dodatkowe tokeny, przedłużony trial) zamiast rabatu cenowego. | pełna kontrola | Ryzyko 3.1.1 (własny mechanizm odblokowania) — nie rekomendowane na iOS. |

Rekomendacja: v1 kody działają na web; paywall w aplikacji nie ma pola kodu (iOS) — Android opcjonalnie w fazie 2 razem z Apple Offer Codes. Panel pokazuje kanały każdego kodu; wspólny licznik użyć = suma redemptions ze wszystkich kanałów (limity sklepowe ustawiamy przy tworzeniu i traktujemy jako górne).

---

## 7. Projekt techniczny (delta)

### 7.1 Migracje

```sql
-- 0001NN_store_iap.up.sql
ALTER TABLE subscriptions
  ADD COLUMN store_environment  TEXT,          -- 'Production' | 'Sandbox'
  ADD COLUMN store_product_id   TEXT,
  ADD COLUMN auto_renew         BOOLEAN,       -- stan auto-odnawiania w sklepie
  ADD COLUMN grace_until        TIMESTAMPTZ,   -- billing grace (E13)
  ADD COLUMN pending_plan_id    UUID REFERENCES subscription_plans(id);  -- downgrade od następnego okresu
-- provider_subscription_id = Apple originalTransactionId | Google purchaseToken (UNIQUE(provider, id) istnieje)

CREATE TABLE store_transactions (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider                 payment_provider NOT NULL CHECK (provider IN ('APPLE_IAP','GOOGLE_IAP')),
  transaction_id           TEXT NOT NULL,      -- Apple transactionId | Google orderId
  original_transaction_id  TEXT NOT NULL,      -- Apple originalTransactionId | Google purchaseToken (root łańcucha linkedPurchaseToken)
  organization_id          UUID REFERENCES organizations(id),
  user_id                  UUID REFERENCES users(id),
  product_id               TEXT NOT NULL,
  purchase_date            TIMESTAMPTZ NOT NULL,
  expires_date             TIMESTAMPTZ,
  environment              TEXT NOT NULL,
  app_account_token        UUID,               -- appAccountToken | obfuscatedExternalAccountId
  offer_type               TEXT, offer_identifier TEXT,
  revocation_date          TIMESTAMPTZ, revocation_reason TEXT,
  raw_payload              JSONB NOT NULL,     -- zweryfikowany payload (bez PII sklepu)
  verified_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider, transaction_id)
);
CREATE INDEX ix_store_tx_org ON store_transactions(organization_id, purchase_date DESC);

CREATE TABLE pending_checkouts (               -- E22: wykrywanie równoległych zakupów
  organization_id UUID NOT NULL REFERENCES organizations(id),
  channel         TEXT NOT NULL,               -- WEB | APPLE | GOOGLE
  reference       TEXT NOT NULL,               -- checkout session id | app_account_token
  expires_at      TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (organization_id, channel)
);

ALTER TABLE subscription_plans ADD COLUMN store_price_gross NUMERIC(10,2);
UPDATE subscription_plans SET apple_product_id='ai.superwizor.solo.monthly', google_product_id='solo:monthly', store_price_gross=174.99
  WHERE tier='SOLO' AND cycle='MONTHLY' AND is_active;  -- itd. dla 4 planów
```

`invoices` pozostaje Stripe-only; historia IAP = `store_transactions` (panel admina) + link do sklepu (aplikacja).

### 7.2 RPC (billing.proto, addytywnie)

```protobuf
// Klient (Flutter / web) — auth Firebase przez ConnectAuthInterceptor, jak GetSubscription z przeglądarki.
rpc GetBillingSurface(google.protobuf.Empty) returns (BillingSurface);
// {active_provider, can_purchase, block_reason, manage_url, web_link_mode, products[]{product_id, plan_tier, plan_cycle, tokens_per_period}, show_restore}

rpc BeginStorePurchase(BeginStorePurchaseRequest) returns (BeginStorePurchaseResponse);
// {platform, product_id} → {allowed, block_reason (OTHER_PROVIDER_ACTIVE|ORG_MANAGED|IAP_DISABLED|PENDING_CHECKOUT), app_account_token, blocked_until}
// side effect: pending_checkouts(channel=platform, expires_at=now()+30min)

rpc VerifyStorePurchase(VerifyStorePurchaseRequest) returns (Subscription);
// {platform, jws_transaction | (purchase_token, product_id)} → weryfikacja u Apple/Google → upsert → state_after

rpc RestoreStorePurchases(RestoreStorePurchasesRequest) returns (Subscription);
// {platform, jws_transactions[] | purchase_tokens[]} → jak wyżej, z kontrolą app_account_token (E1)

// Admin
rpc AdminListStoreTransactions(AdminListStoreTransactionsRequest) returns (AdminListStoreTransactionsResponse);
rpc AdminTransferStoreSubscription(AdminTransferStoreSubscriptionRequest) returns (Subscription);  // E1, reason + audit
```

Transport dla Flutter mobile: **bezpośrednio do billing-svc** (wzorzec „browser-direct" z `docs/agents/03_billing-svc.md`, unika hop-u przez clinical-svc, który dawał `RST_STREAM`). Wymaga dopuszczenia ruchu z aplikacji do billing-svc (ingress + Firebase bearer w `ConnectAuthInterceptor`) — dziś tak działa przeglądarka. `GetMyBillingState` w clinical-svc zostaje bez zmian.

### 7.3 Notyfikacje sklepów → stany

| Wejście | Mechanizm | Weryfikacja |
|---|---|---|
| Apple App Store Server Notifications V2 | `POST /apple/notifications` w billing-svc (ekspozycja jak `/stripe/webhook`) | podpis JWS (łańcuch x5c do Apple Root CA G3), `notificationUUID` → `payment_events(APPLE_IAP)`; potem `Get All Subscription Statuses(originalTransactionId)` |
| Google RTDN | Pub/Sub topic `play-rtdn` (message storage policy `europe-central2` — P3), pull-subscriber w billing-svc | `messageId` → `payment_events(GOOGLE_IAP)`; potem `purchases.subscriptionsv2.get(packageName, purchaseToken)` |
| Reconcile | cron `POST /admin/store-reconcile` (codziennie 03:00) | sub sklepowe z `current_period_end < now()` lub `grace_until < now()` bez zdarzenia → API sklepu |

Mapowanie (wspólna funkcja `applyStoreState(orgID, StoreSubscriptionState)`; źródłem jest odpowiedź API, nie typ notyfikacji):

| Stan sklepu | `subscriptions.status` | Licznik |
|---|---|---|
| aktywna, `expires > now`, nowy `expires` > poprzedni | `ACTIVE` | nowy okres → nowy `usage_counters` (`tokens_per_period` planu) |
| aktywna, auto-renew off (`CANCELED` Google = nadal aktywna) | `ACTIVE`, `cancel_at_period_end=true` | bez zmian |
| grace period | `ACTIVE`, `grace_until` | `period_end = grace_until` (bez nowej puli) |
| billing retry po grace / account hold | `PAST_DUE` | bez zmian (blokada) |
| paused (Google) | `PAUSED` | blokada (`ReserveCredit`: traktować jak INACTIVE — dziś nieobsługiwany status) |
| expired (voluntary / price increase / retry failed) | `CANCELED` | bez zmian |
| refunded / revoked | `CANCELED`, `canceled_at=now()` | `tokens_limit = tokens_used` (zamrożenie) |
| upgrade (wyższy poziom, natychmiast) | `plan_id` nowy | `tokens_limit` ↑, `tokens_used` zostaje |
| downgrade zaplanowany | `pending_plan_id` | realizacja przy następnym okresie |
| `CONSUMPTION_REQUEST` | — | job: Send Consumption Information (tokeny zużyte, % okresu) |

Zmiany w istniejącym kodzie:
- `DeactivateOtherActiveSubscriptions` → tylko `provider IN ('MANUAL')` z planem `TRIAL`/`BETA` (nie płatne suby innych providerów) — E22.
- `checkout_handler.go`: pre-check `canPurchase(org, WEB)`; `409 OTHER_PROVIDER_ACTIVE`.
- `ReserveCredit` / `CheckQuota`: status `PAUSED` → `FailedPrecondition SUBSCRIPTION_PAUSED`.
- `handleManualPeriodRenewal`: bez zmian (filtruje `MANUAL`); `safety-check`: nie „leczyć" subów sklepowych bez licznika, tylko raportować (reconcile to zrobi).
- Sekrety: App Store Server API key (`.p8`, Key ID, Issuer ID, Bundle ID) i konto serwisowe Play (`play-billing@…`, uprawnienia „Zarządzanie zamówieniami i subskrypcjami" w Play Console, WIF/impersonacja jak `google-play-deployer@`) → Secret Manager / IAM. Klucz ASC leżący dziś obok `credentials.env` w katalogu roboczym powinien trafić do Secret Managera.

### 7.4 Flutter

| Element | Zmiana |
|---|---|
| `pubspec.yaml` | `in_app_purchase` (+ `in_app_purchase_storekit` StoreKit 2, `in_app_purchase_android` PBL ≥ 7). Alternatywa RevenueCat (`purchases_flutter`) skraca backend (weryfikacja, notyfikacje, entitlementy), ale dokłada procesora danych w USA (DPA/SCC) i drugie źródło prawdy obok `subscriptions` — D10; rekomendacja: **in-house**, spójnie z Stripe. |
| Rejestracja | Ekran startowy z Apple/Google na pierwszym miejscu + e-mail/hasło; `ProfileSetupScreen` (imię, nazwisko z prefillu providera, nurt, jeden checkbox zgód) → `RecordConsent` + `CreateUser`; `VerifyEmailScreen` pokazywany tylko gdy `emailVerified=false`, z opcją „Zrobię to później" i sticky banerem; gate „zweryfikowany e-mail" w `UploadQueueRunner` przed pierwszym `CreateAudioUpload` (nagranie bez zmian). Pola opcjonalne (tytuł, telefon, rozmiar praktyki, język raportów) trafiają do istniejącego `profile_edit_sheet.dart`. Rekomendacja: ujednolicić web wizard (7 kroków) do tego samego minimum — D12. |
| Usuwanie konta | `DeleteAccountScreen` + nowy RPC `identity.DeleteMyAccount` (soft-delete jak `RemoveTherapist`, przypomnienie o subskrypcji sklepowej — E5). |
| Paywall | `PlanPickerScreen` (onboarding, dialog wyczerpania, trial wygasł, ekran Subskrypcja): karty z `displayPrice`, toggle mies./rok, tekst prawny (cena, okres, auto-odnawianie, Regulamin, Prywatność), `[Przywróć zakupy]`, brak pola kodu (iOS). Widoczność sterowana `GetBillingSurface`. |
| `SubscriptionPlanScreen` | provider, „Zarządzaj subskrypcją" (deep link sklepu) / tekst dla Stripe, „Przywróć zakupy", status grace/PAST_DUE z deep linkiem. |
| `quota_exhausted_dialog.dart` | `[Wybierz plan]` gdy `can_purchase`; `[Nagrywaj lokalnie]` zostaje (UX-1). Usunąć komentarze „Reader App". |
| `quota_warning_banner.dart` | „Rozszerz plan" wraca, tylko gdy `can_purchase`. |
| Transakcje | Nasłuch `purchaseStream` od startu aplikacji; `finish`/`acknowledge` **po** `VerifyStorePurchase` (E28); StoreKit Configuration file do testów lokalnych. |
| Gating | `GetBillingSurface` przy cold-starcie + po każdym zakupie; flagi `app_config` po stronie serwera. |

### 7.5 Web / marketing-site / admin

- `/account` karta Subskrypcja provider-aware (S5); `/upgrade` i `/pricing`: pole kodu + `ValidateDiscountCode` (dziś kod wpisuje się dopiero w Stripe).
- Wizard krok 7: „Subskrypcje kupujesz na WWW **lub w aplikacji**".
- `/admin/discount-codes` (§6.3); `/admin/orgs/[id]`: sekcja „Sklep" (provider, product, environment, transakcje, `AdminTransferStoreSubscription`).
- CRM (`crm_*`, docs/49): zdarzenia `store_purchase`, `store_refund`, `store_billing_issue` → Priority Inbox; drip `trial_exhausted` bez zmian (e-mail poza aplikacją jest legalny).

### 7.6 Testy

- Unit: mapowanie stanów sklepu (tabela §7.3) na fake'ach Apple/Google; `canPurchase` na macierzy §5.1; cykl RESERVED→COMMITTED/RELEASED kodów.
- E2E Go (`-tags=e2e`): `TestStorePurchaseFlow` (JWS testowy podpisany kluczem testowym z podmienionym root CA), `TestStripeVsStoreConflict` (E22), `TestDiscountCodeLifecycle` (Stripe test mode).
- Flutter: StoreKit Configuration (Xcode) + sandbox testerzy; Play internal testing + license testers; scenariusze S1–S9 na obu platformach; „Request a Test Notification" (Apple) i test RTDN (Play Console).
- Recenzja: notatki dla Apple z kontem testowym i opisem, że subskrypcje web są honorowane zgodnie z 3.1.3(b).

---

## 8. Plan wdrożenia

| Faza | Zakres | Zależności | Szacunek |
|---|---|---|---|
| 0 — przygotowanie (bez kodu) | Decyzje §9; App Store Connect: umowa Paid Apps, grupa + 4 produkty + ceny, Small Business Program, klucz App Store Server API, URL notyfikacji (prod + sandbox); Play Console: profil płatności Euphire, 2 subskrypcje × 2 base plany, RTDN topic, konto serwisowe; regulamin: auto-odnawianie, zwroty, zgoda na przekazanie danych o zużyciu (E15). | — | 3–5 dni (głównie konsole i prawnik) |
| 1 — kody rabatowe (web) | PR1 migracja `discount_codes` + seed; PR2 RPC admin + Stripe sync + `ValidateDiscountCode`; PR3 panel + pole kodu na `/pricing`, `/upgrade`; webhook redemptions. | niezależne od IAP | 4–6 dni |
| 2 — backend IAP | PR4 migracje §7.1; PR5 weryfikacja Apple (JWS, Server API) + `/apple/notifications`; PR6 Google (Developer API, RTDN subscriber, acknowledge); PR7 `GetBillingSurface`/`Begin`/`Verify`/`Restore`, `applyStoreState`, reconcile cron, zmiany w Stripe handlerze i `ReserveCredit(PAUSED)`; e2e. | faza 0 | 8–12 dni |
| 3 — Flutter | PR8 `in_app_purchase` + `PlanPickerScreen` + integracja dialogów; PR9 rejestracja in-app + usuwanie konta; PR10 ekran Subskrypcja + restore + deep linki; PR11 testy sandbox/TestFlight/internal. | faza 2 | 8–12 dni |
| 4 — web / admin | PR12 `/account` provider-aware + pre-check checkoutu; PR13 sekcja „Sklep" w `/admin/orgs/[id]` + CRM events. | faza 2 | 3–4 dni |
| 5 — wydanie | Recenzja Apple/Google (IAP wydłuża recenzję, pytania o 3.1.3(b)); flagi `IAP_ENABLED_*` = off do zatwierdzenia; monitoring (alerty: konflikt providerów, błędy weryfikacji, `IGNORED` > X/dzień). | fazy 3–4 | 3–5 dni + czas recenzji |
| 6 — opcjonalnie | Kody w sklepach (§6.5), top-up consumable (`token_grants`), przełączanie providerów z proratą/`trial_end`, universal link zaproszeń. | 1–5 | wg decyzji |

Łącznie ~6–8 tygodni pracy jednej osoby (bez fazy 6); faza 1 może wyjść na produkcję samodzielnie w pierwszym tygodniu.

---

## 9. Decyzje do podjęcia (biznes / prawo)

| # | Pytanie | Rekomendacja |
|---|---|---|
| D1 | Zaokrąglanie +15 % do punktów cenowych w górę; potwierdzenie kwot 174,99 / ≈1 749 / 349,99 / ≈3 449 zł; zgłoszenie do Apple Small Business Program. | Tak; bez SBP rozważyć +30 %. |
| D2 | Odpowiednik cen „early adopter" (99/199 zł z kodem) w aplikacji: introductory offer w sklepach (np. 3 pierwsze miesiące ≈114 / 229 zł), brak, czy wygaszenie kuponów web. | Introductory offer ograniczona czasowo, spójna z kampanią web; inaczej aplikacja jest ~75 % droższa niż web z kodem i użytkownicy to zauważą. |
| D3 | Tryb wzmianki o WWW w aplikacji: `NONE` / `TEXT` / `LINK` (UE, DMA, warunki alternatywne Apple i EOG Google). | `NONE` na start; analiza prawno-finansowa przed `LINK`. |
| D4 | Niewykorzystane tokeny trialu przy zakupie: przepadają czy przechodzą. | Przepadają (spójnie ze Stripe, BR-4); ewentualnie „bonus powitalny" jako grant. |
| D5 | Grace period: bieżący licznik przedłużony (bez nowej puli) czy tymczasowa nowa pula. | Przedłużenie licznika (ekspozycja ≤ 1 pula). |
| D6 | Przełączanie providerów: v1 blokada do końca okresu; v2 natychmiast + zwrot proporcjonalny (Stripe→sklep) / `trial_end` (sklep→Stripe). | v1 blokada; v2 po pierwszych danych o popycie. |
| D7 | Komunikacja braku faktury VAT z NIP przy IAP (JDG/kliniki). | FAQ + e-maile; w aplikacji tekst neutralny. |
| D8 | Kody w sklepach (faza 6): zestaw dopuszczalnych procentów (np. 10/20/33/50) i maks. czas (≤ 12 mies.), Android z polem kodu. | Odłożyć do czasu danych z fazy 1. |
| D9 | Czas trwania rabatu z kodu (`ONCE`/`REPEATING`/`FOREVER`), domyślnie. | `FOREVER` jak dziś, ale pole w panelu. |
| D10 | Build in-house vs RevenueCat. | In-house (spójność z `payment_events`, brak procesora w USA, brak drugiego źródła prawdy). |
| D11 | Top-up (consumable) w fazie 6. | Tak, po IAP; zgodne z docs/17 §14.2 i docs/49. |
| D12 | Rejestracja in-app pod konwersję (decyzja Darka 2026-09-03): weryfikacja e-mail tylko dla e-mail+hasło i nieblokująca (egzekwowana przy pierwszym uploadzie); profil = imię, nazwisko, nurt; reszta opcjonalnie. Otwarte: czy web wizard (7 kroków, obowiązkowa weryfikacja i telefon) ujednolicić do tego samego minimum. | Tak, ujednolicić — jeden lejek, jedna miara konwersji; telefon dla CRM zbierać później (progressive profiling), zgodnie z Apple 5.1.1. |
| D13 | Start: iOS i Android równocześnie czy iOS pierwszy. | Równocześnie w kodzie, flagi per platforma pozwalają włączać osobno. |

---

## 10. Cross-reference

- docs/17 §2 (BR-1..6), §9.3 (upgrade mid-cycle), §14.2 (top-up), §16.7 (UX-1..6)
- docs/18 v2.0 (propagacja stanu przez `state_after`, cron-y)
- docs/29, docs/32 (Stripe: checkout, webhook, kupony sandbox)
- docs/43 (organizacje, miejsca, liczniki per terapeuta)
- docs/44 (buglog auth/onboarding — konta duplikaty, Google/Apple sign-in)
- docs/49 (e-maile: koniec limitów, dunning), docs/52 §5 (IAP w Companion — ta sama zasada „tożsamość płatnicza zostaje w sklepie")
- docs/64 (kill switch przez `app_config` — wzorzec dla `IAP_*`)
- `docs/agents/03_billing-svc.md` (browser-direct, `ConnectAuthInterceptor`, gotchas)

---

## 11. Stan wdrożenia i runbook uruchomienia

Branch: `feat/iap-and-discount-codes`. Sekcja opisuje, co jest zrobione, a
co trzeba zrobić RĘKAMI w konsolach, zanim sprzedaż w aplikacji ruszy.

### 11.1 Co jest w kodzie

| Obszar | Stan | Gdzie |
|---|---|---|
| Migracje | ✅ 000105 (kody rabatowe), 000106 (sklepy + flagi `IAP_*` = false) | `superwizor-backend/migrations/` |
| Kontrakt proto | ✅ 11 nowych RPC + `Subscription.billing_provider` / `grace_until` + `identity.DeleteMyAccount` | `proto/billing/v1`, `proto/identity/v1` |
| Kody rabatowe | ✅ CRUD admina, `ValidateDiscountCode`, dwufazowa rezerwacja użycia, sync ze Stripe, ścieżka awaryjna dla kodów z dashboardu | `billing-svc/internal/adapters/grpc/discount_codes.go`, `.../stripepromo/` |
| Zakupy w aplikacji | ✅ `GetBillingSurface`, `BeginStorePurchase`, `VerifyStorePurchase`, `RestoreStorePurchases`, `applyStoreState`, blokady krzyżowe | `billing-svc/internal/adapters/grpc/store.go` |
| Weryfikacja Apple | ✅ JWS (łańcuch x5c + ES256), App Store Server API, notyfikacje V2 | `billing-svc/internal/adapters/appstore/` |
| Weryfikacja Google | ✅ `purchases.subscriptionsv2` + acknowledge | `billing-svc/internal/adapters/playstore/` |
| Wejścia ze sklepów | ✅ `POST /apple/notifications`, `POST /google/rtdn`, cron `POST /admin/store-reconcile` | `billing-svc/internal/adapters/http/store_handler.go` |
| Usuwanie konta | ✅ `DeleteMyAccount` (soft-delete + wyłączenie Firebase + blokada przy aktywnej subskrypcji ze sklepu) | `identity-svc/.../account_deletion.go` |
| Cron uzgadniania | ✅ zdefiniowany w terraformie (**niezaaplikowany**) | `infra/environments/staging/billing_crons.tf` |
| CI | ✅ `APPLE_BUNDLE_ID`, `PLAY_PACKAGE_NAME`; sekrety Apple opisane, ale **niepodpięte** | `.github/workflows/ci.yml` |

Sprzedaż jest **wyłączona z definicji**: `IAP_ENABLED_IOS` i
`IAP_ENABLED_ANDROID` w `app_config` startują na `false`, a weryfikatory
rejestrują się tylko przy komplecie sekretów. Bez tych dwóch rzeczy
`GetBillingSurface` zwraca `can_purchase=false, block_reason=IAP_DISABLED`
i aplikacja nie pokazuje przycisków zakupu.

### 11.2 Czego jeszcze nie ma

1. **Produktów w sklepach** — bez nich StoreKit i Play nie wycenią kart na
   paywallu (§11.3 krok 1–2).
2. **Sekretów Apple'a** w Secret Managerze (§11.3 krok 3).
3. **Uprawnień konta usługi** billing-svc w Play Console (§11.3 krok 4).
4. **Zaaplikowanego terraformu** i podpiętych sekretów w CI.
5. **Decyzji D1–D13** z §9 — zwłaszcza D1 (Small Business Program), D2
   (odpowiednik kuponów web) i D3 (tryb wzmianki o WWW).
6. Kodów rabatowych w sklepach (§6.5) — świadomie odłożone do fazy 6.

### 11.3 Runbook — kolejność ma znaczenie

**Krok 1. App Store Connect.** Umowa Paid Apps → grupa subskrypcji
„SuperWizor" z poziomami Rozkwit (1) > Równowaga (2) → cztery produkty o
identyfikatorach z migracji 000106 (`ai.superwizor.solo.monthly`,
`.solo.annual`, `.pro.monthly`, `.pro.annual`) → ceny wg D1 → Family
Sharing WYŁĄCZONE. Zgłoszenie do Small Business Program (D1).

**Krok 2. Play Console.** Dwie subskrypcje (`solo`, `pro`), po dwa plany
bazowe (`monthly`, `annual`) — identyfikatory muszą dać
`solo:monthly`, `solo:annual`, `pro:monthly`, `pro:annual`, dokładnie jak w
`subscription_plans.google_product_id`.

**Krok 3. Sekrety Apple'a.**
```bash
# AppleRootCA-G3 pobrany z https://www.apple.com/certificateauthority/
# (plik .cer → PEM: openssl x509 -inform der -in AppleRootCA-G3.cer -out root.pem)
gcloud secrets create apple-root-ca-pem --data-file=root.pem
gcloud secrets create apple-asc-private-key --data-file=AuthKey_XXXXXXXX.p8
gcloud secrets add-iam-policy-binding apple-root-ca-pem \
  --member=serviceAccount:billing-svc@superwizor-ai-25ecd.iam.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor
# to samo dla apple-asc-private-key
```
Potem odkomentuj sekrety w kroku deployu billing-svc w `ci.yml` i dopisz
`APPLE_ISSUER_ID` oraz `APPLE_KEY_ID`.

> Uwaga: klucz `AuthKey_56B8A5D38H.p8` leży dziś luzem w katalogu roboczym
> repo. Przy okazji tego kroku trafia do Secret Managera i znika z dysku.

**Krok 4. Google Play — uprawnienia.** Konto
`billing-svc@superwizor-ai-25ecd.iam.gserviceaccount.com` dodaj w Play
Console (Users and permissions) z uprawnieniem **Zarządzanie zamówieniami i
subskrypcjami** dla `ai.superwizor.superwizor`. Bez tego
`subscriptionsv2.get` zwraca 401, a każda weryfikacja Androida kończy się
`STORE_VERIFICATION_FAILED`.

**Krok 5. Notyfikacje.**
- Apple: App Store Connect → App Information → App Store Server
  Notifications → V2 → URL produkcyjny i sandboxowy:
  `https://billing-svc-e3f32b232q-lm.a.run.app/apple/notifications`.
  Endpoint jest publiczny — uwierzytelnia go podpis JWS.
- Google: Play Console → Monetization setup → temat Pub/Sub w
  `europe-central2` (P3!) → subskrypcja **push** na
  `https://billing-svc-e3f32b232q-lm.a.run.app/google/rtdn` z tokenem OIDC
  konta `cloud-scheduler-billing@…` (ten sam middleware co crony).
  Sprawdź „Send test notification" — powinno wrócić `{"status":"ignored"}`.

**Krok 6. Terraform.** `terragrunt apply` w
`infra/environments/staging` — dokłada cron `billing-store-reconcile`.

**Krok 7. Migracje i deploy.** Push na branch → CI aplikuje 000105–000106
krokiem `db-migrator` przed deployem (kolejność jak w docs/admin-analytics).

**Krok 8. Włączenie sprzedaży.** Dopiero teraz, po jednym udanym zakupie
sandbox na każdej platformie:
```sql
UPDATE app_config SET value = 'true' WHERE key = 'IAP_ENABLED_IOS' AND organization_id IS NULL;
UPDATE app_config SET value = 'true' WHERE key = 'IAP_ENABLED_ANDROID' AND organization_id IS NULL;
```
Zmiana działa w 30 s (cache `pkg/appconfig`), bez deployu i bez wydania
aplikacji. Tą samą drogą wyłącza się sprzedaż, gdyby coś poszło nie tak.

### 11.4 Weryfikacja po wdrożeniu

| Co | Jak |
|---|---|
| Weryfikator Apple wstał | `gcloud logging read 'jsonPayload.msg="billing-svc: App Store verifier ready"' --freshness=1h` |
| Weryfikator Play wstał | jw., `"billing-svc: Google Play verifier ready"` |
| Notyfikacja doszła | `SELECT provider, event_type, processing_status, received_at FROM payment_events WHERE provider IN ('APPLE_IAP','GOOGLE_IAP') ORDER BY received_at DESC LIMIT 10;` |
| Zakup nadał uprawnienie | `SELECT provider, status, store_product_id, store_environment, current_period_end FROM subscriptions WHERE organization_id = '<org>';` |
| Cron uzgadniania działa | `gcloud scheduler jobs run billing-store-reconcile --location=europe-central2` + odpowiedź `{"checked":N,...}` |
| Kod rabatowy liczy użycia | `SELECT code, redemptions_count, max_redemptions FROM discount_codes;` |
