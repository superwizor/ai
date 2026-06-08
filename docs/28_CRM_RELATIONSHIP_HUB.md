# 28. CRM Relationship Hub — Panel Marcina

Dokument opisuje implementację panelu CRM wbudowanego w Admin Dashboard, zaprojektowanego specjalnie pod styl pracy Marcina — relationship buildera, który stawia na osobisty kontakt 1:1 z terapeutami.

---

## 1. Cel i Filozofia

Marcin nie jest typowym administratorem. To były manager zespołu agentów nieruchomości w USA, który buduje relacje osobiste z każdym klientem. CRM musi mu pomagać:

1. **Wiedzieć kogo obdzwonić TERAZ** — priorytetowy inbox z follow-upami
2. **Pamiętać kontekst rozmowy** — prywatne notatki per terapeuta
3. **Widzieć czerwone flagi** — alerty o kończących się kredytach i wygasających subskrypcjach
4. **Szybko wysłać email** — gotowe szablony pisane językiem klinicznym (nie korporacyjnym)
5. **Zarządzać etapami lifecycle** — wiedzieć kto jest nowy, kto aktywny, kto zagrożony odejściem

---

## 2. Architektura

### Backend (billing-svc)

**Migracja:** `000051_crm_tables.up.sql`

```sql
-- Prywatne notatki Marcina per user
CREATE TABLE crm_notes (
    id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    admin_user_id    TEXT NOT NULL,
    target_user_id   UUID NOT NULL REFERENCES users(id),
    body             TEXT NOT NULL,
    created_at       TIMESTAMPTZ DEFAULT now()
);

-- Follow-upy (scheduler)
CREATE TABLE crm_follow_ups (
    id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    admin_user_id    TEXT NOT NULL,
    target_user_id   UUID NOT NULL REFERENCES users(id),
    due_date         DATE NOT NULL,
    note             TEXT,
    completed        BOOLEAN DEFAULT false,
    completed_at     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ DEFAULT now(),
    UNIQUE(admin_user_id, target_user_id, due_date)
);

-- Tagi (tagowanie userów: "entuzjasta", "sceptyk", "potrzebuje pomocy")
CREATE TABLE crm_tags (
    id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    target_user_id   UUID NOT NULL REFERENCES users(id),
    tag              TEXT NOT NULL,
    created_at       TIMESTAMPTZ DEFAULT now(),
    UNIQUE(target_user_id, tag)
);

-- Wykluczenie (blokada usera z widoku CRM)
CREATE TABLE crm_excluded_users (
    user_id          UUID PRIMARY KEY REFERENCES users(id),
    reason           TEXT,
    excluded_at      TIMESTAMPTZ DEFAULT now()
);
```

**Ważne:** Dane CRM (notatki, tagi) **nie są PHI** — nie wymagają szyfrowania `pkg/cryptobox`. To wewnętrzne notatki administracyjne.

### Handlery HTTP

Plik: `billing-svc/internal/adapters/http/crm_handler.go`

| Endpoint | Metoda | Opis |
|---|---|---|
| `/admin/crm/user/{userId}/notes` | GET | Lista notatek per user |
| `/admin/crm/notes` | POST | Dodaj notatkę |
| `/admin/crm/follow-ups` | GET | Lista follow-upów (+ `today_count`, `overdue_count`) |
| `/admin/crm/follow-ups` | POST | Stwórz follow-up (idempotent — `ON CONFLICT DO UPDATE`) |
| `/admin/crm/follow-ups/{id}/complete` | PATCH | Oznacz jako zrobiony |
| `/admin/crm/user/{userId}/tags` | GET | Tagi usera |
| `/admin/crm/tags` | POST | Dodaj tag (case-insensitive, `ON CONFLICT DO NOTHING`) |
| `/admin/crm/tags/{id}` | DELETE | Usuń tag |
| `/admin/crm/exclude` | POST | Wyklucz usera z CRM |
| `/admin/crm/exclude/{userId}` | DELETE | Przywróć usera do CRM |
| `/admin/crm/user/{userId}/detail` | GET | Pełny widok per-user (agregacja z 5 tabel) |

### Filtrowanie wykluczonych

Endpoint listy subskrybentów (`handleCRMSubscribers` w `admin_handler.go`) używa anti-join SQL:

```sql
LEFT JOIN crm_excluded_users ex ON ex.user_id = u.id
...
WHERE ex.user_id IS NULL  -- filtruj wykluczonych
```

---

## 3. Frontend

Plik: `marketing-site/src/components/admin/CRMDashboard.tsx` (~858 linii)

### Sekcje interfejsu

#### A. Priority Inbox
```
📋 Dziś do kontaktu: 3 osoby (1 zaległa!)
┌───────────────────────────────────────────┐
│ Anna Kowalska — Sprawdzić po pierwszym... │ 📞 ✓
│ 🔴 ZALEGŁE                               │
│ Tomasz Nowak — Koniec triala jutro        │ 📞 ✓
└───────────────────────────────────────────┘
```

#### B. KPI Chips
5 kart na górze: Łącznie | 🔴 Krytyczne | 🟡 Ostrzeżenie | ⏰ Wygasa | ❌ Churned

#### C. Tabela subskrybentów
Kolumny: Użytkownik | Plan | Kredyty (progress bar) | Sesje | Odnowienie | Alerty | Akcje (📞📧🔔)

Filtry:
- **Plan tier:** Wszystkie / 🧪 Beta / 🆓 Trial / 🌿 Równowaga / 🌸 Rozkwit / 🏥 Klinika
- **Status:** Aktywny / Trial / Anulowany / Zaległy
- **Alert:** Krytyczne (≤1 kredyt) / Ostrzeżenie (≤3 kredyty)
- **Search:** wolnotekstowe po imieniu, emailu, organizacji

#### D. Slide-out Drawer (po kliknięciu na usera)
- Karta kontaktowa (imię, email, 📱 telefon jednym kliknięciem, tytuł zawodowy)
- Lifecycle badge (🆕 Nowy → 📋 Onboarding → 🎯 Pierwsza sesja → ✅ Aktywny → ⚡ Power User → ⚠️ Zagrożony → ❌ Odszedł)
- Quick stats: Sesje | Kredyty | Dni do końca
- Tagi (pill badges z ×)
- Follow-upy (lista z datami + ✓ do oznaczenia)
- 5 szablonów emailowych (grid 2×3)
- 📓 Notatki (textarea + lista chronologiczna)
- 🚫 Wyklucz z CRM (przycisk na dole)

#### E. Email Composer (modal)
- Pre-filled z szablonu
- Podmiana zmiennych: `{name}`, `{remaining}`, `{period_end}`
- „Otwórz w kliencie email" → `mailto:` link z `from=kontakt@superwizor.ai`

#### F. Follow-up Scheduler (modal)
- Quick-date buttons: Jutro / Za 3 dni / Poniedziałek / Za tydzień
- Date picker + notatka opcjonalna

---

## 4. Lifecycle Stages

7 etapów lifecycle obliczanych w `computeLifecycleStage()`:

| Etap | Warunek | Emoji |
|---|---|---|
| `new` | Brak planu, brak sesji | 🆕 |
| `onboarding` | Ma plan, 0 sesji | 📋 |
| `first_session` | Dokładnie 1 sesja | 🎯 |
| `active` | 2–19 sesji, < 14 dni od ostatniej | ✅ |
| `power_user` | ≥ 20 sesji | ⚡ |
| `at_risk` | > 14 dni od ostatniej sesji | ⚠️ |
| `churned` | Status subskrypcji = CANCELED | ❌ |

---

## 5. Alert System

Alerty obliczane w SQL przy pobieraniu listy subskrybentów:

| Typ | Warunek | Wyświetlanie |
|---|---|---|
| `credit_alert = "critical"` | Zostało ≤ 1 kredyt | 🔴 |
| `credit_alert = "warning"` | Zostało ≤ 3 kredyty | 🟡 |
| `expiry_alert = "imminent"` | ≤ 3 dni do końca okresu | ⏰ |

---

## 6. Szablony Emailowe

5 wbudowanych szablonów, napisane w stylu **Clinical UX Writing** (ciepło, bez toksycznej pozytywności):

| ID | Kiedy użyć | Temat |
|---|---|---|
| `after_first` | Po pierwszej sesji usera | "Jak przebiegła Twoja pierwsza sesja?" |
| `credits_low` | Zostało ≤3 kredyty | "Zostały Ci {remaining} sesje" |
| `trial_end` | Zbliża się koniec triala | "Twój okres próbny dobiega końca" |
| `check_in` | Regularny check-in | "Jak leci z SuperWizorem?" |
| `dormant` | Brak aktywności > 14 dni | "Tęsknimy za Tobą w SuperWizorze" |

---

## 7. CSV Export

Przycisk „📥 Eksport CSV" generuje plik z kolumnami:
Imię, Nazwisko, Email, Telefon, Plan, Status, Sesje, Kredyty użyte, Kredyty pozostałe, Limit, Koniec okresu, Dni do odnowienia, Alert, Pilność, Dołączył

Nazwa pliku: `superwizor-crm-2026-06-09.csv`
