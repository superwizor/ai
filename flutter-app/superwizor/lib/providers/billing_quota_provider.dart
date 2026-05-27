// billingQuotaProvider — exposes the cached billing/quota snapshot.
//
// Phase B refactor (feat/billing-svc-refactor): replaces the previous
// Firestore-stream-based provider. The single source of truth is now
// BillingQuotaCache, which is hydrated on app cold start by calling
// clinical-svc.GetMyBillingState (proxy to billing-svc.GetSubscription)
// and refreshed after each successful upload.
//
// Per user direction we do NOT refresh on app resume — minimise DB
// hits. Cold start is the only automatic refresh; refresh() is also
// called explicitly from upload_queue_provider when a reservation
// commits.
//
// Reference: docs/16 §16, docs/17 §5 (rewritten in phase D).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/billing_quota_cache.dart';
import '../services/billing_quota_state.dart';
import 'current_user_provider.dart';
import 'grpc_provider.dart';

/// Singleton cache, owned by Riverpod. Disposed when the auth scope
/// rebuilds (e.g. on sign-out → sign-in).
final billingQuotaCacheProvider = Provider<BillingQuotaCache>((ref) {
  final clinical = ref.watch(grpcClientsProvider).clinical;
  return BillingQuotaCache(clinicalClient: clinical);
});

/// Notifier surface — emits `QuotaState?` so existing consumers
/// (QuotaWarningBanner etc.) keep their API unchanged.
class BillingQuotaNotifier extends AsyncNotifier<QuotaState?> {
  late final BillingQuotaCache _cache;
  VoidCallback? _listener;

  @override
  Future<QuotaState?> build() async {
    _cache = ref.read(billingQuotaCacheProvider);

    final user = await ref.watch(currentUserProvider.future);
    if (user == null) {
      return null;
    }

    // Listen to the cache so subsequent refresh() / applyOptimistic
    // calls propagate through the AsyncNotifier without us needing
    // to manually set state from every caller.
    _listener = () {
      state = AsyncData(_cache.current);
    };
    _cache.listenable.addListener(_listener!);
    ref.onDispose(() {
      if (_listener != null) {
        _cache.listenable.removeListener(_listener!);
      }
    });

    // Initial hydration — one RPC. If it fails the cache stays null
    // and the UI hides quota chrome (same behaviour as the old
    // empty-Firestore-doc case).
    return await _cache.refresh();
  }

  /// Public hook for upload-success path: optimistically apply a
  /// reserved-tokens delta to the cache, then trigger a refresh so
  /// the authoritative server snapshot lands.
  Future<void> onReservationCreated() async {
    _cache.applyOptimisticReservation(1);
    await _cache.refresh();
  }
}

final billingQuotaProvider =
    AsyncNotifierProvider<BillingQuotaNotifier, QuotaState?>(BillingQuotaNotifier.new);
