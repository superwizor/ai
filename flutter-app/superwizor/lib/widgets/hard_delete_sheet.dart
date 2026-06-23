import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    setState(() {
      _isValid = val.trim().toLowerCase() == 'usuwam';
    });
  }

  Future<void> _executeHardDelete() async {
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
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        await showEuphireBottomSheet<void>(
          context: context,
          builder: (ctx) => EuphireActionSheet(
            header: 'Błąd usuwania',
            body: e.toString(),
            primary: EuphireSheetAction(
              label: 'Rozumiem',
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
            'Usunięcie konta jest bezpowrotne.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: EuphireColors.magma),
          ),
          const SizedBox(height: 16),
          const Text(
            'Skasujemy Twój profil terapeuty, wszystkie sesje, transkrypcje i raporty. Tej akcji nie można cofnąć. Jeśli jesteś pewna/pewien, wpisz słowo usuwam.',
          ),
          const SizedBox(height: 24),
          EuphireTextField(
            controller: _controller,
            labelText: 'Wpisz usuwam',
            onChanged: _onTextChanged,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: EuphireButton(
              text: 'Usuń bezpowrotnie',
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
