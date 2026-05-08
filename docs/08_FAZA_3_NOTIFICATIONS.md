# 🔔 Faza 3 — Notifications & Mobile Sync (Tygodnie 8-10)

> **Cel:** Doprowadzić `notification-svc` z dzisiejszego stubu (`go.mod` + 28-bajtowy `main.go`) do działającego serwisu, który (a) odbiera Pub/Sub eventy z pipeline'u AI, (b) wysyła FCM push do terapeuty, (c) lustruje status sesji do Firestore tak, by aplikacja Flutter dostawała live update bez pollowania.
>
> Bazuje na: [`02_ARCHITEKTURA_TECHNICZNA.md`](./02_ARCHITEKTURA_TECHNICZNA.md) §4.2.7 + §6, [`03_DATA_MODEL.md`](./03_DATA_MODEL.md), oraz wzorcach ustabilizowanych w Fazie 2 (Cloud Functions Gen2 workery + KMS envelope encryption + DLQ).

---

## 📝 Changelog

- **v1.0** (2026-05-08): Pierwsza wersja sprintów dla `notification-svc`. Drop WebSocket vs spec — Firestore listener wystarcza.

---

## 📋 Spis treści

1. [Definition of Done](#definition-of-done)
2. [Decyzje architektoniczne (ADR-IMPL-008+)](#decyzje-architektoniczne)
3. [Sprint planning + dependencies](#sprint-planning)
4. [Sprint 3.1 — Migracje DDL (FCM tokens, deliveries)](#sprint-31)
5. [Sprint 3.2 — Proto + Firestore rules + IAM](#sprint-32)
6. [Sprint 3.3 — Worker (Pub/Sub → FCM + Firestore)](#sprint-33)
7. [Sprint 3.4 — gRPC server (token registration)](#sprint-34)
8. [Sprint 3.5 — Pipeline integration (status events)](#sprint-35)
9. [Sprint 3.6 — E2E + observability](#sprint-36)
10. [Troubleshooting cookbook](#troubleshooting-cookbook)
11. [Pre-Faza 4 checklist](#pre-faza-4-checklist)

---

## Definition of Done

Cała faza zakończona, gdy **wszystkie** poniższe są prawdziwe (jednoczesny test):

### Funkcjonalne

- [ ] Po zakończeniu pipeline'u AI (`report.generated` Pub/Sub event) terapeuta otrzymuje **FCM push** w ciągu < 5 sekund od zapisu raportu w PG.
- [ ] Aplikacja Flutter, mając otwarty ekran sesji, widzi **live update statusu** (`UPLOADED → TRANSCRIBING → ANALYZING → COMPLETED`) przez Firestore listener — bez pollowania.
- [ ] Terapeuta z dwoma urządzeniami (iPhone + iPad) dostaje powiadomienie na **oba**.
- [ ] Wylogowanie z urządzenia kasuje token; kolejne powiadomienia nie są na nie wysyłane.
- [ ] Token, który FCM oznaczy jako `NotRegistered` (np. odinstalowanie aplikacji), jest soft-deleted automatycznie po pierwszej takiej odpowiedzi.

### Niefunkcjonalne

- [ ] **P1 (Zero Data Loss)** — przy duplikacji Pub/Sub message dostarczone jest **dokładnie jedno** powiadomienie (idempotency key na `notification_deliveries`).
- [ ] **§6.3 (Firestore best-effort)** — błąd zapisu do Firestore NIE blokuje wysyłki FCM ani statusu sesji w PG. Failed Firestore writes idą do DLQ; pipeline kliniczny nigdy nie czeka.
- [ ] **P4 (Flutter read-only)** — Firestore rules wymuszają `allow write: if false` na obu kolekcjach (`session_states`, `user_notifications`). Flutter może tylko czytać + ustawiać `readAt` na własnej notyfikacji.
- [ ] Dedykowany SA `notification-svc@<project>` z minimalnym IAM: `roles/datastore.user`, `roles/cloudsql.client`, `roles/secretmanager.secretAccessor`, `roles/firebasecloudmessaging.messagesSender`. **Zero `roles/editor`.**
- [ ] DLQ subscription `notification-deliveries.dlq` z TTL = 7 dni — wszystkie zatrute messagy lądują tam, alert z monitoringa.
- [ ] Loud failures: każde `slog.Error` z `session_id` + `user_id` + przyczyną — żadnych silent `continue` (lekcja z Fazy 2 KMS misconfig).

### Operacyjne

- [ ] Migracje 000009+ zaaplikowane w staging przez `module.migrations` (terragrunt apply).
- [ ] Cloud Function Gen2 `notification-worker` zdeployowany przez `module.cloud_functions` (rozszerzenie istniejącego modułu).
- [ ] Cloud Run service `notification-svc` zdeployowany przez `.github/workflows/ci.yml` (analogicznie do `clinical-svc`).
- [ ] Firestore rules zastąpione produkcyjnymi (z §6.4 architektury) — obecne wide-open rules **wygasają 2026-05-28**, więc to musi się stać przed tą datą niezależnie.
- [ ] E2E test (`tests/e2e/full_session_test.go`) rozszerzony o assertion na Firestore `session_states/{sessionId}` doc.

---

## Decyzje architektoniczne

W kontynuacji ADR-IMPL-001 do 007 (Faza 2):

### ADR-IMPL-008: Drop WebSocket — Firestore listener wystarcza

Architektura w §4.2.7 wspomina o WebSocket connection dla aplikacji Flutter w foreground. **Pomijamy.**

**Uzasadnienie:**

- Firestore listener z FlutterFire ma już offline cache, automatic reconnect, exponential backoff — nie ma sensu pisać tego od zera.
- WebSocket dodaje **drugi protokół** (poza gRPC + REST + Pub/Sub) i drugi sposób utrzymania state.
- Cloud Run **nie skaluje na podstawie liczby otwartych WebSocketów** — sticky connections + scale-to-zero kolidują.
- Latencja Firestore listener'a (~100-500ms cold, ~50ms ciepły) jest wystarczająca dla statusu sesji (status zmienia się raz na 30-60s).

**Konsekwencja:** notification-svc pisze tylko do Firestore + FCM. Flutter subskrybuje Firestore. Koniec.

### ADR-IMPL-009: Firestore writes są best-effort (nie blokują pipeline'u klinicznego)

Z §6.3: "Firestore jest 'nice to have' (retry z DLQ, ale nie blokuje ścieżki klinicznej)."

**Implementacja:**

- Worker subskrybuje `report.generated` → wysyła FCM → próbuje zapisać do Firestore → **ACK Pub/Sub niezależnie od wyniku Firestore write**.
- Failed Firestore writes idą do osobnego DLQ topic'a `firestore-sync.dlq` z retry policy max 6 prób.
- Alert z Cloud Monitoring na `firestore-sync.dlq` > 0 messages — ale **nie failed CI build**, nie blokuje deploy'u.

### ADR-IMPL-010: Worker = Cloud Functions Gen2; Server = Cloud Run

Powiela wzorzec z Fazy 2 (`stt-worker` + `llm-worker` jako Cloud Functions, `ai-pipeline-svc` Cloud Run server).

| Komponent | Type | Trigger | Source |
|---|---|---|---|
| `notification-worker` | Cloud Functions Gen2 | Pub/Sub `report.generated` (i inne) | `services/notification-svc/cmd/worker/` |
| `notification-svc` | Cloud Run | gRPC (Flutter calls) | `services/notification-svc/cmd/server/` |

Oba pakety w jednym module Go (`services/notification-svc/`). Wzorcowy split — patrz `cmd/{server,stt-worker,llm-worker}` w `ai-pipeline-svc`.

### ADR-IMPL-011: FCM tokens — multi-token per user, soft-delete na NotRegistered

Terapeuci często mają iPhone + iPad + Android jednocześnie. Wysyłamy do **wszystkich** aktywnych tokenów. Token rotation jest natywne w Firebase SDK (~30 dni).

**Reguły:**

- `fcm_tokens.user_id + token` — UNIQUE index (where invalidated_at IS NULL).
- Re-registration tego samego tokena = idempotent UPSERT, aktualizuje `last_used_at` + `app_version`.
- FCM response `errorCode = NotRegistered | InvalidRegistration` → SET `invalidated_at = now()`.
- Cron / cleanup job kasuje hard tokens z `invalidated_at < now() - 30 days` (Faza 4 — niska priorytet).

### ADR-IMPL-012: Status taxonomy + minimum viable status events

Statusy sesji w PG (`sessions.status`) i ich mapping na Firestore:

| sessions.status (PG) | Firestore session_states.status | Trigger event |
|---|---|---|
| `CREATED` | `created` | (Flutter sees this from clinical-svc.ListSessions; nie potrzebuje Firestore yet) |
| `UPLOADED` | `uploaded` | `audio.uploaded` Pub/Sub |
| `TRANSCRIBING` | `transcribing` | (Faza 3.1: brak; Faza 4 może dodać `session.status_changed` topic) |
| `ANALYZING` | `analyzing` | `transcript.completed` Pub/Sub (== llm-worker zaczyna pracę) |
| `COMPLETED` | `done` | `report.generated` Pub/Sub |
| `FAILED` | `failed` | (Faza 3.1: brak; clinical-svc.GetSessionDetails zwraca terminal state przy poll) |

**Faza 3 scope: tylko 3 transitions** (`uploaded`, `analyzing`, `done`). `transcribing` i `failed` są lukami świadomie zostawionymi — Flutter pyta clinical-svc o szczegóły gdy listener nic nie pokazuje przez > 30s.

**Faza 4 (out of scope dla tej fazy):** dodać `session.status_changed` topic, do którego każdy worker publikuje na każdą zmianę statusu. Wtedy notification-svc subskrybuje tylko jeden topic i Firestore odzwierciedla wszystkie 6 statusów.

### ADR-IMPL-013: Brak szyfrowania payload'u FCM

FCM message body NIE zawiera PHI:

- Tytuł: lokalizowany string "Raport gotowy" / "Sesja zakończona".
- Body: max 50 znaków, generic ("Sesja z dnia 5 maja jest gotowa do wglądu" — bez imienia, bez treści raportu).
- Data payload: tylko `session_id` + `notification_type` + `created_at`.

Flutter, po kliknięciu w notyfikację, otwiera ekran sesji i robi `clinical-svc.GetSessionDetails` (z deszyfracją przez KMS) — tam jest właściwy raport.

**Konsekwencja:** w razie wycieku FCM payload (logi, monitoring) — nie ma PHI exposure.

---

## Sprint planning

### Timeline

```
Tydzień 8                Tydzień 9                Tydzień 10
─────────────────        ─────────────────        ─────────────────
Sprint 3.1: Migracje     Sprint 3.3: Worker       Sprint 3.5: Status pipeline
Sprint 3.2: Proto + IAM  Sprint 3.4: gRPC server  Sprint 3.6: E2E + obs
                                                  Tag v0.4.0-dev.1
```

Realistyczny szacunek: **3 tygodnie dla solo dev / 2 tygodnie dla pary**. Sprint 3.3 + 3.4 mogą iść równolegle (worker i server są niezależne).

### Dependencies

**Wymaga zakończenia:**

- ✅ Faza 2 (zakończona przy `v0.3.0-dev.1`) — pipeline `report.generated` działa end-to-end.
- ✅ KMS keyring (do podpisywania FCM tokenów jako PHI-equivalent — choć ADR-013 mówi że nie — lepiej zaszyfrować same `fcm_tokens.token` na wszelki wypadek? **Decyzja: NIE szyfrować tokenów FCM**. Tokeny FCM nie są PHI; są opaque identyfikatorami, podobnymi do session ID. Trzymamy plain w bazie. Dostęp via IAM scope na PG.).
- ✅ Firestore rules placeholder — istnieje, **wygasa 2026-05-28**. To wymusza wdrożenie produkcyjnych rules przed tą datą **niezależnie od reszty fazy**.

**Blokery dla kolejnych faz:**

- Faza 4 (analytics, billing, reporting do organizacji) zakłada że terapeuci dostają powiadomienia — bez tego adoption mobile testów się ślimaczy.

---

## Sprint 3.1 — Migracje DDL: FCM tokens + deliveries

**Cel:** dwie nowe tabele do śledzenia urządzeń i wysłanych powiadomień. Idempotency + observability.

### Task 3.1.1 — Migracja 000009: FCM tokens + deliveries

**Plik:** `migrations/000009_notifications.up.sql`

```sql
-- ============================================
-- FCM TOKENS — per-user device tokens
-- ============================================
-- Multi-token per user (iPhone + iPad + Android scenario).
-- Soft delete via invalidated_at — set when FCM returns NotRegistered.

CREATE TABLE fcm_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    token           TEXT NOT NULL,         -- opaque FCM identifier; not PHI
    platform        VARCHAR(20) NOT NULL,  -- 'ios' | 'android' | 'web'
    app_version     VARCHAR(32),
    device_model    VARCHAR(100),
    locale          VARCHAR(10),           -- 'pl-PL' | 'en-US' for FCM body localization

    last_used_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Soft delete on FCM NotRegistered / token rotation. Hard delete via cron > 30 days.
    invalidated_at  TIMESTAMPTZ,
    invalidated_reason VARCHAR(50)        -- 'fcm_not_registered' | 'user_logout' | 'rotated'
);

-- Active tokens unique by (user, token). Allows historical inactive tokens with
-- the same string to coexist (rare but possible after rotation).
CREATE UNIQUE INDEX idx_fcm_tokens_active_user_token
    ON fcm_tokens(user_id, token)
    WHERE invalidated_at IS NULL;

CREATE INDEX idx_fcm_tokens_user_active
    ON fcm_tokens(user_id, last_used_at DESC)
    WHERE invalidated_at IS NULL;

-- ============================================
-- NOTIFICATION DELIVERIES — audit + idempotency
-- ============================================
-- Every attempted FCM send gets a row. Idempotency key prevents duplicate
-- sends from at-least-once Pub/Sub delivery.

CREATE TYPE notification_status AS ENUM (
    'queued',
    'sent',
    'failed',
    'token_invalid'
);

CREATE TABLE notification_deliveries (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES users(id),
    session_id        UUID REFERENCES sessions(id),

    notification_type VARCHAR(50) NOT NULL,  -- 'report_ready' | 'session_failed' | ...
    fcm_message_id    VARCHAR(255),          -- returned by Firebase Admin SDK on success

    -- Idempotency: typically `${session_id}:${notification_type}`.
    -- Same key → no duplicate send.
    idempotency_key   VARCHAR(128) NOT NULL UNIQUE,

    target_token_id   UUID REFERENCES fcm_tokens(id) ON DELETE SET NULL,

    status            notification_status NOT NULL DEFAULT 'queued',
    error_code        VARCHAR(100),  -- 'NotRegistered' | 'QuotaExceeded' | etc.
    error_message     TEXT,

    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at           TIMESTAMPTZ
);

CREATE INDEX idx_notif_deliveries_user_recent
    ON notification_deliveries(user_id, created_at DESC);
CREATE INDEX idx_notif_deliveries_session
    ON notification_deliveries(session_id, created_at DESC)
    WHERE session_id IS NOT NULL;
CREATE INDEX idx_notif_deliveries_status_recent
    ON notification_deliveries(status, created_at DESC)
    WHERE status IN ('queued', 'failed');
```

**Plik:** `migrations/000009_notifications.down.sql`

```sql
DROP TABLE IF EXISTS notification_deliveries;
DROP TYPE IF EXISTS notification_status;
DROP TABLE IF EXISTS fcm_tokens;
```

### Task 3.1.2 — Apply

```bash
cd superwizor-backend/infra/environments/staging
terragrunt apply -target=module.migrations
```

`module.migrations` triggers on `migrations/*.sql` hash change — wystarczy dropnąć migrację i apply.

### Sprint 3.1 Smoke test

```bash
gcloud sql connect superwizor-db-bc4c27de --user=superwizor_app --quiet
\d fcm_tokens                         -- column types match spec
\d notification_deliveries
SELECT enum_range(NULL::notification_status);  -- 4 values
```

---

## Sprint 3.2 — Proto + Firestore rules + IAM

**Cel:** kontrakt gRPC do rejestracji tokenów, prawdziwe Firestore rules zamiast placeholder'a, dedykowany SA z minimalnym IAM.

### Task 3.2.1 — Proto definition

**Plik:** `proto/notification/v1/notification.proto`

```protobuf
syntax = "proto3";

package notification.v1;

import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

option go_package = "github.com/superwizor-ai/backend/gen/go/notification/v1;notificationv1";

service NotificationService {
  // FCM token lifecycle
  rpc RegisterFCMToken(RegisterFCMTokenRequest) returns (RegisterFCMTokenResponse);
  rpc RemoveFCMToken(RemoveFCMTokenRequest) returns (google.protobuf.Empty);

  // Inbox queries (badges, recent list)
  rpc GetUnreadCount(google.protobuf.Empty) returns (GetUnreadCountResponse);

  // Health
  rpc HealthCheck(google.protobuf.Empty) returns (HealthCheckResponse);
}

message RegisterFCMTokenRequest {
  // user_id resolved from Firebase ID token in gRPC metadata; never trusted
  // from client.
  string token = 1;
  Platform platform = 2;
  string app_version = 3;     // semver string; informational
  string device_model = 4;    // for support diagnostics
  string locale = 5;          // BCP-47, e.g. "pl-PL"
}

message RegisterFCMTokenResponse {
  string token_id = 1;        // UUID of fcm_tokens row
  bool already_registered = 2; // true if same (user, token) was already active
}

enum Platform {
  PLATFORM_UNSPECIFIED = 0;
  PLATFORM_IOS = 1;
  PLATFORM_ANDROID = 2;
  PLATFORM_WEB = 3;
}

message RemoveFCMTokenRequest {
  string token = 1;
}

message GetUnreadCountResponse {
  int32 count = 1;
}

message HealthCheckResponse {
  bool ok = 1;
  string version = 2;
}
```

Generate via `buf generate proto/`.

### Task 3.2.2 — Firestore rules

**Plik:** `firestore.rules` (REPLACE the placeholder — ten plik wygasa 2026-05-28!)

```js
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // ============================================================
    // session_states — read-only mirror of sessions.status from PG.
    // Therapist subscribes to this for live status updates.
    // Backend (notification-svc) is the only writer.
    // ============================================================
    match /session_states/{sessionId} {
      allow read: if request.auth != null
                  && request.auth.uid == resource.data.therapistFirebaseUid;
      allow write: if false;  // backend uses Admin SDK, bypasses rules
    }

    // ============================================================
    // user_notifications/{uid}/inbox — recent notifications shown
    // on Flutter notification tray. User can ONLY mark as read.
    // ============================================================
    match /user_notifications/{uid}/inbox/{notifId} {
      allow read: if request.auth != null && request.auth.uid == uid;

      // Allow user to set readAt — and ONLY readAt. Diff check prevents
      // tampering with title / body / sessionId / etc.
      allow update: if request.auth != null
                    && request.auth.uid == uid
                    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['readAt']);

      allow create, delete: if false;
    }

    // Default deny — covers any documents we haven't named explicitly.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

Deploy via Firebase CLI:

```bash
firebase deploy --only firestore:rules --project=superwizor-ai-25ecd
```

Or wire into terraform (`google_firebaserules_release` resource) for full IaC — opcjonalnie.

### Task 3.2.3 — Service account + IAM

**Plik:** `infra/environments/staging/service-accounts.tf` (append)

```hcl
# notification-svc needs:
#   - cloudsql.client (read fcm_tokens, write notification_deliveries)
#   - secretmanager.secretAccessor on postgres-database-url
#   - datastore.user (write to Firestore — the ONLY service allowed to)
#   - firebasecloudmessaging.messagesSender (send FCM via Admin SDK)
resource "google_service_account" "notification_svc" {
  account_id   = "notification-svc"
  display_name = "Notification Service SA"
  project      = var.project_id
}

resource "google_project_iam_member" "notification_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.notification_svc.email}"
}

resource "google_secret_manager_secret_iam_member" "notification_db_pwd" {
  project   = var.project_id
  secret_id = "postgres-database-url"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.notification_svc.email}"
}

resource "google_project_iam_member" "notification_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.notification_svc.email}"
}

resource "google_project_iam_member" "notification_fcm" {
  project = var.project_id
  role    = "roles/firebasecloudmessaging.messagesSender"
  member  = "serviceAccount:${google_service_account.notification_svc.email}"
}

# Eventarc trigger for the worker (analogous to stt-worker / llm-worker)
resource "google_project_iam_member" "notification_worker_eventarc" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.notification_svc.email}"
}

# Pub/Sub service agent → SA token creator (so Eventarc can mint
# tokens as notification-svc when invoking the function)
resource "google_service_account_iam_member" "pubsub_sa_notification_token_creator" {
  service_account_id = google_service_account.notification_svc.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}
```

Add `notification-svc` to `local.public_cloud_run_services` w istniejącym `public_invoker` block — Flutter zaraz zacznie wołać `RegisterFCMToken`.

```hcl
locals {
  public_cloud_run_services = [
    "identity-svc",
    "clinical-svc",
    "ingestion-svc",
    "api-service",
    "notification-svc",  # NEW
  ]
}
```

### Task 3.2.4 — Apply

```bash
cd superwizor-backend/infra/environments/staging
terragrunt apply
# expected plan: 5 service-account resources + 1 cloud_run_v2_service_iam_member
```

### Sprint 3.2 Smoke test

```bash
# 1. SA exists
gcloud iam service-accounts describe \
  notification-svc@superwizor-ai-25ecd.iam.gserviceaccount.com \
  --project=superwizor-ai-25ecd

# 2. Bindings present
gcloud projects get-iam-policy superwizor-ai-25ecd \
  --flatten="bindings[].members" \
  --filter="bindings.members:notification-svc@" \
  --format="table(bindings.role)"

# 3. Firestore rules deployed
firebase firestore:rules:get --project=superwizor-ai-25ecd

# 4. Proto stubs generated
ls superwizor-backend/gen/go/notification/v1/
```

---

## Sprint 3.3 — Worker: Pub/Sub → FCM + Firestore

**Cel:** Cloud Functions Gen2 worker, który subskrybuje `report.generated` (i potem inne topic'i), wysyła FCM, lustruje status do Firestore. Idempotentny, best-effort dla Firestore.

### Task 3.3.1 — Worker entry point

**Plik:** `services/notification-svc/cmd/worker/main.go`

```go
package notificationworker

import (
    "context"
    "log/slog"
    "os"

    firebase "firebase.google.com/go/v4"
    fbmessaging "firebase.google.com/go/v4/messaging"
    "cloud.google.com/go/firestore"
    "github.com/GoogleCloudPlatform/functions-framework-go/functions"
    "github.com/cloudevents/sdk-go/v2/event"
    "github.com/jackc/pgx/v5/pgxpool"
)

var (
    dbPool          *pgxpool.Pool
    firestoreClient *firestore.Client
    fcmClient       *fbmessaging.Client
    projectID       string
)

func init() {
    ctx := context.Background()
    projectID = os.Getenv("GCP_PROJECT_ID")

    if dsn := os.Getenv("DATABASE_URL"); dsn != "" {
        dbPool, _ = pgxpool.New(ctx, dsn)
    }
    if projectID != "" {
        firestoreClient, _ = firestore.NewClient(ctx, projectID)
        app, _ := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID})
        fcmClient, _ = app.Messaging(ctx)
    }

    functions.CloudEvent("ProcessReportGenerated", ProcessReportGenerated)
    // Future sprint 3.5: register additional handlers for audio.uploaded /
    // transcript.completed and wire them as separate Eventarc triggers.
}

// ProcessReportGenerated handles `report.generated` Pub/Sub events:
//   1. Idempotency check (notification_deliveries.idempotency_key UNIQUE).
//   2. Load session + therapist user.
//   3. Send FCM push to all therapist's active fcm_tokens.
//   4. Best-effort Firestore writes:
//      - session_states/{sessionId}.status = "done"
//      - user_notifications/{firebase_uid}/inbox/{notifId}
//   5. Record delivery rows + update tokens on FCM errors.
//
// Steps 3 and 4 are independent — failure in 4 doesn't stop 3 from being
// ACK'd. Failed Firestore writes go to firestore-sync.dlq.
func ProcessReportGenerated(ctx context.Context, e event.Event) error {
    // ... full impl ~150 lines, mirrors stt-worker / llm-worker structure
    return nil
}
```

### Task 3.3.2 — Idempotency middleware

Klucz idempotencji: `${session_id}:report_ready` (jeden sygnał per sesja).

```go
// idempotency check at entry — INSERT ... ON CONFLICT DO NOTHING returning ID.
// If conflict (already processed), short-circuit and ACK without resending.
const idempotencyKey = sessionID + ":report_ready"

result, err := dbPool.Exec(ctx, `
    INSERT INTO notification_deliveries
        (user_id, session_id, notification_type, idempotency_key, status)
    VALUES ($1, $2, 'report_ready', $3, 'queued')
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id`,
    therapistID, sessionID, idempotencyKey)
if err != nil { return err }
if result.RowsAffected() == 0 {
    logger.Info("duplicate report.generated event — already processed",
        "session_id", sessionID)
    return nil  // ACK; not a failure
}
```

### Task 3.3.3 — FCM send + token invalidation

Multicast (one call to FCM, multiple tokens):

```go
tokens := loadActiveTokens(ctx, therapistID)
if len(tokens) == 0 {
    logger.Warn("therapist has no active FCM tokens — skipping push",
        "therapist_id", therapistID)
    // Still write Firestore so foreground app sees the update.
    return writeFirestore(ctx, sessionID, "done")
}

msg := &fbmessaging.MulticastMessage{
    Tokens: tokenStrings(tokens),
    Notification: &fbmessaging.Notification{
        Title: localize(locale, "notification.report_ready.title"),
        Body:  localize(locale, "notification.report_ready.body"),
    },
    Data: map[string]string{
        "session_id":         sessionID,
        "notification_type":  "report_ready",
    },
    APNS: &fbmessaging.APNSConfig{
        Payload: &fbmessaging.APNSPayload{
            Aps: &fbmessaging.Aps{Sound: "default", Badge: ptr(1)},
        },
    },
    Android: &fbmessaging.AndroidConfig{
        Priority: "high",  // ensures wake-up on doze mode
    },
}

batchResp, err := fcmClient.SendMulticast(ctx, msg)
// ... iterate batchResp.Responses, invalidate failed tokens
```

Token invalidation:

```go
for i, resp := range batchResp.Responses {
    if !resp.Success {
        switch fbmessaging.IsNotRegistered(resp.Error) ||
               fbmessaging.IsInvalidArgument(resp.Error) {
        case true:
            invalidateToken(ctx, tokens[i].ID, "fcm_not_registered")
        }
    }
}
```

### Task 3.3.4 — Firestore writes

```go
func writeFirestore(ctx context.Context, sessionID, status string) error {
    // session_states/{sessionId}
    _, err := firestoreClient.Doc("session_states/"+sessionID).Set(ctx, map[string]any{
        "sessionId":              sessionID,
        "therapistFirebaseUid":   therapistFirebaseUID,
        "status":                 status,
        "progressPercent":        100,
        "updatedAt":              firestore.ServerTimestamp,
    }, firestore.MergeAll)
    if err != nil {
        // Best-effort: log, surface to DLQ for monitoring, but DON'T fail.
        logger.Warn("firestore session_states write failed", "error", err)
        return nil
    }
    return nil
}
```

### Task 3.3.5 — Terraform: Cloud Function deploy

Extend `infra/modules/cloud-functions/main.tf`:

```hcl
resource "google_cloudfunctions2_function" "notification_worker" {
  name        = "notification-worker"
  location    = var.region
  project     = var.project_id
  description = "FCM + Firestore notifier"

  build_config {
    runtime     = "go126"
    entry_point = "ProcessReportGenerated"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.notification_worker_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 5
    min_instance_count    = 0
    available_memory      = "512Mi"
    available_cpu         = "1"
    timeout_seconds       = 60
    service_account_email = var.notification_worker_sa_email

    environment_variables = {
      GCP_PROJECT_ID = var.project_id
    }

    secret_environment_variables {
      key        = "DATABASE_URL"
      project_id = var.project_id
      secret     = var.db_url_secret_id
      version    = "latest"
    }

    vpc_connector                 = var.vpc_connector_id
    vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = var.report_generated_topic
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = var.notification_worker_sa_email
  }
}
```

Add input vars: `notification_worker_sa_email`, `report_generated_topic`.

### Sprint 3.3 Smoke test

```bash
# 1. Manually publish a report.generated message
gcloud pubsub topics publish report.generated \
  --message='{"session_id":"<existing_session_uuid>","report_id":"<existing_report_uuid>"}' \
  --project=superwizor-ai-25ecd

# 2. Watch worker logs — should see "processing report.generated"
gcloud logging read \
  'resource.labels.service_name="notification-worker"' \
  --project=superwizor-ai-25ecd --limit=20

# 3. Check Firestore — should have session_states/{sessionId} doc
gcloud firestore documents describe \
  "projects/superwizor-ai-25ecd/databases/(default)/documents/session_states/<session_id>"

# 4. notification_deliveries row exists
psql ... -c "SELECT * FROM notification_deliveries WHERE session_id = '<sessionID>';"
```

---

## Sprint 3.4 — gRPC server: token registration

**Cel:** Flutter wywołuje `RegisterFCMToken` przy każdym logowaniu i refresh'u tokena. Cloud Run service.

### Task 3.4.1 — gRPC implementation

**Plik:** `services/notification-svc/cmd/server/main.go` + `internal/adapters/grpc/server.go`

Wzór: `services/clinical-svc/cmd/server/main.go`. Resolve user_id z gRPC metadata (Firebase UID lookup w `users` table — przez identity-svc albo bezpośrednio przez sqlc).

```go
func (s *Server) RegisterFCMToken(ctx context.Context, req *notificationv1.RegisterFCMTokenRequest) (*notificationv1.RegisterFCMTokenResponse, error) {
    userID, err := userIDFromContext(ctx)  // resolves Firebase UID → users.id
    if err != nil { return nil, status.Error(codes.Unauthenticated, "no user") }

    if req.Token == "" {
        return nil, status.Error(codes.InvalidArgument, "token required")
    }

    // Idempotent UPSERT — same (user_id, token) returns existing row.
    row, err := s.queries.UpsertFCMToken(ctx, db.UpsertFCMTokenParams{
        UserID:      userID,
        Token:       req.Token,
        Platform:    req.Platform.String(),  // strip enum prefix
        AppVersion:  req.AppVersion,
        DeviceModel: req.DeviceModel,
        Locale:      req.Locale,
    })
    if err != nil {
        slog.Error("upsert fcm token", "user_id", userID, "error", err)
        return nil, status.Error(codes.Internal, err.Error())
    }

    return &notificationv1.RegisterFCMTokenResponse{
        TokenId:           row.ID.String(),
        AlreadyRegistered: row.WasExisting,  // sqlc returns this
    }, nil
}
```

### Task 3.4.2 — sqlc queries

**Plik:** `services/notification-svc/sqlc.yaml` + `queries/notifications.sql`

```sql
-- name: UpsertFCMToken :one
INSERT INTO fcm_tokens (user_id, token, platform, app_version, device_model, locale, last_used_at)
VALUES ($1, $2, $3, $4, $5, $6, now())
ON CONFLICT (user_id, token) WHERE invalidated_at IS NULL
DO UPDATE SET
    last_used_at = now(),
    app_version  = EXCLUDED.app_version,
    device_model = EXCLUDED.device_model,
    locale       = EXCLUDED.locale
RETURNING id, (xmax = 0) AS was_existing;

-- name: ListActiveFCMTokensByUser :many
SELECT id, token, locale, platform
FROM fcm_tokens
WHERE user_id = $1 AND invalidated_at IS NULL
ORDER BY last_used_at DESC
LIMIT 10;  -- protect against runaway accumulation

-- name: InvalidateFCMToken :exec
UPDATE fcm_tokens
SET invalidated_at = now(), invalidated_reason = $2
WHERE id = $1;

-- name: RemoveFCMToken :exec
UPDATE fcm_tokens
SET invalidated_at = now(), invalidated_reason = 'user_logout'
WHERE user_id = $1 AND token = $2 AND invalidated_at IS NULL;

-- name: GetUnreadNotificationCount :one
-- Note: count via Firestore is preferable (Flutter already subscribed),
-- but this gives a backend-side audit number for debugging.
SELECT COUNT(*) FROM notification_deliveries
WHERE user_id = $1 AND status = 'sent'
  AND id NOT IN (
    SELECT delivery_id FROM notification_reads WHERE user_id = $1
  );
-- (notification_reads table optional; could just query Firestore directly)
```

### Task 3.4.3 — Dockerfile + CI deploy

Wzór: `services/clinical-svc/Dockerfile` (copy services/ + pkg/ + gen/, GOWORK=on).

CI workflow (`.github/workflows/ci.yml`) — add Build + Deploy steps following the pattern set by clinical-svc / ingestion-svc:

```yaml
- name: Build and Push Notification image
  run: |
    IMAGE_PATH="${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/superwizor-notification"
    docker build -t $IMAGE_PATH:${{ github.sha }} -t $IMAGE_PATH:latest -f services/notification-svc/Dockerfile .
    docker push -a $IMAGE_PATH

- name: Deploy Notification to Cloud Run
  run: |
    IMAGE_PATH="${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/superwizor-notification"
    gcloud run deploy notification-svc \
      --image $IMAGE_PATH:${{ github.sha }} \
      --region ${{ env.REGION }} \
      --platform managed \
      --allow-unauthenticated \
      --service-account=notification-svc@${{ env.PROJECT_ID }}.iam.gserviceaccount.com \
      --vpc-connector swvpc-connector \
      --set-secrets="DATABASE_URL=postgres-database-url:latest" \
      --set-env-vars="GCP_PROJECT_ID=${{ env.PROJECT_ID }},VERSION=${{ github.sha }}"
    gcloud run services add-iam-policy-binding notification-svc \
      --region=${{ env.REGION }} --project=${{ env.PROJECT_ID }} \
      --member=allUsers --role=roles/run.invoker
```

### Sprint 3.4 Smoke test

```bash
TOKEN=$(./tests/e2e/get_test_user.sh | head -1)  # mints Firebase ID token
NOTIFICATION_URL=$(gcloud run services describe notification-svc \
  --region=europe-central2 --project=superwizor-ai-25ecd --format='value(status.url)')

# 1. Register a fake token
grpcurl -H "authorization: Bearer ${TOKEN}" \
  -d '{"token":"fake_test_token_xyz","platform":"PLATFORM_IOS","app_version":"0.1.0"}' \
  ${NOTIFICATION_URL#https://}:443 \
  notification.v1.NotificationService/RegisterFCMToken

# 2. Verify in PG
psql ... -c "SELECT user_id, platform FROM fcm_tokens WHERE token = 'fake_test_token_xyz';"

# 3. Re-register same token — should return already_registered=true
grpcurl ... RegisterFCMToken
# expected: {"tokenId":"<same uuid>","alreadyRegistered":true}

# 4. Remove it
grpcurl ... -d '{"token":"fake_test_token_xyz"}' ... RemoveFCMToken
psql ... -c "SELECT invalidated_at FROM fcm_tokens WHERE token='fake_test_token_xyz';"
# invalidated_at should be set
```

---

## Sprint 3.5 — Pipeline integration: status events

**Cel:** rozszerzyć worker o subskrypcję `audio.uploaded` i `transcript.completed`, żeby Firestore odzwierciedlał trzy transitions (uploaded, analyzing, done).

### Task 3.5.1 — Two more entry points + triggers

```go
functions.CloudEvent("ProcessAudioUploaded", ProcessAudioUploaded)
functions.CloudEvent("ProcessTranscriptCompleted", ProcessTranscriptCompleted)
functions.CloudEvent("ProcessReportGenerated", ProcessReportGenerated)  // existing
```

Each handler does:
1. Idempotency check (`{session_id}:{event_type}`).
2. Update Firestore `session_states/{sessionId}.status`.
3. ACK.

`audio.uploaded` and `transcript.completed` do **not** send FCM — only the final `report.generated` does. Status updates are silent (Flutter sees them via Firestore listener).

### Task 3.5.2 — Three Cloud Function resources, one source bundle

Add three `google_cloudfunctions2_function` resources or ideally one with multiple Eventarc triggers. Currently Cloud Functions Gen2 = 1 function per Eventarc trigger, so three resources.

Naming:
- `notification-worker-on-uploaded`
- `notification-worker-on-transcribed`
- `notification-worker-on-report` (renamed from sprint 3.3)

Each binds its own Eventarc trigger; same source zip. `available_memory = 256Mi` for the simpler ones.

### Sprint 3.5 Smoke test

End-to-end via existing E2E test:

```bash
cd superwizor-backend/tests
go test -tags=e2e -timeout=10m -v ./e2e/... -run TestFullSession_HappyPath
```

While running, watch Firestore:

```bash
# In a second terminal:
gcloud firestore documents list \
  --project=superwizor-ai-25ecd \
  --filter="createTime>=$(date -u -v-5M +%Y-%m-%dT%H:%M:%S)Z"
```

Status should progress `uploaded → analyzing → done` w real-time.

---

## Sprint 3.6 — E2E test extension + observability

**Cel:** confirm full path. Plus podstawowe alerty.

### Task 3.6.1 — Assert Firestore in E2E test

Extend `superwizor-backend/tests/e2e/full_session_test.go` after Step 7 polling:

```go
// Step 8.5: assert Firestore session_state document exists with status="done"
firestoreClient, err := firestore.NewClient(ctx, cfg.projectID)
require.NoError(t, err)

doc, err := firestoreClient.
    Doc("session_states/" + complete.SessionId).
    Get(ctx)
require.NoError(t, err, "Firestore session_states doc missing")

data := doc.Data()
assert.Equal(t, "done", data["status"])
assert.Equal(t, firebaseUID, data["therapistFirebaseUid"])

// Cleanup at the end
t.Cleanup(func() {
    firestoreClient.Doc("session_states/" + complete.SessionId).Delete(context.Background())
})
```

### Task 3.6.2 — Minimal alerting

Cloud Monitoring alerting policies (terraform):

| Metric | Threshold | Why |
|---|---|---|
| `firestore-sync.dlq` undelivered messages | > 0 for 10 min | Firestore writes failing — best-effort but worth knowing |
| `notification-worker-on-report` error rate | > 10% for 15 min | FCM API issues or our bug |
| Cloud Run `notification-svc` error rate | > 5% for 15 min | gRPC handler bugs |

### Sprint 3.6 Definition of Done

- [ ] E2E test passes Step 8.5 (Firestore assertion).
- [ ] All three alerting policies provisioned.
- [ ] Cloud Logging dashboard shows: per-status timeline of recent sessions, FCM success rate, token invalidation rate.
- [ ] Tag `v0.4.0-dev.1`.

---

## Troubleshooting cookbook

### Problem 1: FCM returns `NotRegistered` for every token

**Wskaźnik:** `notification_deliveries.status = 'token_invalid'` for all rows in last hour.

**Najczęstsze:**

- Firebase project ID mismatch — Flutter app and `notification-svc` muszą używać tego samego project ID.
- App został odinstalowany na wszystkich urządzeniach testowych — re-install + ponowny `RegisterFCMToken`.

### Problem 2: Firestore listener w Flutter nie dostaje update'ów

**Wskaźnik:** Flutter logs "stream connected" ale `data == null` po `report.generated`.

**Najczęstsze:**

- Firestore rules blokują read — sprawdź `request.auth.uid == resource.data.therapistFirebaseUid`. Jeśli backend zapisał inne pole jak `therapistId` (UUID z PG), Flutter (z Firebase UID) nie dopasuje.
- W `session_states` doc piszemy `therapistFirebaseUid` (Firebase UID, nie users.id z PG). Common bug.

### Problem 3: Push przychodzi 2× per session

**Wskaźnik:** Flutter dostaje notyfikację "Raport gotowy" dwa razy.

**Najczęstsze:**

- Idempotency key collision — różne typy eventów dla tej samej sesji (np. `report_ready` i `session_done`). Sprawdź `notification_deliveries.idempotency_key`.
- Pub/Sub redelivery + brak idempotency check — sprawdź czy worker robi `INSERT ... ON CONFLICT DO NOTHING` przed wysyłką FCM.

### Problem 4: Worker crashes przy starcie

**Wskaźnik:** Cloud Functions logs "Permission denied on resource".

**Najczęstsze:**

- SA brak `roles/datastore.user` — Firestore write wraca 7 PERMISSION_DENIED.
- SA brak `roles/firebasecloudmessaging.messagesSender` — FCM send wraca 403.
- `gcloud projects get-iam-policy` powinno wylistować obie role na `notification-svc@` SA.

---

## Pre-Faza 4 checklist

### Backend

- [ ] `notification-svc` Cloud Run service deployed, `--allow-unauthenticated`, public_invoker IAM via terraform
- [ ] `notification-worker-on-{uploaded,transcribed,report}` Cloud Functions Gen2 deployed via terraform
- [ ] `notification-svc@` SA z 4 IAM bindings (sql, secret, datastore, fcm)
- [ ] DLQ topic `firestore-sync.dlq` istnieje, ma reader subscription
- [ ] Migration 000009 zaaplikowana

### Frontend

- [ ] Flutter rejestruje FCM token przy logowaniu (FlutterFire `getToken()`)
- [ ] Flutter subskrybuje `session_states/{sessionId}` na ekranie sesji
- [ ] Flutter pokazuje toast/notification gdy push przychodzi w foreground
- [ ] Token rotation handler — Flutter łapie `onTokenRefresh` i wywołuje `RegisterFCMToken`

### Observability

- [ ] Alerting policies wymienione w 3.6.2
- [ ] Cloud Logging dashboard "Notification pipeline"
- [ ] Audit query: średni czas od `report.generated` ACK → FCM `messageId` returned (target: < 2s)

### Security

- [ ] Firestore rules wdrożone (NIE placeholder); `firebase deploy --only firestore:rules` przed 2026-05-28
- [ ] Smoke test: anonymous user nie może czytać `session_states` (unauthenticated 403)
- [ ] Smoke test: User A nie może czytać `session_states/{sessionId_userB}` (different therapistFirebaseUid → 403)

### Tagging

- [ ] `git tag -a v0.4.0-dev.1 -F <message>` — Phase 3 dev milestone
- [ ] `gh release create v0.4.0-dev.1 --prerelease --generate-notes`

---

## Sources

- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §4.2.7 (notification-svc spec), §6 (Firestore as sync layer).
- `docs/03_DATA_MODEL.md` §1.1 (no domain ownership listed for notifications — implicitly here).
- `docs/agents/00_GLOBAL_CONTEXT.md` (P1, P4, encryption pattern, Pub/Sub conventions).
- `docs/agents/05_ai-pipeline-svc.md` (worker pattern reference).
- Live state: `infra/modules/pubsub/main.tf` (existing topics: `report.generated` already there); `firestore.rules` (placeholder, expires 2026-05-28).
