// ─── Euphire Form Widgets ─────────────────────────────────────────────
//
// Shared form components for the Euphire design system.
// Extracted from AddPatientModal / EditPatientModal to eliminate
// duplication and ensure consistent glassmorphism styling.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/euphire_theme.dart';

// ─── Glass-styled text field (lighter surface) ──────────────────────

class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final TextInputType keyboardType;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.autofocus = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autofocus: autofocus,
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
        // LIGHTER than background — "to co na wierzchu jaśniejsze"
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─── Glass-styled dropdown (lighter surface) ────────────────────────

class GlassDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const GlassDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // LIGHTER surface — glass effect, not dark hole
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          // Dropdown popup also lighter
          dropdownColor: const Color(0xFF1A3A3F),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 15,
            color: EuphireColors.frostWhite,
            fontWeight: FontWeight.w500,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: EuphireColors.ember,
            size: 22,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─── Section label (all Montserrat) ─────────────────────────────────

class FormSectionLabel extends StatelessWidget {
  final String text;

  const FormSectionLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: EuphireColors.mist.withValues(alpha: 0.8),
      ),
    );
  }
}

// ─── Consent Checkbox ───────────────────────────────────────────────

class ConsentCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String labelText;
  final String linkLabel;
  final VoidCallback onLinkTap;

  const ConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labelText,
    required this.linkLabel,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: value ? 0.06 : 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value
                ? EuphireColors.ember.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: EuphireColors.ember,
                  checkColor: EuphireColors.obsidianBlack,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: EuphireColors.mist.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(text: '$labelText '),
                    TextSpan(
                      text: linkLabel,
                      style: const TextStyle(
                        color: EuphireColors.ember,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = onLinkTap,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
