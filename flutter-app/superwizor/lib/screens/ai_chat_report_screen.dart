import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../l10n/app_localizations.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_segmented_control.dart';
import '../widgets/euphire_toast.dart';
import '../utils/haptics.dart';
import '../repositories/clinical_notes_repository.dart';
import '../providers/grpc_provider.dart';
import '../providers/patient_notes_provider.dart';

class AiChatReportScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String initialSummary;
  final String fullTranscript;
  final String? noteId;

  const AiChatReportScreen({
    super.key,
    required this.patientId,
    required this.initialSummary,
    required this.fullTranscript,
    this.noteId,
  });

  @override
  ConsumerState<AiChatReportScreen> createState() => _AiChatReportScreenState();
}

class _AiChatReportScreenState extends ConsumerState<AiChatReportScreen> {
  late String _summary;
  String _activeTab = 'report'; // 'report' or 'transcript'
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _summary = widget.initialSummary;
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    
    final l = AppLocalizations.of(context);
    try {
      final notesRepo = ClinicalNotesRepository(
        ref.read(grpcClientsProvider).clinical,
      );

      final combinedText = '''
$_summary

---
### ${l.transcript_tab}
${widget.fullTranscript}
'''.trim();

      if (widget.noteId != null && widget.noteId!.isNotEmpty) {
        await notesRepo.updateNote(
          widget.noteId!,
          l.ai_chat_note_title,
          combinedText,
        );
      } else {
        await notesRepo.createNote(
          widget.patientId,
          l.ai_chat_note_title,
          combinedText,
          kind: 'FREE_NOTE',
        );
      }

      ref.invalidate(patientNotesProvider(widget.patientId));

      if (mounted) {
        EuphireToast.success(context, message: l.ai_chat_saved_toast);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        EuphireToast.error(context, message: 'Błąd zapisu: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showEditSummarySheet() {
    final controller = TextEditingController(text: _summary);
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0A2326),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: EuphireColors.aurora.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.edit_note_rounded,
                                color: EuphireColors.aurora, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.report_edit_summary_title,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: EuphireColors.frostWhite,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.report_section_summary,
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 13,
                                    color: EuphireColors.mist.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.08)),
                    ],
                  ),
                ),
                // ── Text editor ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: TextField(
                      controller: controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        height: 1.7,
                        color: EuphireColors.frostWhite,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: t.report_edit_summary_hint,
                        hintStyle: TextStyle(
                          fontFamily: 'Montserrat',
                          color: EuphireColors.mist.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Actions ──
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            t.common_cancel,
                            style: const TextStyle(
                                fontFamily: 'Montserrat',
                                color: EuphireColors.mist,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _summary = controller.text.trim();
                            });
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EuphireColors.aurora,
                            foregroundColor: const Color(0xFF041416),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            t.common_save,
                            style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSummaryOptions() {
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Text(
                  t.report_section_summary,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: EuphireColors.aurora),
                  title: Text(t.report_btn_copy_summary, style: const TextStyle(color: EuphireColors.frostWhite, fontWeight: FontWeight.w600)),
                  subtitle: Text(t.report_copy_desc, style: TextStyle(color: EuphireColors.mist.withValues(alpha: 0.7))),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _summary));
                    Navigator.pop(ctx);
                    EuphireToast.success(context, message: t.report_toast_summary_copied);
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.edit_note_rounded, color: EuphireColors.aurora),
                  title: Text(t.report_btn_edit_summary, style: const TextStyle(color: EuphireColors.frostWhite, fontWeight: FontWeight.w600)),
                  subtitle: Text(t.report_edit_summary_desc, style: TextStyle(color: EuphireColors.mist.withValues(alpha: 0.7))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditSummarySheet();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return GestureDetector(
      onLongPress: () {
        AppHapticFeedback.selectionClick();
        _showSummaryOptions();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF041416),
          borderRadius: BorderRadius.circular(14),
          border: const Border(
            left: BorderSide(
              color: EuphireColors.aurora,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 18,
                    color: EuphireColors.aurora.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).report_section_summary,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: EuphireColors.frostWhite,
                    ),
                  ),
                ),
                Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: EuphireColors.aurora.withValues(alpha: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _summary,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                height: 1.7,
                color: EuphireColors.frostWhite.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscript() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
      ),
      child: MarkdownBody(
        data: widget.fullTranscript,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            fontFamily: 'Merriweather',
            fontSize: 13.5,
            height: 1.6,
            color: EuphireColors.frostWhite.withValues(alpha: 0.9),
          ),
          strong: const TextStyle(fontWeight: FontWeight.bold, color: EuphireColors.frostWhite),
          listBullet: TextStyle(
            color: EuphireColors.frostWhite.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(t.ai_chat_note_title, style: theme.textTheme.titleLarge),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: EuphireColors.aurora))),
            )
          else if (_summary != widget.initialSummary || widget.noteId == null)
            TextButton(
              onPressed: _saveNote,
              child: Text(
                t.common_save,
                style: const TextStyle(color: EuphireColors.aurora, fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: EuphireSegmentedControl(
            selected: _activeTab,
            leftValue: 'report',
            leftLabel: t.report_section_summary,
            rightValue: 'transcript',
            rightLabel: t.transcript_tab,
            onSelect: (v) {
              setState(() => _activeTab = v);
            },
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_activeTab == 'report')
              _buildSummaryCard()
            else
              _buildTranscript(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.smart_toy_outlined,
                      size: 16,
                      color: EuphireColors.frostWhite.withValues(alpha: 0.45)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.report_ai_disclaimer,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                        color: EuphireColors.frostWhite.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
