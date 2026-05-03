import 'package:flutter/material.dart';
import '../theme/euphire_theme.dart';

class EuphireCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const EuphireCard({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: EuphireColors.nocturne,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}
