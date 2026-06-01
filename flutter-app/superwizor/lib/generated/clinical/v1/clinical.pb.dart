// This is a generated file - do not edit.
//
// Generated from clinical/v1/clinical.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $3;

import 'clinical.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'clinical.pbenum.dart';

class PatientFile extends $pb.GeneratedMessage {
  factory PatientFile({
    $core.String? id,
    $core.String? therapistId,
    $core.String? patientId,
    $core.String? modalityId,
    $core.String? modalityCode,
    $core.String? workingAlias,
    ProcessType? processType,
    $core.String? initialComplaint,
    $core.bool? isProcessClosed,
    $core.bool? hasRecordingConsent,
    $3.Timestamp? consentGivenAt,
    $3.Timestamp? firstConsultationAt,
    $core.String? privateTherapistNotes,
    $3.Timestamp? createdAt,
    $3.Timestamp? updatedAt,
    $core.String? patientFirstName,
    $core.String? patientLastName,
    $core.String? patientLanguageCode,
    $core.String? patientEmail,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (therapistId != null) result.therapistId = therapistId;
    if (patientId != null) result.patientId = patientId;
    if (modalityId != null) result.modalityId = modalityId;
    if (modalityCode != null) result.modalityCode = modalityCode;
    if (workingAlias != null) result.workingAlias = workingAlias;
    if (processType != null) result.processType = processType;
    if (initialComplaint != null) result.initialComplaint = initialComplaint;
    if (isProcessClosed != null) result.isProcessClosed = isProcessClosed;
    if (hasRecordingConsent != null)
      result.hasRecordingConsent = hasRecordingConsent;
    if (consentGivenAt != null) result.consentGivenAt = consentGivenAt;
    if (firstConsultationAt != null)
      result.firstConsultationAt = firstConsultationAt;
    if (privateTherapistNotes != null)
      result.privateTherapistNotes = privateTherapistNotes;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (patientFirstName != null) result.patientFirstName = patientFirstName;
    if (patientLastName != null) result.patientLastName = patientLastName;
    if (patientLanguageCode != null)
      result.patientLanguageCode = patientLanguageCode;
    if (patientEmail != null) result.patientEmail = patientEmail;
    return result;
  }

  PatientFile._();

  factory PatientFile.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PatientFile.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PatientFile',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'therapistId')
    ..aOS(3, _omitFieldNames ? '' : 'patientId')
    ..aOS(4, _omitFieldNames ? '' : 'modalityId')
    ..aOS(5, _omitFieldNames ? '' : 'modalityCode')
    ..aOS(6, _omitFieldNames ? '' : 'workingAlias')
    ..aE<ProcessType>(7, _omitFieldNames ? '' : 'processType',
        enumValues: ProcessType.values)
    ..aOS(8, _omitFieldNames ? '' : 'initialComplaint')
    ..aOB(9, _omitFieldNames ? '' : 'isProcessClosed')
    ..aOB(10, _omitFieldNames ? '' : 'hasRecordingConsent')
    ..aOM<$3.Timestamp>(11, _omitFieldNames ? '' : 'consentGivenAt',
        subBuilder: $3.Timestamp.create)
    ..aOM<$3.Timestamp>(12, _omitFieldNames ? '' : 'firstConsultationAt',
        subBuilder: $3.Timestamp.create)
    ..aOS(13, _omitFieldNames ? '' : 'privateTherapistNotes')
    ..aOM<$3.Timestamp>(14, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $3.Timestamp.create)
    ..aOM<$3.Timestamp>(15, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $3.Timestamp.create)
    ..aOS(16, _omitFieldNames ? '' : 'patientFirstName')
    ..aOS(17, _omitFieldNames ? '' : 'patientLastName')
    ..aOS(18, _omitFieldNames ? '' : 'patientLanguageCode')
    ..aOS(19, _omitFieldNames ? '' : 'patientEmail')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PatientFile clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PatientFile copyWith(void Function(PatientFile) updates) =>
      super.copyWith((message) => updates(message as PatientFile))
          as PatientFile;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PatientFile create() => PatientFile._();
  @$core.override
  PatientFile createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PatientFile getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PatientFile>(create);
  static PatientFile? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get therapistId => $_getSZ(1);
  @$pb.TagNumber(2)
  set therapistId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTherapistId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTherapistId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get patientId => $_getSZ(2);
  @$pb.TagNumber(3)
  set patientId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPatientId() => $_has(2);
  @$pb.TagNumber(3)
  void clearPatientId() => $_clearField(3);

  /// Modality is set at CreatePatientFile time and is intentionally
  /// immutable afterwards — sessions/reports attached to this kartoteka
  /// were analyzed under this modality's prompts and switching mid-process
  /// would silently re-frame past clinical work. Flutter should gray out
  /// the modality picker once the kartoteka exists. If a therapist picks
  /// wrong, the path is DeletePatientFile + recreate.
  @$pb.TagNumber(4)
  $core.String get modalityId => $_getSZ(3);
  @$pb.TagNumber(4)
  set modalityId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasModalityId() => $_has(3);
  @$pb.TagNumber(4)
  void clearModalityId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get modalityCode => $_getSZ(4);
  @$pb.TagNumber(5)
  set modalityCode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasModalityCode() => $_has(4);
  @$pb.TagNumber(5)
  void clearModalityCode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get workingAlias => $_getSZ(5);
  @$pb.TagNumber(6)
  set workingAlias($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasWorkingAlias() => $_has(5);
  @$pb.TagNumber(6)
  void clearWorkingAlias() => $_clearField(6);

  @$pb.TagNumber(7)
  ProcessType get processType => $_getN(6);
  @$pb.TagNumber(7)
  set processType(ProcessType value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasProcessType() => $_has(6);
  @$pb.TagNumber(7)
  void clearProcessType() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get initialComplaint => $_getSZ(7);
  @$pb.TagNumber(8)
  set initialComplaint($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasInitialComplaint() => $_has(7);
  @$pb.TagNumber(8)
  void clearInitialComplaint() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get isProcessClosed => $_getBF(8);
  @$pb.TagNumber(9)
  set isProcessClosed($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIsProcessClosed() => $_has(8);
  @$pb.TagNumber(9)
  void clearIsProcessClosed() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get hasRecordingConsent => $_getBF(9);
  @$pb.TagNumber(10)
  set hasRecordingConsent($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasHasRecordingConsent() => $_has(9);
  @$pb.TagNumber(10)
  void clearHasRecordingConsent() => $_clearField(10);

  @$pb.TagNumber(11)
  $3.Timestamp get consentGivenAt => $_getN(10);
  @$pb.TagNumber(11)
  set consentGivenAt($3.Timestamp value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasConsentGivenAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearConsentGivenAt() => $_clearField(11);
  @$pb.TagNumber(11)
  $3.Timestamp ensureConsentGivenAt() => $_ensure(10);

  @$pb.TagNumber(12)
  $3.Timestamp get firstConsultationAt => $_getN(11);
  @$pb.TagNumber(12)
  set firstConsultationAt($3.Timestamp value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasFirstConsultationAt() => $_has(11);
  @$pb.TagNumber(12)
  void clearFirstConsultationAt() => $_clearField(12);
  @$pb.TagNumber(12)
  $3.Timestamp ensureFirstConsultationAt() => $_ensure(11);

  @$pb.TagNumber(13)
  $core.String get privateTherapistNotes => $_getSZ(12);
  @$pb.TagNumber(13)
  set privateTherapistNotes($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasPrivateTherapistNotes() => $_has(12);
  @$pb.TagNumber(13)
  void clearPrivateTherapistNotes() => $_clearField(13);

  @$pb.TagNumber(14)
  $3.Timestamp get createdAt => $_getN(13);
  @$pb.TagNumber(14)
  set createdAt($3.Timestamp value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasCreatedAt() => $_has(13);
  @$pb.TagNumber(14)
  void clearCreatedAt() => $_clearField(14);
  @$pb.TagNumber(14)
  $3.Timestamp ensureCreatedAt() => $_ensure(13);

  @$pb.TagNumber(15)
  $3.Timestamp get updatedAt => $_getN(14);
  @$pb.TagNumber(15)
  set updatedAt($3.Timestamp value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasUpdatedAt() => $_has(14);
  @$pb.TagNumber(15)
  void clearUpdatedAt() => $_clearField(15);
  @$pb.TagNumber(15)
  $3.Timestamp ensureUpdatedAt() => $_ensure(14);

  /// Patient-user fields — JOIN'd from users(role='PATIENT') via
  /// patient_id (migration 000013). Empty strings when the user row
  /// was deleted via DeletePatientUser (FK SET NULL).
  @$pb.TagNumber(16)
  $core.String get patientFirstName => $_getSZ(15);
  @$pb.TagNumber(16)
  set patientFirstName($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasPatientFirstName() => $_has(15);
  @$pb.TagNumber(16)
  void clearPatientFirstName() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.String get patientLastName => $_getSZ(16);
  @$pb.TagNumber(17)
  set patientLastName($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasPatientLastName() => $_has(16);
  @$pb.TagNumber(17)
  void clearPatientLastName() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.String get patientLanguageCode => $_getSZ(17);
  @$pb.TagNumber(18)
  set patientLanguageCode($core.String value) => $_setString(17, value);
  @$pb.TagNumber(18)
  $core.bool hasPatientLanguageCode() => $_has(17);
  @$pb.TagNumber(18)
  void clearPatientLanguageCode() => $_clearField(18);

  /// Patient contact e-mail (patient_files.patient_email, docs/22). Empty
  /// when none is on file. Drives the "send action plan" e-mail flow.
  @$pb.TagNumber(19)
  $core.String get patientEmail => $_getSZ(18);
  @$pb.TagNumber(19)
  set patientEmail($core.String value) => $_setString(18, value);
  @$pb.TagNumber(19)
  $core.bool hasPatientEmail() => $_has(18);
  @$pb.TagNumber(19)
  void clearPatientEmail() => $_clearField(19);
}

class Modality extends $pb.GeneratedMessage {
  factory Modality({
    $core.String? id,
    $core.String? systemCode,
    $core.String? displayName,
    $core.bool? isSupported,
    $core.String? modalityType,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (systemCode != null) result.systemCode = systemCode;
    if (displayName != null) result.displayName = displayName;
    if (isSupported != null) result.isSupported = isSupported;
    if (modalityType != null) result.modalityType = modalityType;
    return result;
  }

  Modality._();

  factory Modality.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Modality.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Modality',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'systemCode')
    ..aOS(3, _omitFieldNames ? '' : 'displayName')
    ..aOB(4, _omitFieldNames ? '' : 'isSupported')
    ..aOS(5, _omitFieldNames ? '' : 'modalityType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Modality clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Modality copyWith(void Function(Modality) updates) =>
      super.copyWith((message) => updates(message as Modality)) as Modality;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Modality create() => Modality._();
  @$core.override
  Modality createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Modality getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Modality>(create);
  static Modality? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get systemCode => $_getSZ(1);
  @$pb.TagNumber(2)
  set systemCode($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSystemCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearSystemCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get displayName => $_getSZ(2);
  @$pb.TagNumber(3)
  set displayName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDisplayName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isSupported => $_getBF(3);
  @$pb.TagNumber(4)
  set isSupported($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsSupported() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsSupported() => $_clearField(4);

  /// "therapy" or "coaching". Drives downstream label semantics
  /// (clinical vs coaching role vocabulary in transcripts). Added
  /// in migration 000026 (2026-05-25). Empty string for any pre-
  /// migration consumer that hasn't regenerated stubs.
  @$pb.TagNumber(5)
  $core.String get modalityType => $_getSZ(4);
  @$pb.TagNumber(5)
  set modalityType($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasModalityType() => $_has(4);
  @$pb.TagNumber(5)
  void clearModalityType() => $_clearField(5);
}

class CreatePatientFileRequest extends $pb.GeneratedMessage {
  factory CreatePatientFileRequest({
    $core.String? therapistId,
    $core.String? modalityCode,
    $core.String? workingAlias,
    ProcessType? processType,
    $core.String? initialComplaint,
    $core.bool? hasRecordingConsent,
    $core.String? idempotencyKey,
    $core.String? patientFirstName,
    $core.String? patientLastName,
    $core.String? patientLanguageCode,
    $core.String? patientEmail,
  }) {
    final result = create();
    if (therapistId != null) result.therapistId = therapistId;
    if (modalityCode != null) result.modalityCode = modalityCode;
    if (workingAlias != null) result.workingAlias = workingAlias;
    if (processType != null) result.processType = processType;
    if (initialComplaint != null) result.initialComplaint = initialComplaint;
    if (hasRecordingConsent != null)
      result.hasRecordingConsent = hasRecordingConsent;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    if (patientFirstName != null) result.patientFirstName = patientFirstName;
    if (patientLastName != null) result.patientLastName = patientLastName;
    if (patientLanguageCode != null)
      result.patientLanguageCode = patientLanguageCode;
    if (patientEmail != null) result.patientEmail = patientEmail;
    return result;
  }

  CreatePatientFileRequest._();

  factory CreatePatientFileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreatePatientFileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreatePatientFileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'therapistId')
    ..aOS(2, _omitFieldNames ? '' : 'modalityCode')
    ..aOS(3, _omitFieldNames ? '' : 'workingAlias')
    ..aE<ProcessType>(4, _omitFieldNames ? '' : 'processType',
        enumValues: ProcessType.values)
    ..aOS(5, _omitFieldNames ? '' : 'initialComplaint')
    ..aOB(6, _omitFieldNames ? '' : 'hasRecordingConsent')
    ..aOS(7, _omitFieldNames ? '' : 'idempotencyKey')
    ..aOS(8, _omitFieldNames ? '' : 'patientFirstName')
    ..aOS(9, _omitFieldNames ? '' : 'patientLastName')
    ..aOS(10, _omitFieldNames ? '' : 'patientLanguageCode')
    ..aOS(11, _omitFieldNames ? '' : 'patientEmail')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePatientFileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePatientFileRequest copyWith(
          void Function(CreatePatientFileRequest) updates) =>
      super.copyWith((message) => updates(message as CreatePatientFileRequest))
          as CreatePatientFileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreatePatientFileRequest create() => CreatePatientFileRequest._();
  @$core.override
  CreatePatientFileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreatePatientFileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreatePatientFileRequest>(create);
  static CreatePatientFileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get therapistId => $_getSZ(0);
  @$pb.TagNumber(1)
  set therapistId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTherapistId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTherapistId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get modalityCode => $_getSZ(1);
  @$pb.TagNumber(2)
  set modalityCode($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModalityCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearModalityCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get workingAlias => $_getSZ(2);
  @$pb.TagNumber(3)
  set workingAlias($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWorkingAlias() => $_has(2);
  @$pb.TagNumber(3)
  void clearWorkingAlias() => $_clearField(3);

  @$pb.TagNumber(4)
  ProcessType get processType => $_getN(3);
  @$pb.TagNumber(4)
  set processType(ProcessType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasProcessType() => $_has(3);
  @$pb.TagNumber(4)
  void clearProcessType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get initialComplaint => $_getSZ(4);
  @$pb.TagNumber(5)
  set initialComplaint($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInitialComplaint() => $_has(4);
  @$pb.TagNumber(5)
  void clearInitialComplaint() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get hasRecordingConsent => $_getBF(5);
  @$pb.TagNumber(6)
  set hasRecordingConsent($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHasRecordingConsent() => $_has(5);
  @$pb.TagNumber(6)
  void clearHasRecordingConsent() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get idempotencyKey => $_getSZ(6);
  @$pb.TagNumber(7)
  set idempotencyKey($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIdempotencyKey() => $_has(6);
  @$pb.TagNumber(7)
  void clearIdempotencyKey() => $_clearField(7);

  /// Patient-user fields written to the paired users(role='PATIENT')
  /// row in the same transaction. patient_first_name is required;
  /// last_name optional; language_code optional (defaults to the
  /// therapist's ui_language when empty).
  @$pb.TagNumber(8)
  $core.String get patientFirstName => $_getSZ(7);
  @$pb.TagNumber(8)
  set patientFirstName($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPatientFirstName() => $_has(7);
  @$pb.TagNumber(8)
  void clearPatientFirstName() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get patientLastName => $_getSZ(8);
  @$pb.TagNumber(9)
  set patientLastName($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPatientLastName() => $_has(8);
  @$pb.TagNumber(9)
  void clearPatientLastName() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get patientLanguageCode => $_getSZ(9);
  @$pb.TagNumber(10)
  set patientLanguageCode($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasPatientLanguageCode() => $_has(9);
  @$pb.TagNumber(10)
  void clearPatientLanguageCode() => $_clearField(10);

  /// Patient contact e-mail, persisted on patient_files at create time
  /// (migration 000040). Optional; empty leaves it unset.
  @$pb.TagNumber(11)
  $core.String get patientEmail => $_getSZ(10);
  @$pb.TagNumber(11)
  set patientEmail($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasPatientEmail() => $_has(10);
  @$pb.TagNumber(11)
  void clearPatientEmail() => $_clearField(11);
}

class GetPatientFileRequest extends $pb.GeneratedMessage {
  factory GetPatientFileRequest({
    $core.String? patientFileId,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    return result;
  }

  GetPatientFileRequest._();

  factory GetPatientFileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPatientFileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPatientFileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPatientFileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPatientFileRequest copyWith(
          void Function(GetPatientFileRequest) updates) =>
      super.copyWith((message) => updates(message as GetPatientFileRequest))
          as GetPatientFileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPatientFileRequest create() => GetPatientFileRequest._();
  @$core.override
  GetPatientFileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPatientFileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPatientFileRequest>(create);
  static GetPatientFileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);
}

class ListPatientFilesRequest extends $pb.GeneratedMessage {
  factory ListPatientFilesRequest({
    $core.String? therapistId,
    $core.int? pageSize,
    $core.String? pageToken,
  }) {
    final result = create();
    if (therapistId != null) result.therapistId = therapistId;
    if (pageSize != null) result.pageSize = pageSize;
    if (pageToken != null) result.pageToken = pageToken;
    return result;
  }

  ListPatientFilesRequest._();

  factory ListPatientFilesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListPatientFilesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListPatientFilesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'therapistId')
    ..aI(2, _omitFieldNames ? '' : 'pageSize')
    ..aOS(3, _omitFieldNames ? '' : 'pageToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPatientFilesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPatientFilesRequest copyWith(
          void Function(ListPatientFilesRequest) updates) =>
      super.copyWith((message) => updates(message as ListPatientFilesRequest))
          as ListPatientFilesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListPatientFilesRequest create() => ListPatientFilesRequest._();
  @$core.override
  ListPatientFilesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListPatientFilesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListPatientFilesRequest>(create);
  static ListPatientFilesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get therapistId => $_getSZ(0);
  @$pb.TagNumber(1)
  set therapistId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTherapistId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTherapistId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get pageSize => $_getIZ(1);
  @$pb.TagNumber(2)
  set pageSize($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPageSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearPageSize() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get pageToken => $_getSZ(2);
  @$pb.TagNumber(3)
  set pageToken($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPageToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearPageToken() => $_clearField(3);
}

class ListPatientFilesResponse extends $pb.GeneratedMessage {
  factory ListPatientFilesResponse({
    $core.Iterable<PatientFile>? patientFiles,
    $core.String? nextPageToken,
  }) {
    final result = create();
    if (patientFiles != null) result.patientFiles.addAll(patientFiles);
    if (nextPageToken != null) result.nextPageToken = nextPageToken;
    return result;
  }

  ListPatientFilesResponse._();

  factory ListPatientFilesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListPatientFilesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListPatientFilesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<PatientFile>(1, _omitFieldNames ? '' : 'patientFiles',
        subBuilder: PatientFile.create)
    ..aOS(2, _omitFieldNames ? '' : 'nextPageToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPatientFilesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPatientFilesResponse copyWith(
          void Function(ListPatientFilesResponse) updates) =>
      super.copyWith((message) => updates(message as ListPatientFilesResponse))
          as ListPatientFilesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListPatientFilesResponse create() => ListPatientFilesResponse._();
  @$core.override
  ListPatientFilesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListPatientFilesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListPatientFilesResponse>(create);
  static ListPatientFilesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PatientFile> get patientFiles => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get nextPageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set nextPageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextPageToken() => $_clearField(2);
}

/// UpdatePatientFileRequest — therapist-editable fields on a kartoteka.
/// Deliberately excluded:
///   - modality_id / modality_code: immutable after create (see PatientFile.modality_id)
///   - therapist_id / patient_id: ownership is established at create time
///   - has_recording_consent / consent_given_at: separate consent flow
///   - process_type: structural decision, treated like modality
/// Patient-user fields (first_name, last_name, language_code) live on
/// UpdatePatientUserRequest — separate RPC.
class UpdatePatientFileRequest extends $pb.GeneratedMessage {
  factory UpdatePatientFileRequest({
    $core.String? patientFileId,
    $core.String? workingAlias,
    $core.String? initialComplaint,
    $core.String? privateTherapistNotes,
    $core.bool? isProcessClosed,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (workingAlias != null) result.workingAlias = workingAlias;
    if (initialComplaint != null) result.initialComplaint = initialComplaint;
    if (privateTherapistNotes != null)
      result.privateTherapistNotes = privateTherapistNotes;
    if (isProcessClosed != null) result.isProcessClosed = isProcessClosed;
    return result;
  }

  UpdatePatientFileRequest._();

  factory UpdatePatientFileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdatePatientFileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdatePatientFileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..aOS(2, _omitFieldNames ? '' : 'workingAlias')
    ..aOS(3, _omitFieldNames ? '' : 'initialComplaint')
    ..aOS(4, _omitFieldNames ? '' : 'privateTherapistNotes')
    ..aOB(5, _omitFieldNames ? '' : 'isProcessClosed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePatientFileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePatientFileRequest copyWith(
          void Function(UpdatePatientFileRequest) updates) =>
      super.copyWith((message) => updates(message as UpdatePatientFileRequest))
          as UpdatePatientFileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdatePatientFileRequest create() => UpdatePatientFileRequest._();
  @$core.override
  UpdatePatientFileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdatePatientFileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdatePatientFileRequest>(create);
  static UpdatePatientFileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get workingAlias => $_getSZ(1);
  @$pb.TagNumber(2)
  set workingAlias($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkingAlias() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkingAlias() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get initialComplaint => $_getSZ(2);
  @$pb.TagNumber(3)
  set initialComplaint($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInitialComplaint() => $_has(2);
  @$pb.TagNumber(3)
  void clearInitialComplaint() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get privateTherapistNotes => $_getSZ(3);
  @$pb.TagNumber(4)
  set privateTherapistNotes($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPrivateTherapistNotes() => $_has(3);
  @$pb.TagNumber(4)
  void clearPrivateTherapistNotes() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get isProcessClosed => $_getBF(4);
  @$pb.TagNumber(5)
  set isProcessClosed($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsProcessClosed() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsProcessClosed() => $_clearField(5);
}

class DeletePatientFileRequest extends $pb.GeneratedMessage {
  factory DeletePatientFileRequest({
    $core.String? patientFileId,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    return result;
  }

  DeletePatientFileRequest._();

  factory DeletePatientFileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeletePatientFileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeletePatientFileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePatientFileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePatientFileRequest copyWith(
          void Function(DeletePatientFileRequest) updates) =>
      super.copyWith((message) => updates(message as DeletePatientFileRequest))
          as DeletePatientFileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeletePatientFileRequest create() => DeletePatientFileRequest._();
  @$core.override
  DeletePatientFileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeletePatientFileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeletePatientFileRequest>(create);
  static DeletePatientFileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);
}

/// UpdatePatientUser — mutates the paired users(role='PATIENT') row.
/// Identified by patient_file_id so the handler can do the standard
/// therapist-ownership authz on the parent kartoteka. Empty fields
/// mean "leave alone" (server-side COALESCE/NULLIF).
class UpdatePatientUserRequest extends $pb.GeneratedMessage {
  factory UpdatePatientUserRequest({
    $core.String? patientFileId,
    $core.String? firstName,
    $core.String? lastName,
    $core.String? languageCode,
    $core.String? patientEmail,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (languageCode != null) result.languageCode = languageCode;
    if (patientEmail != null) result.patientEmail = patientEmail;
    return result;
  }

  UpdatePatientUserRequest._();

  factory UpdatePatientUserRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdatePatientUserRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdatePatientUserRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..aOS(2, _omitFieldNames ? '' : 'firstName')
    ..aOS(3, _omitFieldNames ? '' : 'lastName')
    ..aOS(4, _omitFieldNames ? '' : 'languageCode')
    ..aOS(5, _omitFieldNames ? '' : 'patientEmail')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePatientUserRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePatientUserRequest copyWith(
          void Function(UpdatePatientUserRequest) updates) =>
      super.copyWith((message) => updates(message as UpdatePatientUserRequest))
          as UpdatePatientUserRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdatePatientUserRequest create() => UpdatePatientUserRequest._();
  @$core.override
  UpdatePatientUserRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdatePatientUserRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdatePatientUserRequest>(create);
  static UpdatePatientUserRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get firstName => $_getSZ(1);
  @$pb.TagNumber(2)
  set firstName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFirstName() => $_has(1);
  @$pb.TagNumber(2)
  void clearFirstName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get lastName => $_getSZ(2);
  @$pb.TagNumber(3)
  set lastName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastName() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get languageCode => $_getSZ(3);
  @$pb.TagNumber(4)
  set languageCode($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLanguageCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearLanguageCode() => $_clearField(4);

  /// Patient contact e-mail (docs/22). Persisted to
  /// patient_files.patient_email. Empty string clears it. Optional.
  @$pb.TagNumber(5)
  $core.String get patientEmail => $_getSZ(4);
  @$pb.TagNumber(5)
  set patientEmail($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPatientEmail() => $_has(4);
  @$pb.TagNumber(5)
  void clearPatientEmail() => $_clearField(5);
}

/// ── Patient notes + action plan (docs/22) ──────────────────────────────
class PatientNote extends $pb.GeneratedMessage {
  factory PatientNote({
    $core.String? id,
    $core.String? patientFileId,
    $core.String? kind,
    $core.String? sourceSessionId,
    $core.String? title,
    $core.String? text,
    $3.Timestamp? sentToPatientAt,
    $core.String? sentToEmail,
    $3.Timestamp? createdAt,
    $3.Timestamp? updatedAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (kind != null) result.kind = kind;
    if (sourceSessionId != null) result.sourceSessionId = sourceSessionId;
    if (title != null) result.title = title;
    if (text != null) result.text = text;
    if (sentToPatientAt != null) result.sentToPatientAt = sentToPatientAt;
    if (sentToEmail != null) result.sentToEmail = sentToEmail;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  PatientNote._();

  factory PatientNote.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PatientNote.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PatientNote',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'patientFileId')
    ..aOS(3, _omitFieldNames ? '' : 'kind')
    ..aOS(4, _omitFieldNames ? '' : 'sourceSessionId')
    ..aOS(5, _omitFieldNames ? '' : 'title')
    ..aOS(6, _omitFieldNames ? '' : 'text')
    ..aOM<$3.Timestamp>(7, _omitFieldNames ? '' : 'sentToPatientAt',
        subBuilder: $3.Timestamp.create)
    ..aOS(8, _omitFieldNames ? '' : 'sentToEmail')
    ..aOM<$3.Timestamp>(9, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $3.Timestamp.create)
    ..aOM<$3.Timestamp>(10, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $3.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PatientNote clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PatientNote copyWith(void Function(PatientNote) updates) =>
      super.copyWith((message) => updates(message as PatientNote))
          as PatientNote;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PatientNote create() => PatientNote._();
  @$core.override
  PatientNote createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PatientNote getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PatientNote>(create);
  static PatientNote? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get patientFileId => $_getSZ(1);
  @$pb.TagNumber(2)
  set patientFileId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPatientFileId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPatientFileId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get kind => $_getSZ(2);
  @$pb.TagNumber(3)
  set kind($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearKind() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get sourceSessionId => $_getSZ(3);
  @$pb.TagNumber(4)
  set sourceSessionId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSourceSessionId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSourceSessionId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get title => $_getSZ(4);
  @$pb.TagNumber(5)
  set title($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTitle() => $_has(4);
  @$pb.TagNumber(5)
  void clearTitle() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get text => $_getSZ(5);
  @$pb.TagNumber(6)
  set text($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasText() => $_has(5);
  @$pb.TagNumber(6)
  void clearText() => $_clearField(6);

  @$pb.TagNumber(7)
  $3.Timestamp get sentToPatientAt => $_getN(6);
  @$pb.TagNumber(7)
  set sentToPatientAt($3.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSentToPatientAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearSentToPatientAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $3.Timestamp ensureSentToPatientAt() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.String get sentToEmail => $_getSZ(7);
  @$pb.TagNumber(8)
  set sentToEmail($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSentToEmail() => $_has(7);
  @$pb.TagNumber(8)
  void clearSentToEmail() => $_clearField(8);

  @$pb.TagNumber(9)
  $3.Timestamp get createdAt => $_getN(8);
  @$pb.TagNumber(9)
  set createdAt($3.Timestamp value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasCreatedAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearCreatedAt() => $_clearField(9);
  @$pb.TagNumber(9)
  $3.Timestamp ensureCreatedAt() => $_ensure(8);

  @$pb.TagNumber(10)
  $3.Timestamp get updatedAt => $_getN(9);
  @$pb.TagNumber(10)
  set updatedAt($3.Timestamp value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasUpdatedAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearUpdatedAt() => $_clearField(10);
  @$pb.TagNumber(10)
  $3.Timestamp ensureUpdatedAt() => $_ensure(9);
}

class CreatePatientNoteRequest extends $pb.GeneratedMessage {
  factory CreatePatientNoteRequest({
    $core.String? patientFileId,
    $core.String? title,
    $core.String? text,
    $core.String? kind,
    $core.String? sourceSessionId,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (title != null) result.title = title;
    if (text != null) result.text = text;
    if (kind != null) result.kind = kind;
    if (sourceSessionId != null) result.sourceSessionId = sourceSessionId;
    return result;
  }

  CreatePatientNoteRequest._();

  factory CreatePatientNoteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreatePatientNoteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreatePatientNoteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..aOS(4, _omitFieldNames ? '' : 'kind')
    ..aOS(5, _omitFieldNames ? '' : 'sourceSessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePatientNoteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePatientNoteRequest copyWith(
          void Function(CreatePatientNoteRequest) updates) =>
      super.copyWith((message) => updates(message as CreatePatientNoteRequest))
          as CreatePatientNoteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreatePatientNoteRequest create() => CreatePatientNoteRequest._();
  @$core.override
  CreatePatientNoteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreatePatientNoteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreatePatientNoteRequest>(create);
  static CreatePatientNoteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get kind => $_getSZ(3);
  @$pb.TagNumber(4)
  set kind($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasKind() => $_has(3);
  @$pb.TagNumber(4)
  void clearKind() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get sourceSessionId => $_getSZ(4);
  @$pb.TagNumber(5)
  set sourceSessionId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSourceSessionId() => $_has(4);
  @$pb.TagNumber(5)
  void clearSourceSessionId() => $_clearField(5);
}

class ListPatientNotesRequest extends $pb.GeneratedMessage {
  factory ListPatientNotesRequest({
    $core.String? patientFileId,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    return result;
  }

  ListPatientNotesRequest._();

  factory ListPatientNotesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListPatientNotesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListPatientNotesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPatientNotesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPatientNotesRequest copyWith(
          void Function(ListPatientNotesRequest) updates) =>
      super.copyWith((message) => updates(message as ListPatientNotesRequest))
          as ListPatientNotesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListPatientNotesRequest create() => ListPatientNotesRequest._();
  @$core.override
  ListPatientNotesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListPatientNotesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListPatientNotesRequest>(create);
  static ListPatientNotesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);
}

class ListPatientNotesResponse extends $pb.GeneratedMessage {
  factory ListPatientNotesResponse({
    $core.Iterable<PatientNote>? notes,
  }) {
    final result = create();
    if (notes != null) result.notes.addAll(notes);
    return result;
  }

  ListPatientNotesResponse._();

  factory ListPatientNotesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListPatientNotesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListPatientNotesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<PatientNote>(1, _omitFieldNames ? '' : 'notes',
        subBuilder: PatientNote.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPatientNotesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPatientNotesResponse copyWith(
          void Function(ListPatientNotesResponse) updates) =>
      super.copyWith((message) => updates(message as ListPatientNotesResponse))
          as ListPatientNotesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListPatientNotesResponse create() => ListPatientNotesResponse._();
  @$core.override
  ListPatientNotesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListPatientNotesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListPatientNotesResponse>(create);
  static ListPatientNotesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PatientNote> get notes => $_getList(0);
}

class UpdatePatientNoteRequest extends $pb.GeneratedMessage {
  factory UpdatePatientNoteRequest({
    $core.String? noteId,
    $core.String? title,
    $core.String? text,
  }) {
    final result = create();
    if (noteId != null) result.noteId = noteId;
    if (title != null) result.title = title;
    if (text != null) result.text = text;
    return result;
  }

  UpdatePatientNoteRequest._();

  factory UpdatePatientNoteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdatePatientNoteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdatePatientNoteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'noteId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePatientNoteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePatientNoteRequest copyWith(
          void Function(UpdatePatientNoteRequest) updates) =>
      super.copyWith((message) => updates(message as UpdatePatientNoteRequest))
          as UpdatePatientNoteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdatePatientNoteRequest create() => UpdatePatientNoteRequest._();
  @$core.override
  UpdatePatientNoteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdatePatientNoteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdatePatientNoteRequest>(create);
  static UpdatePatientNoteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get noteId => $_getSZ(0);
  @$pb.TagNumber(1)
  set noteId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNoteId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNoteId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);
}

class DeletePatientNoteRequest extends $pb.GeneratedMessage {
  factory DeletePatientNoteRequest({
    $core.String? noteId,
  }) {
    final result = create();
    if (noteId != null) result.noteId = noteId;
    return result;
  }

  DeletePatientNoteRequest._();

  factory DeletePatientNoteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeletePatientNoteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeletePatientNoteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'noteId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePatientNoteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePatientNoteRequest copyWith(
          void Function(DeletePatientNoteRequest) updates) =>
      super.copyWith((message) => updates(message as DeletePatientNoteRequest))
          as DeletePatientNoteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeletePatientNoteRequest create() => DeletePatientNoteRequest._();
  @$core.override
  DeletePatientNoteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeletePatientNoteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeletePatientNoteRequest>(create);
  static DeletePatientNoteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get noteId => $_getSZ(0);
  @$pb.TagNumber(1)
  set noteId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNoteId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNoteId() => $_clearField(1);
}

/// GetActionPlanDraft — extracts the action-plan section from a session's
/// report (server-side heuristic) to prefill the note editor, plus the
/// patient e-mail availability for the send gate.
class GetActionPlanDraftRequest extends $pb.GeneratedMessage {
  factory GetActionPlanDraftRequest({
    $core.String? sessionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  GetActionPlanDraftRequest._();

  factory GetActionPlanDraftRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetActionPlanDraftRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetActionPlanDraftRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetActionPlanDraftRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetActionPlanDraftRequest copyWith(
          void Function(GetActionPlanDraftRequest) updates) =>
      super.copyWith((message) => updates(message as GetActionPlanDraftRequest))
          as GetActionPlanDraftRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetActionPlanDraftRequest create() => GetActionPlanDraftRequest._();
  @$core.override
  GetActionPlanDraftRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetActionPlanDraftRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetActionPlanDraftRequest>(create);
  static GetActionPlanDraftRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

class ActionPlanDraft extends $pb.GeneratedMessage {
  factory ActionPlanDraft({
    $core.String? suggestedTitle,
    $core.String? suggestedText,
    $core.bool? patientHasEmail,
    $core.String? patientEmailMasked,
  }) {
    final result = create();
    if (suggestedTitle != null) result.suggestedTitle = suggestedTitle;
    if (suggestedText != null) result.suggestedText = suggestedText;
    if (patientHasEmail != null) result.patientHasEmail = patientHasEmail;
    if (patientEmailMasked != null)
      result.patientEmailMasked = patientEmailMasked;
    return result;
  }

  ActionPlanDraft._();

  factory ActionPlanDraft.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ActionPlanDraft.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ActionPlanDraft',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'suggestedTitle')
    ..aOS(2, _omitFieldNames ? '' : 'suggestedText')
    ..aOB(3, _omitFieldNames ? '' : 'patientHasEmail')
    ..aOS(4, _omitFieldNames ? '' : 'patientEmailMasked')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActionPlanDraft clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ActionPlanDraft copyWith(void Function(ActionPlanDraft) updates) =>
      super.copyWith((message) => updates(message as ActionPlanDraft))
          as ActionPlanDraft;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActionPlanDraft create() => ActionPlanDraft._();
  @$core.override
  ActionPlanDraft createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ActionPlanDraft getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ActionPlanDraft>(create);
  static ActionPlanDraft? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get suggestedTitle => $_getSZ(0);
  @$pb.TagNumber(1)
  set suggestedTitle($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuggestedTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuggestedTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get suggestedText => $_getSZ(1);
  @$pb.TagNumber(2)
  set suggestedText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSuggestedText() => $_has(1);
  @$pb.TagNumber(2)
  void clearSuggestedText() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get patientHasEmail => $_getBF(2);
  @$pb.TagNumber(3)
  set patientHasEmail($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPatientHasEmail() => $_has(2);
  @$pb.TagNumber(3)
  void clearPatientHasEmail() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get patientEmailMasked => $_getSZ(3);
  @$pb.TagNumber(4)
  set patientEmailMasked($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPatientEmailMasked() => $_has(3);
  @$pb.TagNumber(4)
  void clearPatientEmailMasked() => $_clearField(4);
}

/// SavePatientNote — create/update a note and optionally e-mail it to the
/// patient. send_to_patient=true with no patient e-mail → FAILED_PRECONDITION
/// "PATIENT_EMAIL_MISSING" (note is still saved).
class SavePatientNoteRequest extends $pb.GeneratedMessage {
  factory SavePatientNoteRequest({
    $core.String? patientFileId,
    $core.String? noteId,
    $core.String? title,
    $core.String? text,
    $core.String? kind,
    $core.String? sourceSessionId,
    $core.bool? sendToPatient,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (noteId != null) result.noteId = noteId;
    if (title != null) result.title = title;
    if (text != null) result.text = text;
    if (kind != null) result.kind = kind;
    if (sourceSessionId != null) result.sourceSessionId = sourceSessionId;
    if (sendToPatient != null) result.sendToPatient = sendToPatient;
    return result;
  }

  SavePatientNoteRequest._();

  factory SavePatientNoteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SavePatientNoteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SavePatientNoteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..aOS(2, _omitFieldNames ? '' : 'noteId')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'text')
    ..aOS(5, _omitFieldNames ? '' : 'kind')
    ..aOS(6, _omitFieldNames ? '' : 'sourceSessionId')
    ..aOB(7, _omitFieldNames ? '' : 'sendToPatient')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SavePatientNoteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SavePatientNoteRequest copyWith(
          void Function(SavePatientNoteRequest) updates) =>
      super.copyWith((message) => updates(message as SavePatientNoteRequest))
          as SavePatientNoteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SavePatientNoteRequest create() => SavePatientNoteRequest._();
  @$core.override
  SavePatientNoteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SavePatientNoteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SavePatientNoteRequest>(create);
  static SavePatientNoteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get noteId => $_getSZ(1);
  @$pb.TagNumber(2)
  set noteId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNoteId() => $_has(1);
  @$pb.TagNumber(2)
  void clearNoteId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get text => $_getSZ(3);
  @$pb.TagNumber(4)
  set text($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasText() => $_has(3);
  @$pb.TagNumber(4)
  void clearText() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get kind => $_getSZ(4);
  @$pb.TagNumber(5)
  set kind($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasKind() => $_has(4);
  @$pb.TagNumber(5)
  void clearKind() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get sourceSessionId => $_getSZ(5);
  @$pb.TagNumber(6)
  set sourceSessionId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSourceSessionId() => $_has(5);
  @$pb.TagNumber(6)
  void clearSourceSessionId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get sendToPatient => $_getBF(6);
  @$pb.TagNumber(7)
  set sendToPatient($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSendToPatient() => $_has(6);
  @$pb.TagNumber(7)
  void clearSendToPatient() => $_clearField(7);
}

class SavePatientNoteResponse extends $pb.GeneratedMessage {
  factory SavePatientNoteResponse({
    PatientNote? note,
    $core.bool? sent,
    $core.String? sendError,
  }) {
    final result = create();
    if (note != null) result.note = note;
    if (sent != null) result.sent = sent;
    if (sendError != null) result.sendError = sendError;
    return result;
  }

  SavePatientNoteResponse._();

  factory SavePatientNoteResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SavePatientNoteResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SavePatientNoteResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOM<PatientNote>(1, _omitFieldNames ? '' : 'note',
        subBuilder: PatientNote.create)
    ..aOB(2, _omitFieldNames ? '' : 'sent')
    ..aOS(3, _omitFieldNames ? '' : 'sendError')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SavePatientNoteResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SavePatientNoteResponse copyWith(
          void Function(SavePatientNoteResponse) updates) =>
      super.copyWith((message) => updates(message as SavePatientNoteResponse))
          as SavePatientNoteResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SavePatientNoteResponse create() => SavePatientNoteResponse._();
  @$core.override
  SavePatientNoteResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SavePatientNoteResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SavePatientNoteResponse>(create);
  static SavePatientNoteResponse? _defaultInstance;

  @$pb.TagNumber(1)
  PatientNote get note => $_getN(0);
  @$pb.TagNumber(1)
  set note(PatientNote value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasNote() => $_has(0);
  @$pb.TagNumber(1)
  void clearNote() => $_clearField(1);
  @$pb.TagNumber(1)
  PatientNote ensureNote() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get sent => $_getBF(1);
  @$pb.TagNumber(2)
  set sent($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSent() => $_has(1);
  @$pb.TagNumber(2)
  void clearSent() => $_clearField(2);

  /// When send_to_patient was set but delivery failed, the note is
  /// STILL saved (note above is populated) and this carries a stable
  /// reason code so the UI can show "saved, but not sent" instead of a
  /// false "save failed". Empty when sent==true or no send was requested.
  ///   PATIENT_EMAIL_MISSING — no patient e-mail on file
  ///   EMAIL_NOT_CONFIGURED  — notification-svc not wired (local dev)
  ///   EMAIL_SEND_FAILED     — notification-svc/Resend rejected the send
  @$pb.TagNumber(3)
  $core.String get sendError => $_getSZ(2);
  @$pb.TagNumber(3)
  set sendError($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSendError() => $_has(2);
  @$pb.TagNumber(3)
  void clearSendError() => $_clearField(3);
}

/// DeletePatientUser — RODO-style erasure of a patient. The user row
/// is hard-deleted; every patient_file that references it cascades
/// (migration 000014 flipped the FK to ON DELETE CASCADE), taking
/// sessions / transcripts / reports / audio_uploads with them. The
/// handler pre-fetches session IDs and publishes session.deleted
/// Pub/Sub events so notification-svc can wipe Firestore mirrors +
/// inbox notifications.
///
/// Identified by patient_file_id rather than patient_id so the handler
/// can do the existing therapist-ownership authz on the parent
/// kartoteka. patient_user rows have no auth metadata of their own.
class DeletePatientUserRequest extends $pb.GeneratedMessage {
  factory DeletePatientUserRequest({
    $core.String? patientFileId,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    return result;
  }

  DeletePatientUserRequest._();

  factory DeletePatientUserRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeletePatientUserRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeletePatientUserRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePatientUserRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePatientUserRequest copyWith(
          void Function(DeletePatientUserRequest) updates) =>
      super.copyWith((message) => updates(message as DeletePatientUserRequest))
          as DeletePatientUserRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeletePatientUserRequest create() => DeletePatientUserRequest._();
  @$core.override
  DeletePatientUserRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeletePatientUserRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeletePatientUserRequest>(create);
  static DeletePatientUserRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);
}

class ListModalitiesResponse extends $pb.GeneratedMessage {
  factory ListModalitiesResponse({
    $core.Iterable<Modality>? modalities,
  }) {
    final result = create();
    if (modalities != null) result.modalities.addAll(modalities);
    return result;
  }

  ListModalitiesResponse._();

  factory ListModalitiesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListModalitiesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListModalitiesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<Modality>(1, _omitFieldNames ? '' : 'modalities',
        subBuilder: Modality.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListModalitiesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListModalitiesResponse copyWith(
          void Function(ListModalitiesResponse) updates) =>
      super.copyWith((message) => updates(message as ListModalitiesResponse))
          as ListModalitiesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListModalitiesResponse create() => ListModalitiesResponse._();
  @$core.override
  ListModalitiesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListModalitiesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListModalitiesResponse>(create);
  static ListModalitiesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Modality> get modalities => $_getList(0);
}

class HealthCheckResponse extends $pb.GeneratedMessage {
  factory HealthCheckResponse({
    $core.String? status,
    $core.String? version,
  }) {
    final result = create();
    if (status != null) result.status = status;
    if (version != null) result.version = version;
    return result;
  }

  HealthCheckResponse._();

  factory HealthCheckResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HealthCheckResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HealthCheckResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'status')
    ..aOS(2, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckResponse copyWith(void Function(HealthCheckResponse) updates) =>
      super.copyWith((message) => updates(message as HealthCheckResponse))
          as HealthCheckResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HealthCheckResponse create() => HealthCheckResponse._();
  @$core.override
  HealthCheckResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HealthCheckResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HealthCheckResponse>(create);
  static HealthCheckResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get status => $_getSZ(0);
  @$pb.TagNumber(1)
  set status($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get version => $_getSZ(1);
  @$pb.TagNumber(2)
  set version($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);
}

class UpdateSpeakerLabelsRequest extends $pb.GeneratedMessage {
  factory UpdateSpeakerLabelsRequest({
    $core.String? sessionId,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? labelMapping,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (labelMapping != null) result.labelMapping.addEntries(labelMapping);
    return result;
  }

  UpdateSpeakerLabelsRequest._();

  factory UpdateSpeakerLabelsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateSpeakerLabelsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateSpeakerLabelsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..m<$core.String, $core.String>(2, _omitFieldNames ? '' : 'labelMapping',
        entryClassName: 'UpdateSpeakerLabelsRequest.LabelMappingEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('clinical.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSpeakerLabelsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSpeakerLabelsRequest copyWith(
          void Function(UpdateSpeakerLabelsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateSpeakerLabelsRequest))
          as UpdateSpeakerLabelsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateSpeakerLabelsRequest create() => UpdateSpeakerLabelsRequest._();
  @$core.override
  UpdateSpeakerLabelsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateSpeakerLabelsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateSpeakerLabelsRequest>(create);
  static UpdateSpeakerLabelsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  /// Mapping: speaker_tag (jako string "1", "2", "3") → nowy label
  /// Przykład: {"1": "Anna Kowalska", "2": "Marek Kowalski"}
  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, $core.String> get labelMapping => $_getMap(1);
}

class UpdateSpeakerLabelsResponse extends $pb.GeneratedMessage {
  factory UpdateSpeakerLabelsResponse({
    $core.String? sessionId,
    $core.String? transcriptId,
    $core.int? segmentsUpdated,
    $core.bool? blobRebuilt,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (transcriptId != null) result.transcriptId = transcriptId;
    if (segmentsUpdated != null) result.segmentsUpdated = segmentsUpdated;
    if (blobRebuilt != null) result.blobRebuilt = blobRebuilt;
    return result;
  }

  UpdateSpeakerLabelsResponse._();

  factory UpdateSpeakerLabelsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateSpeakerLabelsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateSpeakerLabelsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'transcriptId')
    ..aI(3, _omitFieldNames ? '' : 'segmentsUpdated')
    ..aOB(4, _omitFieldNames ? '' : 'blobRebuilt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSpeakerLabelsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSpeakerLabelsResponse copyWith(
          void Function(UpdateSpeakerLabelsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateSpeakerLabelsResponse))
          as UpdateSpeakerLabelsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateSpeakerLabelsResponse create() =>
      UpdateSpeakerLabelsResponse._();
  @$core.override
  UpdateSpeakerLabelsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateSpeakerLabelsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateSpeakerLabelsResponse>(create);
  static UpdateSpeakerLabelsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get transcriptId => $_getSZ(1);
  @$pb.TagNumber(2)
  set transcriptId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTranscriptId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTranscriptId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get segmentsUpdated => $_getIZ(2);
  @$pb.TagNumber(3)
  set segmentsUpdated($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSegmentsUpdated() => $_has(2);
  @$pb.TagNumber(3)
  void clearSegmentsUpdated() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get blobRebuilt => $_getBF(3);
  @$pb.TagNumber(4)
  set blobRebuilt($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBlobRebuilt() => $_has(3);
  @$pb.TagNumber(4)
  void clearBlobRebuilt() => $_clearField(4);
}

class Session extends $pb.GeneratedMessage {
  factory Session({
    $core.String? id,
    $core.String? therapistId,
    $core.String? patientFileId,
    $core.String? audioUploadId,
    $core.String? sessionDate,
    $core.int? sessionNumber,
    $core.int? durationSeconds,
    $core.String? contactForm,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        speakerLabelMapping,
    $core.String? status,
    $3.Timestamp? createdAt,
    $core.String? name,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (therapistId != null) result.therapistId = therapistId;
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (audioUploadId != null) result.audioUploadId = audioUploadId;
    if (sessionDate != null) result.sessionDate = sessionDate;
    if (sessionNumber != null) result.sessionNumber = sessionNumber;
    if (durationSeconds != null) result.durationSeconds = durationSeconds;
    if (contactForm != null) result.contactForm = contactForm;
    if (speakerLabelMapping != null)
      result.speakerLabelMapping.addEntries(speakerLabelMapping);
    if (status != null) result.status = status;
    if (createdAt != null) result.createdAt = createdAt;
    if (name != null) result.name = name;
    return result;
  }

  Session._();

  factory Session.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Session.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Session',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'therapistId')
    ..aOS(3, _omitFieldNames ? '' : 'patientFileId')
    ..aOS(4, _omitFieldNames ? '' : 'audioUploadId')
    ..aOS(5, _omitFieldNames ? '' : 'sessionDate')
    ..aI(6, _omitFieldNames ? '' : 'sessionNumber')
    ..aI(7, _omitFieldNames ? '' : 'durationSeconds')
    ..aOS(8, _omitFieldNames ? '' : 'contactForm')
    ..m<$core.String, $core.String>(
        9, _omitFieldNames ? '' : 'speakerLabelMapping',
        entryClassName: 'Session.SpeakerLabelMappingEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('clinical.v1'))
    ..aOS(10, _omitFieldNames ? '' : 'status')
    ..aOM<$3.Timestamp>(11, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $3.Timestamp.create)
    ..aOS(12, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Session clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Session copyWith(void Function(Session) updates) =>
      super.copyWith((message) => updates(message as Session)) as Session;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Session create() => Session._();
  @$core.override
  Session createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Session getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Session>(create);
  static Session? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get therapistId => $_getSZ(1);
  @$pb.TagNumber(2)
  set therapistId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTherapistId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTherapistId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get patientFileId => $_getSZ(2);
  @$pb.TagNumber(3)
  set patientFileId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPatientFileId() => $_has(2);
  @$pb.TagNumber(3)
  void clearPatientFileId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get audioUploadId => $_getSZ(3);
  @$pb.TagNumber(4)
  set audioUploadId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAudioUploadId() => $_has(3);
  @$pb.TagNumber(4)
  void clearAudioUploadId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get sessionDate => $_getSZ(4);
  @$pb.TagNumber(5)
  set sessionDate($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSessionDate() => $_has(4);
  @$pb.TagNumber(5)
  void clearSessionDate() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get sessionNumber => $_getIZ(5);
  @$pb.TagNumber(6)
  set sessionNumber($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSessionNumber() => $_has(5);
  @$pb.TagNumber(6)
  void clearSessionNumber() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get durationSeconds => $_getIZ(6);
  @$pb.TagNumber(7)
  set durationSeconds($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDurationSeconds() => $_has(6);
  @$pb.TagNumber(7)
  void clearDurationSeconds() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get contactForm => $_getSZ(7);
  @$pb.TagNumber(8)
  set contactForm($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasContactForm() => $_has(7);
  @$pb.TagNumber(8)
  void clearContactForm() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbMap<$core.String, $core.String> get speakerLabelMapping => $_getMap(8);

  @$pb.TagNumber(10)
  $core.String get status => $_getSZ(9);
  @$pb.TagNumber(10)
  set status($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasStatus() => $_has(9);
  @$pb.TagNumber(10)
  void clearStatus() => $_clearField(10);

  @$pb.TagNumber(11)
  $3.Timestamp get createdAt => $_getN(10);
  @$pb.TagNumber(11)
  set createdAt($3.Timestamp value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasCreatedAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearCreatedAt() => $_clearField(11);
  @$pb.TagNumber(11)
  $3.Timestamp ensureCreatedAt() => $_ensure(10);

  /// Free-text label shown in the kartoteka list. Default at create-time:
  /// "<modality display_name> <session_number>". Therapist can rename via
  /// ClinicalService.UpdateSession. Migration 000011 added the column;
  /// ingestion-svc.CompleteAudioUpload populates it on new sessions.
  @$pb.TagNumber(12)
  $core.String get name => $_getSZ(11);
  @$pb.TagNumber(12)
  set name($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasName() => $_has(11);
  @$pb.TagNumber(12)
  void clearName() => $_clearField(12);
}

class ListSessionsRequest extends $pb.GeneratedMessage {
  factory ListSessionsRequest({
    $core.String? patientFileId,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    return result;
  }

  ListSessionsRequest._();

  factory ListSessionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListSessionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSessionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessionsRequest copyWith(void Function(ListSessionsRequest) updates) =>
      super.copyWith((message) => updates(message as ListSessionsRequest))
          as ListSessionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListSessionsRequest create() => ListSessionsRequest._();
  @$core.override
  ListSessionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListSessionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSessionsRequest>(create);
  static ListSessionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);
}

/// UpdateSession — rename a session. Currently `name` is the only
/// mutable field; add more here as edit needs surface (e.g. session_date
/// correction). Empty `name` is rejected by the handler.
class UpdateSessionRequest extends $pb.GeneratedMessage {
  factory UpdateSessionRequest({
    $core.String? sessionId,
    $core.String? name,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (name != null) result.name = name;
    return result;
  }

  UpdateSessionRequest._();

  factory UpdateSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSessionRequest copyWith(void Function(UpdateSessionRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateSessionRequest))
          as UpdateSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateSessionRequest create() => UpdateSessionRequest._();
  @$core.override
  UpdateSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateSessionRequest>(create);
  static UpdateSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);
}

/// DeleteSession — hard delete via CASCADE (migration 000012).
/// Removes transcripts, reports, hitop_measurements, audio_uploads
/// rows referencing this session. Publishes session.deleted Pub/Sub
/// event so notification-svc can purge the Firestore mirror + inbox.
class DeleteSessionRequest extends $pb.GeneratedMessage {
  factory DeleteSessionRequest({
    $core.String? sessionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  DeleteSessionRequest._();

  factory DeleteSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSessionRequest copyWith(void Function(DeleteSessionRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteSessionRequest))
          as DeleteSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteSessionRequest create() => DeleteSessionRequest._();
  @$core.override
  DeleteSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteSessionRequest>(create);
  static DeleteSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

class CancelSessionRequest extends $pb.GeneratedMessage {
  factory CancelSessionRequest({
    $core.String? sessionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  CancelSessionRequest._();

  factory CancelSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CancelSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CancelSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelSessionRequest copyWith(void Function(CancelSessionRequest) updates) =>
      super.copyWith((message) => updates(message as CancelSessionRequest))
          as CancelSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CancelSessionRequest create() => CancelSessionRequest._();
  @$core.override
  CancelSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CancelSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CancelSessionRequest>(create);
  static CancelSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

class ListSessionsResponse extends $pb.GeneratedMessage {
  factory ListSessionsResponse({
    $core.Iterable<Session>? sessions,
  }) {
    final result = create();
    if (sessions != null) result.sessions.addAll(sessions);
    return result;
  }

  ListSessionsResponse._();

  factory ListSessionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListSessionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSessionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<Session>(1, _omitFieldNames ? '' : 'sessions',
        subBuilder: Session.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessionsResponse copyWith(void Function(ListSessionsResponse) updates) =>
      super.copyWith((message) => updates(message as ListSessionsResponse))
          as ListSessionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListSessionsResponse create() => ListSessionsResponse._();
  @$core.override
  ListSessionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListSessionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSessionsResponse>(create);
  static ListSessionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Session> get sessions => $_getList(0);
}

class TranscriptSegment extends $pb.GeneratedMessage {
  factory TranscriptSegment({
    $core.int? speakerTag,
    $core.String? speakerLabel,
    $core.int? startOffsetMs,
    $core.int? endOffsetMs,
    $core.String? text,
    $core.double? confidence,
  }) {
    final result = create();
    if (speakerTag != null) result.speakerTag = speakerTag;
    if (speakerLabel != null) result.speakerLabel = speakerLabel;
    if (startOffsetMs != null) result.startOffsetMs = startOffsetMs;
    if (endOffsetMs != null) result.endOffsetMs = endOffsetMs;
    if (text != null) result.text = text;
    if (confidence != null) result.confidence = confidence;
    return result;
  }

  TranscriptSegment._();

  factory TranscriptSegment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TranscriptSegment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TranscriptSegment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'speakerTag')
    ..aOS(2, _omitFieldNames ? '' : 'speakerLabel')
    ..aI(3, _omitFieldNames ? '' : 'startOffsetMs')
    ..aI(4, _omitFieldNames ? '' : 'endOffsetMs')
    ..aOS(5, _omitFieldNames ? '' : 'text')
    ..aD(6, _omitFieldNames ? '' : 'confidence', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TranscriptSegment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TranscriptSegment copyWith(void Function(TranscriptSegment) updates) =>
      super.copyWith((message) => updates(message as TranscriptSegment))
          as TranscriptSegment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TranscriptSegment create() => TranscriptSegment._();
  @$core.override
  TranscriptSegment createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TranscriptSegment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TranscriptSegment>(create);
  static TranscriptSegment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get speakerTag => $_getIZ(0);
  @$pb.TagNumber(1)
  set speakerTag($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSpeakerTag() => $_has(0);
  @$pb.TagNumber(1)
  void clearSpeakerTag() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get speakerLabel => $_getSZ(1);
  @$pb.TagNumber(2)
  set speakerLabel($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSpeakerLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearSpeakerLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get startOffsetMs => $_getIZ(2);
  @$pb.TagNumber(3)
  set startOffsetMs($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartOffsetMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartOffsetMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get endOffsetMs => $_getIZ(3);
  @$pb.TagNumber(4)
  set endOffsetMs($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEndOffsetMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearEndOffsetMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get text => $_getSZ(4);
  @$pb.TagNumber(5)
  set text($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasText() => $_has(4);
  @$pb.TagNumber(5)
  void clearText() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get confidence => $_getN(5);
  @$pb.TagNumber(6)
  set confidence($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasConfidence() => $_has(5);
  @$pb.TagNumber(6)
  void clearConfidence() => $_clearField(6);
}

class Transcript extends $pb.GeneratedMessage {
  factory Transcript({
    $core.String? id,
    $core.Iterable<TranscriptSegment>? segments,
    $core.Iterable<SpeakerTurn>? turns,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (segments != null) result.segments.addAll(segments);
    if (turns != null) result.turns.addAll(turns);
    return result;
  }

  Transcript._();

  factory Transcript.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Transcript.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Transcript',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..pPM<TranscriptSegment>(2, _omitFieldNames ? '' : 'segments',
        subBuilder: TranscriptSegment.create)
    ..pPM<SpeakerTurn>(3, _omitFieldNames ? '' : 'turns',
        subBuilder: SpeakerTurn.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Transcript clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Transcript copyWith(void Function(Transcript) updates) =>
      super.copyWith((message) => updates(message as Transcript)) as Transcript;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Transcript create() => Transcript._();
  @$core.override
  Transcript createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Transcript getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Transcript>(create);
  static Transcript? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// Per-chunk segments — one row per pause-bounded utterance from STT.
  /// Kept for the speaker-label edit UI (UpdateSpeakerLabels) and any
  /// analysis that needs raw granularity. The read-only transcript view
  /// should bind to `turns` instead, which collapses consecutive
  /// same-speaker chunks into one block.
  @$pb.TagNumber(2)
  $pb.PbList<TranscriptSegment> get segments => $_getList(1);

  /// Speaker-grouped view derived from `segments`. Computed server-side
  /// (clinical-svc.GroupSegmentsIntoTurns) so every client renders the
  /// same shape: one entry per uninterrupted stretch of a single speaker.
  /// Joining/timestamping is policy that lives backend-side; clients
  /// only choose the timestamp display format from start_offset_ms.
  @$pb.TagNumber(3)
  $pb.PbList<SpeakerTurn> get turns => $_getList(2);
}

/// SpeakerTurn — a contiguous span of segments attributed to one
/// speaker. Display contract:
///   "[<speaker_label> · <start_offset_ms formatted>] <text>"
/// `segment_count` exists so a future "expand to raw chunks" UI can
/// jump back to the underlying TranscriptSegments without an extra
/// fetch. `confidence_avg` is the word-count-weighted mean across the
/// underlying segments — fall back to plain mean if word counts are
/// zero (defensive; STT always emits them today).
class SpeakerTurn extends $pb.GeneratedMessage {
  factory SpeakerTurn({
    $core.int? speakerTag,
    $core.String? speakerLabel,
    $core.int? startOffsetMs,
    $core.int? endOffsetMs,
    $core.String? text,
    $core.int? segmentCount,
    $core.double? confidenceAvg,
  }) {
    final result = create();
    if (speakerTag != null) result.speakerTag = speakerTag;
    if (speakerLabel != null) result.speakerLabel = speakerLabel;
    if (startOffsetMs != null) result.startOffsetMs = startOffsetMs;
    if (endOffsetMs != null) result.endOffsetMs = endOffsetMs;
    if (text != null) result.text = text;
    if (segmentCount != null) result.segmentCount = segmentCount;
    if (confidenceAvg != null) result.confidenceAvg = confidenceAvg;
    return result;
  }

  SpeakerTurn._();

  factory SpeakerTurn.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SpeakerTurn.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SpeakerTurn',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'speakerTag')
    ..aOS(2, _omitFieldNames ? '' : 'speakerLabel')
    ..aI(3, _omitFieldNames ? '' : 'startOffsetMs')
    ..aI(4, _omitFieldNames ? '' : 'endOffsetMs')
    ..aOS(5, _omitFieldNames ? '' : 'text')
    ..aI(6, _omitFieldNames ? '' : 'segmentCount')
    ..aD(7, _omitFieldNames ? '' : 'confidenceAvg',
        fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SpeakerTurn clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SpeakerTurn copyWith(void Function(SpeakerTurn) updates) =>
      super.copyWith((message) => updates(message as SpeakerTurn))
          as SpeakerTurn;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SpeakerTurn create() => SpeakerTurn._();
  @$core.override
  SpeakerTurn createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SpeakerTurn getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SpeakerTurn>(create);
  static SpeakerTurn? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get speakerTag => $_getIZ(0);
  @$pb.TagNumber(1)
  set speakerTag($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSpeakerTag() => $_has(0);
  @$pb.TagNumber(1)
  void clearSpeakerTag() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get speakerLabel => $_getSZ(1);
  @$pb.TagNumber(2)
  set speakerLabel($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSpeakerLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearSpeakerLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get startOffsetMs => $_getIZ(2);
  @$pb.TagNumber(3)
  set startOffsetMs($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartOffsetMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartOffsetMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get endOffsetMs => $_getIZ(3);
  @$pb.TagNumber(4)
  set endOffsetMs($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEndOffsetMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearEndOffsetMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get text => $_getSZ(4);
  @$pb.TagNumber(5)
  set text($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasText() => $_has(4);
  @$pb.TagNumber(5)
  void clearText() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get segmentCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set segmentCount($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSegmentCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearSegmentCount() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.double get confidenceAvg => $_getN(6);
  @$pb.TagNumber(7)
  set confidenceAvg($core.double value) => $_setFloat(6, value);
  @$pb.TagNumber(7)
  $core.bool hasConfidenceAvg() => $_has(6);
  @$pb.TagNumber(7)
  void clearConfidenceAvg() => $_clearField(7);
}

class Report extends $pb.GeneratedMessage {
  factory Report({
    $core.String? id,
    $core.String? title,
    $core.String? summaryShort,
    $core.String? content,
    $core.String? sentimentLabel,
    $core.String? riskLevel,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (summaryShort != null) result.summaryShort = summaryShort;
    if (content != null) result.content = content;
    if (sentimentLabel != null) result.sentimentLabel = sentimentLabel;
    if (riskLevel != null) result.riskLevel = riskLevel;
    return result;
  }

  Report._();

  factory Report.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Report.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Report',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'summaryShort')
    ..aOS(4, _omitFieldNames ? '' : 'content')
    ..aOS(5, _omitFieldNames ? '' : 'sentimentLabel')
    ..aOS(6, _omitFieldNames ? '' : 'riskLevel')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Report clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Report copyWith(void Function(Report) updates) =>
      super.copyWith((message) => updates(message as Report)) as Report;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Report create() => Report._();
  @$core.override
  Report createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Report getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Report>(create);
  static Report? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get summaryShort => $_getSZ(2);
  @$pb.TagNumber(3)
  set summaryShort($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSummaryShort() => $_has(2);
  @$pb.TagNumber(3)
  void clearSummaryShort() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get content => $_getSZ(3);
  @$pb.TagNumber(4)
  set content($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(3);
  @$pb.TagNumber(4)
  void clearContent() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get sentimentLabel => $_getSZ(4);
  @$pb.TagNumber(5)
  set sentimentLabel($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSentimentLabel() => $_has(4);
  @$pb.TagNumber(5)
  void clearSentimentLabel() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get riskLevel => $_getSZ(5);
  @$pb.TagNumber(6)
  set riskLevel($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRiskLevel() => $_has(5);
  @$pb.TagNumber(6)
  void clearRiskLevel() => $_clearField(6);
}

class GetSessionDetailsRequest extends $pb.GeneratedMessage {
  factory GetSessionDetailsRequest({
    $core.String? sessionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  GetSessionDetailsRequest._();

  factory GetSessionDetailsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSessionDetailsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSessionDetailsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSessionDetailsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSessionDetailsRequest copyWith(
          void Function(GetSessionDetailsRequest) updates) =>
      super.copyWith((message) => updates(message as GetSessionDetailsRequest))
          as GetSessionDetailsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSessionDetailsRequest create() => GetSessionDetailsRequest._();
  @$core.override
  GetSessionDetailsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetSessionDetailsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSessionDetailsRequest>(create);
  static GetSessionDetailsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

class GetSessionDetailsResponse extends $pb.GeneratedMessage {
  factory GetSessionDetailsResponse({
    Session? session,
    Transcript? transcript,
    $core.Iterable<Report>? reports,
  }) {
    final result = create();
    if (session != null) result.session = session;
    if (transcript != null) result.transcript = transcript;
    if (reports != null) result.reports.addAll(reports);
    return result;
  }

  GetSessionDetailsResponse._();

  factory GetSessionDetailsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSessionDetailsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSessionDetailsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOM<Session>(1, _omitFieldNames ? '' : 'session',
        subBuilder: Session.create)
    ..aOM<Transcript>(2, _omitFieldNames ? '' : 'transcript',
        subBuilder: Transcript.create)
    ..pPM<Report>(3, _omitFieldNames ? '' : 'reports',
        subBuilder: Report.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSessionDetailsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSessionDetailsResponse copyWith(
          void Function(GetSessionDetailsResponse) updates) =>
      super.copyWith((message) => updates(message as GetSessionDetailsResponse))
          as GetSessionDetailsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSessionDetailsResponse create() => GetSessionDetailsResponse._();
  @$core.override
  GetSessionDetailsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetSessionDetailsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSessionDetailsResponse>(create);
  static GetSessionDetailsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Session get session => $_getN(0);
  @$pb.TagNumber(1)
  set session(Session value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
  @$pb.TagNumber(1)
  Session ensureSession() => $_ensure(0);

  @$pb.TagNumber(2)
  Transcript get transcript => $_getN(1);
  @$pb.TagNumber(2)
  set transcript(Transcript value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTranscript() => $_has(1);
  @$pb.TagNumber(2)
  void clearTranscript() => $_clearField(2);
  @$pb.TagNumber(2)
  Transcript ensureTranscript() => $_ensure(1);

  @$pb.TagNumber(3)
  $pb.PbList<Report> get reports => $_getList(2);
}

class ReportRating extends $pb.GeneratedMessage {
  factory ReportRating({
    $core.String? id,
    $core.String? reportId,
    $core.String? therapistId,
    $core.String? rating,
    $core.Iterable<$core.String>? issues,
    $core.String? notes,
    $core.String? source,
    $3.Timestamp? createdAt,
    $3.Timestamp? updatedAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (reportId != null) result.reportId = reportId;
    if (therapistId != null) result.therapistId = therapistId;
    if (rating != null) result.rating = rating;
    if (issues != null) result.issues.addAll(issues);
    if (notes != null) result.notes = notes;
    if (source != null) result.source = source;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  ReportRating._();

  factory ReportRating.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReportRating.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReportRating',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'reportId')
    ..aOS(3, _omitFieldNames ? '' : 'therapistId')
    ..aOS(4, _omitFieldNames ? '' : 'rating')
    ..pPS(5, _omitFieldNames ? '' : 'issues')
    ..aOS(6, _omitFieldNames ? '' : 'notes')
    ..aOS(7, _omitFieldNames ? '' : 'source')
    ..aOM<$3.Timestamp>(8, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $3.Timestamp.create)
    ..aOM<$3.Timestamp>(9, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $3.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReportRating clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReportRating copyWith(void Function(ReportRating) updates) =>
      super.copyWith((message) => updates(message as ReportRating))
          as ReportRating;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReportRating create() => ReportRating._();
  @$core.override
  ReportRating createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReportRating getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReportRating>(create);
  static ReportRating? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reportId => $_getSZ(1);
  @$pb.TagNumber(2)
  set reportId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReportId() => $_has(1);
  @$pb.TagNumber(2)
  void clearReportId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get therapistId => $_getSZ(2);
  @$pb.TagNumber(3)
  set therapistId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTherapistId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTherapistId() => $_clearField(3);

  /// "positive" | "negative"
  @$pb.TagNumber(4)
  $core.String get rating => $_getSZ(3);
  @$pb.TagNumber(4)
  set rating($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRating() => $_has(3);
  @$pb.TagNumber(4)
  void clearRating() => $_clearField(4);

  /// Chip categories the therapist picked on the negative-rating
  /// modal. Empty when rating="positive". See design doc for
  /// canonical list.
  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get issues => $_getList(4);

  /// Optional free-form note ≤200 chars, server-sanitized.
  @$pb.TagNumber(6)
  $core.String get notes => $_getSZ(5);
  @$pb.TagNumber(6)
  set notes($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNotes() => $_has(5);
  @$pb.TagNumber(6)
  void clearNotes() => $_clearField(6);

  /// Origin of the rating: "in_app" | "email" | "post_session" | ...
  @$pb.TagNumber(7)
  $core.String get source => $_getSZ(6);
  @$pb.TagNumber(7)
  set source($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSource() => $_has(6);
  @$pb.TagNumber(7)
  void clearSource() => $_clearField(7);

  @$pb.TagNumber(8)
  $3.Timestamp get createdAt => $_getN(7);
  @$pb.TagNumber(8)
  set createdAt($3.Timestamp value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasCreatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedAt() => $_clearField(8);
  @$pb.TagNumber(8)
  $3.Timestamp ensureCreatedAt() => $_ensure(7);

  @$pb.TagNumber(9)
  $3.Timestamp get updatedAt => $_getN(8);
  @$pb.TagNumber(9)
  set updatedAt($3.Timestamp value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasUpdatedAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearUpdatedAt() => $_clearField(9);
  @$pb.TagNumber(9)
  $3.Timestamp ensureUpdatedAt() => $_ensure(8);
}

class RateReportRequest extends $pb.GeneratedMessage {
  factory RateReportRequest({
    $core.String? reportId,
    $core.String? therapistId,
    $core.String? rating,
    $core.Iterable<$core.String>? issues,
    $core.String? notes,
    $core.String? source,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (reportId != null) result.reportId = reportId;
    if (therapistId != null) result.therapistId = therapistId;
    if (rating != null) result.rating = rating;
    if (issues != null) result.issues.addAll(issues);
    if (notes != null) result.notes = notes;
    if (source != null) result.source = source;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  RateReportRequest._();

  factory RateReportRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RateReportRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RateReportRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reportId')
    ..aOS(2, _omitFieldNames ? '' : 'therapistId')
    ..aOS(3, _omitFieldNames ? '' : 'rating')
    ..pPS(4, _omitFieldNames ? '' : 'issues')
    ..aOS(5, _omitFieldNames ? '' : 'notes')
    ..aOS(6, _omitFieldNames ? '' : 'source')
    ..aOS(7, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RateReportRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RateReportRequest copyWith(void Function(RateReportRequest) updates) =>
      super.copyWith((message) => updates(message as RateReportRequest))
          as RateReportRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RateReportRequest create() => RateReportRequest._();
  @$core.override
  RateReportRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RateReportRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RateReportRequest>(create);
  static RateReportRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reportId => $_getSZ(0);
  @$pb.TagNumber(1)
  set reportId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReportId() => $_has(0);
  @$pb.TagNumber(1)
  void clearReportId() => $_clearField(1);

  /// Therapist doing the rating. Server validates against the
  /// authenticated user — request therapist_id must equal session
  /// therapist_id.
  @$pb.TagNumber(2)
  $core.String get therapistId => $_getSZ(1);
  @$pb.TagNumber(2)
  set therapistId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTherapistId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTherapistId() => $_clearField(2);

  /// "positive" | "negative". Rejects other values.
  @$pb.TagNumber(3)
  $core.String get rating => $_getSZ(2);
  @$pb.TagNumber(3)
  set rating($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRating() => $_has(2);
  @$pb.TagNumber(3)
  void clearRating() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get issues => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get notes => $_getSZ(4);
  @$pb.TagNumber(5)
  set notes($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasNotes() => $_has(4);
  @$pb.TagNumber(5)
  void clearNotes() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get source => $_getSZ(5);
  @$pb.TagNumber(6)
  set source($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSource() => $_has(5);
  @$pb.TagNumber(6)
  void clearSource() => $_clearField(6);

  /// Required. UPSERT key: same (report, therapist) with same
  /// idempotency_key replays as no-op. Different idempotency_key on
  /// the same (report, therapist) overwrites the prior rating
  /// (re-rating is intended behavior).
  @$pb.TagNumber(7)
  $core.String get idempotencyKey => $_getSZ(6);
  @$pb.TagNumber(7)
  set idempotencyKey($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIdempotencyKey() => $_has(6);
  @$pb.TagNumber(7)
  void clearIdempotencyKey() => $_clearField(7);
}

class RateReportResponse extends $pb.GeneratedMessage {
  factory RateReportResponse({
    ReportRating? rating,
  }) {
    final result = create();
    if (rating != null) result.rating = rating;
    return result;
  }

  RateReportResponse._();

  factory RateReportResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RateReportResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RateReportResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOM<ReportRating>(1, _omitFieldNames ? '' : 'rating',
        subBuilder: ReportRating.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RateReportResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RateReportResponse copyWith(void Function(RateReportResponse) updates) =>
      super.copyWith((message) => updates(message as RateReportResponse))
          as RateReportResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RateReportResponse create() => RateReportResponse._();
  @$core.override
  RateReportResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RateReportResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RateReportResponse>(create);
  static RateReportResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ReportRating get rating => $_getN(0);
  @$pb.TagNumber(1)
  set rating(ReportRating value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRating() => $_has(0);
  @$pb.TagNumber(1)
  void clearRating() => $_clearField(1);
  @$pb.TagNumber(1)
  ReportRating ensureRating() => $_ensure(0);
}

class GetReportRatingRequest extends $pb.GeneratedMessage {
  factory GetReportRatingRequest({
    $core.String? reportId,
    $core.String? therapistId,
  }) {
    final result = create();
    if (reportId != null) result.reportId = reportId;
    if (therapistId != null) result.therapistId = therapistId;
    return result;
  }

  GetReportRatingRequest._();

  factory GetReportRatingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetReportRatingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetReportRatingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reportId')
    ..aOS(2, _omitFieldNames ? '' : 'therapistId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetReportRatingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetReportRatingRequest copyWith(
          void Function(GetReportRatingRequest) updates) =>
      super.copyWith((message) => updates(message as GetReportRatingRequest))
          as GetReportRatingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetReportRatingRequest create() => GetReportRatingRequest._();
  @$core.override
  GetReportRatingRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetReportRatingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetReportRatingRequest>(create);
  static GetReportRatingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reportId => $_getSZ(0);
  @$pb.TagNumber(1)
  set reportId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReportId() => $_has(0);
  @$pb.TagNumber(1)
  void clearReportId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get therapistId => $_getSZ(1);
  @$pb.TagNumber(2)
  set therapistId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTherapistId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTherapistId() => $_clearField(2);
}

class GetActiveSuggestionRequest extends $pb.GeneratedMessage {
  factory GetActiveSuggestionRequest({
    $core.String? therapistId,
  }) {
    final result = create();
    if (therapistId != null) result.therapistId = therapistId;
    return result;
  }

  GetActiveSuggestionRequest._();

  factory GetActiveSuggestionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetActiveSuggestionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetActiveSuggestionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'therapistId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetActiveSuggestionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetActiveSuggestionRequest copyWith(
          void Function(GetActiveSuggestionRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetActiveSuggestionRequest))
          as GetActiveSuggestionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetActiveSuggestionRequest create() => GetActiveSuggestionRequest._();
  @$core.override
  GetActiveSuggestionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetActiveSuggestionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetActiveSuggestionRequest>(create);
  static GetActiveSuggestionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get therapistId => $_getSZ(0);
  @$pb.TagNumber(1)
  set therapistId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTherapistId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTherapistId() => $_clearField(1);
}

class PreferenceSuggestion extends $pb.GeneratedMessage {
  factory PreferenceSuggestion({
    $core.String? suggestionId,
    $core.String? dimension,
    $core.String? fromValue,
    $core.String? toValue,
    $core.String? reasonLabel,
    $core.int? triggerCount,
    $core.Iterable<PreferenceSuggestionCandidate>? alternatives,
  }) {
    final result = create();
    if (suggestionId != null) result.suggestionId = suggestionId;
    if (dimension != null) result.dimension = dimension;
    if (fromValue != null) result.fromValue = fromValue;
    if (toValue != null) result.toValue = toValue;
    if (reasonLabel != null) result.reasonLabel = reasonLabel;
    if (triggerCount != null) result.triggerCount = triggerCount;
    if (alternatives != null) result.alternatives.addAll(alternatives);
    return result;
  }

  PreferenceSuggestion._();

  factory PreferenceSuggestion.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PreferenceSuggestion.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PreferenceSuggestion',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'suggestionId')
    ..aOS(2, _omitFieldNames ? '' : 'dimension')
    ..aOS(3, _omitFieldNames ? '' : 'fromValue')
    ..aOS(4, _omitFieldNames ? '' : 'toValue')
    ..aOS(5, _omitFieldNames ? '' : 'reasonLabel')
    ..aI(6, _omitFieldNames ? '' : 'triggerCount')
    ..pPM<PreferenceSuggestionCandidate>(
        7, _omitFieldNames ? '' : 'alternatives',
        subBuilder: PreferenceSuggestionCandidate.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreferenceSuggestion clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreferenceSuggestion copyWith(void Function(PreferenceSuggestion) updates) =>
      super.copyWith((message) => updates(message as PreferenceSuggestion))
          as PreferenceSuggestion;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PreferenceSuggestion create() => PreferenceSuggestion._();
  @$core.override
  PreferenceSuggestion createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PreferenceSuggestion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PreferenceSuggestion>(create);
  static PreferenceSuggestion? _defaultInstance;

  /// Empty string = no active suggestion (Flutter hides banner).
  /// Non-empty = stable ID for telemetry round-trips. All
  /// alternatives below share this same id — the user sees ONE
  /// banner; suggestion_id identifies that banner session, not the
  /// specific dimension.
  @$pb.TagNumber(1)
  $core.String get suggestionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set suggestionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuggestionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuggestionId() => $_clearField(1);

  /// Which preference dimension to nudge (matches a field name on
  /// identity.v1.ReportPreferences). This is the top candidate —
  /// dimension/from_value/to_value/reason_label/trigger_count
  /// duplicate alternatives[0] (or are empty if no candidate
  /// survives filtering).
  @$pb.TagNumber(2)
  $core.String get dimension => $_getSZ(1);
  @$pb.TagNumber(2)
  set dimension($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDimension() => $_has(1);
  @$pb.TagNumber(2)
  void clearDimension() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get fromValue => $_getSZ(2);
  @$pb.TagNumber(3)
  set fromValue($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFromValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearFromValue() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get toValue => $_getSZ(3);
  @$pb.TagNumber(4)
  set toValue($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasToValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearToValue() => $_clearField(4);

  /// Localized chip label that triggered this suggestion (e.g.
  /// "za długi"). UI uses it to render the banner copy.
  @$pb.TagNumber(5)
  $core.String get reasonLabel => $_getSZ(4);
  @$pb.TagNumber(5)
  set reasonLabel($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReasonLabel() => $_has(4);
  @$pb.TagNumber(5)
  void clearReasonLabel() => $_clearField(5);

  /// How many negatives drove this (≥3 by current trigger).
  @$pb.TagNumber(6)
  $core.int get triggerCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set triggerCount($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTriggerCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearTriggerCount() => $_clearField(6);

  /// Ranked candidate list (highest chip count first). The first
  /// entry is identical to the top-level fields above; subsequent
  /// entries are fall-backs the client can iterate when the top
  /// candidate is a no-op (current pref already equals to_value).
  /// Empty when no candidates survive trigger-count + dimension +
  /// cooldown filtering. Always populated for non-empty
  /// suggestion_id responses (alternatives.length >= 1).
  @$pb.TagNumber(7)
  $pb.PbList<PreferenceSuggestionCandidate> get alternatives => $_getList(6);
}

/// PreferenceSuggestionCandidate is one row in the ranked candidate
/// list. Same shape as the top-level PreferenceSuggestion fields
/// minus suggestion_id (shared at the top level).
class PreferenceSuggestionCandidate extends $pb.GeneratedMessage {
  factory PreferenceSuggestionCandidate({
    $core.String? dimension,
    $core.String? fromValue,
    $core.String? toValue,
    $core.String? reasonLabel,
    $core.int? triggerCount,
  }) {
    final result = create();
    if (dimension != null) result.dimension = dimension;
    if (fromValue != null) result.fromValue = fromValue;
    if (toValue != null) result.toValue = toValue;
    if (reasonLabel != null) result.reasonLabel = reasonLabel;
    if (triggerCount != null) result.triggerCount = triggerCount;
    return result;
  }

  PreferenceSuggestionCandidate._();

  factory PreferenceSuggestionCandidate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PreferenceSuggestionCandidate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PreferenceSuggestionCandidate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dimension')
    ..aOS(2, _omitFieldNames ? '' : 'fromValue')
    ..aOS(3, _omitFieldNames ? '' : 'toValue')
    ..aOS(4, _omitFieldNames ? '' : 'reasonLabel')
    ..aI(5, _omitFieldNames ? '' : 'triggerCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreferenceSuggestionCandidate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreferenceSuggestionCandidate copyWith(
          void Function(PreferenceSuggestionCandidate) updates) =>
      super.copyWith(
              (message) => updates(message as PreferenceSuggestionCandidate))
          as PreferenceSuggestionCandidate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PreferenceSuggestionCandidate create() =>
      PreferenceSuggestionCandidate._();
  @$core.override
  PreferenceSuggestionCandidate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PreferenceSuggestionCandidate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PreferenceSuggestionCandidate>(create);
  static PreferenceSuggestionCandidate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dimension => $_getSZ(0);
  @$pb.TagNumber(1)
  set dimension($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDimension() => $_has(0);
  @$pb.TagNumber(1)
  void clearDimension() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get fromValue => $_getSZ(1);
  @$pb.TagNumber(2)
  set fromValue($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFromValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearFromValue() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get toValue => $_getSZ(2);
  @$pb.TagNumber(3)
  set toValue($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasToValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearToValue() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get reasonLabel => $_getSZ(3);
  @$pb.TagNumber(4)
  set reasonLabel($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReasonLabel() => $_has(3);
  @$pb.TagNumber(4)
  void clearReasonLabel() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get triggerCount => $_getIZ(4);
  @$pb.TagNumber(5)
  set triggerCount($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTriggerCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearTriggerCount() => $_clearField(5);
}

class LogPreferenceSuggestionRequest extends $pb.GeneratedMessage {
  factory LogPreferenceSuggestionRequest({
    $core.String? therapistId,
    $core.String? suggestionId,
    $core.String? dimension,
    $core.String? fromValue,
    $core.String? toValue,
    $core.int? triggerCount,
    $core.String? action,
  }) {
    final result = create();
    if (therapistId != null) result.therapistId = therapistId;
    if (suggestionId != null) result.suggestionId = suggestionId;
    if (dimension != null) result.dimension = dimension;
    if (fromValue != null) result.fromValue = fromValue;
    if (toValue != null) result.toValue = toValue;
    if (triggerCount != null) result.triggerCount = triggerCount;
    if (action != null) result.action = action;
    return result;
  }

  LogPreferenceSuggestionRequest._();

  factory LogPreferenceSuggestionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LogPreferenceSuggestionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogPreferenceSuggestionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'therapistId')
    ..aOS(2, _omitFieldNames ? '' : 'suggestionId')
    ..aOS(3, _omitFieldNames ? '' : 'dimension')
    ..aOS(4, _omitFieldNames ? '' : 'fromValue')
    ..aOS(5, _omitFieldNames ? '' : 'toValue')
    ..aI(6, _omitFieldNames ? '' : 'triggerCount')
    ..aOS(7, _omitFieldNames ? '' : 'action')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogPreferenceSuggestionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogPreferenceSuggestionRequest copyWith(
          void Function(LogPreferenceSuggestionRequest) updates) =>
      super.copyWith(
              (message) => updates(message as LogPreferenceSuggestionRequest))
          as LogPreferenceSuggestionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogPreferenceSuggestionRequest create() =>
      LogPreferenceSuggestionRequest._();
  @$core.override
  LogPreferenceSuggestionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LogPreferenceSuggestionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LogPreferenceSuggestionRequest>(create);
  static LogPreferenceSuggestionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get therapistId => $_getSZ(0);
  @$pb.TagNumber(1)
  set therapistId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTherapistId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTherapistId() => $_clearField(1);

  /// Echoed back from PreferenceSuggestion.suggestion_id that
  /// identity-svc handed to the Flutter client.
  @$pb.TagNumber(2)
  $core.String get suggestionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set suggestionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSuggestionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSuggestionId() => $_clearField(2);

  /// Which dimension the banner targeted.
  @$pb.TagNumber(3)
  $core.String get dimension => $_getSZ(2);
  @$pb.TagNumber(3)
  set dimension($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDimension() => $_has(2);
  @$pb.TagNumber(3)
  void clearDimension() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get fromValue => $_getSZ(3);
  @$pb.TagNumber(4)
  set fromValue($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFromValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearFromValue() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get toValue => $_getSZ(4);
  @$pb.TagNumber(5)
  set toValue($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasToValue() => $_has(4);
  @$pb.TagNumber(5)
  void clearToValue() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get triggerCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set triggerCount($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTriggerCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearTriggerCount() => $_clearField(6);

  /// Lifecycle event: "shown" | "applied" | "dismissed".
  /// "applied" fires from UpdateReportPreferences in identity-svc
  /// (we log to both rows so analytics doesn't need a cross-service
  /// join); "shown"/"dismissed" come from the Flutter UI directly.
  @$pb.TagNumber(7)
  $core.String get action => $_getSZ(6);
  @$pb.TagNumber(7)
  set action($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAction() => $_has(6);
  @$pb.TagNumber(7)
  void clearAction() => $_clearField(7);
}

class AdminListSessionsRequest extends $pb.GeneratedMessage {
  factory AdminListSessionsRequest({
    $3.Timestamp? startTime,
    $3.Timestamp? endTime,
    $core.String? therapistFilter,
    $core.int? pageSize,
    $core.int? page,
    $core.String? sortBy,
    $core.String? sortOrder,
  }) {
    final result = create();
    if (startTime != null) result.startTime = startTime;
    if (endTime != null) result.endTime = endTime;
    if (therapistFilter != null) result.therapistFilter = therapistFilter;
    if (pageSize != null) result.pageSize = pageSize;
    if (page != null) result.page = page;
    if (sortBy != null) result.sortBy = sortBy;
    if (sortOrder != null) result.sortOrder = sortOrder;
    return result;
  }

  AdminListSessionsRequest._();

  factory AdminListSessionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListSessionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListSessionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOM<$3.Timestamp>(1, _omitFieldNames ? '' : 'startTime',
        subBuilder: $3.Timestamp.create)
    ..aOM<$3.Timestamp>(2, _omitFieldNames ? '' : 'endTime',
        subBuilder: $3.Timestamp.create)
    ..aOS(3, _omitFieldNames ? '' : 'therapistFilter')
    ..aI(4, _omitFieldNames ? '' : 'pageSize')
    ..aI(5, _omitFieldNames ? '' : 'page')
    ..aOS(6, _omitFieldNames ? '' : 'sortBy')
    ..aOS(7, _omitFieldNames ? '' : 'sortOrder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListSessionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListSessionsRequest copyWith(
          void Function(AdminListSessionsRequest) updates) =>
      super.copyWith((message) => updates(message as AdminListSessionsRequest))
          as AdminListSessionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListSessionsRequest create() => AdminListSessionsRequest._();
  @$core.override
  AdminListSessionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListSessionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListSessionsRequest>(create);
  static AdminListSessionsRequest? _defaultInstance;

  /// Window on sessions.created_at. Both bounds are inclusive on the
  /// low end / exclusive on the high end (PG idiomatic). If unset, the
  /// server uses [now()-24h, now()] so the default UI shows the last
  /// 24h.
  @$pb.TagNumber(1)
  $3.Timestamp get startTime => $_getN(0);
  @$pb.TagNumber(1)
  set startTime($3.Timestamp value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStartTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartTime() => $_clearField(1);
  @$pb.TagNumber(1)
  $3.Timestamp ensureStartTime() => $_ensure(0);

  @$pb.TagNumber(2)
  $3.Timestamp get endTime => $_getN(1);
  @$pb.TagNumber(2)
  set endTime($3.Timestamp value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasEndTime() => $_has(1);
  @$pb.TagNumber(2)
  void clearEndTime() => $_clearField(2);
  @$pb.TagNumber(2)
  $3.Timestamp ensureEndTime() => $_ensure(1);

  /// Case-insensitive substring filter on therapist first_name +
  /// last_name + email. Empty = no filter.
  @$pb.TagNumber(3)
  $core.String get therapistFilter => $_getSZ(2);
  @$pb.TagNumber(3)
  set therapistFilter($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTherapistFilter() => $_has(2);
  @$pb.TagNumber(3)
  void clearTherapistFilter() => $_clearField(3);

  /// Page size. Server clamps to [1, 5000]. Default 100 if zero. 5000
  /// is the CSV-export cap; UI uses a smaller value (50) for paged
  /// browsing.
  @$pb.TagNumber(4)
  $core.int get pageSize => $_getIZ(3);
  @$pb.TagNumber(4)
  set pageSize($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPageSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearPageSize() => $_clearField(4);

  /// Zero-based offset. Server reads page+1 row to compute has_more.
  @$pb.TagNumber(5)
  $core.int get page => $_getIZ(4);
  @$pb.TagNumber(5)
  set page($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPage() => $_has(4);
  @$pb.TagNumber(5)
  void clearPage() => $_clearField(5);

  /// Sort key — one of the allowlisted columns below. Anything else
  /// (including empty) falls back to created_at.
  ///
  ///   "created_at"           — when the upload landed (default)
  ///   "session_date"         — the clinical session date
  ///   "duration_seconds"
  ///   "status"
  ///   "therapist"            — last_name, then first_name
  ///   "organization"         — legal_name
  ///   "plan_name"            — subscription_plans.display_name
  ///   "period_end"           — subscriptions.current_period_end
  ///   "tokens_used"          — usage_counters.tokens_used
  ///
  /// Anything else falls through to the default. The server doesn't
  /// 400 on unknown sort keys — the UI will just behave as if the
  /// sort wasn't set.
  @$pb.TagNumber(6)
  $core.String get sortBy => $_getSZ(5);
  @$pb.TagNumber(6)
  set sortBy($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSortBy() => $_has(5);
  @$pb.TagNumber(6)
  void clearSortBy() => $_clearField(6);

  /// "asc" | "desc". Anything else defaults to "desc".
  @$pb.TagNumber(7)
  $core.String get sortOrder => $_getSZ(6);
  @$pb.TagNumber(7)
  set sortOrder($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSortOrder() => $_has(6);
  @$pb.TagNumber(7)
  void clearSortOrder() => $_clearField(7);
}

class AdminListSessionsResponse extends $pb.GeneratedMessage {
  factory AdminListSessionsResponse({
    $core.Iterable<AdminSessionRow>? sessions,
    $core.bool? hasMore,
  }) {
    final result = create();
    if (sessions != null) result.sessions.addAll(sessions);
    if (hasMore != null) result.hasMore = hasMore;
    return result;
  }

  AdminListSessionsResponse._();

  factory AdminListSessionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListSessionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListSessionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<AdminSessionRow>(1, _omitFieldNames ? '' : 'sessions',
        subBuilder: AdminSessionRow.create)
    ..aOB(2, _omitFieldNames ? '' : 'hasMore')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListSessionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListSessionsResponse copyWith(
          void Function(AdminListSessionsResponse) updates) =>
      super.copyWith((message) => updates(message as AdminListSessionsResponse))
          as AdminListSessionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListSessionsResponse create() => AdminListSessionsResponse._();
  @$core.override
  AdminListSessionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListSessionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListSessionsResponse>(create);
  static AdminListSessionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AdminSessionRow> get sessions => $_getList(0);

  /// True when the server has additional rows past this page.
  @$pb.TagNumber(2)
  $core.bool get hasMore => $_getBF(1);
  @$pb.TagNumber(2)
  set hasMore($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHasMore() => $_has(1);
  @$pb.TagNumber(2)
  void clearHasMore() => $_clearField(2);
}

class AdminSessionRow extends $pb.GeneratedMessage {
  factory AdminSessionRow({
    $core.String? sessionId,
    $core.String? therapistId,
    $core.String? therapistFirstName,
    $core.String? therapistLastName,
    $core.String? therapistEmail,
    $core.String? organizationId,
    $core.String? organizationName,
    $3.Timestamp? createdAt,
    $3.Timestamp? sessionDate,
    $core.int? durationSeconds,
    $core.String? status,
    $core.String? subscriptionPlanName,
    $3.Timestamp? subscriptionPeriodEnd,
    $core.int? subscriptionTokensUsed,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (therapistId != null) result.therapistId = therapistId;
    if (therapistFirstName != null)
      result.therapistFirstName = therapistFirstName;
    if (therapistLastName != null) result.therapistLastName = therapistLastName;
    if (therapistEmail != null) result.therapistEmail = therapistEmail;
    if (organizationId != null) result.organizationId = organizationId;
    if (organizationName != null) result.organizationName = organizationName;
    if (createdAt != null) result.createdAt = createdAt;
    if (sessionDate != null) result.sessionDate = sessionDate;
    if (durationSeconds != null) result.durationSeconds = durationSeconds;
    if (status != null) result.status = status;
    if (subscriptionPlanName != null)
      result.subscriptionPlanName = subscriptionPlanName;
    if (subscriptionPeriodEnd != null)
      result.subscriptionPeriodEnd = subscriptionPeriodEnd;
    if (subscriptionTokensUsed != null)
      result.subscriptionTokensUsed = subscriptionTokensUsed;
    return result;
  }

  AdminSessionRow._();

  factory AdminSessionRow.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminSessionRow.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminSessionRow',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'therapistId')
    ..aOS(3, _omitFieldNames ? '' : 'therapistFirstName')
    ..aOS(4, _omitFieldNames ? '' : 'therapistLastName')
    ..aOS(5, _omitFieldNames ? '' : 'therapistEmail')
    ..aOS(6, _omitFieldNames ? '' : 'organizationId')
    ..aOS(7, _omitFieldNames ? '' : 'organizationName')
    ..aOM<$3.Timestamp>(8, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $3.Timestamp.create)
    ..aOM<$3.Timestamp>(9, _omitFieldNames ? '' : 'sessionDate',
        subBuilder: $3.Timestamp.create)
    ..aI(10, _omitFieldNames ? '' : 'durationSeconds')
    ..aOS(11, _omitFieldNames ? '' : 'status')
    ..aOS(12, _omitFieldNames ? '' : 'subscriptionPlanName')
    ..aOM<$3.Timestamp>(13, _omitFieldNames ? '' : 'subscriptionPeriodEnd',
        subBuilder: $3.Timestamp.create)
    ..aI(14, _omitFieldNames ? '' : 'subscriptionTokensUsed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminSessionRow clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminSessionRow copyWith(void Function(AdminSessionRow) updates) =>
      super.copyWith((message) => updates(message as AdminSessionRow))
          as AdminSessionRow;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminSessionRow create() => AdminSessionRow._();
  @$core.override
  AdminSessionRow createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminSessionRow getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminSessionRow>(create);
  static AdminSessionRow? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get therapistId => $_getSZ(1);
  @$pb.TagNumber(2)
  set therapistId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTherapistId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTherapistId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get therapistFirstName => $_getSZ(2);
  @$pb.TagNumber(3)
  set therapistFirstName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTherapistFirstName() => $_has(2);
  @$pb.TagNumber(3)
  void clearTherapistFirstName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get therapistLastName => $_getSZ(3);
  @$pb.TagNumber(4)
  set therapistLastName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTherapistLastName() => $_has(3);
  @$pb.TagNumber(4)
  void clearTherapistLastName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get therapistEmail => $_getSZ(4);
  @$pb.TagNumber(5)
  set therapistEmail($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTherapistEmail() => $_has(4);
  @$pb.TagNumber(5)
  void clearTherapistEmail() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get organizationId => $_getSZ(5);
  @$pb.TagNumber(6)
  set organizationId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOrganizationId() => $_has(5);
  @$pb.TagNumber(6)
  void clearOrganizationId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get organizationName => $_getSZ(6);
  @$pb.TagNumber(7)
  set organizationName($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasOrganizationName() => $_has(6);
  @$pb.TagNumber(7)
  void clearOrganizationName() => $_clearField(7);

  /// When the session row was created server-side (effectively when
  /// the therapist hit Save in the UI / when the audio upload landed).
  @$pb.TagNumber(8)
  $3.Timestamp get createdAt => $_getN(7);
  @$pb.TagNumber(8)
  set createdAt($3.Timestamp value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasCreatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedAt() => $_clearField(8);
  @$pb.TagNumber(8)
  $3.Timestamp ensureCreatedAt() => $_ensure(7);

  /// The clinical session date — a DATE column, transmitted as a
  /// timestamp at 00:00 UTC for simplicity.
  @$pb.TagNumber(9)
  $3.Timestamp get sessionDate => $_getN(8);
  @$pb.TagNumber(9)
  set sessionDate($3.Timestamp value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSessionDate() => $_has(8);
  @$pb.TagNumber(9)
  void clearSessionDate() => $_clearField(9);
  @$pb.TagNumber(9)
  $3.Timestamp ensureSessionDate() => $_ensure(8);

  /// null for sessions that haven't completed STT yet.
  @$pb.TagNumber(10)
  $core.int get durationSeconds => $_getIZ(9);
  @$pb.TagNumber(10)
  set durationSeconds($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDurationSeconds() => $_has(9);
  @$pb.TagNumber(10)
  void clearDurationSeconds() => $_clearField(10);

  /// session_status enum value as a bare string ("CREATED",
  /// "TRANSCRIBING", "DONE", "FAILED", …).
  @$pb.TagNumber(11)
  $core.String get status => $_getSZ(10);
  @$pb.TagNumber(11)
  set status($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasStatus() => $_has(10);
  @$pb.TagNumber(11)
  void clearStatus() => $_clearField(11);

  /// Subscription context for the therapist's organisation at query
  /// time. All three fields are best-effort — null/empty for org-less
  /// therapists, suspended subscriptions, or counters that haven't
  /// been initialised yet. The handler always picks the most-recent
  /// active row (a single org has at most one ACTIVE subscription at
  /// a time per ADR-BL-001).
  @$pb.TagNumber(12)
  $core.String get subscriptionPlanName => $_getSZ(11);
  @$pb.TagNumber(12)
  set subscriptionPlanName($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasSubscriptionPlanName() => $_has(11);
  @$pb.TagNumber(12)
  void clearSubscriptionPlanName() => $_clearField(12);

  @$pb.TagNumber(13)
  $3.Timestamp get subscriptionPeriodEnd => $_getN(12);
  @$pb.TagNumber(13)
  set subscriptionPeriodEnd($3.Timestamp value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasSubscriptionPeriodEnd() => $_has(12);
  @$pb.TagNumber(13)
  void clearSubscriptionPeriodEnd() => $_clearField(13);
  @$pb.TagNumber(13)
  $3.Timestamp ensureSubscriptionPeriodEnd() => $_ensure(12);

  @$pb.TagNumber(14)
  $core.int get subscriptionTokensUsed => $_getIZ(13);
  @$pb.TagNumber(14)
  set subscriptionTokensUsed($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasSubscriptionTokensUsed() => $_has(13);
  @$pb.TagNumber(14)
  void clearSubscriptionTokensUsed() => $_clearField(14);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
