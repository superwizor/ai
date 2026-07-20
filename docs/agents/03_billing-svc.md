---
type: Backend Service Specification
title: "billing-svc"
description: "Quota gateway for the platform. Owns the per-organization token-bucket model (tokensperperiod, tokensused, tokensreserved), the two-phase debit (ReserveCredi..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/agents/03_billing-svc.md
tags: [svc, billing, agents]
timestamp: 2026-05-29T15:03:30+02:00
---

# billing-svc

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.
> Canonical design: [`docs/17_BILLING_SERVICE_PHASE_3.md`](../17_BILLING_SERVICE_PHASE_3.md) (with Phase C supersedes — see banner).
> Current end-to-end flow: [`docs/18_BILLING_IMPLEMENTATION_FLOW.md`](../18_BILLING_IMPLEMENTATION_FLOW.md) v2.0.

## Mission

Quota gateway for the platform. Owns the per-organization token-bucket model (`tokens_per_period`, `tokens_used`, `tokens_reserved`), the two-phase debit (`ReserveCredit` → `CommitUsage` / `ReleaseCredit`), Trial provisioning on signup, period rollover crons, and (eventually) Stripe webhook ingestion. Returns a fully-populated `Subscription` proto on every state-mutating RPC so callers can update their local caches without a separate read.

## Status (2026-05-27, Phase C deployed)

- Live on Cloud Run as `billing-svc` (revision `00067-kr4` at time of writing).
- 4 + 1 gRPC methods: `ReserveCredit`, `CommitUsage`, `ReleaseCredit`, `CheckQuota`, `GetSubscription` (the last is what `clinical-svc.GetMyBillingState` proxies).
- All state-mutating RPCs return `state_after Subscription` (Phase A, commit `8774f17`).
- Outbox pattern + Pub/Sub `billing.outbox` + Firestore mirror + `notification-worker-on-billing` Cloud Function were **removed in Phase C** (commit `634d2f9`). Quota state propagates only via direct RPCs now.
- 3 admin HTTP endpoints for Cloud Scheduler crons (reservation-expiry / manual-period-renewal / safety-check).
- Stripe webhook endpoint exists as a stub (`/stripe/webhook`); signature verification + real handler pending.

## Repo paths

```
services/billing-svc/
├── cmd/server/main.go                          # h2c mixed (gRPC + HTTP) listener
├── go.mod / go.sum                             # replaces gen/go
├── Dockerfile                                  # GOWORK=off; minimal
├── sqlc.yaml                                   # schema from ../../migrations
└── internal/
    ├── adapters/
    │   ├── grpc/
    │   │   ├── server.go                       # 5 RPCs + helpers (buildSubscriptionProto)
    │   │   ├── server_test.go                  # unit tests with fakeQuerier
    │   │   └── testdoubles_test.go             # nil-embed Querier pattern
    │   ├── http/
    │   │   ├── admin_handler.go                # /admin/reservation-expiry, /admin/manual-period-renewal, /admin/safety-check
    │   │   └── stripe_stub.go                  # /stripe/webhook (stub)
    │   └── postgres/
    │       ├── db/                             # sqlc-generated (gitignored, regen via `sqlc generate`)
    │       └── queries/*.sql                   # 17 .sql files driving sqlc
    └── domain/tokens/
        └── tokens.go                           # max(1, ceil((duration-180)/3600))

proto/billing/v1/billing.proto                  # canonical contract (Phase A schema)
gen/go/billing/v1/                              # generated Go stubs

migrations/
├── 000027_billing_phase3_types.up.sql          # plan_tier, subscription_status, reservation_status, usage_type enums
├── 000028_billing_phase3_tables.up.sql         # subscriptions, usage_counters, pending_reservations, usage_events, payment_events
├── 000029_billing_phase3_seed_plans.up.sql     # SOLO/PRO/CLINIC × MONTHLY/ANNUAL
├── 000030_billing_phase3_seed_staging_subscription.up.sql
├── 000031_outbox_events.up.sql                 # (table dropped by 000034 — DDL retained for historical record)
├── 000032_trial_plan.up.sql                    # ALTER TYPE plan_tier ADD VALUE 'TRIAL'
├── 000033_trial_plan_seed.up.sql               # INSERT subscription_plans TRIAL MONTHLY 3 tokens
└── 000034_drop_outbox_events.up.sql            # one-way Phase C cleanup
```

## gRPC API

```protobuf
service BillingService {
  rpc ReserveCredit(ReserveCreditRequest) returns (Reservation);          // pre-charge for upload
  rpc CommitUsage(CommitUsageRequest) returns (UsageCommit);              // post-STT, consume tokens
  rpc ReleaseCredit(ReleaseCreditRequest) returns (google.protobuf.Empty);// undo reservation on failure
  rpc CheckQuota(CheckQuotaRequest) returns (QuotaDecision);              // read-only check
  rpc GetSubscription(GetSubscriptionRequest) returns (Subscription);     // canonical state snapshot
}

message Subscription {
  string subscription_id = 1;
  string organization_id = 2;
  string plan_tier = 3;                    // SOLO|PRO|CLINIC|TRIAL
  string status = 4;                       // ACTIVE|PAST_DUE|TRIALING|CANCELED
  int32 tokens_per_period = 5;
  int32 tokens_used_this_period = 6;
  int32 tokens_reserved_this_period = 7;
  google.protobuf.Timestamp current_period_start = 8;
  google.protobuf.Timestamp current_period_end = 9;
  string billing_source = 10;              // STRIPE|MANUAL
  string plan_cycle = 11;                  // MONTHLY|ANNUAL (Phase A)
  int32 tokens_remaining = 12;             // limit - used - reserved (Phase A)
}

message Reservation {
  string reservation_id = 1;
  string session_id = 2;
  int32 tokens_reserved = 3;
  google.protobuf.Timestamp expires_at = 4;
  Subscription state_after = 5;            // post-mutation snapshot (Phase A)
}

message UsageCommit {
  int32 tokens_consumed = 1;
  int32 remaining_tokens = 2;
  int32 limit_tokens = 3;
  Subscription state_after = 4;            // post-mutation snapshot (Phase A)
}
```

`state_after` is built by `buildSubscriptionProto(subFields, counter)` and embedded on **every** success path (including idempotent hits — the existing reservation/usage_event row + the current counter snapshot). Empty Subscription is an error signal; the caller must treat it the same as a transport failure.

## Tables (Phase 3 live)

| Table | Key invariants | Notes |
|---|---|---|
| `subscription_plans` | 6 catalogue rows (SOLO/PRO/CLINIC × MONTHLY/ANNUAL) + 1 TRIAL MONTHLY | Partial unique index `(tier, cycle) WHERE active` — see commit `a147726` for ON CONFLICT pitfall |
| `subscriptions` | one ACTIVE/TRIALING/PAST_DUE per org at a time | `billing_source` (STRIPE/MANUAL); Trial subs have MANUAL + period_end=NOW+100yr |
| `usage_counters` | one ACTIVE per subscription per period | `(tokens_used, tokens_reserved, tokens_limit, period_start, period_end)` |
| `pending_reservations` | `UNIQUE(session_id)`; status ACTIVE→COMMITTED/RELEASED/EXPIRED | TTL 4h via expires_at + reservation-expiry cron |
| `usage_events` | `UNIQUE(session_id)`; one commit per session | session_id-keyed idempotency |
| `payment_events` | Stripe/P24 audit log | provider_event_id UNIQUE |

**Removed (Phase C):** `outbox_events` (migration 000034). The `OutboxStatus` enum from migration 000002 stays as a no-op orphan — no readers, no cost to leave.

## Auth model

**Inbound:** Cloud Run IAM, no `allUsers`. Specific service accounts only:
- `ingestion-svc@` and `clinical-svc@` and `stt-worker@` (via finalize) have `roles/run.invoker`.
- `cloud-scheduler-billing@` for the three admin HTTP endpoints (OIDC).

**Outbound:**
- Cloud SQL (pgxpool MaxConns=2 — billing-svc gets a tight budget; see commit `761e2e4`).
- Stripe API (when webhook handler is real).

Both ingestion-svc and clinical-svc construct their billing client via `idtoken.NewTokenSource` with `BILLING_SVC_URL` as the audience. Missing `BILLING_SVC_URL` env disables the billing client (fail-soft for reservation, but ingestion-svc.CreateAudioUpload then can't ReserveCredit which is the whole point — see commit `fe43420` for the CI fix that ensures the env survives redeploys).

## Key dependencies

- Cloud SQL Postgres (DATABASE_URL or DB_USER/PASS/HOST/NAME envs).
- No other gRPC services on the outbound side.
- Phase C removed: Pub/Sub publisher, outbox poller, edge-threshold computer.

## Constraining ADRs

| ADR | What it forces |
|---|---|
| **ADR-DM-017** | Token semantics: `1 token = up to 60 min audio + 180s grace` → `max(1, ceil((duration-180)/3600))`. Single source: `internal/domain/tokens/tokens.go`. |
| **ADR-BL-001** | Two-phase debit (Reserve → Commit / Release) with `pending_reservations` UNIQUE on session_id. |
| **ADR-BL-002** | `payment_events` is the gateway, not a passthrough. Real Stripe wiring still pending. |
| **ADR-BL-004** | Stripe customer IDs are envelope-encrypted (`encrypted_customer_id` + DEK). |
| Architecture §4.2.2 | Idempotency via session_id UNIQUE on usage_events + pending_reservations. ON CONFLICT DO NOTHING + refetch is the pattern. |
| **Phase C plan** (this repo, `feat/billing-svc-refactor`) | No out-of-band fan-out. Client cache is updated via `state_after` on every state-mutating RPC + `GetMyBillingState` on cold start. Don't reintroduce outbox / Pub/Sub for quota events without a fresh design discussion. |

## GCP resources

| Resource | Notes |
|---|---|
| Service Account | `billing-svc@superwizor-ai-25ecd.iam.gserviceaccount.com` |
| Cloud Run `billing-svc` | NO `--allow-unauthenticated`; VPC connector; HTTP/2 via h2c mixed handler |
| Secret Manager | `postgres-database-url` (mounted as DATABASE_URL env) |
| Cloud Scheduler | three jobs in `infra/environments/staging/billing_crons.tf` (5-min reservation expiry, daily 02:00 period renewal, weekly Mon 06:00 safety check) |
| pgxpool | `MaxConns=2` per `services/billing-svc/cmd/server/main.go` — fits the db-f1-micro budget |

## Local dev loop

```bash
cd services/billing-svc
sqlc generate                                    # regen models from ../../migrations
go test ./...
golangci-lint run ./...

# Local server — needs a DATABASE_URL pointing at a real or proxied PG
DATABASE_URL=postgres://app:app@localhost:5432/superwizor go run ./cmd/server

# Smoke test via grpcurl
grpcurl -plaintext localhost:8080 list
grpcurl -plaintext -d '{"organization_id":"<org>"}' \
  localhost:8080 billing.v1.BillingService/GetSubscription
```

For staging:
```bash
TOKEN=$(gcloud auth print-identity-token --audiences=https://billing-svc-e3f32b232q-lm.a.run.app)
grpcurl -H "authorization: Bearer $TOKEN" \
  -d '{"organization_id":"<org>"}' \
  billing-svc-e3f32b232q-lm.a.run.app:443 \
  billing.v1.BillingService/GetSubscription
```

## Iteration guardrails

**Safe:**
- Adjust token arithmetic in `internal/domain/tokens/tokens.go` (with tests).
- Extend `Subscription` proto (additive only — Phase A added `plan_cycle` + `tokens_remaining` this way).
- Add new admin HTTP endpoints behind the same SA gate.
- Adjust pgxpool budget (currently 2; raise carefully — db-f1-micro has 25 total across 7 services).

**Don't:**
- Reintroduce outbox table / Pub/Sub publisher / Firestore mirror writer without a fresh design discussion. Phase C deleted all three for a reason.
- Skip `state_after` on a success response from `ReserveCredit` / `CommitUsage`. The client cache depends on it.
- Bypass the `pg_advisory_xact_lock(subscription_id)` in ReserveCredit/CommitUsage — it's the only thing preventing a race between concurrent uploads on the same org.
- Mutate `usage_counters` outside a `LockActiveCounter FOR UPDATE` — same race concern.

**Phase D (next):**
- Real Stripe webhook signature verification + handler (subscription.created / invoice.paid / customer.subscription.deleted).
- Encrypted customer ID rotation via KMS.

## Browser-direct call pattern (2026-05-29)

The marketing-site `/account/` Subskrypcja card and the `/admin/orgs`
ZMIEŃ PLAN + ZRESETUJ TOKENY dialogs all call billing-svc **directly
from the browser** via `billingClient.<rpc>(...)` over Connect-Web —
not through clinical-svc as a proxy. The earlier proxy hop
(`browser → clinical-svc.GetMyBillingState → billing-svc.GetSubscription`)
was returning `code = Internal desc = stream terminated by RST_STREAM`
intermittently inside Cloud Run; HTTP/2 keepalive on the upstream
client didn't fix it (commits `2260926`, `fb35e43`). Direct-from-browser
matches the Connect-RPC R1 design goal — one h2c endpoint serves
browsers, the iOS app, and server-to-server callers with no protocol
shim. Apply the same pattern to any new browser surface that needs
billing data.

**Auth on the direct path:** `ConnectAuthInterceptor` (added
2026-05-27, commit per task #141) runs in front of every Connect RPC,
calls `identity-svc.ValidateToken` with the browser's
`Authorization: Bearer …` header, and writes
`x-superwizor-role` / `-user-id` / `-organization-id` into the gRPC
IncomingMetadata so the existing admin handlers (`resolveAdminCaller`)
see them. Server-to-server callers (native gRPC) skip this — they
already inject those headers themselves.

**Caller-org guard on `GetSubscription`** (commit `7e4f2d9`, deployed
`billing-svc-00086-vwt`): when `x-superwizor-organization-id` is
present (browser path), the handler requires
`organization_id == req.organization_id` or
`x-superwizor-role == SUPERWIZOR_ADMIN`. Native gRPC callers without
the metadata bypass — the trusted-caller contract is preserved.
Pattern to replicate for any future browser-callable read.

## Connect error translation (2026-05-29, commit `2b7919f`)

Connect-Go does NOT auto-recognise `status.Errorf(codes.X, ...)` from
`google.golang.org/grpc/status` — it sees a plain `error` and wraps
it as `connect.CodeUnknown`. Every browser admin RPC then surfaced as
the generic "Wystąpił nieznany błąd" in the dialog regardless of
whether the real cause was PermissionDenied, FailedPrecondition,
InvalidArgument, or Internal. The new
`ConnectErrorInterceptor` (`internal/adapters/grpc/connect_error_interceptor.go`)
sits LAST in the Connect chain and:

- Passes `*connect.Error` through untouched (handlers that opt into
  the Connect-native shape still work).
- Translates `grpc/status` errors to `connect.Error` via a 1:1
  `grpcCodeToConnectCode` table.
- `slog`s the original error type + procedure path + grpc-code +
  message so any handler-side failure is visible in Cloud Logging
  (previously: zero app log on 500s — the panic-recovery middleware
  didn't fire because handlers returned errors cleanly, just with
  the wrong wire type).

**This bug almost certainly exists in identity-svc and clinical-svc's
Connect chain too** — both use the same `status.Errorf` pattern.
Follow-up: lift the interceptor into `pkg/connectmd/` and add to all
three services. Until then, browser-surfaced errors from those
services are opaque ("Wystąpił nieznany błąd").

## Common gotchas

- **`BILLING_SVC_URL` must be set on every caller (ingestion-svc, clinical-svc, stt-finalize CF).** CI's `--set-env-vars` REPLACES the env block — manually-set values get stripped on the next deploy. Fixed in CI by `fe43420` (clinical-svc + ingestion-svc); stt-finalize covered in `d15f6e7`.
- **h2c mixed handler:** Cloud Run terminates TLS; inside the container traffic is HTTP/2 plaintext. The `mixedHandler` in `cmd/server/main.go` dispatches `Content-Type: application/grpc` to the gRPC server and everything else to the HTTP mux. Don't add a separate listener — Cloud Run is one-port-per-service.
- **Trial signup race:** `identity-svc.CreateUser` for a THERAPIST opens its own tx that INSERTs org + subscription + counter. If you do anything to that flow, the tx wrapper in `services/identity-svc/internal/adapters/grpc/server.go` is the only place — don't smear writes across multiple txs.
- **Partial unique index gotcha on subscription_plans:** `ux_subscription_plans_active` is partial (`WHERE active = TRUE`). `ON CONFLICT` can't reference a partial index — use `INSERT … SELECT … WHERE NOT EXISTS` (see commit `a147726`).
- **`state_after` on idempotent hits:** when `GetReservationBySession` returns an existing reservation, you still need to read the current counter and build `state_after`. Don't return the proto with empty/nil state_after — clients treat it as a transport failure.
- **`audit_events.reason` is the column every admin RPC writes to.** Lives in migration 000036. If it goes missing (fresh DB without the migration applied, or a misapplied rollback), `writeBillingAudit` returns `Internal: audit: ERROR: column "reason" of relation "audit_events" does not exist (SQLSTATE 42703)` and AdminChangePlan / AdminResetTokens both 500. Before deploying any admin-RPC change, `SELECT version FROM schema_migrations` and confirm ≥ 37. Staging drifted on 2026-05-29 (was stuck at 34) — `golang-migrate up` via cloud-sql-proxy applies 035-037 idempotently.

## Source-doc pointers

- `docs/17_BILLING_SERVICE_PHASE_3.md` — canonical design (with Phase C supersedes inline)
- `docs/18_BILLING_IMPLEMENTATION_FLOW.md` v2.0 — end-to-end flow, debugging cheat sheet
- `docs/01_ARCHITEKTURA_TECHNICZNA.md` §4.2.2 — service responsibility
- `docs/02_DATA_MODEL.md` §4.4 — Phase 3 DDL
- ADR-DM-017 — token semantics
- ADR-BL-001/002/004 — billing-specific ADRs
