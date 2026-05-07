# billing-svc

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.

## Mission

In **Phase 2 — a stub**. Three gRPC methods that always return "allowed" / no-op so clinical-svc can wire its quota gate without waiting for full Stripe integration. In **Phase 3** this becomes the real billing service: subscription state, Stripe webhook listener, monthly usage counter resets, idempotent quota debiting.

## Status (2026-05-07)

- **Stub** running on Cloud Run, internal-only (no public IAM binding).
- Returns `Allowed=true`, `Remaining=999`, `Limit=1000` for every `CheckQuota`.
- `IncrementUsage` is a no-op.
- `GetSubscription` returns hardcoded `{plan_tier: "PRO", status: "active"}`.

> Source: `docs/06_FAZA_2_INGESTION_AI.md` Sprint 2.3 (ADR-IMPL-005, lines 178–183) — "billing-svc as stub" decision and stub spec.

## Repo paths

```
services/billing-svc/
├── cmd/server/main.go               # entry point (Cloud Run)
├── go.mod / go.sum                  # only depends on gen/go (replace + require)
├── Dockerfile                       # GOWORK=off; minimal — no pkg/* deps
└── internal/adapters/grpc/server.go # the stub: 3 methods, ~30 lines

proto/billing/v1/billing.proto       # canonical contract
gen/go/billing/v1/                   # generated Go stubs
```

**Note:** there's NO `pkg/*` dependency for billing-svc today. Its `go.mod` only `replace`s `gen/go`. If you add `pkg/cryptobox` or similar, update the Dockerfile to copy `pkg/` (and either drop `GOWORK=off` or keep it but adjust replaces).

## gRPC API

```protobuf
service BillingService {
  rpc CheckQuota(CheckQuotaRequest) returns (QuotaDecision);
  rpc IncrementUsage(IncrementUsageRequest) returns (google.protobuf.Empty);
  rpc GetSubscription(GetSubscriptionRequest) returns (Subscription);
}

message CheckQuotaRequest {
  string organization_id = 1;
  string therapist_id = 2;
  string usage_type = 3;       // 'session_analysis', 'audio_minutes'
  int32 amount = 4;
}
message QuotaDecision {
  bool allowed = 1;
  string reason = 2;
  int32 remaining = 3;
  int32 limit = 4;
}
```

> **Common naming gotcha:** the RESPONSE type is `QuotaDecision` (NOT `CheckQuotaResponse`). The request field is `usage_type` (NOT `quota_type`). An older stub used the wrong names and broke CI lint — see commits `df41d59` / `97f58fd`.

## Tables (Phase 3 spec, NOT yet built)

| Table | Purpose |
|---|---|
| `subscription_plans` | Static catalog (SOLO/PRO/CLINIC) |
| `subscriptions` | Per-organization current plan + status |
| `payment_events` | Stripe/P24 webhook stream (idempotent: `provider_event_id UNIQUE`) |
| `usage_counters` | Monthly counter per org per usage type |
| `usage_events` | `session_id UNIQUE` for idempotent debiting (architecture §4.2.2) |

> Invoicing itself is delegated to **external SaaS** (Fakturownia / iFirma) per ADR-DM-016. Don't try to render PDFs here.

## Auth model

**Inbound:** Cloud Run IAM, no `allUsers`. Bound only to the calling service's runtime SA (today: default compute SA, used by clinical-svc). The ID token clinical-svc sends gets validated by Cloud Run frontend before reaching the stub container.

**Outbound (Phase 3):**
- Stripe API (HTTPS).
- Cloud SQL.
- KMS (no PHI in billing, but Stripe customer IDs may warrant CMEK).
- Pub/Sub (publish `subscription.changed` etc.).

## Key dependencies

- **Phase 2 stub:** zero. No DB, no other services. Pure stub.
- **Phase 3:** Stripe, Cloud SQL, identity-svc (resolve org from user).

## Constraining ADRs

| ADR | What it forces |
|---|---|
| **ADR-IMPL-005** | Phase 2 = stub. Don't add real logic until Phase 3 is scheduled. |
| **ADR-DM-016** | Invoicing is OUT of scope — delegate to external SaaS. Only `payment_events` lives here. |
| Architecture §4.2.2 | Idempotent quota debiting via `usage_events.session_id UNIQUE` + `INSERT ... ON CONFLICT DO NOTHING`. Don't roll your own dedupe scheme. |

## GCP resources

| Resource | Notes |
|---|---|
| Service Account | currently default compute SA; should be dedicated `billing-svc@${PROJECT}` in Phase 3 |
| Cloud Run `billing-svc` | NO `--allow-unauthenticated`; VPC connector; `--use-http2` for gRPC |
| IAM bindings | runtime SA of clinical-svc has `roles/run.invoker` here |
| Pub/Sub | not yet wired |
| Stripe webhook URL | will be a public Cloud Run endpoint at `/stripe/webhook` (Phase 3) |

## Local dev loop

The stub has no DB or external deps. Just:
```bash
cd services/billing-svc
buf generate ../../proto
go test ./...
golangci-lint run ./...
go run ./cmd/server   # listens on :8080
```

For client testing from clinical-svc, use grpcurl:
```bash
grpcurl -plaintext localhost:8080 list
grpcurl -plaintext -d '{"organization_id":"x","therapist_id":"y","usage_type":"session_analysis","amount":1}' \
  localhost:8080 billing.v1.BillingService/CheckQuota
```

## Iteration guardrails

**Safe to change in Phase 2:**
- Tweak the stub return values.
- Add new RPC methods (mark them clearly as STUB).
- Wire structured logging.

**Don't add in Phase 2:**
- DB tables (no `subscription_plans` etc. yet — wait for Phase 3 design).
- Stripe SDK.
- KMS / encryption.
- Real subscription state.

**Phase 3 (when scheduled):**
- New migrations for the billing tables.
- Stripe webhook receiver as a separate Cloud Run service OR a `/stripe/webhook` HTTP path on this one (decide first).
- Idempotent `usage_events` table.
- Cloud Scheduler job for monthly counter reset.
- Replace stub with real `CheckQuota` reading `subscriptions.sessions_per_month_limit - usage_counters.sessions_used_this_period`.

## Common gotchas

- **The Cloud Run service exists but has no auto-deploy in CI** — until commit `ce7f414` added the deploy step. Verify CI deploys this service on every push to main.
- **Image must be HTTP/2-capable**: deploy with `--use-http2` (already in CI). Without it, gRPC clients fail with cryptic stream errors.
- **`go.mod` requires explicit `require` line** for `gen/go` because the Dockerfile uses `GOWORK=off` (single-module mode). The `replace` alone is insufficient — see commit `ce11f31`.
- **Don't add `pkg/*` deps casually** — the Dockerfile doesn't copy `pkg/`. Adding e.g. `pkg/cryptobox` requires updating both `go.mod` and `Dockerfile`.

## Source-doc pointers

- `docs/06_FAZA_2_INGESTION_AI.md` Sprint 2.3 (lines 1486–1660) — full stub spec.
- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §4.2.2 (lines 401–414) — Phase 3 responsibility.
- `docs/03_DATA_MODEL.md` §4.4 (lines 1201–1384) — Phase 3 DDL.
- ADR-IMPL-005 (`docs/06_*.md` lines 178–183) — why stub.
- ADR-DM-016 (`docs/03_*.md` §1.2) — invoicing is external.
