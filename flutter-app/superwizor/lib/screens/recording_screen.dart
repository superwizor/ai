import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      patientFileId: '67daa161-23dc-4613-b613-1067b7d94357', // valid DB id
      therapistId: '6e8af866-08bc-41b9-89c2-2b5b15d2c665', // valid DB id
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
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
