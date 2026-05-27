// BillingQuotaCache — single source of truth for the therapist's
// quota / subscription state inside the Flutter app.
//
// Phase B refactor (feat/billing-svc-refactor): we no longer subscribe
// to a Firestore mirror. Instead the cache is hydrated on cold start
// from clinical-svc.GetMyBillingState (which proxies billing-svc.
// GetSubscription) and refreshed after every successful upload.
//
// The cache is a thin wrapper around a ValueNotifier so Riverpod can
// expose it via a Provider without our own pub/sub plumbing.

import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart';

import '../generated/billing/v1/billing.pb.dart' as billing_pb;
import '../generated/clinical/v1/clinical.pbgrpc.dart';
import 'billing_quota_state.dart';

class BillingQuotaCache {
  BillingQuotaCache({required ClinicalServiceClient clinicalClient})
      : _clinical = clinicalClient,
        _state = ValueNotifier<QuotaState?>(null);

  final ClinicalServiceClient _clinical;
  final ValueNotifier<QuotaState?> _state;

  ValueListenable<QuotaState?> get listenable => _state;
  QuotaState? get current => _state.value;

  /// Fetches the canonical quota snapshot from clinical-svc and
  /// replaces the cached value. Called once on app cold start and
  /// after every successful CreateAudioUpload (so the new reservation
  /// shows up authoritatively, with the server's view).
  ///
  /// Returns the new state on success. On failure (network / billing
  /// not wired) preserves the previous cache value and returns null —
  /// caller decides how loud to be about it.
  Future<QuotaState?> refresh() async {
    try {
      final sub = await _clinical.getMyBillingState(Empty());
      final next = _fromProto(sub);
      _state.value = next;
      return next;
    } on GrpcError catch (e, st) {
      debugPrint('BillingQuotaCache.refresh GrpcError: $e\n$st');
      return null;
    } catch (e, st) {
      debugPrint('BillingQuotaCache.refresh failed: $e\n$st');
      return null;
    }
  }

  /// Optimistic local update — applies a reserved-tokens delta to the
  /// cached value without an RPC. Used in the tiny gap between
  /// CreateAudioUpload returning OK and refresh() landing the
  /// authoritative snapshot. delta is +1 for a brand-new reservation.
  ///
  /// No-op when the cache hasn't been hydrated yet (cold start before
  /// the first refresh) — we'd be guessing the limit otherwise.
  void applyOptimisticReservation(int delta) {
    final cur = _state.value;
    if (cur == null) return;
    _state.value = cur.withDeltaReserved(delta);
  }

  static QuotaState _fromProto(billing_pb.Subscription sub) {
    return QuotaState(
      organizationId: '', // billing-svc proto doesn't return org_id on the
                          // Subscription message and we don't need it
                          // client-side — kept empty for forward compat
                          // with any caller that still reads it.
      tokensUsed: sub.tokensUsedThisPeriod,
      tokensReserved: sub.tokensReservedThisPeriod,
      tokensLimit: sub.tokensPerPeriod,
      tokensRemaining: sub.tokensRemaining,
      warningLevel: QuotaState.computeLevel(sub.tokensRemaining),
      periodStart: sub.hasCurrentPeriodStart()
          ? sub.currentPeriodStart.toDateTime()
          : null,
      periodEnd: sub.hasCurrentPeriodEnd()
          ? sub.currentPeriodEnd.toDateTime()
          : null,
      planTier: sub.planTier,
      planCycle: sub.planCycle,
    );
  }
}
