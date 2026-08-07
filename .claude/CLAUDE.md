<!-- Copyright 2026 Anthropic PBC -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# Long-running conventions for this project

## Project orientation

This repo (`/Users/dpiotrak/supervisorai_v2/ai/`) hosts **Superwizor AI** — a
Polish therapist co-pilot platform. The web-app build is being done with the
long-running-agents harness. Three workstreams live side-by-side:

- `superwizor-backend/` — Go monorepo (identity-svc, clinical-svc, billing-svc,
  notification-svc, ingestion-svc, mediator-svc). Connect-RPC + gRPC mixed
  handler. sqlc + pgx. Slice 1 of the web-app backend landed on branch
  `feat/web-app` (unmerged — stays unmerged until web is verified end-to-end).
- `flutter-app/superwizor/` — Flutter therapist app (iOS + Android shipping;
  Web compiles but isn't the primary target yet).
- `marketing-site/` — Next.js marketing + admin shell (to be created in Slice 2;
  doesn't exist yet).

Active branch for the web work: **`feat/web-app`**. New per-slice work branches
off it (e.g. `feat/web-app-slice-2`). Do NOT merge to `main` without explicit
user confirmation.

Key design docs:
- `docs/19_WEB_APP_DESIGN.md` — full web-app design (R1-R9 review rounds).
- `docs/20_WEB_SLICE_1_PLAN.md` — the 8-commit backend foundation (DONE on
  `feat/web-app`, 18 commits).

## Always start here

Before doing anything else, read `PROGRESS.md` at the project root. It is your
handoff note from the previous session. If it doesn't exist yet, create it now
with four sections (`## Done`, `## In progress`, `## Next`, `## Notes`) and
seed it from `docs/20_WEB_SLICE_1_PLAN.md` so the next slice has context.

Then:
1. `git -C superwizor-backend status && git -C superwizor-backend log --oneline -10`
   to see what landed on `feat/web-app`.
2. Run the per-workstream smoke check for whatever you're touching:
   - Go: `cd superwizor-backend && go build ./... && go vet ./...`
   - Flutter: `cd flutter-app/superwizor && flutter analyze`
   - Next.js (once it exists): `cd marketing-site && pnpm build`
3. Only after the smoke is green, start the assigned feature.

## One feature at a time

Work on exactly one item from `PROGRESS.md` per session. Finish it (tests
passing, screenshot verified for UI, `go test ./...` green for backend) before
starting another. If the user gives you a new task mid-session, add it to
`PROGRESS.md` and finish the current item first.

## Proof before passing

A test is only "passing" after you have:
1. Run it against the live thing (Playwright screenshot for web UI, httptest
   round-trip for Connect-RPC, real Postgres + sqlc for DB queries).
2. Opened the resulting screenshot / log / output with the Read tool.
3. Confirmed it shows what it should.

Evidence files go under `evidence/<slice>/<feature>/` (create the dir as
needed). Naming convention: `evidence/slice-N/<feature>/<step>.png` for
screenshots and `evidence/slice-N/<feature>/<step>.log` for logs.

The `verify-gate` hook denies writes to `test-results.json` until evidence has
been opened. Do not work around it — open the artifact, then mark the row.

## Keep `PROGRESS.md` current

After each completed item, update `PROGRESS.md`: check off what's done, add
what you learned, note what's next. Future sessions read this file cold —
include file paths, branch names, and any non-obvious gotchas (e.g. "sqlc
generates `*db.OrganizationType` not `NullOrganizationType` — see
org_profile.go").

## Run the tests before you commit

**Before every commit and before every merge to `main`**, run the test suite
for whatever you touched:

- `marketing-site/` → `cd marketing-site && pnpm test:all`
  (typy → jednostkowe → E2E; zatrzymuje się na pierwszym błędzie)
- `superwizor-backend/` → `cd services/<svc> && go build ./... && go vet ./... && go test ./...`
- `flutter-app/superwizor/` → `flutter analyze && flutter test`

Why this is a rule and not a suggestion: **CI does not run the Playwright E2E
suite.** `marketing-site.yml` runs typecheck, l10n parity, unit tests and the
build — E2E needs a browser and a live dev server, so it stays with whoever
made the change. If you don't run it, nobody does.

**State of the E2E suite (2026-08-07):** ~34 of 256 cases fail because the
specs describe a UI that has since been rebuilt (they look for a
`#professionalTitle` field that no longer exists in the registration form).
This is **test debt, not a broken environment** — verified: starting
billing-svc and identity-svc locally moved the count from 35 to 34. The same
failures reproduce on `main`.

Until the specs are reconciled with the UI, compare the failure COUNT before
and after your change rather than expecting all-green — and always from a
clean cache, because a stale `.next` fabricates hundreds of unrelated
failures:

```bash
cd marketing-site && rm -rf .next && pnpm test:e2e 2>&1 | grep -c "✘"
```

Two traps worth remembering:

- `pnpm test` (vitest) does **not** typecheck. A test can pass while `tsc` and
  `next build` fail on the same file. That's why `test:all` starts with
  `typecheck`.
- After writing a regression test, break the code on purpose and confirm the
  test fails. A test that always passes is worse than no test — it manufactures
  false confidence.

Full guide: `docs/61_TESTY_MARKETING_SITE.md`.

## Commit often

The `Stop` hook commits tracked changes at session end, but also `git add` new
files and commit yourself at meaningful checkpoints with descriptive messages.
Slice 1 landed in 18 commits — that cadence is fine. Prefer many small commits
over one giant blob.

## Branch strategy

**Default workflow for every change — features, bug fixes, infra tweaks, docs.**

1. **Never commit directly to `main`.** Before the first edit of any new piece
   of work, create a branch named after what you're doing:
   - `feat/<short-name>` for new functionality
   - `fix/<short-name>` for bug fixes
   - `infra/<short-name>` for terraform / IAM / CI changes
   - `docs/<short-name>` for doc-only changes
   If you're already on a feature branch (e.g. `feat/web-app`), branch off it,
   not off main.
2. **Commit early and often on the branch.** Same small-commit cadence as
   before — proofs and screenshots go into `evidence/` along the way.
3. **Verify before merging.** A branch is "verified" when:
   - Smoke check passes (`go build ./... && go vet ./...`, `flutter analyze`,
     `pnpm build` — whichever apply).
   - **Tests pass, including E2E.** For `marketing-site/` that means
     `pnpm test:all` — CI will NOT run Playwright for you, so a green CI on the
     merge commit does not mean the E2E suite passed. See
     "Run the tests before you commit" above and `docs/61_TESTY_MARKETING_SITE.md`.
   - Tests pass against the live thing (see "Proof before passing" above).
   - For UI changes: a Playwright screenshot of the final state is opened
     with `Read` and confirmed.
   - For infra changes: `terragrunt plan` clean, `terragrunt apply` succeeds,
     post-change `curl` / `gcloud` confirms the live resource.
4. **Then merge to `main`.** Fast-forward when possible (single-commit
   branches, no divergence); use `--no-ff` for slice merges so the branch
   history stays visible. Delete the branch locally after merge.
5. **Push to `origin/main` only when the user asks.** Local merge alone does
   not publish.

**Existing long-lived branches** (still active):
- `feat/web-app` — base branch for the web-app build. Per-slice work branches
  off it as `feat/web-app-slice-N` and merges back into `feat/web-app`
  *before* `feat/web-app` rolls up to `main`. The "verify before merging"
  bar applies at every step.

**Exception:** if the user explicitly says "commit to main" or "push this
straight to main," do as asked — that's a deliberate override.

## If you're told to stop

`OPERATOR STEERING:` messages come from a human via the steer hook. Treat them
as higher priority than your current plan. If the kill-switch fires (touch
file present), exit immediately — don't argue, don't finish "just this one
thing."

## Multi-language note

UI strings must go through the i18n pipeline (Polish is primary, English is
fallback). Do not hard-code Polish in components — use the translation keys
defined in `docs/19_WEB_APP_DESIGN.md` §14. The harness evaluator will flag
hard-coded strings.
