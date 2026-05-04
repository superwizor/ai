import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';
import '../services/recording_service.dart';
import '../services/upload_service.dart';
import '../widgets/euphire_header.dart';
import '../widgets/euphire_button.dart';
import '../widgets/euphire_recording_indicator.dart';
import '../providers/grpc_provider.dart';
import '../generated/ingestion/v1/ingestion.pb.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  final String patientFileId;
  final String therapistId;

  const RecordingScreen({super.key, required this.patientFileId, required this.therapistId});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  final _recorder = RecordingService();
  final _uploader = UploadService();

  String? _sessionId;
  Duration _elapsed = Duration.zero;
  int _chunkCount = 0;
  bool _uploading = false;
  String? _errorMessage;
  Timer? _timer;
  late final Stream<Amplitude> _amplitudeStream;

  @override
  void initState() {
    super.initState();
    _amplitudeStream = _recorder.amplitudeStream;
    _recorder.chunkStream.listen((chunk) {
      if (mounted) {
        setState(() => _chunkCount++);
      }
    });
  }

  Future<void> _start() async {
    try {
      _sessionId = const Uuid().v4();
      await _recorder.startRecording(_sessionId!);

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _recorder.state == RecordingState.recording) {
          setState(() {
            _elapsed += const Duration(seconds: 1);
          });
        }
      });

      setState(() => _errorMessage = null);
    } catch (e) {
      setState(() => _errorMessage = 'Błąd mikrofonu: ${e.toString()}');
    }
  }

  Future<void> _stop() async {
    setState(() => _uploading = true);

    try {
      final chunkPaths = await _recorder.stopRecording();

      // 1. Odszyfruj i połącz chunki do pliku temp (omija RAM)
      final tempFile = await _uploader.combineAndDecryptToTemp(
        chunkPaths, 
        _recorder.sessionKey!, 
        _recorder.sessionIV!
      );

      // 2. Pobierz signed URL z ingestion-svc (placeholder — gRPC call)
      final length = await tempFile.length();
      final signedUrl = await _requestSignedUrl(length);

      // 3. PUT do GCS (streamowane)
      final ok = await _uploader.uploadFileToSignedUrl(
        signedUrl: signedUrl,
        file: tempFile,
        contentType: 'audio/m4a',
      );

      // Szybko usuwamy zdekodowany bufor z dysku
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (!ok) throw Exception('Wystąpił błąd podczas wysyłania nagrania.');

      // 4. Notify ingestion-svc że upload się zakończył
      await _completeUpload(length);

      // 5. Zniszczenie dowodów (Krematorium Danych) po HTTP 200 z ingestion-svc i GCS
      await _recorder.cleanSession(_sessionId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesja została pomyślnie zapisana i wysłana.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, _sessionId);
      }
    } catch (e) {
      setState(() => _errorMessage = '${e.toString()}.');
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  String? _uploadId;

  Future<String> _requestSignedUrl(int sizeBytes) async {
    final client = ref.read(grpcClientsProvider).ingestion;
    final req = CreateAudioUploadRequest(
      patientFileId: widget.patientFileId,
      therapistId: widget.therapistId,
      estimatedSizeBytes: Int64(sizeBytes),
      contentType: 'audio/m4a',
      clientPlatform: 'flutter',
      idempotencyKey: _sessionId ?? const Uuid().v4(),
    );
    final res = await client.createAudioUpload(req);
    _uploadId = res.uploadId;
    return res.signedUrl;
  }

  Future<void> _completeUpload(int sizeBytes) async {
    if (_uploadId == null) return;
    final client = ref.read(grpcClientsProvider).ingestion;
    final res = await client.completeAudioUpload(CompleteAudioUploadRequest(
      uploadId: _uploadId!,
      actualDurationSeconds: _elapsed.inSeconds,
      actualSizeBytes: Int64(sizeBytes),
      chunkCount: _chunkCount,
    ));
    _sessionId = res.sessionId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EuphireHeader(
                title: 'Nagrywanie sesji.',
                subtitle: 'Zadbaj o spokojne warunki do rozmowy.',
              ),
              const SizedBox(height: 48),
              Expanded(
                child: EuphireRecordingIndicator(
                  isRecording: _recorder.state == RecordingState.recording,
                  formattedDuration: _formatDuration(_elapsed),
                  chunkCount: _chunkCount,
                  errorMessage: _errorMessage,
                  amplitudeStream: _amplitudeStream,
                ),
              ),
              const SizedBox(height: 24),
              if (_uploading)
                Column(
                  children: [
                    CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Szyfrowanie i wysyłanie...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                )
              else if (_recorder.state == RecordingState.idle)
                EuphireButton(
                  text: 'Rozpocznij nagrywanie',
                  onPressed: _start,
                  icon: Icons.mic,
                )
              else
                _buildControlPanel(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (_recorder.state == RecordingState.recording)
            _buildIconButton(
              icon: Icons.pause_rounded,
              label: 'Wstrzymaj',
              color: theme.colorScheme.secondary,
              onPressed: _recorder.pauseRecording,
            )
          else
            _buildIconButton(
              icon: Icons.play_arrow_rounded,
              label: 'Wznów',
              color: theme.colorScheme.primary,
              onPressed: _recorder.resumeRecording,
            ),
          
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.secondary.withValues(alpha: 0.2),
          ),

          _buildIconButton(
            icon: Icons.stop_rounded,
            label: 'Zakończ',
            color: theme.colorScheme.error,
            onPressed: _stop,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isPrimary ? color.withValues(alpha: 0.1) : Colors.transparent,
                shape: BoxShape.circle,
                border: isPrimary 
                    ? null 
                    : Border.all(color: color.withValues(alpha: 0.3), width: 2),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
