import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../l10n/app_localizations.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_segmented_control.dart';
import '../widgets/euphire_toast.dart';
import '../utils/haptics.dart';
import '../providers/patient_notes_provider.dart';
import '../services/ai_chat_service.dart';
import 'ai_chat_screen.dart';

// ── Model for parsed transcript messages ───────────────────

class _ReportChatMessage {
  final String role; // 'user', 'ai', 'system'
  final String text;

  _ReportChatMessage({required this.role, required this.text});
}

class AiChatReportScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String initialSummary;
  final String fullTranscript;
  final String? noteId;
  final String? patientAlias;

  const AiChatReportScreen({
    super.key,
    required this.patientId,
    required this.initialSummary,
    required this.fullTranscript,
    this.noteId,
    this.patientAlias,
  });

  @override
  ConsumerState<AiChatReportScreen> createState() => _AiChatReportScreenState();
}

class _AiChatReportScreenState extends ConsumerState<AiChatReportScreen> {
  late String _summary;
  String _activeTab = 'transcript'; // Default to transcript if summary is empty
  bool _isSaving = false;
  bool _isGeneratingSummary = false;
  bool _isBannerDismissed = false;

  @override
  void initState() {
    super.initState();

    final rawSummary = widget.initialSummary.trim();
    final isTranscriptText =
        rawSummary.startsWith('**System:**') ||
        rawSummary.startsWith('**Terapeuta:**') ||
        rawSummary.startsWith('**Superwizor AI:**') ||
        rawSummary.startsWith('**AI:**') ||
        rawSummary.startsWith('###');

    if (rawSummary.isNotEmpty && !isTranscriptText) {
      _summary = rawSummary;
      _activeTab = 'report';
    } else {
      _summary = '';
      _activeTab = 'transcript';
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _saveNote({bool popOnSuccess = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final l = AppLocalizations.of(context);
    try {
      final combinedText = _summary.isNotEmpty
          ? '$_summary\n\n---\n### Zapis rozmowy z AI\n${widget.fullTranscript}'
                .trim()
          : '### Zapis rozmowy z AI\n${widget.fullTranscript}'.trim();

      if (widget.noteId != null && widget.noteId!.isNotEmpty) {
        await ref
            .read(patientNotesMapProvider.notifier)
            .updateNote(
              widget.patientId,
              widget.noteId!,
              l.ai_chat_note_title,
              combinedText,
            );
      } else {
        await ref
            .read(patientNotesMapProvider.notifier)
            .addNote(widget.patientId, l.ai_chat_note_title, combinedText);
      }

      if (mounted) {
        EuphireToast.success(context, message: l.ai_chat_saved_toast);
        if (popOnSuccess) {
          Navigator.of(context).pop();
        }
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
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF00B37E,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: Color(0xFF00B37E),
                              size: 22,
                            ),
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
                                    color: EuphireColors.mist.withValues(
                                      alpha: 0.7,
                                    ),
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
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
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
                    20,
                    8,
                    20,
                    MediaQuery.of(ctx).viewInsets.bottom + 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            t.common_cancel,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              color: EuphireColors.mist,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final newSummary = controller.text.trim();
                            setState(() {
                              _summary = newSummary;
                            });
                            Navigator.pop(ctx);
                            await _saveNote();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00B37E),
                            foregroundColor: EuphireColors.frostWhite,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            t.common_save,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w700,
                            ),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Podsumowanie rozmowy z AI',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.copy_rounded,
                    color: Color(0xFF00B37E),
                  ),
                  title: Text(
                    t.report_btn_copy_summary,
                    style: const TextStyle(
                      color: EuphireColors.frostWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    t.report_copy_desc,
                    style: TextStyle(
                      color: EuphireColors.mist.withValues(alpha: 0.7),
                    ),
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _summary));
                    Navigator.pop(ctx);
                    EuphireToast.success(
                      context,
                      message: 'Skopiowano podsumowanie rozmowy z AI',
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF00B37E),
                  ),
                  title: Text(
                    t.report_btn_edit_summary,
                    style: const TextStyle(
                      color: EuphireColors.frostWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    t.report_edit_summary_desc,
                    style: TextStyle(
                      color: EuphireColors.mist.withValues(alpha: 0.7),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditSummarySheet();
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF00B37E),
                  ),
                  title: const Text(
                    'Wygeneruj ponownie podsumowanie',
                    style: TextStyle(
                      color: EuphireColors.frostWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Utwórz nowe podsumowanie tej rozmowy za pomocą AI',
                    style: TextStyle(
                      color: EuphireColors.mist.withValues(alpha: 0.7),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _generateSummary();
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

  Widget _buildSuperwizorAvatar({double size = 26}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF00B37E).withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          // ignore: avoid_hardcoded_strings_in_widgets
          'assets/images/PNG/v02_supervisor_logo_gradient.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  String _extractSummaryFromNoteText(String text) {
    final headerPattern = RegExp(
      r'###\s*(Zapis rozmowy z AI|Transkrypcja)[^\n]*\n?',
    );
    if (text.contains(headerPattern)) {
      final splitParts = text.split(headerPattern);
      final rawSummary = splitParts[0]
          .replaceFirst(RegExp(r'\n*---+\s*$'), '')
          .trim();
      final isRoleHeader =
          rawSummary.startsWith('**System:**') ||
          rawSummary.startsWith('**Terapeuta:**') ||
          rawSummary.startsWith('**Superwizor AI:**') ||
          rawSummary.startsWith('**AI:**') ||
          rawSummary.startsWith('###');
      if (rawSummary.isNotEmpty && !isRoleHeader) {
        return rawSummary;
      }
    }
    return '';
  }

  Widget _buildSummaryCard() {
    final taskKey = (widget.noteId != null && widget.noteId!.isNotEmpty)
        ? widget.noteId!
        : widget.patientId;
    final summaryTasks = ref.watch(aiChatSummaryProvider);
    final currentTask = summaryTasks[taskKey];
    final isGlobalGenerating = currentTask?.isGenerating ?? false;
    final isGenerating = _isGeneratingSummary || isGlobalGenerating;

    String activeSummary = _summary;
    if (activeSummary.isEmpty &&
        currentTask?.summaryResult != null &&
        currentTask!.summaryResult!.isNotEmpty) {
      activeSummary = currentTask.summaryResult!;
    }
    if (activeSummary.isEmpty && widget.noteId != null) {
      final notesMap = ref.watch(patientNotesMapProvider);
      final notes = notesMap[widget.patientId] ?? [];
      for (final note in notes) {
        if (note.id == widget.noteId) {
          final extracted = _extractSummaryFromNoteText(note.text);
          if (extracted.isNotEmpty) {
            activeSummary = extracted;
            break;
          }
        }
      }
    }

    // Auto-switch to report tab when summary becomes available
    // (e.g. background task finished while user was away or on transcript tab)
    if (activeSummary.isNotEmpty && _activeTab == 'transcript') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _activeTab = 'report');
      });
    }

    return GestureDetector(
      onLongPress: () {
        if (activeSummary.isNotEmpty) {
          AppHapticFeedback.selectionClick();
          _showSummaryOptions();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF071F22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00B37E).withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSuperwizorAvatar(size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Podsumowanie rozmowy z AI',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: EuphireColors.frostWhite,
                    ),
                  ),
                ),
                if (activeSummary.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    color: const Color(0xFF00B37E).withValues(alpha: 0.8),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Edytuj podsumowanie',
                    onPressed: _showEditSummarySheet,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (activeSummary.isNotEmpty)
              MarkdownBody(
                data: activeSummary,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  h3: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                    height: 1.8,
                  ),
                  p: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    height: 1.65,
                    color: EuphireColors.frostWhite.withValues(alpha: 0.92),
                  ),
                  strong: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    color: EuphireColors.ember,
                  ),
                  listBullet: TextStyle(
                    fontFamily: 'Montserrat',
                    color: EuphireColors.ember.withValues(alpha: 0.8),
                  ),
                ),
              )
            else
              (() {
                if (isGenerating) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 8,
                    ),
                    child: Column(
                      children: [
                        _buildSuperwizorAvatar(size: 32),
                        const SizedBox(height: 14),
                        const Text(
                          'Generowanie podsumowania rozmowy...',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: EuphireColors.frostWhite,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Może to potrwać do minuty. Analizujemy przebieg rozmowy i wyciągamy kluczowe wnioski.',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 12.5,
                            color: EuphireColors.mist.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: const SizedBox(
                            height: 6,
                            child: LinearProgressIndicator(
                              backgroundColor: Color(0xFF0D3337),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF00B37E),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Brak wygenerowanego podsumowania z tej rozmowy.',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13.5,
                          color: EuphireColors.mist.withValues(alpha: 0.85),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004D54),
                            foregroundColor: EuphireColors.frostWhite,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: const Color(
                                  0xFF00B37E,
                                ).withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          icon: _buildSuperwizorAvatar(size: 20),
                          label: const Text(
                            'Wygeneruj podsumowanie rozmowy z AI',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          onPressed: _generateSummary,
                        ),
                      ),
                    ],
                  ),
                );
              })(),
          ],
        ),
      ),
    );
  }

  /// Saves the conversation as a patient note.
  ///
  /// This used to call a SECOND, unguarded model to "summarize" the
  /// conversation — generating fresh clinical text about a specific
  /// client outside the classifier, the schema and the verifier. That is
  /// precisely the bypass the guardrail architecture exists to close
  /// (ADR docs/kronikarz/62 section 4.1), so the summarization is gone
  /// and the conversation is saved as it stands.
  ///
  /// If a generated summary is wanted again, it has to come back through
  /// AskPatientQuestion like every other piece of generated clinical
  /// material.
  Future<void> _generateSummary() async {
    if (_isGeneratingSummary) return;
    setState(() => _isGeneratingSummary = true);

    try {
      final saved = await ref
          .read(aiChatSummaryProvider.notifier)
          .saveConversationAsNote(
            patientId: widget.patientId,
            noteId: widget.noteId,
            fullTranscript: widget.fullTranscript,
          );
      if (!mounted) return;
      setState(() => _summary = saved);
      // TODO(i18n): move to .arb before release.
      EuphireToast.success(context, message: 'Zapisano rozmowę jako notatkę');
    } catch (e) {
      if (mounted) {
        EuphireToast.error(context, message: 'Błąd zapisu: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSummary = false);
      }
    }
  }

  // ── Parsowanie surowego zapisu na czytelne duszki wiadomości ──────

  List<_ReportChatMessage> _parseTranscriptToMessages(String raw) {
    final List<_ReportChatMessage> result = [];

    String cleaned = raw
        .replaceFirst(
          RegExp(r'^###\s*(Transkrypcja|Zapis rozmowy z AI)[^\n]*\n?'),
          '',
        )
        .trim();

    final blocks = cleaned.split(RegExp(r'\n---+\n|\n\n---\n\n'));

    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;

      String role = 'ai';
      String content = trimmed;

      if (trimmed.startsWith('**Terapeuta:**')) {
        role = 'user';
        content = trimmed.substring('**Terapeuta:**'.length).trim();
      } else if (trimmed.startsWith('**Superwizor AI:**')) {
        role = 'ai';
        content = trimmed.substring('**Superwizor AI:**'.length).trim();
      } else if (trimmed.startsWith('**AI:**')) {
        role = 'ai';
        content = trimmed.substring('**AI:**'.length).trim();
      } else if (trimmed.startsWith('**System:**')) {
        role = 'system';
        content = trimmed.substring('**System:**'.length).trim();
      }

      // Filter out system welcome messages
      if (role == 'system' ||
          content.contains('Cześć!') ||
          content.contains('asystentem AI') ||
          content.contains('Mam dostęp do raportów z sesji')) {
        continue;
      }

      result.add(_ReportChatMessage(role: role, text: content));
    }

    return result;
  }

  Widget _buildTranscript() {
    final messages = _parseTranscriptToMessages(widget.fullTranscript);

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Subtitle Info Banner ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF071F22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: EuphireColors.glassBorder.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: EuphireColors.ember,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Możesz zaznaczyć dowolny fragment tekstu w duszku wiadomości, aby skopiować jego część.',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: EuphireColors.mist.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Render Message Bubbles in Chat View ──
          ...messages.map((msg) => _buildTranscriptBubble(msg)),
        ],
      ),
    );
  }

  Widget _buildTranscriptBubble(_ReportChatMessage msg) {
    final isUser = msg.role == 'user';
    final isSystem = msg.role == 'system';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF092629).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: EuphireColors.glassBorder.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              _buildSuperwizorAvatar(size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg.text,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: EuphireColors.frostWhite.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildSuperwizorAvatar(size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF35250E), Color(0xFF221607)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0D2D31), Color(0xFF071D20)],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: Border.all(
                  color: isUser
                      ? EuphireColors.ember.withValues(alpha: 0.4)
                      : const Color(0xFF1E4348),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: MarkdownBody(
                data: msg.text,
                selectable:
                    false, // SelectionArea wraps the entire transcript column!
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13.5,
                    height: 1.55,
                    color: isUser
                        ? EuphireColors.frostWhite
                        : EuphireColors.frostWhite.withValues(alpha: 0.92),
                  ),
                  strong: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.ember,
                  ),
                  h1: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                  h2: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                  h3: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.ember,
                  ),
                  listBullet: TextStyle(
                    fontFamily: 'Montserrat',
                    color: isUser ? EuphireColors.ember : EuphireColors.mist,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
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
          // ── Top Copy Button (1:1 with report screen) ──
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: EuphireColors.mist),
            tooltip: _activeTab == 'report'
                ? 'Kopiuj podsumowanie'
                : 'Kopiuj zapis rozmowy',
            onPressed: () {
              if (_activeTab == 'report' && _summary.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: _summary));
                AppHapticFeedback.selectionClick();
                EuphireToast.success(
                  context,
                  message: 'Skopiowano podsumowanie rozmowy z AI',
                );
              } else {
                Clipboard.setData(ClipboardData(text: widget.fullTranscript));
                AppHapticFeedback.selectionClick();
                EuphireToast.success(
                  context,
                  message: 'Skopiowano zapis rozmowy z AI',
                );
              }
            },
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00B37E),
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: EuphireSegmentedControl(
            selected: _activeTab,
            leftValue: 'report',
            leftLabel: 'Podsumowanie',
            rightValue: 'transcript',
            rightLabel: 'Zapis rozmowy z AI',
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
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 16,
                    color: EuphireColors.frostWhite.withValues(alpha: 0.45),
                  ),
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
      bottomNavigationBar: _isBannerDismissed
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                color: EuphireColors.nocturne.withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: EuphireColors.glassBorder.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004D54),
                          foregroundColor: EuphireColors.frostWhite,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: const Color(
                                0xFF00B37E,
                              ).withValues(alpha: 0.6),
                            ),
                          ),
                          elevation: 2,
                        ),
                        icon: _buildSuperwizorAvatar(size: 20),
                        label: const Text(
                          'Wznów rozmowę z AI',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () {
                          AppHapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AiChatScreen(
                                patientId: widget.patientId,
                                patientAlias: widget.patientAlias ?? 'Klient',
                                therapistId: '',
                                initialNoteId: widget.noteId,
                                initialTranscript: widget.fullTranscript,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: EuphireColors.mist.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      tooltip: 'Zamknij',
                      onPressed: () {
                        setState(() => _isBannerDismissed = true);
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
