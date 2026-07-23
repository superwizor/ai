// Once-per-launch orphaned-recording scan (docs/28 WS1).
//
// Resolves to the list of recoverable recordings for the signed-in
// therapist, after running the retention sweep. HomeScreen reads this
// post-frame and walks the user through a recovery sheet per orphan.
//
// The module-level `_ranThisLaunch` guard (same singleton-holder idiom
// as upload_queue_provider.dart) makes the scan a cold-launch event, not
// a rebuild event: provider invalidation, therapist re-auth, or widget
// remounts must not re-prompt the user mid-session.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/recording_recovery_service.dart';
import '../uploads/upload_queue_provider.dart';
import 'current_user_provider.dart';
import 'services_provider.dart';

bool _ranThisLaunch = false;

/// Test-only: reset the once-per-launch latch.
void debugResetRecoveryScanLatch() {
  _ranThisLaunch = false;
}

final recordingRecoveryServiceProvider =
    FutureProvider<RecordingRecoveryService?>((ref) async {
  final runner = await ref.watch(uploadQueueRunnerProvider.future);
  if (runner == null) return null; // signed out
  return RecordingRecoveryService(
    store: ref.watch(recordingManifestStoreProvider),
    runner: runner,
    recordingService: ref.watch(recordingServiceProvider),
  );
});

/// Orphans found on this launch's scan; empty after the first read or
/// when there is nothing to recover.
final orphanedRecordingsProvider =
    FutureProvider<List<RecoverableRecording>>((ref) async {
  if (_ranThisLaunch) return const [];
  final therapistId = await ref.watch(backendUserIdProvider.future);
  if (therapistId == null) return const [];
  final svc = await ref.watch(recordingRecoveryServiceProvider.future);
  if (svc == null) return const [];
  _ranThisLaunch = true;
  await svc.sweep();
  return svc.findOrphans(therapistId);
});
