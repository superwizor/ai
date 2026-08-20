// AiChatService — the therapist-facing AI chat.
//
// ── What changed and why ───────────────────────────────────────────────
//
// This file used to call Vertex AI DIRECTLY FROM THE DEVICE through
// Firebase AI Logic, building its own system prompt out of session
// reports. That is the architecture ADR docs/kronikarz/62 section 6
// rejects in as many words: "identyczny guardrail po stronie serwera
// (żadnej logiki klasyfikacji w kliencie)".
//
// The reason is not tidiness. A guardrail that lives in the client is a
// guardrail that ships on the app store's schedule — and Google Play has
// been stuck on 1.0.3 since 2026-07-23. A classifier bug found on a
// Tuesday would sit in production for weeks. Worse, a client-side prompt
// is advisory: nothing structurally prevents the model from answering a
// diagnostic question, because the schema, the router and the verifier
// are all on the other side of a network call that never happened.
//
// So the chat now makes ONE unary RPC. The backend classifies, routes,
// retrieves, generates, validates and verifies; the client renders what
// comes back and enforces nothing. That division is the point: the app
// cannot weaken a rule it does not implement.
//
// Unary, not streaming, for the same reason the RPC is: the verifier must
// see the complete response before the therapist sees any of it, and a
// token already painted on screen cannot be recalled.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';

import '../generated/clinical/v1/clinical.pb.dart' as pb;
import '../providers/grpc_provider.dart';
import '../providers/patient_notes_provider.dart';

// ── Result model ───────────────────────────────────────────────────────

/// One resolved citation. Every field except [text] is filled in by the
/// server from the database; the model only ever supplied pointers.
@immutable
class ChatQuote {
  const ChatQuote({
    required this.sessionId,
    required this.segmentId,
    required this.text,
    required this.speaker,
    required this.tsStartMs,
    this.sessionAt,
  });

  final String sessionId;
  final String segmentId;

  /// Verbatim transcript text. May contain pseudonymization tokens such
  /// as `[MIEJSCOWOSC-A]` — the transcript is redacted at rest, and
  /// decision D2 on whether to change that for this surface is open. The
  /// UI shows them as-is rather than hiding them: a quote the therapist
  /// cannot fully read is better than one they wrongly believe is
  /// complete.
  final String text;

  final String speaker;
  final int tsStartMs;
  final DateTime? sessionAt;

  static ChatQuote fromProto(pb.Quote q) => ChatQuote(
    sessionId: q.sessionId,
    segmentId: q.segmentId,
    text: q.text,
    speaker: q.speaker,
    tsStartMs: q.tsStartMs,
    sessionAt: q.hasSessionAt() ? q.sessionAt.toDateTime() : null,
  );
}

/// How a section must be presented.
enum ChatSectionKind {
  /// Quoted material with minimal prose.
  extract,

  /// Summarized session material.
  summary,

  /// Computed numbers; no model was involved.
  stats,

  /// Generated clinical material. MUST be visibly marked as AI-produced
  /// and awaiting the therapist's judgement (AI Act article 50).
  hypothesis,

  /// The therapist's own field. Arrives empty and stays theirs.
  userOnly,

  unknown,
}

@immutable
class ChatSection {
  const ChatSection({
    required this.title,
    required this.body,
    required this.quotes,
    required this.kind,
    required this.userAuthored,
  });

  final String title;
  final String body;
  final List<ChatQuote> quotes;
  final ChatSectionKind kind;
  final bool userAuthored;

  /// Whether this section carries model-generated clinical material and
  /// therefore needs the AI marking and the expandable evidence.
  bool get needsAiMarking => kind == ChatSectionKind.hypothesis;

  static ChatSection fromProto(pb.AnswerSection s) => ChatSection(
    title: s.title,
    body: s.body,
    quotes: s.quotes.map(ChatQuote.fromProto).toList(),
    kind: _kindFromProto(s.kind),
    userAuthored: s.userAuthored,
  );

  static ChatSectionKind _kindFromProto(pb.SectionKind k) {
    switch (k) {
      case pb.SectionKind.SECTION_KIND_EXTRACT:
        return ChatSectionKind.extract;
      case pb.SectionKind.SECTION_KIND_SUMMARY:
        return ChatSectionKind.summary;
      case pb.SectionKind.SECTION_KIND_STATS:
        return ChatSectionKind.stats;
      case pb.SectionKind.SECTION_KIND_HYPOTHESIS:
        return ChatSectionKind.hypothesis;
      case pb.SectionKind.SECTION_KIND_USER_ONLY:
        return ChatSectionKind.userOnly;
      default:
        // An unrecognized kind is rendered as a plain summary WITHOUT AI
        // marking privileges. A newer server sending a kind this build
        // does not know must not have its content silently presented as
        // something the therapist can rely on.
        return ChatSectionKind.unknown;
    }
  }
}

/// An AI-proposed question for the therapist to consider (ADR v1.2).
/// Distinct from the curated starter prompts: these are model-authored,
/// grounded, and were checked by the verifier.
@immutable
class ChatSuggestedQuestion {
  const ChatSuggestedQuestion({required this.question, required this.quotes});
  final String question;
  final List<ChatQuote> quotes;
}

/// An offer made alongside a refusal.
@immutable
class ChatAlternative {
  const ChatAlternative({required this.labelKey, required this.prefillKey});

  /// i18n key, not display text — the server does not decide what
  /// language the therapist reads.
  final String labelKey;
  final String prefillKey;
}

@immutable
class ChatRefusal {
  const ChatRefusal({
    required this.messageKey,
    required this.alternatives,
    required this.showCrisisInformation,
  });

  final String messageKey;
  final List<ChatAlternative> alternatives;

  /// Crisis information is shown independently of anything the chat did.
  /// It is never routed through the model and never depends on the chat
  /// working.
  final bool showCrisisInformation;
}

enum ChatOutcomeKind {
  answered,
  degraded,
  refused,
  verifierBlocked,
  unavailable,
}

@immutable
class ChatTurnResult {
  const ChatTurnResult({
    required this.conversationId,
    required this.outcome,
    required this.sections,
    required this.suggestedQuestions,
    required this.refusal,
    required this.degradeReason,
    required this.quotaRemainingMicroUsd,
    required this.latencyMs,
  });

  final String conversationId;
  final ChatOutcomeKind outcome;
  final List<ChatSection> sections;
  final List<ChatSuggestedQuestion> suggestedQuestions;
  final ChatRefusal? refusal;

  /// Why the answer was reduced, when it was: "low_conf", "defined_ops",
  /// "quota", "verifier_block".
  final String degradeReason;

  final int quotaRemainingMicroUsd;
  final int latencyMs;

  bool get isRefusal =>
      outcome == ChatOutcomeKind.refused ||
      outcome == ChatOutcomeKind.verifierBlocked;

  /// True when the turn was answered with a reduced operation. The UI
  /// says so: a therapist who asked for a conceptualization and silently
  /// got quotes would reasonably conclude the feature is bad rather than
  /// restricted.
  bool get wasDegraded => outcome == ChatOutcomeKind.degraded;

  static ChatTurnResult fromProto(pb.AskPatientQuestionResponse r) {
    final answer = r.hasAnswer() ? r.answer : null;
    return ChatTurnResult(
      conversationId: r.conversationId,
      outcome: _outcomeFromProto(r.outcome),
      sections:
          answer?.sections.map(ChatSection.fromProto).toList() ?? const [],
      suggestedQuestions:
          answer?.suggestedQuestions
              .map(
                (q) => ChatSuggestedQuestion(
                  question: q.question,
                  quotes: q.quotes.map(ChatQuote.fromProto).toList(),
                ),
              )
              .toList() ??
          const [],
      refusal: r.hasRefusal()
          ? ChatRefusal(
              messageKey: r.refusal.message,
              alternatives: r.refusal.alternatives
                  .map(
                    (a) => ChatAlternative(
                      labelKey: a.label,
                      prefillKey: a.prefill,
                    ),
                  )
                  .toList(),
              showCrisisInformation: r.refusal.showCrisisInformation,
            )
          : null,
      degradeReason: r.hasMeta() ? r.meta.degradeReason : '',
      quotaRemainingMicroUsd: r.hasMeta()
          ? r.meta.quotaRemainingMicroUsd.toInt()
          : 0,
      latencyMs: r.hasMeta() ? r.meta.latencyMs : 0,
    );
  }

  static ChatOutcomeKind _outcomeFromProto(pb.ChatOutcome o) {
    switch (o) {
      case pb.ChatOutcome.CHAT_OUTCOME_ANSWERED:
        return ChatOutcomeKind.answered;
      case pb.ChatOutcome.CHAT_OUTCOME_DEGRADED:
        return ChatOutcomeKind.degraded;
      case pb.ChatOutcome.CHAT_OUTCOME_REFUSED:
        return ChatOutcomeKind.refused;
      case pb.ChatOutcome.CHAT_OUTCOME_VERIFIER_BLOCKED:
        return ChatOutcomeKind.verifierBlocked;
      default:
        // An outcome this build does not recognize is treated as
        // unavailable, not as an answer. Rendering unknown-shaped content
        // as a normal reply is how a client turns a server-side refusal
        // into a visible answer.
        return ChatOutcomeKind.unavailable;
    }
  }
}

/// Raised when the chat is switched off for this caller.
class ChatUnavailableException implements Exception {
  const ChatUnavailableException();
  @override
  String toString() => 'ChatUnavailableException';
}

// ── Service ────────────────────────────────────────────────────────────

class AiChatService {
  AiChatService({required this.patientFileId, required Ref ref}) : _ref = ref;

  final String patientFileId;
  final Ref _ref;

  /// Conversation identity, assigned by the server on the first turn.
  String _conversationId = '';
  String get conversationId => _conversationId;

  /// Sends one turn.
  ///
  /// [starterId] and [starterEdited] describe a curated starter prompt.
  /// An UNEDITED starter has a known intent, so the server may skip the
  /// classifier for it. The flag must be honest: reporting an edited
  /// starter as unedited would route arbitrary user text down a path that
  /// assumes curated wording.
  Future<ChatTurnResult> send(
    String question, {
    String starterId = '',
    bool starterEdited = false,
  }) async {
    final client = _ref.read(grpcClientsProvider).clinical;
    try {
      final resp = await client.askPatientQuestion(
        pb.AskPatientQuestionRequest(
          patientFileId: patientFileId,
          question: question,
          conversationId: _conversationId,
          starterId: starterId,
          starterEdited: starterEdited,
        ),
        // Dluzej niz serwerowy callTimeout (75 s), zeby to serwer zdazyl
        // odpowiedziec wlasnym bledem. Gdyby klient rezygnowal pierwszy,
        // terapeuta widzialby zerwane polaczenie zamiast komunikatu, a
        // tura i tak obciazylaby budzet.
        //
        // Tyle, bo tura jest wolna z zalozenia: trzy sekwencyjne
        // wywolania modelu, z ktorych jedno pisze proze kliniczna.
        // Zmierzone 20.08.2026: A1 10,4 s, A8 25,5 s. Strumieniowanie by
        // to ukrylo, ale weryfikator go zabrania — musi zobaczyc calosc,
        // zanim cokolwiek trafi na ekran.
        options: CallOptions(timeout: const Duration(seconds: 90)),
      );
      _conversationId = resp.conversationId;
      return ChatTurnResult.fromProto(resp);
    } on GrpcError catch (e) {
      if (e.code == StatusCode.unavailable &&
          (e.message ?? '').contains('FEATURE_DISABLED')) {
        throw const ChatUnavailableException();
      }
      rethrow;
    }
  }
}

/// Starter prompts shown on first open and on an empty chat (ADR v1.3
/// section 6).
///
/// The IDs must match the server registry in
/// clinical-svc/internal/chat/starters.go — that is what lets an unedited
/// starter skip the classifier. An ID this list invents would simply be
/// classified normally, which is the safe failure.
@immutable
class ChatStarter {
  const ChatStarter({
    required this.id,
    required this.label,
    required this.prefill,
  });
  final String id;
  final String label;
  final String prefill;
}

// TODO(i18n): these strings belong in the .arb pipeline before release —
// the project rule is that no Polish is hard-coded in widgets. They are
// inline here only so the composition (which starters, in what order)
// stays reviewable in one place while the .arb keys are added.
const List<ChatStarter> kChatStarters = [
  ChatStarter(
    id: 'recent_themes',
    label: 'Ostatnie wątki',
    prefill: 'Jakie wątki wracały w ostatnich sesjach?',
  ),
  ChatStarter(
    id: 'session_prep',
    label: 'Przygotuj mnie na sesję',
    prefill: 'Przygotuj mnie na najbliższą sesję — do czego warto wrócić?',
  ),
  ChatStarter(
    id: 'attendance',
    label: 'Frekwencja i przerwy',
    prefill: 'Ile mieliśmy sesji i jakie były przerwy?',
  ),
  ChatStarter(
    id: 'conceptualization',
    label: 'Konceptualizacja',
    prefill: 'Jak można rozumieć to, co dzieje się z klientem?',
  ),
  ChatStarter(
    id: 'progress',
    label: 'Co się zmieniło',
    prefill: 'Co zmieniło się w pracy z klientem przez ostatnie miesiące?',
  ),
  ChatStarter(
    id: 'directions',
    label: 'Kierunki pracy',
    prefill: 'Jakie kierunki pracy warto rozważyć?',
  ),
];

// ── Providers ──────────────────────────────────────────────────────────

final aiChatServiceFactoryProvider = Provider<AiChatServiceFactory>((ref) {
  return AiChatServiceFactory(ref);
});

class AiChatServiceFactory {
  AiChatServiceFactory(this._ref);
  final Ref _ref;

  /// Creates a service for one patient file.
  ///
  /// Note how little this does now. Building the model context — loading
  /// reports, assembling a prompt, deciding what the model may see — all
  /// moved to the server, where it is subject to the guardrail. The
  /// client no longer knows what goes into a prompt, which is precisely
  /// the property that makes the guardrail unavoidable.
  AiChatService create({required String patientFileId}) {
    return AiChatService(patientFileId: patientFileId, ref: _ref);
  }
}

// ── Conversation notes ─────────────────────────────────────────────────

@immutable
class SummaryTaskState {
  const SummaryTaskState({
    this.isGenerating = false,
    this.summaryResult,
    this.error,
  });
  final bool isGenerating;
  final String? summaryResult;
  final String? error;
}

/// Saves a chat conversation as a patient note.
///
/// The conversation is saved VERBATIM. It used to be run through a
/// second, unguarded model call that "summarized" it — which would now
/// mean generating fresh clinical text about a client outside the
/// classifier, the schema and the verifier: exactly the bypass this
/// rewrite exists to close. If a summary is wanted later, it has to come
/// through AskPatientQuestion like everything else.
class AiChatSummaryNotifier extends Notifier<Map<String, SummaryTaskState>> {
  @override
  Map<String, SummaryTaskState> build() => {};

  Future<String> saveConversationAsNote({
    required String patientId,
    required String? noteId,
    required String fullTranscript,
  }) async {
    final key = (noteId != null && noteId.isNotEmpty) ? noteId : patientId;
    state = {...state, key: const SummaryTaskState(isGenerating: true)};

    try {
      final body = '### Zapis rozmowy z AI\n$fullTranscript'.trim();
      final notesNotifier = ref.read(patientNotesMapProvider.notifier);
      if (noteId != null && noteId.isNotEmpty) {
        await notesNotifier.updateNote(
          patientId,
          noteId,
          'Notatka z rozmowy AI',
          body,
        );
      } else {
        await notesNotifier.addNote(patientId, 'Notatka z rozmowy AI', body);
      }
      state = {
        ...state,
        key: SummaryTaskState(isGenerating: false, summaryResult: body),
      };
      return body;
    } catch (e) {
      state = {
        ...state,
        key: SummaryTaskState(isGenerating: false, error: e.toString()),
      };
      rethrow;
    }
  }
}

final aiChatSummaryProvider =
    NotifierProvider<AiChatSummaryNotifier, Map<String, SummaryTaskState>>(() {
      return AiChatSummaryNotifier();
    });
