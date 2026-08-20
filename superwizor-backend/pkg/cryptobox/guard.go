package cryptobox

import "errors"

// ErrMockNotAllowed is returned by GuardMock when KMS is unconfigured and the
// explicit dev opt-in is absent.
var ErrMockNotAllowed = errors.New(
	"KMS_KEY_URI required: refusing to persist PHI with placeholder crypto " +
		"(set ALLOW_MOCK_CRYPTO=1 for local dev / tests only)")

// GuardMock enforces the fail-closed crypto-selection policy for services that
// persist special-category health data (transcripts, clinical notes).
//
// Background: each service did `if KMS_KEY_URI != "" { CloudKMS } else { Mock }`,
// and MockBox.Encrypt returns "ENCRYPT_PLACEHOLDER:"+plaintext — i.e. cleartext.
// A production deploy that shipped with KMS_KEY_URI accidentally unset would
// silently store PHI unencrypted with no startup failure
// (SECURITY_REMEDIATION_PLAN.md #6).
//
// Policy:
//   - kmsKeyURI set            -> nil (caller builds the real CloudKMS box).
//   - kmsKeyURI empty, allowMock -> nil (caller may use MockBox; dev/tests).
//   - kmsKeyURI empty, !allowMock -> ErrMockNotAllowed (caller must exit).
//
// allowMock should come from an explicit env opt-in (ALLOW_MOCK_CRYPTO=1), never
// from the mere absence of KMS_KEY_URI.
func GuardMock(kmsKeyURI string, allowMock bool) error {
	if kmsKeyURI == "" && !allowMock {
		return ErrMockNotAllowed
	}
	return nil
}
