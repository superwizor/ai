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

  const EuphireActionSheet({
    super.key,
    required this.header,
    required this.body,
    required this.primary,
    this.secondary,
    this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(header, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: primary.onPressed,
              child: Text(primary.label),
            ),
            if (secondary != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: secondary!.onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: EuphireColors.frostWhite,
                  side: const BorderSide(color: EuphireColors.mist),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(secondary!.label),
              ),
            ],
            if (destructive != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: destructive!.onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: EuphireColors.magma,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(destructive!.label),
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
