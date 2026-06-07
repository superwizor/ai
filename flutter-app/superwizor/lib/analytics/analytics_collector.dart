import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart' as $ts;
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart' as $struct;

import '../generated/clinical/v1/clinical.pbgrpc.dart';
import '../providers/grpc_provider.dart';

final analyticsCollectorProvider = Provider<AnalyticsCollector>((ref) {
  final client = ref.watch(grpcClientsProvider).clinical;
  final collector = AnalyticsCollector(client);
  ref.onDispose(() {
    collector.dispose();
  });
  return collector;
});

class AnalyticsCollector {
  final ClinicalServiceClient _client;
  final List<ClientEvent> _buffer = [];
  Timer? _flushTimer;
  String? _appVersion;

  AnalyticsCollector(this._client) {
    _init();
  }

  Future<void> _init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
    } catch (_) {
      _appVersion = "unknown";
    }
    // Start flush timer every 30 seconds
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
  }

  void track(String name, {Map<String, dynamic>? properties}) {
    final occurredAt = $ts.Timestamp.fromDateTime(DateTime.now());
    
    final platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other'));
    
    final struct = $struct.Struct();
    if (properties != null) {
      properties.forEach((key, value) {
        if (value == null) {
          struct.fields[key] = $struct.Value()..nullValue = $struct.NullValue.NULL_VALUE;
        } else if (value is bool) {
          struct.fields[key] = $struct.Value()..boolValue = value;
        } else if (value is num) {
          struct.fields[key] = $struct.Value()..numberValue = value.toDouble();
        } else if (value is String) {
          struct.fields[key] = $struct.Value()..stringValue = value;
        } else {
          struct.fields[key] = $struct.Value()..stringValue = value.toString();
        }
      });
    }

    final event = ClientEvent()
      ..eventName = name
      ..properties = struct
      ..occurredAt = occurredAt
      ..clientPlatform = platform
      ..clientVersion = _appVersion ?? 'loading';

    _buffer.add(event);
    if (_buffer.length >= 20) {
      flush();
    }
  }

  ScreenTracker trackScreen(String reportId, String sessionId, {bool isRevisit = false}) {
    return ScreenTracker(reportId, sessionId, this, isRevisit: isRevisit);
  }

  Future<void> flush() async {
    if (_buffer.isEmpty) return;

    final eventsToFlush = List<ClientEvent>.from(_buffer);
    _buffer.clear();

    try {
      final request = TrackEventsRequest()..events.addAll(eventsToFlush);
      await _client.trackEvents(request);
    } catch (e) {
      // Silently drop on error according to the design specification (never blocks client flow)
      debugPrint("Analytics flush failed: $e. Events dropped.");
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    flush(); // final flush
  }
}

class ScreenTracker with WidgetsBindingObserver {
  final String _reportId;
  final String _sessionId;
  final AnalyticsCollector _collector;
  final bool _isRevisit;
  final Stopwatch _active = Stopwatch();
  bool _paused = false;

  ScreenTracker(this._reportId, this._sessionId, this._collector, {bool isRevisit = false})
      : _isRevisit = isRevisit;

  void start() {
    _active.start();
    WidgetsBinding.instance.addObserver(this);
    _collector.track("report.read_started", properties: {
      "report_id": _reportId,
      "session_id": _sessionId,
      "is_revisit": _isRevisit,
    });
  }

  void stop() {
    _active.stop();
    WidgetsBinding.instance.removeObserver(this);
    _collector.track("report.read_finished", properties: {
      "report_id": _reportId,
      "session_id": _sessionId,
      "active_read_ms": _active.elapsedMilliseconds,
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _active.stop();
      _paused = true;
    } else if (state == AppLifecycleState.resumed && _paused) {
      _active.start();
      _paused = false;
    }
  }
}
