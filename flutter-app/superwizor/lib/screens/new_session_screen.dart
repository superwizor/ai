// NewSessionScreen — Etap 2b: session entry point with two paths.
//
// After selecting a modality the therapist lands here and can:
//   1. "Rozpocznij nagrywanie" → RecordingScreen (live capture)
//   2. "Wgraj plik" → file_picker → encrypt → signed URL → PUT → status
//
// File upload accepts all formats that Chirp 3 auto-decodes:
//   FLAC, WAV, MP3, OGG/OPUS, WEBM, M4A, AAC, AMR
// NO client-side conversion is required — Chirp 3 uses
// AutoDetectDecodingConfig on the backend.
//
// Visual design transplanted from Labirynt Premium:
//   • Background: Evergreen → Nocturne gradient
//   • Overline: RobotoMono (date, status labels)
//   • Headings: Montserrat SemiBold
//   • Body: Merriweather (security badge, descriptions)
//   • CTA: Ember + Ember Glow shadow, RobotoMono label
//   • Cards: Glassmorphism (White 5% bg + White 10% border)
//   • Spacing: 8px grid

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../generated/ingestion/v1/ingestion.pb.dart';
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/services_provider.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import 'recording_screen.dart';
import 'session_status_screen.dart';

/// Supported audio MIME types for file upload.
/// Chirp 3 BatchRecognize with AutoDetectDecodingConfig handles all of these.
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
  String _reportLanguage = 'pl';

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
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Language selection
                      if (!_uploading) ...[
                        Text(
                          'JĘZYK RAPORTU',
                          style: TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: EuphireColors.frostWhite.withValues(alpha: 0.5),
                            letterSpacing: 2.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: InkWell(
                            onTap: () {
                              showEuphireBottomSheet(
                                context: context,
                                builder: (BuildContext context) {
                                  return SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 16),
                                        Text(
                                          'Wybierz język',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 8),
                                        _LanguageTile(label: 'Polski', value: 'pl', current: _reportLanguage, onSelect: (v) { setState(() => _reportLanguage = v); Navigator.pop(context); }),
                                        _LanguageTile(label: 'English', value: 'en', current: _reportLanguage, onSelect: (v) { setState(() => _reportLanguage = v); Navigator.pop(context); }),
                                        _LanguageTile(label: 'Deutsch', value: 'de', current: _reportLanguage, onSelect: (v) { setState(() => _reportLanguage = v); Navigator.pop(context); }),
                                        _LanguageTile(label: 'Українська', value: 'uk', current: _reportLanguage, onSelect: (v) { setState(() => _reportLanguage = v); Navigator.pop(context); }),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: EuphireColors.frostWhite.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: EuphireColors.frostWhite.withValues(alpha: 0.1),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getLanguageLabel(_reportLanguage),
                                    style: const TextStyle(
                                      fontFamily: 'Merriweather',
                                      fontSize: 15,
                                      color: EuphireColors.frostWhite,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.keyboard_arrow_down_rounded, color: EuphireColors.ember, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

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
        reportLanguage: _reportLanguage,
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
    });

    try {
      await _encryptAndUploadFile(
        file: file,
        contentType: contentType,
        sizeBytes: sizeBytes,
      );
    } catch (e) {
      debugPrint('[file-upload] FAILED: $e');
      if (!mounted) return;
      setState(() => _uploading = false);
      _showErrorSheet('Błąd podczas przesyłania pliku:\n$e');
    }
  }

  Future<void> _encryptAndUploadFile({
    required File file,
    required String contentType,
    required int sizeBytes,
  }) async {
    final sessionId = const Uuid().v4();

    setState(() => _uploadProgress = 0.1);

    // 1. Encrypt the file using SecureAudioStorageService
    final storage = ref.read(secureAudioStorageProvider);
    final chunks = await storage.encryptRecording(
      rawPath: file.path,
      sessionId: sessionId,
    );
    debugPrint('[file-upload] encrypted: ${chunks.length} chunks');

    setState(() => _uploadProgress = 0.3);

    // 2. Decrypt to temp file for upload (same flow as recording)
    final tempForUpload = await storage.decryptToTempFile(sessionId: sessionId);
    final uploadSize = await tempForUpload.length();

    setState(() => _uploadProgress = 0.4);

    // 3. Request signed URL
    final client = ref.read(grpcClientsProvider).ingestion;
    final createRes = await client.createAudioUpload(CreateAudioUploadRequest(
      patientFileId: widget.patientFileId,
      therapistId: widget.therapistId,
      estimatedSizeBytes: Int64(uploadSize),
      contentType: contentType,
      clientPlatform: Platform.isIOS ? 'ios' : 'android',
      idempotencyKey: sessionId,
      reportLanguage: _reportLanguage,
    ));
    final uploadId = createRes.uploadId;
    final signedUrl = createRes.signedUrl;
    debugPrint('[file-upload] got signed URL (uploadId=$uploadId)');

    setState(() => _uploadProgress = 0.5);

    // 4. Upload
    final uploadOk = await ref.read(uploadServiceProvider).uploadEncryptedSession(
      sessionId: sessionId,
      signedUrl: signedUrl,
      contentType: contentType,
    );
    if (!uploadOk) throw StateError('upload failed');

    setState(() => _uploadProgress = 0.8);

    // 5. Complete upload
    final completeRes = await client.completeAudioUpload(CompleteAudioUploadRequest(
      uploadId: uploadId,
      actualDurationSeconds: 0, // unknown for uploaded files
      actualSizeBytes: Int64(uploadSize),
      chunkCount: chunks.length,
      reportLanguage: _reportLanguage,
    ));
    final completedSessionId = completeRes.sessionId;
    debugPrint('[file-upload] completeAudioUpload returned sessionId=$completedSessionId');

    await storage.purgeSession(sessionId);

    setState(() => _uploadProgress = 1.0);

    // Invalidate caches
    ref.invalidate(patientsProvider);
    ref.invalidate(sessionsProvider);

    // Clean up temp
    try {
      if (await tempForUpload.exists()) await tempForUpload.delete();
    } catch (_) {}

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SessionStatusScreen(sessionId: completedSessionId),
    ));
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
        color: const Color(0xFF0F5A56), // Nice vibrant green
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: EuphireColors.frostWhite.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Icon circle (Labirynt lock-notice pattern)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: EuphireColors.nocturne.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.shield_outlined,
                color: EuphireColors.ember.withValues(alpha: 0.6),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              'Twoje nagrania są chronione szyfrowaniem end-to-end i służą wyłącznie '
              'do analizy AI. Nikt poza Tobą nie ma dostępu do danych Twoich sesji.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: EuphireColors.frostWhite.withValues(alpha: 0.6),
                height: 1.5,
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

class _UploadProgressCard extends StatelessWidget {
  final String fileName;
  final double progress;

  const _UploadProgressCard({
    required this.fileName,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF001A1C), // Solid premium dark (Labirynt)
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
            'PRZESYŁANIE',
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
              const Icon(Icons.upload_file_rounded,
                  color: EuphireColors.ember, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName,
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
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: const AlwaysStoppedAnimation(EuphireColors.ember),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            progress < 0.3
                ? 'Szyfrowanie pliku…'
                : progress < 0.5
                    ? 'Przygotowanie do wysyłki…'
                    : progress < 0.8
                        ? 'Przesyłanie na serwer…'
                        : 'Finalizacja…',
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

class _LanguageTile extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onSelect;

  const _LanguageTile({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Merriweather',
          fontSize: 16,
          color: isSelected ? EuphireColors.ember : EuphireColors.frostWhite,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: EuphireColors.ember) : null,
      onTap: () => onSelect(value),
    );
  }
}
