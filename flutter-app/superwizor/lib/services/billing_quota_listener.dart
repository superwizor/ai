// Live billing-quota stream from Firestore `organization_quota/{orgId}`.
//
// Reference: docs/16_BILLING_SERVICE_PHASE_3.md §16.3.
//
// Backend (notification-svc + outbox poller) is the only writer. Flutter is
// read-only (per Firestore rules). Stream emits null when the document
// doesn't exist yet (slice 4 will introduce the writer side) — the UI
// gracefully hides quota banners in that case.
//
// Pattern intentionally mirrors SessionStateListener (single doc snapshot
// stream with mapper).

import 'package:cloud_firestore/cloud_firestore.dart';

/// WarningLevel — derived from tokensRemaining. Klient bierze ten sam enum
/// z mirror-a; jeśli backend nie pisał `warningLevel`, derive'ujemy lokalnie
/// z `tokens_used` / `tokens_limit`.
enum QuotaWarningLevel {
  none,      // > Warn threshold remaining
  warning,   // ≤ Warn but > Critical
  critical,  // ≤ Critical but > 0
  exhausted, // 0 remaining
}

/// Domyślne progi — spójne z billing-svc env defaults (§16.1).
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
  final DateTime? updatedAt;
  final String planTier;  // 'SOLO' | 'PRO' | 'CLINIC' | ''
  final String planCycle; // 'MONTHLY' | 'SEMI_ANNUAL' | 'ANNUAL' | ''

  const QuotaState({
    required this.organizationId,
    required this.tokensUsed,
    required this.tokensReserved,
    required this.tokensLimit,
    required this.tokensRemaining,
    required this.warningLevel,
    this.periodStart,
    this.periodEnd,
    this.updatedAt,
    this.planTier = '',
    this.planCycle = '',
  });

  /// Lokalny offset rezerwacji — używane przez UI gdy ingestion-svc
  /// CreateAudioUpload zwróciło sukces ale mirror w Firestore jeszcze
  /// się nie zaktualizował (albo nigdy, bo nie przekroczyło edge thresholds).
  ///
  /// Zwraca nowy QuotaState z reserved += delta, remaining -= delta.
  /// Warning level przeliczany zgodnie ze swoim default thresholdem.
  QuotaState applyLocalReservation(int delta) {
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
      updatedAt: updatedAt,
      planTier: planTier,
      planCycle: planCycle,
    );
  }

  static QuotaWarningLevel computeLevel(int remaining, {int warn = _kDefaultWarnRemaining, int critical = _kDefaultCriticalRemaining}) {
    if (remaining <= 0) return QuotaWarningLevel.exhausted;
    if (remaining <= critical) return QuotaWarningLevel.critical;
    if (remaining <= warn) return QuotaWarningLevel.warning;
    return QuotaWarningLevel.none;
  }

  factory QuotaState.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    final used = _toInt(data['tokensUsed']);
    final reserved = _toInt(data['tokensReserved']);
    final limit = _toInt(data['tokensLimit']);
    // Prefer explicit remaining from backend; else compute.
    var remaining = _toIntNullable(data['tokensRemaining']);
    remaining ??= (limit - used - reserved).clamp(0, limit);

    // Prefer explicit warningLevel string; else derive locally.
    QuotaWarningLevel level;
    final lvlStr = (data['warningLevel'] as String?)?.toLowerCase();
    switch (lvlStr) {
      case 'exhausted':
        level = QuotaWarningLevel.exhausted;
        break;
      case 'critical':
        level = QuotaWarningLevel.critical;
        break;
      case 'warning':
        level = QuotaWarningLevel.warning;
        break;
      case 'none':
        level = QuotaWarningLevel.none;
        break;
      default:
        level = computeLevel(remaining);
    }

    return QuotaState(
      organizationId: (data['organizationId'] ?? doc.id).toString(),
      tokensUsed: used,
      tokensReserved: reserved,
      tokensLimit: limit,
      tokensRemaining: remaining,
      warningLevel: level,
      periodStart: (data['periodStart'] as Timestamp?)?.toDate(),
      periodEnd: (data['periodEnd'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      planTier: (data['planTier'] ?? '').toString(),
      planCycle: (data['planCycle'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic v) => v is int ? v : (v as num?)?.toInt() ?? 0;
  static int? _toIntNullable(dynamic v) {
    if (v == null) return null;
    return v is int ? v : (v as num).toInt();
  }
}

class BillingQuotaListener {
  BillingQuotaListener({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Emits QuotaState gdy doc istnieje, lub null gdy doc nie utworzony
  /// (backend Firestore mirror jeszcze nie zbudowany — slice 4).
  Stream<QuotaState?> watchQuota(String organizationId) {
    if (organizationId.isEmpty) {
      return const Stream.empty();
    }
    return _firestore
        .doc('organization_quota/$organizationId')
        .snapshots()
        .map((doc) => doc.exists ? QuotaState.fromFirestore(doc) : null);
  }
}
