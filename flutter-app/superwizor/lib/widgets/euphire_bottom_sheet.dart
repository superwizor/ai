import 'package:flutter/material.dart';
import '../theme/euphire_theme.dart';

Future<T?> showEuphireBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    // Slightly lighter than nocturne (#002E32) — gives the sheet
    // a layered, elevated feel while staying dark-mode cohesive.
    backgroundColor: const Color(0xFF0A3438),
    barrierColor: Colors.black.withValues(alpha: 0.6),
    constraints: const BoxConstraints(maxWidth: double.infinity),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: builder,
  );
}
