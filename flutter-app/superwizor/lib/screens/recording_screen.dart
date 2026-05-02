import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/recording_service.dart';
import '../services/upload_service.dart';
import '../widgets/euphire_header.dart';
import '../widgets/euphire_button.dart';
import '../widgets/euphire_recording_indicator.dart';

class RecordingScreen extends StatefulWidget {
  final String patientFileId;
  final String therapistId;

  const RecordingScreen({super.key, required this.patientFileId, required this.therapistId});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final _recorder = RecordingService();
  final _uploader = UploadService();

  String? _sessionId;
  Duration _elapsed = Duration.zero;
  int _chunkCount = 0;
  bool _uploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _recorder.chunkStream.listen((chunk) {
      if (mounted) {
        setState(() => _chunkCount++);
      }
    });
  }

  Future<void> _start() async {
    _sessionId = const Uuid().v4();
    await _recorder.startRecording(_sessionId!);

    // Update timer co sekundę
    Stream.periodic(const Duration(seconds: 1)).take(7200).listen((tick) {
      if (mounted && _recorder.state == RecordingState.recording) {
        setState(() => _elapsed = Duration(seconds: tick + 1));
      }
    });

    setState(() {});
  }

  Future<void> _stop() async {
    setState(() => _uploading = true);

    try {
      final chunkPaths = await _recorder.stopRecording();

      // 1. Połącz chunki w jeden plik (w prod: native ffmpeg)
      final combined = await _uploader.combineChunks(chunkPaths);

      // 2. Pobierz signed URL z ingestion-svc (placeholder — gRPC call)
      // TODO: prawdziwe gRPC wywołanie, dla przykładu hardcoded
      final signedUrl = await _requestSignedUrl(combined.length);

      // 3. PUT do GCS
      final ok = await _uploader.uploadToSignedUrl(
        signedUrl: signedUrl,
        audioBytes: combined,
        contentType: 'audio/m4a',
      );

      if (!ok) throw Exception('Wystąpił błąd podczas wysyłania nagrania.');

      // 4. Notify ingestion-svc że upload się zakończył
      await _completeUpload();

      // 5. Zniszczenie dowodów (Krematorium Danych) po HTTP 200 z ingestion-svc i GCS
      await _recorder.cleanSession(_sessionId!);

      if (mounted) {
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

  Future<String> _requestSignedUrl(int sizeBytes) async {
    // TODO: real gRPC call do ingestion-svc.CreateAudioUpload
    throw UnimplementedError('Funkcja nie została zaimplementowana.');
  }

  Future<void> _completeUpload() async {
    // TODO: real gRPC call do ingestion-svc.CompleteAudioUpload
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
                ),
              ),
              const SizedBox(height: 24),
              if (_uploading)
                const Center(child: CircularProgressIndicator())
              else if (_recorder.state == RecordingState.idle)
                EuphireButton(
                  text: 'Rozpocznij nagrywanie.',
                  onPressed: _start,
                )
              else
                Column(
                  children: [
                    if (_recorder.state == RecordingState.recording)
                      EuphireButton(
                        text: 'Wstrzymaj.',
                        onPressed: _recorder.pauseRecording,
                      )
                    else
                      EuphireButton(
                        text: 'Wznów nagrywanie.',
                        onPressed: _recorder.resumeRecording,
                      ),
                    const SizedBox(height: 16),
                    EuphireButton(
                      text: 'Zakończ i wyślij.',
                      onPressed: _stop,
                    ),
                  ],
                ),
            ],
          ),
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
    _recorder.dispose();
    super.dispose();
  }
}
