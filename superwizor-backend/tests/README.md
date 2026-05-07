# tests

Cross-cutting end-to-end tests for SuperWizor AI services. Lives as its own Go module (in `go.work`) because individual service modules don't sensibly own tests that span multiple services.

## Run E2E

```bash
# One-time setup
gcloud auth login                          # for service-URL discovery
gcloud auth application-default login      # for Firebase Admin SDK (token minting)

# From this directory
go test -tags=e2e -timeout=10m -v ./e2e/... -run TestFullSession_HappyPath

# With explicit audio file
AUDIO_FILE=/path/to/sample.m4a \
  go test -tags=e2e -timeout=10m -v ./e2e/... -run TestFullSession_HappyPath
```

E2E tests are gated by the `e2e` build tag, so `make test` and `go test ./...` from elsewhere skip them by design.

## Auth model

Services validate Firebase ID tokens (audience claim must equal the Firebase project ID). `gcloud auth print-identity-token` mints **Google IAM tokens**, which won't pass that check — except on `identity-svc.CreateUser`, which is unauthenticated by design (it's the registration endpoint).

So this test mints a real Firebase ID token by:
1. Creating a Firebase user via Admin SDK (using ADC)
2. Minting a custom token for that UID
3. Exchanging it via `signInWithCustomToken` REST call → Firebase ID token

The test reuses that ID token for **all** gRPC calls (identity, clinical, ingestion). On cleanup, the Firebase user is deleted via Admin SDK regardless of test outcome.

### One-time IAM grant for token minting

The Firebase Admin SDK signs custom tokens by calling the **IAM `signBlob` API** on the Firebase Admin service account (`firebase-adminsdk-fbsvc@<project>`). It only signs in-process when given a service-account JSON key file — ADC users always go via `signBlob`. That requires `roles/iam.serviceAccountTokenCreator` on the Firebase Admin SA.

**Preferred — terraform-managed** (one-time, declarative):

```hcl
# infra/environments/staging/terraform.tfvars (or override file)
e2e_token_minters = [
  "user:you@example.com",
  "serviceAccount:e2e-runner@superwizor-ai-25ecd.iam.gserviceaccount.com",
]
```

```bash
cd infra/environments/staging
terragrunt apply -target='google_service_account_iam_member.e2e_firebase_token_creator'
```

**Quick fix — gcloud one-liner** (skip terraform; works immediately):

```bash
gcloud iam service-accounts add-iam-policy-binding \
  firebase-adminsdk-fbsvc@superwizor-ai-25ecd.iam.gserviceaccount.com \
  --member="user:$(gcloud config get-value account)" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project=superwizor-ai-25ecd
```

Without this, the test fails on the first call to `auth().CustomToken()` with `Permission 'iam.serviceAccounts.signBlob' denied`.

## Environment

| Variable | Default | Purpose |
|---|---|---|
| `GCP_PROJECT_ID` | `superwizor-ai-25ecd` | Project to test against |
| `GCP_REGION` | `europe-central2` | Cloud Run region |
| `IDENTITY_SVC_URL` | (auto-discovered via gcloud) | Override service URL |
| `CLINICAL_SVC_URL` | (auto-discovered via gcloud) | Override service URL |
| `INGESTION_SVC_URL` | (auto-discovered via gcloud) | Override service URL |
| `FIREBASE_API_KEY` | (auto-detected from `flutter-app/.../firebase_options.dart`) | Web API key for the custom-token exchange |
| `FIREBASE_ID_TOKEN` | (skip mint; use this token directly) | Pre-minted ID token — fast path for CI |
| `AUDIO_FILE` | searches `testdata/sample.m4a`, then repo `test-audio.wav` | Audio input |

For CI: pre-mint a token (e.g., via a small helper job) and pass via `FIREBASE_ID_TOKEN` to skip Firebase Admin SDK initialization on every run.

## What's tested

See [`docs/agents/09_testing.md`](../../docs/agents/09_testing.md) Tier 1 + Tier 2 scenarios. The `TestFullSession_HappyPath` test covers:

1. CreateUser (identity)
2. ListModalities (clinical) — cross-service auth check
3. CreatePatientFile + idempotency replay
4. CreateAudioUpload — signed URL grant
5. PUT to GCS via signed URL
6. CompleteAudioUpload — implicitly creates the session
7. Poll GetSessionDetails until terminal status
8. Structural assertions on the completed session:
   - `reports[]` non-empty
   - `speaker_label_mapping` populated, keys parseable as int (gotcha: keys are STRINGs)
   - `transcript.segments` chronologically ordered
   - each segment's `speaker_tag` referenced in mapping

Cleanup: `t.Cleanup` soft-deletes the patient file regardless of test outcome.

## Adding a new E2E test

Files must use the `e2e` build tag:

```go
//go:build e2e
// +build e2e

package e2e_test
```

Use the helpers in `full_session_test.go` (`loadConfig`, `dial`, `authInterceptor`). If the helpers grow, factor them into a separate `helpers_test.go` (same build tag).
