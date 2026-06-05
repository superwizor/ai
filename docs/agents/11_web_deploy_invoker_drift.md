# 11. Runbook — "Wystąpił nieznany błąd" on browser → backend calls (public Cloud Run invoker drift)

**Audience:** any agent (or human) touching the web-app (`marketing-site/`),
billing-svc, or staging/prod Terraform.
**Severity when it happens:** every browser→backend call to the affected service
fails. User-visible as a generic "unknown error". Looks like an app bug; it is
an **infrastructure (IAM) drift**.

First observed: 2026-06-05, admin panel "Zresetuj wykorzystane tokeny"
(`AdminResetTokens`) — see screenshot in the incident thread. The `/account/`
Subskrypcja card had the **identical** root cause on 2026-06-04.

---

## TL;DR

The browser talks **directly** to each Cloud Run service over Connect-Web
(`marketing-site/src/lib/connect/transport.ts`). A browser CORS **preflight**
(`OPTIONS`) carries **no `Authorization` header** by spec. If the target Cloud
Run service does **not** grant `allUsers` the `roles/run.invoker` role, the
Google Front End (GFE) rejects that preflight with **HTTP 403 before the request
ever reaches the app** — so the app's CORS middleware never runs and no
`Access-Control-Allow-Origin` header comes back. The browser aborts the call;
connect-web reports it as `Code.Unknown`; the UI renders the catch-all string
**"Wystąpił nieznany błąd."**

> It is NOT an auth bug, NOT a CORS-config bug in the Go code, NOT a frontend
> bug. It is a **missing `allUsers` run.invoker binding** on the Cloud Run
> service, almost always caused by **IAM drift after a deploy / `terragrunt
> apply`**.

---

## How to recognise it in 30 seconds

Symptom: a feature that calls one specific backend service shows a generic
error, while features hitting *other* services work. (e.g. `/account/` profile
loads — identity-svc — but the Subskrypcja card and admin token tools fail —
billing-svc.)

Run the unauthenticated CORS preflight against the service the bundle calls:

```bash
BILLING="https://billing-svc-344724821207.europe-central2.run.app"
curl -s -o /dev/null -D - -X OPTIONS "$BILLING/billing.v1.BillingService/AdminResetTokens" \
  -H "Origin: https://superwizor.ai" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: content-type,authorization,connect-protocol-version" \
  | grep -iE "HTTP/|access-control-|server:"
```

- **Broken:** `HTTP/2 403` + `server: Google Frontend`, **no** `access-control-*`
  headers → GFE is rejecting the preflight → missing `allUsers` invoker.
- **Healthy:** `HTTP/2 200` + `access-control-allow-origin: https://superwizor.ai`
  → the app handled the preflight; the problem is elsewhere.

Confirm the IAM directly and compare against a service that works:

```bash
for svc in billing-svc identity-svc clinical-svc; do
  echo "== $svc =="
  gcloud run services get-iam-policy "$svc" \
    --region=europe-central2 --project=superwizor-ai-25ecd \
    --format="value(bindings.role,bindings.members)" | grep -iE "invoker|allUsers"
done
```

A healthy public service lists `allUsers` under `roles/run.invoker`. The broken
one lists only service accounts (the screenshot incident: billing-svc had the
SA list but **no `allUsers`**, while identity-svc and clinical-svc had it).

---

## Why it maps to "unknown error" (and not "unauthenticated")

`marketing-site/src/lib/errors/translate.ts` maps each Connect `Code` to a
distinct i18n key:

- A **server**-returned status (e.g. the app's auth interceptor saying
  `CodeUnauthenticated`) → `code.unauthenticated` → a *specific* message.
- A **transport** failure (the `fetch` never gets a valid Connect response —
  CORS block, GFE 403, connection refused, DNS) → connect-web throws
  `Code.Unknown` → `code.unknown` → `messages/pl.json` → **"Wystąpił nieznany
  błąd."**

So the exact wording is the tell: **"Wystąpił nieznany błąd." == `Code.Unknown`
== transport failure == almost always the missing-invoker 403**, not anything
the server logic returned. (If you instead see "Sesja wygasła / nie jesteś
zalogowany" / `code.unauthenticated`, that's a real token problem — different
bug.)

---

## How a "web-app deploy" causes it (the drift mechanism)

The web-app deploy itself (Firebase Hosting) does not touch Cloud Run IAM. The
breakage comes from **IAM drift around the deploy**:

1. The `allUsers` grant for billing-svc lives in Terraform —
   `superwizor-backend/infra/environments/staging/service-accounts.tf`,
   `local.public_cloud_run_services` (billing-svc was added there in commit
   `85d2fa7`).
2. At some point the live binding was set **manually** via
   `gcloud run services add-iam-policy-binding` (the 2026-06-04 hotfix) and/or
   the Terraform change wasn't `terragrunt apply`-d.
3. A later `terragrunt apply` — run by another developer while
   deploying/iterating on staging infra — reconciled the live state back to
   whatever Terraform state it had, **dropping the `allUsers` member** that
   wasn't faithfully represented in that state.
4. identity-svc and clinical-svc survived because they've been canonically in
   the public list and applied for longer; billing-svc — the newest addition —
   was the one that drifted.

**Lesson:** a manually-added IAM binding + a Terraform change that isn't applied
on merge = guaranteed future drift. The next `terragrunt apply` silently
reverts the manual fix, and the failure resurfaces far away from whoever ran the
apply.

---

## Immediate fix

**Preferred (IaC — no drift):** apply the Terraform that already lists
billing-svc as public.

```bash
cd superwizor-backend/infra/environments/staging
terragrunt plan   # confirm it will ADD google_cloud_run_v2_service_iam_member.public_invoker["billing-svc"]
terragrunt apply
```

**Band-aid (only if you cannot apply Terraform right now — it WILL drift again
on the next apply unless the config matches):**

```bash
gcloud run services add-iam-policy-binding billing-svc \
  --region=europe-central2 --project=superwizor-ai-25ecd \
  --member=allUsers --role=roles/run.invoker
```

Re-run the preflight check above; expect `HTTP/2 200` + `access-control-allow-origin`.

---

## How to PREVENT it (checklist for future web/infra work)

1. **Every service the browser calls directly must be in
   `public_cloud_run_services`** (`infra/environments/staging/service-accounts.tf`).
   Today that's: identity-svc, clinical-svc, ingestion-svc, api-service,
   notification-svc, billing-svc. If you make the browser call a *new* service,
   add it there **and apply** in the same change.
2. **Never grant prod/staging IAM with a bare `gcloud add-iam-policy-binding`
   as the durable fix.** Use it only as an emergency band-aid, and immediately
   land+apply the matching Terraform so the binding survives the next
   `terragrunt apply`.
3. **`terragrunt plan` before every `apply`** and read the diff. If you see
   `google_cloud_run_v2_service_iam_member.public_invoker["billing-svc"]` being
   **destroyed**, stop — you're about to recreate this incident.
4. **Add a post-deploy smoke check** for browser-facing services. The web CI
   already runs `marketing-site/scripts/smoke-connect.mjs`; extend it (or add a
   step) to fire an `OPTIONS` preflight against each public service and assert
   `200` + an `access-control-allow-origin` header. A red smoke check beats a
   user screenshot.
5. **Make the frontend fail loudly, not blandly.** `Code.Unknown` on a Connect
   call is operationally meaningful (transport/CORS/IAM), not a random glitch.
   Consider a dedicated message for `code.unknown` that hints "cannot reach
   <service> (network/permissions)" so the next person isn't staring at
   "unknown error".
6. **`NEXT_PUBLIC_*` are build-time inlined.** (Adjacent gotcha found while
   diagnosing this.) The real service URLs live in a **gitignored**
   `marketing-site/.env.production.local`; only `.env.local.example` is tracked.
   The CI workflow (`.github/workflows/marketing-site.yml`) runs a bare
   `pnpm build` with **no `NEXT_PUBLIC_*` env injection**. A CI-built bundle
   would fall back to `http://localhost:8081` (see `transport.ts`) and every
   call would fail the same opaque way. If you ever move the deploy to CI,
   inject these vars at build time first. (The current live bundle has the
   correct `*-344724821207.europe-central2.run.app` URLs, so today's incident is
   the invoker drift, not this — but it's the same failure signature, so check
   both.)

---

## Second failure mode — `IDENTITY_SVC_URL` unset → admin RPCs 401

Once the invoker (above) is fixed, browser admin RPCs can still fail — but
with a **different, more specific** symptom:

- UI shows **"Musisz być zalogowana/y, aby wykonać tę akcję."** (you must be
  logged in) — i.e. `code.unauthenticated`, NOT `code.unknown`. This means the
  request **reached the app** and got a structured `Unauthenticated` back
  (transport is fine).
- The `/admin` panel itself renders (you passed `AdminGuard`, which only shows
  after `identityClient.getMyProfile()` succeeds) — so your Firebase token IS
  attached and valid. The failure is specific to **billing-svc**.

Root cause: billing-svc's `ConnectAuthInterceptor` (which calls
`identity-svc.ValidateToken` to turn the browser's Firebase token into the
`x-superwizor-role` metadata the admin handlers require) is **only installed
when `IDENTITY_SVC_URL` is set** (`services/billing-svc/cmd/server/main.go`:
`if identityClient != nil`). If that env is missing, the interceptor is skipped,
the handler sees no role, and returns `Unauthenticated`. On startup billing-svc
logs: `IDENTITY_SVC_URL unset — admin Connect RPCs require upstream
x-superwizor-role metadata`.

Diagnose:
```bash
gcloud run services describe billing-svc --region=europe-central2 \
  --project=superwizor-ai-25ecd --format=json \
  | python3 -c "import json,sys;print([e['name'] for e in json.load(sys.stdin)['spec']['template']['spec']['containers'][0].get('env',[])])"
# Healthy includes IDENTITY_SVC_URL. If absent → this bug.
```
Immediate fix:
```bash
gcloud run services update billing-svc --region=europe-central2 \
  --project=superwizor-ai-25ecd \
  --update-env-vars "IDENTITY_SVC_URL=https://identity-svc-e3f32b232q-lm.a.run.app"
```

## The real durable root cause (both modes) — the billing CI deploy block

Both failures trace to ONE place: the **`Deploy Billing to Cloud Run`** step in
`.github/workflows/ci.yml`. Unlike every other browser-facing service it was
deployed with:

- `--no-allow-unauthenticated` → **strips `allUsers` on every deploy** (mode 1).
  identity/clinical use `--allow-unauthenticated` + an explicit
  `add-iam-policy-binding`.
- `--set-env-vars="GCP_PROJECT_ID,VERSION"` with **no `IDENTITY_SVC_URL`** —
  and `--set-env-vars` *replaces* the whole env block, so it wiped any manual
  fix (mode 2).

So any CI run that redeployed billing-svc silently reverted both manual fixes —
which is exactly the "another developer deployed and it broke again" pattern.
Fixed on `fix/billing-svc-ci-deploy`: billing now uses `--allow-unauthenticated`,
sets `IDENTITY_SVC_URL`, and pins `allUsers` explicitly — matching identity/clinical.

**Lesson:** when you add a browser-facing service, copy the *whole* deploy
recipe from identity/clinical (`--allow-unauthenticated` + `add-iam-policy-binding`
+ all inter-service `*_SVC_URL` envs). A partial copy that omits public access or
an `*_SVC_URL` produces exactly these two opaque failures.

---

## Third failure mode — CORS allowlist missing the Flutter web origin

Symptom: the **Flutter web app** (`https://superwizor-app.web.app`, reached via
the marketing-site → "Kartoteki" SSO handoff) logs in fine but **can't load
data** (endless spinner). The **native app works** (native gRPC, no CORS).
Browser-only.

Root cause: the CORS allowlist (`getEnv("CORS_ALLOWED_ORIGINS", "<default>")` in
each service's `cmd/server/main.go`) listed `superwizor.ai` + `app.superwizor.ai`
but **not** `superwizor-app.web.app` (the Firebase Hosting URL the Flutter web
build is served from). The app's CORS middleware 403s the preflight with
`vary: Origin` and **no** `access-control-allow-origin` → browser blocks it.
Distinct from mode 1: here the request reaches the app (allUsers is set) and the
app rejects the *origin*; mode 1 is the GFE rejecting before the app.

Diagnose (`vary: Origin` + missing ACAO = app-layer origin reject):
```bash
curl -s -o /dev/null -D - -X OPTIONS \
  "https://clinical-svc-344724821207.europe-central2.run.app/clinical.v1.ClinicalService/ListPatientFiles" \
  -H "Origin: https://superwizor-app.web.app" -H "Access-Control-Request-Method: POST" \
  | grep -iE "HTTP/|access-control-allow-origin|vary"
```
Immediate fix (per service; use `--update-env-vars` with the FULL list, since
`--set-env-vars` replaces the whole env block):
```bash
gcloud run services update clinical-svc --region=europe-central2 --project=superwizor-ai-25ecd \
  --update-env-vars "^@^CORS_ALLOWED_ORIGINS=https://superwizor.ai,https://app.superwizor.ai,https://superwizor-app.web.app,http://localhost:3000,http://localhost:8080"
```
Durable fix: add the origin to the code default in `cmd/server/main.go` for every
browser-facing service (clinical/identity/billing) — `fix/cors-flutter-web-origin`.
**Lesson:** the CORS allowlist must include EVERY origin the browser app is served
from — including the raw `*.web.app` Firebase URL, not just the custom domain.

---

## Quick reference — services & URLs

| Service | Browser-facing? | Public URL (staging, project 344724821207) |
|---|---|---|
| identity-svc | yes | `https://identity-svc-344724821207.europe-central2.run.app` |
| billing-svc | yes | `https://billing-svc-344724821207.europe-central2.run.app` |
| clinical-svc | yes | `https://clinical-svc-344724821207.europe-central2.run.app` |
| ingestion-svc | yes (uploads) | `…/ingestion-svc-…` |

Connect method path = `/<package>.<Service>/<Method>`, e.g.
`/billing.v1.BillingService/AdminResetTokens`.

---

*Related: `07_devops-cicd.md`, `08_infrastructure-terraform.md`,
`03_billing-svc.md`. Source-of-truth for public invokers:
`infra/environments/staging/service-accounts.tf` → `public_cloud_run_services`.*
