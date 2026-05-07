# identity-svc

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.

## Mission

Validate Firebase ID tokens, manage `users`/`organizations` CRUD, and answer permission questions ("can therapist X read patient file Y?") for every other backend service. This is the **only** service that talks to Firebase Auth.

## Status (2026-05-07)

- **Phase 1 — DONE.** Deployed at `https://identity-svc-...run.app`. Firebase token validation + user/org CRUD live.
- Permission cache (Redis) — **not yet implemented** (spec only).
- Service-to-service token issuance — **not yet implemented** (spec only). Today, services pass the original Firebase token through gRPC metadata.

## Repo paths

```
services/identity-svc/
├── cmd/server/main.go               # entry point (Cloud Run)
├── go.mod / go.sum
├── sqlc.yaml                        # generates internal/adapters/postgres/db/
├── Dockerfile                       # builder + distroless runtime
└── internal/
    ├── adapters/
    │   ├── firebase/                # Firebase Admin SDK client + token verifier
    │   ├── grpc/                    # gRPC server: ValidateToken, GetUser, UpdateProfile, CheckPermission
    │   └── postgres/db/             # sqlc-generated queries
    └── domain/                      # business rules (no external deps)

proto/identity/v1/identity.proto     # canonical contract
gen/go/identity/v1/                  # generated Go stubs (committed)
```

## gRPC API

```protobuf
service IdentityService {
  rpc ValidateToken(ValidateTokenRequest) returns (UserContext);     // hot path
  rpc GetUser(GetUserRequest) returns (User);
  rpc UpdateProfile(UpdateProfileRequest) returns (User);
  rpc CheckPermission(CheckPermissionRequest) returns (PermissionDecision);
}
```

`UserContext` is propagated by callers in gRPC metadata (`x-superwizor-user-id`, `x-superwizor-org-id`, `x-superwizor-role`) on every downstream call.

> Source: `docs/05_FAZA_1_TOZSAMOSC_DANE.md` Sprint 1.2 (lines 803–2056) — full task-by-task spec.

## Tables owned (Identity domain)

| Table | Purpose |
|---|---|
| `users` | UUID v4 PK, `firebase_uid UNIQUE NOT NULL`, `email`, `role` enum (`THERAPIST`/`PATIENT`), `organization_id` FK, `deleted_at` (soft delete) |
| `organizations` | Therapy practices; `subscription_id` FK to billing |
| `addresses` | Postal addresses (1:1 with `organizations`) |
| `user_roles` | Reserved for future multi-role support; today `users.role` enum is the truth |

> Source: `docs/03_DATA_MODEL.md` §4.3 (lines 1057–1200).

## Auth model

**Inbound (from Flutter):**
- Cloud Run IAM: `allUsers → roles/run.invoker` (public). Flutter sends Firebase ID token in `authorization: Bearer <token>`.
- App layer: `firebase.Auth.VerifyIDToken(ctx, token)` validates audience = Firebase project ID, signature, expiry, revocation.
- On success, `users` row is fetched/created by `firebase_uid`.

**Inbound (from other services):**
- Today: services forward the Flutter Firebase token. identity-svc validates it the same way.
- Spec (not implemented): identity-svc issues short-lived service-to-service JWTs.

**Outbound:**
- Firebase Admin SDK (HTTPS to Firebase auth endpoints; auto-auth via Cloud Run runtime SA).
- Cloud SQL via VPC connector.
- Secret Manager for `postgres-database-url`.

## Key dependencies (upstream)

- **Firebase Auth** — IdP for end users.
- **Cloud SQL `superwizor-db-bc4c27de`** — `users`, `organizations`, `addresses`, `user_roles`.
- **Secret Manager** — `postgres-database-url` (DSN).
- **No service dependencies** — identity-svc is the bottom of the dep tree.

## Key consumers (downstream)

Every other service. clinical-svc, ingestion-svc, billing-svc all call `ValidateToken` and `CheckPermission` at request entry.

## Constraining ADRs

| ADR | What it forces |
|---|---|
| ADR-DM-001 | UUID v4 PKs |
| ADR-DM-003 | Soft delete via `deleted_at` |
| ADR-DM-004 | Two roles only: `THERAPIST`, `PATIENT`. Don't add new roles without a schema migration + RBAC review |
| ADR-DM-005 | Therapist↔Patient as M:N via `therapist_patient_relations` (in clinical-svc, not here) |
| Firebase as IdP (architecture §4.2.1) | Don't roll your own auth. Don't store passwords. |

## GCP resources

| Resource | Where defined | Notes |
|---|---|---|
| Service Account `identity-svc@${PROJECT}.iam.gserviceaccount.com` | terraform `service-accounts.tf` | runtime identity |
| Cloud Run service `identity-svc` | CI workflow (`.github/workflows/ci.yml`) | `--allow-unauthenticated` + VPC connector |
| IAM bindings | terraform | `roles/cloudsql.client`, `roles/secretmanager.secretAccessor`, Firebase admin |
| Secret access | terraform | `postgres-database-url` reader |

## Local dev loop

```bash
cd services/identity-svc

# Generate sqlc + proto (if dirty)
sqlc generate
buf generate ../../proto

# Lint + test
go test ./...
golangci-lint run ./...

# Run locally with cloud-sql-proxy
cloud-sql-proxy superwizor-ai-25ecd:europe-central2:superwizor-db-bc4c27de --port=15432 &
DATABASE_URL="postgres://superwizor_app:$PASSWORD@127.0.0.1:15432/superwizor?sslmode=disable" \
  GCP_PROJECT_ID=superwizor-ai-25ecd \
  go run ./cmd/server
```

## Iteration guardrails

**Safe to change:**
- Add new gRPC methods (extend proto, regen, implement in `internal/adapters/grpc/`).
- Add new sqlc queries.
- Refactor `internal/domain/` business rules.
- Tweak Firebase claim parsing.

**Careful — touches contracts:**
- Renaming/removing existing gRPC methods → all clients (clinical-svc, Flutter app) need coordinated update.
- Changing `UserContext` fields → all downstream services that read gRPC metadata break.
- `users.role` enum changes → DB migration + RBAC review.

**Don't touch without architecture review:**
- The "service is bottom of dep tree" property — don't add a dependency on clinical-svc or any peer.
- Hard-code roles other than THERAPIST/PATIENT — see ADR-DM-004.
- Bypass Firebase Auth (e.g., adding password auth here) — see architecture §4.2.1.

## Common gotchas

- **`firebase_uid` not set** on User insert → all subsequent `ValidateToken` calls fail because lookup is by `firebase_uid`. Always populate from token claims.
- **`audience` claim** must equal the Firebase project ID (`superwizor-ai-25ecd`), not a custom string. Set in Flutter's Firebase init, not here.
- **Soft-deleted users** still exist in `users` table; queries must filter `WHERE deleted_at IS NULL` unless you specifically need the audit trail.
- **Cloud Run cold start + Firebase Admin SDK init** can add ~2s. Use min-instances=1 if latency-sensitive.

## Source-doc pointers

- `docs/05_FAZA_1_TOZSAMOSC_DANE.md` lines 803–2056 — full Phase 1 task list (proto def, sqlc, Firebase adapter, gRPC handler, deploy, smoke tests, troubleshooting).
- `docs/03_DATA_MODEL.md` §4.3 (lines 1057–1200) — DDL.
- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §4.2.1 (lines 359–400) — service responsibility.
