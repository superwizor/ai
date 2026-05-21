// Riverpod gateway for the offline upload queue.
//
// Lifecycle binding (same shape as cache_provider):
//   • currentUserProvider resolves to a therapist → open the queue
//     box, build a GrpcUploadIo + UploadWorker + UploadQueueRunner,
//     call start()
//   • currentUserProvider resolves to null → stop the running
//     instance; the underlying Hive box stays on disk so a logged-
//     back-in user can resume their pending uploads
//
// The singleton holder pattern avoids re-creating the runner on
// every provider rebuild (which Riverpod can do when an upstream
// changes), since the runner owns timers + stream subscriptions
// that aren't free to recreate.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/current_user_provider.dart';
import '../providers/grpc_provider.dart';
import '../providers/services_provider.dart';
import '../repositories/patient_repository.dart';
import '../repositories/session_repository.dart';
import 'pending_upload.dart';
import 'upload_io_grpc.dart';
import 'upload_queue.dart';
import 'upload_queue_runner.dart';
import 'upload_worker.dart';

class _RunnerHolder {
  UploadQueueRunner? runner;
  UploadQueue? queue;
  String? therapistId;
}

final _holder = _RunnerHolder();

/// Resolves to the queue runner bound to the current therapist.
/// Returns null when there is no authenticated user.
final uploadQueueRunnerProvider =
    FutureProvider<UploadQueueRunner?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);

  // Logged out — tear down any running instance.
  if (user == null) {
    final old = _holder.runner;
    _holder.runner = null;
    final oldQueue = _holder.queue;
    _holder.queue = null;
    _holder.therapistId = null;
    if (old != null) {
      await old.dispose();
    }
    if (oldQueue != null) {
      await oldQueue.close();
    }
    return null;
  }

  // Same therapist as before — return the existing runner.
  if (_holder.therapistId == user.id && _holder.runner != null) {
    return _holder.runner;
  }

  // Therapist switch (or first boot) — replace the runner.
  if (_holder.runner != null) {
    await _holder.runner!.dispose();
  }
  if (_holder.queue != null) {
    await _holder.queue!.close();
  }

  final queue = await UploadQueue.openForUser(user.id);
  final ingestion = ref.watch(grpcClientsProvider).ingestion;
  final secureStorage = ref.watch(secureAudioStorageProvider);
  final sessionStateListener = ref.watch(sessionStateListenerProvider);
  final io = GrpcUploadIo(
    ingestion: ingestion,
    secureStorage: secureStorage,
  );
  final worker = UploadWorker(io: io);
  final runner = UploadQueueRunner(
    queue: queue,
    worker: worker,
    // Push-driven status: the runner subscribes to Firestore
    // `session_states/{sessionId}` (notification-svc mirrors
    // Pub/Sub events here per docs/08_FAZA_3_NOTIFICATIONS.md).
    // No polling — when the worker writes status=done/failed
    // the runner's listener fires and dismisses the row.
    sessionStatusStream: (sessionId) => sessionStateListener
        .watchSession(sessionId)
        .map((s) => s.status),
    // When analysis terminates, refresh the patient + session
    // caches so the kartoteka reflects the new session.status.
    // The session-list cache had stored the pre-analysis
    // "PROCESSING" value at upload-time; without this refresh the
    // kartoteka would keep showing "W trakcie analizy" for hours.
    onAnalysisComplete: (row) async {
      try {
        final patientRepo =
            await ref.read(patientRepositoryProvider.future);
        await patientRepo?.refresh();
      } catch (_) {}
      try {
        final sessionRepo =
            await ref.read(sessionRepositoryProvider.future);
        await sessionRepo?.refresh(row.patientFileId);
      } catch (_) {}
    },
  );

  _holder.queue = queue;
  _holder.runner = runner;
  _holder.therapistId = user.id;

  await runner.start();
  return runner;
});

/// Live stream of pending-upload rows for the current therapist.
/// UI providers / widgets watch this to rebuild on every queue
/// change (enqueue, phase transition, retry, dismiss).
final pendingUploadsStreamProvider =
    StreamProvider<List<PendingUpload>>((ref) async* {
  final runner = await ref.watch(uploadQueueRunnerProvider.future);
  if (runner == null) {
    yield const [];
    return;
  }

  // Emit current snapshot synchronously first so widgets get a
  // value on first frame without waiting for the broadcast stream
  // to push something.
  yield runner.snapshotNow();
  yield* runner.snapshots;
});

/// Convenience: just the count of non-terminal pending uploads.
/// Used by the home-screen pill.
final pendingUploadCountProvider = Provider<int>((ref) {
  final async = ref.watch(pendingUploadsStreamProvider);
  return async.maybeWhen(
    data: (list) =>
        list.where((u) => u.phase != UploadPhase.completed).length,
    orElse: () => 0,
  );
});

/// AppLifecycleObserver that nudges the queue when the app returns
/// to the foreground. Install once at the root in main.dart via
/// WidgetsBinding.instance.addObserver(UploadQueueLifecycleObserver()).
class UploadQueueLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final runner = _holder.runner;
      if (runner != null) {
        debugPrint('[upload-runner] app resumed — kicking queue');
        runner.kick();
      }
    }
  }
}
