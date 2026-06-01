// PatientDto — JSON-serializable cache row mirroring the subset of
// clinical.PatientFile that the Flutter UI actually consumes. We don't
// persist proto messages directly because generated proto classes are
// not designed for stable on-disk serialization (field-number renames,
// reserved-tag promotions etc. would silently shift bytes). Instead
// every cached entity has a thin Dart DTO with explicit toJson/fromJson
// and a fromProto/toProto adapter so schema diffs surface at compile
// time when the .proto changes.
//
// Storage shape: Hive box `patients_v1` keyed by `{therapistId}` holds
// `List<PatientDto>` (encoded as List<Map<String,dynamic>>).

import '../../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../../models/patient.dart';

class PatientDto {
  final String id;
  final String firstName;
  final String lastName;
  final String modalityCode;
  final String languageCode;
  final int sessionCount;
  // Patient contact e-mail (PatientFile.patientEmail, docs/22). Empty
  // when none on file.
  final String email;

  const PatientDto({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.modalityCode,
    required this.languageCode,
    required this.sessionCount,
    this.email = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'modalityCode': modalityCode,
        'languageCode': languageCode,
        'sessionCount': sessionCount,
        'email': email,
      };

  factory PatientDto.fromJson(Map<String, dynamic> j) => PatientDto(
        id: j['id'] as String,
        firstName: j['firstName'] as String? ?? '',
        lastName: j['lastName'] as String? ?? '',
        modalityCode: j['modalityCode'] as String? ?? '',
        languageCode: j['languageCode'] as String? ?? '',
        sessionCount: (j['sessionCount'] as num?)?.toInt() ?? 0,
        email: j['email'] as String? ?? '',
      );

  // sessionCount is not on the proto today; if/when ListPatientFiles
  // starts returning it, source from there. For now consumers populate
  // it from sessions cache or leave 0.
  factory PatientDto.fromProto(
    clinical_pb.PatientFile p, {
    int sessionCount = 0,
  }) =>
      PatientDto(
        id: p.id,
        firstName: p.patientFirstName,
        lastName: p.patientLastName,
        modalityCode: p.modalityCode,
        languageCode: p.patientLanguageCode,
        sessionCount: sessionCount,
        email: p.patientEmail,
      );

  Patient toModel() => Patient(
        id: id,
        firstName: firstName,
        lastName: lastName,
        modalityCode: modalityCode,
        languageCode: languageCode,
        sessionCount: sessionCount,
        email: email,
      );

  factory PatientDto.fromModel(Patient p) => PatientDto(
        id: p.id,
        firstName: p.firstName,
        lastName: p.lastName,
        modalityCode: p.modalityCode,
        languageCode: p.languageCode,
        sessionCount: p.sessionCount,
        email: p.email,
      );
}
