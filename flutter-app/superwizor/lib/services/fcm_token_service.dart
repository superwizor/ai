// FCM token lifecycle (Etap 0).
//
// register():   pulls token from FirebaseMessaging, sends to
//               notification-svc.RegisterFCMToken. Idempotent — backend
//               UPSERTs (user_id, token).
// watchRefresh: long-lived stream subscription; re-registers on rotation
//               (Firebase rotates ~every 30 days).
// unregister(): backend RemoveFCMToken + local deleteToken on logout.

import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../generated/notification/v1/notification.pb.dart' as notif_pb;
import '../generated/notification/v1/notification.pbgrpc.dart' as notif_grpc;

class FcmTokenService {
  FcmTokenService(this._client);

  final notif_grpc.NotificationServiceClient _client;
  StreamSubscription<String>? _refreshSub;

  /// Requests notification permission (iOS + Android 13+) and pushes
  /// the current FCM token to the backend.
  Future<void> registerAfterLogin() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM permission denied — push notifications disabled.');
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      debugPrint('FCM getToken() returned null — skipping register.');
      return;
    }
    await _push(token);

    _refreshSub?.cancel();
    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(_push);
  }

  /// Stops the refresh listener and revokes the token both server-side
  /// and locally. Call on logout / hard-delete.
  Future<void> unregister() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      try {
        await _client.removeFCMToken(
          notif_pb.RemoveFCMTokenRequest(token: token),
        );
      } catch (e) {
        debugPrint('RemoveFCMToken failed (non-fatal): $e');
      }
    }
    await FirebaseMessaging.instance.deleteToken();
  }

  // ---------- internals ----------

  Future<void> _push(String token) async {
    final pkg = await PackageInfo.fromPlatform();
    final platform = await _detectPlatform();
    final model = await _deviceModel();

    try {
      await _client.registerFCMToken(notif_pb.RegisterFCMTokenRequest(
        token: token,
        platform: platform,
        appVersion: pkg.version,
        deviceModel: model,
        locale: 'pl-PL',
      ));
      debugPrint('FCM token registered (${token.substring(0, 12)}…)');
    } catch (e) {
      debugPrint('RegisterFCMToken failed: $e');
    }
  }

  Future<notif_pb.Platform> _detectPlatform() async {
    if (!kIsWeb && Platform.isIOS) return notif_pb.Platform.PLATFORM_IOS;
    if (!kIsWeb && Platform.isAndroid) return notif_pb.Platform.PLATFORM_ANDROID;
    return notif_pb.Platform.PLATFORM_WEB;
  }

  Future<String> _deviceModel() async {
    final info = DeviceInfoPlugin();
    try {
      if (!kIsWeb && Platform.isIOS) {
        final i = await info.iosInfo;
        return i.utsname.machine;
      }
      if (!kIsWeb && Platform.isAndroid) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model}';
      }
    } catch (_) {}
    return 'unknown';
  }
}
