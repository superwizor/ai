import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:labirynt_premium/src/core/theme/app_theme.dart';
import 'package:labirynt_premium/src/core/utils/photo_editor_helper.dart';

/// Reusable photo source picker widget.
///
/// On mobile: shows Camera + Gallery buttons side by side.
/// On web: shows only the Gallery button (camera not supported).
///
/// Handles picking and cropping via [PhotoEditorHelper].
/// Calls [onImagePicked] with the resulting [XFile] after the user
/// completes the crop step.
///
/// Usage - full-screen (e.g. onboarding / settings):
/// ```dart
/// EuPhotoSourcePicker(
///   onImagePicked: (file) async { ... },
/// )
/// ```
///
/// Usage - compact / inline in a list row (e.g. Party Mode lobby):
/// ```dart
/// EuPhotoSourcePicker(
///   buttonSize: 36,
///   isLoading: _isUploadingPhoto,
///   onImagePicked: _uploadPhoto,
/// )
/// ```
class EuPhotoSourcePicker extends StatelessWidget {
  /// Called with the cropped [XFile] after the user completes selection.
  final Future<void> Function(XFile file) onImagePicked;

  /// When true, replaces the buttons with a compact loading spinner.
  final bool isLoading;

  /// Size (width & height) of each icon button.
  /// Default 60.0 for full-screen usage, use 36.0 for compact/inline.
  final double buttonSize;

  const EuPhotoSourcePicker({
    super.key,
    required this.onImagePicked,
    this.isLoading = false,
    this.buttonSize = 60.0,
  });

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final file = await PhotoEditorHelper.pickAndCropImage(
      context,
      source: source,
    );
    if (file != null) {
      await onImagePicked(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      final spinnerSize = (buttonSize * 0.5).clamp(18.0, 32.0);
      return SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: Center(
          child: SizedBox(
            width: spinnerSize,
            height: spinnerSize,
            child: const CircularProgressIndicator(
              color: AppColors.ember,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!kIsWeb) ...[
          _EuPickerButton(
            icon: Icons.camera_alt_rounded,
            isPrimary: false,
            size: buttonSize,
            onTap: () => _pick(context, ImageSource.camera),
          ),
          const SizedBox(width: 16),
        ],
        _EuPickerButton(
          icon: Icons.image_rounded,
          isPrimary: true,
          size: buttonSize,
          onTap: () => _pick(context, ImageSource.gallery),
        ),
      ],
    );
  }
}

class _EuPickerButton extends StatelessWidget {
  final IconData icon;
  final bool isPrimary;
  final double size;
  final VoidCallback onTap;

  const _EuPickerButton({
    required this.icon,
    required this.isPrimary,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular((size * 0.33).clamp(10.0, 20.0));
    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.ember : AppColors.surfaceTeal,
          borderRadius: radius,
          border: Border.all(
            color: isPrimary
                ? AppColors.ember
                : AppColors.surfaceTeal.withValues(alpha: 0.5),
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.ember.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: isPrimary ? Colors.black : Colors.white,
          size: size * 0.47,
        ),
      ),
    );
  }
}
