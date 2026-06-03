# Production DNS cutover — superwizor.ai + app.superwizor.ai

**Status:** Runbook. Execute when launching to production traffic.
**Owner:** Operations on call.
**Estimated downtime:** Zero — DNS swap propagates while the
existing Firebase preview channel keeps serving. Worst-case for a
client with the previous TTL cached is one TTL window (set at
registrar; default 3600s).

This document is the cookbook the on-call operator follows. It
covers two domains in one cutover so the marketing site and the
therapist app come up together:

- `superwizor.ai`        → Firebase Hosting site `superwizor`
                           (Next.js marketing + admin shell)
- `app.superwizor.ai`    → Firebase Hosting site `superwizor-app`
                           (Flutter Web therapist console)

The Cloud Run gRPC services already serve `https://api.superwizor.ai`
via the gateway terraform; only the two hosting sites need DNS work
in this slice.

---

## 0. Pre-flight (T-24h)

Before touching DNS, verify the green path on the preview channel.

1. **Preview channels green** (Firebase Hosting):
   - `superwizor-www--<branch>-<id>.web.app` — load `/`, `/pricing`,
     `/legal/terms`, `/register/therapist`, `/admin/audit`.
   - `superwizor-app--<branch>-<id>.web.app` — load `/login`, sign in
     to a test SUPERWIZOR_ADMIN account.
   - No console errors. Lighthouse mobile-perf ≥ 75 on the marketing
     home (informational; not a gate).

2. **CI green on `main`**:
   - `.github/workflows/marketing-site.yml` — build, lint, l10n
     parity, E2E (both locales) all passing.
   - `.github/workflows/ci.yml` — Go test/vet/build clean across
     services.

3. **Browser allowlist verified** at the registrar console you'll
   use to add records. We need TXT verification capability + the
   ability to set CNAME / A records on the apex and a subdomain.
   - For an apex domain Firebase requires A records (CNAME is
     illegal at the zone root by RFC).
   - For `app.superwizor.ai` we use a CNAME to the Firebase
     hostname.

4. **Firebase Auth authorized-domains list** (Firebase Console →
   Authentication → Settings → Authorized domains):
   - `superwizor.ai` and `app.superwizor.ai` listed alongside the
     existing `*.web.app` and `*.firebaseapp.com` entries.
   - Without this, Firebase Auth refuses the OAuth redirect on
     prod, even though hosting works.

5. **OAuth redirect URIs** in:
   - Google Cloud Console → APIs & Services → Credentials → the
     OAuth 2.0 Web Client used by Firebase:
       Authorised JavaScript origins:
         https://superwizor.ai
         https://app.superwizor.ai
       Authorised redirect URIs:
         https://superwizor.ai/__/auth/handler
         https://app.superwizor.ai/__/auth/handler
   - Apple Sign In (if shipping) → Services ID → return URLs:
       https://superwizor.ai/__/auth/handler
       https://app.superwizor.ai/__/auth/handler
   - Microsoft (if shipping) → App registration → Redirect URIs:
       https://superwizor.ai/__/auth/handler
       https://app.superwizor.ai/__/auth/handler

6. **GCS bucket CORS** already lists both origins (see
   superwizor-backend/infra/storage/main.tf comment). Double-check
   the live config: `gsutil cors get gs://superwizor-uploads`. If
   not, apply via terragrunt before cutover.

---

## 1. Promote `main` to the live channel (T-1h)

Pre-publish prod artifacts so the moment DNS flips, content is
already there.

```bash
# Marketing site — uses Hosting's Web Frameworks support; the
# CI workflow .github/workflows/marketing-site.yml `deploy-production`
# job does this automatically on every push to main. To trigger
# manually:
firebase deploy --only hosting:superwizor \
  --project superwizor-ai-25ecd

# Flutter Web app — built locally, deployed manually for now
# (no CI job yet; tracked as a follow-up).
cd flutter-app/superwizor
flutter build web --release --no-tree-shake-icons
cd ../..
firebase deploy --only hosting:superwizor-app \
  --project superwizor-ai-25ecd
```

After both deploys, hit the default Firebase URLs and smoke test
once more:

- https://superwizor.web.app/
- https://superwizor.web.app/admin/audit (sign-in panel)
- https://superwizor-app.web.app/login

---

## 2. Connect custom domains in Firebase Hosting (T-0h)

Firebase Console → Hosting → for each of the two sites, click
**Add custom domain**.

### 2.1  superwizor.ai (apex) → superwizor

1. Enter `superwizor.ai`. Choose **Quick setup** if Firebase
   recognises the domain (often does for popular registrars); else
   **Advanced setup**.
2. Firebase shows a TXT record to add for ownership verification:
   ```
   Type: TXT
   Host: @  (or superwizor.ai)
   Value: google-site-verification=...
   TTL: 3600
   ```
   Add at registrar. Verification typically takes 5–30 minutes.
3. After verification, Firebase shows the production A records to
   add. Today these are:
   ```
   Type: A   Host: @   Value: 199.36.158.100
   Type: A   Host: @   Value: 199.36.158.101
   ```
   (Confirm the values in the Firebase Console at execution time —
   Google sometimes rotates IP ranges.)

### 2.2  app.superwizor.ai (subdomain) → superwizor-app

1. Enter `app.superwizor.ai`. Same TXT verification step.
2. The DNS record is a CNAME, not an A record:
   ```
   Type: CNAME
   Host: app
   Value: superwizor-app.web.app.
   TTL: 3600
   ```

Set the TTL to **300** for the cutover window so a rollback is
quick if something breaks. Bump back to 3600 the day after.

---

## 3. Wait for SSL provisioning

After DNS resolves to Firebase's IPs, Google's hosting provisions
a managed Let's Encrypt certificate. This takes anywhere from
2 minutes to 24 hours.

Monitor:

```bash
# Should return 200 once SSL is live; expect 522/SSL errors until then.
curl -I https://superwizor.ai
curl -I https://app.superwizor.ai

# Firebase Console shows a per-domain status: Pending DNS →
# Provisioning SSL → Connected.
```

---

## 4. Smoke test on the live domains

Run these as soon as the Console shows **Connected**:

| Endpoint                                          | Expected      |
|---------------------------------------------------|---------------|
| `https://superwizor.ai/`                          | 200 + landing |
| `https://superwizor.ai/en`                        | 200 + EN copy |
| `https://superwizor.ai/pricing`                   | 200           |
| `https://superwizor.ai/admin/audit`               | 200 + AdminGuard sign-in panel |
| `https://superwizor.ai/login`                     | 307 → https://app.superwizor.ai/login |
| `https://app.superwizor.ai/`                      | 200 + Flutter login |
| `https://app.superwizor.ai/login` (signed in)     | 200 + dashboard |

Then, signed in as a test SUPERWIZOR_ADMIN, click through:
- /admin/orgs — list loads
- /admin/users — list loads
- /admin/audit — list loads (the new RPC from this slice)

Open the browser console — no errors on any page.

---

## 5. Post-cutover

1. **Restore TTLs** on the registrar (apex A records + app CNAME)
   to 3600 once you're confident things are stable.
2. **Update `next.config.ts`** if the `/login` redirect target was
   pointing at a Firebase preview URL. Today it already targets
   `https://app.superwizor.ai/login` so no change needed; verify.
3. **Announce in #ops** with a snapshot of the smoke checklist
   passing. Update `PROGRESS.md` "deployment" section.
4. **Watch error rate** in Cloud Logging for 24h:
   - identity-svc 5xx → no spike.
   - hosting traffic — typical European-business-day pattern.

---

## 6. Rollback plan

If the live domains break and you can't fix forward within 15
minutes, revert.

The cleanest rollback is at DNS:

```
# Apex: remove the new A records, no replacement (the Firebase
# preview channels remain reachable via *.web.app).
# Subdomain: delete the app CNAME.
```

DNS caches will hold the failing answer for the TTL (300s if you
set it as recommended in §2; otherwise up to the registrar's
default ~3600s). Users hitting the cached value during this window
see SSL or 404 errors — communicate the maintenance window in
advance.

If the issue is content (not DNS), redeploy the previous Firebase
Hosting release:

```bash
# Marketing site
firebase hosting:rollback --site superwizor --project superwizor-ai-25ecd

# Flutter Web
firebase hosting:rollback --site superwizor-app --project superwizor-ai-25ecd
```

---

## 7. Follow-ups tracked elsewhere

These don't block launch but should land soon after:

- CI job to build + deploy the Flutter Web bundle on every push to
  `main` (today the marketing-site CI does this for the Next.js
  app; flutter-app/superwizor needs the equivalent under
  `.github/workflows/`). Tracked separately.
- Terraform module for the DNS records. Today the cutover is a
  manual registrar-console operation; codifying the records in
  `infra/dns/` would let Terragrunt manage future changes. Worth
  doing once we have a second environment (staging.superwizor.ai).
- Sub-resource integrity + CSP headers — Firebase Hosting allows
  custom headers via `firebase.json`. Pre-launch is the right
  moment to lock the CSP down.
