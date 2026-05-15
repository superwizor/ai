// RecordingScreen — Etap 3 (Sesja w toku).
//
// Flow:
//   1. user lands here from patient detail with `patientFileId` and
//      `therapistId`
//   2. ConsentService.hasConsent() second-line check; missing → show
//      "Brak zgody" sheet, pop back
//   3. Generate sessionId, start RecordingService (FLAC @ 16 kHz mono)
//   4. UI shows waveform + counter + instructions block
//   5. Stop button:
//        < 5 min → "Nagranie zbyt krótkie" sheet, recording continues
//        ≥ 5 min → "Zakończenie i analiza sesji" sheet (3 actions)
//   6. At 130 min → auto-pause + persist PENDING_UPLOAD + show
//      "Limit czasu" sheet
//   7. After confirmation: encrypt → request signed URL → PUT →
//      CompleteAudioUpload → pop with sessionId so caller can route
//      to status stepper screen

import 'dart:async';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../generated/ingestion/v1/ingestion.pb.dart';
import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/services_provider.dart';
import '../services/recording_service.dart';
import '../services/secure_audio_storage_service.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_action_sheet.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_button.dart';
import '../widgets/euphire_recording_indicator.dart';
import 'session_status_screen.dart';

// TODO(pre-prod): restore to Duration(minutes: 5) before TestFlight.
// Lowered to 30s for end-to-end smoke testing on real device — saves us
// ~5 min per pipeline test cycle. The < 5 min "Nagranie zbyt krótkie"
// sheet behavior is exercised separately in widget tests.
const Duration kMinSessionDuration = Duration(seconds: 30);
const Duration kMaxSessionDuration = Duration(minutes: 130); // D5

class RecordingScreen extends ConsumerStatefulWidget {
  final String patientFileId;
  final String therapistId;
  final String patientAlias;
  final String reportLanguage;

  const RecordingScreen({
    super.key,
    required this.patientFileId,
    required this.therapistId,
    required this.patientAlias,
    required this.reportLanguage,
  });

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  String? _sessionId;
  Duration _displayDuration = Duration.zero;
  RecordingState _recState = RecordingState.idle;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<RecordingState>? _stateSub;
  bool _uploading = false;
  bool _maxLimitTriggered = false;
  String? _uploadId;
  int _chunkCount = 0;

  RecordingService get _service => ref.read(recordingServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifyConsentAndStart());
  }

  @override
  void dispose() {
    _durSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _verifyConsentAndStart() async {
    final consent =
        await ref.read(consentServiceProvider).hasConsent(patientFileId: widget.patientFileId);
    if (!consent) {
      if (!mounted) return;
      final t = AppLocalizations.of(context)!;
      final granted = await showEuphireBottomSheet<bool>(
        context: context,
        builder: (ctx) => EuphireActionSheet(
          header: 'Brak zgody',
          body: 'Nie odnotowano zgody pacjenta w systemie. Czy pacjent wyraził zgodę na nagrywanie i przetwarzanie danych?',
          primary: EuphireSheetAction(
            label: 'Tak, wyraził zgode',
            onPressed: () async {
              try {
                await ref.read(consentServiceProvider).recordConsent(
                  patientFileId: widget.patientFileId,
                  documentVersion: 'v1.0',
                );
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                if (ctx.mounted) Navigator.of(ctx).pop(false);
              }
            },
          ),
          secondary: EuphireSheetAction(
            label: t.common_cancel,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
      );
      if (granted != true && mounted) {
        Navigator.of(context).pop();
      } else if (granted == true && mounted) {
        await _start();
      }
      return;
    }
    // Auto-start recording
    await _start();
  }

  /// Pre-flight permission check before kicking off the recorder.
  /// Returns true on granted, false if the user declined (caller pops).
  ///
  /// On iOS 26+ `permission_handler` sometimes returns stale
  /// `permanentlyDenied` BEFORE iOS sees the request — meaning the
  /// OS-native dialog never fires and the per-app Microphone toggle
  /// in Settings never appears. We bypass that by calling the
  /// `record` package's `hasPermission()` directly (it routes to
  /// `AVAudioApplication.requestRecordPermission`, which is the
  /// canonical iOS native call). `permission_handler` is only used
  /// as a fallback when the native call says no, so we can still
  /// detect denial and show "Open Settings" with a recovery path.
  Future<bool> _ensureMicPermission() async {
    final recorder = AudioRecorder();
    try {
      final granted = await recorder.hasPermission();
      debugPrint('[recording] native mic permission: granted=$granted');
      if (granted) return true;
    } finally {
      await recorder.dispose();
    }

    // Native call returned false. Fall back to permission_handler so
    // we can distinguish "user just tapped Don't Allow" (recoverable
    // via Settings) from "first-time refusal" (already shown the OS
    // dialog above).
    final fallback = await Permission.microphone.request();
    debugPrint('[recording] permission_handler fallback: $fallback');
    if (fallback.isGranted) return true;

    if (!mounted) return false;
    await _showMicDeniedSheet();
    if (!mounted) return false;
    Navigator.of(context).pop();
    return false;
  }

  Future<void> _showMicDeniedSheet() async {
    final t = AppLocalizations.of(context);
    await showEuphireBottomSheet<void>(
      context: context,
      isDismissible: false,
      builder: (ctx) => EuphireActionSheet(
        header: t.recording_mic_denied_header,
        body: t.recording_mic_denied_body,
        primary: EuphireSheetAction(
          label: t.recording_mic_denied_open_settings,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await openAppSettings();
          },
        ),
        secondary: EuphireSheetAction(
          label: t.recording_mic_denied_cancel,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  Future<void> _start() async {
    final ok = await _ensureMicPermission();
    if (!ok) return;
    try {
      _sessionId = const Uuid().v4();
      await _service.start(_sessionId!);

      _durSub = _service.durationStream.listen((d) {
        if (!mounted) return;
        setState(() => _displayDuration = d);
        // Sanity: if we ever see an unrealistic value (clock jump,
        // stale state), log and bail BEFORE auto-firing the max-duration
        // sheet. The cap is 130 min — anything north of that is broken.
        if (!_maxLimitTriggered &&
            d >= kMaxSessionDuration &&
            d < const Duration(hours: 4)) {
          _maxLimitTriggered = true;
          debugPrint('[recording] max duration reached at $d');
          _onMaxDurationReached();
        } else if (d >= const Duration(hours: 4)) {
          debugPrint(
              '[recording] WARNING insane duration $d ignored — clock jump?');
        }
      });
      _stateSub = _service.stateStream.listen((s) {
        if (!mounted) return;
        setState(() => _recState = s);
      });
      setState(() => _recState = _service.state);
    } catch (e) {
      if (!mounted) return;
      await showEuphireBottomSheet<void>(
        context: context,
        builder: (ctx) => EuphireActionSheet(
          header: 'Błąd mikrofonu',
          body: e.toString(),
          primary: EuphireSheetAction(
            label: 'OK',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Back-button gate: if we're actively recording or paused, ask
  /// the user before throwing away the session. Returns whether the
  /// pop should proceed.
  Future<bool> _confirmDiscardOnBack() async {
    if (_recState == RecordingState.idle ||
        _recState == RecordingState.stopped ||
        _recState == RecordingState.error) {
      return true; // nothing to discard
    }
    final t = AppLocalizations.of(context);
    final result = await showEuphireBottomSheet<bool>(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: t.recording_discard_confirm_header,
        body: t.recording_discard_confirm_body,
        secondary: EuphireSheetAction(
          label: t.recording_discard_confirm_secondary,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        primary: EuphireSheetAction(
          label: t.recording_discard_confirm_destructive,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ),
    );
    if (result == true) {
      await _service.cancel();
      return true;
    }
    return false;
  }

  // ---------- stop / pause logic per Etap 3 ----------

  Future<void> _onStopPressed() async {
    debugPrint('[recording] _onStopPressed dur=${_service.currentDuration}');
    final t = AppLocalizations.of(context);
    final dur = _service.currentDuration;
    if (dur < kMinSessionDuration) {
      // Stop button doesn't actually stop — recording continues.
      await showEuphireBottomSheet<void>(
        context: context,
        builder: (ctx) => EuphireActionSheet(
          header: t.recording_too_short_header,
          body: t.recording_too_short_body,
          primary: EuphireSheetAction(
            label: t.recording_too_short_primary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          destructive: EuphireSheetAction(
            label: t.recording_too_short_destructive,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _discardAndPop();
            },
          ),
        ),
      );
      return;
    }

    // ≥ 5 min → pause and confirm.
    await _service.pause();
    await _showConfirmEndSheet();
  }

  Future<void> _showConfirmEndSheet() async {
    final t = AppLocalizations.of(context);
    await showEuphireBottomSheet<void>(
      context: context,
      isDismissible: false,
      builder: (ctx) => EuphireActionSheet(
        topIcon: Icons.cloud_upload_outlined,
        header: t.recording_confirm_end_header,
        body: t.recording_confirm_end_body,
        primary: EuphireSheetAction(
          label: t.recording_confirm_end_primary,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _finishAndUpload();
          },
        ),
        secondary: EuphireSheetAction(
          label: t.recording_confirm_end_secondary,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _service.resume();
          },
        ),
        destructive: EuphireSheetAction(
          label: t.recording_confirm_end_destructive,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _discardAndPop();
          },
        ),
      ),
    );
  }

  Future<void> _onMaxDurationReached() async {
    debugPrint(
        '[recording] _onMaxDurationReached dur=${_service.currentDuration}');
    await _service.pause();
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    await showEuphireBottomSheet<void>(
      context: context,
      isDismissible: false,
      builder: (ctx) => EuphireActionSheet(
        topIcon: Icons.cloud_upload_outlined,
        header: t.recording_max_duration_header,
        body: t.recording_max_duration_body,
        primary: EuphireSheetAction(
          label: t.recording_max_duration_primary,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _finishAndUpload();
          },
        ),
        destructive: EuphireSheetAction(
          label: t.recording_max_duration_destructive,
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _discardAndPop();
          },
        ),
      ),
    );
  }

  Future<void> _discardAndPop() async {
    await _service.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  // ---------- finish + upload ----------

  Future<void> _finishAndUpload() async {
    debugPrint(
        '[recording] _finishAndUpload entered; '
        'currentDuration=${_service.currentDuration} '
        'displayDuration=$_displayDuration recState=$_recState');

    // Defensive: refuse to upload absurdly short recordings. The legitimate
    // flow takes you through "Zakończenie i analiza sesji" sheet which
    // requires ≥ 5 min via _onStopPressed, OR the 130-min auto-cap. If we
    // get here with < 30s, something has misfired (stale state, double
    // tap on a hidden control, race after permission denial). Better to
    // bail loudly than ship a 0-byte audio to the backend.
    final realDuration = _service.currentDuration;
    if (realDuration < const Duration(seconds: 5)) {
      debugPrint(
          '[recording] _finishAndUpload aborted: duration too short ($realDuration)');
      if (mounted) {
        setState(() => _uploading = false);
        await showEuphireBottomSheet<void>(
          context: context,
          builder: (ctx) => EuphireActionSheet(
            header: 'Nagranie jest za krótkie',
            body: 'Nagranie trwało $realDuration. Anulowano wysyłkę.',
            primary: EuphireSheetAction(
              label: 'OK',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _uploading = true);
    final sessionId = _sessionId ?? const Uuid().v4();
    try {
      final rawPath = await _service.stop();
      if (rawPath == null) throw StateError('no recording produced');
      // Log the actual file size so we can diagnose the iOS pause→stop
      // empty-file bug if it returns. A healthy 30s OPUS @ 60 kbps file
      // should be ~225 KB (60_000 bps × 30 s ÷ 8).
      final rawSize = await File(rawPath).length();
      debugPrint('[recording] stopped, raw=$rawPath size=${rawSize}B');
      if (rawSize == 0) {
        throw StateError('recording file is empty (0 bytes) — iOS encoder failed to flush');
      }

      final storage = ref.read(secureAudioStorageProvider);
      final chunks = await storage.encryptRecording(
        rawPath: rawPath,
        sessionId: sessionId,
      );
      _chunkCount = chunks.length;
      debugPrint('[recording] encrypted: ${chunks.length} chunks');
      // Calculate exact plaintext size from chunk metadata — no
      // decryption needed.  Each .enc file has 29 bytes of overhead
      // (13 header + 16 GCM tag), so plaintext = Σ(chunk.size - 29).
      //
      // OLD CODE (removed): the previous implementation did a full
      // decryptToTempFile() → .length() → delete(), only to get this
      // number.  That was a double-decrypt anti-pattern because
      // uploadEncryptedSession() internally calls decryptToTempFile()
      // again.  Two AES-GCM passes + two full disk writes for a single
      // upload — wasteful and the root cause of the PathNotFound crash
      // (the first decrypt hit a non-existent temp directory on macOS).
      final length = SecureAudioStorageService.estimateDecryptedSize(chunks);
      debugPrint('[recording] estimated decrypted size=${length}B '
          '(${chunks.length} chunks, ${(length / 1024 / 1024).toStringAsFixed(1)} MB)');

      final signedUrl = await _requestSignedUrl(length);
      debugPrint('[recording] got signed URL (uploadId=$_uploadId)');

      final uploadOk = await ref.read(uploadServiceProvider).uploadEncryptedSession(
            sessionId: sessionId,
            signedUrl: signedUrl,
            contentType: 'audio/flac',
          );
      debugPrint('[recording] PUT result: uploadOk=$uploadOk');
      if (!uploadOk) throw StateError('upload failed');

      debugPrint('[recording] calling completeAudioUpload uploadId=$_uploadId len=$length');
      final completedSessionId = await _completeUpload(length);
      debugPrint('[recording] completeAudioUpload returned sessionId=$completedSessionId');
      await storage.purgeSession(sessionId);

      // Invalidate patient + session caches so the home screen shows
      // the new session count (and the patient's session list reflects
      // the freshly-created session) the next time the user visits.
      // Without this, patientsProvider's per-patient count stays at
      // its pre-recording value until next login.
      ref.invalidate(patientsProvider);
      ref.invalidate(sessionsProvider);

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => SessionStatusScreen(sessionId: completedSessionId),
      ));
    } catch (e, st) {
      debugPrint('[recording] _finishAndUpload FAILED: $e\n$st');
      if (mounted) {
        setState(() => _uploading = false);
        await showEuphireBottomSheet<void>(
          context: context,
          builder: (ctx) => EuphireActionSheet(
            header: 'Błąd uploadu',
            body: e.toString(),
            primary: EuphireSheetAction(
              label: 'OK',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        );
      }
    }
  }

  Future<String> _requestSignedUrl(int sizeBytes) async {
    final client = ref.read(grpcClientsProvider).ingestion;
    final res = await client.createAudioUpload(CreateAudioUploadRequest(
      patientFileId: widget.patientFileId,
      therapistId: widget.therapistId,
      estimatedSizeBytes: Int64(sizeBytes),
      contentType: 'audio/flac',
      clientPlatform: Platform.isIOS
          ? 'ios'
          : Platform.isMacOS
              ? 'macos'
              : Platform.isAndroid
                  ? 'android'
                  : 'desktop',
      idempotencyKey: _sessionId ?? const Uuid().v4(),
      reportLanguage: widget.reportLanguage,
    ));
    _uploadId = res.uploadId;
    return res.signedUrl;
  }

  Future<String> _completeUpload(int sizeBytes) async {
    if (_uploadId == null) throw StateError('uploadId missing');
    final client = ref.read(grpcClientsProvider).ingestion;
    final res = await client.completeAudioUpload(CompleteAudioUploadRequest(
      uploadId: _uploadId!,
      actualDurationSeconds: _displayDuration.inSeconds,
      actualSizeBytes: Int64(sizeBytes),
      chunkCount: _chunkCount,
      reportLanguage: widget.reportLanguage,
    ));
    return res.sessionId;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final dateLabel = DateFormat('d MMMM y', 'pl_PL').format(DateTime.now());

    return PopScope(
      // Block automatic back-gesture/system-back when actively recording —
      // we always want the discard-confirmation sheet between the user
      // and a thrown-away session.
      canPop: _recState == RecordingState.idle ||
          _recState == RecordingState.stopped ||
          _recState == RecordingState.error,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscardOnBack();
        if (!shouldPop) return;
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: EuphireColors.backgroundGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: t.common_back,
              onPressed: () async {
                final shouldPop = await _confirmDiscardOnBack();
                if (!shouldPop) return;
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),

            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: EuphireColors.mist),
                onPressed: () {
                  showEuphireBottomSheet<void>(
                    context: context,
                    builder: (_) => _InstructionsBlock(),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    dateLabel.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: EuphireColors.frostWhite.withValues(alpha: 0.5),
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.patientAlias,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: EuphireColors.frostWhite,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, child) {
                      final patients = ref.watch(patientsProvider).whenOrNull(data: (d) => d) ?? [];
                      final patient = patients.where((p) => p.id == widget.patientFileId).firstOrNull;
                      final sessionNumber = (patient?.sessionCount ?? 0) + 1;
                      return Text(
                        'Sesja #$sessionNumber',
                        style: const TextStyle(
                          fontFamily: 'Merriweather',
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: EuphireColors.ember,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const Spacer(),
              EuphireRecordingIndicator(
                isRecording: _recState == RecordingState.recording,
                formattedDuration: _formatDuration(_displayDuration),
                chunkCount: _chunkCount,
                amplitudeStream: _service.amplitudeStream,
              ),
              const Spacer(flex: 2),
              _ControlPanel(
                state: _recState,
                onStart: _start,
                onPause: _service.pause,
                onResume: _service.resume,
                onStop: _onStopPressed,
              ),
              const SizedBox(height: 16),
              if (_uploading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _ControlPanel extends StatelessWidget {
  final RecordingState state;
  final Future<void> Function() onStart;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onStop;

  const _ControlPanel({
    required this.state,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (state == RecordingState.idle || state == RecordingState.error) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircleButton(
            icon: Icons.mic_rounded,
            color: EuphireColors.ember,
            onPressed: onStart,
            isPrimary: true,
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CircleButton(
          icon: state == RecordingState.recording
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          color: EuphireColors.ember,
          onPressed: state == RecordingState.recording ? onPause : onResume,
        ),
        _CircleButton(
          icon: Icons.stop_rounded,
          color: EuphireColors.magma,
          onPressed: onStop,
          isPrimary: true,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Future<void> Function() onPressed;
  final bool isPrimary;

  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(48),
      child: Container(
        width: isPrimary ? 84 : 64,
        height: isPrimary ? 84 : 64,
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.transparent,
          shape: BoxShape.circle,
          border: isPrimary ? null : Border.all(color: color, width: 2),
        ),
        child: Icon(icon,
            color: isPrimary ? EuphireColors.frostWhite : color,
            size: isPrimary ? 40 : 32),
      ),
    );
  }
}

class _InstructionsBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final items = [
      t.recording_instruction_1,
      t.recording_instruction_2,
      t.recording_instruction_3,
      t.recording_instruction_4,
      t.recording_instruction_5,
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.recording_instructions_title,
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final line in items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(Icons.circle, size: 6, color: EuphireColors.mist),
                  ),
                  Expanded(
                    child: Text(line, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Glue: EuphireButton import to suppress unused warning if a future
// CTA gets re-introduced.
// ignore: unused_element
const _kKeepImportEuphireButton = EuphireButton;
