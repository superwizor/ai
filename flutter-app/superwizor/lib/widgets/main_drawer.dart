import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/euphire_theme.dart';
import '../screens/legal_markdown_screen.dart';
import 'euphire_bottom_sheet.dart';
import 'hard_delete_sheet.dart';
import 'language_sheet.dart';
import 'modality_sheet.dart';
import 'profile_edit_sheet.dart';
import '../l10n/app_localizations.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: EuphireColors.deepGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Profile Section
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: EuphireColors.glassDecoration(
                    surfaceOpacity: 0.05,
                    borderOpacity: 0.1,
                    borderRadius: 24,
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: EuphireColors.emberGlow,
                        ),
                        child: const CircleAvatar(
                          radius: 28,
                          backgroundColor: EuphireColors.ember,
                          child: Icon(Icons.person, size: 28, color: EuphireColors.obsidianBlack),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? t.drawer_fallback_name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: EuphireColors.frostWhite,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(color: EuphireColors.mist),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Section: USTAWIENIA (RobotoMono Label)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(t.drawer_settings_header, style: theme.textTheme.labelMedium),
              ),
              _DrawerTile(
                icon: Icons.person_outline,
                title: AppLocalizations.of(context).drawer_profile,
                onTap: () {
                  Navigator.of(context).pop(); // close drawer
                  showEuphireBottomSheet<void>(
                    context: context,
                    builder: (_) => const ProfileEditSheet(),
                  );
                },
              ),
              _DrawerTile(
                icon: Icons.language,
                title: AppLocalizations.of(context).drawer_language,
                onTap: () {
                  Navigator.of(context).pop();
                  showEuphireBottomSheet<void>(
                    context: context,
                    builder: (_) => const LanguageSheet(),
                  );
                },
              ),
              _DrawerTile(
                icon: Icons.psychology_outlined,
                title: AppLocalizations.of(context).drawer_modalities,
                onTap: () {
                  Navigator.of(context).pop();
                  showEuphireBottomSheet<void>(
                    context: context,
                    builder: (_) => const ModalitySheet(),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              // Section: DOKUMENTY PRAWNE
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(t.drawer_legal_header, style: theme.textTheme.labelMedium),
              ),
              _DrawerTile(
                icon: Icons.description_outlined,
                title: AppLocalizations.of(context).settings_terms,
                onTap: () {
                  final lang = Localizations.localeOf(context).languageCode;
                  Navigator.of(context).push(MaterialPageRoute(
                    settings: const RouteSettings(name: 'LegalMarkdownScreen'),
                    builder: (_) => LegalMarkdownScreen(assetPath: lang == 'en' ? 'assets/legal/terms_en.md' : 'assets/legal/terms.md', title: AppLocalizations.of(context).settings_terms),
                  ));
                },
              ),
              _DrawerTile(
                icon: Icons.lock_outline,
                title: AppLocalizations.of(context).settings_privacy,
                onTap: () {
                  final lang = Localizations.localeOf(context).languageCode;
                  Navigator.of(context).push(MaterialPageRoute(
                    settings: const RouteSettings(name: 'LegalMarkdownScreen'),
                    builder: (_) => LegalMarkdownScreen(assetPath: lang == 'en' ? 'assets/legal/privacy_policy_en.md' : 'assets/legal/privacy_policy.md', title: AppLocalizations.of(context).settings_privacy),
                  ));
                },
              ),
              _DrawerTile(
                icon: Icons.info_outline,
                title: t.drawer_about,
                onTap: () {
                  // TODO: Nawigacja do informacji o aplikacji
                },
              ),
              
              const Spacer(),
              
              // Bottom Actions
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _DrawerTile(
                      icon: Icons.logout,
                      title: t.drawer_logout,
                      onTap: () => FirebaseAuth.instance.signOut(),
                    ),
                    _DrawerTile(
                      icon: Icons.warning_amber_rounded,
                      title: t.drawer_delete_account,
                      color: EuphireColors.magma,
                      onTap: () {
                        Navigator.of(context).pop();
                        showEuphireBottomSheet<void>(
                          context: context,
                          builder: (_) => const HardDeleteSheet(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finalColor = color ?? EuphireColors.mist;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: finalColor, size: 24),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: color ?? EuphireColors.frostWhite,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
