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

import '../utils/debug_flags.dart';

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

/// Invoked the moment a row transitions to phase=completed —
/// CompleteAudioUpload returned, so the server has a session row
/// (in PROCESSING state). Production wires this to refresh
/// patient + session repository caches so the kartoteka actually
/// shows the new session while analysis runs, instead of serving
/// the stale cached session list.
typedef OnUploadComplete = Future<void> Function(PendingUpload row);

/// Invoked when the runner detects that a previously-uploaded row's
/// server-side analysis has finished (status 'done' or 'failed').
/// Production wires this to refresh patient + session repository
/// caches so the kartoteka picks up the new status string.
typedef OnAnalysisComplete = Future<void> Function(PendingUpload row);

/// Fires once per successful CreateAudioUpload (transition pending→created).
/// UI uses this to apply a local decrement on billingQuotaProvider so the
/// SubscriptionPlanScreen shows the reservation immediately without waiting
/// for the Firestore mirror to catch up.
typedef OnReservationCreated = void Function(PendingUpload row);

class UploadQueueRunner {
  UploadQueueRunner({
    required UploadQueue queue,
    required UploadWorker worker,
    Duration? periodicInterval,
    Stream<List<ConnectivityResult>>? connectivityStream,
    Future<bool> Function()? hasNetwork,
    SessionStatusStream? sessionStatusStream,
    OnUploadComplete? onUploadComplete,
    OnAnalysisComplete? onAnalysisComplete,
    OnReservationCreated? onReservationCreated,
  })  : _queue = queue,
        _worker = worker,
        _periodicInterval = periodicInterval ?? const Duration(seconds: 60),
        _connectivityStream =
            connectivityStream ?? Connectivity().onConnectivityChanged,
        _hasNetwork = hasNetwork ?? _defaultHasNetwork,
        _sessionStatusStream = sessionStatusStream,
        _onUploadComplete = onUploadComplete,
        _onAnalysisComplete = onAnalysisComplete,
        _onReservationCreated = onReservationCreated;

  final UploadQueue _queue;
  final UploadWorker _worker;
  final Duration _periodicInterval;
  final Stream<List<ConnectivityResult>> _connectivityStream;
  final Future<bool> Function() _hasNetwork;
  final SessionStatusStream? _sessionStatusStream;
  final OnUploadComplete? _onUploadComplete;
  final OnAnalysisComplete? _onAnalysisComplete;
  final OnReservationCreated? _onReservationCreated;

  /// Active per-sessionId Firestore subscriptions for completed rows
  /// awaiting backend analysis. Keyed by localId so we can clean up
  /// when the row is dismissed.
  final Map<String, StreamSubscription<String>> _analysisSubs = {};

  /// Live upload fraction (0..1) per localId during the GCS PUT — held in
  /// memory only (never persisted; resume() recomputes the real offset after
  /// an app-kill) and overlaid onto emitted snapshots so the UI can render a
  /// progress bar without an extra Hive write per chunk.
  final Map<String, double> _uploadProgress = {};

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
  List<PendingUpload> snapshotNow() => _withProgress(_queue.all());

  /// Overlays the in-memory live upload fraction onto rows currently
  /// uploading (phase=created) so the UI sees a progress bar.
  List<PendingUpload> _withProgress(List<PendingUpload> rows) {
    if (_uploadProgress.isEmpty) return rows;
    return rows.map((u) {
      final p = _uploadProgress[u.localId];
      if (p == null || u.phase != UploadPhase.created) return u;
      return u.copyWith(uploadProgress: p);
    }).toList();
  }

  // ── Lifecycle ─────────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;
    _running = true;

    _connSub = _connectivityStream.listen(_onConnectivityChanged,
        onError: (Object e) =>
            debugPrint('[upload-runner] connectivity stream error: $e'));
    _periodicTimer = Timer.periodic(_periodicInterval, (_) => _tick());

    // Cold-start backoff reset.
    //
    // When the previous app session got QUOTA_EXHAUSTED (or any other
    // retryable error) on a row, the worker pushes nextAttemptAt up to
    // ~30 minutes into the future via exponential backoff. If the user
    // then fixes the underlying problem (admin tops up tokens, a new
    // billing period rolls over, Wi-Fi comes back) and restarts the
    // app, the runner's _tick() still skips that row because
    // _queue.dueNow() filters on nextAttemptAt > now — so the user
    // sees "Audio czeka w kolejce do uploadu" stuck until the backoff
    // window finally elapses, with no visible affordance that anything
    // will happen.
    //
    // App cold-start is a strong "try again now" signal. We pull any
    // future nextAttemptAt back to now so the initial _tick() below
    // gives every parked row one fresh attempt. If the same error
    // recurs, the worker re-applies the backoff schedule via
    // _scheduleRetry, so we don't trade idle for spam.
    await _resetBackoffsForColdStart();

    _emitSnapshot();
    // Initial tick: drain anything that's already due (e.g. queued
    // before this runner existed because we just resumed from
    // backgrounded state). Awaited so callers can trust that by the
    // time start() returns, any pre-existing queue items have had
    // at least one phase advanced (or been deferred for offline).
    await _tick();

    // Startup hygiene: sweep orphaned source files left behind by
    // crashes or pre-fix builds (rows whose Hive entry is gone but
    // whose `sessions/<id>/` or `queued_uploads/<id>/` dir survived).
    // Age-gated by the queue's max-age so we never touch an in-flight
    // recording. Runs after the initial tick (which may have created
    // fresh rows) so those localIds count as live. Unawaited — pure
    // disk hygiene that must not delay start() returning.
    unawaited(_pruneOrphanedSources());
  }

  /// One-shot orphan-source prune. Best-effort; logs the count.
  Future<void> _pruneOrphanedSources() async {
    try {
      final live = _queue.all().map((u) => u.localId).toSet();
      final removed = await _worker.pruneOrphanedSources(
        liveLocalIds: live,
        maxAge: _queue.maxAge,
      );
      if (removed > 0) {
        debugPrint('[upload-runner] pruned $removed orphaned source dir(s)');
      }
    } catch (e) {
      debugPrint('[upload-runner] orphan prune failed (ignored): $e');
    }
  }

  /// Pulls future nextAttemptAt back to now for every non-terminal row.
  /// Public so the Riverpod gateway can call it from the
  /// BillingQuotaCache 0→>0 transition listener (admin tops up tokens
  /// mid-session), and so tests can assert behavior without dealing
  /// with the full start() lifecycle. attemptCount is preserved — we
  /// want a single retry attempt, not a clean slate that would invite
  /// spam if the same problem recurs.
  Future<void> resetBackoffsForColdStart() => _resetBackoffsForColdStart();

  Future<void> _resetBackoffsForColdStart() async {
    final now = DateTime.now().toUtc();
    for (final row in _queue.all()) {
      if (row.isTerminal) continue;
      // Quota holds are explicit-resume only. Never un-park them on
      // cold start or on a billing top-up (feat/tokens-exhausted):
      // the therapist decides when to resend, so they're not surprised
      // by a token being spent on an upload they'd half-forgotten.
      if (row.isParked) continue;
      if (!row.nextAttemptAt.isAfter(now)) continue;
      await _queue.update(row.copyWith(nextAttemptAt: now));
    }
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

  /// Persist [upload] and emit a snapshot WITHOUT running a tick.
  ///
  /// Unlike [enqueueAndKick], this returns the instant the row is
  /// durable — it does NOT wait for the first phase to advance. The
  /// file-upload screen uses this for phase=converting rows: the first
  /// tick would run the (potentially minute-long) on-device transcode,
  /// and we must not block the screen on it. The caller enqueues, then
  /// navigates to SessionStatusScreen and fires [kick] in the
  /// background; the periodic timer would pick the row up regardless.
  /// The row is in Hive before this future completes, so it survives an
  /// immediate app-kill / navigation — which is the whole point.
  Future<void> enqueue(PendingUpload upload) async {
    await _queue.enqueue(upload);
    _emitSnapshot();
  }

  /// Manual nudge — exposed for the lifecycle hook
  /// (AppLifecycleState.resumed) in the Riverpod gateway, and used
  /// by tests to advance one phase at a time.
  Future<void> kick() => _tick();

  /// User-driven cancel/dismiss — removes a row from the queue
  /// regardless of phase. For a non-terminal row this stops further
  /// retries; for a terminal row it's just cleanup.
  Future<void> dismiss(String localId) async {
    // Wipe any on-disk source the row still owns (raw recording,
    // encrypted chunks, staged file-upload) BEFORE dropping the row —
    // once the row is gone the cleanup metadata (sourceKind/sourcePath)
    // is gone too, and the bytes would linger until the orphan sweep.
    // Idempotent: a completed row's source was already purged at PUT.
    final u = _queue.getById(localId);
    if (u != null) {
      await _worker.cleanupSource(u);
    }
    await _queue.removeById(localId);
    _uploadProgress.remove(localId);
    _emitSnapshot();
  }

  /// User-driven retry/resend — flips a failed OR quota-parked row
  /// back to pending so the next tick processes it. No-op for any
  /// other phase. Awaits the resulting tick so callers (and tests)
  /// get deterministic progress, matching enqueueAndKick's contract.
  ///
  /// This is the ONLY path that un-parks a quotaBlocked row: there is
  /// no automatic resume (feat/tokens-exhausted). Resetting
  /// attemptCount to 0 gives the resend a clean backoff schedule if
  /// it ends up hitting a transient error this time around.
  Future<void> retryFailed(String localId) async {
    final u = _queue.getById(localId);
    if (u == null ||
        (u.phase != UploadPhase.failed &&
            u.phase != UploadPhase.quotaBlocked)) {
      return;
    }
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

  /// Semantic alias for [retryFailed] — the quota-UX screens call
  /// "resend" (Wyślij ponownie), which is the same un-park-and-run
  /// operation. Kept as a distinct name so call sites read clearly.
  Future<void> resend(String localId) => retryFailed(localId);

  /// When one upload hits QUOTA_EXHAUSTED, park every OTHER still-active
  /// upload too — they'll all fail CreateAudioUpload the same way, so we
  /// stop the runner from hammering and present a consistent quota state
  /// across the whole queue. Each parked sibling is un-parked
  /// independently by an explicit resend. Excludes the row that just
  /// parked ([trigger]), terminal rows, and already-parked rows.
  Future<void> _parkSiblingsOnQuota(PendingUpload trigger) async {
    for (final row in _queue.all()) {
      if (row.localId == trigger.localId) continue;
      if (row.isTerminal || row.isParked) continue;
      await _queue.update(row.copyWith(
        phase: UploadPhase.quotaBlocked,
        lastError: trigger.lastError,
        clearUploadCredentials: true,
      ));
    }
    _emitSnapshot();
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
        // Re-read live state: a prior row this tick may have hit
        // QUOTA_EXHAUSTED and parked this one as a sibling
        // (_parkSiblingsOnQuota). Skip rows that are no longer runnable
        // so we don't fire a doomed CreateAudioUpload that just re-parks.
        final fresh = _queue.getById(initial.localId);
        if (fresh == null || fresh.isTerminal || fresh.isParked) continue;
        var current = fresh;
        while (_running) {
          // Deadlock breaker (2026-07-23): a single hung await inside
          // runOne (deadline-less gRPC in airplane mode, sesja a5ce601f)
          // held _tickInFlight forever and froze the ENTIRE queue with
          // no error. Every inner step now carries its own timeout; this
          // outer ceiling exists only so no future regression can wedge
          // the runner again. Generous on purpose — a 160 MB PUT with
          // the size-scaled transfer timeout must fit comfortably.
          final next = await _worker
              .runOne(
                current,
                onUploadProgress: (frac) {
                  _uploadProgress[current.localId] = frac;
                  _emitSnapshot(); // live progress bar during the PUT
                },
              )
              .timeout(
                const Duration(minutes: 30),
                onTimeout: () {
                  debugPrint('[upload-runner] runOne WEDGED >30 min for '
                      '${current.localId} (${current.phase.name}) — '
                      'backing off');
                  return current.copyWith(
                    attemptCount: current.attemptCount + 1,
                    nextAttemptAt:
                        DateTime.now().toUtc().add(const Duration(minutes: 2)),
                    lastError: 'wedged: ${current.phase.name} step exceeded '
                        '30 min without completing',
                  );
                },
              );
          if (identical(next, current)) break; // worker no-op (terminal/parked)
          // Upload finished one way or another — drop the transient progress.
          if (next.phase != UploadPhase.created) {
            _uploadProgress.remove(current.localId);
          }
          await _queue.update(next);
          changed = true;

          // QUOTA_EXHAUSTED on this row → every other queued upload for
          // this org will fail the same way. Park them all now so the
          // whole queue shows the consistent "Pula tokenów wyczerpana"
          // state instead of leaving siblings on "Audio czeka w
          // kolejce" until each one individually hits the wall.
          if (current.phase != UploadPhase.quotaBlocked &&
              next.phase == UploadPhase.quotaBlocked) {
            await _parkSiblingsOnQuota(next);
          }
          // Emit a snapshot mid-row so the SessionStatusScreen sees
          // each phase transition (pending → created → uploaded → …)
          // without waiting for the whole pipeline to finish.
          _emitSnapshot();

          // First transition into phase=created → CreateAudioUpload succeeded
          // (and on the backend ingestion-svc.ReserveCredit took 1 token).
          // Fire the callback so the SubscriptionPlanScreen can decrement
          // its local view immediately — no waiting for the Firestore mirror
          // update which only fires on edge thresholds.
          if (current.phase == UploadPhase.pending &&
              next.phase == UploadPhase.created) {
            try {
              _onReservationCreated?.call(next);
            } catch (e) {
              debugPrint('[upload-runner] onReservationCreated failed: $e');
            }
          }

          // First-time transition into phase=completed: the upload
          // pipeline finished and the server has a real session row
          // (in PROCESSING state). Refresh kartoteka caches so the
          // user sees the new session as soon as they navigate
          // back — without this the cached session list serves the
          // pre-upload snapshot for the duration of analysis.
          if (current.phase != UploadPhase.completed &&
              next.phase == UploadPhase.completed) {
            try {
              await _onUploadComplete?.call(next);
            } catch (e) {
              debugPrint('[upload-runner] onUploadComplete failed: $e');
            }
          }

          if (next.isTerminal) break;
          if (next.isParked) break; // quota hold — no auto-retry
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
      unawaited(() async {
        // The network is back, but rows that failed while it was gone
        // carry a nextAttemptAt minutes in the future — a bare tick
        // would skip them (dueNow filters on it) and the user would
        // stare at a frozen upload until the backoff elapsed. Same
        // semantics as the cold-start reset: pull schedules to now,
        // keep attemptCount. Parked (quota) rows stay parked.
        await _resetBackoffsForColdStart();
        await _tick();
      }());
    }
  }

  void _emitSnapshot() {
    if (_snapshotsCtrl.isClosed) return;
    _snapshotsCtrl.add(_withProgress(_queue.all()));
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

  // ── Debug-only surface (tree-shaken in release) ─────────────

  /// Inject a [PendingUpload] into the queue WITHOUT running a tick
  /// or writing to Hive. The row appears in snapshots for the
  /// duration of this session only. Useful for exercising the upload
  /// progress bar, quota-blocked UI, and failed-upload UX.
  void debugInjectRow(PendingUpload row) {
    if (!kDebugMode && !DebugFlags.simulationsEnabled) return;
    _queue.debugInject(row);
    _emitSnapshot();
  }

  /// Set a fake upload progress fraction (0..1) for a localId so
  /// the UI renders a progress bar. Only works for rows in
  /// phase=created (the live-upload phase).
  void debugSetProgress(String localId, double fraction) {
    if (!kDebugMode && !DebugFlags.simulationsEnabled) return;
    _uploadProgress[localId] = fraction.clamp(0.0, 1.0);
    _emitSnapshot();
  }

  /// Remove a debug-injected row and its progress entry.
  void debugDismissRow(String localId) {
    if (!kDebugMode && !DebugFlags.simulationsEnabled) return;
    _queue.debugRemove(localId);
    _uploadProgress.remove(localId);
    _emitSnapshot();
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
