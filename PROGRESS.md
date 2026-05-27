# Web-app progress

Project: Superwizor AI — Polish therapist co-pilot. Web-app build using the
long-running-agents harness. See `.claude/CLAUDE.md` for orientation.

**Goal (multi-slice):** Implement Slices 2, 3, 4, 5, and 6 per
`docs/18_WEB_APP_DESIGN.md` and this file. Use the `evaluator` agent after
each feature to gate progress (PASS / NEEDS_WORK). Each slice merges into
`feat/web-app` only after evaluator passes every feature.

## Done

### Slice 1 — backend foundation (branch `feat/web-app`, 18 commits + harness)
- Migrations 000035-000037 (invitations, audit_events.reason, user_role
  ORG_ADMIN + SUPERWIZOR_ADMIN). sqlc regenerated.
- `pkg/cors` shared middleware on identity/clinical/billing.
- `buf.gen.yaml` with connectrpc/go + connectrpc/es + bufbuild/es plugins;
  `gen/ts/` carved out of root `.gitignore`.
- Dedicated SAs for identity-svc + clinical-svc; GCS CORS configured.
- Proto additions: org registration, invitations, profile updates, admin
  RPCs (AdminResetTokens / AdminChangePlan).
- Identity-svc handlers: org registration, invitation create/accept, profile
  updates, SUPERWIZOR_ADMIN operations.
- Billing-svc handlers: AdminResetTokens, AdminChangePlan.
- Connect-RPC adapters across all three services (h2c mixed handler
  dispatches gRPC vs Connect by Content-Type) — commits 5484987, 403035b,
  74abdfa.
- Notification-svc: Resend transactional email integration (secret + IAM
  binding live in staging).
- E2E test: `identity-svc/.../connect_adapter_test.go` proves the Connect
  wire works via httptest.
- Harness: `.claude/` primitives, PROGRESS.md, test-results.json,
  Playwright MCP (commit a40dc23).

## In progress

- **Slice 2** — marketing-site foundation. Branch:
  `feat/web-app-slice-2` (currently checked out, no commits yet).

## Slice plan (Slices 2-6)

Each slice branches `feat/web-app-slice-N` off the previous slice's merged
state. Slice merges into `feat/web-app` (NOT main) after evaluator PASS on
every feature.

### Slice 2 — `marketing-site-foundation`
Scaffolds Next.js, brand tokens, i18n, Connect-RPC client, Firebase Auth,
public marketing surface. Unblocks all registration/admin work.

1. `nextjs-scaffold` — Next.js App Router scaffold with Tailwind + brand tokens
2. `next-intl-pl-en` — next-intl wired with PL/EN, as-needed routing, hreflang
3. `connect-rpc-client` — Connect-ES generated clients + Firebase ID-token interceptor
4. `firebase-auth-init` — Firebase Web SDK init (Email/Password + Google) + emulator support
5. `landing-page` — Landing page (hero, screenshots, CTA) in PL+EN
6. `pricing-page` — Pricing page reading subscription_plans via Connect-RPC
7. `legal-static-pages` — Terms / Privacy / DPA markdown pages in PL+EN
8. `firebase-hosting-deploy` — Firebase Hosting site superwizor-www + CI deploy step

### Slice 3 — `registration-flows`
Therapist + org self-serve registration (email/pwd + Google), magic-link
invitation accept page. Verifies Slice 1 RPCs end-to-end.

1. `register-therapist-email` — /register/therapist email+password form per §13.2
2. `register-therapist-google` — Google OAuth path + /register/therapist/finish profile page
3. `register-organization-email` — /register/organization email+pwd form per §13.3
4. `register-organization-google` — Google OAuth org path + finish page
5. `email-verification-gate` — sendEmailVerification + verification-required interstitial
6. `accept-invite-page` — /accept-invite token validation + password set + AcceptInvitation RPC
7. `login-redirect` — /login as <a> redirect to app.superwizor.ai/login (R3 origin discipline)
8. `registration-e2e-playwright` — Playwright happy-path: therapist register → Trial → redirected

### Slice 4 — `admin-console`
Internal Superwizor admin panel at `superwizor.ai/admin/*`. Replaces psql
+ bash for support ops.

1. `admin-auth-guard` — Next.js middleware gating /admin/* on role=SUPERWIZOR_ADMIN
2. `admin-shell-nav` — Admin shell (sidebar, user menu, breadcrumbs) in PL+EN
3. `admin-orgs-list` — Orgs list with filters, pagination, TanStack Table
4. `admin-org-detail` — Org detail: usage chart, therapist list, audit panel
5. `admin-org-actions` — Block/unblock, AdminResetTokens, AdminChangePlan with reason dialogs
6. `admin-org-edit` — AdminUpdateOrganization form per §13.7
7. `admin-user-crud` — User list + AdminUpdateUser / AdminDeleteUser per §13.8
8. `admin-audit-log` — Global audit_events viewer with actor/action/date filters

### Slice 5 — `flutter-web-consoles`
Flutter Web for therapist console + org-admin tab on `app.superwizor.ai`.

1. `flutter-web-target` — flutter create --platforms web + kIsWeb branches
2. `flutter-web-login` — Login on app.superwizor.ai with Email/Pwd + Google
3. `flutter-web-therapist-console` — Kartoteki + sessions + transcript + report on web
4. `flutter-web-profile-edit` — Profile edit per §13.4 (UpdateMyProfile, avatar upload)
5. `org-admin-route-guard` — /admin route gated on role=ORG_ADMIN
6. `org-admin-therapists` — Therapists tab: list + InviteTherapist + RemoveTherapist
7. `org-admin-org-settings` — Org settings form per §13.5
8. `org-admin-billing-readonly` — Billing view (subscription, tier, usage, reservations)

### Slice 6 — `i18n-polish-launch`
i18n contract closure, error handling, email templates, both-locale E2E,
DNS cutover. Unblocks production launch.

1. `notification-svc-i18n-templates` — PL+EN for invitation/verify/quota emails
2. `error-code-translation-map` — Frontend error-code → translation map
3. `empty-loading-error-states` — Empty states, skeletons, toasts across surfaces
4. `l10n-parity-ci` — scripts/check-l10n-parity.sh + §13.11 drift test
5. `playwright-e2e-both-locales` — Happy-path E2E run once per locale
6. `shared-machine-warning` — Flutter Web shared-machine login notice
7. `production-dns-cutover` — DNS cutover to Firebase Hosting

## Notes / gotchas

- **Toolchain prerequisite:** Node 20 is installed at
  `/usr/local/opt/node@20/bin/node` (keg-only Homebrew). pnpm install was
  interrupted — the next session needs to choose how to install pnpm
  (`corepack prepare pnpm@9.15.5 --activate` works on Node 20; corepack
  latest needs Node 22). Persist PATH via shell rc or use absolute paths.
- `feat/web-app` does NOT merge to main until end-to-end web is verified.
  Per-slice branches merge back into `feat/web-app`.
- Manual ops still pending: Firebase Console — enable Apple + Microsoft
  providers (task #64); SUPERWIZOR_ADMIN bootstrap SQL after a real
  account exists in Slice 3.
- sqlc tricky bits: `UpdateOrganizationParams.Type` is
  `*db.OrganizationType` (pointer), not `NullOrganizationType` — see
  `services/identity-svc/internal/handlers/org_profile.go`.
- `db.Subscription` has no `PlanTier`/`PlanCycle` fields directly — use
  `GetActiveSubscriptionByOrg` which JOINs `subscription_plans`.
- idtoken import path: `google.golang.org/api/idtoken` (NOT the
  oauth2/google variant).
- pkg/cors origins come from `CORS_ALLOWED_ORIGINS` env (terraform sets
  superwizor.ai + app.superwizor.ai + localhost on staging).
- Polish strings must route through next-intl translation keys — no
  hard-coded Polish in components.
- Evidence pattern: `evidence/slice-N/<feature-id>/<step>.{png,log}`.
  Evaluator denies a feature without evidence opened in-session.
