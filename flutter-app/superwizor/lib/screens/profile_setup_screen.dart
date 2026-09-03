// ProfileSetupScreen — krok 2 rejestracji w aplikacji (docs/70 S1).
//
// JEDEN ekran, trzy pola i jeden checkbox. To nie jest skrócona wersja
// siedmiokrokowego kreatora z weba — to świadome minimum:
//
//   • Imię i nazwisko — trafiają na raporty, więc muszą być.
//   • Nurt (`default_modality_id`) — decyduje, którym promptem AI pisze
//     raport, więc bez niego pierwsza sesja nie ma jak się złożyć.
//   • Jedna zgoda (Regulamin + Polityka prywatności; DPA jest w regulaminie).
//
// Tytuł zawodowy, telefon, rozmiar praktyki i język raportów są OPCJONALNE i
// celowo ich tu nie ma — użytkownik uzupełni je później w istniejącym
// `profile_edit_sheet.dart` (progressive profiling). Każde dodatkowe pole na
// tym ekranie to kolejny procent osób, które nie dojdą do pierwszego nagrania.
//
// Prefill imienia i nazwiska pochodzi z dostawcy tożsamości. Przy Apple to
// jedyna okazja, żeby te dane zdobyć (E4b) — są już utrwalone w szkicu
// rejestracji, zanim ten ekran w ogóle się zbuduje.

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/modalities.dart';
import '../generated/identity/v1/identity.pb.dart' as identity_pb;
import '../l10n/app_localizations.dart';
import '../providers/current_user_provider.dart';
import '../providers/grpc_provider.dart';
import '../providers/email_verification_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/signup_draft_provider.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/modality_sheet.dart';
import 'legal_markdown_screen.dart';
import 'plan_picker_screen.dart';
import 'verify_email_screen.dart';

const _kFont = 'Montserrat';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.draft});

  final SignupDraft? draft;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  bool _consent = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  /// Kolejność źródeł: szkic rejestracji (jedyny, który ma dane z Apple) →
  /// `displayName` z Firebase (Google i e-mail+hasło) → puste pola.
  void _prefill() {
    final draft = widget.draft;
    var first = draft?.firstName ?? '';
    var last = draft?.lastName ?? '';
    if (first.isEmpty && last.isEmpty) {
      final display =
          fb_auth.FirebaseAuth.instance.currentUser?.displayName ?? '';
      final parts = display.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty && parts.first.isNotEmpty) {
        first = parts.first;
        last = parts.length > 1 ? parts.skip(1).join(' ') : '';
      }
    }
    _firstCtrl.text = first;
    _lastCtrl.text = last;
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  void _openLegal({required bool terms}) {
    final t = AppLocalizations.of(context);
    final english = ref.read(localeProvider).languageCode == 'en';
    final asset = terms
        ? (english ? 'assets/legal/terms_en.md' : 'assets/legal/terms.md')
        : (english
            ? 'assets/legal/privacy_policy_en.md'
            : 'assets/legal/privacy_policy.md');
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: 'LegalMarkdownScreen'),
      builder: (_) => LegalMarkdownScreen(
        assetPath: asset,
        title: terms ? t.settings_terms : t.settings_privacy,
      ),
    ));
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    final firstName = _firstCtrl.text.trim();
    final lastName = _lastCtrl.text.trim();
    if (firstName.isEmpty) {
      setState(() => _error = t.profile_setup_error_first_name);
      return;
    }
    if (lastName.isEmpty) {
      setState(() => _error = t.profile_setup_error_last_name);
      return;
    }
    if (!_consent) {
      setState(() => _error = t.profile_setup_error_consent);
      return;
    }

    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    // Nawigator zapamiętany PRZED awaitami: po `clear()` szkicu bramka
    // uwierzytelniania podmienia korzeń na HomeScreen i ten `State` znika,
    // a kolejne kroki (weryfikacja, paywall) muszą wejść na stos mimo to.
    final navigator = Navigator.of(context);
    final identity = ref.read(grpcClientsProvider).identity;
    final modalityCode = ref.read(selectedModalityProvider);

    try {
      // 1. Konto. Backend zakłada przy okazji organizację SOLO, subskrypcję
      //    MANUAL/TRIAL i licznik 10 tokenów — po naszej stronie nic więcej.
      final created = await identity.createUser(identity_pb.CreateUserRequest(
        firebaseUid: user.uid,
        email: user.email ?? '',
        role: identity_pb.UserRole.USER_ROLE_THERAPIST,
        firstName: firstName,
        lastName: lastName,
        uiLanguage: ref.read(localeProvider).languageCode,
        timezone: 'Europe/Warsaw',
        hasAcceptedTos: true,
      ));

      // 2. Nurt. Osobnym RPC, bo `CreateUserRequest` nie ma tego pola —
      //    najlepiej po utworzeniu konta, gdy jest już czyj profil zmieniać.
      try {
        await identity.updateProfile(identity_pb.UpdateProfileRequest(
          userId: created.id,
          defaultModalityId: modalityCode,
        ));
      } catch (e) {
        debugPrint('[signup] zapis nurtu nieudany: $e');
      }

      // 3. Ślad zgody do audytu. Musi iść PO `CreateUser`: RecordConsent
      //    przyjmuje `user_id` istniejącego wiersza i sam uwierzytelnia
      //    wywołującego, więc wcześniej nie ma jak go zawołać. Zgoda i tak
      //    jest już zapisana na koncie (`has_accepted_tos`), a to jest
      //    dowód z wersją dokumentu — brak wpisu nie może wywrócić
      //    rejestracji, którą backend właśnie domknął.
      try {
        await identity.recordConsent(identity_pb.RecordConsentRequest(
          userId: created.id,
          consentType: 'TOS',
          granted: true,
          consentVersion: kConsentDocumentVersion,
        ));
      } catch (e) {
        debugPrint('[signup] zapis zgody nieudany: $e');
      }

      await user.updateDisplayName('$firstName $lastName');

      // 4. Rejestracja domknięta — szkic już niepotrzebny, a odświeżony
      //    profil przełącza korzeń aplikacji na ekran główny.
      await ref.read(signupDraftProvider.notifier).clear(user.uid);
      ref.invalidate(currentUserProvider);
    } catch (e) {
      debugPrint('[signup] CreateUser nieudany: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = t.profile_setup_failed;
        });
      }
      return;
    }

    // 5. Krok 3 (tylko konta e-mail+hasło) i krok 4 — jako zwykłe trasy nad
    //    ekranem głównym. Oba są przeskakiwalne; żaden nie blokuje aplikacji.
    if (!ref.read(emailVerifiedProvider)) {
      await navigator.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'VerifyEmailScreen'),
        builder: (_) => const VerifyEmailScreen(),
      ));
    }
    await navigator.push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'PlanPickerScreen'),
      builder: (_) => const PlanPickerScreen(onboarding: true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final modalityCode = ref.watch(selectedModalityProvider);

    return Scaffold(
      backgroundColor: EuphireColors.nocturne,
      body: Container(
        decoration:
            const BoxDecoration(gradient: EuphireColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                28, 40, 28, 32 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.profile_setup_title,
                  style: const TextStyle(
                    fontFamily: _kFont,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.profile_setup_subtitle,
                  style: const TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 14,
                    height: 1.5,
                    color: EuphireColors.mist,
                  ),
                ),
                const SizedBox(height: 32),
                _Field(
                  controller: _firstCtrl,
                  label: t.profile_setup_first_name,
                  icon: Icons.person_outline,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _Field(
                  controller: _lastCtrl,
                  label: t.profile_setup_last_name,
                  icon: Icons.badge_outlined,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _ModalityField(
                  label: t.profile_setup_modality_label,
                  value: modalityDisplayName(context, modalityCode),
                  onTap: _saving
                      ? null
                      : () => showEuphireBottomSheet<void>(
                            context: context,
                            builder: (_) => const ModalitySheet(),
                          ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.profile_setup_modality_help,
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 12,
                    height: 1.5,
                    color: EuphireColors.mist.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 28),
                _ConsentRow(
                  value: _consent,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() {
                            _consent = v ?? false;
                            _error = null;
                          }),
                  onTerms: () => _openLegal(terms: true),
                  onPrivacy: () => _openLegal(terms: false),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontFamily: _kFont,
                      fontSize: 13,
                      color: Color(0xFFFFAAAA),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EuphireColors.ember,
                      foregroundColor: EuphireColors.obsidianBlack,
                      disabledBackgroundColor:
                          EuphireColors.ember.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  EuphireColors.obsidianBlack),
                            ),
                          )
                        : Text(
                            t.profile_setup_submit,
                            style: const TextStyle(
                              fontFamily: _kFont,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wersja dokumentów, na którą użytkownik się zgodził. Zmieniana ręcznie przy
/// każdej publikacji nowego regulaminu — bez tego wpis w audycie zgód nie
/// mówi, NA CO ktoś się zgodził.
const String kConsentDocumentVersion = '2026-09-03';

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        fontFamily: _kFont,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: EuphireColors.frostWhite,
      ),
      cursorColor: EuphireColors.ember,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: _kFont,
          fontSize: 15,
          color: EuphireColors.mist.withValues(alpha: 0.7),
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: _kFont,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: EuphireColors.ember,
        ),
        prefixIcon: Icon(icon, color: EuphireColors.mist, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EuphireColors.ember, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
    );
  }
}

class _ModalityField extends StatelessWidget {
  const _ModalityField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hub_outlined, color: EuphireColors.mist, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: _kFont,
                      fontSize: 11,
                      letterSpacing: 1,
                      color: EuphireColors.mist.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: _kFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: EuphireColors.frostWhite,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more, color: EuphireColors.mist, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.onTerms,
    required this.onPrivacy,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    const linkStyle = TextStyle(
      fontFamily: _kFont,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: EuphireColors.ember,
      decoration: TextDecoration.underline,
      decorationColor: EuphireColors.ember,
    );
    const plainStyle = TextStyle(
      fontFamily: _kFont,
      fontSize: 13,
      height: 1.5,
      color: EuphireColors.frostWhite,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: EuphireColors.ember,
            checkColor: EuphireColors.obsidianBlack,
            side: BorderSide(color: EuphireColors.mist.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(t.profile_setup_consent_prefix, style: plainStyle),
                GestureDetector(
                  onTap: onTerms,
                  child: Text(t.profile_setup_consent_terms, style: linkStyle),
                ),
                Text(t.profile_setup_consent_conjunction, style: plainStyle),
                GestureDetector(
                  onTap: onPrivacy,
                  child:
                      Text(t.profile_setup_consent_privacy, style: linkStyle),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
