import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:labirynt_premium/src/core/theme/euphire_design_tokens.dart';

/// EUPHIRE styled text input field
class EuInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final String? errorText;
  final bool isObscure;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final TextAlign textAlign;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final int? maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Color? fillColor;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;

  const EuInput({
    super.key,
    required this.controller,
    this.hintText = '',
    this.labelText,
    this.errorText,
    this.isObscure = false,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.suffixIcon,
    this.textAlign = TextAlign.start,
    this.textStyle,
    this.hintStyle,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.onSubmitted,
    this.fillColor,
    this.autofocus = false,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          obscureText: isObscure,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          textAlign: textAlign,
          maxLines: maxLines,
          minLines: minLines,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          inputFormatters: inputFormatters,
          style:
              textStyle ??
              TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                color: Colors.white,
              ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle:
                hintStyle ??
                TextStyle(fontFamily: 'Montserrat', color: Colors.white24),
            filled: true,
            fillColor: fillColor ?? Colors.white.withValues(alpha: 0.1),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: EuDesignTokens.borderRadiusMedium,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: EuDesignTokens.borderRadiusMedium,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: EuDesignTokens.borderRadiusMedium,
              borderSide: const BorderSide(
                color: EuDesignTokens.ember,
                width: 1.5,
              ),
            ),
            errorText: errorText,
            errorStyle: TextStyle(
              fontFamily: 'Montserrat',
              color: EuDesignTokens.error,
              fontSize: 12,
            ),
            suffixIcon: suffixIcon,
            prefixIconColor: Colors.white54,
            suffixIconColor: Colors.white54,
          ),
        ),
      ],
    );
  }
}
