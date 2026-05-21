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

/// Returns the Firestore `session_states/{sessionId}` stream as a
/// Stream of raw status strings ("uploaded", "analyzing", "done",
/// "failed", "pending"). The runner uses this to dismiss queued
/// rows once the backend reports terminal analysis status, without
/// having to poll clinical-svc.
///
/// Wired in upload_queue_provider via SessionStateListener.
typedef SessionStatusStream = Stream<String> Function(String sessionId);

/// Invoked when the runner detects that a previously-uploaded row's
/// server-side analysis has finished (status 'done' or 'failed').
/// Production wires this to refresh patient + session repository
/// caches so the kartoteka reflects the new state.
typedef OnAnalysisComplete = Future<void> Function(PendingUpload row);

class UploadQueueRunner {
  UploadQueueRunner({
    required UploadQueue queue,
    required UploadWorker worker,
    Duration? periodicInterval,
    Stream<List<ConnectivityResult>>? connectivityStream,
    Future<bool> Function()? hasNetwork,
    SessionStatusStream? sessionStatusStream,
    OnAnalysisComplete? onAnalysisComplete,
  })  : _queue = queue,
        _worker = worker,
        _periodicInterval = periodicInterval ?? const Duration(seconds: 60),
        _connectivityStream =
            connectivityStream ?? Connectivity().onConnectivityChanged,
        _hasNetwork = hasNetwork ?? _defaultHasNetwork,
        _sessionStatusStream = sessionStatusStream,
        _onAnalysisComplete = onAnalysisComplete;

  final UploadQueue _queue;
  final UploadWorker _worker;
  final Duration _periodicInterval;
  final Stream<List<ConnectivityResult>> _connectivityStream;
  final Future<bool> Function() _hasNetwork;
  final SessionStatusStream? _sessionStatusStream;
  final OnAnalysisComplete? _onAnalysisComplete;

  /// Active per-sessionId Firestore subscriptions for completed rows
  /// awaiting backend analysis. Keyed by localId so we can clean up
  /// when the row is dismissed.
  final Map<String, StreamSubscription<String>> _analysisSubs = {};

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
    // Tear down all Firestore analysis subscriptions so we don't
    // hold doc listeners after the runner is gone.
    for (final sub in _analysisSubs.values) {
      await sub.cancel();
    }
    _analysisSubs.clear();
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
  /// next tick processes it. No-op for non-failed rows. Awaits the
  /// resulting tick so callers (and tests) get deterministic
  /// progress, matching enqueueAndKick's contract.
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
    await _tick();
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
      //
      // For each row, keep advancing through phases in one tick
      // until the row terminates OR the worker schedules a future
      // retry (nextAttemptAt in the future). Without this loop the
      // periodic 60s tick would pace each phase transition — a
      // typical upload would take 4+ minutes to walk from pending
      // through completed even on a fast network. We still emit
      // snapshots between phases so the UI updates in real time.
      final due = _queue.dueNow();
      for (final initial in due) {
        if (!_running) break;
        var current = initial;
        while (_running) {
          final next = await _worker.runOne(current);
          if (identical(next, current)) break; // worker no-op (terminal)
          await _queue.update(next);
          changed = true;
          // Emit a snapshot mid-row so the SessionStatusScreen sees
          // each phase transition (pending → created → uploaded → …)
          // without waiting for the whole pipeline to finish.
          _emitSnapshot();

          if (next.isTerminal) break;
          // Worker scheduled a backoff retry — let a future tick
          // (periodic or connectivity-triggered) pick it up.
          if (next.nextAttemptAt.isAfter(DateTime.now().toUtc())) {
            break;
          }
          current = next;
        }
      }

      // ── Reconcile Firestore analysis subscriptions ──────────
      //
      // For every row whose upload succeeded (phase=completed,
      // sessionId set) the queue keeps it around so the pill on
      // home shows "analiza" while the backend runs STT + reports.
      // We subscribe to Firestore `session_states/{sessionId}`
      // (written by notification-svc on each Pub/Sub event) and
      // dismiss the row when status flips to 'done' / 'failed'.
      //
      // No polling — the runner is push-driven through Firestore.
      _reconcileAnalysisSubscriptions();
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

  /// Brings the `_analysisSubs` map into sync with the current queue
  /// snapshot: open a Firestore subscription for every
  /// phase=completed row that has a sessionId and isn't already
  /// subscribed; cancel subscriptions for rows that no longer exist
  /// or have been moved out of `completed`.
  void _reconcileAnalysisSubscriptions() {
    if (_sessionStatusStream == null) return;
    final all = _queue.all();
    final activeLocalIds = <String>{};
    for (final row in all) {
      if (row.phase != UploadPhase.completed || row.sessionId == null) {
        continue;
      }
      activeLocalIds.add(row.localId);
      if (_analysisSubs.containsKey(row.localId)) continue;
      _subscribeToAnalysis(row);
    }
    // Tear down subs for rows that were removed or rolled back.
    final stale =
        _analysisSubs.keys.where((k) => !activeLocalIds.contains(k)).toList();
    for (final k in stale) {
      unawaited(_analysisSubs.remove(k)?.cancel());
    }
  }

  void _subscribeToAnalysis(PendingUpload row) {
    final sid = row.sessionId;
    final stream = _sessionStatusStream;
    if (sid == null || stream == null) return;

    debugPrint('[upload-runner] subscribing to analysis status '
        'localId=${row.localId} sessionId=$sid');

    final sub = stream(sid).listen(
      (status) async {
        debugPrint('[upload-runner] analysis status localId=${row.localId} '
            'sessionId=$sid status=$status');
        if (status != 'done' && status != 'failed') return;
        // Terminal — refresh the consumer caches then drop the row.
        try {
          await _onAnalysisComplete?.call(row);
        } catch (e) {
          debugPrint('[upload-runner] onAnalysisComplete failed: $e');
        }
        await _queue.removeById(row.localId);
        unawaited(_analysisSubs.remove(row.localId)?.cancel());
        _emitSnapshot();
      },
      onError: (Object e) {
        debugPrint('[upload-runner] analysis stream error for '
            '${row.sessionId}: $e');
      },
    );
    _analysisSubs[row.localId] = sub;
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
