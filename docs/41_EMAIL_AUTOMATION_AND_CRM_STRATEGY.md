---
type: System Documentation
title: "41. Strategia Automatyzacji E-mail i CRM"
description: "Dokument podsumowuje istniejące szablony e-mail w systemie Superwizor AI, analizuje mechanizmy drip i CRM, oraz przedstawia rekomendacje wdrożeniowe."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/41_EMAIL_AUTOMATION_AND_CRM_STRATEGY.md
tags: [email, crm, automation, marketing, backend]
timestamp: 2026-07-16T01:55:00+02:00
---

# 41. Strategia Automatyzacji E-mail i CRM

Dokument ten podsumowuje stan komunikacji mailowej w platformie **Superwizor AI**, opisuje zaimplementowane nowości w silniku szablonów HTML, przedstawia pełną analizę (Q&A) potencjalnych automatyzacji oraz dostarcza gotowy szablon zadania (Notion/Kanban) do wdrożenia automatycznego silnika wysyłkowego.

---

## 1. Co już mamy w systemie? (Inwentaryzacja)

Obecnie platforma posiada podzielone kanały komunikacji na automatyczne (transakcyjne) oraz relacyjne (ręczne):

### A. E-maile transakcyjne (Automatyczne i półautomatyczne)
Zarządzane przez `notification-svc` (obsługa Resend). Posiadamy 10 szablonów w [services/notification-svc/internal/i18n/templates/pl/](file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/superwizor-backend/services/notification-svc/internal/i18n/templates/pl):

| Nazwa szablonu | Typ komunikatu / Trigger | Obecny status wdrożenia |
|---|---|---|
| `welcome.md` | Po rejestracji nowego terapeuty | **Wdrożony** (automatyczny) |
| `email_verification.md` | Potwierdzenie adresu e-mail (link Firebase) | **Wdrożony** (automatyczny) |
| `invitation.md` | Zaproszenie terapeuty do organizacji | **Wdrożony** (automatyczny) |
| `org_manager_invite.md` | Zaproszenie managera placówki | **Wdrożony** (automatyczny) |
| `patient_invite.md` | Zaproszenie pacjenta do panelu klienta | **Wdrożony** (automatyczny) |
| `action_plan.md` | Wysłanie planu działania do pacjenta | **Wdrożony** (na żądanie terapeuty) |
| `client_note_received.md` | Powiadomienie o notatce przesłanej przez pacjenta | **Wdrożony** (automatyczny) |
| `client_panel_new_item.md`| Udostępnienie nowej sesji/notatki pacjentowi | **Wdrożony** (automatyczny) |
| `quota_warning.md` | Ostrzeżenie o zużyciu limitu pakietu (80% / 95%) | **Wdrożony** (automatyczny, wyzwalany z billing-svc) |
| `trial_exhausted.md` | Wykorzystanie 5 darmowych sesji w okresie próbnym | **Przygotowany szablon** (cron wykrywa, ale brak wysyłki) |
| `followup_1.md` | Check-in 3 dni po wygaśnięciu triala | **Przygotowany szablon** (cron wykrywa, ale brak wysyłki) |
| `followup_2.md` | Check-in 7 dni po wygaśnięciu triala | **Przygotowany szablon** (cron wykrywa, ale brak wysyłki) |
| `renewal_reminder.md` | Przypomnienie o zbliżającym się odnowieniu subskrypcji | **Przygotowany szablon** (cron wykrywa, ale brak wysyłki) |
| `beta_expiry_alert.md` | Powiadomienie o wygaśnięciu planu Beta | **Przygotowany szablon** (cron wykrywa, ale brak wysyłki) |

### B. CRM Relacyjny Marcina (Ręczny)
W Admin Dashboard istnieje zintegrowany hub relacji, w którym Marcin widzi stan każdego użytkownika, jego stopień aktywności (Lifecycle Stages: *new, onboarding, first_session, active, power_user, at_risk, churned*), oraz ma zestaw 5 szablonów emailowych otwierających pre-filled linki `mailto:` (styl pisania kliniczny, empatyczny, nastawiony na relację 1:1):
* **after_first:** Badanie wrażeń po 1. sesji.
* **credits_low:** Przypomnienie o niskim stanie konta sesji (kiedy zostało $\le 3$ kredyty).
* **trial_end:** Przypomnienie o końcu darmowych sesji próbnych.
* **check_in:** Standardowy kontakt relacyjny co jakiś czas.
* **dormant:** Reaktywacja nieaktywnych użytkowników (brak sesji od $>14$ dni).

---

## 2. Nowość: Szablonowanie Branded HTML

Dotychczas jedynie e-mail weryfikacyjny posiadał zaawansowaną oprawę graficzną (białe tło, zielony gradient marki `#004D54` $\to$ `#002E32`, żółty pasek akcentujący, logo i fonty Montserrat). Inne e-maile były konwertowane za pomocą prostego shima `bodyToHTML` do surowego tekstu systemowego.

Wprowadziliśmy **uniwersalny system szablonowania HTML** dla e-maili transakcyjnych:
1. **[generic_email.html](file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/superwizor-backend/services/notification-svc/internal/i18n/templates/generic_email.html)**: Nowy, uniwersalny szablon HTML dziedziczący pełną estetykę premium po mailu weryfikacyjnym.
2. **Dynamiczny CTA & Fallback**: Jeśli wysyłany e-mail zawiera główny link akcji (np. `accept_url`, `billing_url`, `panel_url`), silnik generuje w pełni responsywny, żółty przycisk CTA oraz dodaje link fallback na dole wiadomości z informacją o bezpieczeństwie. Jeśli linku nie ma, sekcja ta jest automatycznie i czysto pomijana.
3. **Inteligentny Parser Markdown**: Konwertuje akapity, pogrubienia (`**tekst**`) oraz wypunktowania (`- element`) na poprawny kod HTML dopasowany do klientów pocztowych (Gmail, Outlook, Apple Mail).
4. **Wdrożenie**: Szablon został wpięty i przetestowany w metodach `SendInvitationEmail`, `SendQuotaWarning`, `SendClientPanelEvent` oraz `SendActionPlanEmail`.

---

## 3. Plik Q&A: Rekomendacje Automatyzacji Marketingowo-Biznesowych

### Pytanie 1: Co zyskamy poprzez pełną automatyzację e-maili cyklu życia (lifecycle drip)?
**Odpowiedź:** 
Zmniejszamy współczynnik utraty użytkowników (Churn Rate) i zwiększamy konwersję na płatne plany (Activation Rate). Terapeuci są zapracowaną grupą zawodową. Jeśli zapomną o aplikacji zaraz po rejestracji, brak kontaktu oznacza ich bezpowrotną utratę. Automatyzacja dba o to, by system przypomniał o sobie w kluczowych momentach.

### Pytanie 2: Jakie automatyczne maile możemy wdrożyć w oparciu o zbierane dane?
**Odpowiedź:**
Nasza baza SQL w `billing-svc` oraz `sessions` dostarcza nam unikalnych punktów zapalnych, na które możemy reagować automatycznie:

1. **Aktywacja i Onboarding (Drip edukacyjny)**:
   * **Trigger:** Ma plan (np. Trial), ale w tabeli `sessions` ma 0 wpisów po 48 godzinach.
   * **Treść:** *„Poradnik Dobrego Nagrania”* — krótka, estetyczna instrukcja jak uzyskać najlepszą jakość dźwięku, jak radzić sobie z szumami oraz jak łatwo uzyskać zgodę pacjenta.
2. **Koniec limitów kredytów (Stripe / In-app)**:
   * **Trigger:** Użytkownik wykorzystał swój limit (np. 30 sesji w planie Równowaga) przed końcem okresu rozliczeniowego.
   * **Treść:** Propozycja dokupienia jednorazowej paczki sesji (Top-up) lub natychmiastowego przejścia na wyższy plan (Rozkwit - 90 sesji) z pro-ratą.
3. **Pętla Wartości (Weekly / Monthly Digest)**:
   * **Trigger:** System co poniedziałek rano zlicza sesje terapeuty z ostatniego tygodnia.
   * **Treść:** *„Twoje podsumowanie tygodnia”*. Wizualny dowód wartości: *„W tym tygodniu zaoszczędziłeś 4 godziny papierkowej roboty dzięki 8 raportom AI. Twoi pacjenci otrzymali 3 plany działania.”* Zamiast spamu, dostarczamy czystą wartość i dumę z zaoszczędzonego czasu.
4. **Powiadomienia o nieudanej płatności (Stripe Dunning)**:
   * **Trigger:** Webhook Stripe informuje o braku środków na karcie przy próbie odnowienia subskrypcji.
   * **Treść:** Kulturalna prośba o aktualizację karty z bezpośrednim odnośnikiem do portalu rozliczeniowego.
5. **Reaktywacja uśpionych (Dormancy / Win-back)**:
   * **Trigger:** Brak jakiejkolwiek aktywności (nagrania sesji) od 14/30 dni u aktywnego subskrybenta.
   * **Treść:** *„Jak możemy pomóc?”*. Pytanie, czy zmienił się profil pacjentów, czy może aplikacja w czymś zawiodła. Oferta krótkiej konsultacji 1:1 z supportem.

### Pytanie 3: Jak powinna wyglądać kooperacja Automatu z CRM Marcina?
**Odpowiedź:**
Terapeuci są bardzo czuli na agresywny marketing automatyczny (często wywołuje on u nich poczucie osaczenia i nieprofesjonalizmu). Dlatego rekomendujemy model hybrydowy:
* **Sprawy techniczne, billingowe i transakcyjne:** 100% automat (potwierdzenie rejestracji, faktura, przypomnienie o odnowieniu, ostrzeżenie o braku środków).
* **Onboarding & Reaktywacja uśpionych (`at_risk`):** Półautomat. System zamiast wysyłać bezosobowy e-mail automatycznie, tworzy zadanie w **Priority Inbox** Marcina. Marcin widzi w CRM alert, klika „Wyślij e-mail reaktywacyjny”, co generuje spersonalizowaną wiadomość z jego skrzynki. Łączymy w ten sposób skalowalność algorytmów z magią relacji osobistej.

---

## 4. Szablon zadania na Notion / Kanban

Poniższy kod w formacie Markdown można bezpośrednio skopiować i wkleić jako opis nowego zadania (karty) w Notion/Jira/Trello:

```markdown
# [TASK] Wdrożenie automatycznego silnika email-drip & billing-reminders

## 🎯 Cel biznesowy
Uruchomienie automatycznych powiadomień mailowych na podstawie danych z bazy PostgreSQL (billing-svc). Chcemy automatycznie powiadamiać użytkowników o wygaśnięciu triala, przypominać o zbliżających się płatnościach Stripe oraz wysyłać dopasowany drip edukacyjny.

## 🛠️ Stan techniczny (Punkt startowy)
1. **Szablony HTML:** W `notification-svc` mamy wdrożony uniwersalny, ostylowany szablon graficzny `generic_email.html` (zielony gradient marki, Montserrat, logo, autolinkowanie CTA).
2. **Crony bazodanowe:** W `billing-svc` (http/admin_handler.go) są zaimplementowane daily/weekly endpointy cronowe `/admin/email-drip` oraz `/admin/renewal-reminders`. SQL poprawnie identyfikuje użytkowników na podstawie kryteriów (wyczerpanie triala, 3 dni przed odnowieniem, followup-1 po 3 dniach, followup-2 po 7 dniach).
3. **Brakujące ogniwo:** W handlerach cronowych w `billing-svc` brakuje realnej integracji z klientem gRPC `notification-svc` oraz zapisu stanu wysłania do tabeli logu `email_drip_log`. Obecnie te funkcje tylko logują informację o kandydatach.

## 📋 Zakres prac deweloperskich
1. **Rozszerzenie AdminHandler w billing-svc:**
   * Przekazać zainicjowany `notificationClient` (który billing-svc już tworzy na start w `main.go`) do konstruktora `NewAdminHandler`.
2. **Implementacja handleEmailDrip:**
   * Dla każdego kandydata z zapytania SQL (Trial Exhausted, Followup-1, Followup-2, Beta Expiry):
     * Wywołać odpowiednie RPC w `notification-svc` (np. stworzyć generyczną metodę gRPC `SendEmail` lub dedykowane rpc jak `SendQuotaWarning`).
     * Zapisać fakt wysłania do tabeli `email_drip_log` w transakcji, aby uniknąć ponownego wysłania (idempotentność bazodanowa).
3. **Implementacja handleRenewalReminders:**
   * Wywołać wysyłkę przypomnienia o odnowieniu planu dla zidentyfikowanych subskrybentów Stripe na 3 dni przed końcem okresu.
4. **Weryfikacja na środowisku Staging:**
   * Wdrożenie i uruchomienie testowe cronów z poziomu Cloud Scheduler.
   * Sprawdzenie logów pod kątem poprawności przejścia stanów w bazie danych.

## 🎨 Wygląd maili
Maile muszą korzystać z nowo utworzonego szablonu `generic_email.html` (jest to już domyślny mechanizm w zaktualizowanym kodzie `notification-svc` dla metod SendInvitation, SendQuotaWarning, SendClientPanel).
```

---

## 5. Podsumowanie zmian deweloperskich

W ramach tego zadania dokonałem modyfikacji w kodzie `notification-svc` w celu ujednolicenia szaty graficznej:
1. **Utworzono:** [generic_email.html](file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/superwizor-backend/services/notification-svc/internal/i18n/templates/generic_email.html) w zasobach wbudowanych serwisu.
2. **Utworzono:** [email_html.go](file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/superwizor-backend/services/notification-svc/internal/adapters/grpc/email_html.go) z funkcją pomocniczą `wrapWithGenericTemplate` i parsowaniem uproszczonego Markdown do standardu e-mail.
3. **Zaktualizowano:** Metody w [invitation_email.go](file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/superwizor-backend/services/notification-svc/internal/adapters/grpc/invitation_email.go), [client_panel_event.go](file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/superwizor-backend/services/notification-svc/internal/adapters/grpc/client_panel_event.go) oraz [action_plan_email.go](file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/superwizor-backend/services/notification-svc/internal/adapters/grpc/action_plan_email.go) w celu użycia nowego silnika szablonów.
4. **Zweryfikowano:** Cały serwis kompiluje się bez błędu (`go build ./...`) i pomyślnie przechodzi wszystkie testy jednostkowe (`go test ./...`).
