// AiChatScreen — full-screen chat interface for therapist ↔ Gemini AI.
//
// Accessed from ClientDetailsScreen's Speed Dial FAB (4th option).
// Loads patient context from session reports, streams Gemini responses,
// and optionally saves the conversation as a clinical note on close.
//
// Design: modern dark Euphire glassmorphism theme, Superwizor AI branding logo,
// responsive message bubbles (user=ember gradient, AI=deep teal glass),
// pulsing logo indicator during streaming.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../services/ai_chat_service.dart';
import '../theme/euphire_theme.dart';
import '../utils/haptics.dart';
import '../widgets/euphire_toast.dart';
import '../providers/patient_notes_provider.dart';
import '../widgets/report_preferences_section.dart';

// ── Thinking Phrases ───────────────────────────────────────

const _kThinkingPhrases = [
  'Przeglądam historię sesji...',
  'Analizuję wzorce w rozmowach...',
  'Porównuję z poprzednimi spotkaniami...',
  'Szukam wspólnych wątków...',
  'Przygotowuję odpowiedź...',
  'Zagłębiam się w kontekst...',
  'Łączę obserwacje z różnych sesji...',
  'Przeglądam notatki z procesu...',
  'Szukam kluczowych momentów...',
  'Analizuję dynamikę procesu...',
  'Badam ciągłość wątków...',
  'Odnajduję istotne szczegóły...',
  'Przygotowuję wgląd...',
  'Czytam między wierszami sesji...',
  'Składam obraz z fragmentów...',
];

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
  final String? initialNoteId;
  final String? initialTranscript;

  const AiChatScreen({
    super.key,
    required this.patientId,
    required this.patientAlias,
    required this.therapistId,
    this.initialNoteId,
    this.initialTranscript,
  });

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];

  AiChatService? _chatService;
  bool _isLoading = true; // initial context loading
  bool _isGenerating = false; // AI is streaming a response
  bool _isLastResponseTruncated = false; // AI response was cut off / truncated
  String _streamingText = ''; // partial response text
  StreamSubscription<AiChatStreamEvent>? _streamSub;
  bool _isUserScrolledUp = false; // smart scroll-lock (Gemini/ChatGPT pattern)
  String _thinkingPhrase = _kThinkingPhrases[0];
  Timer? _thinkingTimer;

  // ── Persist-and-continue state ───────────────────────────
  String? _savedNoteId;           // null = not saved yet
  String? _savedNoteText;         // full note text at last save
  int _lastSavedMessageCount = 0; // messages count at last save

  // ── Copy feedback state ──────────────────────────────────
  int? _copiedIndex;
  Timer? _copiedTimer;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScrollPositionChanged);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _initChat();
  }

  Future<void> _initChat() async {
    try {
      final factory = ref.read(aiChatServiceFactoryProvider);
      await ref.read(patientNotesMapProvider.notifier).refreshNotes(widget.patientId);
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

        if (widget.initialNoteId != null && widget.initialNoteId!.isNotEmpty) {
          _savedNoteId = widget.initialNoteId;
        }
        if (widget.initialTranscript != null &&
            widget.initialTranscript!.isNotEmpty) {
          final parsed = _parseTranscriptToMessages(widget.initialTranscript!);
          if (parsed.isNotEmpty) {
            _messages.addAll(parsed);
            _lastSavedMessageCount = _messages.length;
            _savedNoteText = widget.initialTranscript;
          }
        }
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
    WidgetsBinding.instance.removeObserver(this);
    _streamSub?.cancel();
    _thinkingTimer?.cancel();
    _copiedTimer?.cancel();
    _textCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.removeListener(_onScrollPositionChanged);
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _autoSaveAndClose();
    }
  }

  // ── Stop / Thinking Phrases ──────────────────────────────

  void _stopGenerating() {
    _streamSub?.cancel();
    _stopThinkingPhraseRotation();
    if (!mounted) return;
    final finalText = _streamingText.trim();
    setState(() {
      if (finalText.isNotEmpty) {
        _messages.add(_ChatMessage(role: _MessageRole.ai, text: finalText));
      }
      _streamingText = '';
      _isGenerating = false;
      _isLastResponseTruncated = false;
    });
    _scrollToBottom();
    AppHapticFeedback.lightImpact();
  }

  void _startThinkingPhraseRotation() {
    final rng = Random();
    final shuffled = List<String>.from(_kThinkingPhrases)..shuffle(rng);
    var idx = 0;
    setState(() => _thinkingPhrase = shuffled[idx]);
    _thinkingTimer?.cancel();
    _thinkingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      idx = (idx + 1) % shuffled.length;
      setState(() => _thinkingPhrase = shuffled[idx]);
    });
  }

  void _stopThinkingPhraseRotation() {
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
  }

  // ── Send Message ─────────────────────────────────────────

  void _sendMessage([String? overrideText]) {
    final text = (overrideText ?? _textCtrl.text).trim();
    if (text.isEmpty || _chatService == null || _isGenerating) return;

    AppHapticFeedback.lightImpact();

    setState(() {
      _messages.add(_ChatMessage(role: _MessageRole.user, text: text));
      _isGenerating = true;
      _isLastResponseTruncated = false;
      _streamingText = '';
      _isUserScrolledUp = false; // user sent a message → re-engage auto-scroll
    });
    if (overrideText == null) {
      _textCtrl.clear();
    }
    _scrollToBottom(force: true);
    _startThinkingPhraseRotation();

    bool lastWasTruncated = false;
    _streamSub?.cancel();
    _streamSub = _chatService!.sendMessage(text).listen(
      (event) {
        if (!mounted) return;
        lastWasTruncated = event.isTruncated;
        setState(() => _streamingText = event.text);
        _scrollToBottom();
      },
      onDone: () {
        if (!mounted) return;
        _stopThinkingPhraseRotation();
        final finalText = _streamingText.trim();
        final endsWithSentencePunctuation =
            RegExp(r'[\.\!\?\:\)\"”\*]$').hasMatch(finalText);
        final isGrammaticallyCutOff =
            !endsWithSentencePunctuation && finalText.length > 200;

        setState(() {
          if (_streamingText.isNotEmpty) {
            _messages.add(
                _ChatMessage(role: _MessageRole.ai, text: _streamingText));
          }
          _isLastResponseTruncated =
              lastWasTruncated || isGrammaticallyCutOff;
          _streamingText = '';
          _isGenerating = false;
        });
        _scrollToBottom();
        _saveAsNote(silent: true);
      },
      onError: (e) {
        if (!mounted) return;
        _stopThinkingPhraseRotation();
        setState(() {
          _messages.add(_ChatMessage(
            role: _MessageRole.system,
            text: 'Wystąpił błąd: $e',
          ));
          _streamingText = '';
          _isGenerating = false;
          _isLastResponseTruncated = false;
        });
        _scrollToBottom();
      },
    );
  }

  // ── Auto Save & Close ──────────────────────────────────

  Future<void> _autoSaveAndClose() async {
    final hasUnsaved = _messages.length > _lastSavedMessageCount &&
        _messages.any((m) => m.role != _MessageRole.system);
    if (hasUnsaved) {
      await _saveAsNote(silent: true);
    }
  }

  /// Builds the full transcript markdown from all non-system messages.
  String _buildTranscript({
    int fromIndex = 0,
    bool includeHeader = true,
  }) {
    final chatMessages = _messages
        .skip(fromIndex)
        .where((m) => m.role != _MessageRole.system);
    if (_streamingText.trim().isNotEmpty) {
      // include any partial streaming text
    }
    final transcript = chatMessages.map((m) {
      final role = m.role == _MessageRole.user
          ? '**Terapeuta:**'
          : '**Superwizor AI:**';
      return '$role\n${m.text}';
    }).join('\n\n---\n\n');
    if (includeHeader) {
      return '### Zapis rozmowy z AI\n$transcript';
    }
    return transcript;
  }

  List<_ChatMessage> _parseTranscriptToMessages(String transcript) {
    final List<_ChatMessage> result = [];

    final roleRegex = RegExp(
      r'^\*\*(Terapeuta|Superwizor AI|AI|System):\*\*',
      multiLine: true,
    );

    final matches = roleRegex.allMatches(transcript).toList();
    if (matches.isEmpty) {
      final trimmed = transcript
          .replaceFirst(RegExp(r'^###\s*Zapis rozmowy z AI\s*\n*'), '')
          .trim();
      if (trimmed.isNotEmpty) {
        result.add(_ChatMessage(role: _MessageRole.ai, text: trimmed));
      }
      return result;
    }

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final roleName = match.group(1);

      final startPos = match.end;
      final endPos =
          (i + 1 < matches.length) ? matches[i + 1].start : transcript.length;

      var text = transcript.substring(startPos, endPos).trim();
      text = text.replaceFirst(RegExp(r'\n*\s*---+\s*$'), '').trim();

      if (text.isEmpty) continue;

      if (roleName == 'Terapeuta') {
        result.add(_ChatMessage(role: _MessageRole.user, text: text));
      } else if (roleName == 'Superwizor AI' || roleName == 'AI') {
        result.add(_ChatMessage(role: _MessageRole.ai, text: text));
      }
    }
    return result;
  }

  Future<void> _saveAsNote({bool silent = false}) async {
    if (_chatService == null) return;
    if (_messages.length <= _lastSavedMessageCount) return;

    if (!silent && mounted) {
      EuphireToast.info(context, message: 'Zapisywanie notatki...');
    }

    try {
      final l = AppLocalizations.of(context);

      if (_savedNoteId == null) {
        // ── First save: create a new note ──
        final combinedText = _buildTranscript().trim();
        final noteId = await ref
            .read(patientNotesMapProvider.notifier)
            .addNoteReturningId(
              widget.patientId,
              l.ai_chat_note_title,
              combinedText,
            );
        _savedNoteId = noteId;
        _savedNoteText = combinedText;
        _lastSavedMessageCount = _messages.length;
      } else {
        // ── Subsequent save: update with clean separator ──
        final newPart = _buildTranscript(
          fromIndex: _lastSavedMessageCount,
          includeHeader: false,
        );

        final baseText = _savedNoteText ??
            _buildTranscript(fromIndex: 0, includeHeader: true);
        final fullText = '${baseText.trim()}\n\n---\n\n${newPart.trim()}';

        await ref.read(patientNotesMapProvider.notifier).updateNote(
              widget.patientId,
              _savedNoteId!,
              l.ai_chat_note_title,
              fullText,
            );
        _savedNoteText = fullText;
        _lastSavedMessageCount = _messages.length;
      }

      if (!silent && mounted) {
        EuphireToast.success(context, message: 'Zapisano rozmowę z AI');
      }
    } catch (e) {
      if (!silent && mounted) {
        EuphireToast.error(
            context, message: 'Wystąpił błąd podczas zapisywania notatki: $e');
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────

  /// Re-engages auto-scroll when the user scrolls back near the bottom.
  void _onScrollPositionChanged() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final isNearBottom = pos.maxScrollExtent - pos.pixels < 80;
    if (_isUserScrolledUp && isNearBottom) {
      setState(() => _isUserScrolledUp = false);
    }
  }

  /// Scrolls to the bottom of the message list.
  /// Respects scroll-lock: if the user scrolled up, this is a no-op
  /// unless [force] is true (e.g. after sending a message).
  void _scrollToBottom({bool force = false}) {
    if (_isUserScrolledUp && !force) return;
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

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── Superwizor AI Logo Avatar Widget ─────────────────────

  Widget _buildSuperwizorAvatar({double size = 28, bool isPulsing = false}) {
    if (!isPulsing) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: EuphireColors.ember.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: EuphireColors.ember.withValues(alpha: 0.5),
            width: 1.2,
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

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        // Sinusoidal breathing curve — like a water ripple
        final breathVal = (sin(_pulseCtrl.value * pi) + 1) / 2; // 0..1 smooth
        final glowAlpha = 0.12 + (0.3 * breathVal);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: EuphireColors.ember.withValues(alpha: glowAlpha),
                blurRadius: 10 + 10 * breathVal,
                spreadRadius: 1 + 3 * breathVal,
              ),
            ],
            border: Border.all(
              color: EuphireColors.ember.withValues(
                alpha: 0.45 + 0.35 * breathVal,
              ),
              width: 1.5,
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
      },
    );
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        await _autoSaveAndClose();
        if (mounted) {
          nav.pop();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF002024),
                Color(0xFF001214),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: Stack(
                    children: [
                      _buildMessageList(),
                      _buildScrollToBottomButton(),
                    ],
                  ),
                ),
                _buildInputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: EuphireColors.nocturne.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: EuphireColors.glassBorder.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: EuphireColors.mist, size: 20),
            onPressed: () async {
              await _autoSaveAndClose();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          const SizedBox(width: 4),
          _buildSuperwizorAvatar(size: 34, isPulsing: _isGenerating),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: EuphireColors.ember.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: EuphireColors.ember.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: EuphireColors.ember,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Kontekst: ${widget.patientAlias}',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: EuphireColors.mist.withValues(alpha: 0.75),
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
            _buildSuperwizorAvatar(size: 48, isPulsing: true),
            const SizedBox(height: 20),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: EuphireColors.ember,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).ai_chat_loading_context,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: EuphireColors.mist,
              ),
            ),
          ],
        ),
      );
    }

    return SelectionArea(
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          // Detect user-initiated scroll (drag) vs programmatic scroll.
          // DragUpdateDetails is present only when the user is actively dragging.
          if (notification.dragDetails != null && _isGenerating) {
            final pos = _scrollCtrl.position;
            final isNearBottom = pos.maxScrollExtent - pos.pixels < 80;
            if (!isNearBottom && !_isUserScrolledUp) {
              setState(() => _isUserScrolledUp = true);
            }
          }
          return false; // don't consume the notification
        },
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: _messages.length + (_isGenerating ? 1 : 0),
          itemBuilder: (ctx, index) {
            // Streaming bubble (last item while generating)
            if (index == _messages.length && _isGenerating) {
              return _buildStreamingBubble();
            }
            return _buildMessageBubble(_messages[index], index);
          },
        ),
      ),
    );
  }

  /// Floating button shown when user has scrolled up during streaming.
  /// Tapping it re-engages auto-scroll and jumps to bottom.
  Widget _buildScrollToBottomButton() {
    if (!_isUserScrolledUp) return const SizedBox.shrink();
    return Positioned(
      right: 16,
      bottom: 12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            setState(() => _isUserScrolledUp = false);
            _scrollToBottom(force: true);
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: EuphireColors.nocturne.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border: Border.all(
                color: EuphireColors.ember.withValues(alpha: 0.6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.keyboard_double_arrow_down_rounded,
              color: EuphireColors.ember,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, int index) {
    final isUser = msg.role == _MessageRole.user;
    final isSystem = msg.role == _MessageRole.system;

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF092629).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: EuphireColors.glassBorder.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSuperwizorAvatar(size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Superwizor AI',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: EuphireColors.ember,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      msg.text,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12.5,
                        height: 1.5,
                        color: EuphireColors.frostWhite.withValues(alpha: 0.85),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                _buildSuperwizorAvatar(size: 30, isPulsing: false),
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
                            colors: [
                              Color(0xFF35250E),
                              Color(0xFF221607),
                            ],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0D2D31),
                              Color(0xFF071D20),
                            ],
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
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarkdownBody(
                        data: msg.text,
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
                            color: isUser
                                ? EuphireColors.ember
                                : EuphireColors.mist,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          _formatTime(msg.timestamp),
                          style: TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 10,
                            color: EuphireColors.mist.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 4),
            ],
          ),
          if (!isUser) _buildMessageActions(msg, index),
        ],
      ),
    );
  }

  Widget _buildStreamingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSuperwizorAvatar(size: 30, isPulsing: true),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2D31),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: EuphireColors.ember.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: _streamingText.isEmpty
                  ? _buildThinkingIndicator()
                  : MarkdownBody(
                      data: _streamingText,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13.5,
                          height: 1.55,
                          color: EuphireColors.frostWhite.withValues(alpha: 0.92),
                        ),
                        strong: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700,
                          color: EuphireColors.ember,
                        ),
                        listBullet: const TextStyle(
                          fontFamily: 'Montserrat',
                          color: EuphireColors.mist,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Thinking indicator: sinusoidal shimmer dots + rotating context phrase.
  Widget _buildThinkingIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildShimmerDots(),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _thinkingPhrase,
            key: ValueKey(_thinkingPhrase),
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: EuphireColors.mist.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerDots() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final value = _pulseCtrl.value;
        return SizedBox(
          height: 14,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final delay = i * 0.25;
              final t = (value - delay) % 1.0;
              final normalizedT = t < 0 ? t + 1.0 : t;
              final wave = (sin(normalizedT * 2 * pi) + 1) / 2;
              final liftY = -3.5 * wave;
              final opacity = 0.35 + 0.65 * wave;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Transform.translate(
                  offset: Offset(0, liftY),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: const BoxDecoration(
                        color: EuphireColors.ember,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  /// Action buttons under AI message bubbles: copy + regenerate.
  Widget _buildMessageActions(_ChatMessage msg, int index) {
    if (msg.role != _MessageRole.ai) return const SizedBox.shrink();
    final isCopied = _copiedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(left: 46, bottom: 8, top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionIcon(
            icon: isCopied ? Icons.check_rounded : Icons.copy_rounded,
            color: isCopied
                ? EuphireColors.ember
                : EuphireColors.mist.withValues(alpha: 0.7),
            tooltip: isCopied ? 'Skopiowano!' : 'Kopiuj odpowiedź',
            onTap: () {
              Clipboard.setData(ClipboardData(text: msg.text));
              AppHapticFeedback.mediumImpact();
              EuphireToast.info(context, message: 'Skopiowano treść odpowiedzi');
              _copiedTimer?.cancel();
              setState(() => _copiedIndex = index);
              _copiedTimer = Timer(const Duration(milliseconds: 2000), () {
                if (mounted) setState(() => _copiedIndex = null);
              });
            },
          ),
          const SizedBox(width: 8),
          _buildActionIcon(
            icon: Icons.refresh_rounded,
            color: _isGenerating
                ? EuphireColors.mist.withValues(alpha: 0.3)
                : EuphireColors.mist.withValues(alpha: 0.7),
            tooltip: 'Wygeneruj ponownie',
            onTap: _isGenerating
                ? () {}
                : () {
                    AppHapticFeedback.mediumImpact();
                    _regenerateResponse(index);
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          splashColor: EuphireColors.ember.withValues(alpha: 0.2),
          highlightColor: EuphireColors.ember.withValues(alpha: 0.1),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 16,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _regenerateResponse(int aiMessageIndex) {
    // Find the user message that preceded this AI response
    String? lastUserText;
    for (var i = aiMessageIndex - 1; i >= 0; i--) {
      if (_messages[i].role == _MessageRole.user) {
        lastUserText = _messages[i].text;
        break;
      }
    }
    if (lastUserText == null || _isGenerating) return;
    AppHapticFeedback.lightImpact();
    setState(() => _messages.removeAt(aiMessageIndex));
    _sendMessage(lastUserText);
  }

  void _showAssistantMenu(BuildContext context) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: EuphireColors.nocturne,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: EuphireColors.ember, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Gotowe polecenia',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: EuphireColors.frostWhite,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: EuphireColors.mist),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Gotowe polecenia',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: EuphireColors.mist,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              _buildPromptTile(ctx, '💡 Główny wątek w historii klienta?'),
              _buildPromptTile(ctx, '🎭 Jakie emocje dominują u klienta?'),
              _buildPromptTile(ctx, '📋 Podsumuj postępy w terapii'),
              _buildPromptTile(ctx, '🎯 Cel na kolejną sesję'),
              _buildPromptTile(ctx, '🧭 Od czego zacząć kolejną sesję?'),
              const SizedBox(height: 24),
              const Divider(color: EuphireColors.glassBorder),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showReportPreferences(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: EuphireColors.obsidianBlack.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EuphireColors.glassBorder.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.settings_outlined, color: EuphireColors.frostWhite, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Preferencje formatowania raportów',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: EuphireColors.frostWhite,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: EuphireColors.mist.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportPreferences(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EuphireColors.nocturne,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: EuphireColors.mist.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ReportPreferencesSection(),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPromptTile(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          AppHapticFeedback.selectionClick();
          final cleanText = text.replaceFirst(RegExp(r'^[^\w\s\u00C0-\u024F]+'), '').trim();
          _sendMessage(cleanText);
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0B2D31).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EuphireColors.glassBorder.withValues(alpha: 0.3)),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: EuphireColors.frostWhite,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueChip() {
    if (_isGenerating ||
        !_isLastResponseTruncated ||
        _messages.isEmpty ||
        _messages.last.role != _MessageRole.ai) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(Icons.play_arrow_rounded, size: 16, color: EuphireColors.ember),
          label: const Text(
            'Kontynuuj wypowiedź',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: EuphireColors.frostWhite,
            ),
          ),
          backgroundColor: const Color(0xFF092629),
          side: BorderSide(
            color: const Color(0xFF00B37E).withValues(alpha: 0.5),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onPressed: () {
            _sendMessage('Kontynuuj od miejsca, w którym przerwałeś.');
          },
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final canSend = !_isLoading &&
        !_isGenerating &&
        _chatService != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: EuphireColors.nocturne.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
            color: EuphireColors.glassBorder.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContinueChip(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: EuphireColors.mist),
                  onPressed: () => _showAssistantMenu(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: const Color(0xFF071F22),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _inputFocus.hasFocus
                          ? EuphireColors.ember.withValues(alpha: 0.7)
                          : EuphireColors.glassBorder.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _textCtrl,
                    focusNode: _inputFocus,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color: EuphireColors.frostWhite,
                    ),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).ai_chat_input_hint,
                      hintStyle: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: EuphireColors.mist.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    enabled: canSend,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                child: _isGenerating
                    ? Material(
                        color: const Color(0xFF8B2500),
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: _stopGenerating,
                          child: const Icon(
                            Icons.stop_rounded,
                            size: 22,
                            color: EuphireColors.frostWhite,
                          ),
                        ),
                      )
                    : Material(
                        color: canSend
                            ? EuphireColors.ember
                            : EuphireColors.mist.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: canSend ? () => _sendMessage() : null,
                          child: Icon(
                            Icons.send_rounded,
                            size: 20,
                            color: canSend
                                ? EuphireColors.obsidianBlack
                                : EuphireColors.mist.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
