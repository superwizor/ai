---
type: Technical Design
title: "18. Web App — Design Spec"
description: "Version: 0.2 (2026-05-27) — incorporates Antigravity design-review notes Owner: Dariusz + backend agent Related: 02ARCHITEKTURATECHNICZNA.md, agents/00GLOBAL..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/18_WEB_APP_DESIGN.md
tags: [ai, analytics, architecture, billing, crm, database, frontend, identity, infrastructure, ingestion, notifications, security, testing]
timestamp: 2026-05-27T15:58:39+02:00
---

# 18. Web App — Design Spec

**Version:** 0.2 (2026-05-27) — incorporates Antigravity design-review notes
**Owner:** Dariusz + backend agent
**Related:** `02_ARCHITEKTURA_TECHNICZNA.md`, `agents/00_GLOBAL_CONTEXT.md`, `agents/01_identity-svc.md`, `09_UI_MVP_FLUTTER.md` (the design system this borrows from)
**Changelog vs v0.1:**
- **R4** Single-role MVP. Dropped `users.roles` JSONB; kept singular `users.role`. Org founder is `ORG_ADMIN` *only* — no THERAPIST dual-role. To both manage an org *and* record sessions, the founder creates a second therapist account (invite-yourself flow).
- **R1** Clarified that Connect-RPC natively speaks gRPC, gRPC-Web, and Connect protocols from the same endpoint — Flutter Web's existing `GrpcOrGrpcWebClientChannel` works straight against it; no shim, no Envoy.
- **R2** New shared `pkg/cors` middleware required on every service's mixed HTTP handler. Without it browsers reject every Connect-RPC call.
- **R3** Marketing site's "Log in" CTA *redirects* to `app.superwizor.ai/login` rather than trying to sync a Firebase session cookie across origins (origin-bound IndexedDB makes that fragile).
- **R5** Invitation `token_hash` switched from Argon2 to SHA-256 — magic-link tokens are 256-bit random, slow hashing buys nothing and opens a CPU-DoS vector on `AcceptInvitation`.
- **R6** Slice 1 now provisions dedicated per-service GCP service accounts for clinical-svc + identity-svc (replacing the default Compute SA — was a P2 Zero-Trust violation).
- **R7** Added social-login providers: Google, Apple, Microsoft via Firebase Auth's standard OAuth plug-ins. Email/Password stays for clinics that prefer it. Facebook intentionally excluded (privacy posture for a therapy platform). New §6.5 covers the providers + account-linking + post-OAuth finish-profile flow.
- **R8** Full CRUD spec aligned with the data model. New §13 enumerates every form (registration, profile edit, org edit, admin CRUD) field-by-field, mapped to the canonical `users` / `organizations` / `addresses` columns from `docs/03_DATA_MODEL.md`. §6.1 RPC list extended with `UpdateOrganization`, `GetMyOrganization`, `UpdateMyProfile`, `GetMyProfile`, and three admin-scoped Update/Delete RPCs.
- **R9** Internationalisation required from day one. New §14 specifies: PL + EN at launch (parity with the existing Flutter ARB set), `next-intl` on Next.js, Flutter Web reuses the existing `app_pl.arb` / `app_en.arb`. Locale resolution order: explicit URL prefix → authenticated user's `users.ui_language` → Accept-Language → `pl` fallback. Backend continues to return codes not strings (existing principle), email templates are localised against the recipient's `ui_language`. Form labels in §13 are illustrative PL — the canonical source is the ARB / `messages/*.json` files.
- Misc: Flutter `Hive` native web build is fine — no `idb_shim` wrapper needed. Added GCS bucket CORS terraform requirement for direct-to-GCS browser uploads.

This document specifies a web frontend that complements the existing iOS Flutter app. Four user surfaces, two codebases, one Firebase project, one set of gRPC backend services.

---

## 1. Context — why a web app

The platform is iPhone-only today. Three pressures drive the need for web:

1. **Onboarding friction** — therapists currently sign up via the iOS app, which means the App Store install gate sits in front of every conversion. We want a public marketing-style registration flow that captures users before they touch a device.
2. **Clinic growth** — when a multi-therapist clinic onboards, the founder needs to invite N therapists by email. Today that flow doesn't exist; the app assumes a one-person-one-org model.
3. **Operations** — the Superwizor team needs an admin console for support (block bad orgs, top up tokens, view usage). Today everything is `psql` and ad-hoc Bash.
4. **Daily work without a phone** — therapists want to read transcripts and reports at a desk. Recording stays mobile (iPhone has the trusted FLAC encoder and works in the room), but viewing belongs on a large screen.

The web app is **not** a replacement for the mobile app. The mobile app remains the source of truth for live session capture. Web complements it.

---

## 2. Four surfaces, two codebases

| # | Surface | URL | Audience | Codebase |
|---|---|---|---|---|
| 1 | **Marketing + registration (individual + org)** | `superwizor.ai/*` | Prospective therapists, clinic founders | Next.js |
| 2 | **Superwizor admin console** | `superwizor.ai/admin/*` | Internal team | Next.js |
| 3 | **Org-admin console** (manage therapists, billing) | `app.superwizor.ai/admin/*` | Clinic owners | Flutter Web |
| 4 | **Therapist console** (kartoteki, transcripts, reports) | `app.superwizor.ai/*` | Therapists at desk | Flutter Web |

**Why two codebases:**

- **Next.js for #1 + #2**: SEO-friendly landing/registration pages, server-rendered, fast time-to-interactive, mature admin-panel ergonomics (TanStack Table, etc.).
- **Flutter Web for #3 + #4**: 70%+ code reuse from the existing iOS app. Same widgets (`QuotaWarningBanner`, `EuphireCard`, session stepper), same Riverpod providers, same gRPC clients. Same brand language. The org-admin view is grouped here because it lives behind login next to the therapist console and shares chrome.

Shared between both: Firebase Auth (single project), gRPC backend (via Connect-RPC), brand system (`euphire_theme.dart` for Flutter Web; ported to Tailwind tokens for Next.js).

---

## 3. Hosting & deploy

Both apps deploy to **Firebase Hosting** in the existing `superwizor-ai-25ecd` project. Two sites:

```
firebase.json (extended)
{
  "hosting": [
    { "site": "superwizor-www",   "public": "marketing-site/out",   "rewrites": [...] },  // Next.js
    { "site": "superwizor-app",   "public": "flutter-app/superwizor/build/web" }            // Flutter Web
  ]
}
```

CI workflow gets two new build steps:
1. `cd marketing-site && pnpm build && firebase deploy --only hosting:superwizor-www`
2. `cd flutter-app/superwizor && flutter build web --release && firebase deploy --only hosting:superwizor-app`

Same workflow that already builds backend Docker images; no new auth needed (Firebase service account for GH Actions).

DNS: `superwizor.ai` → www site; `app.superwizor.ai` → app site. Both behind Firebase's CDN.

---

## 4. New repo layout

```
ai/                                 # repo root (existing)
├── superwizor-backend/             # existing — gRPC services
├── flutter-app/superwizor/         # existing — iOS + WEB target enabled
│   └── web/                        #   created by `flutter create --platforms web`
├── marketing-site/                 # NEW — Next.js (TypeScript, App Router)
│   ├── app/
│   │   ├── (marketing)/page.tsx           # landing
│   │   ├── register/therapist/page.tsx    # individual therapist registration
│   │   ├── register/organization/page.tsx # clinic registration
│   │   ├── admin/                          # Superwizor team admin panel
│   │   │   ├── orgs/page.tsx              # org list + block/unblock
│   │   │   ├── orgs/[orgId]/page.tsx      # org detail (usage, token reset, plan change)
│   │   │   └── audit/page.tsx             # audit log viewer
│   │   └── api/                            # Connect-RPC client helpers
│   ├── lib/connect-clients.ts              # generated Connect-RPC TS clients
│   └── package.json
├── firebase.json                   # extended with hosting sites
└── docs/18_WEB_APP_DESIGN.md       # this doc
```

The Flutter app's web target is added with `flutter create --platforms web .` from `flutter-app/superwizor/`. Most screens compile straight out; the affected ones (recording, file pickers, etc.) get a `kIsWeb` branch.

---

## 5. Architecture

```
                ┌──────────────────────┐         ┌──────────────────────┐
   Browser ───→ │  Next.js             │         │  Flutter Web         │
                │  superwizor.ai       │         │  app.superwizor.ai   │
                │  - marketing         │         │  - therapist console │
                │  - registration      │         │  - org-admin console │
                │  - admin (internal)  │         │                      │
                └──────────┬───────────┘         └──────────┬───────────┘
                           │                                │
                           │  Connect-RPC over HTTPS        │  Connect-RPC
                           │  (same proto/ as Go services)  │  (same as iOS app
                           │                                │   via grpc-web shim)
                           ▼                                ▼
                ┌────────────────────────────────────────────────────────┐
                │  Backend gRPC services (Cloud Run, unchanged)          │
                │  identity-svc / clinical-svc / billing-svc /           │
                │  ingestion-svc / notification-svc                       │
                │                                                         │
                │  Each service gains a Connect handler alongside        │
                │  its existing grpc.Server (one new line per service)   │
                └────────────────────────────────────────────────────────┘

                ┌────────────────────────────────────────────────────────┐
                │  Firebase Auth (single project for therapists, org     │
                │  admins, and Superwizor admins; role separation via    │
                │  user_roles enum in identity-svc, NOT separate IdPs)   │
                └────────────────────────────────────────────────────────┘
```

**Browser → backend wire format:** `connectrpc.com/connect-go` on the server side, `@connectrpc/connect-web` on the Next.js side. The **same** Connect handler natively speaks three protocols on the same endpoint — gRPC (existing iOS app), gRPC-Web, and Connect — so Flutter Web's existing `GrpcOrGrpcWebClientChannel.toSingleEndpoint` reaches it without any client-side change. No envoy proxy, no separate REST BFF, no gRPC-Web wrapper.

**CORS is required.** Browsers will pre-flight every cross-origin POST. We ship a shared `pkg/cors` middleware in `superwizor-backend/` and register it on every service's mixed HTTP handler. The middleware must allow `POST`, `OPTIONS`, the headers `Authorization`, `Content-Type`, `Connect-Protocol-Version`, `Connect-Timeout-Ms`, `X-Grpc-Web`, and restrict `Origin` to `https://superwizor.ai`, `https://app.superwizor.ai`, plus `http://localhost:3000` / `http://localhost:8080` for local dev. Without it every Connect call from the browser dies before reaching the gRPC handler.

**Auth flow (same for all 4 surfaces):** Firebase Auth (Email/Password OR Google OR Apple OR Microsoft via OAuth pop-up — see §6.5) → ID token → sent as `authorization: Bearer <token>` in Connect-RPC metadata → identity-svc interceptor validates → injects `UserContext` (user_id, organization_id, role) into ctx. The interceptor is provider-agnostic: it verifies the JWT against Firebase's JWKs and reads `firebase_uid` from the claims, regardless of which sign-in method produced the token. Same interceptor that today serves the iOS app.

**Login origin discipline (per R3):** Firebase Auth stores its session in IndexedDB scoped to the origin. A user logged in on `superwizor.ai` would *appear* logged out on `app.superwizor.ai` because they're different origins. We deliberately do **not** try to bridge that with a cookie sync. Instead, the marketing site's "Log in" CTA is a plain `<a href="https://app.superwizor.ai/login">` redirect. Authentication state lives entirely on the app origin, end of complication.

---

## 6. Backend changes required

### 6.1 New RPCs

**`identity-svc`** (new methods on `IdentityService`):

```protobuf
// Org self-serve registration. Creates organisation + a single ORG_ADMIN user
// + Trial subscription in one tx. Idempotent on email. The founder gets
// role=ORG_ADMIN only — to also record sessions they must invite themselves
// as a THERAPIST under a second email from the Therapists tab.
rpc RegisterOrganization(RegisterOrganizationRequest) returns (RegisterOrganizationResponse);

// Org admin invites a therapist by email. Creates an `invitations` row;
// the actual user row + Firebase account land on invitation acceptance.
rpc InviteTherapist(InviteTherapistRequest) returns (Invitation);

// Therapist clicks the magic link → this RPC validates the token,
// creates Firebase password (or hands off to client-side createUser),
// and attaches the new user to the inviting org.
rpc AcceptInvitation(AcceptInvitationRequest) returns (AcceptInvitationResponse);

// Org admin lists therapists in their org. Same shape as Superwizor admin
// uses but scoped by org_id from the caller's token.
rpc ListTherapistsInMyOrg(google.protobuf.Empty) returns (ListTherapistsResponse);

// Org admin removes a therapist (soft delete via users.deleted_at).
rpc RemoveTherapist(RemoveTherapistRequest) returns (google.protobuf.Empty);

// Profile + org CRUD — used by every authenticated surface.
rpc GetMyProfile(google.protobuf.Empty) returns (User);
rpc UpdateMyProfile(UpdateMyProfileRequest) returns (User);
// Org-admin only — gated on role=ORG_ADMIN, scoped to the caller's org.
rpc GetMyOrganization(google.protobuf.Empty) returns (Organization);
rpc UpdateMyOrganization(UpdateMyOrganizationRequest) returns (Organization);
```

**`identity-svc` admin RPCs** (gated on `role=SUPERWIZOR_ADMIN`):

```protobuf
rpc ListOrganizations(ListOrganizationsRequest) returns (ListOrganizationsResponse);
rpc GetOrganizationDetails(GetOrganizationDetailsRequest) returns (OrganizationDetails);
rpc SetOrganizationStatus(SetOrganizationStatusRequest) returns (google.protobuf.Empty);  // block/unblock

// Full CRUD for support cases. Every mutation writes audit_events with reason.
rpc AdminUpdateOrganization(AdminUpdateOrganizationRequest) returns (Organization);
rpc AdminListUsers(AdminListUsersRequest) returns (AdminListUsersResponse);
rpc AdminGetUser(AdminGetUserRequest) returns (User);
rpc AdminUpdateUser(AdminUpdateUserRequest) returns (User);
rpc AdminDeleteUser(AdminDeleteUserRequest) returns (google.protobuf.Empty);  // soft delete via users.deleted_at
```

**`billing-svc` admin RPCs** (gated on `role=SUPERWIZOR_ADMIN`):

```protobuf
rpc AdminResetTokens(AdminResetTokensRequest) returns (Subscription);
//   Sets usage_counters.tokens_used + tokens_reserved. Reason field required;
//   audit_events row written.

rpc AdminChangePlan(AdminChangePlanRequest) returns (Subscription);
//   Updates subscriptions.plan_tier + plan_cycle, creates fresh usage_counters
//   row at the new limit. Reason field required; audit_events row written.
```

### 6.2 New tables

```sql
-- 000035_invitations.up.sql
CREATE TABLE invitations (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id   UUID NOT NULL REFERENCES organizations(id),
    invited_by_user   UUID NOT NULL REFERENCES users(id),
    email             CITEXT NOT NULL,
    -- SHA-256(token) where token is 32 bytes of crypto/rand, URL-safe-base64-encoded for the link.
    -- Per R5: NOT Argon2. The token already has 256 bits of entropy, brute-forcing it is
    -- physically impossible, and slow KDFs on the AcceptInvitation hot path would be a
    -- CPU-DoS vector — an attacker spamming the endpoint with garbage tokens could pin a
    -- CPU per request. SHA-256 is fast, irreversible, and database-leak safe.
    token_hash        BYTEA NOT NULL,
    expires_at        TIMESTAMPTZ NOT NULL,
    accepted_at       TIMESTAMPTZ,
    accepted_user_id  UUID REFERENCES users(id),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (organization_id, email)
);
CREATE INDEX idx_invitations_token_hash ON invitations(token_hash) WHERE accepted_at IS NULL;

-- 000036_audit_events_admin.up.sql
-- (audit_events table exists since 000012; we add a 'SUPERWIZOR_ADMIN' actor_type
--  and require a `reason` field on admin mutations — schema-level CHECK)
ALTER TABLE audit_events
  ADD COLUMN reason TEXT;
```

### 6.3 Schema additions / role enum (MVP: single-role users)

```sql
-- 000037_user_role_extend.up.sql
-- Extend the existing user_role enum. TRIAL plan already exists from migration 000032.
-- Per R4: roles are mutually exclusive. A user holds EXACTLY ONE role on users.role —
-- we do NOT introduce a JSONB roles array or a junction table for the MVP.
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'ORG_ADMIN';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'SUPERWIZOR_ADMIN';
```

The full enum after this migration: `THERAPIST | PATIENT | ORG_ADMIN | SUPERWIZOR_ADMIN`.

**No `users.roles` JSONB column.** The singular `users.role` is the only role source. Downstream services already propagate it via the `x-superwizor-role` gRPC metadata header — that wiring stays as-is, no multi-role parsing or merging needed anywhere.

**Implication for org founders.** An org self-serve registration produces an `ORG_ADMIN` row only. That account *cannot* record sessions, open kartoteki, or access transcripts — the therapist console is gated on `role = THERAPIST`. If the founder also wants to use Superwizor clinically, they invite themselves with a *different* email (the standard invite flow does the rest). This is the explicit MVP trade-off — clear audit boundaries beat the convenience of one-account dual-role. UI copy on the org-reg form will spell this out so it isn't a surprise:

> "After creating your clinic, you'll be its administrator — managing therapists, billing, and settings. To also record sessions yourself, invite yourself as a therapist using a second email from the Therapists tab."

For individual therapist registration (`/register/therapist`) the user is created as `THERAPIST` with the existing Trial auto-provisioning (commit `0a25ac7`) — no change.

### 6.4 Connect-RPC handler wiring

In `services/*/cmd/server/main.go` we add Connect alongside grpc.Server:

```go
import (
    connectrpc.com/connect
    billingv1connect "github.com/superwizor-ai/backend/gen/go/billing/v1/billingv1connect"
)

// ...
billingPath, billingHandler := billingv1connect.NewBillingServiceHandler(billingServer)
httpMux.Handle(billingPath, billingHandler)
```

The `mixedHandler` in billing-svc's main.go already dispatches non-grpc HTTP to the mux, so this works without architectural change — Connect handlers are just more HTTP routes.

For services that don't have h2c mixed handlers today (identity-svc, clinical-svc), we add the same pattern. Cheap.

### 6.5 Social-login providers (R7)

The existing Flutter iOS app uses Firebase Email/Password only. For the web we add three OAuth providers via Firebase Auth's built-in plug-ins:

| Provider | Why | Backend config | Client SDK call |
|---|---|---|---|
| **Google** | Universal, near-zero friction for B2C and B2B users. Verified email out of the box. | Enable `Google` in Firebase Console → Authentication → Sign-in method. Existing Google Cloud OAuth client; only add the new authorized redirect URIs (`https://superwizor.ai/__/auth/handler`, `https://app.superwizor.ai/__/auth/handler`, `http://localhost:3000/__/auth/handler`, `http://localhost:8080/__/auth/handler`). | `signInWithPopup(auth, new GoogleAuthProvider())` |
| **Apple** | Privacy-aligned, valued by EU clinicians. Required if we later add any third-party login to the iOS app (App Store guideline 4.8); free to opt-in now on web alone. Email may be relay-anonymized — backend must tolerate that. | Create an Apple Services ID in the Apple Developer portal, generate a Sign-in-with-Apple key, paste the key + team ID into Firebase Console. Add the same authorized redirect URIs. | `signInWithPopup(auth, new OAuthProvider('apple.com'))` |
| **Microsoft** | B2B value — clinics on Microsoft 365 / Entra ID get SSO-style onboarding. | Register an app in Microsoft Entra (Azure AD), copy app ID + secret into Firebase Console under Microsoft provider. | `signInWithPopup(auth, new OAuthProvider('microsoft.com'))` |
| **Email / Password** | Stays as a fallback for users who prefer it (and for the invite-yourself founder workaround when a single human needs two distinct accounts). | Already enabled. | `createUserWithEmailAndPassword` / `signInWithEmailAndPassword` |

**Intentionally excluded for MVP:** Facebook, X/Twitter, GitHub. The therapy context demands a professional posture; sign-in-with-Facebook on a clinical platform reads as a brand mismatch. We can revisit if customer demand surfaces.

**One account per email.** Enable Firebase Console → Authentication → Settings → "Account linking" → **Link accounts that use the same email**. Without this, a user who first signed up with Email/Password and later clicks "Continue with Google" using the same address gets a second, orphan Firebase user — which then has no matching row in our `users` table and breaks. With this setting, Firebase prompts to link and reuses the original UID.

**Backend impact is near-zero.** The `identity-svc` auth interceptor verifies any valid Firebase ID token regardless of provider; the `firebase_uid` it injects is stable across providers once account-linking is on. `CreateUser` and the Trial-provisioning flow already accept the `email` + `display_name` directly from the token — they don't care whether the user came from password, Google, Apple, or Microsoft. No new RPCs, no schema changes for social.

**Email verification.** Social-provider tokens come with `email_verified=true` (Google + Microsoft always; Apple unless the user picked the relay-anonymous mode). For Email/Password we explicitly require Firebase's `sendEmailVerification` after `createUserWithEmailAndPassword`, and the Next.js + Flutter Web login screens refuse to proceed past `/home` until `auth.currentUser.emailVerified === true`. This closes a gap that the iOS app's current flow has (it skips verification entirely — known issue, fixed at the same time as web rolls out).

**Post-OAuth "finish profile" page** (Next.js, `/register/therapist/finish` and `/register/organization/finish`). When a brand-new user signs in via Google/Apple/Microsoft on a registration screen, the provider gives us email + name + (sometimes) photo URL — but **not** the fields specific to Superwizor: chosen modality, organization legal name, or which of the two registration paths they wanted. The OAuth pop-up returns → if `identity-svc.GetUserByFirebaseUID` returns NotFound → redirect to the appropriate finish page (therapist or org) → user fills the remaining fields → submit → `CreateUser` or `RegisterOrganization`. Repeat visits skip the finish page entirely (their user row already exists).

**Apple relay email caveat.** Apple's "Hide my email" mode returns an anonymous `@privaterelay.appleid.com` address; the backend stores it verbatim and treats it as the user's email. Invitations sent to this address still reach the user because Apple forwards them. We make no special-case handling — just accept the relay address as the source of truth.

**Admin sign-in.** Superwizor team members log in to the admin panel the same way (Firebase + any provider). The `SUPERWIZOR_ADMIN` role gate is on the *user record* in our PG, not the auth method — so an admin can use Google one day, password the next; the bootstrap script just sets `users.role='SUPERWIZOR_ADMIN'` on the row matching their email.

**iOS app forward-compat.** When the Flutter iOS app adds these providers in a later release (likely after the web ships), the same Firebase configuration applies — only `firebase_auth` Dart calls change. **Important constraint:** if we add Google sign-in on iOS, App Store guideline 4.8 obliges us to add Sign-in-with-Apple at the same time. The web has no such constraint (no app-store gating), so adding Google on web first is fine.

---

## 7. RBAC matrix (single-role per user)

| Role | Marketing site | Registration | Admin panel | Org-admin console | Therapist console |
|---|---|---|---|---|---|
| Unauthenticated | ✓ read | ✓ submit | — | — | — |
| `THERAPIST` (solo or invited-into-org) | ✓ | — | — | — | ✓ |
| `ORG_ADMIN` (clinic owner, including founders) | ✓ | — | — | ✓ | — |
| `SUPERWIZOR_ADMIN` | ✓ | — | ✓ | — | — |
| `PATIENT` (future) | ✓ | — | — | — | — |

Enforcement: both at the API layer (each protected RPC starts with `if userCtx.Role != expected { return PermissionDenied }`) and at the routing layer (Next.js middleware on `/admin/*`, Flutter Web route guards). The interceptor that injects `UserContext` already exposes `Role` as a single value — no parsing of arrays.

Two ergonomic notes:

- A founder who needs both views creates two accounts under two emails. The therapist account is invited from the org-admin account using the standard invite flow. Audit trails stay clean (one human, two intentful logins).
- We are **not** adding a "switch role" UI in the MVP. If user demand surfaces, the path forward is to add a `user_role_grants` junction table without changing the propagation header (the active role would be selected at login time and stamped into the ID token claims).

---

## 8. Feature map

### 8.1 Next.js marketing site (`superwizor.ai`)

- **Landing** — copy describing what Superwizor is, screenshots, CTA → register
- **Pricing** — Trial (free, 3 tokens) / SOLO / PRO / CLINIC (read from `subscription_plans`)
- **`/register/therapist`** — individual therapist signup
  - Top-of-form: three social buttons ("Continue with Google", "Continue with Apple", "Continue with Microsoft") + a "Use email instead" disclosure that expands the email/password fields.
  - Social path: OAuth pop-up → on success `signInWithPopup` returns → check `identity-svc.GetUserByFirebaseUID(firebase_uid)` → if `NotFound`, redirect to `/register/therapist/finish` for the modality picker → submit → `CreateUser(role=THERAPIST, modality=…)` → Trial auto-provisioning (existing `0a25ac7` flow) → land on `app.superwizor.ai`.
  - Email/password path: inputs (email, password, first name, last name, modality) → `createUserWithEmailAndPassword` → `sendEmailVerification` → "We sent you a confirmation email" page → user clicks link → returns → `identity-svc.CreateUser` → Trial provisioned.
- **`/register/organization`** — clinic signup
  - Same three social buttons + email/password fallback.
  - Form shows a notice: "After signup you'll be the clinic *administrator*. To also record sessions yourself, invite a second email from the Therapists tab once you're in."
  - Social path: OAuth pop-up → if user doesn't exist yet, redirect to `/register/organization/finish` for org legal name + billing email → submit → `RegisterOrganization` → user gets `role=ORG_ADMIN` only.
  - Email/password path: inputs (email, password, first name, last name, organization legal name, billing email) → `createUserWithEmailAndPassword` → email verification → `RegisterOrganization` → `role=ORG_ADMIN` only. No THERAPIST row, no kartoteki access.
- **`/login`** — a plain `<a href="https://app.superwizor.ai/login">` redirect to the app origin. We deliberately do **not** run the Firebase login flow on `superwizor.ai` because IndexedDB is origin-scoped and the resulting session wouldn't transfer (see §5 origin discipline). The Flutter Web `/login` screen on `app.superwizor.ai` is the single place authentication actually happens — and it carries the same set of buttons (Google / Apple / Microsoft / Email).
- **Static legal pages** — terms / privacy / DPA — Markdown rendered

### 8.2 Next.js admin console (`superwizor.ai/admin`)

- **Orgs list** — filterable table; columns: org name, plan, status, therapists count, tokens used / limit, last activity
- **Org detail** — usage history chart (sessions/day, tokens/period), therapist list, audit log for this org
- **Actions** (each → confirmation dialog → audit log entry):
  - Block / unblock org
  - Reset / top up tokens (with reason field)
  - Change plan (with reason field)
- **Audit log viewer** — global cross-org audit history (`audit_events` table); filterable by actor, action, date range

### 8.3 Flutter Web therapist console (`app.superwizor.ai`)

Same as iOS app **minus**:

- ❌ `recording_screen.dart` — replaced with a friendly "Use the iPhone app to record" CTA
- ❌ `new_session_screen.dart` audio recording branch — file upload still available
- ❌ FCM push (browser PWA-style notification later; not in v1)

Same as iOS app:

- ✓ Login screen
- ✓ Home / Kartoteki list
- ✓ Client details / patient sessions
- ✓ File upload via browser file input (drag-drop bonus)
- ✓ Session status stepper (Firestore listener works in browser)
- ✓ Transcript screen with player + PDF export
- ✓ Report screen with sections + risk badge
- ✓ Settings menu (profile, language, subscription)
- ✓ Subscription plan screen

Web-specific tweaks:

- File picker uses `<input type="file" accept="audio/*">` instead of native picker.
- Upload queue: Hive's web build target writes to IndexedDB out of the box — no `idb_shim` wrapper. The existing `UploadQueueRunner` keeps working; just verify on first build.
- Avatar upload uses `<input type="file" accept="image/*">` instead of `image_picker`.
- Audio playback uses HTML5 audio (works through `audioplayers`' web implementation).
- `flutter_secure_storage` on web falls back to LocalStorage (browser-isolated, not OS-keychain). Acceptable for the therapist console because we don't store PHI client-side — only Firebase ID tokens, which Firebase Auth already manages. We surface a one-time warning in the login footer ("for use on personal devices only") on shared-machine login attempts (browser fingerprint heuristic).

GCS direct uploads from the browser need a bucket-level CORS policy — see Section 11 / Slice 1 deliverables.

### 8.4 Flutter Web org-admin console (`app.superwizor.ai`)

Lives inside the same Flutter Web bundle. Route gated on `role == 'ORG_ADMIN'`. Org-admins see *only* the admin views — no Kartoteki tab, no transcript viewer.

- **Therapists** — list of therapists in the org, with status (active / pending invite)
  - "Add therapist" → email input → `identity-svc.InviteTherapist` → email sent.
  - "Remove therapist" → `identity-svc.RemoveTherapist`.
  - "Invite myself as therapist" — shortcut for the founder dual-account workaround: pre-fills the invite form with the admin's email + a `_therapist` suffix hint so they pick a second mailbox (or alias). UI copy reminds them they'll log in as a different user.
- **Billing** — org's subscription, plan tier, current period usage, pending reservations (read-only of `Subscription` proto via `clinical-svc.GetMyBillingState`, which scopes to caller's org).
- **Org settings** — legal name, billing email, address (for future invoicing).

A `THERAPIST` user in the same org sees the standard Kartoteki / Sessions UI from §8.3. The two consoles never share a single account.

---

## 9. Invitation flow (end-to-end)

```
1. Org admin opens `/admin` → Therapists → "Add therapist".
2. Enters email → `InviteTherapist(email)`.
3. Backend:
   - Generate `token = base64url(crypto/rand 32 bytes)` — sent in the URL.
   - `token_hash = sha256(token)` — stored in PG. Per R5, **not** Argon2: token entropy is already 256 bits, slow KDFs only buy a CPU-DoS vector here.
   - `INSERT invitations(org_id, email, token_hash, expires=NOW+7d)`.
   - Send email via `notification-svc` with link:
     `https://app.superwizor.ai/accept-invite?token=<base64url>`
4. Therapist clicks link → `app.superwizor.ai/accept-invite` (Flutter Web route).
5. Page shows "You've been invited to join &lt;org name&gt;. Set your password."
6. Therapist enters password → Firebase Auth `createUserWithEmailAndPassword`.
7. After Firebase succeeds, page calls `AcceptInvitation(token, firebase_uid)`.
8. Backend:
   - Re-hash incoming token with SHA-256, look up by `token_hash` (uses the partial index from migration 000035).
   - Verify not expired, not already accepted.
   - `INSERT users(firebase_uid, email, organization_id, role=THERAPIST)`.
   - `UPDATE invitations SET accepted_at=NOW(), accepted_user_id=user.id`.
   - Return user + org info.
9. Page redirects to `/home` → Flutter Web therapist console.
```

Idempotency: a second click on the same link sees `accepted_at IS NOT NULL` → page shows "This invitation was already used; sign in normally."

---

## 10. Phasing (slices)

**Slice 1 — backend foundation** (week 1)
- Add Connect handlers to identity-svc, clinical-svc, billing-svc (no logic change — same `BillingServiceServer` etc. is registered against both `grpc.NewServer` and `billingv1connect.NewBillingServiceHandler`).
- Migrations 000035 (invitations, SHA-256 `token_hash`) + 000036 (`audit_events.reason TEXT`) + 000037 (`user_role` enum extended with `ORG_ADMIN`, `SUPERWIZOR_ADMIN`). **No `users.roles` JSONB column** — singular `users.role` stays.
- New RPCs: `RegisterOrganization` (returns ORG_ADMIN-only user), `InviteTherapist`, `AcceptInvitation`, `ListTherapistsInMyOrg`, `RemoveTherapist` — all with idempotency keys + unit tests + the same `fakeQuerier` test double pattern billing-svc uses.
- Admin RPCs in billing-svc: `AdminResetTokens`, `AdminChangePlan` — interceptor checks `role == SUPERWIZOR_ADMIN`. Both write `audit_events` with required `reason`.
- Admin RPCs in identity-svc: `ListOrganizations`, `GetOrganizationDetails`, `SetOrganizationStatus`. Same role gate, same audit.
- **New shared `superwizor-backend/pkg/cors`** middleware (per R2). Allowed origins from env (staging: `superwizor.ai`, `app.superwizor.ai`, `localhost:3000`, `localhost:8080`). Allowed headers: `Authorization`, `Content-Type`, `Connect-Protocol-Version`, `Connect-Timeout-Ms`, `X-Grpc-Web`, `X-User-Agent`. Registered on every service's mixed HTTP handler.
- **Dedicated service accounts** for `clinical-svc` and `identity-svc` (per R6): provision `clinical-svc@…iam.gserviceaccount.com` and `identity-svc@…iam.gserviceaccount.com` in `infra/environments/staging/service-accounts.tf`, grant `roles/cloudkms.cryptoKeyEncrypterDecrypter` (clinical only), `roles/cloudsql.client`, `roles/secretmanager.secretAccessor` on relevant secrets. Migrate the Cloud Run services off the default compute SA. billing-svc already has its own SA — verify.
- **GCS bucket CORS** terraform — add CORS rules to `${PROJECT}-audio-uploads` allowing `https://app.superwizor.ai` + localhost dev origins for `PUT, OPTIONS`. Without this, browser uploads to V4 signed URLs die at the pre-flight.
- **Social-login provider configuration** (per R7 / §6.5):
  - **Firebase Console** → Authentication → Sign-in method → enable Google, Apple, Microsoft. Add authorized redirect URIs for staging (`superwizor.ai`, `app.superwizor.ai`) + dev (`localhost:3000`, `localhost:8080`).
  - **Firebase Console** → Authentication → Settings → enable "**Link accounts that use the same email**" (one-account-per-email, avoids duplicate UIDs on cross-provider sign-in with the same address).
  - **Google**: reuse the existing OAuth 2.0 client in Google Cloud Console; only add the four new authorized redirect URIs above.
  - **Apple**: create a Services ID + sign-in-with-Apple key in the Apple Developer portal (one-time, ~15 min, requires a paid Apple Developer account). Paste the team ID, service ID, key ID, and private key into Firebase Console. Document the steps in `docs/agents/01_identity-svc.md` for the next operator.
  - **Microsoft**: register an app in Microsoft Entra ID (Azure AD). Application type "Web". Add the same redirect URIs. Copy app (client) ID + a client secret into Firebase Console.
  - Add a `docs/agents/01_identity-svc.md` section describing how to rotate the Apple key (yearly) and the Microsoft client secret.
- Bootstrap: one-time SQL to mark a known email as `SUPERWIZOR_ADMIN` (`UPDATE users SET role='SUPERWIZOR_ADMIN' WHERE email=...`). Document the procedure in `docs/agents/01_identity-svc.md`.

**Slice 2 — Next.js marketing + registration** (week 2)
- Scaffold `marketing-site/` with Next.js App Router + Tailwind + brand tokens
- `/`, `/pricing`, `/register/therapist`, `/register/organization`, `/login`, legal pages
- Connect-RPC client wiring, Firebase Auth SDK init
- Firebase Hosting deploy in CI

**Slice 3 — Flutter Web therapist console** (week 2-3, parallel)
- `flutter create --platforms web .` in flutter-app/superwizor
- `kIsWeb` branches for: recording (hidden), file picker, image picker, Hive→IndexedDB
- Firebase Hosting deploy in CI
- End-to-end smoke: login → see kartoteki → open transcript → view report

**Slice 4 — Flutter Web org-admin tab** (week 3)
- New route `/admin` in Flutter Web (Riverpod-gated on `role == 'ORG_ADMIN'`)
- Therapists list + invite + remove screens
- Org billing view (read-only)
- Email template for invite (notification-svc adds a new template)

**Slice 5 — Next.js admin panel** (week 4)
- `/admin/orgs` list, detail, actions
- Audit log viewer
- Onboard the Superwizor team (mark emails as SUPERWIZOR_ADMIN)

**Slice 6 — polish & launch** (week 5)
- **i18n complete** per §14:
  - Next.js: install `next-intl`, enable `as-needed` routing, create `messages/pl.json` + `messages/en.json` with full coverage for marketing + admin copy; wire `hreflang` alternates.
  - Flutter Web: verify the existing `app_pl.arb` / `app_en.arb` compile under the web target; add any new keys for the web-only finish-profile pages.
  - `notification-svc`: add PL + EN templates for invitation, email-verification, and quota-warning emails under `internal/i18n/templates/{pl,en}/`. Wire recipient `users.ui_language` lookup.
  - CI: add `scripts/check-l10n-parity.sh` (compares the shared key subset between ARB and `messages/pl.json`); extend §13.11 drift test to assert every form label has a matching i18n key.
- Empty states, loading skeletons, error toasts (each maps an error code → translation, never a backend string).
- Cypress / Playwright happy-path E2E test (run once per locale).
- Production DNS cutover.

---

## 11. Open questions for later

- **Stripe wiring**: registration flows currently land users on Trial. Paid plan checkout (SOLO/PRO/CLINIC) is gated by the existing billing-svc Stripe stub becoming real. Not blocking web launch — Trial is enough for MVP.
- **Multi-tenant data residency**: PG schema is single-region (europe-central2). No change needed for web — but if EU clinics demand DE/FR hosting we'd add it as a separate Cloud SQL instance with the same schema. Future.
- **Web PWA push notifications**: Firebase Cloud Messaging works on web but needs a service worker + HTTPS + user permission. Defer to v2; FCM push is a "nice to have" for desktop and not on critical path.
- **Org-level analytics dashboard**: separate from admin — org admin sees their own clinic's metrics. Builds on `analytics-svc` (currently mostly absent). Defer.
- **SSO / Google login**: nice for clinics (less password fatigue) but Firebase Email/Password is enough for v1. Add Google as a second Firebase provider when a sales conversation demands it.
- **Founder dual-role v2**: if customer feedback shows the "invite-yourself" workaround for clinic founders is annoying, the path forward is a `user_role_grants` junction table + a "Switch role" menu. Active role would be stamped into the ID-token custom claims at login (or chosen via a role picker). Until then the singular `users.role` model holds.
- **Shared-machine warning UX**: how aggressive should the "you're on a shared computer" footer warning be in Flutter Web? Heuristic, browser-fingerprint-based detection is approximate. Likely a single-line login-screen notice + a clear logout shortcut.

## 11.1 Resolved by the v0.1 → v0.2 design review

- ~~Multi-role users via JSONB array~~ → singular `users.role` per MVP (R4).
- ~~Cross-domain cookie sync for Firebase Auth between superwizor.ai and app.superwizor.ai~~ → marketing site's Log-in CTA redirects to the app origin (R3).
- ~~Argon2 hashing of invitation tokens~~ → SHA-256 (R5). Argon2 was a CPU-DoS risk for high-entropy random tokens.
- ~~Envoy / grpc-web shim~~ → Connect-RPC handles all three protocols (gRPC, gRPC-Web, Connect) on the same listener; no proxy (R1).
- ~~Default compute SA for clinical-svc / identity-svc on Cloud Run~~ → dedicated per-service SAs land in Slice 1 alongside the new Connect handlers (R6, P2 Zero Trust).
- ~~`idb_shim` to bridge Hive to IndexedDB on web~~ → Hive's stock web target writes to IndexedDB natively.
- ~~Unspecified GCS bucket CORS~~ → terraform CORS rules for `${PROJECT}-audio-uploads` land in Slice 1.
- ~~Email/Password-only auth~~ → Google + Apple + Microsoft OAuth via Firebase plug-ins added (R7). One-account-per-email enabled to prevent duplicate UIDs.
- ~~Unscoped i18n~~ → PL + EN at launch, `next-intl` on Next.js with `as-needed` routing, Flutter Web reuses the existing ARB set; locale resolved as URL prefix → `users.ui_language` → cookie → Accept-Language → `pl` (R9, §14). CI parity check + drift test extension keep translation files in sync with the form catalogue.

---

## 12. Verification

How to know it works:

1. **Backend slice**: `go test ./services/...` green; `grpcurl -plaintext localhost:8080 identity.v1.IdentityService/RegisterOrganization …` returns a Trial subscription; new Connect endpoint reachable via `curl -X POST http://localhost:8080/identity.v1.IdentityService/RegisterOrganization`.
2. **Next.js marketing**: visit `localhost:3000`, fill `/register/therapist`, end up on `app.superwizor.ai` logged in with a usable Trial subscription (verifiable via `psql` and the iOS app showing the same user).
3. **Flutter Web**: `flutter run -d chrome` from `flutter-app/superwizor`; log in with an existing iOS account; see the same kartoteki list; open a session; transcript + report render.
4. **Org-admin flow**: register an org → invite a therapist by email → click link in MailHog (local dev) → set password → therapist lands in the same org's kartoteki list.
5. **Admin panel**: mark your email SUPERWIZOR_ADMIN → log in at `superwizor.ai/admin` → see orgs list → block one → verify the blocked org's user gets a 'subscription past_due' on next API call.
6. **Audit log**: every admin action shows up in `audit_events` with `actor_type='SUPERWIZOR_ADMIN'`, `reason` populated, original payload preserved.
7. **i18n parity**: visit `superwizor.ai` → see Polish; visit `superwizor.ai/en` → same content in English with the correct `<html lang="en">` and `hreflang` alternates. Toggle "Language" in the Flutter Web menu → `UpdateMyProfile` fires, `users.ui_language` flips, next page render is in the new locale. Send a fresh invite while the inviter's `ui_language='en'`: the email body comes from `services/notification-svc/internal/i18n/templates/en/invitation.md`. Run `scripts/check-l10n-parity.sh` locally → exits 0.

---

## 13. Forms catalogue (full CRUD, mapped to data model)

This section is the canonical UI contract for every form on the web. Each field is named exactly as it appears in the form and pinned to the column (or related-table column) in `docs/03_DATA_MODEL.md` §4.1 (Identity). When a form ships, its fields **must** match this list — if the data model gains a column, this doc + the form gain a row in the same PR.

### 13.1 Field types & shared validation rules

| UI control | Backend type | Validation |
|---|---|---|
| **Email** | `VARCHAR(255)` | RFC-5322 pattern (matches `users.chk_users_email_format`); max 255; lowercased before submit. |
| **Password** | (Firebase Auth, not stored in PG) | ≥8 chars, ≥1 letter, ≥1 digit. Firebase enforces server-side; UI mirrors the rule. |
| **Country code** | `CHAR(2)` | ISO 3166-1 alpha-2; UI shows a typeahead dropdown (PL default). |
| **Postal code** | `VARCHAR(20)` | Per-country regex. PL: `^\d{2}-\d{3}$`. Other EU: country-specific lookup table. |
| **Tax ID (NIP)** | `VARCHAR(50)` | PL NIP checksum on PL country; optional otherwise. |
| **EU VAT ID** | `VARCHAR(20)` | Format check only at submit (`^[A-Z]{2}[A-Z0-9]+$`); async VIES validation deferred to v2. |
| **Phone number** | `VARCHAR(20)` | E.164 (`+48…`); UI defaults to PL country code. |
| **UUID FK** | `UUID` | Hidden — never user-typed. Comes from a server-side picker (modality dropdown, address picker). |
| **Enum** | Postgres ENUM | Closed dropdown listing all values for the role-bearing user. |
| **Free text** | `VARCHAR(n)` or `TEXT` | Maxlength enforced client-side; trimmed; rejected if all-whitespace where NOT NULL. |
| **URL** | `VARCHAR(500)` | `^https?://` + valid hostname; max 500. Used for `avatar_url`. |
| **Checkbox** | `BOOLEAN` | Default per data model; ToS is `required=true` on registration forms. |
| **Date / timestamp** | `TIMESTAMPTZ` | Always UTC on the wire; UI renders in user's timezone. |

**Address handling.** Every form that needs an address (org HQ, user billing) presents a flat group of inputs (`country_code`, `region`, `city`, `postal_code`, `street_line`, `building_number`, `unit_number`, `directions`). The RPC accepts a nested `Address` proto; the server creates an `addresses` row in the same transaction as the parent and sets the FK (`organizations.headquarters_address_id` or `users.billing_address_id`). On edit, the RPC re-uses the existing address row and updates it in place — we do **not** create a new `addresses` row per save.

**Soft-delete semantics.** Forms never show `deleted_at`-non-null rows in pickers or lists; cascade-delete is via `users.deleted_at` / `organizations.deleted_at`. Admin "Delete user" hits `AdminDeleteUser` which sets the column, not a `DELETE`.

---

### 13.2 Therapist registration form — `/register/therapist` (Next.js)

Used by individual therapists registering on the marketing site. Submitted via `identity-svc.CreateUser` (with `role=THERAPIST`). Trial subscription auto-provisioned by the existing flow (commit `0a25ac7`).

Two entry paths:
- **Social path** — OAuth pop-up returns email + name pre-filled → "Finish profile" page collects the remaining fields below.
- **Email/password path** — full form below + password + email-verification step.

| Field (UI label PL) | DB column | Required | Notes |
|---|---|---|---|
| Email (Adres e-mail) | `users.email` | ✓ | Locked when arriving from social path. |
| Password (Hasło) | n/a (Firebase Auth) | ✓ for email path | Hidden on social path. |
| First name (Imię) | `users.first_name` | ✓ | Pre-filled from Google/Microsoft display name when available. |
| Last name (Nazwisko) | `users.last_name` | ✓ | Pre-filled from social provider where available. |
| Professional title (Tytuł zawodowy) | `users.professional_title` | optional | e.g. "Psycholog, terapeuta CBT". |
| Credentials number (Numer prawa wykonywania zawodu) | `users.credentials_number` | optional | Free-text; we do not validate against a registry yet. |
| Default modality (Domyślny nurt) | `users.default_modality_id` | ✓ | Dropdown from `clinical-svc.ListModalities` (8 fixed entries). |
| UI language (Język interfejsu) | `users.ui_language` | ✓ (defaults to `pl`) | Radio: Polski / English. |
| Phone number (Telefon) | `users.phone_number` | optional | E.164. |
| Marketing consent (Zgoda marketingowa) | `users.has_marketing_consent` | optional | Default unchecked. |
| ToS acceptance (Akceptuję regulamin) | `users.has_accepted_tos` | ✓ | Default unchecked; submit disabled until ticked. Records `consent_given_at` in `audit_events`. |

Hidden / server-derived: `role=THERAPIST`, `firebase_uid` from token, `is_email_verified` from Firebase claim, `created_at`, `organization_id` (NULL for solo therapists), `timezone` (auto-detect via browser; defaults to `Europe/Warsaw`).

**Not collected at signup** (set later via Settings): biography, avatar_url, billing_address_id.

---

### 13.3 Organization registration form — `/register/organization` (Next.js)

Used by clinic founders. Submitted via `identity-svc.RegisterOrganization`. Creates the organisation, founder user (`role=ORG_ADMIN`), Trial subscription, and the headquarters address — all in one transaction.

| Field (UI label PL) | DB column | Required | Notes |
|---|---|---|---|
| **Section: Founder account** | | | |
| Email (Adres e-mail) | `users.email` | ✓ | Will be the ORG_ADMIN account. |
| Password (Hasło) | n/a (Firebase) | ✓ for email path | |
| First name (Imię) | `users.first_name` | ✓ | |
| Last name (Nazwisko) | `users.last_name` | ✓ | |
| Phone number (Telefon kontaktowy) | `users.phone_number` | ✓ | Required for org admin so we can reach billing contacts. |
| **Section: Organization** | | | |
| Legal name (Nazwa firmy) | `organizations.legal_name` | ✓ | As registered for invoicing. |
| Organization type (Typ organizacji) | `organizations.type` | ✓ | Dropdown: `SOLO` / `CLINIC` / `ENTERPRISE`. Founder picks `CLINIC` by default on this form. |
| Tax ID — NIP (NIP) | `organizations.tax_id` | ✓ for PL | NIP checksum. |
| EU VAT ID (VAT-UE / EU VAT ID) | `organizations.vat_id_eu` | optional | Required only for cross-border invoicing. |
| **Section: Headquarters address** (new `addresses` row) | | | |
| Country (Kraj) | `addresses.country_code` | ✓ | ISO alpha-2; defaults to `PL`. |
| Region / voivodeship (Województwo) | `addresses.region` | optional | Free text in v1; future: closed list per country. |
| City (Miasto) | `addresses.city` | ✓ | |
| Postal code (Kod pocztowy) | `addresses.postal_code` | ✓ | PL format `00-000`. |
| Street (Ulica) | `addresses.street_line` | ✓ | |
| Building number (Numer budynku) | `addresses.building_number` | ✓ | |
| Unit number (Numer lokalu) | `addresses.unit_number` | optional | |
| Directions / notes (Wskazówki dojazdu) | `addresses.directions` | optional | Free `TEXT`. |
| **Section: Consents** | | | |
| Marketing consent | `users.has_marketing_consent` | optional | |
| ToS acceptance | `users.has_accepted_tos` | ✓ | |

Hidden / server-derived: founder `role=ORG_ADMIN`, founder `organization_id=<new org id>`, `organizations.primary_admin_user_id=<founder user id>`, `organizations.headquarters_address_id=<new address id>`. Trial subscription auto-provisioned with the same `0a25ac7` shape (3 tokens, MANUAL billing source).

UI shows the standing notice (per §6.3): "After signup you'll be the clinic administrator. To also record sessions, invite a second email from the Therapists tab once you're in."

---

### 13.4 Therapist profile edit form — Settings → Profile (Flutter Web; mirrors iOS)

Bound to `identity-svc.UpdateMyProfile`. Same surface as the iOS app's `menu_screen.dart` profile sheet — extended here with everything in the data model. Iconography lifted from the existing widgets (`profile_edit_sheet.dart`).

| Field (UI label PL) | DB column | Editable by therapist | Notes |
|---|---|---|---|
| Email | `users.email` | ✗ (read-only) | Tied to Firebase Auth; change flow is a separate ADR (re-verify + Firebase Admin SDK). |
| First name | `users.first_name` | ✓ | |
| Last name | `users.last_name` | ✓ | |
| Phone number | `users.phone_number` | ✓ | |
| Professional title | `users.professional_title` | ✓ | |
| Credentials number | `users.credentials_number` | ✓ | |
| Biography | `users.biography` | ✓ | `TEXT`; maxlength 2000 on UI. |
| Avatar | `users.avatar_url` | ✓ | Uploads via `<input type="file" accept="image/*">` → Firebase Storage → returned URL written to column. |
| Default modality | `users.default_modality_id` | ✓ | Dropdown. |
| UI language | `users.ui_language` | ✓ | |
| Timezone | `users.timezone` | ✓ | IANA list, autocomplete. |
| Marketing consent | `users.has_marketing_consent` | ✓ | |
| Billing address | `users.billing_address_id` → addresses.* | ✓ | Optional sub-form; same 8 address fields as §13.3. Used for personal invoicing (solo therapists). |

Hidden / never editable: `id`, `firebase_uid`, `role`, `organization_id`, `is_email_verified`, `has_accepted_tos`, `created_at`, `deleted_at`.

---

### 13.5 Organization profile edit form — Org-admin → Settings (Flutter Web)

Bound to `identity-svc.UpdateMyOrganization`. Org-admin only. Same address sub-form as §13.3.

| Field | DB column | Editable | Notes |
|---|---|---|---|
| Legal name | `organizations.legal_name` | ✓ | |
| Organization type | `organizations.type` | ✓ | `SOLO` / `CLINIC` / `ENTERPRISE`. Changing this does not auto-migrate billing plan; surface a warning. |
| Tax ID (NIP) | `organizations.tax_id` | ✓ | |
| EU VAT ID | `organizations.vat_id_eu` | ✓ | |
| Headquarters address | `organizations.headquarters_address_id` → addresses.* | ✓ | All 8 address fields; updates the existing row. |
| Primary admin | `organizations.primary_admin_user_id` | ✓ | Picker scoped to users in this org with `role=ORG_ADMIN`. Used for transfer-of-ownership. |

Hidden: `id`, `created_at`, `deleted_at`. The therapist-list, invite-therapist, and remove-therapist controls live in the separate Therapists tab (§8.4) — they share the same screen group but are not part of the org-profile form.

---

### 13.6 Invite therapist form — Org-admin → Therapists → Add

Bound to `identity-svc.InviteTherapist`. Minimal — just kicks off the magic-link flow from §9.

| Field | DB column (on accept) | Required | Notes |
|---|---|---|---|
| Email | `users.email` | ✓ | The invited person's mailbox. |
| First name (suggested) | `users.first_name` | optional | Pre-populates the accept-invite page; the invitee can edit. |
| Last name (suggested) | `users.last_name` | optional | Same. |
| Default modality (suggested) | `users.default_modality_id` | optional | Same. |

The invitee completes the rest (password, ToS) on `/accept-invite`. On the org-admin side, the invite stays in `invitations` until accepted.

---

### 13.7 Admin: organization detail / edit — Superwizor admin (Next.js)

Bound to `identity-svc.AdminUpdateOrganization` (+ `billing-svc.AdminResetTokens` / `AdminChangePlan` for billing actions). All mutations require a `reason` field; the server writes `audit_events` with `actor_type=SUPERWIZOR_ADMIN`.

| Field | DB column | Editable by Superwizor admin | Notes |
|---|---|---|---|
| Legal name | `organizations.legal_name` | ✓ | |
| Type | `organizations.type` | ✓ | |
| Tax ID, EU VAT ID | `organizations.tax_id`, `organizations.vat_id_eu` | ✓ | |
| Headquarters address | `organizations.headquarters_address_id` → addresses.* | ✓ | |
| Primary admin user | `organizations.primary_admin_user_id` | ✓ | For ownership reassignment under support. |
| Status (blocked / active) | `subscriptions.status` (`PAST_DUE` for block) | ✓ | Toggle. Writes audit. |
| Plan tier | `subscriptions.plan_tier` | ✓ | Calls `billing-svc.AdminChangePlan`. |
| Token override | `usage_counters.tokens_used`, `tokens_limit` | ✓ | Calls `billing-svc.AdminResetTokens`. |
| Reason (always required) | `audit_events.reason` | ✓ | Free text, ≥10 chars. |

Read-only side panel: therapists count, last session timestamp, billing source, period start/end, recent audit entries.

---

### 13.8 Admin: user detail / edit — Superwizor admin (Next.js)

Bound to `identity-svc.AdminUpdateUser` / `AdminDeleteUser`. Supports the common support cases: fix a typo'd email, change a role, soft-delete a spam account.

| Field | DB column | Editable | Notes |
|---|---|---|---|
| Email | `users.email` | ✓ | Triggers Firebase re-verification on save. Audit. |
| First name, last name | `users.first_name`, `users.last_name` | ✓ | |
| Phone number | `users.phone_number` | ✓ | |
| Role | `users.role` | ✓ | Restricted: can promote/demote between THERAPIST / ORG_ADMIN / SUPERWIZOR_ADMIN; cannot change to/from PATIENT. |
| Organization | `users.organization_id` | ✓ | Picker; transfer between orgs is a support escape hatch. |
| Default modality | `users.default_modality_id` | ✓ | |
| UI language, timezone | `users.ui_language`, `users.timezone` | ✓ | |
| Professional title, credentials, biography, avatar | `users.professional_title` etc. | ✓ | |
| Billing address | `users.billing_address_id` → addresses.* | ✓ | |
| Email verified | `users.is_email_verified` | ✓ | Force-mark verified (support escape). |
| Soft-delete | `users.deleted_at` | ✓ via `AdminDeleteUser` | Sets the column; record stays for audit. |
| Reason | `audit_events.reason` | ✓ | Required. |

Read-only side panel: `firebase_uid`, `id`, `created_at`, `has_accepted_tos`, `has_marketing_consent`, recent session count, last sign-in.

---

### 13.9 Field-coverage cross-check

Every column on `users` and `organizations` is editable somewhere — none are write-once-and-forgotten unless flagged below:

| Column | Surface | Notes |
|---|---|---|
| `users.role` | Admin (§13.8) only | Therapists/founders cannot self-promote. |
| `users.firebase_uid`, `users.id`, `users.created_at`, `users.deleted_at` | Nowhere | Server-managed lifecycle. |
| `users.is_email_verified` | Verification email flow + Admin (§13.8) | Read elsewhere, written by Firebase callback or Admin escape. |
| `users.has_accepted_tos` | Registration only | Cannot revoke without account deletion; documented in ToS. |
| `organizations.id`, `organizations.created_at`, `organizations.deleted_at` | Nowhere | Lifecycle. |
| Everything else on `users` / `organizations` / `addresses` | At least one editable form above | ✓ |

---

### 13.10 Validation + error UX

- All forms use **inline field-level errors** (red text under the field) for client-side validation. Server-side validation errors (`InvalidArgument` from a Connect-RPC) map to the same fields by name when the gRPC error embeds a `field` value; otherwise they surface as a top-of-form banner.
- Required fields are marked with a `*` in the label; submit button is disabled until all required + valid.
- Forms support `Cmd/Ctrl+Enter` to submit.
- All mutation forms accept an `Idempotency-Key` header (UUID v4 generated at form load) — pinned per submission attempt, regenerated after success/cancel. Backend `pkg/idempotency` already supports it on identity-svc and billing-svc.
- Optimistic UI: profile + org edits update the local cache immediately, then `await` the RPC and roll back on error with a toast.

---

### 13.11 Drift-prevention contract

To prevent the data model and the form catalogue diverging:

1. Every migration that touches `users`, `organizations`, or `addresses` MUST update §13 in the same PR — add or remove rows in the relevant table.
2. CI lint step (post-Slice-1): a Go test under `services/identity-svc/internal/...` reads §13 markdown, parses the "DB column" cells, and asserts every listed column exists in the live schema (`information_schema.columns`). Catches a missing migration or a stale doc.
3. The same test also asserts the reverse: every non-system column on those three tables appears at least once in §13 (with the explicit exception list in §13.9).

---

## 14. Internationalisation (i18n) — PL + EN at launch

The Flutter iOS app already supports two locales via `flutter_localizations` + `gen_l10n` driven from `flutter-app/superwizor/lib/l10n/app_pl.arb` and `app_en.arb`. The web app must hit the same bar from day one — Polish primary, English secondary — and the two codebases must agree on locale resolution so a user who sets `ui_language=en` on iOS sees English on the web too.

### 14.1 Supported locales (MVP)

| Code | Display name | Status at launch | Fallback |
|---|---|---|---|
| `pl` | Polski | ✓ Primary | — |
| `en` | English | ✓ Secondary | `pl` for any missing key during initial rollout |

Future locales (DE, FR, ES) get added as new ARB / JSON files; no code structural change.

### 14.2 Stack

**Next.js (marketing + admin):** [`next-intl`](https://next-intl-docs.vercel.app/) — App Router native, supports server-side rendering with the right locale on first byte (essential for SEO), middleware-based locale routing, no client-side flash of fallback content.

**Flutter Web (therapist + org-admin consoles):** the existing `flutter_localizations` + `gen_l10n` setup compiles unchanged for the web target. The same `AppLocalizations` class works in browser. No additional dependency.

**Translation files:**
- iOS + Flutter Web: `flutter-app/superwizor/lib/l10n/app_{pl,en}.arb` (unchanged).
- Next.js: `marketing-site/messages/{pl,en}.json` — same key namespacing as the ARB files where copy is shared (e.g. `auth.login_button`, `quota.warning_banner`). New keys for marketing-only copy (landing hero, pricing table, legal-page anchors) live alongside.

We do not deduplicate the two sources programmatically in v1 — it's two small files in two languages and the overhead of a shared translation pipeline would dwarf the duplication. A 50-line `scripts/check-l10n-parity.sh` in CI compares the *key sets* of `app_pl.arb` ∩ `messages/pl.json` (shared subset) to flag drift; copy values are free to differ per-platform when needed.

### 14.3 Locale resolution order

Both web codebases resolve the active locale via the same precedence — the first source that yields a supported locale wins:

1. **URL prefix** (Next.js: `/en/register/therapist`; Flutter Web: `?lang=en` query param or a localised route prefix when we adopt one).
2. **Authenticated user's `users.ui_language`** — fetched in the same `GetMyProfile` round-trip the app already makes on cold start. Re-fetched after `UpdateMyProfile` toggles the language.
3. **Persisted cookie** (`SUP_LOCALE`, HttpOnly, 1-year TTL, set on first successful resolution) — survives logout / new device.
4. **`Accept-Language` HTTP header** — first match against `[pl, en]`.
5. **Hardcoded fallback: `pl`** (primary market).

The marketing site is publicly browsable, so steps 1, 3, 4, 5 apply for unauthenticated visitors. The therapist console gates on auth, so step 2 kicks in immediately after sign-in and overrides everything below it.

### 14.4 URL strategy (Next.js)

`next-intl` middleware exposes one of two routing modes:

- **`as-needed`** (chosen) — default locale (`pl`) has no prefix (`/register/therapist`); non-default locales get a prefix (`/en/register/therapist`). Best for SEO on the primary market and avoids forcing a redirect on the typical PL visitor.
- `always` — every locale prefixed, including default. Cleaner but breaks current Polish marketing-page URLs.

We pick `as-needed`. Marketing pages get `hreflang` alternate links in `<head>` so Google indexes both versions cleanly.

Flutter Web does **not** mirror this. Its routes (`/login`, `/home`, `/admin/...`) are app-private and SEO doesn't apply; the locale lives in user state, not the URL. A "Language" switcher in the menu (already in Flutter) sets `users.ui_language` via `UpdateMyProfile` and the UI rebuilds.

### 14.5 i18n contract — what gets translated where

| Content | Owner | Source files |
|---|---|---|
| Form field labels (§13 forms) | Each frontend | Next.js: `messages/{pl,en}.json` ; Flutter Web: existing ARB |
| Form validation messages | Each frontend | Same. **Never** rendered from a backend string. |
| RPC error messages | Each frontend (codes → translations) | Backend returns stable error codes (`QUOTA_EXHAUSTED`, `SUBSCRIPTION_PAST_DUE`, `INVITATION_EXPIRED`, `EMAIL_ALREADY_REGISTERED`, …); the frontend maps. |
| Marketing copy (hero, pricing, legal) | Next.js | `messages/{pl,en}.json` |
| Admin-panel copy (Next.js admin) | Next.js | `messages/{pl,en}.json` |
| Email subjects + bodies (invitation, email verification, quota warning) | `notification-svc` | `services/notification-svc/internal/i18n/templates/{pl,en}/*.md` |
| PWA manifest `name` + `short_name` + `description` | Each web build | One manifest per locale; served from the appropriate URL prefix. |

Backend strings policy stays unchanged from the iOS app: codes not text. The only place where backend produces translated copy is `notification-svc` for emails / FCM pushes — and that path already reads `users.ui_language` of the *recipient* to pick the template.

### 14.6 Date, number, and currency formatting

- Dates / times — `Intl.DateTimeFormat(locale)` in TS, `DateFormat.yMd(locale)` / `DateFormat.Hm(locale)` in Dart. PL renders `DD.MM.YYYY`, `HH:mm`; EN renders `MMM d, yyyy`, `h:mm a`.
- Numbers — `Intl.NumberFormat(locale)`. PL: comma decimal, space thousand separator. EN: dot decimal, comma thousand.
- Currency — same `Intl.NumberFormat(locale, {style: 'currency', currency: ...})`; staging is PLN-only. The `subscription_plans.currency_code` column already lets us add EUR/USD later without code change.
- Timezones — stored UTC, rendered via the user's `users.timezone` (default `Europe/Warsaw`). The browser's local time zone is *not* used for therapy-related timestamps; users explicitly set their tz in Settings.

### 14.7 Email templates (notification-svc)

The invitation email + email-verification email + future quota-warning push all use a small Markdown template engine in `services/notification-svc/internal/i18n/`. Each template has one file per locale under `templates/{locale}/<event>.md` with a frontmatter block:

```yaml
---
subject: "Zostałeś zaproszony do {orgName}"
---

Witaj {firstName},

Twój kolega z {orgName} zaprasza Cię do dołączenia jako terapeuta.
Aby utworzyć konto, kliknij ten link:

{acceptUrl}

Link wygaśnie {expiresAt}.
```

Recipient-locale resolution: when sending an invite, the worker looks up the recipient's `users.ui_language` if a user row already exists; otherwise it falls back to the inviter's `users.ui_language` (clinic context); otherwise `pl`. Same pattern for quota warnings.

### 14.8 i18n implications in §13 (forms)

The form tables in §13 list Polish labels in parentheses (e.g. "Email (Adres e-mail)") for illustration only. Production code does **not** hardcode these — every label is a key in the ARB or `messages/*.json` file. If we add a French locale, no PR touches §13: only the translation files get a new entry per existing key.

The CI drift test in §13.11 is extended (R9 follow-up): a second pass parses §13 labels and asserts a matching i18n key exists in `messages/pl.json` (Next.js forms) or `app_pl.arb` (Flutter Web forms). Missing translation → CI fail.

### 14.9 Open questions

- **Non-EU language priority**: the next locale to add — UK English is already covered, US English is essentially the same (date formats differ; we'd add a sub-region locale if pricing demands it). German + French likely first.
- **In-app live language switch without reload**: Flutter handles this natively. Next.js with `next-intl` requires a full navigation to a new locale-prefixed route — acceptable for marketing pages. The admin/console UI is Flutter Web anyway.
- **Locale-aware NIP / VAT validation**: today §13.1 is PL-centric (NIP checksum, `00-000` postal regex). When DE/FR launch, those rules become country-conditioned. Schema already supports it (`addresses.country_code` is the source of truth); just the validators need to be country-keyed.
