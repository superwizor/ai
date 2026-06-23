import 'analytics/analytics_collector.dart';
import 'providers/current_user_provider.dart';
import 'providers/locale_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'auth/sso_handler.dart'
    if (dart.library.html) 'auth/sso_handler_web.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/euphire_theme.dart';
import 'uploads/upload_queue_provider.dart';
import 'widgets/minimized_recording_bar.dart';

/// Top-level handler for FCM messages while the app is in the
/// background or terminated. Must be a top-level function (or static)
/// per Firebase docs — Dart spawns a new isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate: do minimal work; UI nav happens via
  // onMessageOpenedApp when user taps the notification.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FCM bg msg: ${message.messageId}');
}

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();



  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Cross-origin SSO bridge: if the user arrived from
  // superwizor.web.app via the Otworz kartoteki CTA, the URL
  // fragment carries a one-shot Firebase custom token. Redeem it
  // BEFORE runApp so the _AuthGate's first authStateChanges tick
  // already sees a signed-in user — no LoginScreen flash. No-op on
  // iOS/Android (conditional import resolves to the stub).
  await applySsoFromUrl();

  // Hive — used by ConsentService (D9), the cache repositories
  // (lib/cache/), and the offline upload queue (lib/uploads/).
  await Hive.initFlutter();

  // App-lifecycle observer that nudges the upload queue runner when
  // the app returns to the foreground. The runner itself is created
  // lazily by uploadQueueRunnerProvider after the user signs in.
  WidgetsBinding.instance.addObserver(UploadQueueLifecycleObserver());

  // Firestore offline persistence — keeps last seen session_states
  // for offline-first reads.
  cf.FirebaseFirestore.instance.settings = const cf.Settings(
    persistenceEnabled: true,
    cacheSizeBytes: cf.Settings.CACHE_SIZE_UNLIMITED,
  );

  // Date formatting (Polish month names in PDF + UI).
  await initializeDateFormatting('pl_PL');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Foreground push: just log for MVP — toast UI hooks added later.
  FirebaseMessaging.onMessage.listen((msg) {
    debugPrint('FCM foreground: ${msg.notification?.title}');
  });

  // Tap-from-background routing to session details.
  FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    final type = msg.data['notification_type'];
    final sessionId = msg.data['session_id'];
    if (type == 'report_ready' && sessionId is String && sessionId.isNotEmpty) {
      // Routes via the global navigator; SessionStatusScreen will
      // pick up `done` immediately and run the cascade.
      navigatorKey.currentState?.pushNamed('/session', arguments: sessionId);
    }
  });

  runApp(const ProviderScope(child: SuperWizorApp()));
}
class SuperWizorApp extends ConsumerWidget {
  const SuperWizorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Superwizor AI',
      theme: EuphireTheme.themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('pl'), Locale('en')],
      locale: locale,
      home: const _AuthGate(),
      builder: (context, child) {
        return ActiveRecordingOverlay(child: child!);
      },
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentUserProvider, (previous, next) {
      if (next.value != null && (previous == null || previous.value == null)) {
        ref.read(analyticsCollectorProvider).track("app.session_started");
      }
    });

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.hasData ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
