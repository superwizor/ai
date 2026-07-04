// Detection helper for the reversible-deactivation contract (docs/38).
//
// identity-svc's ValidateToken / resolveCaller deny deactivated accounts
// with PermissionDenied whose message starts with "ACCOUNT_DEACTIVATED".
// Downstream services wrap that error (clinical-svc's interceptor
// re-labels it Unauthenticated "invalid token: … ACCOUNT_DEACTIVATED …"),
// so matching the marker substring — not the gRPC code — is the reliable
// client-side check.

bool isAccountDeactivatedError(Object? error) =>
    error != null && error.toString().contains('ACCOUNT_DEACTIVATED');

/// identity-svc CreateUser returns FailedPrecondition "ACCOUNT_DELETED"
/// when the login self-heal tries to re-provision an identity whose
/// users row was removed by a Superwizor admin (soft-deleted legacy
/// rows). Same UX as deactivation: full-screen block, never the raw
/// gRPC dump (live-tested 2026-07-04: users_firebase_uid_key splash).
bool isAccountDeletedError(Object? error) =>
    error != null && error.toString().contains('ACCOUNT_DELETED');

/// Either flavour of "the administrator cut this account off".
bool isAccountBlockedError(Object? error) =>
    isAccountDeactivatedError(error) || isAccountDeletedError(error);
