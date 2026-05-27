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

import '../providers/billing_quota_provider.dart';
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
    // Fires when CompleteAudioUpload returns — the server has the
    // new session row in PROCESSING state but the kartoteka cache
    // still holds the pre-upload session list. Refresh so the
    // session appears immediately (with PROCESSING status), not
    // only after analysis terminates.
    onUploadComplete: (row) async {
      await _refreshKartoteka(ref, row.patientFileId);
    },
    // Second refresh when analysis terminates — picks up the
    // PROCESSING → COMPLETED/FAILED status flip server-side.
    onAnalysisComplete: (row) async {
      await _refreshKartoteka(ref, row.patientFileId);
    },
    // CreateAudioUpload success → backend just took 1 token via
    // ReserveCredit. Apply an optimistic local decrement, then refresh
    // the cache from clinical-svc.GetMyBillingState so the authoritative
    // server snapshot lands. Phase B refactor (feat/billing-svc-refactor)
    // replaced the previous Firestore-mirror push with this pull model.
    onReservationCreated: (_) {
      // Fire-and-forget — the notifier's listener updates state via
      // its cache listener, so we don't need to await here.
      ref.read(billingQuotaProvider.notifier).onReservationCreated().catchError((e) {
        debugPrint('[upload-runner] onReservationCreated failed: $e');
      });
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

/// Per-patient view onto the upload queue: the active (non-terminal,
/// non-completed, non-failed) rows whose patientFileId matches.
///
/// Why this exists: the patient sessions view (`ClientDetailsScreen`)
/// reads the server-side session list from `sessionsProvider`. For
/// long-audio "Wgraj Plik z Dysku" uploads, the server's
/// `CompleteAudioUpload` blocks on ffmpeg chunking for several minutes
/// before it INSERTs the sessions row, so the user navigates back to
/// the patient view and sees NOTHING until the RPC finally returns.
/// This provider gives the screen a stream of in-flight uploads for
/// that patient so we can render placeholder cards while the
/// background work runs — concrete user-visible signal that "the
/// session is being processed" instead of an empty list.
///
/// The placeholder lifecycle:
///   queued (pending/created/uploaded/converted) → visible here
///   completed                                   → drops from this list;
///                                                 sessionsProvider gets
///                                                 a refresh push and
///                                                 the real session
///                                                 replaces the
///                                                 placeholder
///   failed                                      → drops from here too;
///                                                 the upload-list /
///                                                 home-screen pill UIs
///                                                 surface the error
final pendingUploadsForPatientProvider =
    Provider.family<List<PendingUpload>, String>((ref, patientFileId) {
  final async = ref.watch(pendingUploadsStreamProvider);
  return async.maybeWhen(
    data: (list) => list
        .where((u) =>
            u.patientFileId == patientFileId &&
            u.phase != UploadPhase.completed &&
            u.phase != UploadPhase.failed)
        .toList(growable: false),
    orElse: () => const [],
  );
});

/// Refreshes both repositories' caches for [patientFileId]. Used by
/// the upload-runner callbacks (onUploadComplete + onAnalysisComplete)
/// to keep the kartoteka in sync with server state without polling.
Future<void> _refreshKartoteka(Ref ref, String patientFileId) async {
  try {
    final patientRepo = await ref.read(patientRepositoryProvider.future);
    await patientRepo?.refresh();
  } catch (e) {
    debugPrint('[upload-runner] patient refresh failed: $e');
  }
  try {
    final sessionRepo = await ref.read(sessionRepositoryProvider.future);
    await sessionRepo?.refresh(patientFileId);
  } catch (e) {
    debugPrint('[upload-runner] session refresh failed: $e');
  }
}

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
