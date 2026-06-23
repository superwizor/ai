import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../utils/haptics.dart';
import '../models/patient.dart';
import '../providers/patient_avatar_provider.dart';
import '../providers/patient_provider.dart';
import '../theme/euphire_theme.dart';
import 'avatar_customize_sheet.dart';
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

  String get _initials {
    final f = widget.patient.firstName;
    final l = widget.patient.lastName;
    if (f.isEmpty && l.isEmpty) return '?';
    final first = f.isNotEmpty ? f.characters.first.toUpperCase() : '';
    final last = l.isNotEmpty ? l.characters.first.toUpperCase() : '';
    return '$first$last'.trim();
  }

  Widget _buildAvatarHeader() {
    final avatarConfigs = ref.watch(patientAvatarProvider);
    final avatarConfig =
        avatarConfigs[widget.patient.id] ?? const PatientAvatarConfig();
    final color = avatarConfig.color;
    final avatarLabel = avatarConfig.customLabel ?? _initials;
    final isEmoji = avatarLabel.runes.any((r) => r > 0x2600);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => AvatarCustomizeSheet(
            patientId: widget.patient.id,
            defaultInitials: _initials,
          ),
        );
      },
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: isEmoji
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        avatarLabel,
                        style: const TextStyle(fontSize: 28, height: 1.0),
                      ),
                    )
                  : Text(
                      avatarLabel,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: EuphireColors.frostWhite,
                      ),
                    ),
            ),
            // Pencil badge
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EuphireColors.ember,
                  border: Border.all(
                    color: const Color(0xFF0A2326),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  size: 13,
                  color: EuphireColors.nocturne,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final canSave = !_saving && _firstNameController.text.trim().isNotEmpty;

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

            // ── Header: Avatar + Title + Subtitle ──
            Center(
              child: _buildAvatarHeader(),
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
        AppHapticFeedback.mediumImpact();
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
