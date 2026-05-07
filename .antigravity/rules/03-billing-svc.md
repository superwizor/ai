---
description: Loads when editing billing-svc (Phase 2 stub; full Stripe in Phase 3).
globs:
  - "superwizor-backend/services/billing-svc/**"
  - "superwizor-backend/proto/billing/**"
  - "superwizor-backend/gen/go/billing/**"
  - "superwizor-backend/migrations/*billing*.sql"
alwaysApply: false
---

# billing-svc

**Read [`docs/agents/03_billing-svc.md`](../../docs/agents/03_billing-svc.md) before editing.**

Quick orientation:

- **Phase 2 = stub.** Three RPCs that return "allowed"/no-op (ADR-IMPL-005). Don't add real billing logic until Phase 3 is scheduled.
- **Naming gotcha:** response type is `QuotaDecision` (NOT `CheckQuotaResponse`); request field is `usage_type` (NOT `quota_type`). An older stub had wrong names and broke CI.
- **Internal-only service** — no `allUsers` IAM binding. Only callers' runtime SAs are bound.
- **HTTP/2** required for native gRPC: `--use-http2` flag in CI deploy.
- **`go.mod` requires explicit `require`** for `gen/go` because Dockerfile uses `GOWORK=off`.
- **No `pkg/*` deps today.** If you add any (e.g., `cryptobox`), update Dockerfile to copy `pkg/`.
- **ADR-DM-016:** invoicing (PDF, KSeF, VAT) is delegated to external SaaS. Only `payment_events` lives here in Phase 3.
