// Tests for RecordingForegroundService — verifies the MethodChannel
// calls are dispatched correctly for Android's foreground service.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/services/recording_foreground_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('superwizor/recording_fgs');
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      return true;
    });
    RecordingForegroundService.debugOverrideSupported = true;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    RecordingForegroundService.debugOverrideSupported = false;
  });

  test('start sends title and body arguments when supported', () async {
    await RecordingForegroundService.start(
      title: 'Nagrywanie sesji...',
      body: 'Sesja jest bezpiecznie rejestrowana.',
    );

    expect(log, hasLength(1));
    expect(log.first.method, 'start');
    expect(log.first.arguments, {
      'title': 'Nagrywanie sesji...',
      'body': 'Sesja jest bezpiecznie rejestrowana.',
    });
  });

  test('stop sends stop method call without arguments when supported', () async {
    await RecordingForegroundService.stop();

    expect(log, hasLength(1));
    expect(log.first.method, 'stop');
    expect(log.first.arguments, isNull);
  });

  test('updateStatus sends title and body arguments when supported', () async {
    await RecordingForegroundService.updateStatus(
      title: 'Wgrywanie...',
      body: 'Przesyłanie na serwer.',
    );

    expect(log, hasLength(1));
    expect(log.first.method, 'update');
    expect(log.first.arguments, {
      'title': 'Wgrywanie...',
      'body': 'Przesyłanie na serwer.',
    });
  });

  test('no-op on unsupported platforms (like host machine tests without flag)', () async {
    RecordingForegroundService.debugOverrideSupported = false;

    await RecordingForegroundService.start(title: 'T', body: 'B');
    await RecordingForegroundService.updateStatus(title: 'T', body: 'B');
    await RecordingForegroundService.stop();

    expect(log, isEmpty);
  });

  test('gracefully catches and logs PlatformException without rethrowing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'ERROR', message: 'test error');
    });

    // Should NOT throw.
    await RecordingForegroundService.start(title: 'T', body: 'B');
    await RecordingForegroundService.updateStatus(title: 'T', body: 'B');
    await RecordingForegroundService.stop();
  });
}
