# Plan: Firebase Analytics instrumentation of the Flutter app

Goal: understand how therapists use the app — which screens they visit, in
what order, where they drop off, and which actions they take — by capturing
**screen views** and **user actions** with Firebase Analytics.

## 0. The hard constraint first: PHI / RODO

This is a clinical app. **Analytics must never receive PHI or identifying
data.** That means NO:

- patient names, working aliases, e-mails, or any free text the therapist types
- transcript text, report text, note title/body, action-plan content
- audio, file names, signed URLs

What is allowed: screen names, action names, coarse non-identifying metadata
(counts, durations, enum-like statuses, booleans, modality CODE like "CBT").
Identifiers like `session_id`/`patient_file_id` are UUIDs — treat them as
**off by default** (they're pseudonymous but still linkable); only include a
hashed/opaque form if a specific funnel needs it, and document why.

Concretely:
- A single `Analytics.log(...)` wrapper is the ONLY way events are sent, and it
  runs every param through a **deny-by-default allowlist** (see §5). Anything
  not on the allowlist is dropped, so a careless `name: patient.firstName`
  can't leak.
- `setUserId` / `setUserProperty` MUST NOT be the therapist e-mail or name —
  use the backend user UUID at most (and only if consented).
- Add a unit test that fails if a forbidden key (`name`, `email`, `title`,
  `text`, `alias`, `query`, …) reaches the wrapper.

Consent: analytics collection is gated behind an explicit opt-in (RODO).
Default OFF until the user accepts; `setAnalyticsCollectionEnabled(false)`
until then. Provide an opt-out in Settings. Document retention in the privacy
policy. (Confirm with the DPA owner before shipping.)

## 1. Package + project setup

- Add `firebase_analytics` (matching the `firebase_core ^4.x` BoM) to
  `pubspec.yaml`. Firebase is already initialised in `main.dart`
  (`Firebase.initializeApp`), so no new init plumbing.
- iOS: Analytics works with the existing `GoogleService-Info.plist`. Add
  `FirebaseAnalyticsCollectionEnabled = NO` in Info.plist so collection starts
  OFF and is enabled at runtime only after consent.
- Enable **DebugView** for development (`-FIRDebugEnabled` arg) to verify events
  live without waiting for the 24h batch.

## 2. Architecture — one service, Riverpod-provided

```
analyticsProvider  ->  AnalyticsService
                         ├─ FirebaseAnalytics.instance (real)
                         ├─ consent gate (no-op until opted in)
                         ├─ debug/test no-op impl (logs to console only)
                         └─ param sanitiser (allowlist, §5)
```

- `AnalyticsService.logScreen(String screen, {Map? params})`
- `AnalyticsService.logAction(String screen, String action, {Map? params, String? result})`
- Thin, sync, never throws (wrap in try/catch — analytics must never crash a
  clinical workflow).
- Inject via `ref.read(analyticsProvider)` (consistent with the existing
  Riverpod codebase). A `kReleaseMode ? FirebaseAnalyticsService : NoopService`
  split keeps test/debug clean.

## 3. Screen tracking — the nav reality

The app uses **imperative navigation**: `MaterialApp(home:)`, ~34
`MaterialPageRoute`, **~62 `showModalBottomSheet`**, only 1 named route. So
`FirebaseAnalyticsObserver` alone won't capture much (it keys off
`RouteSettings.name`, which we don't set). Two-part approach:

1. **Full-screen routes** — attach a `FirebaseAnalyticsObserver` to
   `MaterialApp.navigatorObservers`, AND give every pushed route a name:
   `MaterialPageRoute(settings: RouteSettings(name: 'report'), builder: …)`.
   A lint/grep sweep finds the 34 `MaterialPageRoute` call sites; add names to
   each. The observer then auto-logs `screen_view` on push/pop.

2. **Bottom sheets (the bulk of the UX)** — the 62 sheets are modal routes;
   wrap the project's `showEuphireBottomSheet`/`showModalBottomSheet` calls in
   a helper `showTrackedSheet(name: 'edit_patient_sheet', …)` that logs a
   `screen_view` (or `sheet_open`/`sheet_dismiss`) on open/close. Centralising
   in the existing `showEuphireBottomSheet` wrapper covers most of them in one
   edit.

3. **Belt-and-suspenders** — a `ScreenTrackingMixin` on `State` that calls
   `logScreen` in `initState`, for screens/sheets the observer can't see
   (e.g. `IndexedStack` tabs, conditionally-rendered bodies). Use it where the
   route-name approach is awkward.

Screen-name registry: a single `AnalyticsScreens` constants file so names are
stable, unique, and reviewable in one place (no stringly-typed drift).

## 4. Event taxonomy

Naming: `snake_case`, `<noun>_<verb>` or `<screen>_<action>`, ≤40 chars
(GA limit). Stable names — renaming breaks historical funnels.

Standard params on EVERY event (all non-PHI):
- `screen` — origin screen name
- `surface` — where in the screen (e.g. `appbar`, `fab`, `options_sheet`)
- `result` — `success` | `error` | `cancelled` | `blocked` (where meaningful)
- `duration_ms` — for timed actions (recording length bucketed, not raw)
- coarse context: `modality_code`, `session_status`, `has_email` (bool),
  `note_kind`, `report_count` — never the values themselves.

### Screen + action inventory (instrument these)

| Screen | screen_view name | Key actions to log |
|---|---|---|
| Auth — login | `auth_login` | `auth_login_attempt`, `auth_login_success`, `auth_login_error`, provider (google/apple/email) |
| Auth — register/verify/setup | `auth_register` / `auth_verify` / `therapist_setup` | step views, `register_submit`, `verify_resend`, `setup_complete` |
| Home | `home` | `home_search` (no query text), `add_patient_open`, `patient_open`, `patient_options_open`, `patient_pause/archive` |
| Add patient sheet | `add_patient_sheet` | `add_patient_save` (result), `add_patient_cancel`, `has_email` bool |
| Edit patient (modal + home sheet) | `edit_patient_sheet` | `edit_patient_save` (result), `edit_patient_delete`, `has_email` |
| Client details | `client_details` | `record_start`, `note_add_open`, `upload_open`, `report_open`, `session_options_open` |
| New session / recording | `new_session` / `recording` | `record_start`, `record_stop` (duration bucket), `record_discard`, `record_submit` |
| Session status | `session_status` | `session_status_view` (with `session_status` param), `session_cancel` ("Usuń z analizy"), `back_to_records` |
| Report | `report` | `report_view`, `report_copy`, `report_rate` (up/down), `action_plan_send_open`, `report_section_edit` |
| Note editor / action plan | `note_editor` | `note_save`, `note_save_send` (result incl. `send_error` code), `note_delete` |
| Session manage sheet | `session_options_sheet` | `session_rename` (result), `session_delete` (result) |
| Report preferences | `report_prefs` | `prefs_save`, suggestion accept |
| Settings / account | `settings` | `logout`, `account_delete_open/confirm`, `analytics_optout` |

Cross-cutting events worth a dedicated funnel:
- **Session lifecycle funnel**: `record_start` → `record_submit` →
  (server) `session_status_view` per status → `report_view`. Lets us see
  drop-off between recording and reading the report.
- **Action-plan funnel**: `action_plan_send_open` → `note_save_send`
  (`result`, `send_error`) — measures the feature you just built.
- **Errors**: a generic `app_error` event (screen, action, error_code — no
  message text) so we see where users hit failures (e.g. the delete/rename
  bugs would have surfaced as `session_delete` with `result=error`).

## 5. The param sanitiser (the safety net)

```
const _allowedKeys = {
  'screen','surface','result','duration_ms','modality_code','session_status',
  'note_kind','has_email','report_count','provider','error_code','count', ...
};
Map<String,Object> _sanitise(Map<String,Object?> p) =>
  { for (final e in p.entries) if (_allowedKeys.contains(e.key) && e.value != null) e.key: e.value! };
```
- Drop anything not allowlisted; log a debug warning if something was dropped
  (catches mistakes during dev).
- Values must be primitives/enums — assert no free-form strings sneak through
  (e.g. reject values > 36 chars unless they're a known enum).

## 6. Implementation phases

1. **Foundation** (1 PR): add `firebase_analytics`, `AnalyticsService` +
   provider + sanitiser + consent gate + no-op for test/debug, the
   `AnalyticsScreens` registry, and the forbidden-key unit test. Wire the
   `FirebaseAnalyticsObserver`. Ship with collection OFF.
2. **Screen views** (1 PR): name the 34 routes + wrap `showEuphireBottomSheet`;
   add the mixin where needed. Verify every screen/sheet emits one
   `screen_view` in DebugView.
3. **Core actions** (1–2 PRs): instrument the high-value actions — session
   lifecycle funnel, report view/rate/copy, action-plan send, patient
   add/edit/delete, session rename/delete, auth.
4. **Errors + consent UI** (1 PR): `app_error` everywhere a user-facing
   error toast fires; the consent opt-in on first run + Settings opt-out.
5. **Dashboards**: define the funnels in GA4 (or BigQuery export) — session
   completion, action-plan send rate, error hotspots, screen flow.

## 7. Verification ("proof before passing")

- DebugView screenshot showing `screen_view` for each screen + the funnel
  events firing, captured during a manual run on a device.
- Unit test: sanitiser drops forbidden keys; `logAction` with a PHI-looking
  param emits nothing for that param.
- A debug overlay (dev builds) that prints the last N analytics events on
  screen, so QA can eyeball that no PHI is present.
- Privacy review sign-off (DPA owner) before enabling collection in prod.

## 8. Non-goals / later

- No session replay / heatmaps (PHI risk, out of scope).
- No third-party analytics SDKs — Firebase only (already in the stack).
- Crash reporting (Crashlytics) is a separate, complementary effort — worth
  doing but tracked elsewhere.
