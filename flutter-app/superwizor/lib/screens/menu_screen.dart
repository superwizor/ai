import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/euphire_theme.dart';
import '../screens/legal_markdown_screen.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/profile_edit_sheet.dart';
import '../widgets/modality_sheet.dart';
import '../widgets/hard_delete_sheet.dart';
import '../widgets/language_sheet.dart';
import '../l10n/app_localizations.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zaktualizowano zdjęcie profilowe.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie można dodać zdjęcia na tym urządzeniu.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: EuphireColors.evergreen,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: EuphireColors.frostWhite),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Menu'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: EuphireColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Profile Section (no glassmorphism)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: EuphireColors.emberGlow,
                          ),
                          child: const CircleAvatar(
                            radius: 36,
                            backgroundColor: EuphireColors.ember,
                            child: Icon(Icons.person, size: 36, color: EuphireColors.obsidianBlack),
                          ),
                        ),
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: EuphireColors.nocturne,
                              shape: BoxShape.circle,
                              border: Border.all(color: EuphireColors.mist, width: 1.5),
                            ),
                            child: const Icon(Icons.camera_alt, size: 14, color: EuphireColors.mist),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Terapeuta',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(color: EuphireColors.mist),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section: USTAWIENIA
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Text('USTAWIENIA', style: theme.textTheme.labelMedium),
                      ),
                      _MenuTile(
                        icon: Icons.person_outline,
                        title: AppLocalizations.of(context)!.drawer_profile,
                        onTap: () {
                          showEuphireBottomSheet(
                            context: context,
                            builder: (_) => const ProfileEditSheet(),
                          );
                        },
                      ),
                      
                      _MenuTile(
                        icon: Icons.language,
                        title: AppLocalizations.of(context)!.drawer_language,
                        onTap: () {
                          showEuphireBottomSheet(
                            context: context,
                            builder: (_) => const LanguageSheet(),
                          );
                        },
                      ),

                      _MenuTile(
                        icon: Icons.psychology_outlined,
                        title: AppLocalizations.of(context)!.drawer_modalities,
                        onTap: () {
                          showEuphireBottomSheet(
                            context: context,
                            builder: (_) => const ModalitySheet(),
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                      // Section: DOKUMENTY PRAWNE
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Text('DOKUMENTY PRAWNE', style: theme.textTheme.labelMedium),
                      ),
                      _MenuTile(
                        icon: Icons.description_outlined,
                        title: 'Regulamin',
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const LegalMarkdownScreen(assetPath: 'assets/legal/terms.md'),
                          ));
                        },
                      ),
                      _MenuTile(
                        icon: Icons.lock_outline,
                        title: 'Polityka prywatności',
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const LegalMarkdownScreen(assetPath: 'assets/legal/privacy_policy.md'),
                          ));
                        },
                      ),
                      _MenuTile(
                        icon: Icons.handshake_outlined,
                        title: 'Umowa DPA',
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const LegalMarkdownScreen(assetPath: 'assets/legal/dpa.md'),
                          ));
                        },
                      ),

                      const SizedBox(height: 48),
                      // Bottom Actions
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            _MenuTile(
                              icon: Icons.logout,
                              title: 'Wyloguj się',
                              onTap: () async {
                                await FirebaseAuth.instance.signOut();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                            _MenuTile(
                              icon: Icons.warning_amber_rounded,
                              title: 'Usuń konto',
                              color: EuphireColors.magma,
                              onTap: () {
                                showEuphireBottomSheet(
                                  context: context,
                                  builder: (_) => const HardDeleteSheet(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finalColor = color ?? EuphireColors.mist;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: finalColor, size: 24),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color ?? EuphireColors.frostWhite,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

