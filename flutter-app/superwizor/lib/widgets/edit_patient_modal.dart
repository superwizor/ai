import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/patient.dart';
import '../providers/patient_provider.dart';
import '../theme/euphire_theme.dart';
import 'euphire_toast.dart';
import 'euphire_button.dart';

class EditPatientModal extends ConsumerStatefulWidget {
  final Patient patient;

  const EditPatientModal({super.key, required this.patient});

  @override
  ConsumerState<EditPatientModal> createState() => _EditPatientModalState();
}

class _EditPatientModalState extends ConsumerState<EditPatientModal> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  bool _saving = false;
  bool _deleting = false;
  String? _emailError;

  // Light e-mail format check. Empty is allowed (optional field); a
  // non-empty value must look like an address.
  static final RegExp _emailRegex =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.patient.firstName);
    _lastNameController = TextEditingController(text: widget.patient.lastName);
    // Seed from the server-backed patient file e-mail
    // (PatientFile.patientEmail, docs/22).
    _emailController = TextEditingController(text: widget.patient.email);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final canSave = !_saving && !_deleting && _firstNameController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 24,
        right: 24,
        top: 12,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ──
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: EuphireColors.mist.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header: Icon + Title + Subtitle ──
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EuphireColors.ember.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: EuphireColors.ember.withValues(alpha: 0.15),
                      blurRadius: 24, spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: EuphireColors.ember,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.patient.firstName} ${widget.patient.lastName}'.trim(),
              style: const TextStyle(
                fontFamily: 'Merriweather',
                fontStyle: FontStyle.italic,
                fontSize: 20,
                color: EuphireColors.frostWhite,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              t.editPatient_title,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: EuphireColors.mist.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── First Name ──
            _GlassTextField(
              controller: _firstNameController,
              label: t.addPatient_first_name_label,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // ── Last Name / Alias ──
            _GlassTextField(
              controller: _lastNameController,
              label: t.addPatient_last_name_label,
            ),
            const SizedBox(height: 12),

            // ── Email (optional) ──
            _GlassTextField(
              controller: _emailController,
              label: t.addPatient_email_label,
              hint: t.addPatient_email_hint,
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
              onChanged: (_) {
                if (_emailError != null) setState(() => _emailError = null);
              },
            ),
            const SizedBox(height: 24),

            // ── Save Button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: EuphireButton(
                text: t.editPatient_save_primary,
                icon: Icons.check_rounded,
                isLoading: _saving,
                onPressed: canSave ? _onSave : null,
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

    final email = _emailController.text.trim();
    // Validate the optional e-mail: empty is fine, but a non-empty value
    // must be a plausible address.
    if (email.isNotEmpty && !_emailRegex.hasMatch(email)) {
      final t = AppLocalizations.of(context);
      setState(() => _emailError = t.auth_error_invalid_email);
      return;
    }

    setState(() => _saving = true);
    try {
      // Persist first/last name + e-mail in one UpdatePatientUser call.
      // The e-mail goes to PatientFile.patient_email (docs/22); an empty
      // string clears it server-side.
      await ref.read(patientsProvider.notifier).updatePatientUser(
            widget.patient.id,
            firstName,
            lastName,
            email: email,
          );

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        EuphireToast.error(context, message: 'Błąd: $e');
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
        backgroundColor: const Color(0xFF0A3438),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          t.editPatient_erase_confirm_header,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            color: EuphireColors.frostWhite,
          ),
        ),
        content: Text(
          t.editPatient_erase_confirm_body,
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: EuphireColors.mist.withValues(alpha: 0.85),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              t.common_cancel,
              style: const TextStyle(color: EuphireColors.mist),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              t.editPatient_erase_destructive,
              style: const TextStyle(
                color: EuphireColors.magma,
                fontWeight: FontWeight.w600,
              ),
            ),
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
        EuphireToast.error(context, message: 'Błąd: $e');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}

// ─── Glass-styled text field (consistent with AddPatientModal) ──────

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _GlassTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: EuphireColors.frostWhite,
      ),
      decoration: InputDecoration(
        hintText: hint ?? label,
        hintStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: EuphireColors.mist.withValues(alpha: 0.45),
        ),
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: EuphireColors.mist.withValues(alpha: 0.7),
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: EuphireColors.ember.withValues(alpha: 0.9),
        ),
        errorText: errorText,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: EuphireColors.ember,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: EuphireColors.magma,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
