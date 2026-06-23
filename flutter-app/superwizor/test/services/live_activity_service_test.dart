// Tests for LiveActivityService — verifies the MethodChannel bridge
// sends the correct method names and argument maps for each state
// transition (start → update → reportReady → stop).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/services/live_activity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannel channel;
  late LiveActivityService service;
  late List<MethodCall> log;

  setUp(() {
    log = [];
    channel = const MethodChannel('ai.superwizor/live_activity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      return true;
    });
    service = LiveActivityService(channel: channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('start sends patientAlias and elapsedSeconds', () async {
    await service.start(patientAlias: 'Jan K.', elapsedSeconds: 42);

    expect(log, hasLength(1));
    expect(log.first.method, 'start');
    expect(log.first.arguments, {
      'patientAlias': 'Jan K.',
      'elapsedSeconds': 42,
    });
  });

  test('update sends status name and elapsedSeconds', () async {
    await service.update(
      status: LiveActivityStatus.paused,
      elapsedSeconds: 300,
    );

    expect(log, hasLength(1));
    expect(log.first.method, 'update');
    expect(log.first.arguments, {
      'status': 'paused',
      'elapsedSeconds': 300,
    });
  });

  test('update sends recording status', () async {
    await service.update(
      status: LiveActivityStatus.recording,
      elapsedSeconds: 0,
    );

    expect(log.first.arguments['status'], 'recording');
  });

  test('update sends uploading status', () async {
    await service.update(
      status: LiveActivityStatus.uploading,
      elapsedSeconds: 600,
    );

    expect(log.first.arguments['status'], 'uploading');
  });

  test('update sends analyzing status', () async {
    await service.update(
      status: LiveActivityStatus.analyzing,
      elapsedSeconds: 600,
    );

    expect(log.first.arguments['status'], 'analyzing');
  });

  test('showReportReady sends sessionId and default reportCount', () async {
    await service.showReportReady(sessionId: 'abc-123');

    expect(log, hasLength(1));
    expect(log.first.method, 'reportReady');
    expect(log.first.arguments, {
      'sessionId': 'abc-123',
      'reportCount': 1,
    });
  });

  test('showReportReady sends sessionId and custom reportCount', () async {
    await service.showReportReady(sessionId: 'abc-123', reportCount: 3);

    expect(log, hasLength(1));
    expect(log.first.method, 'reportReady');
    expect(log.first.arguments, {
      'sessionId': 'abc-123',
      'reportCount': 3,
    });
  });

  test('stop sends no arguments', () async {
    await service.stop();

    expect(log, hasLength(1));
    expect(log.first.method, 'stop');
    expect(log.first.arguments, isNull);
  });

  test('full lifecycle: start → update → reportReady → stop', () async {
    await service.start(patientAlias: 'A.N.', elapsedSeconds: 0);
    await service.update(
      status: LiveActivityStatus.recording,
      elapsedSeconds: 120,
    );
    await service.update(
      status: LiveActivityStatus.paused,
      elapsedSeconds: 120,
    );
    await service.update(
      status: LiveActivityStatus.uploading,
      elapsedSeconds: 300,
    );
    await service.update(
      status: LiveActivityStatus.analyzing,
      elapsedSeconds: 300,
    );
    await service.showReportReady(sessionId: 'session-xyz');
    await service.stop();

    expect(log.map((c) => c.method).toList(), [
      'start',
      'update',
      'update',
      'update',
      'update',
      'reportReady',
      'stop',
    ]);
  });

  test('start gracefully handles PlatformException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'UNAVAILABLE');
    });

    // Should NOT throw — fire-and-forget.
    await service.start(patientAlias: 'X', elapsedSeconds: 0);
  });

  test('update gracefully handles MissingPluginException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException('no handler');
    });

    // Should NOT throw.
    await service.update(
      status: LiveActivityStatus.recording,
      elapsedSeconds: 0,
    );
  });
}
