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
import '../providers/patient_provider.dart';

// ── Constants ──────────────────────────────────────────────

/// Maximum number of full reports to include verbatim in context.
const int _kMaxFullReports = 3;

/// Maximum number of older sessions to include as summaryShort.
const int _kMaxSummaryOnlyReports = 20;

/// The Gemini model to use for chat.
const String _kModel = 'gemini-2.5-flash';

// ── System Prompt ──────────────────────────────────────────

String _buildSystemPrompt(String patientAlias, String contextBlock) => '''
Jesteś asystentem klinicznym AI dla psychoterapeuty. Twoje zadanie to pomagać terapeucie w analizie i refleksji nad sesjami terapeutycznymi konkretnego pacjenta.

ZASADY:
- Odpowiadaj ZAWSZE po polsku, chyba że terapeuta wyraźnie poprosi o inny język.
- NIE stawiaj diagnoz. Możesz wskazywać wzorce, ale decyzje kliniczne należą do terapeuty.
- Bądź konkretny i odwołuj się do treści raportów z sesji.
- Zachowuj ton profesjonalny, ale przystępny.
- Jeśli nie masz wystarczających informacji, powiedz o tym wprost.
- NIE wymyślaj informacji, których nie ma w raportach.

PACJENT: $patientAlias

KONTEKST — RAPORTY Z SESJI:
$contextBlock
''';

// ── Service ────────────────────────────────────────────────

class AiChatService {
  AiChatService._({
    required this.patientAlias,
    required ChatSession chatSession,
  }) : _chat = chatSession;

  final String patientAlias;
  final ChatSession _chat;

  /// Sends a user message and returns a stream of partial response text.
  /// Each emission is the FULL accumulated text so far (not a delta).
  Stream<String> sendMessage(String userMessage) async* {
    final stream = _chat.sendMessageStream(Content.text(userMessage));
    final buffer = StringBuffer();
    await for (final chunk in stream) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) {
        buffer.write(text);
        yield buffer.toString();
      }
    }
  }

  /// Summarizes the entire conversation into a concise clinical note.
  /// Returns the summary text suitable for saving as a PatientNote.
  Future<String> summarizeConversation() async {
    final response = await _chat.sendMessage(Content.text(
      'Stwórz faktograficzne, wysoce szczegółowe podsumowanie naszej rozmowy '
      'w formie notatki klinicznej. Skup się na przekazaniu maksymalnej ilości '
      'przydatnych detali i szczegółów, które pojawiły się w trakcie rozmowy, '
      'aby wesprzeć proces psychoterapii. Zignoruj ogólniki, skup się na faktach, '
      'odkryciach i konkretach. '
      'Format: krótka notatka, maksymalnie 3-4 akapity. Nie używaj nagłówków markdown.',
    ));
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
        maxOutputTokens: 2048,
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
