---
type: Technical Design
title: "38 — Zarządzanie organizacją (panel org managera + provisioning przez admina)"
description: "Status: DESIGN (2026-07-03). Buduje na istniejących fundamentach — to jest delta, nie budowa od zera. Audyt stanu: organizations + rola ORGADMIN (migracja 00..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/38_ORG_MANAGEMENT_DESIGN.md
tags: [ai, analytics, architecture, billing, crm, database, frontend, identity, notifications, security, testing]
timestamp: 2026-07-03T18:37:20+02:00
---

# 38 — Zarządzanie organizacją (panel org managera + provisioning przez admina)

Status: DESIGN (2026-07-03). Buduje na istniejących fundamentach — to jest
**delta**, nie budowa od zera. Audyt stanu: organizations + rola `ORG_ADMIN`
(migracja 000037), zaproszenia magic-link (000035, `InviteTherapist` /
`AcceptInvitation`), panel `/admin/orgs` w web-app, plany z `price_gross`,
`licenses_limit` i `has_b2b_dashboard` (000028), widoki analityczne (000044).

## 0. Personas i workflow (wymaganie)

1. **SUPERWIZOR_ADMIN** (panel `/admin`): zakłada konto organizacji — dane
   firmowe, e-maile org managerów, liczba miejsc (seats) per plan, ceny per
   plan, możliwość zmiany planu, data startu subskrypcji.
2. System wysyła e-mail zapraszający do **org managera**. Onboarding: ustawia
   hasło (Firebase, jak dotąd) **lub** social login → `AcceptInvitation`.
3. **Org manager** (rola `ORG_ADMIN`, panel `/org` w web-app):
   dodaje terapeutów w ramach planów (e-mail, imię, nazwisko, status),
   deaktywuje/reaktywuje, po deaktywacji może dodać nowego **w ramach limitu
   miejsc**, oraz przegląda sekcję Analityki.

## 1. Co już jest (reużywamy)

| Element | Gdzie | Użycie w tym projekcie |
|---|---|---|
| `organizations` (legal_name, tax_id, vat_id_eu, adres HQ, type CLINIC/ENTERPRISE) | 000003 | dane firmowe — bez zmian |
| Rola `ORG_ADMIN` + single-role MVP | 000037, docs/18 R4 | org manager = ORG_ADMIN |
| `invitations` (SHA-256 token, 7 dni, unique (org,email)) + `InviteTherapist`/`AcceptInvitation` | 000035, identity.proto:53-61 | rozszerzamy o rolę i plan |
| `subscription_plans` (tier, cycle, tokens_per_period, **price_gross**, **licenses_limit**) | 000028 | katalog planów |
| `subscriptions` (org-scoped, MANUAL provider, period start/end) + `usage_counters` | 000028 | subskrypcja kliniki |
| Panel `/admin/orgs`, `/admin/orgs/[id]` + `AdminListOrganizations`, `AdminGetOrganization`, `AdminUpdateOrganization`, `AdminResetTokens`, `AdminChangePlan` (audit + reason ≥10 zn.) | web-app + identity/billing proto | rozszerzamy o kreator organizacji |
| `/account` z `GetMyOrganization`, `ListTherapistsInMyOrg`, `RemoveTherapist` | web-app | zalążek panelu `/org` |
| `email_templates` (template_key, locale) + notification-svc | 000041 | e-maile zaproszeń (bez PHI → obecny dostawca OK) |
| `analytics_events` + widoki `v_analytics_*` (WAU, session_freq, token_util, satisfaction…) | 000044 | baza sekcji Analityki |

## 2. Luki do zaimplementowania (delta)

1. **Provisioning organizacji przez admina** — `RegisterOrganization` jest
   self-serve; brak `AdminCreateOrganization` i zaproszenia org managera.
2. **Seats per plan z ceną negocjowaną** — `licenses_limit` to pole katalogowe
   planu; brak alokacji per organizacja (ile miejsc, w jakim planie, po ile).
3. **Status terapeuty aktywny/nieaktywny** — dziś tylko soft-delete
   (`RemoveTherapist`); brak odwracalnej deaktywacji zwalniającej miejsce
   i blokującej dostęp.
4. **Egzekwowanie limitu miejsc** przy zapraszaniu/reaktywacji.
5. **Analityka per terapeuta dla ORG_ADMIN** — brak RPC/widoków org-scoped.

## 3. Model danych (nowe migracje)

```sql
-- 0000NN_org_seat_allocations.up.sql
CREATE TABLE org_seat_allocations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id),
  plan_id UUID NOT NULL REFERENCES subscription_plans(id),
  seats INT NOT NULL CHECK (seats >= 0),
  -- cena negocjowana per miejsce; NULL = price_gross z katalogu
  price_gross_per_seat NUMERIC(10,2),
  currency_code CHAR(3) NOT NULL DEFAULT 'PLN',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (organization_id, plan_id)
);

-- 0000NN_user_activation.up.sql
ALTER TABLE users ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN deactivated_at TIMESTAMPTZ;
-- przypisanie terapeuty do alokacji (historia zajętości miejsc)
CREATE TABLE seat_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  allocation_id UUID NOT NULL REFERENCES org_seat_allocations(id),
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  unassigned_at TIMESTAMPTZ            -- NULL = miejsce zajęte
);
CREATE UNIQUE INDEX one_active_seat_per_user
  ON seat_assignments (user_id) WHERE unassigned_at IS NULL;

-- 0000NN_invitations_role_plan.up.sql
ALTER TABLE invitations ADD COLUMN invited_role user_role NOT NULL DEFAULT 'THERAPIST';
ALTER TABLE invitations ADD COLUMN allocation_id UUID REFERENCES org_seat_allocations(id);
```

**Definicja zajętości miejsca:** `COUNT(seat_assignments WHERE allocation_id=X
AND unassigned_at IS NULL) + COUNT(pending invitations dla X)` ≤ `seats`.
Deaktywacja terapeuty ⇒ `unassigned_at = now()` ⇒ miejsce wolne. Zaproszenie
rezerwuje miejsce do czasu wygaśnięcia (7 dni) albo akceptacji.

**Model rozliczeń (decyzja 2026-07-03):** zostaje **jedna subskrypcja
MANUAL per organizacja**, ale **licznik tokenów jest per seat (terapeuta)**:
każdy terapeuta ma własny `usage_counter` (`therapist_id` w 000064) z
`tokens_limit = tokens_per_period` planu jego miejsca, odnawiany zgodnie z
cyklem tego planu. **Egzekwowanie jest per-terapeuta** — terapeuta po
wyczerpaniu SWOJEGO limitu jest blokowany, nawet gdy inni mają zapas.
`ReserveCredit`/`LockActiveCounter` lockuje licznik terapeuty wołającego,
z fallbackiem na licznik org-level (`therapist_id IS NULL`) dla organizacji
bez alokacji / kont solo — pełna kompatybilność wstecz. Wartość faktury =
`Σ(seats × COALESCE(price_gross_per_seat, plan.price_gross))`. Zmiana
alokacji przez admina tworzy/aktualizuje liczniki bieżącego okresu (jak
`AdminChangePlan`). `pending_reservations.therapist_id` gwarantuje, że
release/expiry/commit trafia w ten sam licznik, który został obciążony.

## 4. API (nowe/rozszerzone RPC)

### identity-svc
```protobuf
// SUPERWIZOR_ADMIN. Jedna transakcja: organizacja + adres + zaproszenia
// org managerów. reason ≥10 zn., audit_events.
rpc AdminCreateOrganization(AdminCreateOrganizationRequest) returns (OrganizationDetails);
message AdminCreateOrganizationRequest {
  string legal_name = 1; string tax_id = 2; string vat_id_eu = 3;
  Address headquarters = 4; OrganizationType type = 5;      // CLINIC|ENTERPRISE
  repeated string manager_emails = 6;                        // → invitations(ORG_ADMIN)
  string reason = 15; string idempotency_key = 16;
}

// ORG_ADMIN. Rozszerzenie istniejącego InviteTherapist o miejsce w planie.
// Waliduje wolne miejsca w alokacji (patrz §3) — inaczej FAILED_PRECONDITION
// "SEATS_EXHAUSTED".
rpc InviteTherapist(...) // + allocation_id, first_name/last_name już są

// ORG_ADMIN. Odwracalna deaktywacja (NIE soft-delete).
rpc SetTherapistStatus(SetTherapistStatusRequest) returns (User);
message SetTherapistStatusRequest { string user_id = 1; bool is_active = 2; }

// Rozszerzenia odpowiedzi: ListTherapistsInMyOrg → + is_active, plan_tier,
// last_session_at; AcceptInvitation honoruje invitations.invited_role
// (ORG_ADMIN dla managera) i tworzy seat_assignment dla terapeuty.
```

### billing-svc
```protobuf
// SUPERWIZOR_ADMIN. Ustawia alokacje miejsc + start subskrypcji.
// Tworzy/aktualizuje subskrypcję MANUAL (current_period_start = start) i
// usage_counter per plan dla kazdego terapeuty, odnawialne zgodnie z wybranym planem
rpc AdminSetSeatAllocations(AdminSetSeatAllocationsRequest) returns (OrgSeatSummary);
message AdminSetSeatAllocationsRequest {
  string organization_id = 1;
  repeated SeatAllocation allocations = 2;   // {plan_id, seats, price_gross_per_seat?}
  google.protobuf.Timestamp subscription_start = 3;
  string reason = 15; string idempotency_key = 16;
}

// ORG_ADMIN. Zajętość miejsc + zużycie tokenów per terapeuta i plan (na dashboard).
rpc GetMyOrgSeatUsage(google.protobuf.Empty) returns (OrgSeatSummary);
```

### clinical-svc (analityka — patrz §7)
```protobuf
// ORG_ADMIN. Wyłącznie agregaty metadanych — zero PHI (patrz §7.3).
rpc GetOrgTherapistMetrics(GetOrgTherapistMetricsRequest) returns (OrgTherapistMetricsResponse);
message GetOrgTherapistMetricsRequest { Period period = 1; }  // presety: 7d/30d/90d/custom
```

### Egzekwowanie deaktywacji
`is_active=false` sprawdzane w interceptorze auth identity-svc
(`ValidateToken` → `PermissionDenied "ACCOUNT_DEACTIVATED"`), propagowane jak
`x-superwizor-role`. Aplikacja Flutter/web pokazuje ekran „konto nieaktywne —
skontaktuj się z administratorem organizacji". Dane terapeuty (kartoteki,
sesje) pozostają nienaruszone; `RemoveTherapist` (soft-delete) zostaje jako
ścieżka RODO.

## 5. Workflow end-to-end

1. **Admin** (`/admin/orgs/new`): formularz — dane firmowe → alokacje miejsc
   (tabela: plan × seats × cena/miejsce, suma tokenów i wartość widoczna od
   razu) → data startu → e-maile managerów. Submit =
   `AdminCreateOrganization` + `AdminSetSeatAllocations` (idempotentnie).
2. **E-mail do org managera** (notification-svc, szablon
   `org_manager_invite` pl/en — bez PHI): link
   `https://superwizor.ai/invite/<token>`.
3. **Onboarding managera**: strona akceptacji w web-app → Firebase (hasło lub
   Google) → `AcceptInvitation(token, firebase_uid, …)` → user `ORG_ADMIN`
   w organizacji → redirect do `/org`.
4. **Panel `/org`** (gating: rola ORG_ADMIN; analogicznie do AdminGuard):
   - **Zespół**: lista terapeutów (imię, nazwisko, e-mail, plan, status,
     ostatnia sesja) + pasek zajętości per plan („SOLO: 7/10 miejsc").
     Akcje: „Zaproś terapeutę" (modal: e-mail, imię, nazwisko, wybór planu z
     wolnym miejscem), „Deaktywuj"/„Aktywuj" (SetTherapistStatus; reaktywacja
     waliduje wolne miejsce), lista zaproszeń oczekujących (z możliwością
     anulowania — zwalnia rezerwację).
   - **Analityka**: §7.
   - **Organizacja**: dane firmowe (`GetMyOrganization`/`UpdateMyOrganization`
     — istnieje).
   - **Subskrypcja**: alokacje + ceny + zużycie tokenów + faktury
     (`GetMyOrgSeatUsage`, `ListInvoices` — istnieje).
5. **Terapeuta zaproszony przez managera**: identyczny flow magic-link
   (istniejący `AcceptInvitation`), ląduje w aplikacji mobilnej/web.

## 6. UI web-app (Next.js, istniejące wzorce)

- Nowe strony: `/[locale]/admin/orgs/new` (kreator, 3 kroki) oraz
  `/[locale]/org` z zakładkami (Team / Analytics / Organization / Billing).
- Reużycie: `AdminGuardAndShell` → analogiczny `OrgGuardAndShell`
  (rola ORG_ADMIN), transport Connect + i18n next-intl (pl/en), komponenty
  tabel z `/admin/orgs`.
- `/account` dla ORG_ADMIN przekierowuje sekcję organizacji do `/org`
  (deduplikacja istniejącej powierzchni).

## 7. Sekcja Analityki dla organizacji

### 7.1 Metryki per terapeuta (tabela + drill-down, okres 7/30/90 dni)

Wszystko liczone z istniejących tabel (sessions, patient_files, reports,
report_ratings, pending_reservations/usage, analytics_events):

| Metryka | Źródło |
|---|---|
| Liczba sesji (ukończonych / nieudanych / anulowanych) - globalnie oraz per terapeuta | `sessions.status`, `session_date` |
| Łączny i średni czas sesji - globalnie oraz per terapeuta | `sessions.duration_seconds` |
| Aktywni pacjenci (kartoteki otwarte) - globalnie oraz per terapeuta | `patient_files` (`is_process_closed=false`, `deleted_at IS NULL`) |
| Nowi pacjenci w okresie / zamknięte procesy - globalnie oraz per terapeuta | `patient_files.created_at`, `is_process_closed` |
| Średnia liczba sesji na pacjenta i średni odstęp między sesjami pacjenta - globalnie oraz per terapeuta | `sessions` per `patient_file_id` |
| Forma kontaktu (gabinet/online) - globalnie oraz per terapeuta | `sessions.contact_form` |
| Zużyte tokeny + % limitu organizacji - globalnie oraz per terapeuta | `pending_reservations`/`usage_counters` per `therapist_id` |
| Ostatnia aktywność (ostatnia sesja / logowanie) - globalnie oraz per terapeuta | `sessions.session_date`, `analytics_events` |
| Ocena raportów (👍/👎 ratio) — proxy jakości pracy z narzędziem - globalnie oraz per terapeuta | `report_ratings` |
| Odsetek sesji z obejrzanym raportem - globalnie oraz per terapeuta | `sessions.report_viewed_at` |

### 7.2 Raporty dla właściciela kliniki (dashboard + eksport CSV)

1. **Obłożenie zespołu (utilization):** sesje i godziny tygodniowo per
   terapeuta vs średnia kliniki; heatmapa dzień×godzina (planowanie grafiku).
2. **Trendy wolumenu:** sesje/godziny miesięcznie — cała klinika i per
   terapeuta (wzrost/spadek, sezonowość).
3. **Caseload i retencja:** rozkład aktywnych pacjentów per terapeuta;
   pacjenci bez sesji > 3/6 tyg. (ryzyko dropoutu); nowi vs zamknięci
   (net retention procesów).
4. **Ciągłość opieki:** median odstępu między sesjami pacjenta per terapeuta
   (regularność pracy).
5. **Wykorzystanie licencji i kosztów:** zajęte/kupione miejsca per plan;
   tokeny zużyte vs limit + prognoza wyczerpania; koszt na sesję
   (`v_analytics_session_cost` — już istnieje).
6. **Alerty operacyjne:** terapeuta bez sesji > X dni; zaproszenie wygasa;
   zbliżający się limit tokenów (80/95%); pacjent porzucony.
7. **Jakość korzystania z narzędzia:** aktywacja funkcji (notatki, plany
   działań — `analytics_events`), satysfakcja z raportów
   (`v_analytics_satisfaction` org-scoped).

Implementacyjnie: 2–3 nowe widoki SQL org-scoped (wzorem `v_analytics_*`
z 000044) + `GetOrgTherapistMetrics`; dashboard w web-app (wykresy —
lekka biblioteka, np. recharts, już w konwencji Next.js).

### 7.3 Prywatność (twarda granica — spójność z docs/37 i zgodą pacjenta)

**ORG_ADMIN widzi wyłącznie agregaty metadanych.** Nigdy: transkryptów,
raportów, notatek, aliasów/tożsamości pacjentów. Metryki pacjenckie tylko
jako liczności. RPC analityczne zwracają agregaty per terapeuta — bez
identyfikatorów pacjentów. To samo ograniczenie co panel SUPERWIZOR_ADMIN
(metadane-only) i warunek zgodności ze wzorem zgody („dostęp do materiałów ma
wyłącznie terapeuta"). Wzór zgody dla klinik powinien dodatkowo wymieniać
organizację jako administratora/współadministratora — do konsultacji prawnej.

## 8. Plan implementacji (PR-y)

| PR | Zakres | Zależy od |
|---|---|---|
| PR1 | Migracje §3 (alokacje, is_active, seat_assignments, invitations+role/plan) | — |
| PR2 | identity-svc: AdminCreateOrganization, InviteOrgManager (via invitations), AcceptInvitation z rolą, SetTherapistStatus, egzekwowanie `is_active` w interceptorze | PR1 |
| PR3 | billing-svc: AdminSetSeatAllocations (+ przeliczenie tokens_limit), GetMyOrgSeatUsage; walidacja SEATS_EXHAUSTED w InviteTherapist | PR1 |
| PR4 | notification-svc: szablony `org_manager_invite`, `therapist_invite` (pl/en) | PR2 |
| PR5 | web-app: `/admin/orgs/new` (kreator) | PR2+PR3 |
| PR6 | web-app: panel `/org` (Zespół + Organizacja + Subskrypcja) | PR2+PR3 |
| PR7 | Analityka: widoki SQL org-scoped + GetOrgTherapistMetrics + zakładka Analityka | PR6 |
| PR8 | Flutter: ekran „konto nieaktywne" (obsługa ACCOUNT_DEACTIVATED) | PR2 |
| PR9 | E2E: provisioning → zaproszenie → akceptacja → limit miejsc → deaktywacja → reaktywacja; testy analityki | wszystkie |

Ryzyka/decyzje otwarte: (a) model rozliczeń per-plan-pool zamiast wspólnego
licznika (odłożone — §3); (b) współadministrowanie danymi w klinice (prawne);
(c) ORG_ADMIN będący jednocześnie terapeutą — poza MVP (single-role,
docs/18 R4).
