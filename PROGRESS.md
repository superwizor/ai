# Web-app progress

Project: Superwizor AI — Polish therapist co-pilot. Web-app build using the
long-running-agents harness. See `.claude/CLAUDE.md` for orientation.

## Done

### Slice 1 — backend foundation (branch `feat/web-app`, 18 commits, UNMERGED)
- Migrations 000035-000037 (invitations, audit_events.reason, user_role
  ORG_ADMIN + SUPERWIZOR_ADMIN). sqlc regenerated.
- `pkg/cors` shared middleware wired into identity-svc + clinical-svc +
  billing-svc.
- `buf.gen.yaml` extended with connectrpc/go + connectrpc/es + bufbuild/es
  plugins; `gen/ts/` carved out of root `.gitignore`.
- Dedicated SAs for identity-svc + clinical-svc; GCS CORS configured.
- Proto additions: org registration, invitations, profile updates, admin
  RPCs (billing AdminResetTokens / AdminChangePlan).
- Identity-svc handlers: org registration, invitation create/accept,
  profile updates, SUPERWIZOR_ADMIN admin operations.
- Billing-svc handlers: AdminResetTokens, AdminChangePlan.
- Connect-RPC adapters across identity-svc, clinical-svc, billing-svc
  (commits 5484987, 403035b, 74abdfa) — h2c mixed handler dispatches gRPC
  vs Connect by Content-Type.
- Notification-svc: Resend transactional email integration (secret +
  IAM binding live in staging).
- E2E test: `identity-svc/.../connect_adapter_test.go` proves the Connect
  wire works via httptest + real Connect client.

## In progress

- **Harness bootstrap** — installing the long-running-agents primitives at
  the project root (this file, `.claude/CLAUDE.md`, hooks, evaluator). Last
  remaining: confirm Playwright MCP is wired up.

## Next (Slice 2 — Next.js marketing site + admin)

Branch off `feat/web-app` as `feat/web-app-slice-2`.

1. **Scaffold `marketing-site/`** — Next.js 14 app router, pnpm, TypeScript,
   Tailwind. i18n via next-intl (PL primary, EN fallback).
2. **Connect-ES client wiring** — consume `gen/ts/` stubs against
   identity-svc.
3. **Public landing page** (PL + EN) — hero, features, CTA → therapist
   registration.
4. **Individual therapist registration flow** — Firebase Email/Password +
   Google social login; calls identity-svc.RegisterTherapist via Connect.
5. **Organization registration flow** — captures full Org CRUD per
   `docs/18_WEB_APP_DESIGN.md` §13 form catalogue.
6. **Admin shell** (SUPERWIZOR_ADMIN role) — login, dashboard skeleton,
   user/org list. Will host AdminResetTokens / AdminChangePlan in
   subsequent slice.

## Notes / gotchas

- `feat/web-app` does NOT merge to main until end-to-end web is verified.
  Per-slice branches merge back into `feat/web-app`.
- Manual ops pending (NOT for the agent to run): Firebase Console — enable
  Apple + Microsoft providers (task #64). SUPERWIZOR_ADMIN bootstrap SQL.
- sqlc tricky bits: `UpdateOrganizationParams.Type` is `*db.OrganizationType`
  (pointer), not `NullOrganizationType` — see
  `services/identity-svc/internal/handlers/org_profile.go`.
- `db.Subscription` has no `PlanTier`/`PlanCycle` fields directly — use
  `GetActiveSubscriptionByOrg` which JOINs `subscription_plans`.
- idtoken import path is `google.golang.org/api/idtoken` (NOT the
  oauth2/google variant).
- pkg/cors origins come from `CORS_ALLOWED_ORIGINS` env (terraform sets it
  on staging to superwizor.ai + app.superwizor.ai + localhost).
- Polish strings must route through next-intl translation keys, never
  hard-coded in components.
- Evidence pattern: `evidence/slice-2/<feature>/<step>.{png,log}`.
