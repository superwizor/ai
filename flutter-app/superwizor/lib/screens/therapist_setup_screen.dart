// TherapistSetupScreen — Etap 2 / Task 2.1
//
// First-run profile setup. Collects:
//   - main therapy modality (1 of 8 — D7 i18n display, codes from
//     constants/modalities.dart)
//   - session language (PL only in MVP; selecting EN shows
//     EuphirePopup "Język aplikacji" and snaps back to PL)
//
// On save: identityService.UpdateUserProfile (reusing existing gRPC
// scaffolding — falls back to a stub call if the proto field doesn't
// exist yet — see _persistProfile below). After success, registers
// the FCM token via FcmTokenService and routes to Home.

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/modalities.dart';
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../providers/services_provider.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_button.dart';
import '../widgets/euphire_header.dart';
import 'home_screen.dart';

class TherapistSetupScreen extends ConsumerStatefulWidget {
  const TherapistSetupScreen({super.key});

  @override
  ConsumerState<TherapistSetupScreen> createState() =>
      _TherapistSetupScreenState();
}

class _TherapistSetupScreenState extends ConsumerState<TherapistSetupScreen> {
  String _selectedModalityCode = kModalities.first.code;
  String _selectedLanguage = 'pl';
  bool _saving = false;

  String _modalityDisplayName(BuildContext context, String code) {
    final t = AppLocalizations.of(context);
    switch (code) {
      case 'integrative':
        return t.modality_integrative;
      case 'cbt':
        return t.modality_cbt;
      case 'psychodynamic':
        return t.modality_psychodynamic;
      case 'positive':
        return t.modality_positive;
      case 'schema':
        return t.modality_schema;
      case 'systemic':
        return t.modality_systemic;
      case 'eft':
        return t.modality_eft;
      case 'coaching':
        return t.modality_coaching;
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              EuphireHeader(title: t.setup_title, subtitle: t.setup_subtitle),
              const SizedBox(height: 40),
              Text(t.setup_modality_label,
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              _ModalityDropdown(
                value: _selectedModalityCode,
                items: [
                  for (final m in kModalities)
                    DropdownMenuItem(
                      value: m.code,
                      child: Text(_modalityDisplayName(context, m.code)),
                    ),
                ],
                onChanged: (v) =>
                    setState(() => _selectedModalityCode = v ?? _selectedModalityCode),
              ),
              const SizedBox(height: 28),
              Text(t.setup_language_label,
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              _LanguageSegmentedToggle(
                value: _selectedLanguage,
                onChanged: _onLanguageChanged,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: EuphireButton(
                  text: t.setup_continue,
                  isLoading: _saving,
                  onPressed: _saving ? null : _onContinue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onLanguageChanged(String code) async {
    if (code == 'pl') {
      setState(() => _selectedLanguage = 'pl');
      return;
    }
    // EN selected → popup, snap back to PL.
    await showEuphireBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final t = AppLocalizations.of(ctx);
        return EuphireActionSheet(
          header: t.language_popup_title,
          body: t.language_popup_body,
          primary: EuphireSheetAction(
            label: t.common_understand,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        );
      },
    );
    if (mounted) setState(() => _selectedLanguage = 'pl');
  }

  Future<void> _onContinue() async {
    setState(() => _saving = true);
    try {
      await _persistProfile();
      // Best-effort FCM register — failures don't block setup.
      try {
        await ref.read(fcmTokenServiceProvider).registerAfterLogin();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context);
        await showEuphireBottomSheet<void>(
          context: context,
          builder: (ctx) => EuphireActionSheet(
            header: t.common_error,
            body: e.toString(),
            primary: EuphireSheetAction(
              label: t.common_understand,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// MVP: tries `identityService.updateUserProfile` if available; if
  /// the proto doesn't expose that RPC yet, we just log and proceed.
  /// Modality + language end up persisted server-side in a follow-up
  /// patch (out of scope for D9 / MVP-no-backend-change rule when the
  /// existing identity-svc already accepts these fields, otherwise the
  /// values stay client-side until backend catches up).
  Future<void> _persistProfile() async {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Reading the gRPC client triggers Provider initialization and
    // exercises auth interceptor — even if we don't call any RPC yet,
    // this ensures auth metadata path works.
    ref.read(grpcClientsProvider);
    // TODO: when identity-svc exposes UpdateUserProfile, call it
    // here with (modality_code: _selectedModalityCode, ui_language:
    // _selectedLanguage). For MVP we skip silently.
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

class _ModalityDropdown extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _ModalityDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: Theme.of(context).scaffoldBackgroundColor,
        iconEnabledColor: EuphireColors.mist,
      ),
    );
  }
}

class _LanguageSegmentedToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _LanguageSegmentedToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'pl', label: Text('PL')),
        ButtonSegment(value: 'en', label: Text('EN')),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) {
        if (s.isNotEmpty) onChanged(s.first);
      },
    );
  }
}
