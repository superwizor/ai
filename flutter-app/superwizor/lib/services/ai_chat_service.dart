// AiChatService — wraps Firebase AI Logic (Vertex AI backend) to provide
// a streaming conversational interface for therapists. Builds patient
// context from cached session reports and feeds it as system instruction
// to Gemini.
//
// Model: gemini-2.0-flash via Vertex AI (europe-west4) — cheap, 1M context.
// PHI note: report content is sent to Gemini via Vertex AI (EU-resident,
// Google Cloud DPA). No raw transcripts are sent — only report summaries.
//
// Usage: created per-patient via AiChatServiceFactory; holds ChatSession
// state for the lifetime of the chat screen.

import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../generated/clinical/v1/clinical.pbgrpc.dart' as clinical_grpc;
import '../models/session.dart';
import '../providers/grpc_provider.dart';
import '../providers/patient_notes_provider.dart';
import '../providers/patient_provider.dart';

// ── Constants ──────────────────────────────────────────────

/// Maximum number of full reports to include verbatim in context.
const int _kMaxFullReports = 3;

/// Maximum number of older sessions to include as summaryShort.
const int _kMaxSummaryOnlyReports = 20;

/// The Gemini model to use for chat (user requested gemini-2.5-flash).
const String _kModel = 'gemini-2.5-flash';

// ── System Prompt ──────────────────────────────────────────

String _buildSystemPrompt(String patientAlias, String contextBlock) => '''
Jesteś poznawczym partnerem w gabinecie dla psychoterapeuty. Twoje zadanie to pomagać terapeucie w analizie i refleksji nad sesjami z klientem.

ZASADY:
- Odpowiadaj ZAWSZE po polsku, chyba że terapeuta wyraźnie poprosi o inny język.
- Bądź rówieśnikiem w rozmowie (peer-to-peer), mów bezpośrednio do terapeuty, zachowaj spokój, uważność i merytoryczny ton.
- ZAWSZE używaj określenia "klient" zamiast "pacjent".
- NIGDY NIE używaj słów zakazanych z ramy marki: "pacjent", "kliniczny", "diagnoza", "asystent", "asystent kliniczny", "copilot", "scribe", "chatbot".
- NIE stawiaj diagnoz. Możesz wskazywać wzorce i obserwacje z sesji, ale decyzje merytoryczne należą do terapeuty.
- Bądź konkretny i odwołuj się do treści raportów z sesji.
- Jeśli terapeuta zada pytanie niezwiązane z pracą z klientem lub przebiegiem sesji (np. pytania o wiedzę ogólną, geografię jak wysokość Giewontu, matematykę itp.), odpowiedz uprzejmie w 1 zdaniu:
  "Jako partner w gabinecie wspieram Cię wyłącznie w analizie pracy z klientem i przebiegu sesji."
- Jeśli nie masz wystarczających informacji, powiedz o tym wprost.
- NIE wymyślaj informacji, których nie ma w raportach.

KLIENT: $patientAlias

KONTEKST — RAPORTY Z SESJI:
$contextBlock
''';

// ── Service ────────────────────────────────────────────────

class AiChatStreamEvent {
  final String text;
  final bool isTruncated;
  const AiChatStreamEvent({required this.text, this.isTruncated = false});
}

// ── Service ────────────────────────────────────────────────

class AiChatService {
  AiChatService._({
    required this.patientAlias,
    required ChatSession chatSession,
  }) : _chat = chatSession;

  final String patientAlias;
  final ChatSession _chat;

  /// Sends a user message and returns a stream of partial response events.
  /// Each emission is the FULL accumulated text so far and truncation state.
  Stream<AiChatStreamEvent> sendMessage(String userMessage) async* {
    final stream = _chat.sendMessageStream(Content.text(userMessage));
    final buffer = StringBuffer();
    bool isTruncated = false;
    await for (final chunk in stream) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) {
        buffer.write(text);
      }
      if (chunk.candidates.isNotEmpty &&
          chunk.candidates.first.finishReason == FinishReason.maxTokens) {
        isTruncated = true;
      }
      yield AiChatStreamEvent(
        text: buffer.toString(),
        isTruncated: isTruncated,
      );
    }
  }

  /// Summarizes the entire conversation into a concise note.
  /// Returns the summary text suitable for saving as a PatientNote.
  Future<String> summarizeConversation() async {
    final response = await _chat.sendMessage(Content.text(
      'Stwórz faktograficzne, wysoce szczegółowe podsumowanie naszej rozmowy '
      'w formie ustrukturyzowanej notatki z sesji. Skup się na przekazaniu maksymalnej ilości '
      'przydatnych detali i szczegółów, które pojawiły się w trakcie rozmowy, '
      'aby wesprzeć proces psychoterapii. Zignoruj ogólniki, skup się na faktach, '
      'odkryciach i konkretach. Używaj pojęcia "klient" zamiast "pacjent" i unikaj słowa "kliniczny". '
      'Format: krótka notatka, maksymalnie 3-4 akapity. Nie używaj nagłówków markdown.',
    ));
    return response.text ?? 'Nie udało się wygenerować podsumowania.';
  }

  /// Generates a structured summary for a transcript using Gemini 2.5 Flash.
  static Future<String> generateSummaryForTranscript(String transcript) async {
    final model = FirebaseAI.vertexAI().generativeModel(
      model: _kModel,
      generationConfig: GenerationConfig(
        temperature: 0.2,
      ),
    );
    final response = await model.generateContent([
      Content.text(
        'Jesteś poznawczym partnerem dla psychoterapeuty. Twój cel to stworzyć przejrzyste, ustrukturyzowane i odciążające poznawczo podsumowanie rozmowy.\n\n'
        'ZASADY FORMATOWANIA I TYPOGRAFII (UWOLNIENIE POZNAWCZE):\n'
        '1. Podziel wypowiedź na 2-3 główne sekcje z nagłówkami Markdown H3 (np. `### Główny problem klienta:`, `### Propozycje interwencji na kolejną sesję:`).\n'
        '2. Wewnątrz sekcji stosuj zwięzłe punkty z pogrubioną nazwą pojęciową na początku (np. `• **Wzorce relacyjne:** Opis...`).\n'
        '3. Wewnątrz treści punktów NIE pogrubiaj pojedynczych słów, cytatów ani zwrotów (pogrubiaj WYŁĄCZNIE nazwę pojęciową punktu po znaku `• **Nazwa:**`). Cytaty klienta podawaj w zwykłym tekście w cudzysłowie `"..."`.\n'
        '4. ZAWSZE używaj określenia "klient" zamiast "pacjent".\n'
        '5. BEZWZGLĘDNIE NIE używaj słów zakazanych: "pacjent", "kliniczny", "diagnoza", "asystent", "copilot", "scribe", "chatbot".\n'
        '6. Zachowaj merytoryczny, spokojny i wspierający ton rówieśnika (peer-to-peer).\n\n'
        'ROZMOWA DO PODSUMOWANIA:\n$transcript'
      ),
    ]);
    return response.text ?? 'Nie udało się wygenerować podsumowania.';
  }
}

// ── Factory ────────────────────────────────────────────────

class AiChatServiceFactory {
  AiChatServiceFactory(this._ref);
  final Ref _ref;

  /// Creates an [AiChatService] for the given patient.
  ///
  /// Loads completed session reports directly via gRPC (bypassing the
  /// cache layer to avoid coupling to CacheManager lifecycle) and
  /// builds a context string. If there are ≤ 3 sessions, all full
  /// reports are included. For > 3 sessions, the 3 most recent get
  /// full reports and older ones contribute only summaryShort.
  Future<AiChatService> create({
    required String patientId,
    required String patientAlias,
    required String therapistId,
  }) async {
    // 1. Get completed sessions for this patient
    final sessionsMap =
        _ref.read(sessionsProvider).asData?.value ?? {};
    final allSessions = (sessionsMap[patientId] ?? <Session>[])
        .where((s) => s.status == SessionStatus.completed)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // newest first

    // 2. Fetch report details directly via gRPC for each session
    final client = _ref.read(grpcClientsProvider).clinical;

    final contextParts = <String>[];
    for (var i = 0;
        i < allSessions.length &&
            i < _kMaxFullReports + _kMaxSummaryOnlyReports;
        i++) {
      final session = allSessions[i];
      try {
        final details = await _fetchSessionDetails(client, session.id);
        if (details == null) continue;

        final report = details.reports.isNotEmpty ? details.reports.first : null;
        if (report == null) continue;

        if (i < _kMaxFullReports) {
          // Full report for recent sessions
          contextParts.add(
            '--- Sesja ${session.sessionNumber} '
            '(${_formatDate(session.date)}, ${_formatDuration(session.duration)}) ---\n'
            '${report.content.isNotEmpty ? report.content : report.summaryShort}',
          );
        } else {
          // Summary only for older sessions
          if (report.summaryShort.isNotEmpty) {
            contextParts.add(
              '--- Sesja ${session.sessionNumber} '
              '(${_formatDate(session.date)}) [skrót] ---\n'
              '${report.summaryShort}',
            );
          }
        }
      } catch (e) {
        // Skip sessions that can't be fetched — non-blocking.
        debugPrint('[ai-chat] Failed to fetch session ${session.id}: $e');
        continue;
      }
    }

    final contextBlock = contextParts.isEmpty
        ? 'Brak dostępnych raportów z sesji.'
        : contextParts.join('\n\n');

    // 3. Create the Gemini model + chat session
    final model = FirebaseAI.vertexAI().generativeModel(
      model: _kModel,
      systemInstruction: Content.system(
        _buildSystemPrompt(patientAlias, contextBlock),
      ),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topP: 0.9,
        maxOutputTokens: 6144,
      ),
    );

    final chat = model.startChat();

    return AiChatService._(
      patientAlias: patientAlias,
      chatSession: chat,
    );
  }

  /// Directly fetches session details via gRPC, returning a lightweight
  /// record with report data. Returns null on failure.
  static Future<_SessionReport?> _fetchSessionDetails(
    clinical_grpc.ClinicalServiceClient client,
    String sessionId,
  ) async {
    final res = await client.getSessionDetails(
      clinical_pb.GetSessionDetailsRequest(sessionId: sessionId),
    );
    if (res.reports.isEmpty) return null;
    return _SessionReport(reports: res.reports.map(_ReportSlim.fromProto).toList());
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return '${hours}h ${remaining}min';
  }
}

/// Lightweight report data extracted from the gRPC response.
class _ReportSlim {
  final String content;
  final String summaryShort;

  const _ReportSlim({required this.content, required this.summaryShort});

  factory _ReportSlim.fromProto(clinical_pb.Report r) => _ReportSlim(
        content: r.content,
        summaryShort: r.summaryShort,
      );
}

class _SessionReport {
  final List<_ReportSlim> reports;
  const _SessionReport({required this.reports});
}

// ── Riverpod Provider ──────────────────────────────────────

final aiChatServiceFactoryProvider = Provider<AiChatServiceFactory>((ref) {
  return AiChatServiceFactory(ref);
});

// ── Background Summary Generation Notifier ─────────────────

class SummaryTaskState {
  final bool isGenerating;
  final String? summaryResult;
  final String? error;
  const SummaryTaskState({this.isGenerating = false, this.summaryResult, this.error});
}

class AiChatSummaryNotifier extends Notifier<Map<String, SummaryTaskState>> {
  @override
  Map<String, SummaryTaskState> build() => {};

  Future<String> generateSummaryInBackground({
    required String patientId,
    required String? noteId,
    required String fullTranscript,
  }) async {
    final key = (noteId != null && noteId.isNotEmpty) ? noteId : patientId;
    state = {...state, key: const SummaryTaskState(isGenerating: true)};

    try {
      final summary = await AiChatService.generateSummaryForTranscript(fullTranscript);
      final combinedText = '$summary\n\n---\n### Zapis rozmowy z AI\n$fullTranscript'.trim();

      final notesNotifier = ref.read(patientNotesMapProvider.notifier);
      if (noteId != null && noteId.isNotEmpty) {
        await notesNotifier.updateNote(patientId, noteId, 'Notatka z rozmowy AI', combinedText);
      } else {
        await notesNotifier.addNote(patientId, 'Notatka z rozmowy AI', combinedText);
      }

      state = {...state, key: SummaryTaskState(isGenerating: false, summaryResult: summary)};
      return summary;
    } catch (e) {
      state = {...state, key: SummaryTaskState(isGenerating: false, error: e.toString())};
      rethrow;
    }
  }
}

final aiChatSummaryProvider =
    NotifierProvider<AiChatSummaryNotifier, Map<String, SummaryTaskState>>(() {
  return AiChatSummaryNotifier();
});
