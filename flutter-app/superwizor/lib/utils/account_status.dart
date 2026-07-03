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
