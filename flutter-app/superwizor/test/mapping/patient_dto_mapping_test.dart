import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/cache/dto/patient_dto.dart';
import 'package:superwizor/generated/clinical/v1/clinical.pb.dart' as pb;

// Guards the proto -> DTO -> model -> cache mapping for every editable
// PatientFile field. The patient e-mail "doesn't save" bug class is exactly
// a dropped field here: the value persists server-side but the client mapping
// loses it, so the edit form reopens empty.
void main() {
  pb.PatientFile buildProto() => pb.PatientFile(
        id: 'pf-1',
        patientFirstName: 'Anna',
        patientLastName: 'Nowak',
        patientLanguageCode: 'pl',
        modalityCode: 'CBT',
        patientEmail: 'anna@example.com',
        lifecycleStatus: 'ACTIVE',
      );

  group('PatientDto.fromProto carries every editable field', () {
    final dto = PatientDto.fromProto(buildProto());

    test('email', () => expect(dto.email, 'anna@example.com'));
    test('firstName', () => expect(dto.firstName, 'Anna'));
    test('lastName', () => expect(dto.lastName, 'Nowak'));
    test('languageCode', () => expect(dto.languageCode, 'pl'));
    test('modalityCode', () => expect(dto.modalityCode, 'CBT'));
    test('lifecycleStatus', () => expect(dto.lifecycleStatus, 'ACTIVE'));
  });

  group('toModel propagates every field', () {
    final model = PatientDto.fromProto(buildProto()).toModel();

    test('email reaches the Patient model (edit form reads patient.email)',
        () => expect(model.email, 'anna@example.com'));
    test('firstName', () => expect(model.firstName, 'Anna'));
    test('lastName', () => expect(model.lastName, 'Nowak'));
    test('lifecycleStatus reaches the Patient model',
        () => expect(model.lifecycleStatus, 'ACTIVE'));
  });

  test('Hive cache round-trip (toJson -> fromJson) preserves email', () {
    final dto = PatientDto.fromProto(buildProto());
    final restored = PatientDto.fromJson(dto.toJson());
    expect(restored.email, 'anna@example.com',
        reason: 'cache serialization must not drop the e-mail');
    expect(restored.firstName, 'Anna');
    expect(restored.lastName, 'Nowak');
  });

  test('empty patient_email maps to empty (cleared), not a crash', () {
    final dto = PatientDto.fromProto(pb.PatientFile(
      id: 'pf-2',
      patientFirstName: 'Bez',
      modalityCode: 'CBT',
    ));
    expect(dto.email, '');
    expect(dto.toModel().email, '');
  });

  // ── lifecycle_status E2E mapping tests (migration 000058) ────────

  group('lifecycle_status propagation', () {
    test('COMPLETED flows through proto -> DTO -> model -> JSON -> model', () {
      final proto = pb.PatientFile(
        id: 'pf-lifecycle-1',
        patientFirstName: 'Test',
        modalityCode: 'CBT',
        lifecycleStatus: 'COMPLETED',
      );
      final dto = PatientDto.fromProto(proto);
      expect(dto.lifecycleStatus, 'COMPLETED');

      final model = dto.toModel();
      expect(model.lifecycleStatus, 'COMPLETED');

      // Cache round-trip
      final restored = PatientDto.fromJson(dto.toJson());
      expect(restored.lifecycleStatus, 'COMPLETED');
      expect(restored.toModel().lifecycleStatus, 'COMPLETED');
    });

    test('PAUSED flows through proto -> DTO -> model -> JSON -> model', () {
      final proto = pb.PatientFile(
        id: 'pf-lifecycle-2',
        patientFirstName: 'Test',
        modalityCode: 'CBT',
        lifecycleStatus: 'PAUSED',
      );
      final dto = PatientDto.fromProto(proto);
      expect(dto.lifecycleStatus, 'PAUSED');
      expect(dto.toModel().lifecycleStatus, 'PAUSED');

      final restored = PatientDto.fromJson(dto.toJson());
      expect(restored.lifecycleStatus, 'PAUSED');
    });

    test('empty lifecycle_status defaults to ACTIVE', () {
      final proto = pb.PatientFile(
        id: 'pf-lifecycle-3',
        patientFirstName: 'Legacy',
        modalityCode: 'CBT',
        // lifecycleStatus intentionally omitted (empty string in proto)
      );
      final dto = PatientDto.fromProto(proto);
      expect(dto.lifecycleStatus, 'ACTIVE',
          reason: 'empty proto lifecycle must default to ACTIVE');
      expect(dto.toModel().lifecycleStatus, 'ACTIVE');
    });

    test('fromJson with missing lifecycleStatus key defaults to ACTIVE', () {
      // Simulates cached data from before migration 000058.
      final json = {
        'id': 'pf-old',
        'firstName': 'Old',
        'lastName': 'Cache',
        'modalityCode': 'CBT',
        'languageCode': 'pl',
        'sessionCount': 5,
        'email': 'old@example.com',
        // No 'lifecycleStatus' key — pre-migration cache entry.
      };
      final dto = PatientDto.fromJson(json);
      expect(dto.lifecycleStatus, 'ACTIVE',
          reason: 'pre-migration cache entries must default to ACTIVE');
    });

    test('fromModel round-trip preserves lifecycle', () {
      final dto = PatientDto.fromProto(pb.PatientFile(
        id: 'pf-rt',
        patientFirstName: 'RT',
        modalityCode: 'CBT',
        lifecycleStatus: 'PAUSED',
      ));
      final model = dto.toModel();
      final back = PatientDto.fromModel(model);
      expect(back.lifecycleStatus, 'PAUSED');
    });
  });

  // ── Field count guard ────────────────────────────────────────────
  // If you add a new field to PatientDto, this test will break —
  // intentionally. It forces you to update all mapping paths.
  test('PatientDto.toJson has expected field count', () {
    final dto = PatientDto.fromProto(buildProto());
    final json = dto.toJson();
    // Current fields: id, firstName, lastName, modalityCode, languageCode,
    // sessionCount, email, lifecycleStatus = 8
    expect(json.length, 8,
        reason:
            'If you added a field to PatientDto, update all mapping paths '
            'and bump this count');
  });
}
