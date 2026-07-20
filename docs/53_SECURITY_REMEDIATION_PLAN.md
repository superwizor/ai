---
type: Technical Design
title: "53. Security Remediation & Service-Auth Architecture Plan"
description: "Original: 2026-06-13 (authored on feat/web-app after a full fan-out review). Refreshed: 2026-07-05 — re-verified every finding against the current main by a ..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/53_53_SECURITY_REMEDIATION_PLAN.md
tags: [service, security]
timestamp: 2026-07-05T16:49:53+02:00
---

# 53. Security Remediation & Service-Auth Architecture Plan

**Original:** 2026-06-13 (authored on `feat/web-app` after a full fan-out review).
**Refreshed:** 2026-07-05 — re-verified every finding against the **current
`main`** by a 26-agent fan-out re-audit (verify → adversarial confirm → fix plan),
each with file:line evidence.

> ⚠️ **Status correction.** The 2026-06-13 header claimed "Phases 1–4
> IMPLEMENTED". That was true only on the `feat/web-app` branches
> (`fix/phase1-service-auth`, `fix/phase2-4-hardening`) — **those fixes never
> merged into `main`**, which is the branch this codebase now ships from. The
> re-audit found **all 4 Criticals and all 3 Highs OPEN in current `main`**, i.e.
> live in the deployed services. Treat this document as the *to-do*, not a
> record of done work.

---

## 1. Executive summary

Root cause is unchanged and still correct: six Cloud Run services run with the
`allUsers` invoker (`infra/environments/staging/service-accounts.tf`), so **Cloud
Run IAM is not an auth gate** — yet several RPCs were written assuming it is. The
`allUsers` binding is **deliberate and must stay** (browsers and Flutter-Web call
these services directly; the CORS preflight must reach the app, not be 403'd by
IAM). The fix is **application-layer auth, per-RPC, fail-closed** — not IAM
lockdown. See §6 for the target architecture (the auth-class model the fixes
implement) and §7 for the backward-compat proof (clients already send the tokens;
services just ignore them today, so **all Critical/High fixes are server-side, no
client release**).

What changed since the original: only **#16** (dead Next.js `/api/checkout` +
`/api/admin/crm` proxies) is now fixed — the routes were migrated to Go (commit
`3196f97`) and deleted. Everything else the original flagged as "implemented" is,
in fact, still open on `main`.

---

## 2. Verified severity table — current `main` (2026-07-05)

| # | Sev | Component | Issue | Verified status | Fix effort |
|---|-----|-----------|-------|-----------------|-----------|
| 1 | 🔴 Critical | ingestion-svc | `grpc.NewServer()` with **zero** interceptor; trusts `req.therapist_id` → PHI IDOR, arbitrary GCS writes, paid STT/LLM abuse | **OPEN** (main.go:143; server.go:117) | M |
| 2 | 🔴 Critical | billing-svc | Native-gRPC path unauthenticated; `resolveAdminCaller` trusts client `x-superwizor-role` → SUPERWIZOR_ADMIN escalation | **OPEN** (main.go:132/219) | M |
| 3 | 🔴 Critical | notification-svc | `Send*` email RPCs unauthenticated on `allUsers` svc → open phishing relay + Resend cost-bomb | **OPEN** (main.go:129; invitation_email.go) | M |
| 4 | 🔴 Critical | repo/infra | Live Postgres password committed in 5 tracked files + tfstate backups; `sa-key.json`/`.env.production` tracked | **OPEN** (`git grep Zjee` → 5 files) | S |
| 5 | 🟠 High | billing-svc | `GetSubscription`/`ListInvoices` cross-org IDOR — scope check **fails open** on empty caller-org | **OPEN** (server.go:829-841) | S |
| 6 | 🟠 High | clinical + ai-pipeline | PHI crypto **fails open to cleartext MockBox** when `KMS_KEY_URI` unset; no prod guard | **OPEN** (clinical main.go:177-188 + workers) | S |
| 7 | 🟠 High | ingestion-svc | No max size signed into GCS URL; `estimated_size_bytes` unvalidated → unbounded storage/cost DoS | **OPEN** (signer.go:122-163) | M |
| 8 | 🟡 Med | billing-svc | `ConnectAuthInterceptor` conditional → fails open if `IDENTITY_SVC_URL` unset | **OPEN** (main.go:186-192) | S |
| 9 | 🟡 Med | pkg/connectmd | Copies client `x-superwizor-*` into trusted gRPC metadata (escalation primitive behind #2/#5/#8) | **OPEN** (interceptor.go:114-132) | S |
| 10 | 🟡 Med | marketing-site | Open redirect via `continueUrl` (`window.location.replace`, no allowlist) → branded phishing | **OPEN** (AuthActionContent.tsx:157/179/198/493) | S |
| 11 | 🟡 Med | hosting | No HSTS, no CSP on either hosting target | **OPEN** (firebase.json) | S |
| 12 | 🟡 Med | 4 Go services | gRPC reflection registered unconditionally on public services | **OPEN** (ingestion/clinical/identity/notification main.go) | S |
| 13 | 🟡 Med | notification-svc | HTML injection into emails — action-plan/invitation bodies not escaped (only `contact_email.go` fixed) | **OPEN** (action_plan_email.go:44-127) | S |
| 14 | 🟢 Low | notification/identity | Invite-resend has no rate limit (email-bomb / Resend cost; auth'd org-admin only) | **OPEN** (invitations.go:226) | S |
| 15 | 🟢 Low | billing-svc | `/contact` no body-size limit + no captcha verify | **OPEN** (contact_handler.go:50-55) | S |
| 16 | 🟢 Low | marketing-site | Dead insecure `/api/checkout` + `/api/admin/crm` proxies | **✅ FIXED** (routes migrated to Go, commit `3196f97`) | — |
| 17 | 🟢 Low | identity-svc | User emails (PII) logged at INFO in `ValidateToken` (fires every app launch) | **OPEN** (server.go:108, 133-134) | S |
| 18 | 🟢 Low | repo | `.gitignore` gaps: `sa-key.json`, `.env.production` (force-unignored), `*.tfstate*` all tracked | **OPEN** (root + marketing-site `.gitignore`) | S |
| 19 | 🟢 Low | billing-svc | `fmt.Sprintf`-into-SQL in CRM follow-ups | **PARTIAL** — construct remains (crm_handler.go:179) but only constant literals interpolated → not exploitable today | S |

Verified-sound (do not regress): Stripe webhook HMAC (fail-closed), CORS exact-match,
Firestore/Storage rules, `pkg/cryptobox` primitives, invitation tokens, clinical-svc &
identity-svc token gating, FCM RPC auth.

---

## 3. Proposed PRs — Criticals (P0, ship first)

Each is **server-side only, backward-compatible** (§7), with allow+deny unit tests
(fake validator, no network) per the "proof before passing" rule. Order by
blast-radius.

### PR‑A — #4 Remove committed DB password + fix `.gitignore` (effort S, do first)
**Why first:** the live `superwizor_app` Postgres password is in the tree *right now*
(`git grep -l Zjee` → `check_db.go`, `scripts/seed_demo_user.go`,
`billing-svc/.../stripe_handler_test.go`, 2 `terraform.tfstate.*.backup`).
- Replace the hardcoded `postgres://…:Zjee…@` URLs with `os.Getenv("DATABASE_URL")`
  (+ `os.Exit(1)`/`t.Skip` guards) — mirrors the existing `db_check.go` pattern.
- `git rm --cached` the two tfstate backups, `sa-key.json`, `marketing-site/.env.production`.
- Fix `.gitignore`: root add `sa-key.json`, `.env.production`, `**/*.tfstate*`; replace
  the ineffective `*.tfstate.backup` with `*.tfstate.*` / `terraform.tfstate.*.backup`;
  drop the `!.env.production` un-ignore in `marketing-site/.gitignore`.
- **Owner action (out-of-band, cannot be done in code):** rotate the password in GCP
  Secret Manager + the Cloud SQL role, and restrict the Cloud SQL `authorized_networks`
  (public IP `34.118.34.144` was also exposed). The secret persists in git history —
  rotation is what actually protects you (runbook §5).
- CI guard: fail the build on any `postgres://user:pass@` literal in tracked files.

### PR‑B — #9 + #2 + #8 billing-svc native-gRPC auth + connectmd strip (effort M)
The native gRPC path (`application/grpc` → `gs.ServeHTTP`) has **no interceptor**, and
`connectmd` copies client `x-superwizor-role` straight into the metadata
`resolveAdminCaller` trusts — so an anonymous internet caller can invoke
`AdminChangePlan`/`AdminResetTokens`/`AdminSetSeatAllocations` with a forged role.
- **#9 first (underpins 2/5/8):** in `pkg/connectmd/injectMetadata` drop inbound headers
  whose key starts `x-superwizor-` before copying to gRPC metadata. Trusted interceptors
  set them explicitly afterward.
- **#2:** add a native `UnaryAuthInterceptor` (mirror clinical-svc): for non-allowlisted
  methods, validate the Firebase Bearer via `identity.ValidateToken` and **rebuild fresh
  metadata** from the result (never merge inbound). Health/reflection allowlisted; `Admin*`
  and `GetMyOrgSeatUsage` never anonymous. Wire at `main.go:132`
  `grpc.NewServer(grpc.UnaryInterceptor(...))`.
- **#8:** make the Connect interceptor unconditional/fail-closed — when `IDENTITY_SVC_URL`
  is unset, still install it and reject (guard any insecure path behind an explicit,
  never-in-prod `BILLING_ALLOW_INSECURE_GRPC`).
- Tests: forged-header-no-token `AdminChangePlan` → Unauthenticated; THERAPIST token →
  PermissionDenied; SUPERWIZOR_ADMIN token → OK with role from token even when a
  conflicting header is sent; connectmd unit test asserts inbound `x-superwizor-*` dropped.

### PR‑C — #1 ingestion-svc Firebase auth + ownership (effort M)
`grpc.NewServer()` has no interceptor and `therapist_id = uuid.Parse(req.TherapistId)` —
any reachable caller mints a GCS signed-PUT URL under any therapist's path, creates rows
under a victim, and drives paid STT/LLM `ReserveCredit` against any org.
- Add `UnaryAuthInterceptor` (port clinical-svc's) validating the Firebase token; anon
  allowlist = health/reflection only.
- In `CreateAudioUpload`, derive `therapist_id` from the verified token, **ignore/reject**
  `req.TherapistId`; add a `GetPatientFileOwner` query and `PermissionDenied` if the
  `patient_file_id` isn't the caller's.
- In `GetAudioUploadStatus`, return `NotFound` for another therapist's upload (no oracle).
- Tests: anon → Unauthenticated; cross-owner `patient_file_id` → PermissionDenied;
  status of another's upload → NotFound; happy path derives id from token.

### PR‑D — #3 notification-svc internal OIDC gate on `Send*` (effort M)
`Send*` email RPCs have no auth on an `allUsers` service → open phishing relay + Resend
cost-bomb.
- Add a unary interceptor: `Send*` methods → require a valid Google **OIDC** token
  (`idtoken.Validate(aud = own URL)`) whose `email` ∈ `INTERNAL_ALLOWED_SA`
  (clinical/identity/billing SAs) with `email_verified`. FCM/health RPCs pass through
  (keep their Firebase auth). Fail-closed if `OIDC_AUDIENCE` unset in prod.
- Callers already mint OIDC `aud = notification URL` today — no caller change.
- Tests: internal method + allow-listed OIDC → handler runs; no token → Unauthenticated;
  wrong caller → PermissionDenied; FCM passthrough preserved. Use an injected fake validator.

---

## 4. Proposed PRs — Highs (P1)

### PR‑E — #5 billing-svc cross-org IDOR (effort S)
`GetSubscription` rejects only when `callerOrgID != "" && callerOrgID != req.org && role != ADMIN`
— **fails open when the caller has no org** (a THERAPIST/PATIENT unattached to an org can
read any org's subscription by passing an arbitrary `organization_id`).
- Bind the browser-caller query to the **token** org (mirror `orgIDFromContext`, which
  already fails closed). For non-admin browser callers: `callerOrgID == "" ||
  callerOrgID != req.org` → `PermissionDenied`. ADMIN → any org. Native S2S (no role
  header) → unchanged. Apply identically to `ListInvoices`.
- Tests (5, mirrored for ListInvoices): empty-org THERAPIST → deny (regression guard);
  org A→B → deny; A→A → allow; ADMIN → allow; native S2S → allow.

### PR‑F — #6 crypto fail-closed (effort S)
clinical-svc + stt/llm workers silently fall back to cleartext `MockBox` when
`KMS_KEY_URI` is unset — a misconfigured prod would persist recoverable-cleartext PHI.
- New `pkg/cryptobox.FromEnv(ctx)`: real KMS when `KMS_KEY_URI` set; `MockBox` **only** if
  `ALLOW_MOCK_CRYPTO=true` (with a loud warn); otherwise **hard error**. Call sites
  `os.Exit(1)` on error. Set `ALLOW_MOCK_CRYPTO=true` for local/CI compose.
- Tests: empty URI + no opt-in → error (nil box); `ALLOW_MOCK_CRYPTO=true` → MockBox;
  URI set → real-KMS branch.

### PR‑G — #7 ingestion upload size cap (effort M)
Signed PUT URL carries no size bound; `estimated_size_bytes` only picks a TTL.
- Sign `x-goog-content-length-range: 0 <MAX>` into the URL (GCS enforces); validate
  `estimated_size_bytes` in `[1, MAX]` (0 is a current bypass); `OBJECT_FINALIZE`
  subscriber deletes + marks FAILED any object over `MAX`. `MAX` via
  `MAX_UPLOAD_SIZE_BYTES` (default 512 MiB).
- Tests: range header present in signed opts; `estimated_size_bytes` 0 / >MAX →
  InvalidArgument; oversized finalized object deleted + FAILED.

---

## 5. Medium / Low backlog (post-P0/P1)

- **#10** allowlist `continueUrl` (https + `superwizor.ai`/`app.superwizor.ai` only) in `AuthActionContent.tsx`.
- **#11** add HSTS + CSP (start report-only) to both `firebase.json` hosting targets.
- **#12** gate `reflection.Register` behind `ENABLE_GRPC_REFLECTION=1` (off in prod) in the 4 services.
- **#13** `html/template` (or `html.EscapeString`) for user-derived vars in `action_plan_email.go` / `invitation_email.go`.
- **#14** per-`(org,email)` throttle on invite-resend (reuse token within window).
- **#15** `http.MaxBytesReader` + verify the reCAPTCHA token on `/contact`.
- **#17** log `user_id`/`firebase_uid`, not raw email, in identity-svc `ValidateToken`.
- **#18** same `.gitignore` cleanup as PR‑A (fold in).
- **#19** replace the CRM `fmt.Sprintf`-into-SQL with a bound boolean param (hygiene; safe today).

---

## 6. Target auth architecture (the model the fixes implement)

Four fail-closed auth classes, one per RPC/route:

| Class | Who | How enforced |
|-------|-----|--------------|
| `PUBLIC` | anyone | none (health, register, validate-token) |
| `FIREBASE_USER` | browser / Flutter | validate Firebase ID token → user/org/role in ctx |
| `FIREBASE_ADMIN` | admin browser | `FIREBASE_USER` **and** role == `SUPERWIZOR_ADMIN` |
| `OIDC_INTERNAL` | another backend svc | `idtoken.Validate(aud=own URL)` **and** caller email ∈ SA allowlist |

Per-service target: **ingestion** CreateAudioUpload/GetAudioUploadStatus → FIREBASE_USER
(+ownership); **billing** quota/`GetSubscription`(native) → OIDC_INTERNAL, `GetSubscription`(browser)
→ FIREBASE_USER org-scoped, `Admin*`(native) → REJECT, `Admin*`(browser) → FIREBASE_ADMIN;
**notification** `Send*` → OIDC_INTERNAL, FCM → FIREBASE_USER; **clinical/identity** already
sound (add the connectmd strip as defense-in-depth). Shared building block: a
`pkg/svcauth` `PolicyUnaryInterceptor(policy, firebaseValidator, oidcValidator)` with a
fakeable validator; new env vars `INTERNAL_OIDC_AUDIENCE` + `INTERNAL_ALLOWED_SAS` per
internal callee (`^|^` delimiter — SA emails contain `@`).

---

## 7. Why these are all server-side / backward-compatible

1. **Clients send exactly one credential** — a Firebase Bearer token
   (`marketing-site` `bearerTokenInterceptor`; Flutter `AuthInterceptor`). **No client
   sets `x-superwizor-*`** → stripping them (#9) and refusing to trust them (#2) is
   risk-free.
2. **Every S2S call already attaches a Google OIDC token** (`idtoken.NewTokenSource(aud
   = callee URL)`) — it's on the wire, just never validated. Enforcing OIDC on internal
   RPCs (#3, billing quota) changes **no caller**.

So Phase-1/2 can ship without a client release; staging verification = real flows (invite,
action-plan email, recording upload, `/account`) still work, while `grpcurl` with a forged
role or no token against each fixed RPC is now rejected.

---

## 8. Secret rotation runbook (#4 — owner action, DO NOW)

The leaked credential is the `superwizor_app` Postgres password (a Terraform
`random_password`, also in Secret Manager `postgres-database-url`). PR‑A removes it from
the working tree; **rotation + history are yours**:

1. **Rotate:** `cd superwizor-backend/infra/environments/staging` →
   `terragrunt state list | grep -E 'random_password|google_sql_user|secret_manager'` →
   `terragrunt apply -replace='random_password.<name>'`. Confirm the new
   `postgres-database-url` version + updated `google_sql_user`.
2. **Roll services** (redeploy current image so a fresh revision reads the new secret).
3. **Purge history** (destructive, coordinate force-push): `git filter-repo --invert-paths
   --path …tfstate.*.backup --path check_db.go` + `--replace-text` for the literal. If the
   repo was ever pushed/cloned, assume compromise regardless — rotation (1) is the real fix.
4. **Reduce blast radius:** restrict Cloud SQL `authorized_networks`, prefer the Cloud SQL
   connector / IAM DB auth, review access logs for the exposure window.
5. Move tfstate to an encrypted GCS backend; never commit `*.tfstate*` (now gitignored via PR‑A).

---

## 9. Defense-in-depth backlog

- Split the **quota ledger** + **email senders** onto an internal-only (non-`allUsers`)
  Cloud Run service so IAM is a second gate behind the app-layer OIDC check.
- **CI test:** assert every registered RPC has a non-`PUBLIC` policy entry (fail the build
  when a new RPC ships ungated) — prevents regressions of this whole class.
- Centralize all services' auth wiring on the §6 shared helper (single source of truth).
- Consider mTLS / VPC-internal ingress for S2S once traffic is stable.

---

## 10. Open decisions

1. **`ENV`/prod signal** for fail-closed (#6, #12) — reuse an existing var or add `ENVIRONMENT`?
2. **Dead RPCs** `SendEmailVerification` / `SendQuotaWarning` / `IncrementUsage` — gate or delete?
3. **History purge** timing — coordinate the force-push window with anyone who has a clone.
