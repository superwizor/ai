// Cykl życia tokenu FCM.
//
// start()             — obserwuje stan logowania i UTRZYMUJE rejestrację:
//                       przy każdym starcie aplikacji z zalogowanym
//                       użytkownikiem oraz przy każdej rotacji tokenu.
// registerAfterLogin()— wersja z PYTANIEM o uprawnienia; wołana z ekranu
//                       konfiguracji, gdzie systemowy prompt ma kontekst.
// unregister()        — RemoveFCMToken + deleteToken przy wylogowaniu.
//
// DLACZEGO start() ISTNIEJE. Do 22.08.2026 rejestracja odpalała się
// WYŁĄCZNIE z ekranu konfiguracji terapeuty, czyli raz w życiu konta.
// Każda z sześciu sytuacji kończyła się trwałą ciszą, bez śladu w UI:
// konto sprzed tego kodu, reinstalacja, nowe urządzenie, odmowa
// uprawnień w tamtej jednej chwili, błąd RPC w tamtej jednej chwili
// oraz — najgorsza — rotacja tokenu. Firebase rotuje co ~30 dni, a
// `onTokenRefresh` był subskrybowany WEWNĄTRZ registerAfterLogin, więc
// skoro tamto nie działało w żadnej sesji, rotacja nigdy nie docierała.
// Backend oznaczał stary token `invalidated_at`, a terapeuta cicho
// znikał z listy odbiorców (log 21.08: "therapist has no active FCM
// tokens — skipping push").
//
// Rejestracja jest więc STANEM UTRZYMYWANYM, nie zdarzeniem.

import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../generated/notification/v1/notification.pb.dart' as notif_pb;
import '../generated/notification/v1/notification.pbgrpc.dart' as notif_grpc;

class FcmTokenService {
  FcmTokenService(this._client);

  final notif_grpc.NotificationServiceClient _client;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<User?>? _authSub;
  String? _uid;

  /// Zaczyna utrzymywać rejestrację. Wołane raz, przy starcie aplikacji —
  /// przed zalogowaniem jest nieszkodliwe, tak jak InboxRefreshListener.
  ///
  /// NIE pyta o uprawnienia. Systemowy prompt na starcie aplikacji jest
  /// wyrwany z kontekstu; o zgodę prosi ekran konfiguracji. Tutaj tylko
  /// korzystamy z już udzielonej.
  void start() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      final uid = user?.uid;
      if (uid == _uid) return; // bez zmiany
      _uid = uid;
      if (uid == null) {
        _refreshSub?.cancel();
        _refreshSub = null;
        return;
      }
      unawaited(ensureRegistered());
    });
  }

  /// Zwalnia obserwatora stanu logowania. Do testów i zamknięcia aplikacji.
  Future<void> stop() async {
    await _authSub?.cancel();
    _authSub = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
    _uid = null;
  }

  /// Requests notification permission (iOS + Android 13+) and pushes
  /// the current FCM token to the backend.
  Future<void> registerAfterLogin() => ensureRegistered(askPermission: true);

  /// Doprowadza rejestrację do stanu „aktualny token jest u serwera".
  ///
  /// Idempotentne — backend UPSERT-uje po (user_id, token), więc wołanie
  /// przy każdym starcie nic nie psuje, a naprawia reinstalację, nowe
  /// urządzenie i konto sprzed tego kodu.
  Future<void> ensureRegistered({bool askPermission = false}) async {
    final messaging = FirebaseMessaging.instance;

    var status = (await messaging.getNotificationSettings()).authorizationStatus;
    if (askPermission && status == AuthorizationStatus.notDetermined) {
      status = (await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      ))
          .authorizationStatus;
    }
    if (status == AuthorizationStatus.denied) {
      debugPrint('FCM permission denied — push notifications disabled.');
      return;
    }
    if (status == AuthorizationStatus.notDetermined) {
      // Bez zgody iOS nie wyda tokenu. Nie pytamy tu z własnej inicjatywy;
      // zapyta ekran konfiguracji.
      debugPrint('FCM permission not determined — pomijam rejestrację.');
      return;
    }

    final token = await messaging.getToken();
    if (token == null) {
      debugPrint('FCM getToken() returned null — skipping register.');
      return;
    }
    await _push(token);

    // Subskrypcja rotacji NIEZALEŻNIE od wyniku _push. Nawet gdy dzisiejsza
    // rejestracja padła, jutrzejsza rotacja ma dokąd trafić.
    _refreshSub?.cancel();
    _refreshSub = messaging.onTokenRefresh.listen(_push);
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

  /// Odstępy ponowień rejestracji w obrębie jednej sesji aplikacji.
  ///
  /// Start aplikacji to typowy moment na chwilowy brak sieci, a wcześniej
  /// pojedyncza porażka oznaczała ciszę do następnej reinstalacji: błąd
  /// był połykany do debugPrint, a nic nie wracało do tematu.
  static const _retryDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  Future<void> _push(String token) async {
    final pkg = await PackageInfo.fromPlatform();
    final platform = await _detectPlatform();
    final model = await _deviceModel();
    final req = notif_pb.RegisterFCMTokenRequest(
      token: token,
      platform: platform,
      appVersion: pkg.version,
      deviceModel: model,
      locale: 'pl-PL',
    );

    await retryQuietly(
      () => _client.registerFCMToken(req),
      delays: _retryDelays,
      onSuccess: () =>
          debugPrint('FCM token registered (${token.substring(0, 12)}…)'),
      onGiveUp: (e, attempts) =>
          debugPrint('RegisterFCMToken failed after $attempts attempts: $e'),
    );
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

/// Ponawia [op] po kolejnych [delays] i nigdy nie rzuca.
///
/// Wydzielone z FcmTokenService, bo to jedyny fragment tej ścieżki, który
/// da się przetestować bez singletonów Firebase — a zarazem ten, w którym
/// najłatwiej o błąd o jeden (liczba prób to `delays.length + 1`, nie
/// `delays.length`).
///
/// Cisza jest tu zamierzona: nieudana rejestracja tokenu nie może wywalić
/// startu aplikacji. Różnica względem stanu sprzed 22.08.2026 jest taka,
/// że następny start spróbuje ponownie, zamiast zostawić konto bez
/// powiadomień do reinstalacji.
Future<void> retryQuietly(
  Future<void> Function() op, {
  required List<Duration> delays,
  void Function()? onSuccess,
  void Function(Object error, int attempts)? onGiveUp,
  Future<void> Function(Duration)? sleep,
}) async {
  final wait = sleep ?? (d) => Future<void>.delayed(d);
  for (var attempt = 0;; attempt++) {
    try {
      await op();
      onSuccess?.call();
      return;
    } catch (e) {
      if (attempt >= delays.length) {
        onGiveUp?.call(e, delays.length + 1);
        return;
      }
      await wait(delays[attempt]);
    }
  }
}
