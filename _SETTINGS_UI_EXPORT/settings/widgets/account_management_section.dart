import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';
import 'package:labirynt_premium/src/core/ui/eu_components.dart';
import 'package:labirynt_premium/src/core/utils/app_haptics.dart';
import 'package:labirynt_premium/src/features/auth/data/auth_repository.dart';

/// Account management section
///
/// Contains options for:
/// - Resetting game progress (navigates to dedicated screen)
/// - Deleting account (navigates to dedicated screen)
/// - Logging out (with confirmation bottom sheet)
class AccountManagementSection extends ConsumerWidget {
  const AccountManagementSection({super.key});

  /// Shows a logout confirmation bottom sheet
  Future<bool?> _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    AppHaptics.mediumImpact(ref);

    return showModalBottomSheet<bool>(
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
                    color: EuDesignTokens.ember.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: EuDesignTokens.ember,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              context.l10n.logoutConfirmTitle,
              style: EuTextStyles.h2.copyWith(
                color: EuDesignTokens.frostWhite,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              context.l10n.logoutConfirmBody,
              style: EuTextStyles.bodyMedium.copyWith(
                color: EuDesignTokens.frostWhite.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Logout button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EuDesignTokens.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  context.l10n.logoutConfirmButton,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, false),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EuSection(
      header: context.l10n.settingsAccountManagementHeader,
      children: [
        EuListTile(
          leading: const Icon(Icons.refresh),
          title: context.l10n.settingsAccountManagementResetTitle,
          subtitle: context.l10n.settingsAccountManagementResetSubtitle,
          onTap: () {
            context.push('/profile/account-reset');
          },
        ),
        EuListTile(
          leading: const Icon(
            Icons.person_remove_outlined,
            color: EuDesignTokens.error,
          ),
          title: context.l10n.settingsAccountManagementDeleteTitle,
          subtitle: context.l10n.settingsAccountManagementDeleteSubtitle,
          titleColor: EuDesignTokens.error,
          onTap: () {
            context.push('/profile/account-delete');
          },
        ),
        EuListTile(
          leading: const Icon(Icons.logout, color: EuDesignTokens.error),
          title: context.l10n.settingsLogoutButton,
          titleColor: EuDesignTokens.error,
          onTap: () async {
            final confirm = await _showLogoutConfirmation(context, ref);
            if (confirm == true) {
              await ref.read(authRepositoryProvider).signOut();
            }
          },
        ),
      ],
    );
  }
}
