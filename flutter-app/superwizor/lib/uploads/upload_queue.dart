// UploadQueue — Hive-backed durable store for PendingUpload rows.
//
// Why a separate box (not part of CacheManager):
//   • Lifecycle is different — cache boxes are wiped on logout, but
//     pending uploads must survive an auth blip (the audio is the
//     therapist's clinical record, not a derived view).
//   • Encryption key is different — uses the same per-therapist AES
//     key from CacheCipher (key reuse is fine; AES-GCM with random
//     IVs is safe).
//
// Storage shape: Hive box `pending_uploads_v1__<therapistId>` holds
// one Map entry per upload, keyed by PendingUpload.localId. The map
// is the PendingUpload.toJson() output — no envelope wrapper here
// because pending uploads don't have a TTL gate (they live until
// terminal + grace, see [maxAge] sweeper).
//
// Concurrency: all writes go through a single serialised future so
// the worker can't race with enqueue() / removeById() during a tick.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../utils/debug_flags.dart';

import '../cache/cache_cipher.dart';
import 'pending_upload.dart';

class UploadQueue {
  UploadQueue({
    required Box<Map> hiveBox,
    DateTime Function()? clock,
    Duration? maxAge,
  })  : _box = hiveBox,
        _clock = clock ?? (() => DateTime.now().toUtc()),
        _maxAge = maxAge ?? const Duration(days: 7);

  final Box<Map> _box;
  final DateTime Function() _clock;
  /// After this duration in queuedAt, the row is force-terminated
  /// with phase=failed even if it's still in a retryable state.
  /// Default 7 days per the implementation-plan QA — long enough
  /// for a vacation, short enough to flush dead state.
  final Duration _maxAge;

  /// The age after which an idle row is force-terminated and its
  /// on-disk source becomes eligible for the orphan prune sweep.
  /// Exposed so the runner can age-gate [UploadIo.pruneOrphanedSources]
  /// with the same window.
  Duration get maxAge => _maxAge;

  Future<void> _serialised = Future.value();

  /// In-memory-only rows injected by the debug panel. Never persisted
  /// to Hive, never processed by the worker, automatically cleared on
  /// hot restart. Keyed by localId.
  final Map<String, PendingUpload> _debugRows = {};

  // ── Open / scope ───────────────────────────────────────────────

  /// Opens the per-therapist queue box. Same AES key as the cache
  /// boxes (delegated to CacheCipher).
  static Future<UploadQueue> openForUser(
    String therapistId, {
    CacheCipher? cipher,
    Duration? maxAge,
    DateTime Function()? clock,
  }) async {
    final c = cipher ?? CacheCipher();
    final aes = await c.cipherFor(therapistId);
    final safe = therapistId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final box = await Hive.openBox<Map>(
      'pending_uploads_v1__$safe',
      encryptionCipher: aes,
    );
    return UploadQueue(hiveBox: box, maxAge: maxAge, clock: clock);
  }

  Future<void> close() async {
    if (_box.isOpen) await _box.close();
  }

  // ── Public API ────────────────────────────────────────────────

  /// Adds [upload] to the queue. If a row with the same localId
  /// already exists it's overwritten — callers can use this as a
  /// natural upsert.
  Future<void> enqueue(PendingUpload upload) => _enqueue(() async {
        await _box.put(upload.localId, _encode(upload));
      });

  /// Replaces the row identified by [upload.localId]. Throws if
  /// there's no existing row (use [enqueue] for upserts).
  Future<void> update(PendingUpload upload) => _enqueue(() async {
        if (!_box.containsKey(upload.localId)) {
          throw StateError(
              'UploadQueue.update: no row with localId=${upload.localId}');
        }
        await _box.put(upload.localId, _encode(upload));
      });

  /// Removes [localId] from the queue. No-op if it doesn't exist.
  /// The worker uses this to evict completed rows after the UI has
  /// a chance to render the success state (see UploadQueueProvider).
  Future<void> removeById(String localId) => _enqueue(() async {
        await _box.delete(localId);
      });

  /// Snapshot of all rows in the queue (any phase, any age).
  /// Returns a new list so callers can sort/filter without
  /// touching the underlying box.
  List<PendingUpload> all() {
    final out = <PendingUpload>[];
    for (final k in _box.keys) {
      final raw = _box.get(k);
      if (raw == null) continue;
      try {
        out.add(_decode(raw));
      } catch (e) {
        // Corrupt row — log and drop on next sweep. We don't delete
        // synchronously here because all() is meant to be read-only.
        debugPrint('[upload-queue] dropping unreadable row $k: $e');
      }
    }
    // Append debug-only in-memory rows (never persisted to Hive).
    out.addAll(_debugRows.values);
    return out;
  }

  PendingUpload? getById(String localId) {
    // Check debug overlay first.
    final debugRow = _debugRows[localId];
    if (debugRow != null) return debugRow;
    final raw = _box.get(localId);
    if (raw == null) return null;
    try {
      return _decode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Returns all non-terminal rows whose nextAttemptAt has elapsed —
  /// these are the ones the worker should pick up this tick.
  List<PendingUpload> dueNow() {
    final now = _clock();
    // Exclude debug rows — they should never be processed by the worker.
    return all()
        .where((u) =>
            !u.isTerminal &&
            !u.isParked &&
            !u.nextAttemptAt.isAfter(now) &&
            !_debugRows.containsKey(u.localId))
        .toList()
      // Oldest queued first — fair-queue ordering so a recent retry
      // doesn't starve an older row.
      ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
  }

  /// Force-terminates any row older than [_maxAge] that isn't
  /// already terminal. Sets phase=failed and lastError to a
  /// machine-readable sentinel so the UI can render a clear
  /// "max-age" reason. Returns the number of rows swept.
  Future<int> pruneStale() async {
    final now = _clock();
    final victims = all()
        // Parked quota holds are exempt: the audio is intentionally
        // waiting for the therapist to resend after a top-up, and
        // silently failing it after 7 days would lose the recording
        // with no trace. Only the user (resend / cancel) clears it.
        .where((u) => !u.isTerminal && !u.isParked && u.isOlderThan(_maxAge, now))
        // Exclude debug rows from pruning.
        .where((u) => !_debugRows.containsKey(u.localId))
        .toList();
    if (victims.isEmpty) return 0;
    await _enqueue(() async {
      for (final v in victims) {
        await _box.put(
            v.localId,
            _encode(v.copyWith(
              phase: UploadPhase.failed,
              lastError: 'queue.max_age_exceeded',
              terminatedAt: now,
            )));
      }
    });
    return victims.length;
  }

  /// Wipes the box. Used on hard logout / clearForUser cascade only.
  Future<void> clearAll() => _enqueue(() async {
        await _box.clear();
      });

  // ── Debug-only surface (tree-shaken in release) ──────────────

  /// Inject a row into the in-memory overlay. The row is visible in
  /// [all] and [getById] but is never written to Hive and is excluded
  /// from [dueNow] so the worker ignores it.
  void debugInject(PendingUpload row) {
    if (!kDebugMode && !DebugFlags.simulationsEnabled) return;
    _debugRows[row.localId] = row;
  }

  /// Remove a debug-only row from the in-memory overlay.
  void debugRemove(String localId) {
    if (!kDebugMode && !DebugFlags.simulationsEnabled) return;
    _debugRows.remove(localId);
  }

  // ── Internals ─────────────────────────────────────────────────

  Map _encode(PendingUpload u) => u.toJson();

  PendingUpload _decode(Map raw) {
    // Hive deserialises maps as Map<dynamic, dynamic> — fromJson
    // wants Map<String, dynamic>. Normalise via JSON round-trip
    // so the type coercion is consistent with the read path.
    final normalised = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
    return PendingUpload.fromJson(normalised);
  }

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final next = _serialised.then((_) => task());
    _serialised = next.then((_) {}, onError: (_, _) {});
    return next;
  }
}
