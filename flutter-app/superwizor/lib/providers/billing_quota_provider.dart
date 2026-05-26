// billingQuotaProvider — live quota state for the current therapist's org.
//
// Resolves organizationId from currentUserProvider, then opens a Firestore
// stream on organization_quota/{orgId}. The stream emits null while:
//   - User is not yet logged in
//   - currentUserProvider is still resolving
//   - Backend Firestore mirror hasn't written the doc yet (slice 4 work)
//
// Reference: docs/16_BILLING_SERVICE_PHASE_3.md §16.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/billing_quota_listener.dart';
import 'current_user_provider.dart';

/// Singleton listener. Cheaply held (just a FirebaseFirestore reference).
final billingQuotaListenerProvider = Provider<BillingQuotaListener>(
  (ref) => BillingQuotaListener(),
);

/// Live quota stream. Null state == "no info yet" → UI hides banners
/// (graceful degradation while Firestore mirror is bootstrapping).
final billingQuotaProvider = StreamProvider<QuotaState?>((ref) async* {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null || user.organizationId.isEmpty) {
    yield null;
    return;
  }
  final listener = ref.watch(billingQuotaListenerProvider);
  yield* listener.watchQuota(user.organizationId);
});
