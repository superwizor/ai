# 20. Web frontends — design, structure, configuration, security

> Status: living document, last revised 2026-05-29.
> Scope: the two browser surfaces that ship with the Superwizor AI
> platform — `marketing-site` (Next.js, served at
> `https://superwizor.web.app`) and the Flutter web app (`flutter-app/superwizor`
> compiled to the `web` target, served at `https://superwizor-app.web.app`).
> Both originated in `docs/18_WEB_APP_DESIGN.md`; this doc digs into the
> as-built architecture, file layout, configuration surface, and
> security model. Anything contradicting this doc in 18 is older.

## 1. Map of the territory

```
┌─────────────────────────────────────────────────────────────────────┐
│  Browser                                                            │
│  ┌───────────────────────────┐    ┌───────────────────────────┐    │
│  │ superwizor.web.app        │    │ superwizor-app.web.app    │    │
│  │ Next.js 16 static export  │    │ Flutter Web (DartJS)      │    │
│  │ marketing-site/out/       │    │ flutter-app/.../build/web │    │
│  │                           │    │                           │    │
│  │ • Marketing (PL+EN)       │    │ • Therapist console       │    │
│  │ • Registration            │    │ • Kartoteki + sessions    │    │
│  │ • /login, /account        │    │ • (mobile-shared codebase │    │
│  │ • /admin/* (SUP_ADMIN)    │    │   with kIsWeb branches)   │    │
│  │                           │    │                           │    │
│  │ Firebase Auth (IndexedDB) │    │ Firebase Auth (IndexedDB) │    │
│  │ Connect-Web → backend     │    │ gRPC-Web → backend        │    │
│  └────────────┬──────────────┘    └─────────────┬─────────────┘    │
└───────────────│───────────────────────────────────│───────────────┘
                │                                   │
                │   custom-token #fragment SSO      │
                │   (browser-to-browser hop on      │
                │    Otwórz kartoteki click)        │
                │                                   │
                ▼                                   ▼
        ┌───────────────────────────────────────────────────┐
        │  Cloud Run (europe-central2) — h2c mixed handler  │
        │  ┌──────────┬──────────┬──────────┬──────────┐    │
        │  │ identity │ billing  │ clinical │ ingestion│    │
        │  └──────────┴──────────┴──────────┴──────────┘    │
        │  Each port answers Connect + gRPC-Web + native    │
        │  gRPC simultaneously (dispatch by Content-Type)   │
        └───────────────────────────────────────────────────┘
```

Two browser origins. Two Firebase Hosting sites (`superwizor` +
`superwizor-app`). One Firebase project (`superwizor-ai-25ecd`),
one user pool. Backend is shared.

The **two-origin split is intentional** (docs/18 R3 origin discipline):
keeps the marketing site and the Flutter app on separate IndexedDB
buckets so the marketing site can never accidentally read a
therapist's recorded-session-in-progress state, and so a future
public-facing landing page can run in a sandboxed origin without
giving up the keys to the production app. The price is that we can't
share Firebase Auth sessions trivially across the two; the **custom
token SSO** in §6.3 is how we bridge that intentionally.

## 2. marketing-site (Next.js)

### 2.1 Build profile

| Item | Value | Why |
|---|---|---|
| Framework | Next.js 16, App Router | Latest stable; this is **not** the Next.js most LLMs know — read `node_modules/next/dist/docs/` before changing routing or rendering primitives. The repo's `marketing-site/AGENTS.md` flags this. |
| Output | `output: "export"` (pure static) | Avoids `firebase-frameworks` adapter; that pipeline kept breaking Cloud Build (npm-ci-against-pnpm-lockfile, 2026-05-28 incident). Static export gives plain HTML/JS that Firebase Hosting serves at the edge. No Cloud Functions involved. |
| Trailing slash | `trailingSlash: true` | Static export emits one directory per route with an `index.html`; trailing slashes make the URLs work without server-side rewrites. |
| Images | `images.unoptimized = true` | Static export can't run the default image optimiser. We ship few images; design-time optimisation suffices. |
| Toolchain | Node 20.20.2 + pnpm 9.15.9 | Node 20 keg-only at `/usr/local/opt/node@20/bin/node`. Legacy 2017 Node v6 at `/usr/local/bin/node` is shadowed by PATH order — don't call it directly, modern JS will SyntaxError. |

### 2.2 Source tree

```
marketing-site/
├── src/
│   ├── app/                          # Next.js App Router
│   │   ├── [locale]/                 # `pl` | `en` parametrised root
│   │   │   ├── page.tsx              # Landing
│   │   │   ├── login/                # NEW (2026-05-29) on-origin sign-in
│   │   │   ├── pricing/
│   │   │   ├── legal/[slug]/         # Terms / Privacy / DPA (markdown)
│   │   │   ├── register/
│   │   │   │   ├── therapist/
│   │   │   │   │   ├── page.tsx           # Email signup form
│   │   │   │   │   ├── finish/page.tsx    # Google-OAuth path completion
│   │   │   │   │   └── verify-email/      # Email-gate interstitial
│   │   │   │   └── organization/...       # Clinic founder signup
│   │   │   ├── accept-invite/        # Magic-link landing
│   │   │   ├── account/              # Therapist account dashboard
│   │   │   └── admin/                # SUPERWIZOR_ADMIN console
│   │   │       ├── orgs/             # List + /[id] detail
│   │   │       ├── users/
│   │   │       └── audit/
│   │   └── globals.css               # Tailwind 4 @theme — Euphire tokens
│   ├── components/
│   │   ├── account/                  # /account dashboard
│   │   ├── admin/                    # /admin/* (AdminGuard, OrgDetail, …)
│   │   ├── auth/                     # LoginForm
│   │   ├── forms/                    # Shared form primitives
│   │   ├── marketing/                # Navbar, Footer, hero sections
│   │   └── register/                 # 4 signup forms + email-gate
│   ├── content/                      # Markdown for legal pages
│   ├── i18n/                         # next-intl runtime config
│   │   └── request.ts                # Per-request locale negotiation
│   ├── lib/
│   │   ├── connect/                  # Connect-RPC transports + clients
│   │   ├── firebase/                 # Web SDK init + AuthProvider
│   │   ├── billing/                  # billing-svc helpers
│   │   ├── clinical/                 # clinical-svc helpers
│   │   ├── errors/translate.ts       # Connect-error → i18n key map
│   │   └── register/                 # Multi-step signup state
│   ├── messages/                     # next-intl message catalogues
│   │   ├── pl.json
│   │   └── en.json
│   └── proxy.ts                      # next-intl middleware shim
├── public/                           # Static assets (favicon, logos)
├── out/                              # next build output (gitignored)
├── .env.local.example                # Dev env template
├── .env.production.local             # Build-time prod env (gitignored)
├── next.config.ts
├── tailwind.config.* / @theme in CSS
└── package.json
```

### 2.3 Routing model

Pages live under `src/app/[locale]/...`. The `[locale]` segment is one of
`pl` or `en` and resolves via `next-intl`'s App Router integration.
Polish is the default; English is fallback. The historic
`localePrefix: 'as-needed'` (no `/pl/` prefix for the default locale)
worked at SSR/dev but **static export forces explicit directories**
(`out/pl/...` and `out/en/...`). To preserve the no-prefix UX,
`firebase.json` redirects bare `/`, `/register/*`, `/admin/*`,
`/legal/*`, `/pricing/`, `/accept-invite/`, `/login/` to `/pl/...`
via 307. Loops are avoided by writing one redirect per top-level
segment instead of a single catchall (which would also match `/pl/*`).

Two routes are dynamically scoped at runtime:

- **`/{locale}/admin/orgs/[id]`** — static export can't pre-render every
  org UUID. We ship one template per locale (literal
  `out/{pl,en}/admin/orgs/[id]/index.html`) and Firebase Hosting
  rewrites all matching traffic to it (`firebase.json` `rewrites`).
  The client component reads `usePathname()` and fetches the org via
  `identityClient.adminGetOrganization`.
- **`/{locale}/register/therapist/verify-email`** — same template,
  reads `?email=` query at runtime for the "we sent it to <email>"
  intro line.

### 2.4 i18n contract

- **All UI strings** route through `next-intl` keys defined in
  `messages/pl.json` and `messages/en.json`. The evaluator hook denies
  hard-coded Polish in components.
- **Namespaces** (top-level keys) mirror the page tree: `landing`,
  `pricing`, `register.therapist`, `register.verifyEmail`, `account`,
  `admin`, `errors`, `legal`.
- **Error namespace** (`errors.*`) is shared across all surfaces — see
  §5.2 for the Connect-error translation map.
- **L10n parity CI** (Slice 6 task #110) detects key drift between
  `pl.json` and `en.json`. Don't add a key to one without the other.

### 2.5 Styling

Tailwind 4's `@theme` block declares the Euphire design tokens in
`src/app/globals.css`. The colour ramp + tracking + shadow vars there
are the single source of truth — the iOS Flutter theme
(`flutter-app/superwizor/lib/theme/euphire_theme.dart`) mirrors them by
hand, with a comment pointing back. Don't divergently change one;
keep both in lockstep.

## 3. Flutter web app (`superwizor-app.web.app`)

### 3.1 Build profile

| Item | Value | Why |
|---|---|---|
| Engine | Flutter Web (DartJS, via `flutter build web --release`) | Same Dart codebase as the iOS/Android app; web is an additional target, not a fork. |
| State | Riverpod (`flutter_riverpod`) | Pre-existing on mobile; reused on web. |
| Auth | `firebase_auth` Web SDK (origin-scoped IndexedDB) | `signInWithEmailAndPassword`, `signInWithCustomToken`. |
| Storage | `cloud_firestore` (mirror reads), `hive_flutter` (web-localStorage-backed) | Web uses IndexedDB under the hood for Hive. |
| RPC | `package:grpc` v5 over `GrpcOrGrpcWebClientChannel` (`services/grpc_client.dart`) | The same channel API works on mobile (HTTP/2 native gRPC) and web (gRPC-Web fallback). The backend's h2c mixed handler accepts both. |
| URL strategy | Default Flutter web hash strategy (`/#/path`) | Means our cross-origin SSO transport uses a **non-routing** fragment shape (`#auth_token=...`, no leading slash) so the Flutter router ignores it. |

### 3.2 Source tree (web-relevant subset)

```
flutter-app/superwizor/
├── lib/
│   ├── main.dart                     # _AuthGate, applySsoFromUrl,
│   │                                 # Firebase init, Hive init
│   ├── auth/
│   │   ├── sso_handler.dart          # Stub for iOS/Android (no-op)
│   │   └── sso_handler_web.dart      # dart:html redeems #auth_token
│   ├── firebase_options.dart         # Multi-platform Firebase config
│   ├── screens/
│   │   ├── login_screen.dart         # kIsWeb shows "Powrót do strony
│   │   │                             # głównej" instead of "Zarejestruj"
│   │   ├── home_screen.dart
│   │   ├── new_session_screen.dart   # File-picker upload (web-friendly)
│   │   └── recording_screen.dart     # kIsWeb-guarded (web can't
│   │                                 # record yet — banner shown)
│   ├── services/
│   │   └── grpc_client.dart          # GrpcOrGrpcWebClientChannel × 5
│   ├── theme/euphire_theme.dart      # Mirrors marketing-site tokens
│   ├── l10n/                         # PL + EN ARB → generated Dart
│   └── uploads/                      # Hive-backed upload queue
├── web/
│   ├── index.html                    # Flutter bootstrap, $FLUTTER_BASE_HREF
│   ├── manifest.json
│   └── icons/
├── pubspec.yaml
└── ios/, android/, macos/, ...       # Other platforms
```

### 3.3 Platform-conditional code

- `if (kIsWeb)` checks gate UI affordances that don't work in browsers
  (audio recording uses native iOS APIs; we hide the record button on
  web and show a "use the iOS app" banner instead).
- Conditional imports (`import 'foo.dart' if (dart.library.html) 'foo_web.dart'`)
  swap the platform impl at compile time. We use this for
  `sso_handler.dart` (web reaches `window.location.hash`; mobile
  doesn't need to). This keeps the mobile bundle free of `dart:html`,
  which would otherwise break the iOS build.
- The recording screen has a comment cap at the top noting which
  blocks are gated on `kIsWeb` and why.

### 3.4 Surfaces on web

Slice 5 features 1-3 landed (web target, login, therapist console).
Features 4-7 (profile edit, org-admin tabs) are still in flight on
`feat/web-app-slice-5`. The org-admin tab + profile edit reuse the same
Riverpod providers as mobile — the only new work is route-gating on
`role=ORG_ADMIN` and surfacing forms that mobile didn't need.

## 4. Hosting & deploy

### 4.1 Firebase Hosting layout

`firebase.json` declares two `hosting` sites under one project:

| `site` | Public dir | Origin | Owns |
|---|---|---|---|
| `superwizor` | `marketing-site/out` | `superwizor.web.app` (+ `superwizor.ai` custom domain) | Marketing + register + login + account + admin |
| `superwizor-app` | `flutter-app/superwizor/build/web` | `superwizor-app.web.app` (+ planned `app.superwizor.ai`) | Therapist + org-admin consoles |

Each site has its own `redirects` / `rewrites` block, deployed
independently:

```
# Marketing site only
pnpm --dir marketing-site build
firebase deploy --only hosting:superwizor

# Flutter web only
cd flutter-app/superwizor && flutter build web --release
firebase deploy --only hosting:superwizor-app
```

The deploy pipeline (CI) hits both after merge to `feat/web-app`.

### 4.2 Cache policy

Firebase Hosting's **default 1-hour HTML cache** is left in place — the
explicit decision in the 2026-05-29 deploy. Performance for repeat
visitors trumps deploy-instantness; new deploys propagate within an
hour as the edge nodes' TTLs expire. Browser-side `hard refresh`
bypasses the cache when needed.

JS / CSS / image assets get content-hashed filenames from
Next/Flutter's build and so are safe to long-cache (Firebase Hosting
defaults are fine).

### 4.3 Custom domains (planned)

- `superwizor.ai` → `superwizor` site (DNS cut over in Slice 6
  task #113).
- `app.superwizor.ai` → `superwizor-app` site (deferred).

Both run through Firebase Hosting's managed cert flow. The
`firebase.json` redirect block keeps working under custom domains —
all matchers are path-relative.

## 5. Communication with the backend

### 5.1 Protocol matrix

Every Go service runs an **h2c mixed handler** on a single port
(docs/18 R1). The HTTP server dispatches by `Content-Type`:

| Client | Content-Type sent | Backend handler |
|---|---|---|
| Marketing-site (Connect-Web) | `application/json` or `application/connect+json` | Connect handler (`grpcadapter.NewConnectAdapter(...)`) |
| Flutter web (`package:grpc` Web channel) | `application/grpc-web+proto` | Same Connect handler (it speaks gRPC-Web natively) |
| Flutter iOS / Android (`package:grpc` native) | `application/grpc` | Native gRPC server (`grpc.Server`) |
| Server-to-server (`google.golang.org/grpc`) | `application/grpc` | Native gRPC server |

There is **no separate gRPC-Web proxy**, no Envoy sidecar. The
Connect handler does both. Browser callers do not require server-side
adaptation work to ship.

### 5.2 marketing-site Connect setup

- `src/lib/connect/transport.ts` — `createServiceTransport({ baseUrl, tokenProvider })`
  wraps `@connectrpc/connect-web::createConnectTransport`. Adds a
  bearer-token interceptor (`Authorization: Bearer <id-token>`).
- `src/lib/connect/clients.ts` — three transports + three clients
  (`identityClient`, `billingClient`, `clinicalClient`). One client per
  service because each runs at its own Cloud Run hostname; the
  pricing-page anonymous read still uses `clinicalClient` (the
  token interceptor omits the header when no user is signed in).
- The `tokenProvider` is mutable (`setTokenProvider`). The Firebase
  `init.ts` wires it once on first auth-state read:
  `setTokenProvider(() => auth.currentUser?.getIdToken() ?? null)`.
  This breaks an import cycle (Firebase shouldn't have to be loaded
  before Connect clients).

### 5.3 Connect-error translation

`src/lib/errors/translate.ts` is the single map from Connect errors
to i18n keys:

1. **Substring match** on the error message (e.g. "reason must be >="
   → `errors.backend.reasonTooShort`). Most actionable failures are
   here.
2. **Connect code** lookup if no substring matched
   (`Code.PermissionDenied` → `errors.code.permissionDenied`). Covers
   the generic case.
3. **Generic fallback** (`errors.generic`).

**Bug class to know about (2026-05-29):** Connect-Go does NOT
auto-translate `status.Errorf(codes.X, …)` errors from
`google.golang.org/grpc/status`. It wraps them as `connect.CodeUnknown`,
which always falls through to `errors.code.unknown` (= "Wystąpił
nieznany błąd"). Fixed for billing-svc via the
`ConnectErrorInterceptor` (commit `2b7919f`). Identity-svc and
clinical-svc are still affected; lift the interceptor to
`pkg/connectmd/` in a follow-up.

### 5.4 Flutter web gRPC-Web setup

- `lib/services/grpc_client.dart` constructs five
  `GrpcOrGrpcWebClientChannel.toSingleEndpoint(...)` channels
  (identity, clinical, ingestion, notification, billing). The
  "Or" in the name means the channel picks gRPC vs gRPC-Web based on
  whether `dart:io` (mobile) or `dart:html` (web) is available — no
  application code branches.
- The Authorization header is set per-call via gRPC `CallOptions`
  (`metadata: () async => { 'authorization': 'Bearer ${await user.getIdToken()}' }`).
  Same shape as the marketing-site interceptor.

### 5.5 Direct browser calls vs server-side proxying

**Pattern**: browser calls each backend service **directly**. The
marketing site does NOT proxy requests through Next.js API routes; we
have no `/api/*` handlers, no Cloud Functions in front of the
services.

Rationale:

1. The proxy hop was the source of the 2026-05-29 `/account/`
   subscription bug — `browser → clinical-svc.GetMyBillingState →
   billing-svc.GetSubscription` intermittently RST_STREAM-d inside
   Cloud Run. Direct calls (`browser → billing-svc.GetSubscription`)
   were rock-solid.
2. Server-side proxies pay a roundtrip for each call without adding
   security (the bearer token authenticates both hops equally; there's
   no privileged operation the proxy could safely add on the user's
   behalf).
3. The static export model has no server runtime anyway — there's
   nowhere to host an API route without re-introducing a Cloud
   Function. We rejected that in 2026-05-28.

**Exception**: anything that requires a **service-account-issued
token** (admin migrations, idtoken-authenticated server-to-server
flows) lives on the backend. The browser never sees SA credentials.

## 6. Authentication & session management

### 6.1 Sign-in providers

- **Email + Password** — always on. `createUserWithEmailAndPassword`
  for signup, `signInWithEmailAndPassword` for login. Email
  verification flow gates new accounts.
- **Google OAuth** — on at launch. Uses Firebase's
  `signInWithPopup(GoogleAuthProvider)` on the marketing site. The
  authorized redirect URIs in the Google Cloud OAuth client cover all
  origins (see identity-svc agent doc §"Firebase OAuth providers").
- **Apple, Microsoft** — stubbed in `AuthProvider`, gated on Firebase
  Console toggles. Wiring them is a 3-line change once the providers
  are enabled (manual op).

### 6.2 Session persistence

- **Marketing site**: `setPersistence(auth, browserLocalPersistence)` —
  user stays signed in across page reloads. Token refresh is automatic
  via the Web SDK.
- **Flutter web**: Default persistence on web is also
  `browserLocalPersistence` (IndexedDB). Same model.
- **Origin scoping**: Firebase Auth's IndexedDB is keyed by origin.
  Sessions do NOT cross between `superwizor.web.app` and
  `superwizor-app.web.app`. This is intentional (R3 origin discipline).
  The bridge is §6.3.

### 6.3 Cross-origin SSO via custom token

Sign-in on the marketing site doesn't propagate to the Flutter app's
origin. Without intervention, clicking "Otwórz kartoteki" on
`/account/` would dump the user on the Flutter login screen.
`identity-svc.MintAppLoginToken` fixes this:

```
1. Browser on superwizor.web.app, signed in. User clicks Otwórz kartoteki.
2. Marketing site:
     window.open("about:blank", "_blank")     ← popup opened synchronously
                                                inside the click handler so
                                                Safari permits it
     token = await identityClient.mintAppLoginToken({})
                                              ← Connect-RPC, ID token in
                                                Authorization header
     popup.location.href =
       "https://superwizor-app.web.app/#auth_token=<jwt>"
3. Flutter web main():
     await Firebase.initializeApp()
     await applySsoFromUrl()                  ← reads window.location.hash
                                                signInWithCustomToken(jwt)
                                                history.replaceState to
                                                strip the fragment
     runApp()                                 ← _AuthGate first tick sees
                                                signed-in user → HomeScreen
4. No LoginScreen flash. No second password prompt.
```

**Security properties:**

- **Server NEVER reads a uid from the request.** The handler always
  mints for the caller's own `firebase_uid` (resolved from the verified
  Firebase ID token in the Authorization header). No escalation
  surface.
- **Custom-token TTL ≈ 1 hour** (Firebase Admin SDK default). The
  receiving origin redeems within seconds of minting; the token then
  becomes one-shot in practice (Firebase rejects reuse).
- **Token transport: URL fragment, not query string.** Fragments are
  not sent to Firebase Hosting (no access-log retention), are not
  included in the `Referer` header on outbound clicks, and are
  stripped from the URL bar immediately after redemption.
- **Graceful degradation**: any failure (mint RPC down, popup blocked,
  token expired, network blip) falls back to opening the Flutter
  origin with `?email=<email>` so the user can still log in by hand —
  the pre-SSO behaviour.
- **Mobile bundles unaffected**: conditional import on
  `dart.library.html` resolves to a no-op stub on iOS/Android. The
  mobile builds don't link `dart:html`.

**Operational requirements:**

- Identity-svc Firebase init must use ADC (not
  `option.WithoutAuthentication()`) so `CustomToken` can sign.
- The runtime SA needs `roles/iam.serviceAccountTokenCreator` on
  ITSELF so the IAM Credentials API allows signing without a
  private-key JSON.

### 6.4 Token lifetime & refresh

Firebase ID tokens have a **1-hour TTL**. The Web SDK refreshes them
automatically via the refresh token (stored in the same IndexedDB
bucket as the auth session). The marketing-site Connect transport
calls `user.getIdToken()` on **every** outbound RPC, which auto-renews
if needed.

Long-running operations (e.g. an STT job that takes 10 minutes) don't
hold a token client-side — the worker picks up the audio via the
GCS bucket notification flow and proceeds server-side. Browser
polling for status uses fresh tokens each call.

### 6.5 Sign-out

Sign-out clears the IndexedDB session on the current origin only. To
sign out of both surfaces a user has to sign out from each origin
(rare in practice — most users live on the Flutter app).

## 7. Authorization model (per role)

The same backend RBAC matrix (docs/18 §7) gates every RPC; the
frontends only enforce **route visibility**. Defence in depth — never
trust the client to gate auth.

| Role | Marketing-site routes | Flutter web routes |
|---|---|---|
| Anonymous | Landing, pricing, legal, register, accept-invite | Login only |
| `THERAPIST` | + `/account` | Kartoteki, sessions, transcripts |
| `ORG_ADMIN` | + `/account` (Organizacja section appears) | + `/admin/*` (org settings, therapists, billing) |
| `SUPERWIZOR_ADMIN` | + `/admin/*` (orgs, users, audit) | (use marketing site's /admin) |

### 7.1 Marketing-site `/admin/*` guard

`AdminGuard` (in `src/components/admin/AdminGuard.tsx`) wraps the
admin layout. It:

1. Calls `identityClient.getMyProfile({})` on mount.
2. If the response role is `SUPERWIZOR_ADMIN`, renders children.
3. Otherwise shows an inline sign-in form (since the user might just
   not be authenticated yet) or a "not authorised" message.

This is **UI gating only**. The backend (every admin RPC in
billing-svc + identity-svc) independently enforces
`requireSuperwizorAdmin()` via the resolved role from
`x-superwizor-role` metadata. A user who bypasses the UI guard still
gets `PermissionDenied` from the server.

### 7.2 Flutter `/admin` org-admin route

Slice 5 task #100 ships an analogous guard for the org-admin tab —
checks `role == ORG_ADMIN` before rendering. Same defence-in-depth
principle.

## 8. Configuration surface

### 8.1 marketing-site

#### Build-time env (NEXT_PUBLIC_* — visible in browser bundle)

| Var | Purpose | Example |
|---|---|---|
| `NEXT_PUBLIC_IDENTITY_URL` | identity-svc Cloud Run URL | `https://identity-svc-...run.app` |
| `NEXT_PUBLIC_BILLING_URL` | billing-svc Cloud Run URL | `https://billing-svc-...run.app` |
| `NEXT_PUBLIC_CLINICAL_URL` | clinical-svc Cloud Run URL | `https://clinical-svc-...run.app` |
| `NEXT_PUBLIC_FIREBASE_API_KEY` | Firebase Web API key | from Firebase Console |
| `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN` | `<project>.firebaseapp.com` | |
| `NEXT_PUBLIC_FIREBASE_PROJECT_ID` | `superwizor-ai-25ecd` | |
| `NEXT_PUBLIC_FIREBASE_APP_ID` | Web app ID | |
| `NEXT_PUBLIC_FIREBASE_USE_EMULATOR` | `1` to point Auth at `127.0.0.1:9099` | dev only |
| `NEXT_PUBLIC_SHOW_AUTH_BADGE` | `1` to show the dev auth badge on prod | optional |

`.env.local` (gitignored) holds dev values; `.env.production.local`
(also gitignored — populated by the CI step) holds the production
build values.

**There are no server-side env vars** for the marketing site — pure
static export. Anything sensitive (DB passwords, SA keys) lives on the
Cloud Run services, never in the browser bundle.

#### Build-time config

- `next.config.ts` — `output: "export"`, `trailingSlash: true`,
  `images.unoptimized: true`, next-intl plugin pointer.
- `tailwind.config.* / @theme in CSS` — Euphire brand tokens.
- `src/i18n/request.ts` — next-intl per-request locale negotiation.

#### Hosting config (root `firebase.json`)

- `redirects[]` — bare-path → `/pl/...` 307s (login, register, admin,
  legal, pricing, accept-invite). One per top-level segment to avoid
  catchall loops.
- `rewrites[]` — `/admin/orgs/**` → `/admin/orgs/[id]/index.html` per
  locale, for the dynamic-org-id route.

### 8.2 Flutter web

#### Build-time config

- `lib/firebase_options.dart` — multi-platform Firebase config; the
  web block is read when `kIsWeb`. The values are baked into the
  build, not env-driven, because Flutter web has no Next-style
  `NEXT_PUBLIC_*` mechanism. Regenerated via `flutterfire configure`.
- `web/index.html` — Flutter bootstrap. `$FLUTTER_BASE_HREF` is
  replaced at build time by `--base-href`; we use `/` for both staging
  and prod.
- `pubspec.yaml` — same as mobile; the web target is opt-in via
  `flutter create --platforms web` (already done; task #96 Slice 5
  feature 1).
- No runtime env layer — the gRPC endpoint URLs are baked at compile
  time. To swap staging vs prod, build two different bundles.

#### Hosting config (root `firebase.json`)

- `site: "superwizor-app"` block. No redirects or rewrites —
  Flutter's hash router owns all URL routing post-load.

### 8.3 Local dev

- **Backend**: `docker compose` (TBD) or run each Go service on its
  default port (`identity-svc :8080`, `billing-svc :8081`,
  `clinical-svc :8082`). Set `CORS_ALLOWED_ORIGINS=http://localhost:3000`
  on each.
- **Firebase emulator**: `firebase emulators:start --only auth` brings
  up Auth on `127.0.0.1:9099`. Set
  `NEXT_PUBLIC_FIREBASE_USE_EMULATOR=1` in `.env.local`.
- **marketing-site**: `pnpm --dir marketing-site dev` →
  `http://localhost:3000`.
- **Flutter web**: `cd flutter-app/superwizor && flutter run -d chrome --web-port 8080`.

## 9. Security model

### 9.1 Threat model

We assume the **browser is the most hostile environment** in the
stack. Token theft, XSS, malicious extensions, and shoulder-surfing
on shared machines are all in scope. The mitigations below stack.

### 9.2 Token handling

- **Bearer-token-only**. There are no auth cookies. CSRF is not a
  concern because no state-changing endpoint reads ambient
  credentials.
- **Firebase ID token, 1h TTL**. Refresh tokens persist in IndexedDB
  via the Web SDK; we never see or manipulate them ourselves.
- **No tokens in URLs** except the **one-shot custom token in the
  Flutter SSO handoff**, which is in the URL fragment (not query
  string), stripped immediately after redemption, and rejected by
  Firebase on reuse.
- **No tokens in localStorage** (Web SDK uses IndexedDB by default;
  we don't override).

### 9.3 CORS

Each Cloud Run service runs `pkg/cors` middleware reading
`CORS_ALLOWED_ORIGINS` env. Production list includes
`https://superwizor.ai`, `https://app.superwizor.ai`,
`https://superwizor.web.app`, `https://superwizor-app.web.app`,
preview-channel wildcards
(`https://superwizor--*.web.app`, `https://superwizor-app--*.web.app`),
and `http://localhost:3000` / `http://localhost:8080` for dev. The CI
deploy step bakes the value into `--update-env-vars` so manual edits
get restored on every redeploy.

### 9.4 Cloud Run IAM

Each service runs as a dedicated SA:

- `identity-svc@<project>.iam.gserviceaccount.com`
- `billing-svc@<project>.iam.gserviceaccount.com`
- `clinical-svc@<project>.iam.gserviceaccount.com`

Inbound IAM is restrictive — production billing-svc has NO
`allUsers`; only the SAs of upstream callers
(`ingestion-svc@`, `clinical-svc@`, `stt-worker@`, Cloud Scheduler)
hold `roles/run.invoker`. Browser callers go through Cloud Run's
default unauthenticated route on services that allow it (currently
identity-svc + clinical-svc); billing-svc + ingestion-svc require
identity-svc.ValidateToken via the Connect auth interceptor.

For the new SSO RPC, the identity-svc runtime SA additionally needs
`roles/iam.serviceAccountTokenCreator` on itself so the Admin SDK can
sign custom tokens via the IAM Credentials API without a private-key
JSON.

### 9.5 Hosting security headers

Firebase Hosting defaults: HSTS, HTTPS-only. We don't currently set
custom CSP headers (TODO — Slice 6 polish). The marketing site is
static HTML; XSS surface is limited to whatever next-intl interpolates
into translation strings, which is escape-by-default in React.

### 9.6 Admin operations

- `/admin/*` UI gating on `SUPERWIZOR_ADMIN` (§7.1). Backend
  re-enforcement (every admin RPC calls `requireSuperwizorAdmin`).
- `SUPERWIZOR_ADMIN` is bootstrapped by `psql` (intentionally) —
  there's no admin-UI promotion path, so a compromised admin account
  can't elevate a co-conspirator. See identity-svc agent doc
  §"SUPERWIZOR_ADMIN bootstrap".
- **Every admin mutation writes `audit_events`** with a required
  `reason` field (≥ 10 chars enforced at handler level). The audit
  rows are visible in `/admin/audit` (Slice 4 task #95) with
  actor/action/date filters.

### 9.7 Marketing-site `/admin/*` specifically

- Login form on `/admin` is the inline AdminGuard — uses the same
  `LoginForm` component as `/login`, so the credential entry path is
  audited identically.
- Once signed in, every admin action (`AdminChangePlan`,
  `AdminResetTokens`, `AdminUpdateUser`, `AdminSetOrganizationStatus`)
  requires a >=10-char reason which is propagated into
  `audit_events.reason`. The dialog enforces the length client-side
  and the handler re-checks server-side.

### 9.8 Marketing-site / Flutter cross-origin trust boundary

The custom-token SSO bridges the two origins **intentionally and
narrowly**:

- The bridge is **one-way only** (marketing → Flutter). There is no
  reverse handoff.
- The bridge is **user-initiated** (click on Otwórz kartoteki). There
  is no automatic background redirect.
- A user signed in on `superwizor-app.web.app` cannot use that session
  to act as themselves on `superwizor.web.app`. They have to sign in
  to the marketing origin separately. This is by design.

### 9.9 Data exposure surfaces

- **Pricing page** (`/pricing`): public, reads from clinical-svc.
  `ListModalities` is the one anonymous endpoint and intentionally
  returns no PII.
- **Registration**: collects email + password + therapist's name +
  modality. All goes to identity-svc over TLS. No third-party
  trackers.
- **Account page**: shows the signed-in user their own profile + org +
  subscription. The new `GetSubscription` caller-org guard
  (commit `7e4f2d9`) means a browser user can't even *try* to read
  someone else's subscription — the server rejects the request before
  any DB lookup.
- **Admin pages**: SUPERWIZOR_ADMIN sees everyone, by design. Every
  read is auditable via the request log (Cloud Logging) + every
  mutation writes `audit_events`.

## 10. Operational gotchas

- **Firebase Hosting 1-hour HTML cache** (§4.2) means new marketing
  deploys are visible within an hour, NOT immediately. Hard-refresh in
  the browser to verify. Don't push a cache-busting header — the
  performance trade-off was explicitly chosen.
- **`firebase-frameworks` is NOT used** for the marketing site. Don't
  add SSR / API routes without re-evaluating the 2026-05-28 decision.
  If you do, you have to recreate the `cloudbuild` adapter — which
  was the source of the breakage that drove us to static export.
- **Pnpm cache lies after proto regen**. After `buf generate` updates
  `gen/ts/`, `pnpm install --force` in `marketing-site/` to refresh
  the symlinked `@superwizor/proto-ts` package. Without this, TS
  picks up the stale cached copy and complains the new RPC method
  doesn't exist on the client.
- **Flutter web build needs `dart.library.html`-conditional imports**
  for any code that reaches into DOM APIs. The `sso_handler.dart` +
  `sso_handler_web.dart` split in `lib/auth/` is the canonical
  pattern. Don't import `dart:html` from anything mobile compiles.
- **The `dart:html` deprecation warning is suppressed** at the import
  site in `sso_handler_web.dart` (`// ignore: deprecated_member_use`).
  Migrating to `package:web` + `dart:js_interop` is a Slice-6-polish
  task.
- **Marketing-site `/admin/orgs/[id]` is a single static template per
  locale**, rewritten by Firebase Hosting. The component reads the
  pathname at runtime. Don't try to pre-render per-org pages —
  static export can't.

## 11. Pointers

- **`docs/18_WEB_APP_DESIGN.md`** — original v0.x design with R1-R9
  review rounds. Some sections superseded by this doc; check timestamps
  if conflicting.
- **`docs/19_WEB_SLICE_1_PLAN.md`** — the 8-commit backend foundation
  that made this UI possible. Already DONE on `feat/web-app`.
- **`docs/agents/01_identity-svc.md`** — `MintAppLoginToken` reference,
  Firebase ADC switch, cross-origin SSO handler details.
- **`docs/agents/03_billing-svc.md`** — caller-org guard pattern,
  ConnectErrorInterceptor, browser-direct call pattern.
- **`marketing-site/AGENTS.md`** — reminder that Next.js 16 has
  breaking changes from the model's training data.
- **`PROGRESS.md`** — running log of slices + out-of-slice hotfixes.
  Read this on every session start (per `.claude/CLAUDE.md`).
