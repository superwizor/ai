// DeactivatedAccountScreen — full-screen block shown when the backend
// reports the account as reversibly deactivated (docs/38 §4).
//
// Trigger: users.is_active = false, surfaced either as
// User.isActive == false from GetUserByFirebaseUID, or as
// PermissionDenied "ACCOUNT_DEACTIVATED: …" from any gated RPC
// (identity-svc resolveCaller / ValidateToken). Clinical data stays
// intact server-side; the org's manager can reactivate the seat at
// any time — hence "contact your administrator", not "goodbye".

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/euphire_theme.dart';

class DeactivatedAccountScreen extends StatelessWidget {
  const DeactivatedAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  Icons.lock_person_outlined,
                  size: 56,
                  color: EuphireColors.mist,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.deactivated_title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.deactivated_body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: EuphireColors.mist,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: Text(l10n.deactivated_logout),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
