import 'package:flutter/material.dart';
import '../theme/euphire_theme.dart';

class EuphireListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final IconData trailingIcon;
  final Widget? trailingWidget;

  const EuphireListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailingIcon = Icons.arrow_forward_ios,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: EuphireColors.frostWhite,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: EuphireColors.mist,
              ),
            )
          : null,
      trailing: trailingWidget ?? SizedBox(
        width: trailingIcon == Icons.arrow_forward_ios ? 16 : 24,
        child: Icon(trailingIcon, color: trailingIcon == Icons.arrow_forward_ios ? EuphireColors.ember : EuphireColors.mist, size: trailingIcon == Icons.arrow_forward_ios ? 16 : 24),
      ),
      onTap: onTap,
    );
  }
}
