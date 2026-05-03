import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReportDetailSheet extends StatelessWidget {
  final String title;
  final String content;

  const ReportDetailSheet({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.secondary, // Mist
            ),
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Skopiowano raport do schowka!')),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy),
            label: const Text('Skopiuj treść'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.scaffoldBackgroundColor, // Obsidian Black equivalent
              foregroundColor: theme.colorScheme.primary, // Ember
              side: BorderSide(color: theme.colorScheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
