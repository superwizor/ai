import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import '../theme/euphire_theme.dart';
import 'euphire_button.dart';
import 'euphire_text_field.dart';
import 'euphire_action_sheet.dart';
import 'euphire_bottom_sheet.dart';
import '../providers/services_provider.dart';
import '../screens/login_screen.dart';

class HardDeleteSheet extends ConsumerStatefulWidget {
  const HardDeleteSheet({super.key});

  @override
  ConsumerState<HardDeleteSheet> createState() => _HardDeleteSheetState();
}

class _HardDeleteSheetState extends ConsumerState<HardDeleteSheet> {
  final _controller = TextEditingController();
  bool _isValid = false;
  bool _isDeleting = false;

  void _onTextChanged(String val) {
    final t = AppLocalizations.of(context);
    setState(() {
      _isValid = val.trim().toLowerCase() == t.delete_account_confirm_word.toLowerCase();
    });
  }

  Future<void> _executeHardDelete() async {
    final t = AppLocalizations.of(context);
    setState(() => _isDeleting = true);
    try {
      // 1. Backend: soft delete user + cascade soft delete patient_files + sessions
      // TODO: Uncomment when backend exposes hardDeleteUser
      // await ref.read(grpcClientsProvider).identity.hardDeleteUser(...);

      // 2. FCM unregister
      try {
        await ref.read(fcmTokenServiceProvider).unregister();
      } catch (_) {} // Ignore unregister errors

      // 3. Local: kasuj wszystkie cache, klucze, Hive boxes
      // TODO: Call _localDataPurger.purgeEverything() when fully implemented

      // 4. Firebase Auth: delete user account
      await FirebaseAuth.instance.currentUser?.delete();

      // 5. Routing: na login screen
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(settings: const RouteSettings(name: 'LoginScreen'), builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        await showEuphireBottomSheet<void>(
          context: context,
          builder: (ctx) => EuphireActionSheet(
            header: t.hard_delete_error,
            body: e.toString(),
            primary: EuphireSheetAction(
              label: t.common_understand,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomPadding + 24,
        left: 24,
        right: 24,
        top: 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.hard_delete_title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: EuphireColors.magma),
          ),
          const SizedBox(height: 16),
          Text(
            t.hard_delete_body(t.delete_account_confirm_word),
          ),
          const SizedBox(height: 24),
          EuphireTextField(
            controller: _controller,
            labelText: '${t.delete_account_sheet_subtitle} ${t.delete_account_confirm_word}',
            onChanged: _onTextChanged,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: EuphireButton(
              text: t.hard_delete_btn_confirm,
              isLoading: _isDeleting,
              onPressed: _isValid ? _executeHardDelete : null,
              backgroundColor: EuphireColors.magma,
            ),
          ),
        ],
      ),
    );
  }
}
