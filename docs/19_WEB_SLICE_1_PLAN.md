---
type: Technical Design
title: "Slice 1 — Web App backend foundation: detailed plan"
description: "Branch: feat/web-app (at 3e820b4) Parent doc: docs/18WEBAPPDESIGN.md v0.2 (R1–R9) Goal: When this slice closes, the backend exposes everything the Next.js ma..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/19_WEB_SLICE_1_PLAN.md
tags: [ai, analytics, billing, crm, database, frontend, identity, infrastructure, ingestion, notifications, security, testing]
timestamp: 2026-05-27T22:15:06+02:00
---

# Slice 1 — Web App backend foundation: detailed plan

**Branch:** `feat/web-app` (at `3e820b4`)
**Parent doc:** `docs/18_WEB_APP_DESIGN.md` v0.2 (R1–R9)
**Goal:** When this slice closes, the backend exposes everything the Next.js marketing/admin site and the Flutter Web therapist console need. No frontend code yet — that's Slices 2 + 3.
**Definition of done:** All RPCs in the §18 §6.1 list are implemented, tested, deployed to staging, reachable from `curl` over the Connect protocol, and audited (admin mutations). `feat/web-app` is mergeable to `main`.

---

## 0. Decisions locked (2026-05-27)

| # | Decision | Choice | Implication |
|---|---|---|---|
| **D1** | Transactional email provider | **Resend** (`resend.com`) | Go SDK (`github.com/resend/resend-go/v2`) wired into `notification-svc/internal/email/`. Secret `resend-api-key` lands in Secret Manager and the notification-svc Cloud Run env. Custom-domain DKIM/SPF setup deferred to Slice 6 (use Resend's onboarding domain for staging until then). |
| **D2** | `UpdateProfile` evolution | **Extend the existing RPC** | New fields (`avatar_url`, `default_modality_id`, `ui_language`, `timezone`, `billing_address_id`, `has_marketing_consent`) become optional in `UpdateProfileRequest`. Handler uses selective UPDATE so iOS partial submits don't blank columns the client doesn't know about. No new `UpdateMyProfile` RPC. |
| **D3** | TS codegen output | **`gen/ts/`** alongside `gen/go/` | Same `buf generate` call emits both. Next.js + Flutter Web both import from there. The repo-root `gen/` gitignore needs a carve-out so `gen/ts/` is committed. |

Locked in commit (this doc edit, branch `feat/web-app`). If any of these need to change later it's a doc bump + a fresh PR.

---

## 1. Work breakdown (eleven sub-tasks, three waves)

### Wave A — independent, can start in parallel

**1.1 — Migrations (PG schema)**
- `migrations/000035_invitations.up.sql` — CREATE TABLE `invitations` (per §18 §6.2). Includes the partial index `(token_hash) WHERE accepted_at IS NULL` for the AcceptInvitation lookup.
- `migrations/000036_audit_events_reason.up.sql` — `ALTER TABLE audit_events ADD COLUMN reason TEXT`.
- `migrations/000037_user_role_extend.up.sql` — `ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'ORG_ADMIN'; ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'SUPERWIZOR_ADMIN';`. Note: postgres doesn't allow new enum values in a tx with usage, so this is its own migration.
- Matching `.down.sql` stubs (one-way for the enum — comment-only down).
- After migration is in place, **regenerate sqlc** for both `identity-svc` and `billing-svc` so the new types + tables surface in `internal/adapters/postgres/db/`.
- Local verification: `cloud-sql-proxy` + `golang-migrate up` against the staging DB clone.

Owner: backend. ~2h.

**1.2 — Shared `pkg/cors` middleware**
- New module `superwizor-backend/pkg/cors/cors.go`. API: `New(allowedOrigins []string) func(http.Handler) http.Handler`.
- Reads allowed origins + headers from env via `os.Getenv("CORS_ALLOWED_ORIGINS")` (comma-separated). Defaults baked in for staging + localhost.
- Handles preflight `OPTIONS` properly; allows `Authorization`, `Content-Type`, `Connect-Protocol-Version`, `Connect-Timeout-Ms`, `X-Grpc-Web`, `X-User-Agent`.
- Unit tests (table-driven: preflight, simple request, denied origin, wildcard subdomains forbidden).
- Wire into `services/{identity,clinical,billing,ingestion,notification}-svc/cmd/server/main.go` — wrap the `mixedHandler` / HTTP mux.

Owner: backend. ~3h.

**1.3 — `buf.gen.yaml` extended for Connect + TS**
- Add to `superwizor-backend/buf.gen.yaml`:
  - `buf.build/connectrpc/go` plugin → outputs `gen/go/<package>/connect/<service>.connect.go`.
  - `buf.build/bufbuild/es` (TS messages) + `buf.build/connectrpc/es` (TS client) plugins → outputs `gen/ts/...`.
- Run `make proto` (which calls `buf generate proto/`).
- Verify both Go connect packages and TS clients are generated.
- Commit the generated TS to git in `gen/ts/` (gitignored today via global `gen/` ignore — needs adjustment).

Owner: backend. ~2h.

**1.4 — Terraform: dedicated SAs + GCS CORS**
- `infra/environments/staging/service-accounts.tf`:
  - Provision `google_service_account.identity_svc` (`identity-svc@${PROJECT}.iam.gserviceaccount.com`).
  - Provision `google_service_account.clinical_svc` (`clinical-svc@${PROJECT}.iam.gserviceaccount.com`).
  - Grant `roles/cloudsql.client` + `roles/secretmanager.secretAccessor` on `postgres-database-url` for both.
  - Grant `roles/cloudkms.cryptoKeyEncrypterDecrypter` on `app-data-key` for clinical-svc only.
- Update CI workflow `.github/workflows/ci.yml`: `gcloud run deploy clinical-svc` + `identity-svc` use `--service-account=<dedicated SA>` instead of default Compute SA.
- `infra/modules/storage/main.tf`: add CORS rules to `audio-uploads` bucket:
  ```hcl
  cors {
    origin          = ["https://superwizor.ai", "https://app.superwizor.ai", "http://localhost:3000", "http://localhost:8080"]
    method          = ["PUT", "OPTIONS"]
    response_header = ["Content-Type", "x-goog-content-length-range", "x-goog-meta-*"]
    max_age_seconds = 3600
  }
  ```
- `terragrunt plan` from staging → review → `terragrunt apply`.
- Verify Cloud Run revisions cycle onto the new SAs without breaking existing traffic (RPCs from iOS keep working).

Owner: backend + infra. ~3h.

**1.5 — Firebase Console: providers + linking**
- Manual config in Firebase Console (`superwizor-ai-25ecd`):
  - Authentication → Sign-in method → enable Google, Apple, Microsoft.
  - For Apple: create Services ID + Sign-in-with-Apple key in Apple Developer portal (requires paid Apple Developer account; ~15 min).
  - For Microsoft: register a "Web" app in Entra ID; copy app (client) ID + client secret into Firebase Console.
  - Authentication → Settings → enable "Link accounts that use the same email".
  - Add authorized domains: `superwizor.ai`, `app.superwizor.ai` (production), `localhost`.
- Document the steps + screenshots in `docs/agents/01_identity-svc.md`.
- No code change needed here — backend already trusts any provider's verified Firebase ID token.

Owner: human (Dariusz). ~1h once Apple credentials are in hand.

---

### Wave B — needs Wave A to land

**1.6 — Proto additions + handler stubs**

Drop into `proto/identity/v1/identity.proto`:

```protobuf
// === Public (authenticated user) ===
rpc RegisterOrganization(RegisterOrganizationRequest) returns (RegisterOrganizationResponse);
rpc GetMyProfile(google.protobuf.Empty) returns (User);
// UpdateProfile (existing) gets new optional fields per D2; no new RPC.
rpc GetMyOrganization(google.protobuf.Empty) returns (Organization);
rpc UpdateMyOrganization(UpdateMyOrganizationRequest) returns (Organization);

// === Org-admin ===
rpc InviteTherapist(InviteTherapistRequest) returns (Invitation);
rpc AcceptInvitation(AcceptInvitationRequest) returns (AcceptInvitationResponse);
rpc ListTherapistsInMyOrg(google.protobuf.Empty) returns (ListTherapistsResponse);
rpc RemoveTherapist(RemoveTherapistRequest) returns (google.protobuf.Empty);

// === Superwizor admin ===
rpc AdminListOrganizations(AdminListOrganizationsRequest) returns (AdminListOrganizationsResponse);
rpc AdminGetOrganization(AdminGetOrganizationRequest) returns (OrganizationDetails);
rpc AdminSetOrganizationStatus(AdminSetOrganizationStatusRequest) returns (google.protobuf.Empty);
rpc AdminUpdateOrganization(AdminUpdateOrganizationRequest) returns (Organization);
rpc AdminListUsers(AdminListUsersRequest) returns (AdminListUsersResponse);
rpc AdminGetUser(AdminGetUserRequest) returns (User);
rpc AdminUpdateUser(AdminUpdateUserRequest) returns (User);
rpc AdminDeleteUser(AdminDeleteUserRequest) returns (google.protobuf.Empty);
```

Drop into `proto/billing/v1/billing.proto`:

```protobuf
rpc AdminResetTokens(AdminResetTokensRequest) returns (Subscription);
rpc AdminChangePlan(AdminChangePlanRequest) returns (Subscription);
```

Plus message definitions for every new request / response. Extend the existing `UpdateProfileRequest` with the new optional fields (D2). Add new `Address` message used by both User + Organization.

After protos land: `buf lint && buf generate`. Commit generated stubs (Go + TS).

Owner: backend. ~3h.

**1.7 — `identity-svc` handler implementations**

Layout — split handlers by domain so PR review stays sane:
- `services/identity-svc/internal/adapters/grpc/org_registration.go` — `RegisterOrganization`. Pattern lifted from the existing trial-provisioning tx in `cmd/server` (commit `0a25ac7`): one Postgres tx that INSERTs `addresses`, `organizations`, `users(role=ORG_ADMIN)`, then calls billing-svc.CreateTrialSubscription (existing flow continues). All wrapped in idempotency-key cache.
- `services/identity-svc/internal/adapters/grpc/invitations.go` — `InviteTherapist`, `AcceptInvitation`, `ListTherapistsInMyOrg`, `RemoveTherapist`. SHA-256 token hashing (per R5, §18 §6.2). Send the actual email via `notification-svc.SendInvitationEmail` (new RPC — see 1.10).
- `services/identity-svc/internal/adapters/grpc/profile.go` — `GetMyProfile`, refactor existing `UpdateProfile` to accept new optional fields. Selective UPDATE (skip zero-valued fields so iOS partial submits stay safe).
- `services/identity-svc/internal/adapters/grpc/org_profile.go` — `GetMyOrganization`, `UpdateMyOrganization`. Org-admin role gate.
- `services/identity-svc/internal/adapters/grpc/admin.go` — eight Admin* RPCs. Strict role gate (`SUPERWIZOR_ADMIN` only). Every mutation calls into a shared `auditAdminAction(ctx, action, resourceID, reason, beforePayload, afterPayload)` helper.
- `services/identity-svc/internal/adapters/grpc/auth_interceptor.go` — extend to read the user's `role` (single column, no JSONB) and stash on ctx for handler-side checks.

Per handler:
- Unit tests using the `fakeQuerier` nil-embed pattern (same as `services/billing-svc/internal/adapters/grpc/testdoubles_test.go`).
- sqlc queries under `services/identity-svc/internal/adapters/postgres/queries/{invitations,organizations,users}.sql` — additive only; nothing existing changes shape.

Idempotency on all mutating RPCs via existing `pkg/idempotency`.

Owner: backend. ~12h total across the five handler files.

**1.8 — `billing-svc` admin handlers**

- `services/billing-svc/internal/adapters/grpc/admin.go` — `AdminResetTokens`, `AdminChangePlan`. Both acquire the existing `pg_advisory_xact_lock` on subscription_id, update counters / plan in a tx, return the fresh `Subscription` proto (same `buildSubscriptionProto` helper as the existing handlers).
- Both write `audit_events` with `reason` (required, validated ≥10 chars) and `actor_type='SUPERWIZOR_ADMIN'`.
- Unit tests with `fakeQuerier`.

Owner: backend. ~4h.

**1.9 — Connect handler registration**

In each service's `cmd/server/main.go`:
```go
identityPath, identityHandler := identityv1connect.NewIdentityServiceHandler(identityServer)
httpMux.Handle(identityPath, identityHandler)
```

The existing `mixedHandler` h2c pattern (used in billing-svc) already routes non-gRPC HTTP to the mux, so Connect handlers slot in.

For `clinical-svc` + `identity-svc` (no mixed handler today), introduce the same pattern. ~30 lines per service.

Smoke verify with `curl`:
```bash
curl -X POST -H 'Content-Type: application/json' -H 'Connect-Protocol-Version: 1' \
  -d '{}' \
  http://localhost:8080/identity.v1.IdentityService/HealthCheck
```

Owner: backend. ~3h.

**1.10 — Email infra in `notification-svc`**

- New module `services/notification-svc/internal/email/`:
  - `sender.go` — interface `Sender { Send(ctx, to, subject, body) error }`.
  - `resend_sender.go` — implementation using Resend's Go SDK (`github.com/resend/resend-go/v2`).
  - `mock_sender.go` — captures into an in-memory slice for tests + local dev (when `RESEND_API_KEY` unset).
- New module `services/notification-svc/internal/i18n/`:
  - `templater.go` — reads `templates/{locale}/<event>.md`, parses frontmatter (`subject: ...`), substitutes `{var}` placeholders, returns `(subject, body)`.
  - `templates/pl/invitation.md` + `templates/en/invitation.md` — the §14.7 schema.
- New RPC on `notification-svc`: `SendInvitationEmail(SendInvitationEmailRequest) returns (Empty)`. Args: `email`, `inviter_first_name`, `org_name`, `accept_url`, `expires_at`, `locale`. Picks the template via `(locale, "invitation")`, substitutes, calls `Sender.Send`.
- Secret: add `resend-api-key` to Secret Manager (in `infra/environments/staging/main.tf` secrets section). notification-svc Cloud Run reads it as `RESEND_API_KEY`.
- Identity-svc.InviteTherapist becomes a caller — adds a `notification-svc` gRPC client to its dependencies.

Owner: backend. ~6h.

---

### Wave C — verify + ship

**1.11 — Tests, deploy, bootstrap**

- Run `make lint test` from `superwizor-backend/` — every service green.
- E2E test (Go integration test under `tests/`):
  1. `RegisterOrganization` with a fresh email → returns ORG_ADMIN user + Trial subscription.
  2. `InviteTherapist` → email captured by `mock_sender`.
  3. `AcceptInvitation(token)` → THERAPIST user attached to the org.
  4. `ListTherapistsInMyOrg` → returns the new therapist + the admin.
  5. `AdminListOrganizations` → returns the new org.
  6. `AdminResetTokens(reason="manual test")` → counter resets; `audit_events` row present with reason.
- Commit + push `feat/web-app` → opens CI.
- After CI green: merge to `main` → CI deploys all services with new code + dedicated SAs.
- Run staging bootstrap: `psql ... -c "UPDATE users SET role='SUPERWIZOR_ADMIN' WHERE email='dpiotrak2@gmail.com'"`. Document in `docs/agents/01_identity-svc.md`.
- Manual smoke from local Mac:
  ```bash
  TOKEN=$(gcloud auth print-identity-token --audiences=https://identity-svc-...a.run.app)
  curl -X POST -H "authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' -H 'Connect-Protocol-Version: 1' \
    -d '{}' \
    https://identity-svc-...a.run.app/identity.v1.IdentityService/GetMyProfile
  ```
  Expect: 200 OK, your full User proto.

Owner: backend. ~4h.

---

## 2. PR strategy

Eleven sub-tasks → not one giant PR. Proposed sequencing on `feat/web-app`, each with its own commit:

| Commit # | Sub-tasks bundled | Why bundled |
|---|---|---|
| 1 | 1.1 migrations | Atomic. Run on staging immediately so handlers in commit 5 have the new tables. |
| 2 | 1.2 pkg/cors + wiring | Self-contained library + one-line wiring per service. |
| 3 | 1.3 buf.gen extension + generated stubs | Pure tooling + regen. Verifies the codegen path works. |
| 4 | 1.4 terraform SAs + GCS CORS | Infra-only. `terragrunt apply` separately from code deploys. |
| 5 | 1.6 proto + 1.7 identity handlers + 1.8 billing admin | The bulk of the slice. Big commit but cohesive — the proto and handlers ship together or not at all. |
| 6 | 1.9 Connect handler registration | Landed across 6a (identity-svc), 6b (clinical-svc), 6c (billing-svc). Each service gets a `connect_adapter.go` with mechanical 1:1 wrappers (identity 25 RPCs, clinical 19 RPCs, billing 8 RPCs = 52 total) so the existing gRPC handlers stay unchanged but the same business logic answers the Connect/gRPC-Web protocols too. cmd/server/main.go for identity-svc + clinical-svc grow the h2c mixed-handler pattern (billing-svc already had it); pkg/cors wraps everything; CORS_ALLOWED_ORIGINS env overrides the default allowlist. Browser-facing auth interceptor for clinical-svc deferred to Slice 2's first browser-authenticated RPC. |
| 7 | 1.10 notification-svc email + identity-svc invite wiring | Cross-service; both sides change together. |
| 8 | 1.11 E2E tests + bootstrap | Final commit; squash-ready merge to main. |

Manual step 1.5 (Firebase Console) happens out-of-band any time before commit 7.

Each commit must pass `make lint test` locally before push so the in-flight CI runs stay green.

---

## 3. Risks + mitigations

| Risk | Where | Mitigation |
|---|---|---|
| **Connect TS codegen incompat with our buf-managed-mode** | 1.3 | Time-box to 1h. If `connect-es` doesn't cleanly emit, fall back to generating TS manually with `protoc-gen-es` outside buf — same result, just one extra step in `make proto`. |
| **iOS app breaks on extended `UpdateProfile`** | 1.7 | Selective UPDATE in the handler: only overwrite a column if the request field is non-zero. iOS sends a subset; the rest stays untouched. Add a test case asserting `UpdateProfile{first_name:"X"}` doesn't blank `biography`. |
| **Postgres enum extension blocks if existing rows use the new value** | 1.1 | We're adding values, not removing; safe. The migration cannot be run inside a tx with subsequent SELECTs using the new value — keep migration 000037 standalone. |
| **Dedicated SA rollout breaks Cloud SQL access** | 1.4 | Provision SA + IAM grants *before* changing Cloud Run deploy flag. Roll out one service at a time (identity-svc first since it's lower-risk than clinical-svc). |
| **Resend deliverability for `@privaterelay.appleid.com` (Apple hidden email)** | 1.10 | Resend forwards happily; Apple's relay handles the bounce. Add a smoke test sending to a relay address from staging. |
| **`audit_events.reason` retro-fill** | 1.1 | Column is NULL-allowed at creation; existing rows stay NULL. New admin RPCs gate `reason` at handler level, not in PG. |
| **Firebase Apple provider depends on a paid Apple Developer account** | 1.5 | If not in hand, defer Apple to Slice 2 (post-MVP); Google + Microsoft alone unblock most of the work. |

---

## 4. Out of scope for Slice 1

These are documented in §18 but defer to later slices:

- Any frontend code (Slices 2 + 3).
- Email verification UI / flow (the backend supports it via the existing Firebase claim; UI lands when Next.js login screens land in Slice 2).
- Translation files for marketing copy or admin panel — they land alongside the screens that need them.
- Stripe webhook re-implementation (separate work stream).
- PWA service worker / FCM web push (Slice 6+).
- `users.role` → multi-role refactor (explicit MVP simplification, see R4).

---

## 5. Time estimate

| Wave | Sub-tasks | Hours |
|---|---|---|
| A (parallel) | 1.1, 1.2, 1.3, 1.4, 1.5 | ~11h (~7h if 1.5 runs human-async) |
| B (sequenced) | 1.6, 1.7, 1.8, 1.9, 1.10 | ~28h |
| C | 1.11 | ~4h |
| **Total** | | **~43h backend dev + ~1h manual** |

At ~6h focused dev/day, this is **~7 working days** for one engineer. Faster if 1.7 (handlers) gets parallelized — that's the long pole.

---

## 6. Definition of done (mergeable checklist)

- [ ] Migrations 000035 / 000036 / 000037 applied to staging DB.
- [ ] `pkg/cors` exists, has tests, is wired on all five services' mixed handlers.
- [ ] `buf.gen.yaml` emits Go + Connect-Go + TS-Connect; `gen/ts/` populated.
- [ ] Dedicated `identity-svc@` + `clinical-svc@` SAs provisioned and Cloud Run is using them.
- [ ] `audio-uploads` bucket has CORS rules for `superwizor.ai`, `app.superwizor.ai`, localhost.
- [ ] Firebase Console: Google, Apple, Microsoft enabled; account-linking on.
- [ ] All 17 new / 1 extended RPC implemented, unit tested, lint-clean.
- [ ] Connect-RPC endpoints reachable via `curl` (smoke recipe in §1.9).
- [ ] Email path: `notification-svc.SendInvitationEmail` delivers via Resend in staging; mock sender works locally.
- [ ] Bootstrap user marked `SUPERWIZOR_ADMIN`.
- [ ] E2E test passes (RegisterOrg → invite → accept → admin actions).
- [ ] All commits on `feat/web-app`, CI green, ready to merge to `main`.

Once that checklist is fully ticked, Slice 2 (Next.js marketing site) can start with no backend blockers.
