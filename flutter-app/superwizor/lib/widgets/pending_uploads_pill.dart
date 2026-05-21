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
    final list = async.maybeWhen(data: (l) => l, orElse: () => <PendingUpload>[]);

    // Hide completed + dismissed rows from the count; failed rows are
    // shown so the user notices and can retry.
    final visible = list
        .where((u) => u.phase != UploadPhase.completed)
        .toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    final hasFailure = visible.any((u) => u.phase == UploadPhase.failed);
    final color = hasFailure ? Colors.redAccent.shade200 : EuphireColors.ember;
    final icon = hasFailure ? Icons.error_outline : Icons.cloud_upload_outlined;
    final label =
        hasFailure ? '${visible.length} błąd' : '${visible.length} w toku';

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
