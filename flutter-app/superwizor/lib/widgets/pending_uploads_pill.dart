// PendingUploadsPill — a compact status chip that surfaces the
// upload-queue state on the home shell. Renders nothing when the
// queue is empty.
//
// Watches pendingUploadsStreamProvider; tapping the pill navigates
// to the full list view.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/pending_uploads_screen.dart';
import '../theme/euphire_theme.dart';
import '../uploads/pending_upload.dart';
import '../uploads/upload_queue_provider.dart';

class PendingUploadsPill extends ConsumerWidget {
  const PendingUploadsPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingUploadsStreamProvider);
    final list =
        async.maybeWhen(data: (l) => l, orElse: () => <PendingUpload>[]);

    // We show every non-dismissed row so the pill stays visible during
    // server-side processing too — the SessionStatusScreen's success
    // cascade dismisses the row once analysis is fully done.
    if (list.isEmpty) return const SizedBox.shrink();

    final hasFailure = list.any((u) => u.phase == UploadPhase.failed);
    final allCompleted =
        list.every((u) => u.phase == UploadPhase.completed);

    final Color color;
    final IconData icon;
    final String label;
    if (hasFailure) {
      color = Colors.redAccent.shade200;
      icon = Icons.error_outline;
      label = '${list.length} błąd';
    } else if (allCompleted) {
      // Upload finished; backend analysis is still running.
      color = EuphireColors.ember;
      icon = Icons.auto_awesome;
      label = '${list.length} analiza';
    } else {
      color = EuphireColors.ember;
      icon = Icons.cloud_upload_outlined;
      label = '${list.length} w toku';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const PendingUploadsScreen(),
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
