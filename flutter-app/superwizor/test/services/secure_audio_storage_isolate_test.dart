// Round-trip test for the background-isolate AES path (Option A).
//
// SecureAudioStorageService.encryptRecording / decryptToTempFile now run
// their CPU-heavy AES-GCM loops in a background isolate (so the main/UI
// isolate never janks). This test proves the isolate path still produces
// chunks that decrypt back to the exact original bytes — the correctness
// invariant that matters most after moving crypto across an isolate
// boundary (key bytes passed in, encrypt pkg + dart:io only).

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:superwizor/services/secure_audio_storage_service.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sas_iso_test_');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  test('encrypt→decrypt round-trips exactly through the background isolate',
      () async {
    final svc = SecureAudioStorageService();
    const sessionId = 'sess-iso-1';

    // 2.5 MB of deterministic pseudo-random bytes → 3 chunks (2×1 MB + tail).
    final sessionDir = Directory(p.join(root.path, 'sessions', sessionId))
      ..createSync(recursive: true);
    final rawPath = p.join(sessionDir.path, 'raw.flac');
    final rng = Random(42);
    final original = Uint8List(2500000);
    for (var i = 0; i < original.length; i++) {
      original[i] = rng.nextInt(256);
    }
    await File(rawPath).writeAsBytes(original, flush: true);

    // Encrypt (isolate) → 3 chunks, raw securely deleted.
    final chunks = await svc.encryptRecording(rawPath: rawPath, sessionId: sessionId);
    expect(chunks.length, 3, reason: '2.5 MB / 1 MB chunk → 3 chunks');
    expect(File(rawPath).existsSync(), isFalse,
        reason: 'raw FLAC securely deleted after encryption');
    for (final c in chunks) {
      expect(File(c.path).existsSync(), isTrue, reason: 'chunk ${c.seq} written');
    }
    expect(SecureAudioStorageService.estimateDecryptedSize(chunks),
        original.length,
        reason: 'size estimate from chunk metadata matches plaintext');

    // Decrypt (isolate) → exact original bytes.
    final temp = await svc.decryptToTempFile(sessionId: sessionId);
    final roundTrip = await temp.readAsBytes();
    expect(roundTrip.length, original.length);
    expect(roundTrip, equals(original),
        reason: 'isolate encrypt+decrypt must reproduce the input exactly');
  });
}
