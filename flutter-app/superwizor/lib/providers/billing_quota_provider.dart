// billingQuotaProvider — live quota state z dwoma źródłami:
//   1) Firestore stream `organization_quota/{orgId}` (push, baseline)
//   2) Lokalny offset rezerwacji (applied po sukces CreateAudioUpload)
//
// Lokalny offset jest reset'owany za każdym razem gdy Firestore emit nowy
// snapshot — wtedy backend juz wie o nowych rezerwacjach i offset zbędny.
//
// Reference: docs/16_BILLING_SERVICE_PHASE_3.md §16.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/billing_quota_listener.dart';
import 'current_user_provider.dart';

/// Singleton listener.
final billingQuotaListenerProvider = Provider<BillingQuotaListener>(
  (ref) => BillingQuotaListener(),
);

/// Notifier — utrzymuje aktualny QuotaState z applied local offset.
class BillingQuotaNotifier extends AsyncNotifier<QuotaState?> {
  StreamSubscription<QuotaState?>? _sub;
  int _localReservationOffset = 0;
  QuotaState? _serverState;

  @override
  Future<QuotaState?> build() async {
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });

    final user = await ref.watch(currentUserProvider.future);
    if (user == null || user.organizationId.isEmpty) {
      return null;
    }
    final listener = ref.read(billingQuotaListenerProvider);

    final completer = Completer<QuotaState?>();
    _sub?.cancel();
    _sub = listener.watchQuota(user.organizationId).listen((qs) {
      _serverState = qs;
      // Server confirmed a snapshot — reset local offset (backend's view
      // is authoritative once we receive a write).
      _localReservationOffset = 0;
      state = AsyncData(_apply());
      if (!completer.isCompleted) completer.complete(_apply());
    }, onError: (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    });
    return completer.future;
  }

  /// Wywołane przez UI tuż po sukces CreateAudioUpload — dekrementuje
  /// pozostałe tokeny lokalnie, dopóki backend nie zaktualizuje mirror.
  void applyLocalReservation(int delta) {
    _localReservationOffset += delta;
    state = AsyncData(_apply());
  }

  QuotaState? _apply() {
    if (_serverState == null) return null;
    if (_localReservationOffset == 0) return _serverState;
    return _serverState!.applyLocalReservation(_localReservationOffset);
  }
}

final billingQuotaProvider =
    AsyncNotifierProvider<BillingQuotaNotifier, QuotaState?>(BillingQuotaNotifier.new);
