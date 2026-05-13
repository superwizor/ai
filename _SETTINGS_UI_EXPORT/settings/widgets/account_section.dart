import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:labirynt_premium/src/core/ui/eu_components.dart';
import 'package:labirynt_premium/src/core/providers/user_provider.dart';
import 'package:labirynt_premium/src/core/utils/app_haptics.dart';
import 'package:labirynt_premium/src/features/auth/data/auth_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';

/// Account management section
///
/// Displays:
/// - Current user info (profile card for logged in, warning for guest)
/// - Login/Logout button
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final userProfile = ref.watch(userProfileProvider).valueOrNull;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode
        ? EuDesignTokens.frostWhite
        : EuDesignTokens.obsidianBlack;

    // Not logged in at all
    if (user == null) {
      return _NotLoggedInView(textColor: textColor);
    }

    final isAnonymous = user.isAnonymous;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(
            left: EuDesignTokens.space16,
            bottom: EuDesignTokens.space8,
          ),
          child: Text(
            context.l10n.settingsAccountSectionTitlePersonal,
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.6),
              letterSpacing: 1.5,
            ),
          ),
        ),

        // Logged in status indicator
        _LoggedInAsRow(
          email: userProfile?.email ?? user.email,
          isAnonymous: isAnonymous,
          textColor: textColor,
        ),

        const SizedBox(height: EuDesignTokens.space8),

        // Anonymous user warning + login CTA
        if (isAnonymous) ...[
          _GuestWarningCard(textColor: textColor),
          const SizedBox(height: EuDesignTokens.space16),
          _LoginButton(ref: ref),
        ]
        // Logged in user profile card
        else ...[
          _ProfileCard(user: user, userProfile: userProfile, ref: ref),
        ],
      ],
    );
  }
}

/// Shows when user is not logged in at all
class _NotLoggedInView extends StatelessWidget {
  final Color textColor;

  const _NotLoggedInView({required this.textColor});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? EuDesignTokens.glassDark : Colors.white;

    return Container(
      padding: const EdgeInsets.all(EuDesignTokens.space20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: EuDesignTokens.borderRadiusMedium,
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.grey),
          const SizedBox(width: EuDesignTokens.space12),
          Expanded(
            child: Text(
              context.l10n.settingsNotLoggedIn,
              style: TextStyle(fontFamily: 'Merriweather', color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Row showing "Logged in as: ..."
class _LoggedInAsRow extends StatelessWidget {
  final String? email;
  final bool isAnonymous;
  final Color textColor;

  const _LoggedInAsRow({
    required this.email,
    required this.isAnonymous,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: EuDesignTokens.space4,
        vertical: EuDesignTokens.space8,
      ),
      child: Row(
        children: [
          Icon(
            isAnonymous
                ? Icons.no_accounts_outlined
                : Icons.account_circle_outlined,
            size: 16,
            color: textColor.withValues(alpha: 0.5),
          ),
          const SizedBox(width: EuDesignTokens.space8),
          Flexible(
            child: Text(
              context.l10n.settingsLoggedInAs(
                isAnonymous
                    ? context.l10n.settingsGuestAccount
                    : (email ?? context.l10n.settingsDefaultUser),
              ),
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 12,
                color: textColor.withValues(alpha: 0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Warning card for guest/anonymous users
class _GuestWarningCard extends StatelessWidget {
  final Color textColor;

  const _GuestWarningCard({required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EuDesignTokens.space12),
      decoration: BoxDecoration(
        color: EuDesignTokens.ember.withValues(alpha: 0.1),
        borderRadius: EuDesignTokens.borderRadiusSmall,
        border: Border.all(color: EuDesignTokens.ember.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: EuDesignTokens.ember,
            size: 20,
          ),
          const SizedBox(width: EuDesignTokens.space12),
          Expanded(
            child: Text(
              context.l10n.settingsGuestWarning,
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 12,
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Login button for anonymous users
class _LoginButton extends StatelessWidget {
  final WidgetRef ref;

  const _LoginButton({required this.ref});

  @override
  Widget build(BuildContext context) {
    return EuSection(
      children: [
        EuListTile(
          leading: const Icon(Icons.login, color: EuDesignTokens.ember),
          title: context.l10n.settingsLoginButton,
          titleColor: EuDesignTokens.ember,
          onTap: () async {
            AppHaptics.mediumImpact(ref);
            await ref.read(authRepositoryProvider).signOut();
          },
        ),
      ],
    );
  }
}

/// Profile card for logged in users
class _ProfileCard extends StatelessWidget {
  final dynamic user;
  final dynamic userProfile;
  final WidgetRef ref;

  const _ProfileCard({
    required this.user,
    required this.userProfile,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    // Photo URL handling
    String? photoUrl = userProfile?.photoUrl ?? user?.photoURL;
    if (kIsWeb && photoUrl != null && photoUrl.contains('firebasestorage')) {
      photoUrl = '$photoUrl&t=${DateTime.now().millisecondsSinceEpoch}';
    }

    final displayName = userProfile?.displayName ?? user?.displayName;
    final email = userProfile?.email ?? user?.email;

    return EuSection(
      children: [
        EuListTile(
          leading: const Icon(Icons.person_outline),
          title: context.l10n.profileName,
          trailing: Text(
            displayName ?? context.l10n.profileNotSet,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              color: EuDesignTokens.frostWhite.withValues(alpha: 0.4),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _showEditNameSheet(context, ref, displayName),
        ),
        EuListTile(
          leading: const Icon(Icons.email_outlined),
          title: 'Email',
          trailing: Text(
            user.isAnonymous ? context.l10n.profileGuest : (email ?? '-'),
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              color: EuDesignTokens.frostWhite.withValues(alpha: 0.4),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: user.isAnonymous
              ? null
              : () => _showEditEmailSheet(context, ref, email),
        ),
        EuListTile(
          leading: const Icon(Icons.camera_alt_outlined),
          title: context.l10n.profilePhoto,
          trailing: photoUrl != null && photoUrl.isNotEmpty
              ? CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(photoUrl),
                )
              : Icon(
                  Icons.add_a_photo_outlined,
                  size: 20,
                  color: EuDesignTokens.frostWhite.withValues(alpha: 0.3),
                ),
          onTap: () {
            context.push('/profile/avatar-upload');
          },
        ),
      ],
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

              // Next step button → opens confirmation sheet
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final newEmail = controller.text.trim();
                    if (newEmail.isNotEmpty && newEmail.contains('@')) {
                      Navigator.pop(sheetContext);
                      _showEmailConfirmSheet(context, ref, newEmail);
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
                    context.l10n.emailChangeNextButton,
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
  // BOTTOM SHEET: Confirm Email Change
  // ─────────────────────────────────────────────────────────────
  void _showEmailConfirmSheet(
    BuildContext context,
    WidgetRef ref,
    String newEmail,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: EuDesignTokens.nocturne,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EuDesignTokens.ember.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: EuDesignTokens.ember.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: EuDesignTokens.ember,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              context.l10n.emailChangeConfirmTitle,
              style: EuTextStyles.h2.copyWith(
                color: EuDesignTokens.frostWhite,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Body - explains verification email
            Text(
              context.l10n.emailChangeConfirmBody(newEmail),
              style: EuTextStyles.bodyMedium.copyWith(
                color: EuDesignTokens.frostWhite.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(authRepositoryProvider)
                        .updateEmail(newEmail);
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                      EuSnackbar.success(
                        context,
                        context.l10n.emailChangeSuccessSnackbar(newEmail),
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
                  context.l10n.emailChangeConfirmButton,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: Text(
                context.l10n.cancelButton,
                style: EuTextStyles.button.copyWith(
                  color: EuDesignTokens.frostWhite.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
