import 'package:flutter/material.dart';
import 'euphire_waveform_indicator.dart';

class EuphireRecordingIndicator extends StatelessWidget {
  final bool isRecording;
  final bool isInitializing;
  final String formattedDuration;
  final int chunkCount;
  final String? errorMessage;
  final Stream<double>? amplitudeStream;

  const EuphireRecordingIndicator({
    super.key,
    required this.isRecording,
    this.isInitializing = false,
    required this.formattedDuration,
    required this.chunkCount,
    this.errorMessage,
    this.amplitudeStream,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        EuphireWaveformIndicator(
          isRecording: isRecording,
          isInitializing: isInitializing,
          amplitudeStream: amplitudeStream,
          formattedDuration: formattedDuration,
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
