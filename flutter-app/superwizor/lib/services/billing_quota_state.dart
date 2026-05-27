// Billing-quota domain model — pure data, no transport.
//
// Phase B refactor (feat/billing-svc-refactor): this file replaces the
// previous billing_quota_listener.dart by stripping the Firestore-
// snapshot constructor. The cache is now hydrated from
// clinical-svc.GetMyBillingState (which proxies billing-svc.GetSubscription)
// — see billing_quota_cache.dart.

/// WarningLevel — derived from tokensRemaining vs. the global thresholds
/// below. Backend used to publish this via Firestore mirror; we now
/// compute it client-side from the snapshot.
enum QuotaWarningLevel {
  none,      // > warn threshold remaining
  warning,   // ≤ warn but > critical
  critical,  // ≤ critical but > 0
  exhausted, // 0 remaining
}

/// Defaults match billing-svc env defaults (docs/17 §0).
const int _kDefaultWarnRemaining = 5;
const int _kDefaultCriticalRemaining = 1;

class QuotaState {
  final String organizationId;
  final int tokensUsed;
  final int tokensReserved;
  final int tokensLimit;
  final int tokensRemaining;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final QuotaWarningLevel warningLevel;
  final String planTier;  // 'SOLO' | 'PRO' | 'CLINIC' | 'TRIAL' | ''
  final String planCycle; // 'MONTHLY' | 'ANNUAL' | ''

  const QuotaState({
    required this.organizationId,
    required this.tokensUsed,
    required this.tokensReserved,
    required this.tokensLimit,
    required this.tokensRemaining,
    required this.warningLevel,
    this.periodStart,
    this.periodEnd,
    this.planTier = '',
    this.planCycle = '',
  });

  /// Locally-recomputed copy with a different reservation count. Used by
  /// the cache after a successful CreateAudioUpload to optimistically
  /// reflect the new reservation immediately, before the follow-up
  /// GetMyBillingState refresh comes back. delta is normally +1 (one
  /// session reserved).
  QuotaState withDeltaReserved(int delta) {
    final newReserved = (tokensReserved + delta).clamp(0, tokensLimit);
    final newRemaining = (tokensLimit - tokensUsed - newReserved).clamp(0, tokensLimit);
    return QuotaState(
      organizationId: organizationId,
      tokensUsed: tokensUsed,
      tokensReserved: newReserved,
      tokensLimit: tokensLimit,
      tokensRemaining: newRemaining,
      warningLevel: computeLevel(newRemaining),
      periodStart: periodStart,
      periodEnd: periodEnd,
      planTier: planTier,
      planCycle: planCycle,
    );
  }

  static QuotaWarningLevel computeLevel(
    int remaining, {
    int warn = _kDefaultWarnRemaining,
    int critical = _kDefaultCriticalRemaining,
  }) {
    if (remaining <= 0) return QuotaWarningLevel.exhausted;
    if (remaining <= critical) return QuotaWarningLevel.critical;
    if (remaining <= warn) return QuotaWarningLevel.warning;
    return QuotaWarningLevel.none;
  }
}
