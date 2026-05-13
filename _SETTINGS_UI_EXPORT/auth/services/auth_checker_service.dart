import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:labirynt_premium/src/core/router/app_router.dart';
import 'package:labirynt_premium/src/core/ui/eu_components.dart';
import 'package:labirynt_premium/src/features/auth/data/auth_repository.dart';
import 'package:labirynt_premium/src/features/auth/data/user_repository.dart';
import 'package:labirynt_premium/src/core/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:labirynt_premium/src/models/user_profile.dart';
import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';

/// Serwis sprawdzający logowania na wielu urządzeniach
/// (Multi-device login lock).
class AuthCheckerService {
  final Ref _ref;
  String? _localSessionToken;
  bool _isProcessingLogout = false;

  AuthCheckerService(this._ref) {
    _init();
  }

  void _init() {
    // 1. Obserwowanie stanu logowania (Firebase Auth)
    // Jeśli user się zaloguje/jest zalogowany przy starcie - generuj lokalny token i wyślij.
    _ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user == null) {
        // User wylogowany - wyczyść nasz token urządzenia
        if (previous?.valueOrNull?.uid != null) {
          final oldUid = previous!.value!.uid;
          SharedPreferences.getInstance().then(
            (prefs) => prefs.remove('localSessionToken_$oldUid'),
          );
        }
        _localSessionToken = null;
        _isProcessingLogout = false;
        return;
      }

      // Pojawił się user (zalogował się, lub aplikacja wstała już z cache)
      if (_localSessionToken == null) {
        _initializeLocalToken(user.uid);
      }
    });

    // 2. Nasłuchiwanie zmian na docu profilu w firestore (nasłuchuje na bieżąco)
    _ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (
      previous,
      next,
    ) {
      final profile = next.valueOrNull;
      if (profile == null) return;

      // Unikalny stan multi-login:
      // Posiadamy wygenerowany _localSessionToken na URZĄDZENIU X.
      // Nowe dane pokazują inny token, tzn. wygenerował go telefon Y.
      if (_localSessionToken != null &&
          profile.currentSessionToken != null &&
          profile.currentSessionToken != _localSessionToken &&
          !_isProcessingLogout) {
        // Zabezpieczenie przed pętlą (by nie wywoływał alertu do woli).
        _isProcessingLogout = true;

        debugPrint(
          'AuthCheckerService: Mismatched Session Token! Got ${profile.currentSessionToken}, expected $_localSessionToken',
        );
        _promptLogoutDueToMultiDevice();
      }
    });
  }

  Future<void> _initializeLocalToken(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('localSessionToken_$uid');

    if (storedToken != null) {
      _localSessionToken = storedToken;
      debugPrint(
        'AuthCheckerService: Loaded local session token $_localSessionToken',
      );
    } else {
      await _generateAndRegisterLocalToken(uid);
    }
  }

  Future<void> _generateAndRegisterLocalToken(String uid) async {
    const uuid = Uuid();
    _localSessionToken = uuid.v4();
    debugPrint(
      'AuthCheckerService: Generated local session token $_localSessionToken',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('localSessionToken_$uid', _localSessionToken!);

    try {
      await _ref
          .read(userRepositoryProvider)
          .updateSessionToken(uid, _localSessionToken!);
    } catch (e) {
      debugPrint(
        'AuthCheckerService: Failed to update session token on server: $e',
      );
    }
  }

  Future<void> _promptLogoutDueToMultiDevice() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    EuBottomSheet.show(
      context: context,
      variant: EuBottomSheetVariant.dark,
      isDismissible: false,
      enableDrag: false,
      icon: Icons.phonelink_erase_rounded,
      title: context.l10n.sessionConflictTitle,
      description: context.l10n.sessionConflictDescription,
      primaryButton: EuBottomSheetButton(
        label: context.l10n.sessionConflictPlayHere,
        onPressed: () async {
          Navigator.pop(context);
          // Odzyskaj token dla TEGO urządzenia, nadpisz w Firebase
          final user = _ref.read(authStateProvider).value;
          if (user != null) {
            // Najpierw generuj nowy token, potem odblokuj listener,
            // aby uniknąć wyścigu (race condition) z pustym tokenem.
            await _generateAndRegisterLocalToken(user.uid);
            _isProcessingLogout = false;

            if (context.mounted) {
              EuSnackbar.success(context, context.l10n.sessionConflictRestored);
            }
          }
        },
      ),
      secondaryButton: EuBottomSheetButton(
        label: context.l10n.sessionConflictLogout,
        onPressed: () async {
          Navigator.pop(context);
          _localSessionToken = null;

          try {
            await _ref.read(authRepositoryProvider).signOut();
          } catch (e) {
            debugPrint('AuthCheckerService: Logout error: $e');
          }
        },
      ),
    );
  }
}

/// Provider uruchamiający nasz serwis globalny przy starcie apki w `app.dart`.
final authCheckerServiceProvider = Provider<AuthCheckerService>((ref) {
  return AuthCheckerService(ref);
});
