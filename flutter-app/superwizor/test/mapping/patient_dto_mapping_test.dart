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
      );

  group('PatientDto.fromProto carries every editable field', () {
    final dto = PatientDto.fromProto(buildProto());

    test('email', () => expect(dto.email, 'anna@example.com'));
    test('firstName', () => expect(dto.firstName, 'Anna'));
    test('lastName', () => expect(dto.lastName, 'Nowak'));
    test('languageCode', () => expect(dto.languageCode, 'pl'));
    test('modalityCode', () => expect(dto.modalityCode, 'CBT'));
  });

  group('toModel propagates every field', () {
    final model = PatientDto.fromProto(buildProto()).toModel();

    test('email reaches the Patient model (edit form reads patient.email)',
        () => expect(model.email, 'anna@example.com'));
    test('firstName', () => expect(model.firstName, 'Anna'));
    test('lastName', () => expect(model.lastName, 'Nowak'));
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
}
