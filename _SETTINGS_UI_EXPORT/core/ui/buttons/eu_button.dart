import 'package:flutter/material.dart';

import 'package:labirynt_premium/src/core/theme/euphire_design_tokens.dart';

/// Button variants for different purposes
enum EuButtonVariant {
  /// Primary action - Ember background, black text
  primary,

  /// Secondary action - Glass background, white text
  secondary,

  /// Ghost/Tertiary - Transparent, ember text
  ghost,

  /// Destructive action - Error color
  destructive,
}

/// Button sizes
enum EuButtonSize { small, medium, large }

/// EUPHIRE styled button component
///
/// Follows Brand Book with 6px border radius and Montserrat typography.
///
/// Example:
/// ```dart
/// EuButton(
///   label: 'Rozpocznij',
///   onPressed: () => doSomething(),
///   variant: EuButtonVariant.primary,
/// )
/// ```
class EuButton extends StatelessWidget {
  /// Button label text
  final String label;

  /// Callback when button is pressed. Null disables the button.
  final VoidCallback? onPressed;

  /// Visual variant of the button
  final EuButtonVariant variant;

  /// Size of the button
  final EuButtonSize size;

  /// Optional leading icon
  final IconData? leadingIcon;

  /// Optional trailing icon
  final IconData? trailingIcon;

  /// Show loading spinner instead of content
  final bool isLoading;

  /// Make button full width
  final bool isFullWidth;

  const EuButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = EuButtonVariant.primary,
    this.size = EuButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  /// Creates a primary button (shorthand)
  const EuButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = EuButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : variant = EuButtonVariant.primary;

  /// Creates a secondary button (shorthand)
  const EuButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = EuButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : variant = EuButtonVariant.secondary;

  /// Creates a ghost button (shorthand)
  const EuButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = EuButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : variant = EuButtonVariant.ghost;

  double get _height {
    switch (size) {
      case EuButtonSize.small:
        return EuDesignTokens.buttonHeightSmall;
      case EuButtonSize.medium:
        return EuDesignTokens.buttonHeightMedium;
      case EuButtonSize.large:
        return EuDesignTokens.buttonHeightLarge;
    }
  }

  double get _fontSize {
    switch (size) {
      case EuButtonSize.small:
        return 12;
      case EuButtonSize.medium:
        return 14;
      case EuButtonSize.large:
        return 16;
    }
  }

  double get _iconSize {
    switch (size) {
      case EuButtonSize.small:
        return EuDesignTokens.iconSizeSmall;
      case EuButtonSize.medium:
        return EuDesignTokens.iconSizeMedium;
      case EuButtonSize.large:
        return EuDesignTokens.iconSizeLarge;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case EuButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case EuButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
      case EuButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: _height,
      child: AnimatedContainer(
        duration: EuDesignTokens.durationFast,
        decoration: _getDecoration(isDisabled),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : onPressed,
            borderRadius: EuDesignTokens.borderRadiusSmall,
            splashColor: _getSplashColor(),
            child: Padding(padding: _padding, child: _buildContent(isDisabled)),
          ),
        ),
      ),
    );
  }

  BoxDecoration _getDecoration(bool isDisabled) {
    switch (variant) {
      case EuButtonVariant.primary:
        return BoxDecoration(
          color: isDisabled
              ? EuDesignTokens.ember.withValues(alpha: 0.5)
              : EuDesignTokens.ember,
          borderRadius: EuDesignTokens.borderRadiusSmall,
          boxShadow: isDisabled
              ? null
              : EuDesignTokens.shadowEmber(opacity: 0.25),
        );

      case EuButtonVariant.secondary:
        return BoxDecoration(
          color: EuDesignTokens.glassDark,
          borderRadius: EuDesignTokens.borderRadiusSmall,
          border: Border.all(
            color: isDisabled
                ? EuDesignTokens.glassBorderDark.withValues(alpha: 0.3)
                : EuDesignTokens.glassBorderDark,
          ),
        );

      case EuButtonVariant.ghost:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: EuDesignTokens.borderRadiusSmall,
        );

      case EuButtonVariant.destructive:
        return BoxDecoration(
          color: isDisabled
              ? EuDesignTokens.error.withValues(alpha: 0.5)
              : EuDesignTokens.error,
          borderRadius: EuDesignTokens.borderRadiusSmall,
        );
    }
  }

  Color _getSplashColor() {
    switch (variant) {
      case EuButtonVariant.primary:
        return Colors.black12;
      case EuButtonVariant.secondary:
      case EuButtonVariant.ghost:
        return Colors.white12;
      case EuButtonVariant.destructive:
        return Colors.white24;
    }
  }

  Color _getForegroundColor(bool isDisabled) {
    switch (variant) {
      case EuButtonVariant.primary:
        return EuDesignTokens.obsidianBlack;
      case EuButtonVariant.secondary:
        return isDisabled ? Colors.white38 : Colors.white;
      case EuButtonVariant.ghost:
        return isDisabled
            ? EuDesignTokens.ember.withValues(alpha: 0.5)
            : EuDesignTokens.ember;
      case EuButtonVariant.destructive:
        return Colors.white;
    }
  }

  Widget _buildContent(bool isDisabled) {
    if (isLoading) {
      return Center(
        child: SizedBox(
          width: _iconSize,
          height: _iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getForegroundColor(false),
            ),
          ),
        ),
      );
    }

    final foregroundColor = _getForegroundColor(isDisabled);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: _iconSize, color: foregroundColor),
          SizedBox(width: EuDesignTokens.space8),
        ],
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
            color: foregroundColor,
            letterSpacing: 0.5,
          ),
        ),
        if (trailingIcon != null) ...[
          SizedBox(width: EuDesignTokens.space8),
          Icon(trailingIcon, size: _iconSize, color: foregroundColor),
        ],
      ],
    );
  }
}
