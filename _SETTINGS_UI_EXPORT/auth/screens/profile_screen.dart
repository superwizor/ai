import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';
import 'package:labirynt_premium/src/features/auth/data/auth_repository.dart';
import 'package:labirynt_premium/src/core/ui/eu_components.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final textColor = isDarkMode
        ? EuDesignTokens.frostWhite
        : EuDesignTokens.obsidianBlack;

    return Scaffold(
      backgroundColor: isDarkMode
          ? EuDesignTokens.nocturne
          : Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header - same style as settings
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isDarkMode ? Colors.white10 : Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Account Options Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? EuDesignTokens.glassDark : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDarkMode
                        ? EuDesignTokens.glassBorderDark
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    _buildProfileOption(
                      context,
                      label: context.l10n.profileName,
                      value: user.displayName ?? context.l10n.profileNotSet,
                      onTap: () =>
                          _showEditNameSheet(context, ref, user.displayName),
                      showArrow: true,
                      textColor: textColor,
                      isDarkMode: isDarkMode,
                      isFirst: true,
                    ),
                    _buildDivider(isDarkMode),
                    _buildProfileOption(
                      context,
                      label: "Email",
                      value: user.isAnonymous
                          ? context.l10n.profileGuest
                          : (user.email ?? "-"),
                      onTap: user.isAnonymous
                          ? null
                          : () => _showEditEmailSheet(context, ref, user.email),
                      showArrow: !user.isAnonymous,
                      textColor: textColor,
                      isDarkMode: isDarkMode,
                    ),
                    _buildDivider(isDarkMode),
                    _buildProfileOption(
                      context,
                      label: context.l10n.profilePhoto,
                      trailing: user.photoURL != null
                          ? CircleAvatar(
                              radius: 16,
                              backgroundImage: NetworkImage(user.photoURL!),
                            )
                          : Icon(
                              Icons.add_a_photo_outlined,
                              size: 20,
                              color: textColor.withValues(alpha: 0.3),
                            ),
                      onTap: () {
                        context.push('/profile/avatar-upload');
                      },
                      showArrow: true,
                      textColor: textColor,
                      isDarkMode: isDarkMode,
                    ),
                    _buildDivider(isDarkMode),
                    _buildProfileOption(
                      context,
                      label: context.l10n.accountResetButton,
                      onTap: () {
                        context.push('/profile/account-reset');
                      },
                      showArrow: true,
                      textColor: textColor,
                      isDarkMode: isDarkMode,
                    ),
                    _buildDivider(isDarkMode),
                    _buildProfileOption(
                      context,
                      label: context.l10n.accountDeleteButton,
                      labelColor: EuDesignTokens.error,
                      onTap: () {
                        context.push('/profile/account-delete');
                      },
                      showArrow: true,
                      textColor: textColor,
                      isDarkMode: isDarkMode,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM SHEET: Edit Name
  // ─────────────────────────────────────────────────────────────
  void _showEditNameSheet(
    BuildContext context,
    WidgetRef ref,
    String? currentName,
  ) {
    final controller = TextEditingController(text: currentName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: EuDesignTokens.nocturne,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EuDesignTokens.frostWhite.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EuDesignTokens.ember.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: EuDesignTokens.ember,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                context.l10n.profileChangeName,
                style: EuTextStyles.h3.copyWith(
                  color: EuDesignTokens.frostWhite,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                context.l10n.profileChangeNameDesc,
                style: EuTextStyles.bodyMedium.copyWith(
                  color: EuDesignTokens.frostWhite.withValues(alpha: 0.6),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Text field
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: EuDesignTokens.frostWhite,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.profileEnterNewName,
                  hintStyle: TextStyle(
                    color: EuDesignTokens.frostWhite.withValues(alpha: 0.3),
                  ),
                  filled: true,
                  fillColor: EuDesignTokens.frostWhite.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: EuDesignTokens.ember,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (controller.text.trim().isNotEmpty) {
                      try {
                        await ref
                            .read(authRepositoryProvider)
                            .updateDisplayName(controller.text.trim());
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                          EuSnackbar.success(
                            context,
                            context.l10n.profileNameUpdated,
                          );
                        }
                      } catch (e) {
                        if (sheetContext.mounted) {
                          EuSnackbar.error(
                            sheetContext,
                            "${context.l10n.error}: $e",
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EuDesignTokens.ember,
                    foregroundColor: EuDesignTokens.obsidianBlack,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    context.l10n.saveButton,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM SHEET: Edit Email
  // ─────────────────────────────────────────────────────────────
  void _showEditEmailSheet(
    BuildContext context,
    WidgetRef ref,
    String? currentEmail,
  ) {
    final controller = TextEditingController(text: currentEmail);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: EuDesignTokens.nocturne,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EuDesignTokens.frostWhite.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EuDesignTokens.ember.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: EuDesignTokens.ember,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                context.l10n.profileChangeEmail,
                style: EuTextStyles.h3.copyWith(
                  color: EuDesignTokens.frostWhite,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                context.l10n.profileChangeEmailDesc,
                style: EuTextStyles.bodyMedium.copyWith(
                  color: EuDesignTokens.frostWhite.withValues(alpha: 0.6),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Text field
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: EuDesignTokens.frostWhite,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.profileEnterNewEmail,
                  hintStyle: TextStyle(
                    color: EuDesignTokens.frostWhite.withValues(alpha: 0.3),
                  ),
                  filled: true,
                  fillColor: EuDesignTokens.frostWhite.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: EuDesignTokens.ember,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final newEmail = controller.text.trim();
                    if (newEmail.isNotEmpty && newEmail.contains('@')) {
                      try {
                        await ref
                            .read(authRepositoryProvider)
                            .updateEmail(newEmail);
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                          EuSnackbar.success(
                            context,
                            context.l10n.profileEmailVerificationSent,
                          );
                        }
                      } catch (e) {
                        if (sheetContext.mounted) {
                          final msg = e.toString();
                          if (msg.contains('requires-recent-login')) {
                            EuSnackbar.error(
                              sheetContext,
                              context.l10n.profileEmailRequiresRecentLogin,
                            );
                          } else {
                            EuSnackbar.error(
                              sheetContext,
                              "${context.l10n.error}: $e",
                            );
                          }
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EuDesignTokens.ember,
                    foregroundColor: EuDesignTokens.obsidianBlack,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    context.l10n.saveButton,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────
  Widget _buildProfileOption(
    BuildContext context, {
    required String label,
    String? value,
    Widget? trailing,
    required VoidCallback? onTap,
    bool showArrow = true,
    Color? labelColor,
    required Color textColor,
    required bool isDarkMode,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(24))
          : isFirst
          ? const BorderRadius.vertical(top: Radius.circular(24))
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Merriweather',
                  color: labelColor ?? textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: trailing,
              )
            else if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: SizedBox(
                  width: 120,
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: textColor.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            if (showArrow)
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: textColor.withValues(alpha: 0.2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05),
    );
  }
}
