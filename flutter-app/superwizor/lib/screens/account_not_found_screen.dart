// AccountNotFoundScreen — a Firebase session exists but identity-svc
// has no users row (never registered, or the account was hard-deleted
// by an admin). Replaces the old silent auto-registration, which minted
// ghost THERAPIST accounts for any unknown Google/Apple sign-in and
// then blocked the person's real invitation (docs/39 live-fix,
// 2026-07-04).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/euphire_theme.dart';

class AccountNotFoundScreen extends StatelessWidget {
  const AccountNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: EuphireColors.deepTealBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person_search_outlined,
                  size: 56,
                  color: EuphireColors.mist,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.account_not_found_title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.account_not_found_body(email),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: EuphireColors.mist,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(l10n.deactivated_logout),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EuphireColors.ember,
                    side: const BorderSide(color: EuphireColors.ember),
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
