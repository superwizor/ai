import 'dart:async';
import 'dart:io';

import 'analytics/analytics_collector.dart';
import 'analytics/screen_view_observer.dart';
import 'providers/current_user_provider.dart';
import 'providers/patient_notes_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/connectivity_provider.dart';
import 'services/live_activity_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'auth/sso_handler.dart'
    if (dart.library.html) 'auth/sso_handler_web.dart';
import 'auth/app_lock_controller.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'client/app_version.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'client/client_home_screen.dart';
import 'generated/identity/v1/identity.pbenum.dart' as identity_enum;
import 'providers/billing_surface_provider.dart';
import 'providers/email_verification_provider.dart';
import 'providers/onboarding_paywall_provider.dart';
import 'providers/signup_draft_provider.dart';
import 'screens/account_not_found_screen.dart';
import 'screens/deactivated_account_screen.dart';
import 'screens/plan_picker_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/verify_email_screen.dart';
import 'utils/account_status.dart';
import 'utils/auth_gate.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/login_screen.dart';
import 'screens/session_status_screen.dart';
import 'providers/services_provider.dart';
import 'services/inbox_refresh_listener.dart';
import 'theme/euphire_theme.dart';
import 'uploads/upload_queue_provider.dart';
import 'widgets/debug_test_overlay.dart';
import 'widgets/minimized_recording_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/debug_flags.dart';

/// Top-level handler for FCM messages while the app is in the
/// background or terminated. Must be a top-level function (or static)
/// per Firebase docs — Dart spawns a new isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate: do minimal work; UI nav happens via
  // onMessageOpenedApp when user taps the notification.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FCM bg msg: ${message.messageId}');

  // NOTE: Live Activity updates are handled NATIVELY in AppDelegate.swift
  // (application(_:didReceiveRemoteNotification:fetchCompletionHandler:)).
  // We do NOT call MethodChannel from here because this background isolate
  // runs on a separate FlutterEngine where our channel is not registered.
}

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Wersja aplikacji rozstrzygana raz, przed runApp — kolejka wgrywania
  // czyta ją synchronicznie, także w oknie wykonania w tle.
  await initAppVersion();

  // Raportowanie awarii. Do 13.08.2026 aplikacja nie miała ŻADNEGO: ani
  // FlutterError.onError, ani runZonedGuarded, ani obsługi
  // PlatformDispatcher. Awaria u terapeutki w trakcie sesji była dla nas
  // całkowicie niewidoczna.
  //
  // ŚWIADOMIE NIE ustawiamy setUserIdentifier. To aplikacja z danymi o
  // zdrowiu; identyfikator użytkownika po stronie Google to osobna
  // decyzja o przetwarzaniu, nie domyślny wybór biblioteki. Klucze niżej
  // są nieosobowe. Uwaga przy dopisywaniu kolejnych: treść komunikatów
  // błędów trafia do Crashlytics w całości, więc nie wolno wkładać w nie
  // danych pacjenta.
  if (!kIsWeb) {
    // Crashlytics nie wspiera weba — wywołanie tam by rzuciło.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
    await FirebaseCrashlytics.instance.setCustomKey('app_version', appVersion);
    await FirebaseCrashlytics.instance.setCustomKey(
      'platform',
      defaultTargetPlatform.name,
    );

    final poprzedniaObsluga = FlutterError.onError;
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      // Nie zjadamy istniejącej obsługi — bez tego konsola w trybie
      // debug przestałaby pokazywać błędy układu.
      poprzedniaObsluga?.call(details);
    };

    // Błędy spoza drzewa widgetów (asynchroniczne, z isolate'ów).
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

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
  // Client-panel prefs (docs/39 PR13: light/dark choice). Opened here so
  // the ClientDarkNotifier can read it synchronously.
  await Hive.openBox('client_prefs');

  // App-lifecycle observer that nudges the upload queue runner when
  // the app returns to the foreground. The runner itself is created
  // lazily by uploadQueueRunnerProvider after the user signs in.
  WidgetsBinding.instance.addObserver(UploadQueueLifecycleObserver());

  // Live Activity cleanup on app resume: when the user returns to the
  // app, dismiss any lingering Dynamic Island / Lock Screen widget.
  // Covers: (1) report finished while app was killed, (2) offline
  // scenario where FCM push arrived late, (3) user just wants to use
  // the app and the widget is redundant. On Android this is a no-op.
  if (!kIsWeb && Platform.isIOS) {
    WidgetsBinding.instance.addObserver(_LiveActivityResumeObserver());
  }

  // Firestore offline persistence — keeps last seen session_states
  // for offline-first reads.
  cf.FirebaseFirestore.instance.settings = const cf.Settings(
    persistenceEnabled: true,
    cacheSizeBytes: cf.Settings.CACHE_SIZE_UNLIMITED,
  );

  // Date formatting (Polish month names in PDF + UI).
  await initializeDateFormatting('pl_PL');

  // Load debug reminder interval seconds if present
  try {
    final prefs = await SharedPreferences.getInstance();
    DebugFlags.debugReminderIntervalSeconds =
        prefs.getInt('debug_reminder_interval_seconds') ?? 0;
  } catch (e) {
    debugPrint('Error loading debug reminder seconds: $e');
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // A single root container shared by the widget tree AND the
  // background FCM handlers, so a push can invalidate providers even
  // though it fires outside any widget's `ref` (docs/39 PR11).
  final container = ProviderContainer();

  // Foreground push. docs/39 PR11: a client_note_received push refreshes
  // the therapist's cached notes for that kartoteka so a sent note shows
  // up live instead of only after a manual reopen.
  FirebaseMessaging.onMessage.listen((msg) {
    debugPrint('FCM foreground: ${msg.notification?.title}');
    if (msg.data['notification_type'] == 'client_note_received') {
      final pfId = msg.data['patient_file_id'];
      if (pfId is String && pfId.isNotEmpty) {
        container
            .read(patientNotesMapProvider.notifier)
            .refreshNotes(pfId)
            .catchError((_) {});
      }
    }
    // Report ready while app is in foreground.
    // If the user is ALREADY on SessionStatusScreen for this exact session,
    // we do nothing (the screen has its own Firestore listener and cascade).
    // If they are anywhere else in the app (e.g. MenuScreen, HomeScreen),
    // we automatically route them to the success screen so they don't
    // miss the satisfying cascade.
    if (msg.data['notification_type'] == 'report_ready') {
      if (!kIsWeb && Platform.isIOS) LiveActivityService.markReportReady();
      final sessionId = msg.data['session_id'];
      if (sessionId is String && sessionId.isNotEmpty) {
        if (SessionStatusScreen.currentlyViewedSessionId != sessionId) {
          if (!kIsWeb && Platform.isIOS) LiveActivityService.stopFromBackground();
          // Do 2026-08-24 aplikacja NAWIGOWAŁA tu sama (pushNamed) —
          // wyrywało to użytkownika z dowolnego ekranu, a przy dwóch
          // sesjach w locie mnożyło ekrany statusu i rozstrajało stos
          // (raport bez drogi powrotu). Raport-gotowy w foregroundzie
          // to informacja, nie rozkaz: snackbar z akcją, nawigacja
          // wyłącznie z ręki użytkownika.
          final ctx = navigatorKey.currentContext;
          final t =
              (ctx != null && ctx.mounted) ? AppLocalizations.of(ctx) : null;
          scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            content: Text(t?.report_ready_snackbar ?? 'Raport jest gotowy.'),
            action: SnackBarAction(
              label: t?.report_ready_snackbar_open ?? 'Otwórz',
              onPressed: () => navigatorKey.currentState
                  ?.pushNamed('/session', arguments: sessionId),
            ),
          ));
        }
      }
    }
  });

  // Tap-from-background routing.
  FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    final type = msg.data['notification_type'];
    final sessionId = msg.data['session_id'];
    if (type == 'report_ready' && sessionId is String && sessionId.isNotEmpty) {
      // User tapped the push → they're about to see the report.
      // Dismiss the Live Activity widget so it doesn't linger.
      if (!kIsWeb && Platform.isIOS) LiveActivityService.stopFromBackground();
      // Routes via the global navigator; SessionStatusScreen will
      // pick up `done` immediately and run the cascade.
      navigatorKey.currentState?.pushNamed('/session', arguments: sessionId);
    } else if (type == 'client_note_received') {
      // No named client route in this app; refreshing the cached notes
      // is enough — the note is there when the therapist opens the
      // kartoteka.
      final pfId = msg.data['patient_file_id'];
      if (pfId is String && pfId.isNotEmpty) {
        container
            .read(patientNotesMapProvider.notifier)
            .refreshNotes(pfId)
            .catchError((_) {});
      }
    }
  });

  // docs/39 PR12: live client-panel refresh over the existing Firestore
  // inbox — works foreground on iOS AND web, where FCM does not. Follows
  // the signed-in user via authStateChanges; harmless before login.
  InboxRefreshListener(container).start();

  // Utrzymanie rejestracji tokenu FCM. Do 22.08.2026 rejestracja odpalała
  // się wyłącznie z ekranu konfiguracji terapeuty, czyli raz w życiu
  // konta — reinstalacja, nowe urządzenie i rotacja tokenu (co ~30 dni)
  // kończyły się trwałą ciszą bez śladu w UI. Tak samo jak wyżej: śledzi
  // zalogowanego użytkownika, nieszkodliwe przed logowaniem, NIE pyta o
  // uprawnienia (o zgodę prosi ekran konfiguracji).
  container.read(fcmTokenServiceProvider).start();

  // Zakupy sklepowe: nasłuch `purchaseStream` musi żyć OD STARTU aplikacji,
  // a nie od wejścia na paywall (docs/70 E28). Transakcja potwierdzona przez
  // sklep tuż przed crashem albo utratą sieci wraca właśnie tędy — i dopiero
  // po jej weryfikacji na serwerze wolno ją domknąć. Bez tego użytkownik
  // zostaje z obciążoną kartą i bez planu. Nieszkodliwe przed zalogowaniem i
  // na platformach bez sklepu (usługa sama się wtedy wyłącza).
  unawaited(container.read(storePurchaseServiceProvider).start());

  // Listen to connectivity restoration and refresh patient data
  setupConnectivityListener(container);

  runApp(UncontrolledProviderScope(
    container: container,
    child: const SuperWizorApp(),
  ));
}

class SuperWizorApp extends ConsumerWidget {
  const SuperWizorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      // Pełne pokrycie ekranów zamiast trzech ręcznych wywołań.
      // Zdarzenia idą do NASZEGO kolektora — uzasadnienie w
      // analytics/screen_view_observer.dart.
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorObservers: [
        ScreenViewObserver((nazwa) {
          ref
              .read(analyticsCollectorProvider)
              .track('screen.viewed', properties: {'screen_name': nazwa});
        }),
      ],
      // ignore: avoid_hardcoded_strings_in_widgets
      title: 'Superwizor AI',
      theme: EuphireTheme.themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('pl'), Locale('en')],
      locale: locale,
      home: const _AuthGate(),
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri == null) return null;

        // Handle /session route (used by FCM push handler)
        if (settings.name == '/session') {
          final sessionId = settings.arguments as String?;
          if (sessionId != null) {
            return MaterialPageRoute(
              builder: (_) => SessionStatusScreen(sessionId: sessionId),
              // Nazwa spójna z resztą (obserwator raportuje po nazwie),
              // z zachowaniem `arguments` z głębokiego linku.
              settings: RouteSettings(
                name: 'SessionStatusScreen',
                arguments: settings.arguments,
              ),
            );
          }
        }

        // Handle /report/:id or /report?id=... (from widget deep link)
        if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'report') {
          final sessionId = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
          if (sessionId != null && sessionId.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => SessionStatusScreen(sessionId: sessionId),
              // Nazwa spójna z resztą (obserwator raportuje po nazwie),
              // z zachowaniem `arguments` z głębokiego linku.
              settings: RouteSettings(
                name: 'SessionStatusScreen',
                arguments: settings.arguments,
              ),
            );
          }
        }

        return null;
      },
      builder: (context, child) {
        return DebugTestOverlay(child: ActiveRecordingOverlay(child: child!));
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

    // Deactivation gate (docs/38 §4): a reversibly-deactivated account
    // (users.is_active = false, toggled by the org's manager) gets a
    // full-screen block instead of the app. Detected from the resolved
    // User row; every backend RPC would fail with PermissionDenied
    // "ACCOUNT_DEACTIVATED" anyway — this makes the state legible.
    final deactivated = ref.watch(currentUserProvider).maybeWhen(
          data: (u) => u != null && !u.isActive,
          // Mid-session deactivation: the cached profile predates the
          // toggle, but any refetch (or any gated RPC) now fails with
          // the ACCOUNT_DEACTIVATED marker — treat that the same.
          // ACCOUNT_DELETED (admin removed the users row) gets the
          // same full-screen block instead of a raw gRPC dump.
          error: (e, _) => isAccountBlockedError(e),
          orElse: () => false,
        );
    // Deleted-vs-deactivated only differ in the block screen's copy.
    final deleted = ref.watch(currentUserProvider).maybeWhen(
          error: (e, _) => isAccountDeletedError(e),
          orElse: () => false,
        );

    // Firebase session without an identity row (never registered, or
    // hard-deleted by an admin): explicit dead-end screen — the app
    // must NOT mint an account (the removed auto-register used to
    // create ghost THERAPIST rows for any unknown Google sign-in).
    final notRegistered = ref.watch(currentUserProvider).maybeWhen(
          error: (e, _) => e is AccountNotRegisteredException,
          orElse: () => false,
        );

    // Client panel routing (docs/39): PATIENT accounts get the
    // client-only surface — no recording, kartoteki, or billing.
    final isClient = ref.watch(currentUserProvider).whenOrNull(
              data: (u) =>
                  u != null &&
                  u.role == identity_enum.UserRole.USER_ROLE_PATIENT,
            ) ??
        false;

    // Czy w ogóle WIEMY, kim jest ten użytkownik po naszej stronie.
    //
    // `currentUserProvider` przechodzi przez trzy stany, a bramka do
    // 04.09.2026 rozróżniała tylko dwa. Na zimnym starcie `authStateChanges`
    // emituje najpierw `null` (sesja jeszcze się nie odtworzyła), więc
    // provider kończy jako `AsyncData(null)` i dopiero potem rusza z
    // zapytaniem o prawdziwego użytkownika. W tym oknie `notRegistered`,
    // `deactivated` i `isClient` są fałszem — czyli bramka wpuszczała na
    // ekran główny KOGOŚ, o kim nie wiedziała jeszcze nic. Świeżo
    // zarejestrowany terapeuta widział wtedy „Witaj, z kim dzisiaj
    // pracujemy?" z kręcącym się kółkiem przez kilkanaście sekund, zanim
    // pojawił się ekran uzupełnienia profilu (zgłoszone z produkcji na
    // buildzie 1.0.9+59).
    final userAsync = ref.watch(currentUserProvider);
    final accountUnresolved = userAsync.value == null && !userAsync.hasError;

    // Furtka offline (poprawka z 2026-07-23): kto zalogował się kiedyś na
    // tym urządzeniu, ma zapisane mapowanie firebaseUid → users.id i wchodzi
    // do aplikacji od razu, z pamięci podręcznej — bez czekania na sieć,
    // której w trybie samolotowym nie ma. Blokada niżej dotyczy więc
    // wyłącznie pierwszego logowania na urządzeniu, czyli dokładnie tego
    // przypadku, w którym ekran główny i tak nie miałby co pokazać.
    final knownBackendUserId = ref.watch(backendUserIdProvider).value;

    // Paywall powitalny (docs/70 S1 krok 4) — patrz komentarz w
    // `onboarding_paywall_provider.dart`: to stan, nie `Navigator.push`.
    final showOnboardingPaywall = ref.watch(onboardingPaywallProvider);

    final authState = ref.watch(firebaseUserProvider);

    // Sesja Firebase bez wiersza w `users` ma dwa różne znaczenia. Gdy
    // istnieje szkic rejestracji, użytkownik jest w środku naszego własnego
    // przepływu „Załóż konto" (docs/70 S1) i należy mu się ekran profilu.
    // Bez szkicu to cudza tożsamość bez konta — ślepy zaułek z docs/39,
    // którego świadomie NIE leczymy cichym zakładaniem konta.
    final signupDraft = ref.watch(signupDraftProvider);

    // Potwierdzony adres e-mail jest warunkiem wejscia — przed profilem,
    // przed kartotekami, przed czymkolwiek (decyzja 2026-09-03, docs/70
    // D12). Dotyczy w praktyce tylko kont e-mail+haslo: Apple i Google
    // oddaja adres juz zweryfikowany. Blokada stoi TUTAJ, w korzeniu, a nie
    // na pojedynczych ekranach, zeby restart aplikacji ani zaden skrot
    // nawigacyjny nie omijaly jej. Dodatkowy skutek: `CreateUser` idzie
    // dopiero po potwierdzeniu, wiec pomylony albo zmyslony adres nie
    // zakłada konta, organizacji ani trialu.
    final emailVerified = ref.watch(emailVerifiedProvider);

    return authState.when(
      data: (user) {
        // Kolejność ekranów mieszka w `utils/auth_gate.dart` — czysta
        // funkcja, żeby dało się ją przetestować bez `fb_auth.User`,
        // którego nie da się sfałszować.
        switch (authGateDestination(
          signedIn: user != null,
          emailVerified: emailVerified,
          accountUnresolved: accountUnresolved,
          hasKnownBackendUserId: knownBackendUserId != null,
          notRegistered: notRegistered,
          hasSignupDraft: signupDraft != null,
          deactivated: deactivated,
          isClient: isClient,
          showOnboardingPaywall: showOnboardingPaywall,
        )) {
          case AuthGateDestination.login:
            return const LoginScreen();
          case AuthGateDestination.verifyEmail:
            return const VerifyEmailScreen();
          case AuthGateDestination.resolving:
            return const _ResolvingAccountScreen();
          case AuthGateDestination.profileSetup:
            return ProfileSetupScreen(draft: signupDraft);
          case AuthGateDestination.accountNotFound:
            return const AccountNotFoundScreen();
          case AuthGateDestination.deactivated:
            return DeactivatedAccountScreen(deleted: deleted);
          case AuthGateDestination.clientHome:
            return const ClientHomeScreen();
          case AuthGateDestination.onboardingPaywall:
            return const PlanPickerScreen(onboarding: true);
          case AuthGateDestination.app:
            return const _LockGate();
        }
      },
      // Pierwsza klatka zimnego startu — ten sam ekran, co przy
      // rozstrzyganiu konta. Gołe kółko na białym tle błyskało jasnym
      // prostokątem przed ciemnym motywem aplikacji.
      loading: () => const _ResolvingAccountScreen(),
      error: (e, st) => Scaffold(
        body: Center(child: Text('Auth error: $e')),
      ),
    );
  }
}

/// Ekran na czas rozstrzygania, kim jest zalogowany użytkownik.
///
/// Świadomie w barwach aplikacji, a nie gołe kółko na białym tle: to jest
/// pierwsza rzecz, jaką widzi ktoś, kto właśnie potwierdził adres e-mail, i
/// ma wyglądać jak ładowanie, a nie jak pusty ekran główny.
class _ResolvingAccountScreen extends StatelessWidget {
  const _ResolvingAccountScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: EuphireColors.nocturne,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: EuphireColors.backgroundGradient),
        child: Center(
          child: CircularProgressIndicator(color: EuphireColors.ember),
        ),
      ),
    );
  }
}

/// Sits between a signed-in session and the app: while [appLockProvider] is
/// locked (cold launch / inactivity), the biometric LockScreen is shown
/// instead of HomeScreen. No-op on web/desktop (the provider stays unlocked).
class _LockGate extends ConsumerWidget {
  const _LockGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mid-session relock (60 s+ backgrounded — incl. iOS auto-locking the
    // screen while the therapist reads without touching) can engage while
    // the user is deep in the navigator stack (kartoteka, transcript…).
    // This gate only swaps the ROOT route, so without the collapse below
    // the LockScreen mounts INVISIBLY under the pushed route: its
    // auto-prompt fires "out of nowhere" over patient data (or gets
    // swallowed by the resume race), the PHI stays visible despite the
    // locked state, and the lock UI only surfaces when the user happens
    // to pop back — reported 2026-07-19 as "Face ID przy przejściu
    // kartoteka → lista, bez wygaszania ekranu". Collapsing to root the
    // moment the lock engages hides PHI instantly and guarantees the
    // prompt only ever fires with the LockScreen actually on screen.
    ref.listen<bool>(appLockProvider, (prev, next) {
      if (next && !(prev ?? false)) {
        navigatorKey.currentState?.popUntil((r) => r.isFirst);
      }
    });
    final locked = ref.watch(appLockProvider);
    return locked ? const LockScreen() : const HomeScreen();
  }
}

// ── Live Activity app-resume cleanup ───────────────────────────────

/// When the user returns to the app (foreground), dismiss any lingering
/// Live Activity. The widget is only useful when the app is NOT open;
/// once the user is back, the in-app UI takes over.
///
/// This is the safety net for:
///   • FCM push arrived in background → widget showed "Raport gotowy" →
///     user now opens the app → widget dismissed.
///   • Offline scenario: widget was stale → user comes online and opens
///     the app → widget dismissed.
///   • Any race condition where SessionStatusScreen was disposed before
///     calling stop() on the Live Activity.
class _LiveActivityResumeObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndDismiss();
    }
  }

  Future<void> _checkAndDismiss() async {
    final shouldDismiss = await LiveActivityService.shouldDismissOnResume();
    if (shouldDismiss) {
      await LiveActivityService.stopFromBackground();
    }
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final uri = routeInformation.uri;
    if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'report') {
      final sessionId = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
      if (sessionId != null && sessionId.isNotEmpty) {
        if (SessionStatusScreen.currentlyViewedSessionId != sessionId) {
          if (!kIsWeb && Platform.isIOS) LiveActivityService.stopFromBackground();
          navigatorKey.currentState?.pushNamed('/session', arguments: sessionId);
        }
        return true;
      }
    }
    return super.didPushRouteInformation(routeInformation);
  }
}
