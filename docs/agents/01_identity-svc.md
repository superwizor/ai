---
type: Backend Service Specification
title: "identity-svc"
description: "Validate Firebase ID tokens, manage users/organizations CRUD, and answer permission questions (\"can therapist X read patient file Y?\") for every other backen..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/agents/01_identity-svc.md
tags: [identity, agents, svc]
timestamp: 2026-06-30T16:31:47+02:00
---

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
  // Report customization (feat/report-customization, 2026-05-18) —
  // see "Report preferences" section below.
  rpc GetReportPreferences(GetReportPreferencesRequest) returns (ReportPreferences);
  rpc UpdateReportPreferences(UpdateReportPreferencesRequest) returns (ReportPreferences);
  // Cross-origin SSO (Slice 2 follow-up, 2026-05-29) — see
  // "Cross-origin SSO via custom token" section below.
  rpc MintAppLoginToken(google.protobuf.Empty) returns (AppLoginToken);
}
```

`UserContext` is propagated by callers in gRPC metadata (`x-superwizor-user-id`, `x-superwizor-org-id`, `x-superwizor-role`) on every downstream call.

> Source: `docs/05_FAZA_1_TOZSAMOSC_DANE.md` Sprint 1.2 (lines 803–2056) — full task-by-task spec.

## Tables owned (Identity domain)

| Table | Purpose |
|---|---|
| `users` | UUID v4 PK, `firebase_uid UNIQUE` (NULLable since migration 000013 — patient rows have no Firebase account), `email` (also NULLable post-000013, partial CHECK enforces presence for non-PATIENT), `role` enum (`THERAPIST`/`PATIENT`), `organization_id` FK, `deleted_at` (soft delete), `report_preferences JSONB DEFAULT '{}'` (since 000015 — therapist style preferences for AI report generation, see "Report preferences" below) |
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

## Report preferences (feat/report-customization, 2026-05-18)

Per-therapist style preferences for AI-generated clinical reports.
**identity-svc owns the storage** (`users.report_preferences JSONB`),
not the consumption — ai-pipeline-svc reads the JSONB at call-2
prompt build time. clinical-svc owns the matched feedback loop
(`report_ratings`, `preference_suggestions_log`).

Design spec: `docs/10_REPORT_CUSTOMIZATION.md`.

**Handler**: `internal/adapters/grpc/preferences.go`.

**RPCs**:
- `GetReportPreferences(therapist_id)` — returns the stored blob
  decoded. Empty/missing → default `ReportPreferences` (renders to
  no-op fragment in ai-pipeline-svc).
- `UpdateReportPreferences(therapist_id, preferences, idempotency_key)` —
  validates + sanitizes + UPSERTs. Returns the post-update blob.

**Stored shape (`users.report_preferences` JSONB)**:

```json
{
  "version": 1,
  "length": "brief|standard|detailed",
  "tone": "clinical_formal|empathic_warm|pragmatic_direct|academic_rigorous",
  "quote_density": "few|selective|many",
  "diagnostic_language": "descriptive|clinical_labels|dsm_icd",
  "hypothesis_hedging": "tentative|balanced|assertive",
  "section_emphasis": ["clinical_picture", "safety_and_risk", ...],
  "strengths_framing": "problem_focused|balanced|strengths_first",
  "free_text": "Plain-Polish guidance, ≤500 chars, sanitized.",
  "updated_at": "2026-05-18T..."
}
```

Empty string for any enum field = "use default". Empty object `{}` = "use defaults for everything". Both render to an empty prompt fragment server-side.

**Validation rules** (`preferences.go::validatePayload`):
- Closed allow-lists for every enum field. Unknown value → `InvalidArgument`.
- `section_emphasis` allow-list checked per entry; whitespace-only entries dropped before validation.
- `free_text` ≤ 500 chars; newlines/zero-width chars stripped silently; regex-rejected on injection patterns (`ignore previous instructions`, `system prompt`, `you are now`, `new instructions:`, `act as ...`). **Rejection is the contract — don't silently strip injection attempts.**
- Server stamps `version + updated_at` ignoring client values for those fields.

**Idempotency quirk vs the global pattern**: `UpdateReportPreferences` accepts same key + different payload (treats it as "user changed their mind mid-flight" and overwrites). This DIVERGES from `CreatePatientFile`-style contracts where same key + different payload → `AlreadyExists`. Documented in the handler doc comment because it's surprising.

**Cross-service coupling**:
- Suggestion engine lives in clinical-svc (owns `report_ratings`). Identity-svc has no downstream dep on clinical-svc — they're queried in parallel by Flutter on the settings screen.
- `users.report_preferences` is JOINed by ai-pipeline-svc at call-2 prompt build time. If you change the JSONB schema, update BOTH the `preferencesPayload` struct here AND the `Preferences` struct in `ai-pipeline-svc/internal/reportprefs/` in lockstep. Tests cover the renderer end of that contract.

## Common gotchas

- **`firebase_uid` not set** on User insert → all subsequent `ValidateToken` calls fail because lookup is by `firebase_uid`. Always populate from token claims.
- **`firebase_uid` + `email` are now `*string`** in sqlc-generated types (since migration 000013 relaxed NOT NULL for patient rows). Use the `derefString` helper in `server.go` when rendering to wire types. CreateUser path still requires both pre-pointer-wrap (partial CHECK enforces presence for THERAPIST).
- **Report preferences JSONB**: querying with `WHERE deleted_at IS NULL` is implicit via `GetReportPreferences` query — soft-deleted users return `NotFound`, not a stale blob.
- **Injection patterns in `free_text`**: legitimate Polish therapy phrasing has been verified not to trip the regex (`TestValidatePayload_AllowsLegitimatePolishGuidance`). If a real-world false positive surfaces, add it to that test before relaxing the regex.
- **`audience` claim** must equal the Firebase project ID (`superwizor-ai-25ecd`), not a custom string. Set in Flutter's Firebase init, not here.
- **Soft-deleted users** still exist in `users` table; queries must filter `WHERE deleted_at IS NULL` unless you specifically need the audit trail.
- **Cloud Run cold start + Firebase Admin SDK init** can add ~2s. Use min-instances=1 if latency-sensitive.
- **Firebase Admin SDK init uses ADC** (since 2026-05-29, commit `fbc3b67`). The earlier `option.WithoutAuthentication()` was fine for `VerifyIDToken` (which only fetches Google's public JWKS) but BLOCKS `CustomToken` (which signs the JWT with the runtime SA's key via the IAM Credentials API). The new init is `firebase.NewApp(ctx, &firebase.Config{ProjectID: ...})` with no auth option — ADC resolves through the metadata server on Cloud Run. Local dev needs `gcloud auth application-default login` or `GOOGLE_APPLICATION_CREDENTIALS` pointing at a SA JSON.
- **Runtime SA needs `roles/iam.serviceAccountTokenCreator` on ITSELF** for `CustomToken` to sign without a private-key JSON. Granted to `344724821207-compute@developer.gserviceaccount.com` on 2026-05-29. New environments must replicate.

## Cross-origin SSO via custom token (2026-05-29)

The marketing site (`superwizor.web.app`) and the Flutter web app
(`superwizor-app.web.app`) live on different origins, so Firebase Auth's
IndexedDB session doesn't bridge between them — a user who clicked
"Otwórz kartoteki" on `/account/` used to land on the Flutter login
screen and have to re-enter their password. `MintAppLoginToken` fixes
this.

**Flow:**
1. Browser is signed in on `superwizor.web.app` (marketing origin).
2. User clicks "Otwórz kartoteki" → marketing-site calls
   `identityClient.mintAppLoginToken({})` over Connect-RPC (Firebase ID
   token in the `Authorization: Bearer …` header as usual).
3. Handler calls `resolveCaller(ctx)` → extracts the verified
   `firebase_uid`, then `auth.CustomToken(ctx, firebase_uid)` — never
   reads a uid from the request body.
4. Returns `AppLoginToken{token: <jwt>}`.
5. marketing-site opens
   `https://superwizor-app.web.app/#auth_token=<jwt>` in a new tab.
6. Flutter web's `main()` reads `window.location.hash`, calls
   `FirebaseAuth.instance.signInWithCustomToken(token)`, and strips
   the fragment via `history.replaceState`. The `_AuthGate`'s first
   `authStateChanges` tick already sees the signed-in user, so no
   `LoginScreen` flash.

**Security:**
- The handler NEVER reads a uid from the request — always mints for the
  caller's own `firebase_uid`. No org/role escalation surface.
- Custom tokens are ~1h TTL by Firebase Admin SDK default and single-use
  in practice (Firebase rejects reuse).
- Token is in the URL fragment, not the query string. Fragments don't
  reach Firebase Hosting access logs, aren't included in the `Referer`
  header on outbound clicks, and are stripped from the URL bar
  immediately after redemption.
- On any failure (mint RPC down, popup blocked by Safari, token
  expired before redeem) the marketing-site code falls back to the
  pre-SSO `?email=` prefill so the user can still log in by hand.

**Code:**
- Proto: `proto/identity/v1/identity.proto` — `rpc MintAppLoginToken`
  + `message AppLoginToken{ string token = 1; }`.
- Handler: `services/identity-svc/internal/adapters/grpc/sso.go`.
- Connect adapter: `connect_adapter.go::MintAppLoginToken`.
- Firebase helper: `internal/adapters/firebase/auth.go::CustomToken`.
- Browser: `marketing-site/src/components/account/AccountSections.tsx`
  → `OpenKartotekiButton` (opens popup synchronously inside the click
  handler so Safari's popup blocker permits it, then mutates the
  popup's `location` once the mint resolves).
- Flutter web: `flutter-app/superwizor/lib/auth/sso_handler_web.dart`
  redeems the fragment + strips it; the iOS/Android stub is at
  `lib/auth/sso_handler.dart` (no-op). Conditional import on
  `dart.library.html` in `main.dart` keeps mobile bundles unchanged.

## SUPERWIZOR_ADMIN bootstrap (one-time, per environment)

After Slice 1 of `feat/web-app` deploys, the `users.role` enum gains
`ORG_ADMIN` and `SUPERWIZOR_ADMIN` values (migration 000037). New
admins are minted by flipping the `role` column for an existing user
row:

```sql
-- staging — pick the Superwizor team email
UPDATE users
   SET role = 'SUPERWIZOR_ADMIN'
 WHERE email = 'dpiotrak2@gmail.com'
   AND deleted_at IS NULL;
```

Run via the cloud-sql-proxy (port 5433 + `psql ... sslmode=disable`),
NOT via a Cloud SQL admin tool — the proxy is the only path with the
right IAM. The change takes effect on the user's next inbound RPC
(no service restart needed).

The reverse — demoting an admin — uses the same UPDATE with the
target role. There is intentionally no admin UI for this; the
escape-hatch lives in `psql` so an attacker who compromises the
admin panel can't promote themselves.

## Firebase OAuth providers (Slice 1 manual config)

Per docs/18 R7. One-time setup in Firebase Console
(`superwizor-ai-25ecd`):

1. **Authentication → Sign-in method** — enable Google, Apple,
   Microsoft, plus the existing Email/Password.
2. **Authentication → Settings → Account linking** — enable
   "Link accounts that use the same email" (avoids duplicate UIDs
   when a user signs up with one provider and later switches).
3. **Google**: reuses the existing Google Cloud OAuth 2.0 client.
   Add authorized redirect URIs:
   `https://superwizor.ai/__/auth/handler`,
   `https://app.superwizor.ai/__/auth/handler`,
   `http://localhost:3000/__/auth/handler`,
   `http://localhost:8080/__/auth/handler`.
4. **Apple**: create a Services ID + Sign-in-with-Apple key in
   the Apple Developer portal. Paste the Services ID, team ID,
   key ID, and the private key into Firebase. Rotate the key
   yearly (Apple expires them after 6 months, so a calendar
   reminder for month 5 is wise).
5. **Microsoft**: register a "Web" app in Microsoft Entra (Azure
   AD). Copy app (client) ID + secret into Firebase. Rotate
   secret yearly.

No code changes required for any of the above — identity-svc trusts
the Firebase JWT regardless of provider once verified.

## Resend transactional email (Slice 1)

Production invitation emails go through Resend (Go SDK in
`services/notification-svc/internal/email/`). To bring this up in a
new environment:

1. `gcloud secrets create resend-api-key --replication-policy=automatic`
2. `echo -n "$RESEND_KEY" | gcloud secrets versions add resend-api-key --data-file=-`
3. Grant `roles/secretmanager.secretAccessor` on `resend-api-key` to
   `notification-svc@<project>.iam.gserviceaccount.com` (add to
   `infra/environments/<env>/service-accounts.tf`).
4. Set `RESEND_FROM` env on notification-svc Cloud Run — e.g.
   `Superwizor <noreply@client.superwizor.ai>`. Defaults to that value in
   the CI workflow if unset.

Without the secret the notification-svc binary boots happily and uses
`MockSender` (logs but doesn't send). identity-svc.InviteTherapist
still creates the invitation row + URL — only the email leg is
silent. Useful for local dev; loud in prod logs ("RESEND_API_KEY
unset — using MockSender").

## Source-doc pointers

- `docs/05_FAZA_1_TOZSAMOSC_DANE.md` lines 803–2056 — full Phase 1 task list (proto def, sqlc, Firebase adapter, gRPC handler, deploy, smoke tests, troubleshooting).
- `docs/03_DATA_MODEL.md` §4.3 (lines 1057–1200) — DDL.
- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §4.2.1 (lines 359–400) — service responsibility.
- `docs/18_WEB_APP_DESIGN.md` — full Slice 1+ design + form catalogue + i18n contract.
- `docs/19_WEB_SLICE_1_PLAN.md` — the 8-commit Slice 1 plan that introduces the new RPCs (RegisterOrganization, InviteTherapist, AcceptInvitation, Admin*).
