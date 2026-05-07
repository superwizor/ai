# tests

Cross-cutting end-to-end tests for SuperWizor AI services. Lives as its own Go module (in `go.work`) because individual service modules don't sensibly own tests that span multiple services.

## Run E2E

```bash
# from this directory
go test -tags=e2e -timeout=10m -v ./e2e/... -run TestFullSession_HappyPath

# with explicit audio file
AUDIO_FILE=/path/to/sample.m4a \
  go test -tags=e2e -timeout=10m -v ./e2e/... -run TestFullSession_HappyPath
```

E2E tests are gated by the `e2e` build tag, so `make test` and `go test ./...` from elsewhere skip them by design.

## Environment

| Variable | Default | Purpose |
|---|---|---|
| `GCP_PROJECT_ID` | `superwizor-ai-25ecd` | Project to test against |
| `GCP_REGION` | `europe-central2` | Cloud Run region |
| `IDENTITY_SVC_URL` | (auto-discovered) | Override service URL |
| `CLINICAL_SVC_URL` | (auto-discovered) | Override service URL |
| `INGESTION_SVC_URL` | (auto-discovered) | Override service URL |
| `GCP_AUTH_TOKEN` | (auto: `gcloud auth print-identity-token`) | Bearer token |
| `AUDIO_FILE` | searches `testdata/sample.m4a`, repo `test-audio.wav` | Audio input |

When env vars are unset, the test shells out to `gcloud` to discover URLs and mint a token. Faster CI: pre-mint the token and pass via `GCP_AUTH_TOKEN`.

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
