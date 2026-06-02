import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/cache/dto/session_dto.dart';
import 'package:superwizor/generated/clinical/v1/clinical.pb.dart' as pb;

// Guards the proto -> DTO -> model mapping for editable Session fields.
// Regression guard for the rename bug: sessions.name was mapped into
// Session.modality and never into Session.name (the field the card title
// shows), so a persisted rename reverted on every refresh.
void main() {
  pb.Session buildProto({String name = 'Custom Title'}) => pb.Session(
        id: 's-1',
        patientFileId: 'pf-1',
        name: name,
        status: 'COMPLETED',
        sessionNumber: 2,
        durationSeconds: 1234,
      );

  test('custom session name reaches Session.name (the card title)', () {
    final model = SessionDto.fromProto(buildProto(name: 'Sesja z Anną'))
        .toModel();
    expect(model.name, 'Sesja z Anną',
        reason: 'rename must survive proto->DTO->model (was dropped before)');
  });

  test('other fields round-trip', () {
    final model = SessionDto.fromProto(buildProto()).toModel();
    expect(model.id, 's-1');
    expect(model.status.name, isNotEmpty);
    expect(model.duration.inSeconds, 1234);
  });

  test('Hive cache round-trip preserves name', () {
    final dto = SessionDto.fromProto(buildProto(name: 'Trwała nazwa'));
    final restored = SessionDto.fromJson(dto.toJson());
    expect(restored.name, 'Trwała nazwa',
        reason: 'cache serialization must not drop the session name');
    expect(restored.toModel().name, 'Trwała nazwa');
  });
}
