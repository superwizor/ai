import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'euphire_button.dart';
import 'euphire_text_field.dart';
import '../providers/grpc_provider.dart';
import '../generated/identity/v1/identity.pb.dart';

class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet({super.key});

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  final _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller.text = FirebaseAuth.instance.currentUser?.displayName ?? '';
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Firebase auth update
        await user.updateDisplayName(_controller.text);

        // Splitting Display name into First and Last
        final parts = _controller.text.split(' ');
        final firstName = parts.isNotEmpty ? parts.first : '';
        final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        // identityClient update
        try {
          await ref.read(grpcClientsProvider).identity.updateProfile(
            UpdateProfileRequest(
              firstName: firstName,
              lastName: lastName,
            )
          );
        } catch (_) {} // Ignore if not fully implemented in backend yet

        // Force user reload so the UI updates
        await user.reload();
        ref.invalidate(currentUserProvider);

        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          Text('Edycja profilu', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          EuphireTextField(
            controller: _controller,
            labelText: 'Imię i nazwisko (lub pseudonim)',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: EuphireButton(
              text: 'Zapisz',
              isLoading: _isSaving,
              onPressed: _saveProfile,
            ),
          ),
        ],
      ),
    );
  }
}
