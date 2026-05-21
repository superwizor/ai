// UploadQueueRunner — orchestrates the upload queue lifecycle.
//
// Owns:
//   • The 60-second periodic tick that scans for due rows
//   • The connectivity_plus listener that wakes the queue when Wi-Fi
//     or cellular comes back
//   • A broadcast stream of `List<PendingUpload>` snapshots so the
//     Riverpod layer can rebuild UI on every queue change
//   • Concurrency guard — only one tick runs at a time
//
// Doesn't own:
//   • The actual gRPC / HTTP / encryption code — that lives in
//     UploadIo
//   • Hive — that's UploadQueue's job; runner just calls its API
//
// Lifecycle:
//   start() → subscribe to connectivity, start periodic timer,
//             kick an immediate tick
//   stop()  → unsubscribe, cancel timer; safe to call multiple times
//   kick()  → public manual nudge (e.g. after a fresh enqueue from
//             new_session_screen)
//
// The runner is created per-therapist by upload_queue_provider; on
// therapist switch the old runner is stopped and a new one started.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'pending_upload.dart';
import 'upload_queue.dart';
import 'upload_worker.dart';

class UploadQueueRunner {
  UploadQueueRunner({
    required UploadQueue queue,
    required UploadWorker worker,
    Duration? periodicInterval,
    Stream<List<ConnectivityResult>>? connectivityStream,
    Future<bool> Function()? hasNetwork,
  })  : _queue = queue,
        _worker = worker,
        _periodicInterval = periodicInterval ?? const Duration(seconds: 60),
        _connectivityStream =
            connectivityStream ?? Connectivity().onConnectivityChanged,
        _hasNetwork = hasNetwork ?? _defaultHasNetwork;

  final UploadQueue _queue;
  final UploadWorker _worker;
  final Duration _periodicInterval;
  final Stream<List<ConnectivityResult>> _connectivityStream;
  final Future<bool> Function() _hasNetwork;

  final _snapshotsCtrl =
      StreamController<List<PendingUpload>>.broadcast();
  Timer? _periodicTimer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _running = false;
  bool _tickInFlight = false;
  /// Public test/visibility hook — counter increments every time
  /// _tick completes (success or no-op).
  int ticksCompleted = 0;

  /// Stream of queue snapshots. Emits the current `all()` list on:
  ///   • start()
  ///   • every enqueue / state-mutation via this runner
  ///   • every tick that changed something
  ///
  /// UI providers should bind to this rather than polling.
  Stream<List<PendingUpload>> get snapshots => _snapshotsCtrl.stream;

  /// Current snapshot synchronously (for initial UI paint).
  List<PendingUpload> snapshotNow() => _queue.all();

  // ── Lifecycle ─────────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;
    _running = true;

    _connSub = _connectivityStream.listen(_onConnectivityChanged,
        onError: (Object e) =>
            debugPrint('[upload-runner] connectivity stream error: $e'));
    _periodicTimer = Timer.periodic(_periodicInterval, (_) => _tick());

    _emitSnapshot();
    // Initial tick: drain anything that's already due (e.g. queued
    // before this runner existed because we just resumed from
    // backgrounded state). Awaited so callers can trust that by the
    // time start() returns, any pre-existing queue items have had
    // at least one phase advanced (or been deferred for offline).
    await _tick();
  }

  Future<void> stop() async {
    _running = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    await _connSub?.cancel();
    _connSub = null;
  }

  Future<void> dispose() async {
    await stop();
    await _snapshotsCtrl.close();
  }

  // ── Public mutation surface ───────────────────────────────────

  /// Adds [upload] to the queue and runs one tick synchronously
  /// before returning. Callers get deterministic behavior — by the
  /// time the future completes, the runner has either started the
  /// upload or determined we're offline and parked it. UI can
  /// immediately watch [snapshots] to track progress.
  Future<void> enqueueAndKick(PendingUpload upload) async {
    await _queue.enqueue(upload);
    _emitSnapshot();
    await _tick();
  }

  /// Manual nudge — exposed for the lifecycle hook
  /// (AppLifecycleState.resumed) in the Riverpod gateway, and used
  /// by tests to advance one phase at a time.
  Future<void> kick() => _tick();

  /// User-driven cancel/dismiss — removes a row from the queue
  /// regardless of phase. For a non-terminal row this stops further
  /// retries; for a terminal row it's just cleanup.
  Future<void> dismiss(String localId) async {
    await _queue.removeById(localId);
    _emitSnapshot();
  }

  /// User-driven retry — flips a failed row back to pending so the
  /// next tick processes it. No-op for non-failed rows.
  Future<void> retryFailed(String localId) async {
    final u = _queue.getById(localId);
    if (u == null || u.phase != UploadPhase.failed) return;
    await _queue.update(u.copyWith(
      phase: UploadPhase.pending,
      attemptCount: 0,
      nextAttemptAt: DateTime.now().toUtc(),
      clearLastError: true,
      terminatedAt: null,
    ));
    _emitSnapshot();
    unawaited(_tick());
  }

  // ── Tick ──────────────────────────────────────────────────────

  Future<void> _tick() async {
    if (!_running || _tickInFlight) return;
    _tickInFlight = true;
    var changed = false;
    try {
      // Cheap age sweep — keeps the queue honest.
      final swept = await _queue.pruneStale();
      if (swept > 0) changed = true;

      // Don't even try the network if we know we're offline; saves a
      // burst of doomed gRPC attempts. The classifier would handle
      // them as retryable anyway, but skipping is cheaper.
      if (!await _hasNetwork()) {
        if (changed) _emitSnapshot();
        return;
      }

      // Process each due row in order. We process serially rather
      // than in parallel so a slow upload doesn't starve CPU /
      // bandwidth, and so progress UI for one upload is meaningful.
      final due = _queue.dueNow();
      for (final u in due) {
        if (!_running) break;
        final next = await _worker.runOne(u);
        if (!identical(next, u)) {
          await _queue.update(next);
          changed = true;
        }
      }
    } catch (e, st) {
      debugPrint('[upload-runner] tick crashed: $e\n$st');
    } finally {
      _tickInFlight = false;
      ticksCompleted++;
      if (changed) _emitSnapshot();
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online) {
      unawaited(_tick());
    }
  }

  void _emitSnapshot() {
    if (_snapshotsCtrl.isClosed) return;
    _snapshotsCtrl.add(_queue.all());
  }
}

// connectivity_plus's onConnectivityChanged doesn't report whether
// the network actually works (DNS / captive portals can lie). We
// keep _hasNetwork pluggable so tests can stub it; production just
// inspects the most recent ConnectivityResult.
Future<bool> _defaultHasNetwork() async {
  final results = await Connectivity().checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
}
