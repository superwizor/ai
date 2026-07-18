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
  // Pseudonymous client label (docs/43 §4) — the only identifier the
  // kartoteka carries. Real names are never stored client-side.
  final String workingAlias;
  final String modalityCode;
  final String languageCode;
  final int sessionCount;
  // Client account e-mail resolved server-side (account/invitation).
  // Read-only in the kartoteka. Empty when none on file.
  final String email;
  // 3-state lifecycle (ACTIVE/COMPLETED/PAUSED). Stored in
  // patient_files.lifecycle_status (migration 000058).
  final String lifecycleStatus;

  const PatientDto({
    required this.id,
    required this.workingAlias,
    required this.modalityCode,
    required this.languageCode,
    required this.sessionCount,
    this.email = '',
    this.lifecycleStatus = 'ACTIVE',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'workingAlias': workingAlias,
        'modalityCode': modalityCode,
        'languageCode': languageCode,
        'sessionCount': sessionCount,
        'email': email,
        'lifecycleStatus': lifecycleStatus,
      };

  factory PatientDto.fromJson(Map<String, dynamic> j) {
    // Legacy cache rows (pre docs/43 §4) stored firstName/lastName
    // instead of workingAlias — join them so an old Hive snapshot keeps
    // rendering until the next refresh overwrites it.
    final legacyName =
        '${j['firstName'] as String? ?? ''} ${j['lastName'] as String? ?? ''}'
            .trim();
    return PatientDto(
      id: j['id'] as String,
      workingAlias: j['workingAlias'] as String? ?? legacyName,
      modalityCode: j['modalityCode'] as String? ?? '',
      languageCode: j['languageCode'] as String? ?? '',
      sessionCount: (j['sessionCount'] as num?)?.toInt() ?? 0,
      email: j['email'] as String? ?? '',
      lifecycleStatus: j['lifecycleStatus'] as String? ?? 'ACTIVE',
    );
  }

  // sessionCount is not on the proto today; if/when ListPatientFiles
  // starts returning it, source from there. For now consumers populate
  // it from sessions cache or leave 0.
  factory PatientDto.fromProto(
    clinical_pb.PatientFile p, {
    int sessionCount = 0,
  }) =>
      PatientDto(
        id: p.id,
        // working_alias is the canonical identifier. Very old records
        // could in theory miss it — fall back to the (deprecated) name
        // fields so the row is never blank.
        workingAlias: p.workingAlias.isNotEmpty
            ? p.workingAlias
            : '${p.patientFirstName} ${p.patientLastName}'.trim(),
        modalityCode: p.modalityCode,
        languageCode: p.patientLanguageCode,
        sessionCount: sessionCount,
        email: p.patientEmail,
        lifecycleStatus:
            p.lifecycleStatus.isNotEmpty ? p.lifecycleStatus : 'ACTIVE',
      );

  Patient toModel() => Patient(
        id: id,
        workingAlias: workingAlias,
        modalityCode: modalityCode,
        languageCode: languageCode,
        sessionCount: sessionCount,
        email: email,
        lifecycleStatus: lifecycleStatus,
      );

  factory PatientDto.fromModel(Patient p) => PatientDto(
        id: p.id,
        workingAlias: p.workingAlias,
        modalityCode: p.modalityCode,
        languageCode: p.languageCode,
        sessionCount: p.sessionCount,
        email: p.email,
        lifecycleStatus: p.lifecycleStatus,
      );
}
