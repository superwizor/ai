# 12. Deferred — web file upload (browser "Wgraj plik z dysku")

**Status:** Frontend done, backend NOT done → **web file upload is non-functional and deferred.** The native iOS/Android app is unaffected.
**Owner:** whoever picks up web file upload next.

---

## What works / what doesn't

- **Native app (iOS/Android):** file upload works — picks a file, stages it to disk (`dart:io`), enqueues into the durable Hive upload queue, uploads via native gRPC. Unchanged.
- **Web (`superwizor-app.web.app`):** file upload **does not work**. Original symptom: picking a file threw `MissingPluginException(getApplicationDocumentsDirectory ... path_provider)` (mislabeled "Błąd mikrofonu") — the native `dart:io`/path_provider staging can't run in a browser.

## Frontend — DONE (commit `bfa2af2`)

`flutter-app/superwizor/lib/screens/new_session_screen.dart::_pickAndUploadFileWeb()`
(kIsWeb-gated; native path untouched):
1. `FilePicker.pickFiles(withData: true)` → reads bytes into memory (web has no path).
2. `ingestion.createAudioUpload(...)` → signed URL + sessionId.
3. `http.put(signedUrl, headers: {Content-Type, ...requiredHeaders}, body: bytes)` — echoes the server's `requiredHeaders` so the **signed** `x-goog-meta-source` matches (else 403; see `ingestion-svc/.../storage/signer.go`).
4. Navigate to `SessionStatusScreen(sessionId:)` — server-driven listeners (work on web).

This code is correct but **inert** until the backend below lands.

## Backend — NOT DONE (the blockers)

### 1. ingestion-svc is raw gRPC — browsers can't call it
`services/ingestion-svc/cmd/server/main.go` serves `net.Listen` + `grpc.NewServer()` + `gs.Serve(lis)` — **no HTTP/Connect handler, no interceptors**. Browsers can't speak raw gRPC (HTTP/2 trailers). clinical/identity/billing are reachable because they're **Connect** services.

**Fix (mechanical — mirror clinical-svc):** the Connect handler is already generated (`gen/go/ingestion/v1/ingestionv1connect`). Convert ingestion's serving layer to a mixed gRPC+Connect h2c `http.Server` exactly like `services/clinical-svc/cmd/server/main.go` (see its `httpMux` / `NewClinicalServiceHandler` / `mixedHandler` / `SetUnencryptedHTTP2(true)` / `corsMW(mixedHandler)` block, ~lines 277–333). Native gRPC keeps working through the same mixed handler.

### 2. ingestion-svc has no CORS
Add `cors.New(cors.FromEnv(corsOrigins))` with the same default origin list the other services use (must include `https://superwizor-app.web.app` — see `docs/agents/11`). Wrap the mixed handler.

### 3. GCS bucket CORS missing the web origin
`gs://superwizor-ai-25ecd-audio-uploads` CORS allows `superwizor.ai, app.superwizor.ai, localhost:3000, localhost:8080` — **add `https://superwizor-app.web.app`** (method PUT/OPTIONS), or the browser PUT to the signed URL 403s on preflight. Update both the live bucket and the Terraform GCS module (avoid drift — see `docs/agents/11`).

### 4. Auth note
ingestion's gRPC server currently wires **no** auth interceptor (CreateAudioUpload trusts the request's therapistId; Cloud Run is `allUsers`). For parity the Connect handler can skip auth too — but consider adding `ConnectAuthInterceptor` (like billing-svc) to validate the Firebase token while you're in there. Pre-existing gap, flag separately.

## To finish + verify
1. ingestion-svc: items 1+2 (Connect + CORS), `go build/vet/test`.
2. GCS bucket CORS: item 3 (live + TF).
3. Cloud Build + deploy ingestion-svc.
4. Deploy the Flutter web build (frontend already on `main`).
5. **Browser e2e**: from `superwizor-app.web.app`, pick an audio file → confirm CreateAudioUpload (gRPC-web 200), the GCS PUT (200/204), and the session reaching COMPLETED. Watch the Network tab for CORS/preflight failures on both ingestion-svc and `storage.googleapis.com`.

## Interim option (not taken)
Could instead show a "use the mobile app to upload" message on web (gate the button by `kIsWeb`) so it's not a broken affordance. Deferred per product decision — revisit if the broken button is a problem before the backend lands.
