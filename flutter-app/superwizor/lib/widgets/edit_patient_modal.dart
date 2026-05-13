import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/patient.dart';
import '../providers/patient_provider.dart';
import '../theme/euphire_theme.dart';
import 'euphire_button.dart';
import 'euphire_text_field.dart';

class EditPatientModal extends ConsumerStatefulWidget {
  final Patient patient;

  const EditPatientModal({super.key, required this.patient});

  @override
  ConsumerState<EditPatientModal> createState() => _EditPatientModalState();
}

class _EditPatientModalState extends ConsumerState<EditPatientModal> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.patient.firstName);
    _lastNameController = TextEditingController(text: widget.patient.lastName);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final canSave = !_saving && !_deleting && _firstNameController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.editPatient_title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            EuphireTextField(
              controller: _firstNameController,
              labelText: t.addPatient_first_name_label,
            ),
            const SizedBox(height: 16),
            EuphireTextField(
              controller: _lastNameController,
              labelText: t.addPatient_last_name_label,
            ),
            const SizedBox(height: 24),
            // Notice: Modality and Language pickers are intentionally omitted for now (per MVP design)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: EuphireButton(
                text: t.editPatient_save_primary,
                isLoading: _saving,
                onPressed: canSave ? _onSave : null,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: EuphireColors.magma,
                  side: const BorderSide(color: EuphireColors.magma),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _deleting ? null : _onDelete,
                child: _deleting 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: EuphireColors.magma, strokeWidth: 2))
                    : Text(t.editPatient_erase_destructive),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref.read(patientsProvider.notifier).updatePatientUser(
        widget.patient.id,
        firstName,
        lastName,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onDelete() async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EuphireColors.nocturne,
        title: Text(t.editPatient_erase_confirm_header, style: const TextStyle(color: EuphireColors.frostWhite)),
        content: Text(t.editPatient_erase_confirm_body, style: const TextStyle(color: EuphireColors.mist)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common_cancel, style: const TextStyle(color: EuphireColors.mist)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.editPatient_erase_destructive, style: const TextStyle(color: EuphireColors.magma)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      await ref.read(patientsProvider.notifier).deletePatientUser(widget.patient.id);
      if (mounted) {
        Navigator.of(context).pop(); // close modal
        Navigator.of(context).pop(); // pop back to home screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}
