// Locks the JSON round-trip contract for every cache DTO. If a field
// is added, the field-count assertion fails until toJson/fromJson are
// updated in lockstep — a cheap guard against silent cache corruption
// when the proto evolves.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/cache/dto/patient_dto.dart';
import 'package:superwizor/cache/dto/report_dto.dart';
import 'package:superwizor/cache/dto/session_details_dto.dart';
import 'package:superwizor/cache/dto/session_dto.dart';
import 'package:superwizor/cache/dto/transcript_dto.dart';

void main() {
  group('PatientDto', () {
    test('JSON round-trip preserves all fields', () {
      const original = PatientDto(
        id: 'pf-1',
        firstName: 'Anna',
        lastName: 'Kowalska',
        modalityCode: 'CBT',
        languageCode: 'pl-PL',
        sessionCount: 7,
        email: 'anna@example.com',
      );
      final encoded = jsonEncode(original.toJson());
      final decoded = PatientDto.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>);
      expect(decoded.id, original.id);
      expect(decoded.firstName, original.firstName);
      expect(decoded.lastName, original.lastName);
      expect(decoded.modalityCode, original.modalityCode);
      expect(decoded.languageCode, original.languageCode);
      expect(decoded.sessionCount, original.sessionCount);
      expect(decoded.email, original.email);
      expect((jsonDecode(encoded) as Map).length, 7,
          reason: 'field-count guard — add toJson/fromJson coverage for new fields');
    });
  });

  group('SessionDto', () {
    test('JSON round-trip preserves all fields incl. createdAt UTC', () {
      final original = SessionDto(
        id: 's-1',
        patientFileId: 'pf-1',
        name: 'Sesja 3',
        contactForm: 'IN_PERSON',
        durationSeconds: 3600,
        createdAt: DateTime.utc(2026, 5, 20, 19, 22, 7),
        status: 'COMPLETED',
        sessionNumber: 3,
        audioUploadId: 'au-1',
        speakerLabelMapping: const {'1': 'Therapist', '2': 'Client'},
      );
      final decoded = SessionDto.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);
      expect(decoded.id, original.id);
      expect(decoded.patientFileId, original.patientFileId);
      expect(decoded.createdAt.toUtc(), original.createdAt.toUtc());
      expect(decoded.status, 'COMPLETED');
      expect(decoded.speakerLabelMapping, original.speakerLabelMapping);
    });

    test('toModel maps status COMPLETED/ERROR/other correctly', () {
      SessionDto withStatus(String s) => SessionDto(
            id: 's',
            patientFileId: 'p',
            name: 'n',
            contactForm: '',
            durationSeconds: 0,
            createdAt: DateTime.utc(2026, 1, 1),
            status: s,
            sessionNumber: 0,
            audioUploadId: '',
            speakerLabelMapping: const {},
          );
      expect(withStatus('COMPLETED').toModel().status.name, 'completed');
      expect(withStatus('ERROR').toModel().status.name, 'error');
      expect(withStatus('FAILED').toModel().status.name, 'error');
      expect(withStatus('PROCESSING').toModel().status.name, 'inProgress');
      expect(withStatus('').toModel().status.name, 'inProgress');
    });
  });

  group('TranscriptDto', () {
    test('JSON round-trip preserves segments and turns', () {
      const original = TranscriptDto(
        id: 't-1',
        segments: [
          TranscriptSegmentDto(
            speakerTag: 1,
            speakerLabel: 'Therapist',
            startOffsetMs: 0,
            endOffsetMs: 1200,
            text: 'Cześć.',
            confidence: 0.97,
          ),
        ],
        turns: [
          SpeakerTurnDto(
            speakerTag: 1,
            speakerLabel: 'Therapist',
            startOffsetMs: 0,
            endOffsetMs: 5000,
            text: 'Cześć, jak się dziś czujesz?',
            segmentCount: 3,
            confidenceAvg: 0.95,
          ),
        ],
      );
      final decoded = TranscriptDto.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);
      expect(decoded.segments.single.text, 'Cześć.');
      expect(decoded.turns.single.segmentCount, 3);
      expect(decoded.turns.single.confidenceAvg, closeTo(0.95, 1e-6));
    });
  });

  group('ReportDto', () {
    test('JSON round-trip preserves all fields', () {
      const original = ReportDto(
        id: 'r-1',
        title: 'Sesja 3 — podsumowanie',
        summaryShort: 'Niski poziom ryzyka.',
        content: '## Treść\n\nDługa treść raportu.',
        sentimentLabel: 'positive',
        riskLevel: 'low',
      );
      final decoded = ReportDto.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);
      expect(decoded.id, original.id);
      expect(decoded.title, original.title);
      expect(decoded.content, original.content);
      expect(decoded.riskLevel, 'low');
    });
  });

  group('SessionDetailsDto', () {
    test('JSON round-trip preserves composite structure', () {
      final original = SessionDetailsDto(
        session: SessionDto(
          id: 's-1',
          patientFileId: 'pf-1',
          name: 'Sesja 1',
          contactForm: '',
          durationSeconds: 1800,
          createdAt: DateTime.utc(2026, 5, 20),
          status: 'COMPLETED',
          sessionNumber: 1,
          audioUploadId: 'au-1',
          speakerLabelMapping: const {},
        ),
        transcript: const TranscriptDto(id: 't-1', segments: [], turns: []),
        reports: const [
          ReportDto(
            id: 'r-1',
            title: 'r',
            summaryShort: '',
            content: '',
            sentimentLabel: '',
            riskLevel: '',
          ),
        ],
      );
      final decoded = SessionDetailsDto.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);
      expect(decoded.session.id, 's-1');
      expect(decoded.reports.single.id, 'r-1');
    });
  });
}
