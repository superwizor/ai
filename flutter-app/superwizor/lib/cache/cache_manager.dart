// CacheManager — the singleton entry point for the cache subsystem.
//
// Responsibilities:
//   • Open per-therapist Hive boxes lazily, using CacheCipher to
//     produce a HiveAesCipher bound to the therapist.
//   • Expose typed CacheBox<T> handles to repositories.
//   • Enforce the global 300 MB cap with cross-box LRU eviction.
//   • On logout: close + delete every box for the previous therapist
//     and forget the secure-storage key (hard eviction).
//   • Pin schema version; wipe on bump.
//
// Lifecycle (driven by main.dart + a riverpod listener):
//   1. App boot → CacheManager.initialize() opens Hive at app docs.
//   2. Therapist signs in → openForUser(therapistId) opens all three
//      domain boxes for that user.
//   3. Therapist signs out → clearForUser(therapistId) drops boxes
//      from disk and wipes the keychain key.
//
// Concurrency: all public methods serialise on a single Future to
// avoid open/close races during fast auth changes.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'cache_box.dart';
import 'cache_cipher.dart';
import 'cache_keys.dart';
import 'dto/patient_dto.dart';
import 'dto/session_details_dto.dart';
import 'dto/session_dto.dart';

class _BoxHandles {
  final String therapistId;
  final Box<Map> patients;
  final Box<Map> sessions;
  final Box<Map> sessionDetails;
  final Box<Map> meta;

  _BoxHandles({
    required this.therapistId,
    required this.patients,
    required this.sessions,
    required this.sessionDetails,
    required this.meta,
  });

  Iterable<Box<Map>> get all => [patients, sessions, sessionDetails, meta];
}

class CacheManager {
  CacheManager({CacheCipher? cipher, int? maxBytes})
      : _cipher = cipher ?? CacheCipher(),
        _maxBytes = maxBytes ?? _defaultMaxBytes;

  // Hard cap: 300 MB. The number was chosen with the user in the
  // implementation-plan QA — large enough that typical (~50 MB) and
  // moderate (~150 MB) caches never evict, small enough that a worst-
  // case 200 patients × 10 sessions × 200 KB transcript (~400 MB) is
  // trimmed to the most-recently-accessed slice.
  static const _defaultMaxBytes = 300 * 1024 * 1024;

  // TTLs by entity. Soft = serve cached then revalidate; hard = drop
  // on read. Tuned for clinical workflow: patients change rarely,
  // session lists change after each new session, session details are
  // immutable after report generation but reports themselves can be
  // re-rated.
  static const _patientsSoftTtl = Duration(hours: 24);
  static const _patientsHardTtl = Duration(days: 30);
  static const _sessionsSoftTtl = Duration(hours: 1);
  static const _sessionsHardTtl = Duration(days: 30);
  static const _sessionDetailsSoftTtl = Duration(hours: 1);
  static const _sessionDetailsHardTtl = Duration(days: 30);

  final CacheCipher _cipher;
  final int _maxBytes;

  _BoxHandles? _open;
  Future<void> _serialised = Future.value();

  // ── lifecycle ──────────────────────────────────────────────────

  /// Opens (or returns the already-open) box set for [therapistId].
  /// Calling this with a different therapistId than the currently
  /// open one is treated as a switch — old boxes are closed first.
  Future<void> openForUser(String therapistId) {
    return _enqueue(() async {
      if (_open?.therapistId == therapistId) return;
      if (_open != null) await _closeOpenedBoxes();

      final cipher = await _cipher.cipherFor(therapistId);
      Future<Box<Map>> open(String name) =>
          Hive.openBox<Map>(name, encryptionCipher: cipher);

      _open = _BoxHandles(
        therapistId: therapistId,
        patients: await open(CacheKeys.patientsBox(therapistId)),
        sessions: await open(CacheKeys.sessionsBox(therapistId)),
        sessionDetails: await open(CacheKeys.sessionDetailsBox(therapistId)),
        meta: await open(CacheKeys.metaBox(therapistId)),
      );
    });
  }

  /// Closes any open boxes without deleting them — used when the app
  /// pauses without an explicit sign-out (Hive will reopen them on
  /// next openForUser).
  Future<void> close() => _enqueue(_closeOpenedBoxes);

  /// Hard-evicts every byte for [therapistId]: closes boxes, deletes
  /// the box files from disk, deletes the secure-storage key. Safe to
  /// call when nothing is open. Used on sign-out.
  Future<void> clearForUser(String therapistId) {
    return _enqueue(() async {
      if (_open?.therapistId == therapistId) {
        await _closeOpenedBoxes();
      }
      for (final name in CacheKeys.allBoxesFor(therapistId)) {
        try {
          await Hive.deleteBoxFromDisk(name);
        } catch (e) {
          debugPrint('[cache] deleteBoxFromDisk($name) failed: $e');
        }
      }
      await _cipher.forgetKeyFor(therapistId);
    });
  }

  Future<void> _closeOpenedBoxes() async {
    final h = _open;
    if (h == null) return;
    for (final b in h.all) {
      try {
        if (b.isOpen) await b.close();
      } catch (e) {
        debugPrint('[cache] close(${b.name}) failed: $e');
      }
    }
    _open = null;
  }

  // ── typed box accessors (for repositories) ─────────────────────

  CacheBox<List<PatientDto>> patientsBox() {
    final h = _requireOpen();
    return CacheBox<List<PatientDto>>(
      hiveBox: h.patients,
      fromJson: (j) => ((j['items'] as List?) ?? const [])
          .map((e) => PatientDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      toJson: (list) => {'items': list.map((p) => p.toJson()).toList()},
      softTtl: _patientsSoftTtl,
      hardTtl: _patientsHardTtl,
    );
  }

  CacheBox<List<SessionDto>> sessionsBox() {
    final h = _requireOpen();
    return CacheBox<List<SessionDto>>(
      hiveBox: h.sessions,
      fromJson: (j) => ((j['items'] as List?) ?? const [])
          .map((e) => SessionDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      toJson: (list) => {'items': list.map((s) => s.toJson()).toList()},
      softTtl: _sessionsSoftTtl,
      hardTtl: _sessionsHardTtl,
    );
  }

  CacheBox<SessionDetailsDto> sessionDetailsBox() {
    final h = _requireOpen();
    return CacheBox<SessionDetailsDto>(
      hiveBox: h.sessionDetails,
      fromJson: SessionDetailsDto.fromJson,
      toJson: (dto) => dto.toJson(),
      softTtl: _sessionDetailsSoftTtl,
      hardTtl: _sessionDetailsHardTtl,
    );
  }

  String get currentTherapistId => _requireOpen().therapistId;

  // ── targeted invalidation (called from repositories on mutations) ──

  /// Wipes everything for a patient — used when DeletePatientFile or
  /// DeletePatientUser succeeds. Removes the patient row from the
  /// patient list, the session list for that patient, and every
  /// session_details entry whose Session.patientFileId matches.
  Future<void> evictPatient(String patientFileId) async {
    final h = _open;
    if (h == null) return;
    final tid = h.therapistId;

    // Patient list — rewrite without the deleted row.
    final pBox = patientsBox();
    final cached = await pBox.get(CacheKeys.patientsKey(tid));
    if (cached != null) {
      final remaining =
          cached.data.where((p) => p.id != patientFileId).toList();
      await pBox.put(CacheKeys.patientsKey(tid), remaining);
    }

    // Session list for this patient — drop entirely.
    await h.sessions.delete(CacheKeys.sessionsKey(tid, patientFileId));

    // Session details — scan keys, drop those whose cached Session
    // points at this patient. Cheap because keys + envelopes are in
    // memory; we don't need to decrypt full transcripts.
    final detailsBox = sessionDetailsBox();
    final toDelete = <String>[];
    for (final key in h.sessionDetails.keys) {
      final raw = h.sessionDetails.get(key);
      if (raw == null) continue;
      final data = raw['d'];
      if (data is! Map) continue;
      final session = data['session'];
      if (session is! Map) continue;
      if (session['patientFileId'] == patientFileId) {
        toDelete.add(key.toString());
      }
    }
    for (final k in toDelete) {
      await detailsBox.delete(k);
    }
  }

  // ── size enforcement (LRU eviction) ────────────────────────────

  /// Walks all currently-open boxes, sums sizeBytes, and if the total
  /// exceeds [_maxBytes] evicts oldest-accessed entries until back
  /// under the cap. Called by repositories after large writes (session
  /// details) and can be scheduled periodically by main.dart.
  Future<EvictionReport> enforceSizeCap() async {
    final h = _open;
    if (h == null) return const EvictionReport.empty();

    // Build a flat (boxName, key, lastAccessedAt, sizeBytes) list.
    final entries = <_LruEntry>[];
    int total = 0;
    for (final box in [h.patients, h.sessions, h.sessionDetails]) {
      for (final k in box.keys) {
        final raw = box.get(k);
        if (raw == null) continue;
        final la = raw['la'];
        final sz = raw['sz'];
        if (la is! String || sz is! num) continue;
        final size = sz.toInt();
        total += size;
        entries.add(_LruEntry(
          box: box,
          key: k.toString(),
          lastAccessedAt: DateTime.tryParse(la)?.toUtc() ?? DateTime.utc(1970),
          sizeBytes: size,
        ));
      }
    }

    if (total <= _maxBytes) {
      return EvictionReport(evictedCount: 0, bytesEvicted: 0, totalAfter: total);
    }

    // Sort oldest-first; evict head until we're under cap.
    entries.sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));
    var evictedBytes = 0;
    var evictedCount = 0;
    for (final e in entries) {
      if (total - evictedBytes <= _maxBytes) break;
      await e.box.delete(e.key);
      evictedBytes += e.sizeBytes;
      evictedCount++;
    }

    debugPrint('[cache] LRU eviction: dropped $evictedCount entries / '
        '${(evictedBytes / 1024 / 1024).toStringAsFixed(1)} MB');

    return EvictionReport(
      evictedCount: evictedCount,
      bytesEvicted: evictedBytes,
      totalAfter: total - evictedBytes,
    );
  }

  int currentTotalBytes() {
    final h = _open;
    if (h == null) return 0;
    var sum = 0;
    for (final box in [h.patients, h.sessions, h.sessionDetails]) {
      for (final k in box.keys) {
        final raw = box.get(k);
        if (raw == null) continue;
        final sz = raw['sz'];
        if (sz is num) sum += sz.toInt();
      }
    }
    return sum;
  }

  // ── internals ──────────────────────────────────────────────────

  _BoxHandles _requireOpen() {
    final h = _open;
    if (h == null) {
      throw StateError(
          'CacheManager: no therapist box set is open. Call openForUser() first.');
    }
    return h;
  }

  // Serialise public mutations so open/close/clear can't interleave.
  Future<T> _enqueue<T>(Future<T> Function() task) {
    final next = _serialised.then((_) => task());
    _serialised = next.then((_) {}, onError: (_, _) {});
    return next;
  }
}

class _LruEntry {
  final Box<Map> box;
  final String key;
  final DateTime lastAccessedAt;
  final int sizeBytes;
  _LruEntry({
    required this.box,
    required this.key,
    required this.lastAccessedAt,
    required this.sizeBytes,
  });
}

class EvictionReport {
  final int evictedCount;
  final int bytesEvicted;
  final int totalAfter;
  const EvictionReport({
    required this.evictedCount,
    required this.bytesEvicted,
    required this.totalAfter,
  });
  const EvictionReport.empty()
      : evictedCount = 0,
        bytesEvicted = 0,
        totalAfter = 0;
}
