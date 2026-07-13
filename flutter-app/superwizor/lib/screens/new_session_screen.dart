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
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../analytics/analytics_collector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../generated/ingestion/v1/ingestion.pb.dart' as ingestion_pb;
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../providers/patient_provider.dart';
import '../services/audio_converter_service.dart';
import '../theme/euphire_theme.dart';
import '../uploads/pending_upload.dart';
import '../uploads/upload_queue_provider.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_toast.dart';
import '../providers/services_provider.dart';
import '../services/recording_service.dart';
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

/// Extensions we transcode on-device before upload — these are enqueued
/// in UploadPhase.converting so the work is durable (see the worker's
/// phase map). WAV is normalized to 16-bit PCM (pure Dart, every
/// platform); M4A/MP4/AAC become FLAC on iOS via the AudioConverter
/// platform channel and fall back to the server transcode elsewhere.
/// Everything else is enqueued straight into UploadPhase.pending.
const Set<String> _kClientConvertExts = {'.wav', '.m4a', '.mp4', '.aac'};

/// Content types Chirp 3 europe-central2 accepts directly. Anything not in
/// this set must be routed through IngestionService.ConvertAudio before
/// CompleteAudioUpload, or the server rejects with FAILED_PRECONDITION.
/// Mirrors IsChirpSupported in ingestion-svc/internal/adapters/storage/converter.go.
const Set<String> _kChirpNativeContentTypes = {
  'audio/flac',
  'audio/wav',
  'audio/x-wav',
  'audio/ogg',
  'audio/opus',
  'audio/webm',
  'audio/amr',
  'audio/amr-wb',
};

class NewSessionScreen extends ConsumerStatefulWidget {
  final String patientFileId;
  final String therapistId;
  final String patientAlias;
  // BCP47-tagged language for the AI-generated clinical report.
  // Sourced from PatientFile.patientLanguageCode (set at create-time
  // from the patient's ui_language). Passed through to CreateAudio
  // UploadRequest + CompleteAudioUploadRequest so the server doesn't
  // have to fall back to its defensive default. Default 'pl-PL' kept
  // for the legacy-fixture path; production callers always have a real
  // value from the kartoteka.
  final String patientLanguageCode;
  // Auto-open the file picker on screen entry — used by the
  // upload-tap FAB in ClientDetailsScreen to skip the intermediate
  // "tap upload" step.
  final bool autoPickFile;

  const NewSessionScreen({
    super.key,
    required this.patientFileId,
    required this.therapistId,
    required this.patientAlias,
    this.patientLanguageCode = 'pl-PL',
    this.autoPickFile = false,
  });

  @override
  ConsumerState<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends ConsumerState<NewSessionScreen>
    with TickerProviderStateMixin {
  AppLocalizations get t => AppLocalizations.of(context);
  bool _uploading = false;
  // True only during the brief pick → stage → enqueue window, before
  // the row is durable in Hive. While true we block back-navigation
  // (PopScope) so a stray tap can't race the enqueue. The moment the
  // row is persisted we flip it false — from then on the pending-
  // uploads pill owns the session and leaving the screen is safe.
  bool _busy = false;
  String? _uploadFileName;
  String _uploadStatusLabel = '';

  // ── Smoothed progress animation ──
  // Instead of directly showing the raw upload fraction (which can jump
  // from 0 to 82% in a flash when uploading a local file), we animate
  // from a stored snapshot (_startProgress) to the new _targetProgress.
  // The duration scales with the jump size: small increments are fast,
  // big jumps (0→82%) play out over ~3 seconds so the bar fills smoothly.
  late AnimationController _smoothProgressController;
  double _displayedProgress = 0.0;
  double _startProgress = 0.0;
  double _targetProgress = 0.0;

  void _setUploadProgress(double target) {
    // Snapshot where we are RIGHT NOW so the tween is stable.
    _startProgress = _displayedProgress;
    _targetProgress = target.clamp(0.0, 1.0);

    // Duration proportional to jump size.
    // Small increments (33%→35%) ~500ms; big jumps (0→82%) ~3s.
    final delta = (_targetProgress - _startProgress).abs();
    final durationMs = (delta * 4000).clamp(300, 3500).toInt();

    _smoothProgressController.duration =
        Duration(milliseconds: durationMs);
    _smoothProgressController.forward(from: 0.0);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsCollectorProvider).track("screen.viewed", properties: {"screen_name": "NewSessionScreen"});
      if (widget.autoPickFile) {
        _pickAndUploadFile();
      }
    });
    _smoothProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        if (!mounted) return;
        // Simple tween from fixed start to fixed target — no mutation
        // of the start point, so the easing curve renders correctly.
        final easedT =
            Curves.easeOutCubic.transform(_smoothProgressController.value);
        setState(() {
          _displayedProgress =
              _startProgress + (_targetProgress - _startProgress) * easedT;
        });
      });
  }

  @override
  void dispose() {
    _smoothProgressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMMM y', Localizations.localeOf(context).toString()).format(DateTime.now());

    return PopScope(
      // Block back ONLY during the brief, indivisible stage+enqueue
      // window (_busy). Conversion no longer runs here, so this is a
      // sub-second guard that prevents a back tap from racing the Hive
      // write — not the long lock the old inline-conversion flow needed.
      canPop: !_busy,
      child: Scaffold(
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
                          widget.autoPickFile ? t.newSession_upload_file_header : t.newSession_new_session_header,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
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
                            fontFamily: 'Montserrat',
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
                  // Web/desktop: cap content to a centered column so the
                  // CTA/text don't stretch full-width. topCenter preserves
                  // the existing top-aligned layout. Self-gating — phones
                  // (width < 760) are unaffected, native unchanged.
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: _uploading && _uploadFileName != null
                          ? _buildSecureUploadView()
                          : _buildDefaultView(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ── Default view: file/record selection ──
  Widget _buildDefaultView() {
    return Column(
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

        // Description — context-aware
        Text(
          widget.autoPickFile
              ? t.newSession_pick_file_desc
              : t.newSession_record_or_upload_desc,
          style: TextStyle(
            fontFamily: 'Merriweather',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: EuphireColors.frostWhite.withValues(alpha: 0.8),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 40),

        // Security badge — only in full mode
        if (!widget.autoPickFile) _SecurityBadge(),

        const Spacer(),

        // CTA buttons — only in full mode.
        //
        // Web build flips the affordance: live audio recording isn't
        // supported in the browser (docs/18 §8.3), so file upload
        // becomes the primary path and the record CTA is hidden.
        // iOS keeps the existing record-first ordering.
        if (!widget.autoPickFile) ...[
          if (kIsWeb) ...[
            _PrimaryButton(
              icon: Icons.upload_file_rounded,
              label: t.clientDetails_upload_file_btn,
              onPressed: _pickAndUploadFile,
            ),
          ] else ...[
            _PrimaryButton(
              icon: Icons.mic_rounded,
              label: t.clientDetails_record_btn,
              onPressed: _goToRecording,
            ),
            const SizedBox(height: 12),
            _SecondaryButton(
              icon: Icons.upload_file_rounded,
              label: t.clientDetails_upload_file_btn,
              onPressed: _pickAndUploadFile,
            ),
          ],
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Secure upload view: shown while file is being uploaded ──
  Widget _buildSecureUploadView() {
    return Column(
      children: [
        const SizedBox(height: 48),

        // ── Animated Shield Icon ──
        _AnimatedShieldIcon(progress: _displayedProgress),

        const SizedBox(height: 32),

        // ── Title ──
        Text(
          t.newSession_secure_upload_title,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: EuphireColors.frostWhite,
            letterSpacing: -0.3,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // ── Security description ──
        Text(
          t.newSession_secure_upload_desc,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: EuphireColors.mist.withValues(alpha: 0.8),
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        // ── Encryption badges ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _EncryptionChip(
              icon: Icons.lock_rounded,
              label: 'E2E',
            ),
            const SizedBox(width: 12),
            _EncryptionChip(
              icon: Icons.language_rounded,
              label: 'EU',
            ),
            const SizedBox(width: 12),
            _EncryptionChip(
              icon: Icons.verified_user_rounded,
              label: 'RODO',
            ),
          ],
        ),

        const Spacer(),

        // ── Progress card at bottom ──
        _UploadProgressCard(
          fileName: _uploadFileName!,
          progress: _displayedProgress,
          statusLabel: _uploadStatusLabel,
          isActive: _displayedProgress < 1.0,
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  void _goToRecording() {
    final t = AppLocalizations.of(context);
    // Guard: block if another recording is already active.
    final svc = ref.read(recordingServiceProvider);
    if (svc.state == RecordingState.recording ||
        svc.state == RecordingState.paused ||
        svc.state == RecordingState.interrupted) {
      EuphireToast.info(context,
          message: t.newSession_recording_in_progress_err);
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RecordingScreen(
        patientFileId: widget.patientFileId,
        therapistId: widget.therapistId,
        patientAlias: widget.patientAlias,
        reportLanguage: widget.patientLanguageCode,
      ),
    ));
  }

  /// Web file upload. The browser has no filesystem path and no dart:io,
  /// so the native stage-to-disk + Hive durable-queue path can't run
  /// (it threw MissingPluginException on path_provider). Instead we read
  /// the picked file's bytes into memory and upload them directly:
  /// CreateAudioUpload (Connect/gRPC-web) → HTTP PUT to the signed URL →
  /// navigate to the server-driven status screen by sessionId. No durable
  /// queue (acceptable on web — no app-kill recovery needed).
  Future<void> _pickAndUploadFileWeb() async {
    final t = AppLocalizations.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kSupportedAudioTypes.keys
          .map((e) => e.replaceFirst('.', ''))
          .toList(),
      allowMultiple: false,
      withData: true, // web: no path — load bytes into memory
    );
    if (result == null || result.files.isEmpty) {
      if (widget.autoPickFile && mounted) Navigator.of(context).maybePop();
      return;
    }
    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      _showErrorSheet(t.common_error);
      return;
    }
    final ext = '.${(picked.extension ?? '').toLowerCase()}';
    final contentType = _kSupportedAudioTypes[ext];
    if (contentType == null) {
      if (!mounted) return;
      _showErrorSheet(
        t.newSession_format_not_supported(ext) + t.newSession_supported_formats,
      );
      return;
    }
    if (bytes.length > 500 * 1024 * 1024) {
      if (!mounted) return;
      _showErrorSheet(
        t.newSession_file_too_large((bytes.length / 1024 / 1024).toStringAsFixed(0)),
      );
      return;
    }

    ref.read(analyticsCollectorProvider).track("file_upload.picked", properties: {
      "file_extension": ext,
      "file_size_bytes": bytes.length,
    });

    setState(() {
      _uploading = true;
      _busy = true;
      _uploadFileName = picked.name;
      _displayedProgress = 0.0;
      _targetProgress = 0.0;
      _uploadStatusLabel = t.newSession_uploading_file;
    });
    _setUploadProgress(0.1);

    try {
      final ingestion = ref.read(grpcClientsProvider).ingestion;
      final created = await ingestion.createAudioUpload(
        ingestion_pb.CreateAudioUploadRequest(
          patientFileId: widget.patientFileId,
          therapistId: widget.therapistId,
          estimatedSizeBytes: Int64(bytes.length),
          contentType: contentType,
          clientPlatform: 'web',
          idempotencyKey: const Uuid().v4(),
          reportLanguage: widget.patientLanguageCode,
        ),
      );
      _setUploadProgress(0.25);

      // The signed URL pins headers (x-goog-meta-source — see ingestion
      // signer.go), so echo exactly what the server signed via
      // requiredHeaders or the PUT 403s. Content-Type must match too.
      final putHeaders = <String, String>{'Content-Type': contentType};
      created.requiredHeaders.forEach((k, v) => putHeaders[k] = v);
      final resp = await http.put(
        Uri.parse(created.signedUrl),
        headers: putHeaders,
        body: bytes,
      );
      if (resp.statusCode != 200 && resp.statusCode != 204) {
        throw 'PUT ${resp.statusCode}: ${resp.body}';
      }
      _setUploadProgress(1.0);

      if (!mounted) return;
      if (created.sessionId.isEmpty) {
        // No sessionId from the server (legacy) — bounce back; the
        // session will surface in the kartoteka as processing.
        Navigator.of(context).maybePop();
        return;
      }
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => SessionStatusScreen(sessionId: created.sessionId),
      ));
    } catch (e) {
      debugPrint('[web-upload] FAILED: $e');
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      setState(() {
        _uploading = false;
        _busy = false;
      });
      _showErrorSheet('${t.common_error}\n$e');
    }
  }

  Future<void> _pickAndUploadFile() async {
    final t = AppLocalizations.of(context);
    // Guard: block if a recording is active — uploading a file would
    // create a second session while the first is still being captured.
    final svc = ref.read(recordingServiceProvider);
    if (svc.state == RecordingState.recording ||
        svc.state == RecordingState.paused ||
        svc.state == RecordingState.interrupted) {
      if (mounted) {
        EuphireToast.info(context,
            message: t.newSession_recording_active_err);
      }
      return;
    }
    // Web has no filesystem path / dart:io staging — use the bytes-based
    // direct-upload path instead.
    if (kIsWeb) return _pickAndUploadFileWeb();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kSupportedAudioTypes.keys
          .map((e) => e.replaceFirst('.', ''))
          .toList(),
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      // User cancelled file picker — go back if in auto-pick mode
      if (widget.autoPickFile && mounted) {
        Navigator.of(context).maybePop();
      }
      return;
    }
    final picked = result.files.first;

    if (picked.path == null) {
      if (!mounted) return;
      _showErrorSheet(t.common_error);
      return;
    }

    final file = File(picked.path!);
    if (!await file.exists()) {
      if (!mounted) return;
      _showErrorSheet(t.common_error);
      return;
    }

    final ext = p.extension(picked.path!).toLowerCase();
    final contentType = _kSupportedAudioTypes[ext];
    if (contentType == null) {
      if (!mounted) return;
      _showErrorSheet(
        t.newSession_format_not_supported(ext) + t.newSession_supported_formats,
      );
      return;
    }

    final sizeBytes = await file.length();
    if (sizeBytes == 0) {
      if (!mounted) return;
      _showErrorSheet(t.common_error);
      return;
    }

    // Max 500 MB safety
    if (sizeBytes > 500 * 1024 * 1024) {
      if (!mounted) return;
      _showErrorSheet(
        t.newSession_file_too_large((sizeBytes / 1024 / 1024).toStringAsFixed(0)),
      );
      return;
    }

    ref.read(analyticsCollectorProvider).track("file_upload.picked", properties: {
      "file_extension": ext,
      "file_size_bytes": sizeBytes,
    });

    setState(() {
      _uploading = true;
      _busy = true;
      _uploadFileName = picked.name;
      _displayedProgress = 0.0;
      _targetProgress = 0.0;
      _uploadStatusLabel = t.newSession_preparing_file;
    });
    _setUploadProgress(0.05);

    try {
      await _stageAndEnqueue(file: file, originalSizeBytes: sizeBytes);
    } catch (e) {
      debugPrint('[file-upload] FAILED: $e');
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _busy = false;
      });
      _showErrorSheet(t.newSession_upload_error(e.toString()));
    }
  }

  /// Stages the picked file into a durable queue dir, enqueues a
  /// PendingUpload, and navigates to the status screen — WITHOUT
  /// running any audio conversion on this screen.
  ///
  /// This is the fix for the data-loss bug: conversion used to run as
  /// an inline `await` here, *before* any durable row existed, so
  /// leaving the "Konwertuję" screen (or an app-kill / OS cache purge
  /// mid-convert) silently dropped the whole session. Now the row is
  /// persisted to Hive the moment the file is staged, conversion is a
  /// resumable worker phase (UploadPhase.converting →
  /// UploadIo.convertSource), and the pending-uploads pill keeps
  /// tracking it even if the user navigates away. See
  /// docs/11_IPHONE_AUDIO_CONVERSION.md and the worker's phase map.
  ///
  /// Files needing an on-device transcode (iPhone M4A/MP4/AAC → FLAC,
  /// WAV → 16-bit PCM) are enqueued in phase=converting; everything
  /// already Chirp-native (or server-transcoded, e.g. MP3) goes
  /// straight into phase=pending.
  Future<void> _stageAndEnqueue({
    required File file,
    required int originalSizeBytes,
  }) async {
    final ext = p.extension(file.path).toLowerCase();
    final contentType = _kSupportedAudioTypes[ext] ?? 'audio/wav';

    // Files we transcode on-device. WAV normalization is pure Dart
    // (every platform); M4A/MP4/AAC become FLAC on iOS and fall back to
    // the server transcode elsewhere — UploadIo.convertSource decides,
    // so we route all four through the converting phase regardless of
    // platform and let the worker handle it durably.
    final needsClientConversion = _kClientConvertExts.contains(ext);

    final localId = const Uuid().v4();

    // Copy the picked file out of the OS cache (file_picker's path can
    // be purged at any time) into <docs>/queued_uploads/<localId>/ so
    // the queue can resume after an app kill. For the converting path
    // the worker rewrites sourcePath to the transcoded file inside this
    // same dir; cleanupSource deletes the whole dir on terminal-success
    // or dismiss.
    final stagedFile = await _stageForQueue(localId: localId, source: file);
    if (!mounted) return;
    _setUploadProgress(0.55);

    // Duration is format-independent, so probe the staged original once
    // here rather than re-probing post-transcode. Drives the server's
    // chunking trigger for > 19-min files (Chirp 3's word-timestamp
    // limit); the server re-probes as defense in depth, and this
    // returns 0 on any failure.
    final probedDurationSec =
        await AudioConverterService().probeDurationSeconds(stagedFile.path);
    debugPrint('[file-upload] staged localId=$localId '
        'convert=$needsClientConversion duration=${probedDurationSec}s');

    final runner = await ref.read(uploadQueueRunnerProvider.future);
    if (runner == null) {
      throw StateError('Upload queue not available — user not signed in?');
    }

    if (!mounted) return;
    setState(() => _uploadStatusLabel = t.newSession_queuing);
    _setUploadProgress(0.85);

    var pending = PendingUpload.initial(
      localId: localId,
      therapistId: widget.therapistId,
      patientFileId: widget.patientFileId,
      patientLanguageCode: widget.patientLanguageCode,
      sourceKind: UploadSourceKind.plainFile,
      sourcePath: stagedFile.path,
      contentType: contentType,
      sizeBytes: originalSizeBytes,
      chunkCount: 1,
      actualDurationSeconds: probedDurationSec,
      // For the converting path the worker recomputes this after the
      // transcode; for the direct path it's authoritative now.
      needsServerSideConversion: needsClientConversion
          ? false
          : !_kChirpNativeContentTypes.contains(contentType),
      idempotencyKey: localId,
      now: DateTime.now().toUtc(),
    );
    if (needsClientConversion) {
      pending = pending.copyWith(phase: UploadPhase.converting);
    }

    // Persist the row (durable) WITHOUT awaiting a tick — the first
    // tick on a converting row would run the (possibly minute-long)
    // transcode, and we must not block navigation on it. The row is in
    // Hive before this returns, so back-navigation / app-kill can no
    // longer lose it.
    await runner.enqueue(pending);

    if (!mounted) return;
    _setUploadProgress(1.0);
    // Past the durable point — releasing the back guard is safe; the
    // pending-uploads pill now owns this session.
    _busy = false;

    // Refresh the patient + sessions cache so the new session shows up
    // in the kartoteka once it lands server-side.
    ref.invalidate(patientsProvider);
    ref.invalidate(sessionsProvider);

    // Kick the worker in the background so conversion/upload starts
    // immediately — fire-and-forget so navigation isn't blocked on it.
    unawaited(runner.kick());

    // Navigate to the status screen. It watches the queue row by
    // localId and renders the converting → uploading → analyzing →
    // done stepper; once a server-side sessionId materialises it hands
    // off to the Firestore / clinical-svc listeners.
    await Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SessionStatusScreen(localId: localId),
    ));
  }

  /// Copies [source] into `<docs>/queued_uploads/<localId>/<basename>`
  /// and returns the new File. The staging dir is exclusive to this
  /// upload — GrpcUploadIo.cleanupSource deletes the whole dir when
  /// the upload terminates (success or failed dismiss).
  Future<File> _stageForQueue({
    required String localId,
    required File source,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final stagingRoot = Directory(p.join(docs.path, 'queued_uploads', localId));
    if (!await stagingRoot.exists()) {
      await stagingRoot.create(recursive: true);
    }
    final basename = p.basename(source.path);
    final dest = File(p.join(stagingRoot.path, basename));
    await source.copy(dest.path);
    return dest;
  }

  Future<void> _showErrorSheet(String message) async {
    final t = AppLocalizations.of(context);
    await showEuphireBottomSheet<void>(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: t.newSession_error_header,
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
    final t = AppLocalizations.of(context);
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
          Expanded(
            child: Text(
              '${t.newSession_encryption_notice_part1}${t.newSession_encryption_notice_part2}',
              style: const TextStyle(
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
                  fontFamily: 'Montserrat',
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
  final bool isActive;

  const _UploadProgressCard({
    required this.fileName,
    required this.progress,
    required this.statusLabel,
    this.isActive = true,
  });

  @override
  State<_UploadProgressCard> createState() => _UploadProgressCardState();
}

class _UploadProgressCardState extends State<_UploadProgressCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.progress * 100).toInt().clamp(0, 100);
    final isDone = widget.progress >= 0.99;

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
          // Overline with spinning indicator
          Row(
            children: [
              Text(
                AppLocalizations.of(context).clientDetails_status_processing.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: EuphireColors.frostWhite.withValues(alpha: 0.4),
                  letterSpacing: 2.0,
                ),
              ),
              if (widget.isActive && !isDone) ...[
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _spinController,
                  builder: (_, child) => Transform.rotate(
                    angle: _spinController.value * 2 * math.pi,
                    child: child,
                  ),
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: CustomPaint(
                      painter: _SpinnerPainter(
                        color: EuphireColors.ember.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ],
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
                  color: isDone ? const Color(0xFF4CAF50) : EuphireColors.ember,
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
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDone ? const Color(0xFF4CAF50) : EuphireColors.ember,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar — value is already smoothed by the parent controller
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widget.progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation(
                isDone
                    ? const Color(0xFF4CAF50)
                    : EuphireColors.ember,
              ),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 12),
          // Animated status label with wave effect
          _AnimatedStatusLabel(
            text: widget.statusLabel,
            isActive: widget.isActive && !isDone,
          ),
        ],
      ),
    );
  }
}

/// Animated status text with:
/// - Wave effect: letters gently bounce in a sine-wave pattern
/// - Animated dots: cycles through ".", "..", "..." every 600ms
class _AnimatedStatusLabel extends StatefulWidget {
  final String text;
  final bool isActive;

  const _AnimatedStatusLabel({
    required this.text,
    this.isActive = true,
  });

  @override
  State<_AnimatedStatusLabel> createState() => _AnimatedStatusLabelState();
}

class _AnimatedStatusLabelState extends State<_AnimatedStatusLabel> {
  Timer? _dotTimer;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted) return;
      setState(() => _dotCount = (_dotCount % 3) + 1);
    });
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Split the label into base text and dots
    final hasTrailingDots = widget.text.endsWith('...');
    final baseText = hasTrailingDots
        ? widget.text.substring(0, widget.text.length - 3)
        : widget.text;
    final animatedDots = widget.isActive && hasTrailingDots
        ? '.' * _dotCount
        : (hasTrailingDots ? '...' : '');

    return Text(
      '$baseText$animatedDots',
      style: TextStyle(
        fontFamily: 'Merriweather',
        fontSize: 12,
        color: EuphireColors.frostWhite.withValues(alpha: 0.5),
        height: 1.5,
      ),
    );
  }
}

/// Custom painter for a small arc-based spinner.
class _SpinnerPainter extends CustomPainter {
  final Color color;

  _SpinnerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final rect = Offset.zero & size;
    // Draw a 270° arc — the remaining 90° gap creates the spinner effect
    canvas.drawArc(rect, 0, math.pi * 1.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter old) => color != old.color;
}

/// Animated shield icon with progress ring and pulsing glow.
class _AnimatedShieldIcon extends StatefulWidget {
  final double progress;

  const _AnimatedShieldIcon({required this.progress});

  @override
  State<_AnimatedShieldIcon> createState() => _AnimatedShieldIconState();
}

class _AnimatedShieldIconState extends State<_AnimatedShieldIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.progress >= 1.0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, _) {
        final glowOpacity = isDone
            ? 0.35
            : 0.1 + (_pulseController.value * 0.15);
        final scale = isDone
            ? 1.0
            : 1.0 + (_pulseController.value * 0.03);

        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: EuphireColors.ember.withValues(alpha: glowOpacity),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                // Progress ring
                SizedBox(
                  width: 110,
                  height: 110,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: widget.progress),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    builder: (_, value, _) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(
                        isDone
                            ? const Color(0xFF4CAF50)
                            : EuphireColors.ember,
                      ),
                    ),
                  ),
                ),
                // Inner circle with shield icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(
                    isDone
                        ? Icons.check_rounded
                        : Icons.shield_rounded,
                    size: 40,
                    color: isDone
                        ? const Color(0xFF4CAF50)
                        : EuphireColors.ember,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Small pill-shaped badge for encryption/compliance features.
class _EncryptionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EncryptionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: EuphireColors.ember),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: EuphireColors.mist,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
