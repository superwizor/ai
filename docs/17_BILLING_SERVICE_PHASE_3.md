---
type: System Documentation
title: "17. Billing Service (Faza 3) — Pełny Design"
description: "Wersja: 1.0 (2026-05-25); częściowo zastąpiona przez Phase C refactor (2026-05-27) Status: Canonical design dla rdzenia (DB schema, gRPC contract, quota arit..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/17_BILLING_SERVICE_PHASE_3.md
tags: [service, billing]
timestamp: 2026-05-27T14:25:11+02:00
---

# 17. Billing Service (Faza 3) — Pełny Design

**Wersja:** 1.0 (2026-05-25); częściowo zastąpiona przez Phase C refactor (2026-05-27)
**Status:** Canonical design dla rdzenia (DB schema, gRPC contract, quota arithmetic, Stripe stub). Zastępuje wstępny plan z `b371abbd-fe69-4093-a063-9af7dab67354/implementation_plan.md`.
**Powiązane dokumenty:** `01_ARCHITEKTURA_TECHNICZNA.md §4.2.2`, `02_DATA_MODEL.md §4.4`, `agents/00_GLOBAL_CONTEXT.md`, `agents/03_billing-svc.md`, **`18_BILLING_IMPLEMENTATION_FLOW.md` v2.0** (canonical opis aktualnego flow po Phase C — w razie konfliktu wygrywa).
**Zasada nadrzędna:** W razie konfliktu z Konstytucją (`P1` Zero Data Loss, `P4` Flutter read-only, `Świętość Nagrania`) — Konstytucja wygrywa.

> **⚠️ Phase C update (2026-05-27, branch `feat/billing-svc-refactor`):** Mechanizm propagacji stanu kwoty został uproszczony. Sekcje opisujące **outbox + Pub/Sub `billing.outbox` + Firestore `organization_quota` mirror + notification-worker-on-billing CF + edge-threshold FCM push** są **SUPERSEDED** — patrz `18_BILLING_IMPLEMENTATION_FLOW.md` §5. Krótko: Flutter teraz pobiera stan przez `clinical-svc.GetMyBillingState` (cold start) plus `state_after` na każdej odpowiedzi `ReserveCredit` / `CommitUsage`. Tabela `outbox_events`, topic `billing.outbox`, mirror Firestore i Cloud Function `notification-worker-on-billing` zostały usunięte (migracja 000034, terragrunt apply 2026-05-27). Konkretne fragmenty oznaczono inline poniżej.

---

## 0. TL;DR

Phase 3 zamienia stub `billing-svc` w pełny gateway kwot, działający w modelu **token-bucket per organizacja** z 3-minutowym grace period na sesję. Plan obejmuje:

1. Przejście semantyki z `sessions_*` na `tokens_*` (formalnie ADR-DM-017).
2. Stripe / P24 webhook driver, ze stream zdarzeń `payment_events` jako gateway do zewnętrznego invoicingu (Fakturownia/iFirma).
3. Dwufazowy debit: `ReserveCredit` przy uploadzie → `CommitUsage` po STT z autorytatywnym `duration_seconds`, z `ReleaseCredit` na rollback.
4. Pełną zgodność z cross-cutting patternami: `pkg/idempotency`, `pkg/errors`, `pkg/cryptobox` (dla Stripe customer IDs), outbox-events, `audit_events`.
5. Monthly reset napędzany Stripe `invoice.paid` + cron dla `MANUAL` providers + fallback.

---

## 1. Bounded Context & Decyzje Architektoniczne

### 1.1 Pozycja w systemie

```
                  Flutter (therapist app)
                          │
                          ▼
                   ingestion-svc ──── ReserveCredit
                          │                │
                          ▼                ▼
                  clinical-svc ───── CheckQuota / CommitUsage / ReleaseCredit
                                           │
                                           ▼
                                    billing-svc ◄──── Stripe Webhook (HTTPS)
                                       │   │            (/stripe/webhook)
                                       │   │
                                       │   └─► Cloud SQL (subscriptions, usage_*, payment_events)
                                       │
                                       └─► Outbox → Pub/Sub
                                                ├─► notification-svc  (quota.exhausted, period.renewed)
                                                ├─► analytics-svc     (revenue, churn)
                                                └─► external invoicing SaaS (poll on payment_events.outbox)
```

`billing-svc` jest **internal-only** (no `allUsers` IAM, brak public ingress poza endpointem `/stripe/webhook` jeśli zdecydujemy się hostować go tu — patrz §11).

### 1.2 Nowe ADRs

| ADR | Decyzja | Uzasadnienie |
|---|---|---|
| **ADR-DM-017** | Token-bucket per organization, **NIE** session count. Pula tokenów dzielona w obrębie `organization_id`, 1 token = 60 min audio + 180 s grace. Tabele `usage_counters.tokens_*` zastępują `sessions_*` z v4.3. | Upheal-equivalent model; sesje 50–60 min są normą kliniczną; grace period eliminuje paniczne kończenie o czasie. |
| **ADR-DM-018** | `usage_events.session_id UNIQUE` jako jedyny idempotent commit log. Brak refund. Brak rollover. | Spójne z `02_*.md §4.2.2`; chroni przed double-debit po retry; chroni przed kosztami hostingu/API przy korupcji audio. |
| **ADR-BL-001** | Dwufazowy quota: `ReserveCredit` (TTL 4h, eksperyment z 24h) → `CommitUsage` z `duration_seconds` po STT. Reservation expiry → automatyczny release. | Bez rezerwacji race dwóch równoległych uploadów może spalić ostatni token jednego z nich po nagraniu — łamie "Świętość Nagrania". |
| **ADR-BL-002** | `payment_events` jest **gateway**, nie passthrough. External invoicing SaaS subskrybuje outbox (lub czyta tabelę przez read-replica), nie reaguje bezpośrednio na Stripe webhook. | Single source of truth dla raw event log; deduplikacja idempotencyjna jedna; własny replay. |
| **ADR-BL-003** | Stripe `invoice.paid` (nie `customer.subscription.updated`) jest triggerem dla nowego okresu rozliczeniowego. `customer.subscription.updated` triggeruje tylko stan/plan/cancel. | `invoice.paid` ma jednoznaczną semantykę "okres opłacony, reset liczników". |
| **ADR-BL-004** | `provider_customer_id` szyfrowany envelope encryption (`pkg/cryptobox`) — to bezpośredni handle do PII u Stripe. | Zero Trust; minimum surface area gdyby DB leakowała. |

---

## 2. Business Rules (Pinned)

| # | Reguła | Konsekwencja techniczna |
|---|---|---|
| **BR-1** | **Organization-level pooling.** Wszystkie limity i debit są na `organization_id` (klinika z 5 terapeutami dzieli pulę). | `usage_counters.subscription_id` → `subscriptions.organization_id` 1:1 dla aktywnej subskrypcji. |
| **BR-2** | **Duration + 3-min grace.** Wzór: $T = \max(1, \lceil (\text{sec} - 180) / 3600 \rceil)$ | Implementacja w `billing.tokens.Calculate(durationSec int32) int32`. Testy jednostkowe na boundary: 2520, 3420, 3600, 3660, 7200. |
| **BR-3** | **Quota exhausted → durable local storage.** `CheckQuota` zwraca `ResourceExhausted` z `reason=QUOTA_EXHAUSTED`. Flutter NIE generuje signed URL, NIE wysyła do GCS, trzyma audio w lokalnym (szyfrowanym) chunked store. | gRPC error → `pkg/errors.QuotaExhausted` → `error_code_ui = "quota_exhausted"` w `sessions`. Flutter pokazuje sesję w "Pending Uploads / Processing" widget na Kartotece. |
| **BR-4** | **No rollover.** Niewykorzystane tokeny wygasają z końcem `current_period_end`. | Cron / webhook handler tworzy nowy `usage_counters` row z `tokens_used=0`, nie kopiuje pozostałości. |
| **BR-5** | **No refund.** Po `CommitUsage` tokeny są spalone — niezależnie od późniejszego failu STT/LLM. | Jeśli STT zwróci błąd PRZED `CommitUsage`, token nie jest naliczony (commit po STT). Jeśli LLM padnie po commit — bez refund. |
| **BR-6** | **Reservation TTL.** Rezerwacja gaśnie po 4h. Cron co 5 min czyści stale reservations. | `pending_reservations.expires_at` + cron job `release-expired-reservations`. |

**Edge case `MANUAL` provider:** klinika rozliczana fakturą poza Stripe (np. enterprise pilot). `subscriptions.provider = 'MANUAL'`, brak webhooka — okres resetuje cron (§9.2).

---

## 3. Database Schema (DDL)

Pełen DDL trafia do migracji `000027_billing_phase3.up.sql`. Poniżej tabele i kluczowe constrainty.

### 3.1 Custom types

```sql
-- Już istnieje (003_enums.up.sql): plan_tier, billing_cycle, payment_provider, subscription_status
-- Phase 3 dodaje:

CREATE TYPE reservation_status AS ENUM (
    'ACTIVE',          -- reserved, czeka na commit
    'COMMITTED',       -- token spalony, finalized
    'RELEASED',        -- explicit release (np. upload failed)
    'EXPIRED'          -- TTL przekroczone, cron release
);
```

### 3.2 `subscription_plans` (katalog planów)

```sql
CREATE TABLE subscription_plans (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tier                     plan_tier NOT NULL,
    cycle                    billing_cycle NOT NULL,
    display_name             VARCHAR(100) NOT NULL,
    price_gross              NUMERIC(10,2) NOT NULL,
    currency_code            CHAR(3) NOT NULL DEFAULT 'PLN',

    -- Token model (ADR-DM-017)
    tokens_per_period        INT NOT NULL,                  -- pula na okres rozliczeniowy
    licenses_limit           INT NOT NULL DEFAULT 1,        -- ile użytkowników może dzielić pulę

    -- Feature flags
    has_b2b_dashboard        BOOLEAN NOT NULL DEFAULT FALSE,
    marketing_description    TEXT,

    -- Provider mappings (lookup do checkout flow)
    stripe_price_id          VARCHAR(100),
    p24_plan_id              VARCHAR(100),
    apple_product_id         VARCHAR(100),
    google_product_id        VARCHAR(100),

    is_active                BOOLEAN NOT NULL DEFAULT TRUE,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_plans_currency CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_plans_price    CHECK (price_gross >= 0),
    CONSTRAINT chk_plans_tokens   CHECK (tokens_per_period >= 0)
);

CREATE UNIQUE INDEX idx_plans_tier_cycle_active
    ON subscription_plans(tier, cycle) WHERE is_active = TRUE;
```

### 3.3 `subscriptions` (per-organization)

```sql
CREATE TABLE subscriptions (
    id                                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id                   UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
    plan_id                           UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE RESTRICT,

    provider                          payment_provider NOT NULL,
    provider_subscription_id          VARCHAR(255) NOT NULL,

    -- ADR-BL-004: customer ID szyfrowany envelope
    provider_customer_id_ciphertext   BYTEA,
    provider_customer_id_encrypted_dek BYTEA,

    status                            subscription_status NOT NULL,
    current_period_start              TIMESTAMPTZ NOT NULL,
    current_period_end                TIMESTAMPTZ NOT NULL,
    cancel_at_period_end              BOOLEAN NOT NULL DEFAULT FALSE,
    canceled_at                       TIMESTAMPTZ,
    trial_end_at                      TIMESTAMPTZ,

    created_at                        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                        TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (provider, provider_subscription_id)
);

-- Jedna aktywna subskrypcja per organization w danym momencie
CREATE UNIQUE INDEX idx_subscriptions_one_active_per_org
    ON subscriptions(organization_id)
    WHERE status IN ('ACTIVE', 'TRIALING', 'PAST_DUE');

CREATE INDEX idx_subscriptions_period_end
    ON subscriptions(current_period_end)
    WHERE status IN ('ACTIVE', 'TRIALING');
```

### 3.4 `usage_counters` (per-period bucket)

```sql
CREATE TABLE usage_counters (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id     UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    period_start        TIMESTAMPTZ NOT NULL,
    period_end          TIMESTAMPTZ NOT NULL,

    tokens_used         INT NOT NULL DEFAULT 0,
    tokens_reserved     INT NOT NULL DEFAULT 0,      -- live reservations (informational)
    tokens_limit        INT NOT NULL,                -- snapshot z subscription_plans.tokens_per_period

    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (subscription_id, period_start),
    CONSTRAINT chk_counters_nonneg CHECK (tokens_used >= 0 AND tokens_reserved >= 0)
);

CREATE INDEX idx_usage_counters_active
    ON usage_counters(subscription_id, period_start, period_end);
```

**Decyzja: snapshot vs live limit.** `tokens_limit` jest snapshotem z planu w momencie tworzenia row. Mid-cycle upgrade tworzy NOWY `usage_counters` row z nową wartością (po `subscription.updated` event) — patrz §9.3.

### 3.5 `pending_reservations` (ADR-BL-001)

```sql
CREATE TABLE pending_reservations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID NOT NULL UNIQUE,           -- 1:1 z sesją
    subscription_id     UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,

    tokens_reserved     INT NOT NULL,                   -- zwykle 1, max ze wzoru
    status              reservation_status NOT NULL DEFAULT 'ACTIVE',

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at          TIMESTAMPTZ NOT NULL,           -- created_at + 4h domyślnie
    finalized_at        TIMESTAMPTZ                     -- nullable; set on commit/release
);

CREATE INDEX idx_pending_reservations_expiry
    ON pending_reservations(expires_at)
    WHERE status = 'ACTIVE';

CREATE INDEX idx_pending_reservations_sub
    ON pending_reservations(subscription_id, status);
```

### 3.6 `usage_events` (commit log, idempotent)

```sql
CREATE TABLE usage_events (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID NOT NULL UNIQUE,           -- ENFORCES 1:1 charge per session
    subscription_id     UUID NOT NULL REFERENCES subscriptions(id) ON DELETE RESTRICT,
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,

    tokens_consumed     INT NOT NULL,
    duration_seconds    INT NOT NULL,                   -- authoritative, post-STT
    usage_type          VARCHAR(50) NOT NULL DEFAULT 'session_analysis',

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_usage_events_tokens CHECK (tokens_consumed > 0)
);

CREATE INDEX idx_usage_events_sub_time
    ON usage_events(subscription_id, created_at DESC);
```

### 3.7 `payment_events` (Stripe/P24 raw stream, ADR-BL-002)

```sql
CREATE TABLE payment_events (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id     UUID REFERENCES subscriptions(id) ON DELETE RESTRICT,  -- nullable; checkout.session.completed może być przed subscriptions row

    provider            payment_provider NOT NULL,
    provider_event_id   VARCHAR(255) NOT NULL,          -- np. "evt_1ABC..." ze Stripe
    event_type          VARCHAR(100) NOT NULL,          -- "invoice.paid", "customer.subscription.updated", ...

    amount_gross        NUMERIC(10,2),
    amount_net          NUMERIC(10,2),
    vat_rate            NUMERIC(5,4),                   -- 0.2300 = 23%
    currency_code       CHAR(3),

    raw_payload         JSONB NOT NULL,                 -- pełen webhook body; źródło dla external invoicing
    processing_status   VARCHAR(20) NOT NULL DEFAULT 'PENDING',  -- 'PENDING' | 'PROCESSED' | 'FAILED' | 'IGNORED'
    processed_at        TIMESTAMPTZ,
    error_message       TEXT,

    received_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (provider, provider_event_id)                -- idempotency webhooka
);

CREATE INDEX idx_payment_events_subscription
    ON payment_events(subscription_id, received_at DESC);

CREATE INDEX idx_payment_events_type
    ON payment_events(event_type, received_at DESC);

CREATE INDEX idx_payment_events_unprocessed
    ON payment_events(received_at) WHERE processing_status = 'PENDING';
```

### 3.8 Outbox integration — **SUPERSEDED (Phase C, 2026-05-27)**

> Tabela `outbox_events` została usunięta migracją `000034_drop_outbox_events.up.sql`. Topic `billing.outbox` + DLQ + IAM + Cloud Function `notification-worker-on-billing` zostały zniszczone przez `terragrunt apply staging`. Quota state propaguje teraz wyłącznie przez `state_after` na odpowiedziach `ReserveCredit` / `CommitUsage` oraz `clinical-svc.GetMyBillingState` na cold start. Patrz `18_BILLING_IMPLEMENTATION_FLOW.md` §5.
>
> Subscription-lifecycle events (`subscription.created`, `subscription.period_renewed`, `subscription.canceled`, `subscription.payment_failed`) były zaprojektowane ale w v1.0 były wysyłane tylko jako konsekwencja CommitUsage (quota events). Po Phase C żadne z nich nie istnieje na wire. Jeśli wrócimy do wymagania notyfikacji "Twoja subskrypcja została odnowiona", trzeba je dodać świeżo (najprawdopodobniej jako bezpośredni `notification-svc.EnqueueNotification` RPC z `billing-svc` cron handlerów — nie wskrzeszać outbox).

Sekcja oryginalna (referencyjna, dla zrozumienia poprzedniego designu):

`billing-svc` używa współdzielonej tabeli `outbox_events` (ADR-DM-009) do publikacji eventów do Pub/Sub:

| `aggregate_type` | `event_type` | Trigger | Konsumenci |
|---|---|---|---|
| `subscription` | `subscription.created` | nowa subskrypcja po `checkout.session.completed` | `notification-svc` (welcome email), `analytics-svc` |
| `subscription` | `subscription.period_renewed` | `invoice.paid` triggerujący nowy `usage_counters` | `notification-svc` (info dla terapeuty), `analytics-svc` |
| `subscription` | `subscription.canceled` | `customer.subscription.deleted` lub `cancel_at_period_end=true` | `notification-svc` (win-back email) |
| `subscription` | `subscription.payment_failed` | `invoice.payment_failed` | `notification-svc` (alert dla admina org) |
| `quota` | `quota.warning` | po `CommitUsage` jeśli `tokens_used >= 0.8 * tokens_limit` | `notification-svc` (push: kończą Ci się tokeny) |
| `quota` | `quota.exhausted` | po `CommitUsage` jeśli `tokens_used >= tokens_limit` | `notification-svc` (push + email do admina) |

Payload outbox: `{subscription_id, organization_id, plan_tier, tokens_used, tokens_limit, period_end, ...}`.

---

## 4. gRPC Contract (proto/billing/v1/billing.proto)

### 4.1 Strategia migracji proto

Obecny proto (Phase 2 stub) ma pola `remaining`, `limit`, `amount`. Zmiana wyłącznie semantyki (sesje → tokeny) **bez breaking change** poprzez:

1. **Zachowanie nazw** `remaining` i `limit` — od teraz znaczą tokeny.
2. **Dodanie** explicit nazwanych odpowiedników: `remaining_tokens`, `limit_tokens` jako aliasy (ten sam numer pola? nie — duplikat by łamał wire format. Dodajemy jako nowe pola, populujemy oba.).
3. `IncrementUsage.amount` → **deprecated**, zachowane dla kompatybilności. Dodajemy `duration_seconds` jako nowe pole; jeśli klient wysyła oba — `duration_seconds` wygrywa.
4. Nowe metody: `ReserveCredit`, `ReleaseCredit`. `IncrementUsage` zostaje jako alias do `CommitUsage` (lub deprecated z migracją call-sites).

### 4.2 Proto v2 (canonical)

```protobuf
syntax = "proto3";

package billing.v1;

import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

option go_package = "github.com/superwizor-ai/backend/gen/go/billing/v1;billingv1";

service BillingService {
  // Sprawdza dostępną pulę tokenów (read-only, nie blokuje).
  rpc CheckQuota(CheckQuotaRequest) returns (QuotaDecision);

  // Rezerwuje token na sesję (ADR-BL-001). TTL 4h.
  // Idempotent po session_id: powtórne wywołanie zwraca tą samą rezerwację.
  rpc ReserveCredit(ReserveCreditRequest) returns (Reservation);

  // Commituje token po STT, ze znanym duration_seconds.
  // Idempotent po session_id (usage_events.session_id UNIQUE).
  rpc CommitUsage(CommitUsageRequest) returns (UsageCommit);

  // Zwalnia rezerwację (np. upload failed, manual cancel przed STT).
  // Idempotent: re-call na RELEASED/COMMITTED zwraca OK bez zmian.
  rpc ReleaseCredit(ReleaseCreditRequest) returns (google.protobuf.Empty);

  // DEPRECATED: użyj CommitUsage. Zachowany dla Phase 2 callers.
  rpc IncrementUsage(IncrementUsageRequest) returns (google.protobuf.Empty) {
    option deprecated = true;
  }

  // Stan subskrypcji + bieżące zużycie.
  rpc GetSubscription(GetSubscriptionRequest) returns (Subscription);
}

message CheckQuotaRequest {
  string organization_id = 1;
  string therapist_id    = 2;
  string usage_type      = 3;          // 'session_analysis'
  int32  amount          = 4;          // estymowane tokeny; default 1
}

message QuotaDecision {
  bool   allowed         = 1;
  string reason          = 2;          // 'QUOTA_EXHAUSTED', 'SUBSCRIPTION_PAST_DUE', 'OK'
  int32  remaining       = 3;          // tokens remaining (legacy name; tokens)
  int32  limit           = 4;          // tokens limit (legacy name; tokens)
  int32  remaining_tokens = 5;         // explicit alias (= remaining)
  int32  limit_tokens     = 6;         // explicit alias (= limit)
  google.protobuf.Timestamp period_end = 7;
}

message ReserveCreditRequest {
  string session_id      = 1;          // UUID; key idempotencji
  string organization_id = 2;
  string therapist_id    = 3;
  int32  estimated_tokens = 4;         // optional; default 1
  string idempotency_key = 5;
}

message Reservation {
  string reservation_id  = 1;
  string session_id      = 2;
  int32  tokens_reserved = 3;
  google.protobuf.Timestamp expires_at = 4;
}

message CommitUsageRequest {
  string session_id       = 1;         // UUID; key idempotencji
  string organization_id  = 2;
  string therapist_id     = 3;
  int32  duration_seconds = 4;         // autoritative, post-STT
  string usage_type       = 5;
  string idempotency_key  = 6;
}

message UsageCommit {
  int32  tokens_consumed  = 1;
  int32  remaining_tokens = 2;
  int32  limit_tokens     = 3;
}

message ReleaseCreditRequest {
  string session_id       = 1;
  string organization_id  = 2;
  string reason           = 3;         // 'UPLOAD_FAILED', 'USER_CANCELED', 'STT_FAILED'
}

message IncrementUsageRequest {
  option deprecated = true;
  string organization_id = 1;
  string therapist_id    = 2;
  string usage_type      = 3;
  int32  amount          = 4;
  string session_id      = 5;
  string idempotency_key = 6;
  // Nowi klienci powinni wysyłać duration_seconds = 0, billing-svc obliczy
  // tokens jako amount (fallback dla legacy Phase 2 ścieżki).
}

message GetSubscriptionRequest {
  string organization_id = 1;
}

message Subscription {
  string id                          = 1;
  string plan_tier                   = 2;     // 'SOLO', 'PRO', 'CLINIC', 'PATIENT'
  string status                      = 3;
  int32  sessions_per_month_limit    = 4;     // DEPRECATED — zwracamy tokens_per_period
  int32  sessions_used_this_period   = 5;     // DEPRECATED — zwracamy tokens_used
  int32  tokens_per_period           = 6;
  int32  tokens_used_this_period     = 7;
  int32  tokens_reserved_this_period = 8;
  google.protobuf.Timestamp current_period_start = 9;
  google.protobuf.Timestamp current_period_end   = 10;
}
```

### 4.3 Error mapping (`pkg/errors`)

| Domain error | gRPC code | `reason` | `error_code_ui` (Flutter) |
|---|---|---|---|
| `ErrQuotaExhausted` | `ResourceExhausted` | `QUOTA_EXHAUSTED` | `quota_exhausted` |
| `ErrSubscriptionInactive` | `FailedPrecondition` | `SUBSCRIPTION_INACTIVE` | `subscription_inactive` |
| `ErrSubscriptionPastDue` | `FailedPrecondition` | `SUBSCRIPTION_PAST_DUE` | `subscription_past_due` |
| `ErrReservationExpired` | `FailedPrecondition` | `RESERVATION_EXPIRED` | `reservation_expired` |
| `ErrIdempotencyConflict` | `AlreadyExists` | `IDEMPOTENCY_CONFLICT` | — (internal retry signal) |

---

## 5. Lifecycle: jedna sesja end-to-end

> **⚠️ Aktualny flow:** patrz `18_BILLING_IMPLEMENTATION_FLOW.md` §2-§5. Poniższy diagram opisuje v1.0 (z outbox-em i T3). T3 już nie istnieje — billing-svc kończy się na T2 (CommitUsage zwraca `state_after`, koniec). Flutter widzi nowy stan na cold start lub na następnym ReserveCredit, nie przez Pub/Sub push.

```
T0  Flutter: tap "Rozpocznij sesję"
    └─► clinical-svc.CreateSession(idempotency_key=K1)
         └─► sessions row, status=CREATED

T1  Flutter: tap "Stop", upload start
    └─► ingestion-svc.CreateAudioUpload(session_id=S)
         ├─► billing-svc.CheckQuota(org, "session_analysis", 1)
         │    └─► QuotaDecision{allowed=true, remaining=12, limit=20}
         ├─► billing-svc.ReserveCredit(session_id=S, idempotency_key=K2)
         │    └─► pending_reservations INSERT (status=ACTIVE, expires_at=T1+4h)
         │       + audit_events INSERT
         │    └─► Reservation{reservation_id=R, tokens_reserved=1}
         └─► signed GCS URL
            sessions.status=UPLOADING

T2  GCS receives audio → Eventarc → audio.uploaded topic
    └─► stt-worker (Cloud Function Gen2)
         ├─► Chirp 3 transcribe → transcript_ciphertext INSERT
         ├─► sessions.status=ANALYZING, duration_seconds populated
         ├─► billing-svc.CommitUsage(session_id=S, duration_seconds=2700)
         │    ├─► [tx]
         │    │   ├─► pg_advisory_xact_lock(subscription_id)
         │    │   ├─► INSERT usage_events ON CONFLICT (session_id) DO NOTHING
         │    │   │     └─► jeśli conflict: RETURN UsageCommit (no-op)
         │    │   ├─► UPDATE usage_counters SET tokens_used += T, tokens_reserved -= R
         │    │   ├─► UPDATE pending_reservations SET status='COMMITTED'
         │    │   ├─► INSERT outbox_events: quota.warning if used >= 0.8*limit
         │    │   │                          quota.exhausted if used >= limit
         │    │   ├─► INSERT audit_events
         │    │   └─► [commit]
         │    └─► UsageCommit{tokens_consumed=1, remaining=11, limit=20}
         └─► [pipeline continues to LLM, report.ready]

T3  outbox-poller (cron 5s) → publish do Pub/Sub
    └─► notification-svc: push "Zostało Ci 11 tokenów"
```

**Failure path (upload fails at T2):**

```
ingestion-svc detects upload timeout
└─► billing-svc.ReleaseCredit(session_id=S, reason='UPLOAD_FAILED')
     ├─► UPDATE pending_reservations SET status='RELEASED', finalized_at=now()
     ├─► UPDATE usage_counters SET tokens_reserved -= R   (NIE tokens_used)
     └─► INSERT audit_events
```

**Failure path (reservation expires bez committu):**

`release-expired-reservations` cron co 5 min:
```sql
UPDATE pending_reservations
SET status = 'EXPIRED', finalized_at = now()
WHERE status = 'ACTIVE' AND expires_at < now()
RETURNING subscription_id, tokens_reserved;
-- per row: UPDATE usage_counters SET tokens_reserved -= ...
```

---

## 6. Concurrency & Idempotency

### 6.1 `ReserveCredit` (transakcja)

```sql
BEGIN;

-- Idempotency: jeśli rezerwacja już istnieje, zwróć ją
SELECT id, tokens_reserved, expires_at FROM pending_reservations
WHERE session_id = $1 AND status IN ('ACTIVE', 'COMMITTED')
FOR UPDATE;
-- Jeśli COMMITTED → return ErrIdempotencyConflict
-- Jeśli ACTIVE   → return Reservation

-- Serialize per-organization
SELECT pg_advisory_xact_lock(hashtextextended(subscription_id::text, 0));

-- Sprawdź dostępność
SELECT tokens_limit - tokens_used - tokens_reserved AS available
FROM usage_counters
WHERE subscription_id = $1
  AND period_start <= now()
  AND period_end > now();
-- Jeśli available < estimated_tokens → ROLLBACK, return ErrQuotaExhausted

-- Rezerwuj
INSERT INTO pending_reservations (session_id, subscription_id, organization_id,
                                  tokens_reserved, expires_at)
VALUES ($1, $2, $3, $4, now() + interval '4 hours');

UPDATE usage_counters SET tokens_reserved = tokens_reserved + $4
WHERE subscription_id = $2 AND ...active period...;

INSERT INTO outbox_events ...;  -- if needed (np. dla audit pipeline)
INSERT INTO audit_events ...;

COMMIT;
```

### 6.2 `CommitUsage` (transakcja)

```sql
BEGIN;

SELECT pg_advisory_xact_lock(hashtextextended(subscription_id::text, 0));

-- Idempotent insert
WITH ins AS (
    INSERT INTO usage_events (session_id, subscription_id, organization_id,
                              tokens_consumed, duration_seconds, usage_type)
    VALUES ($1, $2, $3, $4, $5, $6)
    ON CONFLICT (session_id) DO NOTHING
    RETURNING id, tokens_consumed
)
SELECT id, tokens_consumed FROM ins
UNION ALL
SELECT id, tokens_consumed FROM usage_events WHERE session_id = $1
LIMIT 1;
-- Jeśli z UNION wyszedł stary row (conflict): no-op path, return UsageCommit z aktualnym counter

-- Update counter (tylko jeśli INSERT zadziałał — sprawdź FOUND w Go)
UPDATE usage_counters
SET tokens_used = tokens_used + $tokens,
    tokens_reserved = GREATEST(0, tokens_reserved - $reserved_amount),
    updated_at = now()
WHERE subscription_id = $2 AND ...active period...;

-- Finalize reservation (jeśli była)
UPDATE pending_reservations
SET status = 'COMMITTED', finalized_at = now()
WHERE session_id = $1 AND status = 'ACTIVE';

-- Outbox: quota signals
INSERT INTO outbox_events ('quota.warning' / 'quota.exhausted' jeśli progi)

-- Audit
INSERT INTO audit_events (...);

COMMIT;
```

### 6.3 Cross-cutting idempotency keys

`pkg/idempotency` (per `00_GLOBAL_CONTEXT.md`) zapisuje `idempotency_keys` row dla każdej mutating RPC. Dla `billing-svc`:

- `ReserveCredit`, `CommitUsage`, `ReleaseCredit` → `idempotency_keys.key = (request.idempotency_key)`, response_payload zapisana.
- **Druga warstwa** ochrony to `session_id UNIQUE` constraint na `pending_reservations` i `usage_events`. Te dwa się uzupełniają: idempotency_keys broni przed retry tego samego logical request, UNIQUE constraint broni przed retry z różnymi idempotency_keys ale tym samym session_id.
- Konflikt: ten sam `session_id`, różny `duration_seconds` → `AlreadyExists` (per global context error mapping). Klient widzi `ErrIdempotencyConflict`.

---

## 7. Stripe Webhook Driver

### 7.1 Endpoint

```
POST /stripe/webhook
Host: billing-svc.[run.app | custom domain]
Headers: Stripe-Signature: t=...,v1=...
```

**Decyzja deploymentu:** endpoint live **wewnątrz** `billing-svc` na osobnej HTTP-route (gRPC nie obsługuje raw webhooków). Cloud Run service akceptuje IT z `allUsers` **tylko** na ścieżce `/stripe/webhook`; reszta serwisu (gRPC) pozostaje IAM-bound. Realizacja: dwa porty / IngressController per path nie istnieje w Cloud Run, więc:

- Opcja A (rekomendowana): `billing-svc` jest internal-only (gRPC), a **osobny mini-serwis `billing-webhook-svc`** (kolejne Cloud Run service z `allUsers`) jest publicznym endpointem. Po weryfikacji signatury wysyła `payment_events` insert i internal gRPC call do `billing-svc.ProcessPaymentEvent`.
- Opcja B: `billing-svc` ma multiplex HTTP+gRPC (`cmux`), `allUsers` IAM, ale path-based authentication w aplikacji. **Mniej rekomendowane** — łamie Zero Trust per-path.

→ **Wybieramy A.**

### 7.2 Walidacja sygnatury

```go
sig := r.Header.Get("Stripe-Signature")
event, err := webhook.ConstructEvent(body, sig, stripeWebhookSecret)
if err != nil { return 400 }
```

`stripeWebhookSecret` w Secret Manager (`stripe-webhook-secret` secret, latest version).

### 7.3 Idempotency

```sql
INSERT INTO payment_events (provider, provider_event_id, event_type, raw_payload, ...)
VALUES ('STRIPE', $1, $2, $3, ...)
ON CONFLICT (provider, provider_event_id) DO NOTHING
RETURNING id;
-- Jeśli RETURNING pusty → event już processowany, return 200 OK
```

### 7.4 Event handling matrix

| Stripe event | Akcja billing-svc | Outbox event |
|---|---|---|
| `checkout.session.completed` | INSERT `subscriptions` row (jeśli nowa), link organization | `subscription.created` |
| `customer.subscription.created` | Upsert `subscriptions`, ustaw `current_period_*` | `subscription.created` (jeśli nowa) |
| `invoice.paid` (ADR-BL-003) | Create NEW `usage_counters` row z `tokens_used=0`, `tokens_limit=plan.tokens_per_period`, period dates z `invoice.lines` | `subscription.period_renewed` |
| `invoice.payment_failed` | UPDATE `subscriptions.status = PAST_DUE` | `subscription.payment_failed` |
| `customer.subscription.updated` | Update plan_id / status / cancel_at_period_end (NIE period dates — to robi `invoice.paid`) | jeśli plan zmieniony: `subscription.plan_changed` |
| `customer.subscription.deleted` | UPDATE `status = CANCELED, canceled_at = now()` | `subscription.canceled` |
| inne | INSERT `payment_events` z `processing_status = 'IGNORED'` | — |

Wszystkie INSERT-y w **jednej transakcji** (DB + outbox), żeby Pub/Sub event nie wyszedł bez DB writeu.

### 7.5 External invoicing integration

External SaaS (Fakturownia/iFirma) **NIE** dostaje raw Stripe webhooków. Czyta z naszego stream:

- **Opcja 1 (push):** osobny outbox stream `payment_events.outbox` → Pub/Sub topic `billing.payment-events` → adapter Cloud Function publikuje do API SaaS.
- **Opcja 2 (pull):** SaaS przez nasze API gRPC `ListPaymentEvents(since=...)` (paginated, read-only). Wymaga osobnego SA z `roles/run.invoker`.

Wybór zależy od integratora — design doc tego nie pinuje, ale **wymaga jednego z dwóch przed launchem** (nie zostawić w powietrzu).

---

## 8. Reservation expiry cron

`release-expired-reservations` — Cloud Scheduler co 5 min → publish do Pub/Sub topic `billing.cron.reservation-expiry` → Cloud Function albo HTTP endpoint:

```sql
BEGIN;
WITH expired AS (
    UPDATE pending_reservations
    SET status = 'EXPIRED', finalized_at = now()
    WHERE status = 'ACTIVE' AND expires_at < now()
    RETURNING subscription_id, tokens_reserved
)
UPDATE usage_counters c
SET tokens_reserved = GREATEST(0, c.tokens_reserved - e.sum_reserved)
FROM (SELECT subscription_id, SUM(tokens_reserved) AS sum_reserved FROM expired GROUP BY subscription_id) e
WHERE c.subscription_id = e.subscription_id AND ...active period...;

-- audit_events INSERT per expired row
COMMIT;
```

Metrics: `billing.reservations.expired_total` (counter). Jeśli ratio expired/total > 5% w 24h → alert ("za krótki TTL" lub "zła UX uploadu").

---

## 9. Monthly resets

### 9.1 Stripe-driven (default)

`invoice.paid` handler (§7.4) tworzy nowy `usage_counters` row. To jest **happy path** dla ~95% klientów.

### 9.2 Manual provider cron

Dla `subscriptions.provider = 'MANUAL'` (klinikalna enterprise, P24 jeśli ich webhook jest niewiarygodny):

Cloud Scheduler `manual-period-renewal` daily o 00:05 → HTTP → billing-svc:

```sql
SELECT s.id, s.organization_id, s.plan_id, s.current_period_end, p.tokens_per_period
FROM subscriptions s JOIN subscription_plans p ON s.plan_id = p.id
WHERE s.provider = 'MANUAL'
  AND s.status = 'ACTIVE'
  AND s.current_period_end < now();
-- per row: UPDATE current_period_start/end, INSERT new usage_counters
```

### 9.3 Mid-cycle plan upgrade

`customer.subscription.updated` z nowym `plan_id`:

1. Plan zostaje wymieniony NATYCHMIAST w `subscriptions`.
2. `usage_counters` BIEŻĄCEGO okresu **dostaje update** `tokens_limit` (snapshot się refresh-uje, ale `tokens_used` zostaje).
3. Jeśli upgrade → nowa pula dostępna od razu, klient zyskuje.
4. Jeśli downgrade i `tokens_used > new_limit` → counter zostaje "overcommit"; dalsze `CheckQuota` zwraca `QUOTA_EXHAUSTED` aż do końca okresu. Bez clawback.
5. Następny `invoice.paid` tworzy nowy row z czystym kontem.

### 9.4 Fallback safety net

Cron `usage-counter-safety-check` weekly:

```sql
-- Znajdź ACTIVE subscriptions bez aktywnego usage_counters
SELECT s.id FROM subscriptions s
WHERE s.status IN ('ACTIVE', 'TRIALING')
  AND NOT EXISTS (
    SELECT 1 FROM usage_counters c
    WHERE c.subscription_id = s.id
      AND c.period_start <= now()
      AND c.period_end > now()
  );
```

Wynik → alert PagerDuty (`billing.missing_counter`). Auto-create counter z snapshotem planu.

---

## 10. Security

### 10.1 IAM

| Caller | Method | Required |
|---|---|---|
| `clinical-svc` SA | All gRPC methods | `roles/run.invoker` na `billing-svc` |
| `ingestion-svc` SA | `CheckQuota`, `ReserveCredit`, `ReleaseCredit` | `roles/run.invoker` |
| `ai-pipeline-svc` SA | `CommitUsage`, `ReleaseCredit` | `roles/run.invoker` |
| `billing-webhook-svc` SA | internal `ProcessPaymentEvent` | `roles/run.invoker` |
| Stripe (public) | `/stripe/webhook` on `billing-webhook-svc` | `allUsers` → signature validation w aplikacji |

### 10.2 Encryption (ADR-BL-004)

`provider_customer_id` szyfrowany przez `pkg/cryptobox`:

```go
ct, dek, err := crypto.Encrypt(ctx, []byte(stripeCustomerID))
// INSERT subscriptions(provider_customer_id_ciphertext, provider_customer_id_encrypted_dek)
```

KMS KEK URI: `module.kms.app_data_key_id` (już istnieje w staging).

### 10.3 Secrets

| Secret | Manager path | Rotation |
|---|---|---|
| `stripe-api-key` | `projects/${PROJECT}/secrets/stripe-api-key` | Manual przy rotacji w Stripe |
| `stripe-webhook-secret` | `.../stripe-webhook-secret` | Manual |
| `p24-merchant-key` | `.../p24-merchant-key` | Manual |

### 10.4 Audit

Każda mutacja → `audit_events`:
- `action`: `subscription.created`, `subscription.canceled`, `reservation.created`, `usage.committed`, `reservation.released`, `reservation.expired`, `webhook.received`, `webhook.processed`.
- `resource_type`: `subscription` | `usage_event` | `reservation` | `payment_event`.
- `resource_id`: odpowiednie UUID.
- `metadata`: `{tokens, duration_seconds, stripe_event_id, ...}` — bez PHI.

---

## 11. Service topology & deployment

### 11.1 Dwa Cloud Run services

| Service | Type | Ingress | SA | Notes |
|---|---|---|---|---|
| `billing-svc` | gRPC, internal | `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` | `billing-svc@${PROJECT}.iam` | Per agent doc + Phase 3 upgrade z default compute SA |
| `billing-webhook-svc` | HTTP, public | `INGRESS_TRAFFIC_ALL` | `billing-webhook-svc@...` | Tylko `/stripe/webhook`. Po walidacji → internal gRPC call do `billing-svc`. |

### 11.2 Dependencies (Phase 3)

- Cloud SQL (`superwizor-db-bc4c27de` w staging) — istniejąca instancja.
- Secret Manager — nowe sekrety stripe.
- Cloud KMS — istniejący keyring `app_data_key`.
- Pub/Sub — nowy topic `billing.outbox` + DLQ.
- Cloud Scheduler — 2 nowe jobs (`release-expired-reservations`, `manual-period-renewal`, `usage-counter-safety-check`).
- Stripe account (test mode dla staging, live mode po launchu).

### 11.3 Migrations

Migracje sekwencyjnie:
- `000027_billing_phase3_types.up.sql` — `reservation_status` enum.
- `000028_billing_phase3_tables.up.sql` — wszystkie tabele §3.
- `000029_billing_phase3_seed_plans.up.sql` — seed planów SOLO/PRO/CLINIC (z `stripe_price_id` w env-specific values).

### 11.4 Repo paths (Phase 3 evolution z agent doc)

```
services/billing-svc/
├── cmd/server/main.go                  # gRPC listener
├── internal/
│   ├── adapters/grpc/server.go         # implementuje BillingService
│   ├── adapters/grpc/webhook_client.go # internal call z billing-webhook-svc
│   ├── domain/tokens/calculate.go      # BR-2 formuła
│   ├── domain/quota/                   # CheckQuota / Reserve / Commit / Release logic
│   ├── domain/stripe/                  # event handlers
│   ├── repo/                           # sqlc-generated queries
│   └── outbox/                         # outbox event writer
├── sqlc.yaml
├── queries/                            # SQL queries → sqlc
├── go.mod
└── Dockerfile

services/billing-webhook-svc/
├── cmd/server/main.go                  # HTTP handler /stripe/webhook
├── internal/
│   ├── adapters/http/handler.go
│   └── adapters/grpc/billing_client.go # internal call do billing-svc
├── go.mod
└── Dockerfile

proto/billing/v1/billing.proto           # zaktualizowany z §4.2
```

---

## 12. Observability

### 12.1 Metrics (Cloud Monitoring custom)

| Metric | Type | Labels |
|---|---|---|
| `billing.quota_check.total` | counter | `org_id`, `decision={allowed,denied}` |
| `billing.reservation.active` | gauge | `org_id` |
| `billing.reservation.expired_total` | counter | `org_id` |
| `billing.usage.committed_total` | counter | `org_id`, `tokens_consumed` |
| `billing.tokens.utilization_pct` | gauge | `org_id` (= `100 * tokens_used / tokens_limit`) |
| `billing.stripe.webhook_received_total` | counter | `event_type`, `status={processed,ignored,failed}` |
| `billing.stripe.webhook_lag_seconds` | histogram | `event_type` (= `processed_at - received_at`) |
| `billing.subscription.churn_total` | counter | `plan_tier`, `reason` |

### 12.2 SLO

| SLO | Target | Alert threshold |
|---|---|---|
| `CheckQuota` P95 latency | <50ms | >150ms over 5min |
| `CommitUsage` success rate | 99.9% | <99% over 1h |
| Webhook → counter reset lag | <60s | >300s |
| Reservation expiry ratio | <5% | >10% over 24h |
| Missing usage_counters | 0 | >0 (any) |

### 12.3 Dashboards

- **Billing Ops:** quota checks, commits, reservations live/expired.
- **Revenue/Stripe:** webhook stream, payment_events processing, plan distribution.
- **Quota Health:** per-org utilization, time-to-exhaustion, near-limit alerts.

---

## 13. Testing strategy

### 13.1 Unit

- `domain/tokens/calculate.go`: tabela boundary cases (2520, 3420, 3600, 3660, 7200, 0, negative).
- `domain/quota/`: rezerwacja vs commit vs release transitions; idempotency happy path.
- `domain/stripe/`: each event handler z fixturami webhook bodies.

### 13.2 Integration (testcontainers Postgres)

- Concurrent `ReserveCredit` na tej samej organizacji (10 goroutines, 1 dostępny token → 1 sukces, 9 ResourceExhausted).
- `CommitUsage` po `ReserveCredit` z różnym `duration_seconds` (verify token count).
- Webhook replay: ten sam `provider_event_id` 3x → 1 insert.
- Reservation expiry cron: utwórz 5 reservations z `expires_at = now() - 1h`, run cron, verify all RELEASED.

### 13.3 E2E (staging)

- Flutter → ingestion-svc → billing-svc real flow.
- Stripe test mode: trigger `invoice.paid` via Stripe CLI, verify `usage_counters` reset.
- Manual provider: trigger cron, verify counter creation.

---

## 14. Open questions / future work

1. **Patient-tier plans** (`plan_tier = 'PATIENT'`) — Phase 4? Czy włączamy je do MVP Phase 3?
2. **Pakiety dodatkowe (top-up)** — jednorazowy zakup 10 dodatkowych tokenów. Tabela `token_grants(organization_id, tokens, expires_at)` — nie w MVP Phase 3.
3. **Family/couple sessions** — `process_type IN ('COUPLE', 'FAMILY')`. Plan zakłada że to nadal 1 sesja = 1 token (60min+grace). Czy dłuższe sesje par/rodzin (90 min) wymagają nowej semantyki? **Default: nie**, wzór BR-2 to obsługuje (90min = 1 token jeśli ≤63min grace, inaczej 2).
4. **Concurrent therapist limit** — CLINIC plan ma `licenses_limit`. Plan **nie** egzekwuje tego dziś (każdy therapist w org może wołać `ReserveCredit`). Czy potrzebne? → Phase 3.5.
5. **External invoicing integration choice** — push vs pull (§7.5). Zależy od wybranego SaaS — decyzja przed launchem produkcyjnym.

---

## 15. Rollout plan

| Krok | Akcja | Verification |
|---|---|---|
| 1 | Migracje 000027-000029 (idempotent up/down) | `migrator` job na staging green |
| 2 | Seed planów z STAGING `stripe_price_id` | Manual: select * from subscription_plans |
| 3 | Deploy `billing-svc` z proto v2 i implementacją | gRPC reflection + grpcurl test |
| 4 | Deploy `billing-webhook-svc` | curl test endpoint, Stripe CLI `trigger` |
| 5 | Update `clinical-svc` / `ingestion-svc` na `ReserveCredit` flow | E2E test |
| 6 | Włącz Cloud Scheduler jobs | Manual trigger + log inspection |
| 7 | Soft-launch z 1 testową organizacją, monitor 7 dni | Dashboards green |
| 8 | Migracja istniejących orgs (jeśli są) ze stuba na real (manual subscriptions insert) | Audit log review |
| 9 | Deprecation notice: `IncrementUsage` legacy method (3 miesiące min.) | Communication to client teams |
| 10 | Remove legacy fields (`sessions_per_month_limit`, `sessions_used_this_period`, deprecated `IncrementUsage`) — Phase 4 cleanup | Proto major bump |

---

## 16. Flutter UI Contract & FCM Notifications

Ta sekcja pinuje **dokładnie** co użytkownik widzi w jakim momencie, jaki event w outbox tym steruje, i jakie copy (PL) trafia do `app_pl.arb` (Flutter i18n).

> **Zasada:** Backend NIE wysyła stringów do wyświetlenia. Backend wysyła **kody** (`error_code_ui`, `notification_type`); Flutter mapuje kod → tłumaczenie. To pozwala zmieniać copy bez deploy backendu.

### 16.1 Thresholds (konfigurowane) — **SUPERSEDED (Phase C)**

> Edge-triggered thresholds zostały usunięte z `billing-svc`. Backend nie emituje już `quota.warning` / `quota.critical` / `quota.exhausted` jako oddzielnych events — żaden Pub/Sub topic ich nie odbiera, żaden konsument nie istnieje. Próg "który warning level pokazać" jest teraz wyliczany **klientowo** w `flutter-app/superwizor/lib/services/billing_quota_state.dart::QuotaState.computeLevel`: `none` (>5), `warning` (≤5), `critical` (≤1), `exhausted` (==0). To pozwala zmieniać progi przez release Flutter bez deploy backendu.
>
> `BILLING_RESERVATION_TTL_HOURS=4` (sekcja niżej w tabeli) jest dalej aktualna — używana przez reservation-expiry cron.

Zaszyte w `billing-svc` jako env vars (default values poniżej). Wszystkie wyrażone **w pozostałych tokenach**, nie procentowo — terapeuta myśli "ile mam sesji do końca miesiąca", nie "ile %".

| Threshold | Default | Trigger | Owner |
|---|---|---|---|
| `BILLING_WARN_REMAINING` | `5` | Po `CommitUsage` jeśli `tokens_limit - tokens_used == X` (edge-triggered, NIE level-triggered — żeby nie spamować) | `billing-svc` |
| `BILLING_CRITICAL_REMAINING` | `1` | Ostatni token | `billing-svc` |
| `BILLING_EXHAUSTED` | `0` | `tokens_limit - tokens_used == 0` | `billing-svc` |
| `BILLING_RESERVATION_TTL_HOURS` | `4` | Reservation expiry | `billing-svc` |

**Edge-triggered logic** — kluczowe:

```sql
-- W transakcji CommitUsage, po UPDATE counter:
WITH new_state AS (SELECT tokens_used, tokens_limit FROM usage_counters WHERE ...)
SELECT
  (tokens_limit - tokens_used) AS remaining_after,
  (tokens_limit - tokens_used + $tokens_just_consumed) AS remaining_before
FROM new_state;

-- Outbox event tylko jeśli:
-- remaining_after <= 5 AND remaining_before > 5  → quota.warning (raz)
-- remaining_after == 1 AND remaining_before > 1  → quota.critical (raz)
-- remaining_after == 0 AND remaining_before > 0  → quota.exhausted (raz)
```

Bez edge-trigger: każde `CommitUsage` poniżej 5 tokenów spamowałoby push. Z edge-trigger: jeden push przy przejściu progu.

### 16.2 Outbox → FCM notification types — **SUPERSEDED (Phase C)**

> Cała mapa outbox-event → FCM-push została usunięta wraz z Cloud Function `notification-worker-on-billing`. Nie ma już billing-driven push notyfikacji. `notification-svc` dalej obsługuje session-lifecycle push (audio uploaded, transcript ready, report ready) — to inne CFs (`notification-worker-on-uploaded/transcribed/report/deleted`).
>
> Jeśli wrócimy do wymagania "push, gdy zostaje 1 token" — to wracamy do designu (najprawdopodobniej jako bezpośredni `notification-svc` RPC z `billing-svc` po CommitUsage, bez Pub/Sub).

Sekcja oryginalna (referencyjna):

`notification-svc` mapuje outbox events na FCM `notification_type` per ADR-IMPL-013 (data-only payload, bez PHI):

| Outbox event | FCM `notification_type` | Data payload | Push title (PL) | Push body (PL) |
|---|---|---|---|---|
| `quota.warning` | `quota_warning` | `{organization_id, tokens_remaining, period_end}` | "Zostało Ci niewiele tokenów" | "Pozostało {N} tokenów do końca okresu rozliczeniowego." |
| `quota.critical` | `quota_critical` | `{organization_id, tokens_remaining, period_end}` | "Ostatni token" | "Został Ci 1 token. Rozważ rozszerzenie planu." |
| `quota.exhausted` | `quota_exhausted` | `{organization_id, period_end}` | "Wyczerpano pulę tokenów" | "Nagrywaj dalej — sesje zostaną zachowane lokalnie i przetworzone po odnowieniu puli." |
| `subscription.period_renewed` | `quota_renewed` | `{organization_id, tokens_limit}` | "Pula tokenów odnowiona" | "Masz znów {N} tokenów na nowy okres rozliczeniowy." |
| `subscription.payment_failed` | `payment_failed` | `{organization_id}` | "Problem z płatnością" | "Nie udało się pobrać opłaty. Sprawdź metodę płatności w ustawieniach." |
| `subscription.canceled` | `subscription_canceled` | `{organization_id, period_end}` | "Subskrypcja zakończona" | "Twoja subskrypcja kończy się {DATE}. Do tego czasu możesz dalej korzystać z aplikacji." |

**FCM delivery target:** użytkownik z `role = THERAPIST` przypisany jako `primary_admin_user_id` organizacji + (dla CLINIC) wszyscy z `role = THERAPIST` w danej organizacji. Patient nie dostaje quota notifications.

**Lokalizacja:** push body tłumaczone backendowo z `users.ui_language`. Backend popełnia tu **wyjątek** od zasady "Flutter mapuje kody" — bo notyfikacja FCM jest renderowana przez OS poza aplikacją. Tłumaczenia żyją w `notification-svc/internal/i18n/`.

### 16.3 Firestore mirror (live UI state) — **SUPERSEDED (Phase C)**

> Firestore mirror `organization_quota/{organizationId}` został wycofany. `OrganizationQuota` struct + `WriteOrganizationQuota` method usunięte z `services/notification-svc/internal/adapters/firestore/writer.go`. Reguła `match /organization_quota/{orgId}` w `firestore.rules` usunięta (deploy: `firebase deploy --only firestore:rules`, 2026-05-27). Default-deny pokrywa wszystkie pozostałe sieroce dokumenty.
>
> Flutter teraz pobiera ten sam payload przez gRPC: `clinical-svc.GetMyBillingState` (cold start) lub `state_after` na każdej odpowiedzi `ReserveCredit`/`CommitUsage`. Cache żyje w `lib/services/billing_quota_cache.dart` jako `ValueNotifier<QuotaState?>`. `lib/services/billing_quota_listener.dart` (Firestore subscriber) usunięty.
>
> Schema poniżej jest dalej dokładna jako **shape** danych — to samo pole-po-polu wraca w `billing.v1.Subscription` proto, więc zostaje jako reference.

Sekcja oryginalna (referencyjna):

Per `02_*.md §6`, Firestore jest **read-only** mirror wybranych pól. Dla billing, każdy `usage_counters` write triggeruje (przez outbox) update do Firestore w kolekcji `organization_quota/{organization_id}`:

```json
{
  "organizationId": "uuid",
  "tokensUsed": 15,
  "tokensReserved": 1,
  "tokensLimit": 20,
  "tokensRemaining": 4,
  "periodStart": 1714000000,
  "periodEnd": 1716678400,
  "warningLevel": "warning",
  "updatedAt": 1714123456
}
```

`warningLevel` enum: `none` | `warning` (≤5 left) | `critical` (≤1 left) | `exhausted` (0 left).

Flutter subskrybuje `organization_quota/{currentOrgId}` jako `StreamProvider` — wszystkie ekrany czytają z jednego źródła.

**Firestore rules:**
```javascript
match /organization_quota/{orgId} {
  allow read: if request.auth != null
              && exists(/databases/$(database)/documents/user_org/$(request.auth.uid))
              && get(/databases/$(database)/documents/user_org/$(request.auth.uid)).data.organizationId == orgId;
  allow write: if false;
}
```

### 16.4 Flutter UI States

#### 16.4.1 Pre-flight check przy `CreateSession`

**Gdzie:** Ekran "Nowa sesja" → tap "Rozpocznij nagrywanie".

**Backend call:** `clinical-svc.CreateSession` → internal call `billing-svc.CheckQuota(amount=1)`.

**Stany:**

| Backend response | Flutter behavior |
|---|---|
| `QuotaDecision{allowed=true, remaining > 5}` | Nagrywanie startuje, brak ostrzeżenia. |
| `QuotaDecision{allowed=true, remaining ∈ [1, 5]}` | **Soft warning banner** przed nagrywaniem (dismissible). |
| `QuotaDecision{allowed=true, remaining == 0}` (edge case: ostatni token zarezerwowany przez inną sesję) | Pre-flight pokazuje błąd jak `quota_exhausted` (patrz dialog poniżej). |
| `QuotaDecision{allowed=false, reason="SUBSCRIPTION_PAST_DUE"}` | Blokujący dialog, link do "Ustawienia → Subskrypcja". |
| `QuotaDecision{allowed=false, reason="QUOTA_EXHAUSTED"}` | **Non-blocking** dialog z opcją "Nagrywaj mimo to" (audio leci do local store). |

**Copy (PL) — soft warning banner przed nagrywaniem:**

```
⚠ Zostały Ci 3 tokeny

Po wyczerpaniu pula odnawia się 28 czerwca 2026.
[Rozszerz plan]   [Rozumiem, kontynuuj]
```

**Copy (PL) — quota_exhausted dialog (NON-BLOCKING, kluczowe dla "Świętości Nagrania"):**

```
Pula tokenów wyczerpana

Możesz nadal nagrywać sesję — audio zostanie bezpiecznie
zaszyfrowane i zapisane lokalnie na Twoim urządzeniu.
Po rozszerzeniu planu lub odnowieniu puli (28 czerwca 2026)
możesz wznowić przetwarzanie sesji z poziomu Kartoteki.

[Anuluj]   [Rozszerz plan]   [Nagrywaj lokalnie]
```

**Decyzja "Nagrywaj lokalnie":** Flutter ustawia `session.processing_status = PENDING_QUOTA` (nowy lokalny state, NIE na backendzie — sesja nawet nie jest jeszcze w PG), trzyma audio w encrypted chunks (per `11_IPHONE_AUDIO_CONVERSION.md` i `13_STT_GCS_CALLBACK_AND_CHUNKING.md`).

#### 16.4.2 Pending sessions widget na Kartotece

**Gdzie:** Kartoteka pacjenta (`patient_files` detail screen), góra ekranu.

**Trigger:** Local storage zawiera sesje w stanie `PENDING_QUOTA` LUB `UPLOAD_FAILED_QUOTA`.

**Wygląd (3 stany):**

**Stan A — `warningLevel = warning` lub `critical`, brak pending sessions:**

```
┌──────────────────────────────────────────────────┐
│ ⚠ Pozostały Ci 3 tokeny do 28 czerwca 2026       │
│   [Rozszerz plan]                                 │
└──────────────────────────────────────────────────┘
```

Dismissible per session (jeśli user zamknął, banner wraca przy następnym refresh).

**Stan B — `warningLevel = exhausted`, brak pending sessions:**

```
┌──────────────────────────────────────────────────┐
│ ⊘ Pula tokenów wyczerpana                         │
│   Nowe sesje będą zapisywane lokalnie do dnia    │
│   odnowienia (28 czerwca 2026).                   │
│   [Rozszerz plan]                                 │
└──────────────────────────────────────────────────┘
```

**Stan C — pending sessions istnieją (priorytet nad A/B):**

```
┌──────────────────────────────────────────────────┐
│ ⌛ Sesje oczekujące na przetworzenie (2)          │
│                                                   │
│  • Sesja z 22.05.2026, 14:30 (52 min)            │
│    Audio zapisane lokalnie · Czeka na tokeny     │
│    [Wznów przetwarzanie]   [Usuń]                │
│                                                   │
│  • Sesja z 24.05.2026, 09:00 (47 min)            │
│    Audio zapisane lokalnie · Czeka na tokeny     │
│    [Wznów przetwarzanie]   [Usuń]                │
│                                                   │
│  Tokeny dostępne: 0 / Wymagane: 2                │
│  [Rozszerz plan]                                  │
└──────────────────────────────────────────────────┘
```

**"Wznów przetwarzanie":** Flutter retry: `ingestion-svc.CreateAudioUpload` → `billing-svc.ReserveCredit`. Jeśli teraz są tokeny → upload startuje, audio z local storage idzie do GCS. Jeśli nadal brak → zostaje w widgecie.

**"Usuń":** Lokalne kasowanie audio (po confirm dialogu — to **trwała utrata danych klinicznych**). Confirm copy:

```
Usunąć nagranie sesji z 22.05.2026?

Audio zostanie trwale usunięte z tego urządzenia.
Tej operacji nie można cofnąć.

[Anuluj]   [Usuń trwale]
```

#### 16.4.3 In-app banners (global, sticky)

Powyżej AppBar w aplikacji (per `09_UI_MVP_FLUTTER.md` design system), reaguje na Firestore `organization_quota` stream:

| `warningLevel` | Banner | Kolor | Dismissible |
|---|---|---|---|
| `none` | brak | — | — |
| `warning` | "Zostały Ci {N} tokenów" + link "Rozszerz plan" | żółty (warning) | tak, per session |
| `critical` | "Został Ci 1 token" + link "Rozszerz plan" | pomarańczowy | tak, per session |
| `exhausted` | "Pula wyczerpana — nowe sesje zapiszą się lokalnie" + link | czerwony (error) | **nie** (sticky do końca okresu) |

#### 16.4.4 Mid-pipeline failures (reservation expired / payment past_due)

**Reservation expired** (rzadkie — upload trwał >4h):

Flutter on listening do `session_states/{sessionId}` w Firestore widzi `processingStatus = FAILED, errorCode = "reservation_expired"`. Pokazuje per-session card:

```
✗ Sesja z 22.05.2026 — przetwarzanie nie powiodło się

Rezerwacja tokena wygasła po 4 godzinach.
Audio jest nadal zapisane lokalnie.

[Spróbuj ponownie]   [Usuń lokalne audio]
```

"Spróbuj ponownie" → ten sam flow co "Wznów przetwarzanie" z §16.4.2.

**Subscription past_due** (Stripe nie pobrał płatności): Modal full-screen przy starcie aplikacji (sticky, niedismissible):

```
Problem z płatnością

Nie udało się pobrać opłaty za subskrypcję.
Możesz kontynuować korzystanie z aplikacji,
ale do czasu rozwiązania problemu nie będziemy
przetwarzać nowych sesji.

[Otwórz ustawienia płatności]   [Skontaktuj się z nami]
```

### 16.5 `error_code_ui` → ARB key mapping

Flutter ma w `lib/l10n/app_pl.arb` (wraz z `app_en.arb`):

```json
{
  "billingQuotaWarning": "Zostały Ci {n, plural, =1{1 token} other{{n} tokenów}}",
  "@billingQuotaWarning": { "placeholders": { "n": { "type": "int" } } },

  "billingQuotaCritical": "Został Ci ostatni token",
  "billingQuotaExhausted": "Pula tokenów wyczerpana",

  "billingPendingSessionTitle": "Sesja z {date}, {time} ({duration} min)",
  "billingPendingSessionSubtitle": "Audio zapisane lokalnie · Czeka na tokeny",
  "billingResumeProcessing": "Wznów przetwarzanie",
  "billingDeleteLocalAudio": "Usuń",

  "billingExpandPlanCta": "Rozszerz plan",
  "billingRecordLocallyCta": "Nagrywaj lokalnie",

  "billingReservationExpired": "Rezerwacja tokena wygasła po 4 godzinach",
  "billingSubscriptionPastDue": "Problem z płatnością",
  "billingSubscriptionPastDueBody": "Nie udało się pobrać opłaty. Sesje nie będą przetwarzane do rozwiązania problemu.",

  "billingPeriodRenewed": "Pula tokenów odnowiona — masz znów {n, plural, =1{1 token} other{{n} tokenów}}",
  "@billingPeriodRenewed": { "placeholders": { "n": { "type": "int" } } },

  "billingDeleteConfirmTitle": "Usunąć nagranie sesji z {date}?",
  "billingDeleteConfirmBody": "Audio zostanie trwale usunięte z tego urządzenia. Tej operacji nie można cofnąć."
}
```

Backend mapping (`pkg/errors/billing_codes.go`):

```go
const (
    ErrCodeQuotaWarning         = "quota_warning"
    ErrCodeQuotaCritical        = "quota_critical"
    ErrCodeQuotaExhausted       = "quota_exhausted"
    ErrCodeReservationExpired   = "reservation_expired"
    ErrCodeSubscriptionPastDue  = "subscription_past_due"
    ErrCodeSubscriptionInactive = "subscription_inactive"
)
```

Flutter `error_code_resolver.dart`:

```dart
String resolveErrorCode(BuildContext context, String code, Map<String, dynamic>? params) {
  final l = AppLocalizations.of(context)!;
  switch (code) {
    case 'quota_warning':    return l.billingQuotaWarning(params?['remaining'] ?? 0);
    case 'quota_critical':   return l.billingQuotaCritical;
    case 'quota_exhausted':  return l.billingQuotaExhausted;
    case 'reservation_expired': return l.billingReservationExpired;
    case 'subscription_past_due': return l.billingSubscriptionPastDue;
    // ...
    default: return l.errorGeneric;
  }
}
```

### 16.6 FCM data payload schema (canonical)

Per ADR-IMPL-013 (no PHI in FCM), payload zawiera tylko routing info:

```json
{
  "notification_type": "quota_warning",
  "organization_id": "uuid",
  "tokens_remaining": "3",
  "period_end": "1716678400",
  "deep_link": "superwizor://billing/quota"
}
```

Flutter on receive (`notification-svc/internal/fcm/payload.go` → mobile handler):

1. Parsuje `notification_type` → znajduje odpowiedni ARB key (sekcja 16.5).
2. Renderuje notyfikację z lokalnym tłumaczeniem (jeśli app w foreground); jeśli background — OS pokazuje pre-renderowane przez backend body (sekcja 16.2).
3. Tap → `deep_link` otwiera ekran "Ustawienia → Subskrypcja" lub Kartotekę z pending sessions.

### 16.7 Reguły UX — pinned

| # | Reguła | Konsekwencja |
|---|---|---|
| **UX-1** | **Brak tokenów NIGDY nie blokuje nagrywania.** | Confirm dialog jest non-blocking; "Nagrywaj lokalnie" zawsze dostępne. Świętość Nagrania > UX friction. |
| **UX-2** | **Quota warning to edge-trigger, nie level-trigger.** | Push leci raz przy przekroczeniu progu, nie przy każdej kolejnej sesji poniżej progu. |
| **UX-3** | **Local audio NIE auto-uploaduje się po renewal.** | Wymaga jawnego "Wznów" od terapeuty — żeby nie spalić nowych tokenów na stare sesje bez kontekstu (np. sesja sprzed 3 miesięcy może być już bez sensu klinicznego). |
| **UX-4** | **Usunięcie lokalnego audio wymaga confirm.** | To trwała utrata danych klinicznych. Confirm dialog z explicit wording. |
| **UX-5** | **Pending sessions widget jest priorytetem nad ogólnym banner-em quota.** | Jeśli są zaległe sesje, pokazujemy je zamiast informacji o pozostałych tokenach — terapeuta wie ile mu zostało z widgetu. |
| **UX-6** | **Push notification nie zawiera PHI.** | Per ADR-IMPL-013 — payload data-only, body generyczne ("Zostały Ci 3 tokeny", nie "Sesja z pacjentką Anną się nie udała"). |

### 16.8 Test scenarios (E2E, Flutter)

| Scenario | Setup | Expected |
|---|---|---|
| Token warning at 5 | Organization z 5 pozostałymi tokenami | FCM push received, warning banner widoczny |
| Quota exhausted mid-recording | Tokeny = 0 podczas nagrywania (nie powinno się zdarzyć — rezerwacja, ale defensive) | Recording się nie przerywa, lokalne audio |
| Pending session resume after renewal | 2 pending sessions, period_renewed event | Pending widget widoczny, "Wznów" dostępne, użycie tokenów po wznowieniu |
| Reservation expiry mid-pipeline | Manual: ustaw `expires_at = now() - 1h` w PG, run cron | Flutter pokazuje per-session error card |
| Subscription past_due | Stripe CLI: `trigger invoice.payment_failed` | Full-screen modal, sesje nie startują |
| Edge-triggered push (5 → 4 → 3) | Trzy sesje pod rząd, każda zjada 1 token | **Jeden** push przy przekroczeniu 5, nie trzy |

---

## 17. Cross-reference

- [01_ARCHITEKTURA_TECHNICZNA.md §4.2.2](./01_ARCHITEKTURA_TECHNICZNA.md) — high-level service responsibility.
- [02_DATA_MODEL.md §4.4](./02_DATA_MODEL.md) — base billing schema (v4.3 — zaktualizowana wartość `tokens_*` per ADR-DM-017 w v4.4).
- [agents/00_GLOBAL_CONTEXT.md](./agents/00_GLOBAL_CONTEXT.md) — cross-cutting patterns (idempotency, outbox, audit, cryptobox).
- [agents/03_billing-svc.md](./agents/03_billing-svc.md) — service-level agent guide; **wymaga update** po wdrożeniu Phase 3 (sekcja "Status" → "Phase 3 live", "Tables" → "built per migration 000027-000029").
