// Package e2e holds end-to-end tests for the SuperWizor backend that run
// against the staging GCP environment.
//
// All test files in this directory are gated by the `e2e` build tag, so
// they're excluded from `go test ./...` and `make test` by design. To run
// the suite:
//
//	cd superwizor-backend/tests
//	go test -tags=e2e -timeout=10m -v ./e2e/... -run TestFullSession_HappyPath
//
// See README.md and docs/agents/09_testing.md for setup (gcloud, ADC,
// FIREBASE_API_KEY auto-detection, audio file conventions).
//
// This file exists in the default (un-tagged) package so that
// `golangci-lint run ./...` from the module root has at least one Go file
// to analyze — without it, the linter errors with "no go files to analyze"
// because every other file in the directory is build-tagged.
package e2e
