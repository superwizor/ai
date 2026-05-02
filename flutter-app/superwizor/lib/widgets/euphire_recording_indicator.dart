import 'package:flutter/material.dart';

class EuphireRecordingIndicator extends StatelessWidget {
  final bool isRecording;
  final String formattedDuration;
  final int chunkCount;
  final String? errorMessage;

  const EuphireRecordingIndicator({
    super.key,
    required this.isRecording,
    required this.formattedDuration,
    required this.chunkCount,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRecording 
                ? theme.colorScheme.primary.withValues(alpha: 0.1) 
                : theme.colorScheme.surface,
            border: Border.all(
              color: isRecording 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.onSurface.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Center(
            child: Icon(
              isRecording ? Icons.fiber_manual_record : Icons.mic,
              color: isRecording 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          formattedDuration,
          style: theme.textTheme.displayLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Zapisane fragmenty: $chunkCount.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            errorMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
