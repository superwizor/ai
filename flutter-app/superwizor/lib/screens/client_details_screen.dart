import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_header.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../models/patient.dart';
import '../models/session.dart';
import '../providers/current_user_provider.dart';
import '../providers/patient_provider.dart';
import '../widgets/edit_patient_modal.dart';
import 'new_session_screen.dart';
import 'recording_screen.dart';
import 'session_status_screen.dart';
import 'transcript_screen.dart';

class ClientDetailsScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String clientName;

  const ClientDetailsScreen({
    super.key,
    required this.patientId,
    required this.clientName,
  });

  @override
  ConsumerState<ClientDetailsScreen> createState() =>
      _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends ConsumerState<ClientDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _recordAnim; // mini-FAB #1 (closer to main FAB)
  late Animation<double> _uploadAnim; // action card #2 (higher up)
  late Animation<double> _bannerAnim; // security banner from top
  late AnimationController _pulseController; // mic icon pulse
  late Animation<double> _pulseScale;
  bool _hasCollapsedExtendedFab = false; // first-session extended FAB state

  bool get _isExpanded =>
      _fabController.status == AnimationStatus.completed ||
      _fabController.status == AnimationStatus.forward;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // Staggered: record appears first, upload slides out with delay, banner last
    _recordAnim = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    );
    _uploadAnim = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.12, 0.80, curve: Curves.easeOutCubic),
    );
    _bannerAnim = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
    );

    // Mic pulse: 2 gentle beats when FAB opens
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fabController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.repeat(reverse: true);
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) {
            _pulseController.reverse().then((_) {
              if (mounted) _pulseController.stop();
            });
          }
        });
      } else if (status == AnimationStatus.reverse) {
        _pulseController.stop();
        _pulseController.value = 0;
      }
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    if (_isExpanded) {
      _fabController.reverse();
    } else {
      _fabController.forward();
    }
  }

  void _closeFab() {
    if (_isExpanded) _fabController.reverse();
  }

  /// Resolves therapistId and patient alias, then returns them.
  /// Returns null if therapistId is unavailable.
  Future<({String therapistId, String alias})?> _resolveSessionContext() async {
    var therapistId = ref.read(therapistIdProvider);
    if (therapistId == null) {
      try {
        final user = await ref.read(currentUserProvider.future);
        therapistId = user?.id;
      } catch (e) {
        // network / auth error — fall through with null
      }
    }
    if (!mounted) return null;
    if (therapistId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profil nie został jeszcze załadowany. Spróbuj za chwilę.',
          ),
        ),
      );
      return null;
    }
    final patientsState =
        ref.read(patientsProvider).whenOrNull(data: (d) => d) ?? [];
    final patient = patientsState.firstWhere(
      (p) => p.id == widget.patientId,
      orElse: () =>
          Patient(id: widget.patientId, firstName: 'Brak', lastName: ''),
    );
    final alias = '${patient.firstName} ${patient.lastName}'.trim();
    return (therapistId: therapistId, alias: alias);
  }

  Future<void> _onRecordTapped() async {
    _closeFab();
    final ctx = await _resolveSessionContext();
    if (ctx == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordingScreen(
          patientFileId: widget.patientId,
          therapistId: ctx.therapistId,
          patientAlias: ctx.alias,
          reportLanguage: 'pl',
        ),
      ),
    );
  }

  Future<void> _onUploadTapped() async {
    _closeFab();
    final ctx = await _resolveSessionContext();
    if (ctx == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewSessionScreen(
          patientFileId: widget.patientId,
          therapistId: ctx.therapistId,
          patientAlias: ctx.alias,
          autoPickFile: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientAsync = ref.watch(patientsProvider);
    final sessionsAsync = ref.watch(sessionsProvider);

    // Always re-fetch sessions on entry. Backend is the source of
    // truth for session.status (CREATED → TRANSCRIBING → ANALYZING →
    // COMPLETED), and we may be returning here from RecordingScreen
    // /SessionStatusScreen where status just transitioned. The
    // previous "only fetch if not cached" check kept stale state
    // forever — caused the bug where finished sessions kept routing
    // to SessionStatusScreen instead of TranscriptScreen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionsProvider.notifier).fetchSessions(widget.patientId);
    });

    return Scaffold(
      backgroundColor: EuphireColors.obsidianBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: EuphireColors.mist),
        actions: [
          patientAsync.when(
            data: (patients) {
              final patient = patients.firstWhere(
                (p) => p.id == widget.patientId,
                orElse: () => Patient(
                    id: widget.patientId, firstName: '', lastName: ''),
              );
              if (patient.firstName.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4, top: 2),
                child: IconButton(
                  icon: const Icon(Icons.edit, color: EuphireColors.mist),
                  onPressed: () {
                    showEuphireBottomSheet(
                      context: context,
                      builder: (_) => EditPatientModal(patient: patient),
                    );
                  },
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: patientAsync.when(
        loading: () => const Center(
            child:
                CircularProgressIndicator(color: EuphireColors.ember)),
        error: (e, st) => Center(
            child: Text('Błąd: $e',
                style: const TextStyle(color: EuphireColors.ember))),
        data: (patients) {
          final patient = patients.firstWhere(
            (p) => p.id == widget.patientId,
            orElse: () => Patient(
                id: widget.patientId,
                firstName: 'Nie znaleziono',
                lastName: ''),
          );

          return SizedBox.expand(
            child: Stack(
              children: [
              // ── Main content ──
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EuphireHeader(
                        title:
                            '${patient.firstName} ${patient.lastName}'
                                .trim(),
                        subtitle:
                            '${patient.sessionCount} sesji${patient.modalityCode.isNotEmpty
                                    ? ' • ${patient.modalityCode}'
                                    : ''}',
                      ),
                      const SizedBox(height: 32),
                      sessionsAsync.when(
                        loading: () => const Center(
                            child: CircularProgressIndicator(
                                color: EuphireColors.ember)),
                        error: (e, st) => Center(
                            child: Text('Błąd sesji: $e',
                                style: const TextStyle(
                                    color: EuphireColors.ember))),
                        data: (sessionsMap) {
                          final sessions =
                              sessionsMap[widget.patientId] ?? [];
                          final reversedSessions =
                              sessions.reversed.toList();
                          if (reversedSessions.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 120.0, left: 32.0, right: 32.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: EuphireColors.frostWhite.withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 32,
                                        color: EuphireColors.mist,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Rozpocznij pracę',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Merriweather',
                                        fontSize: 20,
                                        fontStyle: FontStyle.italic,
                                        color: EuphireColors.frostWhite.withValues(alpha: 0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Rozpocznij nagrywanie, a system zadba o bezpieczną transkrypcję i przygotuje raport kliniczny.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 14,
                                        color: EuphireColors.mist,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            itemCount: reversedSessions.length,
                            itemBuilder: (context, index) {
                              final session = reversedSessions[index];
                              return _SessionCard(
                                session: session,
                                patientId: widget.patientId,
                                ref: ref,
                              );
                            },
                          );
                        },
                      ),
                      // Bottom padding so FAB doesn't cover last card
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              // ── Scrim (dark overlay when FAB expanded) ──
              AnimatedBuilder(
                animation: _fabController,
                builder: (_, _) {
                  if (_fabController.value == 0) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    onTap: _closeFab,
                    child: Container(
                      color: Colors.black
                          .withValues(alpha: 0.5 * _fabController.value),
                    ),
                  );
                },
              ),

              // ── Security banner (slides from top, organic gradient) ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _bannerAnim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -1.0),
                      end: Offset.zero,
                    ).animate(_bannerAnim),
                    child: ClipPath(
                      clipper: const _ArcBottomClipper(arcDip: 18),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF0D3B34),
                              Color(0xFF0A302A),
                              Color(0x000A302A),
                            ],
                            stops: [0.0, 0.6, 1.0],
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(24, 18, 24, 44),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.shield_rounded,
                                    color: EuphireColors.frostWhite,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    'Twoje dane są szyfrowane end-to-end. '
                                    'Nikt poza Tobą nie ma do nich dostępu.',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: EuphireColors.frostWhite
                                          .withValues(alpha: 0.85),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Speed Dial action cards + FAB ──
              Positioned(
                right: 16,
                bottom: 16,
                // No left constraint — FAB extends freely to the left
                // Action cards get explicit width from the builder
                child: Builder(
                  builder: (ctx) {
                    // Detect first session
                    final currentSessions = sessionsAsync.whenOrNull(
                      data: (map) => map[widget.patientId],
                    ) ?? [];
                    final isFirstSession = currentSessions.isEmpty &&
                        !_hasCollapsedExtendedFab &&
                        !_isExpanded;

                    // Fixed extended width so it wraps the text perfectly without 
                    // unnecessary negative space, clamped to avoid overflow.
                    final screenWidth = MediaQuery.of(ctx).size.width;
                    final extendedWidth = 285.0.clamp(200.0, screenWidth - 32.0);

                    return AnimatedBuilder(
                      animation: _fabController,
                      builder: (_, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // ── Action Card #2: Upload file (higher) ──
                          SizeTransition(
                            sizeFactor: _uploadAnim,
                            axisAlignment: 1.0,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: SizedBox(
                                width: screenWidth - 48,
                                child: _buildActionCard(
                                  animation: _uploadAnim,
                                  icon: Icons.upload_file_rounded,
                                  label: 'WGRAJ PLIK Z DYSKU',
                                  subtitle: 'Prześlij nagranie z dyktafonu',
                                  onTap: _onUploadTapped,
                                  isPrimary: false,
                                ),
                              ),
                            ),
                          ),

                          // ── Action Card #1: Record (closer to main) ──
                          SizeTransition(
                            sizeFactor: _recordAnim,
                            axisAlignment: 1.0,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: SizedBox(
                                width: screenWidth - 48,
                                child: _buildActionCard(
                                  animation: _recordAnim,
                                  icon: Icons.mic_rounded,
                                  label: 'ROZPOCZNIJ NAGRYWANIE',
                                  subtitle: 'Nagraj nową sesję terapeutyczną',
                                  onTap: _onRecordTapped,
                                  isPrimary: true,
                                ),
                              ),
                            ),
                          ),

                          // ── Main FAB (extended pill or circle) ──
                          GestureDetector(
                            onTap: () {
                              if (isFirstSession) {
                                setState(
                                    () => _hasCollapsedExtendedFab = true);
                                Future.delayed(
                                  const Duration(milliseconds: 380),
                                  _toggleFab,
                                );
                              } else {
                                _toggleFab();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOutCubic,
                              height: 56,
                              width: isFirstSession ? extendedWidth : 56,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: EuphireColors.ember,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: EuphireColors.emberGlow,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Extended label (slides right & fades)
                                  AnimatedOpacity(
                                    opacity: isFirstSession ? 1.0 : 0.0,
                                    duration:
                                        const Duration(milliseconds: 250),
                                    child: AnimatedSlide(
                                      offset: isFirstSession
                                          ? Offset.zero
                                          : const Offset(0.3, 0),
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInCubic,
                                      child: SizedBox(
                                        width: extendedWidth,
                                        child: Row(
                                          children: [
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Text(
                                                'Rozpocznij pierwszą analizę',
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: EuphireColors
                                                      .obsidianBlack,
                                                  letterSpacing: 0.2,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.add_rounded,
                                              size: 22,
                                              color: EuphireColors
                                                  .obsidianBlack
                                                  .withValues(alpha: 0.6),
                                            ),
                                            const SizedBox(width: 16),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Circle icon (appears when collapsed)
                                  AnimatedOpacity(
                                    opacity: isFirstSession ? 0.0 : 1.0,
                                    duration:
                                        const Duration(milliseconds: 200),
                                    child: AnimatedRotation(
                                      turns:
                                          _fabController.value * 0.125,
                                      duration: Duration.zero,
                                      child: Icon(
                                        Icons.add,
                                        size: 28,
                                        color:
                                            EuphireColors.obsidianBlack,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          );
        },
      ),
    );
  }

  /// Builds an animated full-width action card for the speed dial.
  Widget _buildActionCard({
    required Animation<double> animation,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(animation),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isPrimary
                  ? EuphireColors.ember
                  : const Color(0xFF0F1F21),
              borderRadius: BorderRadius.circular(14),
              border: isPrimary
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: isPrimary
                  ? [
                      ...EuphireColors.emberGlow,
                      BoxShadow(
                        color: EuphireColors.ember
                            .withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Icon circle — with pulse on primary
                ScaleTransition(
                  scale: isPrimary ? _pulseScale : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: isPrimary
                          ? EuphireColors.frostWhite
                          : EuphireColors.frostWhite.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Text column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: isPrimary
                              ? EuphireColors.obsidianBlack
                              : EuphireColors.frostWhite,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: isPrimary
                              ? EuphireColors.obsidianBlack
                                  .withValues(alpha: 0.6)
                              : EuphireColors.mist
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isPrimary
                      ? EuphireColors.obsidianBlack.withValues(alpha: 0.4)
                      : EuphireColors.mist.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Session Card (extracted from inline builder) ────────────────────

class _SessionCard extends StatelessWidget {
  final Session session;
  final String patientId;
  final WidgetRef ref;

  const _SessionCard({
    required this.session,
    required this.patientId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final months = [
      'Sty', 'Lut', 'Mar', 'Kwi', 'Maj', 'Cze',
      'Lip', 'Sie', 'Wrz', 'Paź', 'Lis', 'Gru',
    ];
    final dateStr =
        '${session.date.day} ${months[session.date.month - 1]}';
    final timeStr =
        '${session.date.hour.toString().padLeft(2, '0')}:${session.date.minute.toString().padLeft(2, '0')}';

    final isCompleted = session.status == SessionStatus.completed;
    final dotColor =
        isCompleted ? EuphireColors.aurora : EuphireColors.ember;
    final statusText =
        isCompleted ? 'Wnioski gotowe' : 'W trakcie analizy';

    return InkWell(
      onTap: () {
        final destination = isCompleted
            ? MaterialPageRoute(
                builder: (_) =>
                    TranscriptScreen(sessionId: session.id))
            : MaterialPageRoute(
                builder: (_) =>
                    SessionStatusScreen(sessionId: session.id));
        Navigator.push(context, destination);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: EuphireColors.obsidianBlack.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
              color:
                  EuphireColors.frostWhite.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Raport z sesji',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: EuphireColors.frostWhite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dotColor.withValues(alpha: 0.2),
                            border: Border.all(color: dotColor),
                            boxShadow: [
                              BoxShadow(
                                  color: dotColor, blurRadius: 6)
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: const TextStyle(
                            fontFamily: 'Merriweather',
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                            color: EuphireColors.mist,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            color: EuphireColors.mist,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              color: EuphireColors.mist, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: EuphireColors.nocturne,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('Zmień nazwę',
                                  style: TextStyle(
                                      color: EuphireColors
                                          .frostWhite)),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Usuń sesję',
                                  style: TextStyle(
                                      color:
                                          EuphireColors.magma)),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'delete') {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor:
                                      EuphireColors.nocturne,
                                  title: const Text(
                                      'Bezpowrotne usunięcie sesji',
                                      style: TextStyle(
                                          color: EuphireColors
                                              .frostWhite)),
                                  content: const Text(
                                      'Czy na pewno chcesz BEZPOWROTNIE usunąć tę sesję, nagranie oraz transkrypcję? Tej operacji nie można cofnąć.',
                                      style: TextStyle(
                                          color:
                                              EuphireColors.mist)),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text('Anuluj',
                                          style: TextStyle(
                                              color: EuphireColors
                                                  .mist)),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        try {
                                          await ref
                                              .read(sessionsProvider
                                                  .notifier)
                                              .deleteSession(
                                                  patientId,
                                                  session.id);
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        } catch (_) {}
                                      },
                                      child: const Text(
                                          'Usuń bezpowrotnie',
                                          style: TextStyle(
                                              color: EuphireColors
                                                  .magma)),
                                    ),
                                  ],
                                ),
                              );
                            } else if (value == 'rename') {
                              final controller =
                                  TextEditingController(
                                      text: session.modality);
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor:
                                      EuphireColors.nocturne,
                                  title: const Text(
                                      'Zmień nazwę sesji',
                                      style: TextStyle(
                                          color: EuphireColors
                                              .frostWhite)),
                                  content: TextField(
                                    controller: controller,
                                    style: const TextStyle(
                                        color: EuphireColors
                                            .frostWhite),
                                    autofocus: true,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text('Anuluj',
                                          style: TextStyle(
                                              color: EuphireColors
                                                  .mist)),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        if (controller.text
                                            .trim()
                                            .isNotEmpty) {
                                          try {
                                            await ref
                                                .read(
                                                    sessionsProvider
                                                        .notifier)
                                                .renameSession(
                                                    patientId,
                                                    session.id,
                                                    controller.text
                                                        .trim());
                                            if (context.mounted) {
                                              Navigator.pop(
                                                  context);
                                            }
                                          } catch (_) {}
                                        }
                                      },
                                      child: const Text('Zapisz',
                                          style: TextStyle(
                                              color: EuphireColors
                                                  .ember)),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontFamily: 'RobotoMono',
                        color: EuphireColors.mist
                            .withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
                color: EuphireColors.mist.withValues(alpha: 0.3),
                height: 1),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: EuphireColors.obsidianBlack,
                              border: Border.all(
                                  color: EuphireColors.mist
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.person,
                                size: 16,
                                color: EuphireColors.mist),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'NURT: ${session.modality}',
                              style: const TextStyle(
                                fontFamily: 'RobotoMono',
                                fontSize: 13,
                                color: EuphireColors.mist,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Zobacz więcej',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: EuphireColors.ember,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward,
                            size: 18, color: EuphireColors.ember),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom clipper: shallow arc at the bottom edge ─────────────────

class _ArcBottomClipper extends CustomClipper<Path> {
  final double arcDip; // how much the center dips below the edges

  const _ArcBottomClipper({required this.arcDip});

  @override
  Path getClip(Size size) {
    final path = Path();
    // Top edge — straight
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    // Right edge — down to the arc start point
    path.lineTo(size.width, size.height - arcDip);
    // Bottom edge — shallow arc curving down in the center
    path.quadraticBezierTo(
      size.width / 2, // control point X: center
      size.height + arcDip, // control point Y: dips below
      0, // end X: left edge
      size.height - arcDip, // end Y: same height as start
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _ArcBottomClipper oldClipper) =>
      oldClipper.arcDip != arcDip;
}
