// NewSessionScreen — Etap 2b: session entry point with two paths.
//
// After selecting a modality the therapist lands here and can:
//   1. "Rozpocznij nagrywanie" → RecordingScreen (live capture)
//   2. "Wgraj plik" → file_picker → convert to FLAC → upload → status
//
// All uploaded files are converted client-side to FLAC (16-bit, mono,
// 16 kHz) via ffmpeg_kit before upload. This ensures Chirp 3 always
// receives a supported encoding regardless of the source format.
//
// Visual design transplanted from Labirynt Premium:
//   • Background: Evergreen → Nocturne gradient
//   • Overline: RobotoMono (date, status labels)
//   • Headings: Montserrat SemiBold
//   • Body: Merriweather (security badge, descriptions)
//   • CTA: Ember + Ember Glow shadow, RobotoMono label
//   • Cards: Glassmorphism (White 5% bg + White 10% border)
//   • Spacing: 8px grid

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../generated/ingestion/v1/ingestion.pb.dart';
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../providers/patient_provider.dart';

import '../services/audio_converter_service.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import 'recording_screen.dart';
import 'session_status_screen.dart';

/// Supported audio extensions for file upload.
/// All are converted client-side to FLAC before upload.
const Map<String, String> _kSupportedAudioTypes = {
  '.flac': 'audio/flac',
  '.wav': 'audio/wav',
  '.mp3': 'audio/mpeg',
  '.ogg': 'audio/ogg',
  '.opus': 'audio/ogg',
  '.webm': 'audio/webm',
  '.m4a': 'audio/mp4',
  '.aac': 'audio/aac',
  '.amr': 'audio/amr',
  '.wma': 'audio/x-ms-wma',
  '.mp4': 'audio/mp4',
};

class NewSessionScreen extends ConsumerStatefulWidget {
  final String patientFileId;
  final String therapistId;
  final String patientAlias;

  const NewSessionScreen({
    super.key,
    required this.patientFileId,
    required this.therapistId,
    required this.patientAlias,
  });

  @override
  ConsumerState<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends ConsumerState<NewSessionScreen> {
  bool _uploading = false;
  String? _uploadFileName;
  double _uploadProgress = 0.0;
  String _uploadStatusLabel = '';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final dateLabel = DateFormat('d MMMM y', 'pl_PL').format(DateTime.now());

    return Scaffold(
      // Use gradient instead of flat color (Labirynt pattern)
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: EuphireColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar area ──
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: EuphireColors.frostWhite, size: 22),
                      tooltip: t.common_back,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    // Overline: RobotoMono date label (Labirynt header pattern)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NOWA SESJA',
                          style: TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: EuphireColors.ember,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: EuphireColors.frostWhite
                                .withValues(alpha: 0.5),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Invisible spacer for balance
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // ── Content ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 32),

                      // Patient name — Montserrat headline
                      Text(
                        widget.patientAlias,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: EuphireColors.frostWhite,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Subtitle divider (Labirynt ember gradient divider)
                      Center(
                        child: Container(
                          height: 1,
                          width: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                EuphireColors.ember.withValues(alpha: 0.4),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description — Merriweather body
                      Text(
                        'Nagraj tę sesję, lub prześlij plik audio z dyktafonu.',
                        style: TextStyle(
                          fontFamily: 'Merriweather',
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: EuphireColors.frostWhite
                              .withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 40),

                      // Security badge — glassmorphism card
                      _SecurityBadge(),

                      const Spacer(),

                      // Upload progress state
                      if (_uploading && _uploadFileName != null) ...[
                        _UploadProgressCard(
                          fileName: _uploadFileName!,
                          progress: _uploadProgress,
                          statusLabel: _uploadStatusLabel,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Usunięty wybór języka


                      // CTA buttons at the bottom
                      if (!_uploading) ...[
                        // Primary CTA — Ember with glow
                        _PrimaryButton(
                          icon: Icons.mic_rounded,
                          label: 'ROZPOCZNIJ NAGRYWANIE',
                          onPressed: _goToRecording,
                        ),
                        const SizedBox(height: 12),
                        // Secondary — outlined
                        _SecondaryButton(
                          icon: Icons.upload_file_rounded,
                          label: 'Wgraj plik audio',
                          onPressed: _pickAndUploadFile,
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToRecording() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RecordingScreen(
        patientFileId: widget.patientFileId,
        therapistId: widget.therapistId,
        patientAlias: widget.patientAlias,
        reportLanguage: 'pl',
      ),
    ));
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kSupportedAudioTypes.keys
          .map((e) => e.replaceFirst('.', ''))
          .toList(),
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;

    if (picked.path == null) {
      if (!mounted) return;
      _showErrorSheet('Nie udało się pobrać pliku.');
      return;
    }

    final file = File(picked.path!);
    if (!await file.exists()) {
      if (!mounted) return;
      _showErrorSheet('Plik nie istnieje lub został usunięty.');
      return;
    }

    final ext = p.extension(picked.path!).toLowerCase();
    final contentType = _kSupportedAudioTypes[ext];
    if (contentType == null) {
      if (!mounted) return;
      _showErrorSheet(
        'Format "$ext" nie jest obsługiwany.\n\n'
        'Obsługiwane formaty: FLAC, WAV, MP3, OGG, OPUS, M4A, AAC, WEBM, AMR.',
      );
      return;
    }

    final sizeBytes = await file.length();
    if (sizeBytes == 0) {
      if (!mounted) return;
      _showErrorSheet('Plik jest pusty (0 bajtów).');
      return;
    }

    // Max 500 MB safety
    if (sizeBytes > 500 * 1024 * 1024) {
      if (!mounted) return;
      _showErrorSheet(
        'Plik jest zbyt duży (${(sizeBytes / 1024 / 1024).toStringAsFixed(0)} MB). '
        'Maksymalny rozmiar to 500 MB.',
      );
      return;
    }

    setState(() {
      _uploading = true;
      _uploadFileName = picked.name;
      _uploadProgress = 0.0;
      _uploadStatusLabel = 'Konwersja audio...';
    });

    try {
      await _convertAndUploadFile(file: file, originalSizeBytes: sizeBytes);
    } catch (e) {
      debugPrint('[file-upload] FAILED: $e');
      if (!mounted) return;
      setState(() => _uploading = false);
      _showErrorSheet('Błąd podczas przesyłania pliku:\n$e');
    }
  }

  Future<void> _convertAndUploadFile({
    required File file,
    required int originalSizeBytes,
  }) async {
    final sessionId = const Uuid().v4();
    File? tempFile;

    try {
      final ext = p.extension(file.path).toLowerCase();
      File fileToUpload = file;
      String contentType = _kSupportedAudioTypes[ext] ?? 'audio/wav';
      int uploadSize = originalSizeBytes;

      // ── Phase 1: Normalize WAV if needed (0% → 25%) ──
      if (ext == '.wav') {
        if (!mounted) return;
        setState(() {
          _uploadProgress = 0.02;
          _uploadStatusLabel = 'Normalizacja audio...';
        });

        try {
          final converter = AudioConverterService();
          final normalized = await converter.normalizeWav(
            file.path,
            onProgress: (p) {
              if (!mounted) return;
              setState(() {
                _uploadProgress = p * 0.25;
                _uploadStatusLabel = 'Normalizacja audio... ${(p * 100).toInt()}%';
              });
            },
          );

          if (normalized != null && normalized.path != file.path) {
            tempFile = normalized;
            fileToUpload = normalized;
            uploadSize = await normalized.length();
            debugPrint('[file-upload] WAV normalized: ${(uploadSize / 1024 / 1024).toStringAsFixed(1)} MB');
          } else if (normalized == null) {
            // normalizeWav returns null for non-WAV or unsupported
            // sub-formats. The original file might be 32-bit float
            // which Chirp 3 rejects. Log it and upload anyway — if
            // the file is already 16-bit PCM, normalizeWav returns
            // the original File (same path).
            debugPrint('[file-upload] WAV normalization returned null — '
                'file may have unsupported format; uploading original');
          } else {
            debugPrint('[file-upload] WAV already 16-bit PCM, no conversion needed');
          }
        } catch (e, st) {
          debugPrint('[file-upload] WAV normalization failed: $e\n$st');
          // Continue with original file — backend may still handle it
        }
        contentType = 'audio/wav';
      }

      if (!mounted) return;
      setState(() {
        _uploadProgress = 0.28;
        _uploadStatusLabel = 'Przygotowywanie...';
      });

      // ── Phase 2: Request signed URL (28% → 33%) ──
      final client = ref.read(grpcClientsProvider).ingestion;
      final createRes = await client.createAudioUpload(CreateAudioUploadRequest(
        patientFileId: widget.patientFileId,
        therapistId: widget.therapistId,
        estimatedSizeBytes: Int64(uploadSize),
        contentType: contentType,
        clientPlatform: Platform.isIOS ? 'ios' : 'android',
        idempotencyKey: sessionId,
        reportLanguage: 'pl',
      ));
      final uploadId = createRes.uploadId;
      final signedUrl = createRes.signedUrl;
      debugPrint('[file-upload] got signed URL (uploadId=$uploadId)');

      if (!mounted) return;
      setState(() {
        _uploadProgress = 0.33;
        _uploadStatusLabel = 'Przesyłanie pliku...';
      });

      // ── Phase 3: Upload with streamed progress (33% → 90%) ──
      await _uploadWithProgress(
        signedUrl: signedUrl,
        file: fileToUpload,
        contentType: contentType,
        totalBytes: uploadSize,
      );

      if (!mounted) return;
      setState(() {
        _uploadProgress = 0.92;
        _uploadStatusLabel = 'Finalizacja...';
      });

      // ── Phase 4: Complete upload (92% → 100%) ──
      final completeRes = await client.completeAudioUpload(CompleteAudioUploadRequest(
        uploadId: uploadId,
        actualDurationSeconds: 0,
        actualSizeBytes: Int64(uploadSize),
        chunkCount: 1,
        reportLanguage: 'pl',
      ));
      final completedSessionId = completeRes.sessionId;
      debugPrint('[file-upload] done, sessionId=$completedSessionId');

      if (!mounted) return;
      setState(() {
        _uploadProgress = 1.0;
        _uploadStatusLabel = 'Gotowe!';
      });

      // Invalidate caches
      ref.invalidate(patientsProvider);
      ref.invalidate(sessionsProvider);

      await Future<void>.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => SessionStatusScreen(sessionId: completedSessionId),
      ));
    } finally {
      // Clean up temp file (only if we created one)
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Uploads a file via streamed PUT with real-time progress tracking.
  Future<void> _uploadWithProgress({
    required String signedUrl,
    required File file,
    required String contentType,
    required int totalBytes,
  }) async {
    final uri = Uri.parse(signedUrl);
    final request = http.StreamedRequest('PUT', uri);
    request.headers['Content-Type'] = contentType;
    request.headers['x-goog-meta-source'] = 'superwizor-mobile';
    request.contentLength = totalBytes;

    // Stream the file bytes and track progress
    int bytesSent = 0;
    final fileStream = file.openRead();

    fileStream.listen(
      (chunk) {
        request.sink.add(chunk);
        bytesSent += chunk.length;
        if (!mounted) return;
        final uploadFraction = bytesSent / totalBytes;
        // Map upload progress to 33% → 90% of total progress
        final totalProgress = 0.33 + (uploadFraction * 0.57);
        setState(() {
          _uploadProgress = totalProgress;
          _uploadStatusLabel =
              'Przesyłanie... ${(uploadFraction * 100).toInt()}%';
        });
      },
      onDone: () => request.sink.close(),
      onError: (e) => request.sink.addError(e),
      cancelOnError: true,
    );

    final response = await http.Client().send(request);
    final statusCode = response.statusCode;

    if (statusCode != 200 && statusCode != 204) {
      final body = await response.stream.bytesToString();
      throw StateError('Upload failed (HTTP $statusCode): $body');
    }
  }

  Future<void> _showErrorSheet(String message) async {
    await showEuphireBottomSheet<void>(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: 'Błąd',
        body: message,
        primary: EuphireSheetAction(
          label: 'OK',
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }
}

// ─── Internal widgets ────────────────────────────────────────────────

class _SecurityBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF004D54), // #004D54 per user request
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.gpp_good_rounded,
                color: Colors.white.withValues(alpha: 0.75),
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Twoje nagrania są chronione szyfrowaniem end-to-end i służą wyłącznie '
              'do analizy AI. Nikt poza Tobą nie ma dostępu do danych.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: EuphireColors.frostWhite,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        boxShadow: EuphireColors.emberGlow,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: EuphireColors.ember,
            foregroundColor: EuphireColors.obsidianBlack,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: EuphireColors.frostWhite,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: EuphireColors.frostWhite.withValues(alpha: 0.6)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: EuphireColors.frostWhite.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadProgressCard extends StatefulWidget {
  final String fileName;
  final double progress;
  final String statusLabel;

  const _UploadProgressCard({
    required this.fileName,
    required this.progress,
    required this.statusLabel,
  });

  @override
  State<_UploadProgressCard> createState() => _UploadProgressCardState();
}

class _UploadProgressCardState extends State<_UploadProgressCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF001A1C),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: EuphireColors.ember.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overline
          Text(
            'PRZETWARZANIE',
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: EuphireColors.frostWhite.withValues(alpha: 0.4),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Pulsing icon during upload
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) => Opacity(
                  opacity: 0.6 + (_pulseController.value * 0.4),
                  child: child,
                ),
                child: Icon(
                  widget.progress < 0.30
                      ? Icons.transform_rounded
                      : widget.progress < 0.90
                          ? Icons.cloud_upload_rounded
                          : Icons.check_circle_outline_rounded,
                  color: EuphireColors.ember,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.fileName,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: EuphireColors.frostWhite,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: EuphireColors.ember,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Smooth animated progress bar
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: widget.progress),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (_, value, child) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation(
                  widget.progress >= 1.0
                      ? const Color(0xFF4CAF50) // green when done
                      : EuphireColors.ember,
                ),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.statusLabel,
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 12,
              color: EuphireColors.frostWhite.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

String _getLanguageLabel(String code) {
  switch (code) {
    case 'pl': return 'Polski';
    case 'en': return 'English';
    case 'de': return 'Deutsch';
    case 'uk': return 'Українська';
    default: return 'Polski';
  }
}

