import 'package:flutter/material.dart';
import 'euphire_waveform_indicator.dart';

class EuphireRecordingIndicator extends StatelessWidget {
  final bool isRecording;
  final String formattedDuration;
  final int chunkCount;
  final String? errorMessage;
  final Stream<double>? amplitudeStream;

  const EuphireRecordingIndicator({
    super.key,
    required this.isRecording,
    required this.formattedDuration,
    required this.chunkCount,
    this.errorMessage,
    this.amplitudeStream,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EuphireWaveformIndicator(isRecording: isRecording, amplitudeStream: amplitudeStream),
          const SizedBox(height: 48),
          Text(
            formattedDuration,
            style: theme.textTheme.displayLarge?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
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
      ),
    );
  }
}
