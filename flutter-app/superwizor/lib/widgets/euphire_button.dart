import 'package:flutter/material.dart';

class EuphireButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final bool iconOnRight;

  const EuphireButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.iconOnRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null && !iconOnRight) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              if (icon != null && iconOnRight) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 20),
              ],
            ],
          );

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: backgroundColor != null
          ? ElevatedButton.styleFrom(backgroundColor: backgroundColor)
          : null,
      child: content,
    );
  }
}
