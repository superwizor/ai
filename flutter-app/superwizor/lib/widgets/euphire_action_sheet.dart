// Reusable bottom-sheet content layout for confirm / warning /
// destructive flows. The plan's UX writing repeats the same shape:
//
//   [header]
//   [body]
//   [primary button]
//   [secondary button (optional)]
//   [destructive button (optional)]
//
// Render this inside `showEuphireBottomSheet(...)` to keep visuals
// consistent across screens. Texts come from caller (D7 — i18n).

import 'package:flutter/material.dart';

import '../theme/euphire_theme.dart';

class EuphireActionSheet extends StatelessWidget {
  final String header;
  final String body;
  final EuphireSheetAction primary;
  final EuphireSheetAction? secondary;
  final EuphireSheetAction? destructive;
  final IconData? topIcon;

  const EuphireActionSheet({
    super.key,
    required this.header,
    required this.body,
    required this.primary,
    this.secondary,
    this.destructive,
    this.topIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle for bottom sheet
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 28),
            if (topIcon != null) ...[
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EuphireColors.ember.withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: EuphireColors.ember.withValues(alpha: 0.2),
                        blurRadius: 28, spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    topIcon,
                    color: EuphireColors.ember,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              header,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
                color: EuphireColors.frostWhite,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Montserrat',
                height: 1.5,
                color: EuphireColors.mist,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: primary.onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EuphireColors.ember,
                  foregroundColor: EuphireColors.obsidianBlack,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  primary.label,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            if (secondary != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: secondary!.onPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EuphireColors.frostWhite,
                    side: BorderSide(color: EuphireColors.mist.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    secondary!.label,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
            if (destructive != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: TextButton(
                  onPressed: destructive!.onPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: EuphireColors.magma,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    destructive!.label,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EuphireSheetAction {
  final String label;
  final VoidCallback? onPressed;

  const EuphireSheetAction({required this.label, this.onPressed});
}
