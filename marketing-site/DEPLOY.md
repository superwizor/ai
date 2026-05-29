# marketing-site deploy

Target: **Firebase Hosting** site `superwizor-www` in project
`superwizor-ai-25ecd`. DNS: `superwizor.ai` → `superwizor-www`.

Modes:

1. **Production (automated)** — push to `main` triggers
   `.github/workflows/marketing-site.yml` job `deploy-production`,
   which builds and deploys to the `live` channel of the
   `superwizor-www` Hosting site. Required GitHub secrets:
     - `WIF_PROVIDER` — Workload Identity Federation provider resource
     - `HOSTING_DEPLOYER_SA` — service-account email (terraform-managed,
       has `roles/firebasehosting.admin`)
     - `HOSTING_DEPLOYER_SA_JSON` — JSON key fallback consumed by the
       `FirebaseExtended/action-hosting-deploy` action.
2. **Preview (automated)** — PRs and pushes to `feat/web-app-*` branches
   deploy to ephemeral preview channels at
   `https://superwizor-ai-25ecd--pr-<N>-<hash>.web.app`. Auto-expire
   after 7 days.
3. **Manual** — from a developer machine with `firebase login`:

       cd /Users/dpiotrak/supervisorai_v2/ai
       firebase use superwizor-ai-25ecd
       firebase deploy --only hosting:superwizor-www

   Firebase CLI auto-detects the Next.js app via
   `firebase.json#hosting.source` and runs `pnpm build` then deploys
   the resulting static + SSR artefacts.

## Hosting topology

```
firebase.json
└── hosting[]
    ├── superwizor-www  ← Next.js marketing site
    │   • source = marketing-site/         (Web Frameworks support)
    │   • frameworksBackend.region = europe-central2
    │   • Auto-deploys static pages + Cloud Functions for SSR/SSG
    │     (next-intl proxy stays intact)
    │
    └── superwizor-app  ← Flutter Web bundle
        • public = flutter-app/superwizor/build/web
```

> Why `"source"` not `"public"`: docs/18 §3 originally specified
> `"public": "marketing-site/out"` for a static-exported Next.js.
> Static export requires removing the middleware/proxy that handles
> next-intl locale routing on the same path. Firebase Hosting's Web
> Frameworks support (`"source"`) keeps the dev-time middleware
> intact and deploys SSR pages to Cloud Functions transparently.
> Net result: same URL surface (`/`, `/en`, `/pricing`,
> `/legal/{terms,privacy,dpa}`, all i18n-correct), zero proxy
> deletion, simpler CI.

## DNS cutover

Two `A` records pointing at Firebase Hosting per the Firebase Console
"Add custom domain" flow. Cutover lands in Slice 6
(`production-dns-cutover`).

## Verifying a deploy

After `deploy-production` finishes:

```sh
curl -I https://superwizor.ai/
curl -I https://superwizor.ai/pricing
curl -I https://superwizor.ai/en/legal/dpa
```

Each should return `200 OK` plus a `cache-control` that reflects
Hosting's static-asset policy.

## Rollback

Firebase Hosting keeps every released version. From the Console,
"Hosting" → site → "Release history" → click an older version →
"Rollback". The CLI equivalent is `firebase hosting:rollback`.

## Locally previewing the production bundle

```sh
cd marketing-site
pnpm build
cd ..
firebase emulators:start --only hosting:superwizor-www
# serves at http://localhost:5000 with the production-built bundle
```
