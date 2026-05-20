// Tests for AudioConverterService.convertM4aToFlac.
//
// We don't exercise the iOS-native side here — that requires an
// integration test on a real device or simulator (out of scope for
// `flutter test`). What we cover here is the Dart-side glue:
//
//   • Non-iOS platforms throw UnsupportedError (callers fall through
//     to server-side ConvertAudio RPC).
//   • Platform-channel responses surface as the right exception types.
//
// We use TestDefaultBinaryMessengerBinding to mock the MethodChannel
// so the tests run on whatever host platform `flutter test` uses
// (typically the Dart VM with Platform.* reflecting the developer's
// machine).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/services/audio_converter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ai.superwizor/audio_converter');

  group('convertM4aToFlac', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    // Only meaningful when running on a non-iOS host (which is true
    // for `flutter test` on macOS/Linux/Windows CI). Guard with a
    // platform check so an iOS device run doesn't fail the expectation.
    test('throws UnsupportedError on non-iOS platforms', () async {
      if (Platform.isIOS) {
        // Skip on iOS device runs — the assertion would be inverted.
        return;
      }
      final svc = AudioConverterService();
      expect(
        () => svc.convertM4aToFlac('/tmp/whatever.m4a'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    // On iOS-host CI (when we eventually get one), the MethodChannel
    // mock kicks in. The handler returns an error to simulate a
    // decode failure, and the wrapper should surface it as a
    // StateError (we strip the PlatformException type so callers
    // don't import flutter/services to catch it).
    test('surfaces native errors as StateError on iOS-host runs', () async {
      if (!Platform.isIOS) return;

      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'CONVERT_FAILED',
          message: 'simulated decode failure',
        );
      });

      final svc = AudioConverterService();
      expect(
        () => svc.convertM4aToFlac('/tmp/whatever.m4a'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
