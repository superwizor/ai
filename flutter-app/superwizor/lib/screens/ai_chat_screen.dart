// AiChatScreen — full-screen chat interface for therapist ↔ Gemini AI.
//
// Accessed from ClientDetailsScreen's Speed Dial FAB (4th option).
// Loads patient context from session reports, streams Gemini responses,
// and optionally saves the conversation as a clinical note on close.
//
// Design: dark Euphire theme, message bubbles (user=ember, AI=surfaceTeal),
// shimmer loading indicator, streaming text.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/grpc_provider.dart';
import '../providers/patient_notes_provider.dart';
import '../repositories/clinical_notes_repository.dart';
import '../services/ai_chat_service.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_toast.dart';

// ── Chat Message Model ─────────────────────────────────────

enum _MessageRole { user, ai, system }

class _ChatMessage {
  final _MessageRole role;
  final String text;
  final DateTime timestamp;

  _ChatMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ── Screen ─────────────────────────────────────────────────

class AiChatScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientAlias;
  final String therapistId;

  const AiChatScreen({
    super.key,
    required this.patientId,
    required this.patientAlias,
    required this.therapistId,
  });

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];

  AiChatService? _chatService;
  bool _isLoading = true; // initial context loading
  bool _isGenerating = false; // AI is streaming a response
  String _streamingText = ''; // partial response text
  StreamSubscription<String>? _streamSub;

  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _initChat();
  }

  Future<void> _initChat() async {
    try {
      final factory = ref.read(aiChatServiceFactoryProvider);
      final service = await factory.create(
        patientId: widget.patientId,
        patientAlias: widget.patientAlias,
        therapistId: widget.therapistId,
      );
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(() {
        _chatService = service;
        _isLoading = false;
        _messages.add(_ChatMessage(
          role: _MessageRole.system,
          text: l.ai_chat_system_intro,
        ));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          role: _MessageRole.system,
          text: '${l.ai_chat_error_init}\n$e',
        ));
      });
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _textCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Send Message ─────────────────────────────────────────

  void _sendMessage() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _chatService == null || _isGenerating) return;

    setState(() {
      _messages.add(_ChatMessage(role: _MessageRole.user, text: text));
      _isGenerating = true;
      _streamingText = '';
    });
    _textCtrl.clear();
    _scrollToBottom();

    _streamSub?.cancel();
    _streamSub = _chatService!.sendMessage(text).listen(
      (partial) {
        if (!mounted) return;
        setState(() => _streamingText = partial);
        _scrollToBottom();
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          if (_streamingText.isNotEmpty) {
            _messages.add(
                _ChatMessage(role: _MessageRole.ai, text: _streamingText));
          }
          _streamingText = '';
          _isGenerating = false;
        });
        _scrollToBottom();
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _messages.add(_ChatMessage(
            role: _MessageRole.system,
            text: 'Wystąpił błąd: $e',
          ));
          _streamingText = '';
          _isGenerating = false;
        });
        _scrollToBottom();
      },
    );
  }

  // ── Close / Save Dialog ──────────────────────────────────

  Future<bool> _onWillPop() async {
    // No messages beyond the intro → just close
    final userMessages =
        _messages.where((m) => m.role == _MessageRole.user).toList();
    if (userMessages.isEmpty) return true;

    final l = AppLocalizations.of(context);

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: EuphireColors.surfaceTeal,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            l.ai_chat_save_dialog_title,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: EuphireColors.frostWhite,
            ),
          ),
          content: Text(
            l.ai_chat_save_dialog_body,
            style: const TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 14,
              color: EuphireColors.mist,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(l.ai_chat_save_cancel,
                  style: const TextStyle(color: EuphireColors.mist, fontFamily: 'Montserrat')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: Text(l.ai_chat_save_no,
                  style: const TextStyle(color: EuphireColors.magma, fontFamily: 'Montserrat')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: EuphireColors.ember,
                foregroundColor: EuphireColors.obsidianBlack,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text(l.ai_chat_save_yes,
                  style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );

    if (result == 'cancel') return false;
    if (result == 'save') {
      await _saveAsNote();
    }
    return true;
  }

  Future<void> _saveAsNote() async {
    if (_chatService == null) return;

    final l = AppLocalizations.of(context);

    // Show saving indicator
    EuphireToast.info(context, message: '⏳ ${l.ai_chat_saving}');

    try {
      final summary = await _chatService!.summarizeConversation();

      final notesRepo = ClinicalNotesRepository(
        ref.read(grpcClientsProvider).clinical,
      );
      await notesRepo.createNote(
        widget.patientId,
        l.ai_chat_note_title,
        summary,
        kind: 'FREE_NOTE',
      );

      // Refresh notes list
      ref.invalidate(patientNotesProvider(widget.patientId));

      if (mounted) {
        EuphireToast.success(context, message: l.ai_chat_saved_toast);
      }
    } catch (e) {
      if (mounted) {
        EuphireToast.error(context, message: 'Błąd zapisu: $e');
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: EuphireColors.obsidianBlack,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: EuphireColors.nocturne,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: EuphireColors.mist),
        onPressed: () async {
          final canPop = await _onWillPop();
          if (canPop && mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: EuphireColors.aurora.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, size: 18, color: EuphireColors.aurora),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).ai_chat_title,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: EuphireColors.frostWhite,
                  ),
                ),
                Text(
                  widget.patientAlias,
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 11,
                    color: EuphireColors.mist.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: EuphireColors.ember,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).ai_chat_loading_context,
              style: const TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 14,
                color: EuphireColors.mist,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isGenerating ? 1 : 0),
      itemBuilder: (ctx, index) {
        // Streaming bubble (last item while generating)
        if (index == _messages.length && _isGenerating) {
          return _buildStreamingBubble();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.role == _MessageRole.user;
    final isSystem = msg.role == _MessageRole.system;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 4, right: 8),
              decoration: BoxDecoration(
                color: isSystem
                    ? EuphireColors.mist.withValues(alpha: 0.15)
                    : EuphireColors.aurora.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSystem ? Icons.info_outline : Icons.auto_awesome,
                size: 14,
                color: isSystem ? EuphireColors.mist : EuphireColors.aurora,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? EuphireColors.ember.withValues(alpha: 0.15)
                    : isSystem
                        ? EuphireColors.mist.withValues(alpha: 0.08)
                        : EuphireColors.surfaceTeal,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? Border.all(
                        color: EuphireColors.ember.withValues(alpha: 0.3),
                        width: 1)
                    : null,
              ),
              child: SelectableText(
                msg.text,
                style: TextStyle(
                  fontFamily: 'Merriweather',
                  fontSize: 13.5,
                  height: 1.6,
                  color: isUser
                      ? EuphireColors.frostWhite
                      : isSystem
                          ? EuphireColors.mist
                          : EuphireColors.frostWhite.withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildStreamingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 4, right: 8),
            decoration: BoxDecoration(
              color: EuphireColors.aurora.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome,
                size: 14, color: EuphireColors.aurora),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: EuphireColors.surfaceTeal,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: _streamingText.isEmpty
                  ? _buildShimmerDots()
                  : SelectableText(
                      _streamingText,
                      style: TextStyle(
                        fontFamily: 'Merriweather',
                        fontSize: 13.5,
                        height: 1.6,
                        color:
                            EuphireColors.frostWhite.withValues(alpha: 0.92),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerDots() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, _) {
        final value = _shimmerCtrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final opacity =
                (0.3 + 0.7 * ((value + delay) % 1.0)).clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: EuphireColors.aurora,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildInputBar() {
    final canSend = !_isLoading &&
        !_isGenerating &&
        _chatService != null;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: EuphireColors.nocturne,
        border: Border(
          top: BorderSide(
            color: EuphireColors.glassBorder.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: EuphireColors.deepTealBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: EuphireColors.glassBorder.withValues(alpha: 0.4),
                ),
              ),
              child: TextField(
                controller: _textCtrl,
                focusNode: _inputFocus,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  fontFamily: 'Merriweather',
                  fontSize: 14,
                  color: EuphireColors.frostWhite,
                ),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).ai_chat_input_hint,
                  hintStyle: TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 14,
                    color: EuphireColors.mist.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                enabled: canSend,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            child: Material(
              color: canSend ? EuphireColors.ember : EuphireColors.mist.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: canSend ? _sendMessage : null,
                child: Icon(
                  Icons.send_rounded,
                  size: 20,
                  color: canSend
                      ? EuphireColors.obsidianBlack
                      : EuphireColors.mist.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
