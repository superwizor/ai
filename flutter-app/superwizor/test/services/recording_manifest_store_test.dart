import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:superwizor/services/recording_manifest_store.dart';

void main() {
  late Directory tmp;
  late RecordingManifestStore store;

  RecordingManifest manifest(String id, {String therapist = 'th_1'}) =>
      RecordingManifest(
        sessionId: id,
        therapistId: therapist,
        patientFileId: 'pf_1',
        patientAlias: 'Jan K.',
        patientLanguageCode: 'pl-PL',
        startedAtUtc: DateTime.utc(2026, 6, 9, 10, 12, 33),
      );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('manifest_test_');
    store = RecordingManifestStore(documentsDirProvider: () async => tmp);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('write → scanAll round-trips all fields', () async {
    await store.write(manifest('s1'));
    final found = await store.scanAll();
    expect(found, hasLength(1));
    final m = found.single;
    expect(m.sessionId, 's1');
    expect(m.therapistId, 'th_1');
    expect(m.patientFileId, 'pf_1');
    expect(m.patientAlias, 'Jan K.');
    expect(m.patientLanguageCode, 'pl-PL');
    expect(m.startedAtUtc, DateTime.utc(2026, 6, 9, 10, 12, 33));
    expect(m.version, RecordingManifest.currentVersion);
  });

  test('scanAll skips malformed manifests without throwing', () async {
    await store.write(manifest('good'));
    final badDir = Directory(p.join(tmp.path, 'sessions', 'bad'));
    await badDir.create(recursive: true);
    await File(p.join(badDir.path, 'manifest.json'))
        .writeAsString('{not json!!');
    final found = await store.scanAll();
    expect(found.map((m) => m.sessionId), ['good']);
  });

  test('scanAll skips manifests from a future version', () async {
    final dir = Directory(p.join(tmp.path, 'sessions', 'future'));
    await dir.create(recursive: true);
    final json = manifest('future').toJson()..['version'] = 99;
    await File(p.join(dir.path, 'manifest.json'))
        .writeAsString(jsonEncode(json));
    expect(await store.scanAll(), isEmpty);
  });

  test('scanAll on missing sessions root returns empty', () async {
    expect(await store.scanAll(), isEmpty);
  });

  test('delete removes only the manifest, audio stays', () async {
    await store.write(manifest('s1'));
    final flac = File(p.join(tmp.path, 'sessions', 's1', 'raw.flac'));
    await flac.writeAsBytes(List.filled(10, 0));

    await store.delete('s1');

    expect(await store.scanAll(), isEmpty);
    expect(await flac.exists(), isTrue);
    // Idempotent — second delete is a no-op, not an error.
    await store.delete('s1');
  });

  test('deleteSessionDir removes the whole directory', () async {
    await store.write(manifest('s1'));
    await File(p.join(tmp.path, 'sessions', 's1', 'raw.flac'))
        .writeAsBytes(List.filled(10, 0));

    await store.deleteSessionDir('s1');

    expect(
      Directory(p.join(tmp.path, 'sessions', 's1')).existsSync(),
      isFalse,
    );
  });
}
