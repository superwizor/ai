// RecordingManifestStore — durable sidecar metadata for an in-progress
// recording (docs/28 WS1).
//
// Problem: between RecordingService.start() and the stop-time
// runner.enqueue(), a recording has NO durable owner — the raw FLAC sits
// on disk but the session metadata (patient, therapist, language) lives
// only in RecordingScreen widget state. If the process dies (classically:
// the therapist answers a phone call, the app is backgrounded and the OS
// kills it), the file is orphaned forever and the session "disappears".
//
// Fix: `manifest.json` is written next to `raw.flac` the moment recording
// starts and deleted the moment durability ownership transfers to the
// upload queue (enqueue) or the user discards the recording. On launch,
// RecordingRecoveryService scans for manifests whose session never made
// it into the queue and offers the partial recording for upload.
//
// Deliberately plain dart:io + path_provider, no Hive: the manifest must
// be co-located with the audio so the pair lives or dies together, and
// must be writable before any provider graph is up.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class RecordingManifest {
  static const int currentVersion = 1;

  final int version;
  final String sessionId;
  final String therapistId;
  final String patientFileId;

  /// Denormalized so the recovery sheet can render a human-readable label
  /// even when the patients cache is cold or the patient was deleted.
  final String patientAlias;
  final String patientLanguageCode; // BCP47, e.g. 'pl-PL'
  final DateTime startedAtUtc;

  const RecordingManifest({
    this.version = currentVersion,
    required this.sessionId,
    required this.therapistId,
    required this.patientFileId,
    required this.patientAlias,
    required this.patientLanguageCode,
    required this.startedAtUtc,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'sessionId': sessionId,
        'therapistId': therapistId,
        'patientFileId': patientFileId,
        'patientAlias': patientAlias,
        'patientLanguageCode': patientLanguageCode,
        'startedAtUtc': startedAtUtc.toUtc().toIso8601String(),
      };

  factory RecordingManifest.fromJson(Map<String, dynamic> j) =>
      RecordingManifest(
        version: (j['version'] as num?)?.toInt() ?? 1,
        sessionId: j['sessionId'] as String,
        therapistId: j['therapistId'] as String,
        patientFileId: j['patientFileId'] as String,
        patientAlias: j['patientAlias'] as String? ?? '',
        patientLanguageCode: j['patientLanguageCode'] as String? ?? 'pl-PL',
        startedAtUtc: DateTime.parse(j['startedAtUtc'] as String).toUtc(),
      );
}

class RecordingManifestStore {
  /// Injection point for tests; production uses the app documents dir.
  RecordingManifestStore({Future<Directory> Function()? documentsDirProvider})
      : _documentsDir =
            documentsDirProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDir;

  static const String manifestFileName = 'manifest.json';

  Future<Directory> sessionsRoot() async {
    final docs = await _documentsDir();
    return Directory(p.join(docs.path, 'sessions'));
  }

  Future<String> _manifestPath(String sessionId) async {
    final root = await sessionsRoot();
    return p.join(root.path, sessionId, manifestFileName);
  }

  Future<void> write(RecordingManifest m) async {
    final path = await _manifestPath(m.sessionId);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(m.toJson()), flush: true);
  }

  /// Idempotent best-effort delete of the manifest only (the audio file
  /// is owned by whoever called this — queue row or discard flow).
  Future<void> delete(String sessionId) async {
    try {
      final f = File(await _manifestPath(sessionId));
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('[manifest] delete($sessionId) failed: $e');
    }
  }

  /// Deletes the whole `<docs>/sessions/<sessionId>/` directory —
  /// manifest, raw.flac, encrypted chunks, everything. Used by the
  /// recovery "Usuń" action and the retention sweep.
  Future<void> deleteSessionDir(String sessionId) async {
    try {
      final root = await sessionsRoot();
      final dir = Directory(p.join(root.path, sessionId));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('[manifest] deleteSessionDir($sessionId) failed: $e');
    }
  }

  /// Scans `<docs>/sessions/*/manifest.json`. Malformed or
  /// unknown-version manifests are skipped (logged, never thrown) — a
  /// future app version may understand them.
  Future<List<RecordingManifest>> scanAll() async {
    final out = <RecordingManifest>[];
    final root = await sessionsRoot();
    if (!await root.exists()) return out;
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final f = File(p.join(entry.path, manifestFileName));
      if (!await f.exists()) continue;
      try {
        final json = jsonDecode(await f.readAsString());
        if (json is! Map<String, dynamic>) continue;
        final m = RecordingManifest.fromJson(json);
        if (m.version > RecordingManifest.currentVersion) {
          debugPrint('[manifest] skipping ${m.sessionId}: '
              'version ${m.version} > ${RecordingManifest.currentVersion}');
          continue;
        }
        out.add(m);
      } catch (e) {
        debugPrint('[manifest] skipping malformed ${f.path}: $e');
      }
    }
    return out;
  }
}
