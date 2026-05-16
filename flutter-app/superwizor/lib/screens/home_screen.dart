import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';

import '../theme/euphire_theme.dart';
import '../providers/current_user_provider.dart';
import '../models/session.dart';
import '../providers/patient_provider.dart';
import '../widgets/add_patient_modal.dart';
import '../widgets/edit_patient_modal.dart';
import '../widgets/euphire_bottom_sheet.dart';
import 'client_details_screen.dart';
import 'menu_screen.dart';

/// Returns a human-friendly relative time string in Polish.
/// e.g. "dzisiaj", "wczoraj", "3 dni temu", "2 tyg. temu", "1 mies. temu".
String _relativeTime(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inDays == 0) return 'dzisiaj';
  if (diff.inDays == 1) return 'wczoraj';
  if (diff.inDays < 7) return '${diff.inDays} dni temu';
  if (diff.inDays < 14) return '1 tydz. temu';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} tyg. temu';
  if (diff.inDays < 60) return '1 mies. temu';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} mies. temu';
  return '${(diff.inDays / 365).floor()} r. temu';
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showAddPatientModal(BuildContext context, WidgetRef ref) {
    showEuphireBottomSheet(
      context: context,
      builder: (context) => const AddPatientModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsProvider);
    ref.watch(currentUserProvider); // fire backend lookup


    return Scaffold(
      backgroundColor: EuphireColors.nocturne,
      // Usunięty appBar, zrobimy customowy header dla lepszego UI
      body: Stack(
        children: [
          Container(
            color: const Color(0xFF173E43), // Tło: #173e43
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // ── Header (w stylu Stitch) ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/images/svg/Brandmark_whiteSam_sygnet_euphire.svg',
                          height: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Superwizor AI',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 1,
                            color: EuphireColors.frostWhite,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.menu, color: EuphireColors.frostWhite),
                      onPressed: () {
                        Navigator.of(context).push(CupertinoPageRoute(
                          builder: (_) => const MenuScreen(),
                        ));
                      },
                    ),
                  ],
                ),
              ),

              // ── Patient list (directly in Expanded — no greeting/section header) ──
              Expanded(
                child: patientsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: EuphireColors.ember),
                  ),
                  error: (err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Błąd: $err', style: const TextStyle(color: EuphireColors.ember)),
                    ),
                  ),
                  data: (patients) {
                    if (patients.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: EuphireColors.frostWhite.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.folder_open_rounded,
                                  size: 40,
                                  color: EuphireColors.mist.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Twoja kartoteka jest pusta',
                                style: TextStyle(
                                  fontFamily: 'Merriweather',
                                  fontSize: 17,
                                  fontStyle: FontStyle.italic,
                                  color: EuphireColors.frostWhite.withValues(alpha: 0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Dodaj pierwszego klienta przyciskiem +',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 13,
                                  color: EuphireColors.mist.withValues(alpha: 0.5),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Consumer(
                      builder: (context, ref, child) {
                        final sessionsMap = ref.watch(sessionsProvider).value ?? {};
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: patients.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 2),
                          itemBuilder: (context, index) {
                            final patient = patients[index];
                            final patientSessions = sessionsMap[patient.id] ?? [];
                            final lastSessionDate = patientSessions.isNotEmpty
                                ? patientSessions.last.date
                                : null;
                            final hasActiveAnalysis = patientSessions.any(
                              (s) => s.status != SessionStatus.completed,
                            );

                            return _PatientCalmCard(
                              patientId: patient.id,
                              name: '${patient.firstName} ${patient.lastName}'.trim(),
                              lastSessionDate: lastSessionDate,
                              hasActiveAnalysis: hasActiveAnalysis,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPatientModal(context, ref),
        backgroundColor: EuphireColors.ember,
        foregroundColor: EuphireColors.nocturne,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

// ─── Calm Kartoteka Card ────────────────────────────────────────────
// Minimal 1-line design: status dot + name + relative time + chevron.
// Options (edit/delete) available via long-press (iOS-native pattern).

class _PatientCalmCard extends ConsumerWidget {
  final String patientId;
  final String name;
  final DateTime? lastSessionDate;
  final bool hasActiveAnalysis;

  const _PatientCalmCard({
    required this.patientId,
    required this.name,
    this.lastSessionDate,
    this.hasActiveAnalysis = false,
  });

  void _showOptions(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PatientOptionsMenu(
        patientId: patientId,
        patientName: name,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Status dot color: ember = analysis in progress, aurora = idle/all done
    final dotColor = hasActiveAnalysis ? EuphireColors.ember : EuphireColors.aurora;
    // Relative time label
    final timeLabel = lastSessionDate != null
        ? _relativeTime(lastSessionDate!)
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => ClientDetailsScreen(
                patientId: patientId,
                clientName: name,
              ),
            ),
          );
        },
        onLongPress: () => _showOptions(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // ── Status dot ──
              if (lastSessionDate != null)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: hasActiveAnalysis
                        ? [
                            BoxShadow(
                              color: EuphireColors.ember.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                )
              else
                const SizedBox(width: 22), // alignment spacer for dot-less cards

              // ── Patient name ──
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: EuphireColors.frostWhite,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── Relative time ──
              if (timeLabel != null) ...[
                const SizedBox(width: 12),
                Text(
                  timeLabel,
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 12,
                    color: EuphireColors.mist.withValues(alpha: 0.6),
                  ),
                ),
              ],

              // ── Chevron (navigation affordance) ──
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: EuphireColors.mist.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── BOTTOM SHEET: OPCJE PACJENTA (EDYTUJ / USUŃ) ────────────────

class _PatientOptionsMenu extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  const _PatientOptionsMenu({required this.patientId, required this.patientName});

  @override
  ConsumerState<_PatientOptionsMenu> createState() => _PatientOptionsMenuState();
}

class _PatientOptionsMenuState extends ConsumerState<_PatientOptionsMenu> {
  // Funkcja edycji z formularzem do imienia i nazwiska
  void _editName() {
    Navigator.pop(context); // close options
    final patients = ref.read(patientsProvider).value ?? [];
    try {
      final patient = patients.firstWhere((p) => p.id == widget.patientId);
      showEuphireBottomSheet(
        context: context,
        builder: (context) => EditPatientModal(patient: patient),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Błąd: Nie znaleziono klienta.')),
      );
    }
  }

  void _deleteWarning() {
    Navigator.pop(context); // close options
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DeletePatientWarningSheet(
        patientId: widget.patientId,
        patientName: widget.patientName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A2326),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 28),
              
              // Ikona
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EuphireColors.ember.withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: EuphireColors.ember.withValues(alpha: 0.2),
                        blurRadius: 28, spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.manage_accounts_rounded,
                    color: EuphireColors.ember,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                widget.patientName,
                style: const TextStyle(
                  fontFamily: 'Merriweather',
                  fontStyle: FontStyle.italic,
                  fontSize: 22,
                  color: EuphireColors.frostWhite,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Zarządzaj kartoteką klienta',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: EuphireColors.mist.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              InkWell(
                onTap: _editName,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: EuphireColors.ember.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_rounded, color: EuphireColors.ember, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edytuj dane',
                              style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w600, color: EuphireColors.frostWhite),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Zmień imię i nazwisko',
                              style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: EuphireColors.mist.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: EuphireColors.mist, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: _deleteWarning,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: EuphireColors.magma.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: EuphireColors.magma.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: EuphireColors.magma.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: EuphireColors.magma, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Usuń kartotekę',
                              style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w600, color: EuphireColors.magma),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Skasuj historię, sesje i notatki',
                              style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: EuphireColors.magma.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: EuphireColors.magma.withValues(alpha: 0.5), size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DELETE FLOW DLA PACJENTA: 1. WARNING SHEET Z TOGGLE ──────────

class _DeletePatientWarningSheet extends StatefulWidget {
  final String patientId;
  final String patientName;
  const _DeletePatientWarningSheet({required this.patientId, required this.patientName});

  @override
  State<_DeletePatientWarningSheet> createState() => _DeletePatientWarningSheetState();
}

class _DeletePatientWarningSheetState extends State<_DeletePatientWarningSheet> {
  bool _understands = false;

  void _onProceed() {
    Navigator.pop(context); // zamyka warning sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DeletePatientConfirmSheet(
        patientId: widget.patientId,
        patientName: widget.patientName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A2326),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EuphireColors.magma.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: EuphireColors.magma, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'Usunięcie klienta: ${widget.patientName}',
                style: const TextStyle(
                  fontFamily: 'Merriweather', fontStyle: FontStyle.italic,
                  fontSize: 20, color: EuphireColors.frostWhite,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Cała dokumentacja kliniczna — sesje, notatki AI oraz nagrania audio — zostanie trwale i bezpowrotnie usunięta z baz medycznych.\nZgodnie z RODO (prawo do zapomnienia).',
                style: TextStyle(fontFamily: 'Montserrat', fontSize: 13, color: EuphireColors.mist.withValues(alpha: 0.8), height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text('Rozumiem, to nieodwracalne.',
                      style: TextStyle(fontFamily: 'Montserrat', fontSize: 14, fontWeight: FontWeight.w600, color: EuphireColors.magma)),
                  ),
                  Switch(
                    value: _understands,
                    onChanged: (v) => setState(() => _understands = v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: EuphireColors.magma,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AnimatedOpacity(
                opacity: _understands ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    onPressed: _understands ? _onProceed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EuphireColors.magma,
                      disabledBackgroundColor: EuphireColors.magma,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Kontynuuj kasowanie',
                      style: TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DELETE FLOW DLA PACJENTA: 2. CONFIRM SHEET (Wpisz USUWAM) ────

class _DeletePatientConfirmSheet extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  const _DeletePatientConfirmSheet({required this.patientId, required this.patientName});

  @override
  ConsumerState<_DeletePatientConfirmSheet> createState() => _DeletePatientConfirmSheetState();
}

class _DeletePatientConfirmSheetState extends ConsumerState<_DeletePatientConfirmSheet> {
  final _ctrl = TextEditingController();
  bool _confirmed = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final ok = _ctrl.text.trim().toLowerCase() == 'usuwam';
      if (ok != _confirmed) setState(() => _confirmed = ok);
    });
  }

  Future<void> _delete() async {
    if (!_confirmed) return;
    setState(() => _deleting = true);
    try {
      await ref.read(patientsProvider.notifier).deletePatientUser(widget.patientId);
      if (mounted) Navigator.of(context).pop(); // zamknij po sukcesie
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd usunięcia: $e'), backgroundColor: EuphireColors.magma));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A2326),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                const Text(
                  'Aby potwierdzić, wpisz:',
                  style: TextStyle(fontFamily: 'Montserrat', color: EuphireColors.mist),
                ),
                const SizedBox(height: 4),
                const Text(
                  'usuwam',
                  style: TextStyle(fontFamily: 'RobotoMono', color: EuphireColors.magma, fontWeight: FontWeight.w800, letterSpacing: 4, fontSize: 20),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _ctrl,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 20, fontWeight: FontWeight.w700, color: EuphireColors.frostWhite, letterSpacing: 3),
                  decoration: InputDecoration(
                    hintText: 'wpisz tutaj…',
                    filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _confirmed ? EuphireColors.magma : EuphireColors.mist.withValues(alpha: 0.3), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedOpacity(
                  opacity: _confirmed ? 1.0 : 0.35,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _confirmed && !_deleting ? _delete : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EuphireColors.magma, disabledBackgroundColor: EuphireColors.magma,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _deleting
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Usuń pacjenta', style: TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Anuluj.', style: TextStyle(fontFamily: 'Montserrat', color: EuphireColors.mist.withValues(alpha: 0.7))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
