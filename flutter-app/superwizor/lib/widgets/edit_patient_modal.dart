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
  // docs/43 §4: the working alias is the only editable client
  // identifier. The e-mail is shown read-only below — it changes only
  // by sending a new client-panel invitation.
  late final TextEditingController _aliasController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _aliasController =
        TextEditingController(text: widget.patient.workingAlias);
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  String get _initials {
    final words = widget.patient.workingAlias
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2);
    final initials =
        words.map((w) => w.characters.first.toUpperCase()).join();
    return initials.isEmpty ? '?' : initials;
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
    final canSave = !_saving && _aliasController.text.trim().isNotEmpty;

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
              widget.patient.workingAlias,
              style: const TextStyle(
                fontFamily: 'Merriweather',
                fontStyle: FontStyle.italic,
                fontSize: 20,
                color: EuphireColors.frostWhite,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

            // ── Working alias ("Pseudonim") — the only editable
            // client identifier (docs/43 §4). ──
            _GlassTextField(
              controller: _aliasController,
              label: t.addPatient_last_name_label,
              onChanged: (_) => setState(() {}),
            ),

            // ── E-mail (read-only, resolved server-side from the
            // account/invitation; changes via a new invite). ──
            if (widget.patient.email.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '${t.home_menu_field_email}: ${widget.patient.email}',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: EuphireColors.mist.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t.editPatient_email_readonly_hint,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  color: EuphireColors.mist.withValues(alpha: 0.5),
                ),
              ),
            ],
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
    final alias = _aliasController.text.trim();
    if (alias.isEmpty) return;

    setState(() => _saving = true);
    try {
      // Persist the alias via UpdatePatientFile.working_alias — the
      // server COALESCEs the other fields (docs/43 §4).
      await ref
          .read(patientsProvider.notifier)
          .updatePatientAlias(widget.patient.id, alias);

      if (mounted) {
        AppHapticFeedback.mediumImpact();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context);
        EuphireToast.error(context, message: t.editPatient_error(e.toString()));
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
  final ValueChanged<String>? onChanged;

  const _GlassTextField({
    required this.controller,
    required this.label,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: EuphireColors.frostWhite,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: label,
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
          height: 1.1,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: EuphireColors.ember.withValues(alpha: 0.9),
          height: 1.1,
        ),
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
