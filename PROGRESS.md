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

### Slice 2 — marketing-site foundation (DONE, merged to `feat/web-app` at aa09972)
8 features, all PASS evaluator, 8+ commits + 1 merge commit:
- nextjs-scaffold       — Euphire brand tokens (Tailwind 4 @theme)
- next-intl-pl-en       — PL/EN with as-needed routing + hreflang
- connect-rpc-client    — typed clients + bearer interceptor
- firebase-auth-init    — Web SDK + emulator + token bridge
- landing-page          — full PL+EN composition (7 sections)
- pricing-page          — Trial + Solo + Pro + Clinic
- legal-static-pages    — Terms/Privacy/DPA markdown PL+EN
- firebase-hosting-deploy — superwizor-www site + GitHub Actions CI

### Slice 3 — registration flows (DONE, merged to `feat/web-app` at 7b10f48)
8 features, all PASS evaluator, 8 commits + 1 merge:
- register-therapist-email     — /register/therapist email form per §13.2
- register-therapist-google    — Continue with Google + finish-profile page
- register-organization-email  — clinic founder signup with HQ address
- register-organization-google — Google OAuth org path
- email-verification-gate      — polling + auto-redirect on verified
- accept-invite-page           — /accept-invite + AcceptInvitation RPC
- login-redirect               — /login 307 → app.superwizor.ai/login
- registration-e2e-playwright  — Playwright happy-path, 2/2 green

### Slice 4 — admin console (PARTIAL, merged to `feat/web-app` at ded7f3d)
2/8 features landed; 6 deferred. The chrome + guard are in place so
features 3-8 can land in any order:
- ✅ admin-auth-guard   — /admin layout with role=SUPERWIZOR_ADMIN gate
- ✅ admin-shell-nav    — sidebar + header chrome
- ⏸ admin-orgs-list
- ⏸ admin-org-detail
- ⏸ admin-org-actions
- ⏸ admin-org-edit
- ⏸ admin-user-crud
- ⏸ admin-audit-log

## In progress

- **Slice 5** — Flutter Web consoles at `app.superwizor.ai`. Branch:
  `feat/web-app-slice-5` (branched off post-Slice-4-partial merge).
- ✅ flutter-web-target — web platform live, build green, recording
  screen kIsWeb-guarded. Login renders cleanly on web.

### Flutter audio-conversion data-loss fix (branch `fix/app-audio-conversion`, 2026-06-04)

Commit `85c6cc3`, off `main`. **Not yet merged** — awaiting device smoke
test on Marcin's iPhone build.

- **Bug:** file-upload → "Konwertuję" screen → tapping back lost the
  whole session (also app-kill / OS cache purge mid-convert). Root
  cause: client-side conversion (M4A→FLAC, WAV normalize) ran as an
  inline `await` inside `NewSessionScreen` *before* any durable
  `PendingUpload` existed — an interruption returned early past the
  enqueue, and the `finally` even deleted the converted output.
- **Fix:** conversion is now a durable queue phase
  (`UploadPhase.converting`). The row is persisted to Hive the instant
  the file is staged; `UploadIo.convertSource` runs the transcode in
  the worker (writing the FLAC into `queued_uploads/<localId>/`,
  durable + swept by `cleanupSource`); iOS decode-failure / non-iOS
  fall back to the original + `needsServerSideConversion=true` (server
  ffmpeg, no data loss). New `UploadQueueRunner.enqueue()` persists
  without ticking so the screen navigates immediately instead of
  blocking on the first (minute-long) transcode tick. Cancel now works
  during conversion. Gotcha for next time: `copyWith` had to gain
  `sourcePath/contentType/sizeBytes/actualDurationSeconds` params (were
  immutable post-construction) so the worker can repoint the source at
  the transcoded file.
- **Tests:** 4 new converting-phase worker tests; `upload_worker_test`
  +25 / `upload_queue_test` +10 / `pending_upload_test` +7 all green;
  `flutter analyze` 0 new issues. NOTE: `upload_state_transitions_test`
  (+2 −13) and `upload_queue_runner_test` (+3 −7) have **pre-existing**
  flaky failures — verified identical on the clean baseline via
  `git stash` (real-timer/Hive runner-lifecycle tests:
  retryFailed/dismiss/connectivity). Worth a separate cleanup task.
  Evidence: `evidence/fix-app-audio-conversion/`.

### Recording lost on phone call (branch `fix/recording-call-interruption`, 2026-06-09)

Off `main` (83b6e41…). **Not yet merged** — code complete
(WS1–**WS5** of `docs/28_RECORDING_INTERRUPTION_RESILIENCE.md`), awaiting the
on-device manual matrix (docs/28 §8.3 M1–M10) on physical iPhone **+ Android**;
phone-call interruptions can't be simulated.

- **Bug:** incoming phone call during a session recording → recorder
  natively auto-pauses (record_ios `AudioInterruptionMode.pause` default)
  and never resumes; app never subscribed to `onStateChanged` so UI kept
  saying "recording"; if the backgrounded app was killed during the call,
  the partial `raw.flac` was orphaned with no recovery path → session
  totally lost.
- **Fix:** (1) durable `manifest.json` written next to `raw.flac` at
  recording start + once-per-launch orphan-recovery scan with send/later/
  delete sheet on HomeScreenV2 (`RecordingRecoveryGuard`); (2) native
  state sync with intent timestamps → new `RecordingState.interrupted` +
  banner, frozen duration clock; (3) verified resume: iOS
  `superwizor/audio_session` MethodChannel reactivates the AVAudioSession
  (plugin's resume never does), then a **file-growth probe** confirms
  capture (plugin's `isRecording()`/state stream flip optimistically even
  when `AVAudioRecorder.record()` fails — verified in plugin source, do
  NOT trust them); (4) `actualDurationSeconds` excludes interruption gaps.
- **Gotchas for next time:** `RecordingService` now takes injectable
  recorder/documentsDir/wakelock for tests; plugin `isPaused()` is the
  meaningful reconcile probe (`isRecording()` = `state != stop`, so
  paused counts as recording!); new Swift file had to be hand-added to
  `project.pbxproj` (4 entries, mirror AudioConverter.swift).
- **WS5 — Android foreground service (NOW IMPLEMENTED):** `record` plugin
  has no FGS, so a backgrounded Android recording dies on a long call.
  Added `RecordingForegroundService.kt` (microphone FGS +
  `START_NOT_STICKY` + ongoing notification), `superwizor/recording_fgs`
  channel in `MainActivity.kt`, `<service microphone>` +
  `POST_NOTIFICATIONS` in the manifest, and
  `recording_foreground_service.dart` (best-effort, Android-only, never
  aborts recording). Notification strings flow from the l10n pipeline
  (`recording_fgs_notification_*`); Kotlin has PL fallbacks. Started in
  `RecordingService.start`, stopped on stop/cancel/unexpected-stop.
- **R1 RESOLVED — recovered FLAC forced through server ffmpeg:** instead
  of betting Chirp accepts an unfinalized FLAC header, `recover()` uploads
  with content-type **`audio/x-flac`** (a real FLAC MIME that's NOT in the
  server's `IsChirpSupported` list) → ingestion-svc runs its lossless
  ffmpeg re-encode → clean header. Server's ext-map defaults unknown types
  to `.flac` so ffmpeg demuxes correctly; a `audio/mp4` mislabel would
  break the demuxer (`.m4a` path), hence x-flac. **Backend gotcha:** the
  coupling lives in `converter.go:IsChirpSupported` — locked by a new case
  in `converter_test.go` (`audio/x-flac` → false). The local
  `needsServerSideConversion` bool is NOT sent on the RPC; content-type is
  the only server trigger.
- **Tests:** 26 recording unit tests green + backend `TestIsChirpSupported`
  green + `go build ./services/ingestion-svc/...` clean; full Flutter suite
  181 green, analyze at 20-issue baseline.

### Out-of-slice fixes / improvements landed 2026-05-29

All on `feat/web-app`. Independent of any specific slice; ship-ready as
hotfixes to the in-flight web build.

- **Therapist `/account/` page first-class on the marketing origin.**
  Profil + Organizacja + Subskrypcja sections, all PL+EN, with i18n
  ARB-equivalent keys under the `account.*` namespace. Profil + Org are
  collapsible (default-closed) and use a +20% bigger input variant per
  user feedback. Header (email + Otwórz kartoteki + sign-out) also +20%.
  Commits: `5725d12`, `ffbf113`, `2f474aa`, `6e1b3d9`.
- **Subskrypcja card calls billing-svc directly** (`aff0e8e`+
  `2b29922`). The earlier `clinical.GetMyBillingState` proxy was
  intermittently RST_STREAM-ing inside Cloud Run; bypassing it matches
  the proven /admin/orgs `ZMIEŃ PLAN` pattern. **Pre-req on the
  backend:** `billing-svc.GetSubscription` now enforces caller-org
  scope (commit `7e4f2d9`, deployed as `billing-svc-00086-vwt`) — the
  Connect interceptor populates `x-superwizor-organization-id` from
  the validated Firebase token, and any browser caller whose org
  doesn't match the requested `organization_id` gets
  `PermissionDenied`. Server-to-server callers (native gRPC, no
  metadata) bypass; `SUPERWIZOR_ADMIN` bypasses for cross-org reads.
- **Post-email-verification redirect → same origin `/account/`.**
  `ResendVerificationButton.tsx` polls `currentUser.reload()` and on
  `emailVerified=true` now navigates to `/${locale}/account/` instead
  of `https://superwizor-app.web.app/`. Avoids the cross-origin
  re-login that killed the just-completed signup (Firebase Auth
  IndexedDB is origin-scoped). i18n key renamed
  `verifiedGoToApp` → `verifiedGoToAccount`. Commit `18d7030`.
- **Cross-origin SSO from marketing-site → Flutter app.** Otwórz
  kartoteki on `/account/` now mints a short-lived Firebase custom
  token via `identity-svc.MintAppLoginToken` (new RPC), opens
  `https://superwizor-app.web.app/#auth_token=<jwt>` in a new tab, and
  the Flutter web bundle redeems via `signInWithCustomToken` before
  `runApp` (conditional import on `dart.library.html` keeps iOS/Android
  untouched). Token is in the URL fragment, not the query string —
  hashes don't reach Firebase Hosting logs and aren't included in
  Referer headers on outbound clicks. On any failure (mint RPC down,
  popup blocked, token expired) the flow gracefully degrades to the
  pre-SSO `?email=` prefill so the user can still log in by hand.
  Backend commit `fbc3b67`, marketing-site `aff0e8e`, Flutter web
  `3d55ae7`. One-time IAM: granted
  `roles/iam.serviceAccountTokenCreator` to the compute SA on itself
  so the Admin SDK can sign custom tokens via the IAM Credentials API
  without an SA private-key JSON. Switched identity-svc Firebase init
  from `option.WithoutAuthentication()` → plain `firebase.NewApp` so
  it can resolve ADC for the signing call.
- **billing-svc `ConnectErrorInterceptor`** (commit `2b7919f`,
  deployed `billing-svc-00087-ddr`). Connect-Go does not auto-translate
  `status.Errorf(codes.X, ...)` errors — it sees a plain `error` and
  wraps them as `connect.CodeUnknown`, so every admin browser RPC
  surfaced as "Wystąpił nieznany błąd" regardless of the real cause
  (PermissionDenied, FailedPrecondition, NotFound, Internal…). The new
  interceptor sits after the auth interceptor, translates 1:1, and
  slogs the original error type + procedure path so handler-side
  failures are visible in Cloud Logging. **Action item:** the SAME
  bug almost certainly exists in identity-svc and clinical-svc's
  Connect chain; lift the interceptor into `pkg/connectmd/` and add
  to all three services in a follow-up.
- **Staging Cloud SQL schema synced to migrations 035, 036, 037.**
  The webhook + audit flow had been silently failing for weeks
  because `audit_events.reason` didn't exist on staging Postgres —
  `golang-migrate up` against `superwizor-db-bc4c27de` applied
  invitations (035), audit_events.reason (036), and user_role_extend
  (037). DB is now at version 37, dirty=false. Done via cloud-sql-proxy
  on port 5438 with the password from the `superwizor-db-password`
  Secret Manager secret.

### Known-but-deferred

- **Marcin's stuck audio upload (session `5930f11c-...`).** Row in
  `audio_uploads` has status=PENDING, content_type=audio/flac, NULL
  file_size_bytes — Flutter never PUT to GCS. GCS audit logs confirm
  no PUT attempt. Two `billing reserve` log lines 6 min apart show
  the worker is retrying CreateAudioUpload (the `signedUrlExpired`
  classify path bounces phase=created → phase=pending after the PUT
  fails locally on Marcin's phone). Root cause is on his iPhone (most
  likely `file.readAsBytes()` throwing because iOS purged the tmp
  FLAC file between conversion + PUT). Row auto-expires
  `2026-05-31 11:11:28 UTC`; reserved token is released then.
  Definitive fix is the post-`a5e8f4c` Flutter build (M4A→FLAC
  staging-dir fix) but install on Marcin's iPhone is blocked on the
  Apple Developer Personal Team bundle-ID reclaim (task #147).
- **Apple Developer Personal Team reclaimed `ai.superwizor.superwizor`.**
  Xcode can't re-register the App ID; iOS builds for new devices
  fail at the provisioning step. Pending path chosen with the user:
  change bundle ID to `ai.superwizor.therapist`, register the new
  ID in Firebase Console (manual step the user owns), then update
  Xcode project + `GoogleService-Info.plist`. Long-term fix is
  enrolment in the paid Apple Developer Program.

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

- **Toolchain ready:** Node 20.20.2 + pnpm 9.15.9 installed. Node 20 is
  keg-only at `/usr/local/opt/node@20/bin/node`; PATH is persisted in
  `~/.bash_profile` so every new login shell sees it. Corepack's pnpm
  shim was disabled (`corepack disable pnpm`) and pnpm@9 installed via
  npm-global so it resolves through `/usr/local/bin/pnpm` →
  `pnpm.cjs` running under node@20. `bash -lc 'node --version && pnpm
  --version'` should print `v20.20.2` and `9.15.9` from any new shell.
  The legacy 2017 Node v6 at `/usr/local/bin/node` is left in place but
  shadowed by node@20 via PATH order. Do NOT call `node` by absolute
  path `/usr/local/bin/node` — that hits v6 and will SyntaxError on
  modern JS.
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
