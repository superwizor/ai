// menu_screen.dart — Ekran Ustawień wzorowany 1:1 na Labirynt Premium
//
// Layout:
//   [Duży italic tytuł "Ustawienia"] + subtitle RobotoMono
//   [TWOJE KONTO] → zgrupowana karta: Nazwa (wartość →), Email (→), Zdjęcie (avatar →)
//   [PREFERENCJE] → toggle Dźwięki, toggle Wibracje + Język aplikacji inline
//   [WSPARCIE] → kontakt email
//   [INFORMACJE PRAWNE] → regulamin, prywatność, DPA, licencje
//   [ZARZĄDZANIE KONTEM] → Wyloguj, Usuń konto
//   [Wersja] → stopka

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/locale_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/modality_sheet.dart';
import '../widgets/profile_edit_sheet.dart';
import '../widgets/report_preferences_section.dart';
import '../l10n/app_localizations.dart';
import 'delete_account_screen.dart';
import 'legal_markdown_screen.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  bool _uploadingAvatar = false;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    });
  }

  Future<void> _pickImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Zrób zdjęcie czy wybierz z galerii?
    final source = await showEuphireBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: 'Zdjęcie profilowe',
        body: 'Wybierz skąd chcesz dodać zdjęcie.',
        primary: EuphireSheetAction(
          label: 'Aparat',
          onPressed: () => Navigator.of(ctx).pop(ImageSource.camera),
        ),
        secondary: EuphireSheetAction(
          label: 'Galeria',
          onPressed: () => Navigator.of(ctx).pop(ImageSource.gallery),
        ),
      ),
    );
    
    if (source == null) return;

    // Dobre praktyki: kompresja, zmiana rozmiaru (zapobiega gigabajtowym HEIC/JPG)
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 512,
      maxHeight: 512,
      preferredCameraDevice: CameraDevice.front,
    );
    
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final ref = FirebaseStorage.instance.ref('users/${user.uid}/profile.jpg');
      
      // Metadane: poprawne ustawienie Content-Type
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );
      
      await ref.putFile(File(picked.path), metadata);
      final downloadUrl = await ref.getDownloadURL();
      
      await user.updatePhotoURL(downloadUrl);
      await user.reload();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zdjęcie profilowe zaktualizowane')),
        );
      }
    } catch (e) {
      debugPrint('Avatar upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wystąpił błąd podczas zapisu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LogoutBottomSheet(),
    );
    if (ok != true) return;
    await FirebaseAuth.instance.signOut();
    // ignore: use_build_context_synchronously
    if (context.mounted) Navigator.of(context).pop();
  }

  void _openLegal(String baseName, String title) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final path = isEn ? 'assets/legal/${baseName}_en.md' : 'assets/legal/$baseName.md';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LegalMarkdownScreen(assetPath: path, title: title),
    ));
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final locale = ref.watch(localeProvider);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, _) {
        final user = FirebaseAuth.instance.currentUser;
        final displayName = (user?.displayName?.isNotEmpty == true) ? user!.displayName! : 'Terapeuta';
        final email = user?.email ?? '';
        final photoUrl = user?.photoURL;

        return Scaffold(
          backgroundColor: EuphireColors.nocturne,
          body: Container(
            decoration: const BoxDecoration(gradient: EuphireColors.backgroundGradient),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Nagłówek (jak w Labiryncie) ─────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            t.settings_title,
                            style: theme.textTheme.displayLarge?.copyWith(
                              color: EuphireColors.ember,
                              fontFamily: 'Merriweather',
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w700,
                              fontSize: 36,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: EuphireColors.frostWhite.withValues(alpha: 0.5)),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Text(
                      t.settings_subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: EuphireColors.frostWhite.withValues(alpha: 0.6),
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  // ── Reszta przewijana ────────────────────────────────
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [

                        // ── TWOJE KONTO ──────────────────────────────────
                        _SectionLabel(t.settings_section_account),

                        // Wiersz "Zalogowano jako:"
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Row(
                            children: [
                              Icon(Icons.account_circle_outlined, size: 14,
                                  color: EuphireColors.frostWhite.withValues(alpha: 0.45)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  t.settings_logged_in_as(email),
                                  style: TextStyle(
                                    fontFamily: 'RobotoMono',
                                    fontSize: 11,
                                    color: EuphireColors.frostWhite.withValues(alpha: 0.45),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Karta konta
                        _SettingsCard(children: [
                          _SettingsRow(
                            icon: Icons.person_outline,
                            title: t.settings_name,
                            trailing: Expanded(
                              child: Text(
                                displayName,
                                textAlign: TextAlign.right,
                                style: TextStyle(fontFamily: 'Montserrat', fontSize: 14,
                                    color: EuphireColors.frostWhite.withValues(alpha: 0.4)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            onTap: () async {
                              await showEuphireBottomSheet(
                                context: context,
                                builder: (_) => const ProfileEditSheet(),
                              );
                              setState(() {}); // refresh after sheet closes
                            },
                          ),
                          _Divider(),
                          _SettingsRow(
                            icon: Icons.email_outlined,
                            title: t.settings_email,
                            trailing: Expanded(
                              child: Text(
                                email,
                                textAlign: TextAlign.right,
                                style: TextStyle(fontFamily: 'Montserrat', fontSize: 13,
                                    color: EuphireColors.frostWhite.withValues(alpha: 0.4)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            onTap: null, // email read-only (zmiana przez Firebase)
                          ),
                          _Divider(),
                          _SettingsRow(
                            icon: Icons.camera_alt_outlined,
                            title: t.settings_avatar,
                            trailing: _uploadingAvatar
                                ? const SizedBox(width: 32, height: 32,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: EuphireColors.ember))
                                : (photoUrl != null
                                    ? CircleAvatar(radius: 16, backgroundImage: NetworkImage(photoUrl))
                                    : Icon(Icons.add_a_photo_outlined, size: 20,
                                        color: EuphireColors.frostWhite.withValues(alpha: 0.35))),
                            onTap: _pickImage,
                          ),
                          _Divider(),
                          Consumer(
                            builder: (ctx, ref, _) {
                              final code = ref.watch(selectedModalityProvider);
                              final abbr = _modalityAbbr(context, code);
                              return _SettingsRow(
                                icon: Icons.psychology_outlined,
                                title: t.settings_modality,
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: EuphireColors.ember.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(abbr,
                                        style: const TextStyle(
                                          fontFamily: 'RobotoMono',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: EuphireColors.ember,
                                        )),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.chevron_right,
                                      color: EuphireColors.mist.withValues(alpha: 0.4), size: 18),
                                ]),
                                onTap: () => showEuphireBottomSheet(
                                  context: context,
                                  builder: (_) => const ModalitySheet(),
                                ),
                              );
                            },
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // ── PREFERENCJE ──────────────────────────────────
                        _SectionLabel(t.settings_section_preferences),
                        _SettingsCard(children: [
                          // Dźwięki
                          _ToggleRow(
                            icon: Icons.volume_up_outlined,
                            iconColor: EuphireColors.ember,
                            title: t.settings_sounds,
                            subtitle: settings.soundEnabled ? t.settings_sounds_on : t.settings_sounds_off,
                            value: settings.soundEnabled,
                            onChanged: settingsNotifier.toggleSound,
                          ),
                          _Divider(),
                          // Wibracje
                          _ToggleRow(
                            icon: Icons.vibration_outlined,
                            iconColor: EuphireColors.ember,
                            title: t.settings_haptics,
                            subtitle: settings.hapticsEnabled ? t.settings_haptics_on : t.settings_haptics_off,
                            value: settings.hapticsEnabled,
                            onChanged: settingsNotifier.toggleHaptics,
                          ),
                          _Divider(),
                          // Język aplikacji — inline selector
                          _LanguageRow(locale: locale),
                        ]),

                        const SizedBox(height: 24),

                        // ── PREFERENCJE RAPORTÓW ─────────────────────────
                        // Per-therapist report-style preferences (length,
                        // tone, sections, free-text guidance, etc.). Loads
                        // its own data; renders a self-contained card.
                        const ReportPreferencesSection(),

                        const SizedBox(height: 24),

                        // ── WSPARCIE ─────────────────────────────────────
                        _SectionLabel(t.settings_section_support),
                        _SettingsCard(children: [
                          _SettingsRow(
                            icon: Icons.mail_outline,
                            title: t.settings_contact,
                            subtitle: 'kontakt@superwizor.ai',
                            trailing: Icon(Icons.chevron_right,
                                color: EuphireColors.mist.withValues(alpha: 0.4), size: 18),
                            onTap: () => _openUrl('mailto:kontakt@superwizor.ai'),
                          ),
                          _Divider(),
                          _SettingsRow(
                            icon: Icons.open_in_new,
                            title: t.settings_waitlist,
                            subtitle: 'euphire.pl',
                            trailing: Icon(Icons.chevron_right,
                                color: EuphireColors.mist.withValues(alpha: 0.4), size: 18),
                            onTap: () => _openUrl('https://euphire.pl/superwizor-ai-lista-oczekujacych'),
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // ── INFORMACJE PRAWNE ────────────────────────────
                        _SectionLabel(t.settings_section_legal),
                        _SettingsCard(children: [
                          _SettingsRow(
                            icon: Icons.description_outlined,
                            title: t.settings_terms,
                            trailing: Icon(Icons.chevron_right,
                                color: EuphireColors.mist.withValues(alpha: 0.4), size: 18),
                            onTap: () => _openLegal('terms', t.settings_terms),
                          ),
                          _Divider(),
                          _SettingsRow(
                            icon: Icons.lock_outline,
                            title: t.settings_privacy,
                            trailing: Icon(Icons.chevron_right,
                                color: EuphireColors.mist.withValues(alpha: 0.4), size: 18),
                            onTap: () => _openLegal('privacy_policy', t.settings_privacy),
                          ),
                          _Divider(),
                          _SettingsRow(
                            icon: Icons.handshake_outlined,
                            title: t.settings_dpa,
                            trailing: Icon(Icons.chevron_right,
                                color: EuphireColors.mist.withValues(alpha: 0.4), size: 18),
                            onTap: () => _openLegal('dpa', t.settings_dpa),
                          ),
                          _Divider(),
                          _SettingsRow(
                            icon: Icons.info_outline,
                            title: t.settings_licenses,
                            trailing: Icon(Icons.chevron_right,
                                color: EuphireColors.mist.withValues(alpha: 0.4), size: 18),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const _LicensesScreen(),
                              ),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // ── ZARZĄDZANIE KONTEM ───────────────────────────
                        _SectionLabel(t.settings_section_account_management),
                        _SettingsCard(children: [
                          _SettingsRow(
                            icon: Icons.logout,
                            title: t.settings_logout,
                            trailing: Icon(Icons.chevron_right,
                                color: EuphireColors.mist.withValues(alpha: 0.4), size: 18),
                            onTap: _logout,
                          ),
                          _Divider(),
                          _SettingsRow(
                            icon: Icons.warning_amber_rounded,
                            iconColor: EuphireColors.magma,
                            title: t.settings_delete_account,
                            titleColor: EuphireColors.magma,
                            trailing: Icon(Icons.chevron_right,
                                color: EuphireColors.magma.withValues(alpha: 0.4), size: 18),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
                            ),
                          ),
                        ]),

                        // ── Stopka ───────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.only(top: 32, bottom: 8),
                          child: Center(
                            child: Text(
                              _appVersion != null ? 'Superwizor AI v$_appVersion' : 'Superwizor AI',
                              style: TextStyle(
                                fontFamily: 'RobotoMono', fontSize: 11,
                                color: EuphireColors.mist.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Helper: skróty modalności ───────────────────────────────

String _modalityAbbr(BuildContext context, String code) {
  final t = AppLocalizations.of(context);
  switch (code) {
    case 'UNIV': return t.modality_abbr_univ;
    case 'CBT':  return t.modality_abbr_cbt;
    case 'PSYCHO': return t.modality_abbr_psycho;
    case 'PPT':  return t.modality_abbr_ppt;
    case 'ST':   return t.modality_abbr_st;
    case 'SYS':  return t.modality_abbr_sys;
    case 'EFT':  return t.modality_abbr_eft;
    case 'COACH': return t.modality_abbr_coach;
    default:     return code;
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text,
          style: TextStyle(
            fontFamily: 'RobotoMono', fontSize: 11, fontWeight: FontWeight.w500,
            color: EuphireColors.frostWhite.withValues(alpha: 0.55),
            letterSpacing: 1.5,
          )),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1,
        color: Colors.white.withValues(alpha: 0.06), indent: 52);
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.iconColor,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fgColor = titleColor ?? EuphireColors.frostWhite;
    final icColor = iconColor ?? EuphireColors.mist;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: EuphireColors.ember.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: icColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: fgColor, fontWeight: FontWeight.w500, fontSize: 15)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                          fontFamily: 'Montserrat', fontSize: 12,
                          color: EuphireColors.mist.withValues(alpha: 0.65),
                        )),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? EuphireColors.ember, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: EuphireColors.frostWhite, fontWeight: FontWeight.w500, fontSize: 15)),
                Text(subtitle,
                    style: TextStyle(
                      fontFamily: 'Montserrat', fontSize: 12,
                      color: EuphireColors.mist.withValues(alpha: 0.65),
                    )),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: EuphireColors.ember,
            inactiveThumbColor: EuphireColors.mist,
            inactiveTrackColor: EuphireColors.mist.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

class _LanguageRow extends ConsumerWidget {
  final Locale locale;
  const _LanguageRow({required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPl = locale.languageCode == 'pl';
    final flag = isPl ? '🇵🇱' : '🇬🇧';
    final langName = isPl ? 'Polski (PL)' : 'English (UK)';
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).settings_language_app,
              style: theme.textTheme.titleMedium?.copyWith(
                  color: EuphireColors.frostWhite, fontWeight: FontWeight.w500, fontSize: 15)),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _showLanguagePicker(context, ref, locale.languageCode),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(langName,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: EuphireColors.frostWhite.withValues(alpha: 0.9))),
                  ),
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06), shape: BoxShape.circle),
                    child: const Icon(Icons.keyboard_arrow_down,
                        size: 18, color: EuphireColors.ember),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LanguagePickerSheet(currentCode: current),
    );
  }
}

class _LanguagePickerSheet extends ConsumerWidget {
  final String currentCode;
  const _LanguagePickerSheet({required this.currentCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final activeCode = currentLocale.languageCode;
    
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A2326),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(AppLocalizations.of(context).settings_choose_language,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'Merriweather', fontWeight: FontWeight.w700,
                      color: EuphireColors.frostWhite)),
            ),
            const Divider(color: Colors.white10, height: 1),
            _LangTile(flag: '🇵🇱', name: 'Polski', sub: 'Polish',
                selected: activeCode == 'pl',
                onTap: () async {
                  await ref.read(localeProvider.notifier).setLocale(const Locale('pl'));
                  await Future.delayed(const Duration(milliseconds: 200));
                  if (context.mounted) Navigator.of(context).pop();
                }),
            _LangTile(flag: '🇬🇧', name: 'English', sub: 'English (UK)',
                selected: activeCode == 'en',
                onTap: () async {
                  await ref.read(localeProvider.notifier).setLocale(const Locale('en'));
                  await Future.delayed(const Duration(milliseconds: 200));
                  if (context.mounted) Navigator.of(context).pop();
                }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String flag, name, sub;
  final bool selected;
  final VoidCallback onTap;
  const _LangTile({required this.flag, required this.name, required this.sub,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: TextStyle(
                      fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w600,
                      color: selected ? EuphireColors.frostWhite : EuphireColors.mist,
                    )),
                Text(sub,
                    style: const TextStyle(
                        fontFamily: 'RobotoMono', fontSize: 11, color: Colors.grey)),
              ]),
            ),
            if (selected) const Icon(Icons.check, color: EuphireColors.ember, size: 20),
          ],
        ),
      ),
    );
  }
}
// ─── Logout Bottom Sheet ────────────────────────────────────

class _LogoutBottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A2326),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),

              // Ikona
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EuphireColors.ember.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: EuphireColors.ember.withValues(alpha: 0.2),
                      blurRadius: 28, spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: EuphireColors.ember,
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                AppLocalizations.of(context).settings_logout_confirm_title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Merriweather',
                  fontStyle: FontStyle.italic,
                  color: EuphireColors.frostWhite,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context).settings_logout_confirm_body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: EuphireColors.mist,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Przycisk wyloguj
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EuphireColors.ember,
                    foregroundColor: EuphireColors.obsidianBlack,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    AppLocalizations.of(context).settings_logout_confirm_logout,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Anuluj
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  AppLocalizations.of(context).settings_logout_confirm_cancel,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: EuphireColors.mist.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Delete Account Row — Toggle → Bottom Sheet → Screen ─────

class _DeleteAccountRow extends StatefulWidget {
  @override
  State<_DeleteAccountRow> createState() => _DeleteAccountRowState();
}

class _DeleteAccountRowState extends State<_DeleteAccountRow> {
  bool _deleteToggle = false;

  Future<void> _onToggle(bool value) async {
    if (!value) {
      setState(() => _deleteToggle = false);
      return;
    }
    setState(() => _deleteToggle = true);

    // Po krótkim opóźnieniu pokaż bottom sheet z ostrzeżeniem
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final proceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DeleteWarningSheet(),
    );

    if (proceed == true && mounted) {
      setState(() => _deleteToggle = false);
      // Otwórz ekran usuwania z prawej strony
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
      );
    } else {
      if (mounted) setState(() => _deleteToggle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: EuphireColors.magma, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).settings_delete_account,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: EuphireColors.magma,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Trwałe i nieodwracalne usunięcie',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: EuphireColors.magma.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _deleteToggle,
            onChanged: _onToggle,
            activeThumbColor: Colors.white,
            activeTrackColor: EuphireColors.magma,
            inactiveThumbColor: EuphireColors.mist,
            inactiveTrackColor: EuphireColors.mist.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

// ─── Delete Warning Bottom Sheet ──────────────────────────────

class _DeleteWarningSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A2326),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 28),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EuphireColors.magma.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: EuphireColors.magma.withValues(alpha: 0.3),
                      blurRadius: 32, spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: EuphireColors.magma, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context).settings_delete_confirm_title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Merriweather',
                  fontStyle: FontStyle.italic,
                  color: EuphireColors.frostWhite,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context).settings_delete_confirm_body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: EuphireColors.mist,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EuphireColors.magma,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    AppLocalizations.of(context).settings_delete_confirm_proceed,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  AppLocalizations.of(context).settings_delete_confirm_cancel,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: EuphireColors.mist.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Licenses Screen ──────────────────────────────────────────

class _LicensesScreen extends StatefulWidget {
  const _LicensesScreen();

  @override
  State<_LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<_LicensesScreen> {
  List<LicenseEntry> _licenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LicenseRegistry.licenses.toList().then((list) {
      if (mounted) setState(() { _licenses = list; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Group by package name
    final Map<String, List<LicenseEntry>> byPkg = {};
    for (final e in _licenses) {
      for (final pkg in e.packages) {
        byPkg.putIfAbsent(pkg, () => []).add(e);
      }
    }
    final pkgs = byPkg.keys.toList()..sort();

    return Scaffold(
      backgroundColor: EuphireColors.nocturne,
      body: Container(
        decoration: const BoxDecoration(gradient: EuphireColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: EuphireColors.frostWhite, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text('Licencje',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontFamily: 'Merriweather',
                            fontStyle: FontStyle.italic,
                            color: EuphireColors.ember,
                          )),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator(color: EuphireColors.ember)))
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: pkgs.length,
                    itemBuilder: (ctx, i) {
                      final pkg = pkgs[i];
                      final entries = byPkg[pkg]!;
                      return _LicenseTile(pkg: pkg, entries: entries);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LicenseTile extends StatefulWidget {
  final String pkg;
  final List<LicenseEntry> entries;
  const _LicenseTile({required this.pkg, required this.entries});

  @override
  State<_LicenseTile> createState() => _LicenseTileState();
}

class _LicenseTileState extends State<_LicenseTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: EuphireColors.ember.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.code, color: EuphireColors.ember, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.pkg,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                              color: EuphireColors.frostWhite,
                            )),
                        Text(
                          '${widget.entries.length} licencj${widget.entries.length == 1 ? 'a' : widget.entries.length < 5 ? 'e' : 'i'}',
                          style: TextStyle(
                            fontFamily: 'RobotoMono', fontSize: 11,
                            color: EuphireColors.mist.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: EuphireColors.mist.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: [
                  Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                  const SizedBox(height: 12),
                  for (final e in widget.entries)
                    ...e.paragraphs.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(p.text,
                          style: TextStyle(
                            fontFamily: 'RobotoMono', fontSize: 10,
                            color: EuphireColors.mist.withValues(alpha: 0.55),
                            height: 1.5,
                          )),
                    )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
