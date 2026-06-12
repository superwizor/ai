import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/identity/v1/identity.pb.dart';
import '../providers/current_user_provider.dart';
import '../providers/grpc_provider.dart';
import '../theme/euphire_theme.dart';
import 'euphire_button.dart';
import 'euphire_text_field.dart';

class ProfileEditSheet extends ConsumerStatefulWidget {
  /// Wywoływany po pomyślnym zapisaniu profilu — użyj do setState w rodzicu.
  final VoidCallback? onSaved;

  const ProfileEditSheet({super.key, this.onSaved});

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _titleController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final parts = (user.displayName ?? '').split(' ');
      _firstController.text = parts.isNotEmpty ? parts.first : '';
      _lastController.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    // Load professional title from backend user profile
    final backendUser = ref.read(currentUserProvider).value;
    if (backendUser != null && backendUser.professionalTitle.isNotEmpty) {
      _titleController.text = backendUser.professionalTitle;
    }
  }

  Future<void> _saveProfile() async {
    final firstName = _firstController.text.trim();
    final lastName = _lastController.text.trim();
    final professionalTitle = _titleController.text.trim();
    if (firstName.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final displayName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

      // 1. Firebase Auth — aktualizuje displayName
      await user.updateDisplayName(displayName);

      // 2. identity-svc gRPC — aktualizuje rejestr backendu
      try {
        await ref.read(grpcClientsProvider).identity.updateProfile(
          UpdateProfileRequest(
            firstName: firstName,
            lastName: lastName,
            professionalTitle: professionalTitle,
          ),
        );
      } catch (_) {
        // Nie blokuj UI jeśli backend niedostępny
      }

      // 3. Wymuszamy reload — konieczne żeby FirebaseAuth.currentUser.displayName
      //    był aktualny natychmiast po pop()
      await user.reload();
      ref.invalidate(currentUserProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      // Callback do rodzica — odświeża setState w MenuScreen
      widget.onSaved?.call();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text('Edytuj profil.', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Podaj swoje imię, nazwisko i tytuł zawodowy.',
            style: theme.textTheme.bodyMedium?.copyWith(color: EuphireColors.mist),
          ),
          const SizedBox(height: 24),
          EuphireTextField(
            controller: _firstController,
            labelText: 'Imię',
          ),
          const SizedBox(height: 12),
          EuphireTextField(
            controller: _lastController,
            labelText: 'Nazwisko (opcjonalne)',
          ),
          const SizedBox(height: 12),
          EuphireTextField(
            controller: _titleController,
            labelText: 'Tytuł zawodowy (np. mgr, dr)',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: EuphireButton(
              text: 'Zapisz.',
              isLoading: _isSaving,
              onPressed: _saveProfile,
            ),
          ),
        ],
      ),
    );
  }
}
