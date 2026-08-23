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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart' as $4;
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
    @$core.Deprecated('This field is deprecated.')
    $core.String? patientFirstName,
    @$core.Deprecated('This field is deprecated.')
    $core.String? patientLastName,
    $core.String? patientLanguageCode,
    $core.String? patientEmail,
    $core.String? lifecycleStatus,
    $core.String? avatarConfig,
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
    if (lifecycleStatus != null) result.lifecycleStatus = lifecycleStatus;
    if (avatarConfig != null) result.avatarConfig = avatarConfig;
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
    ..aOS(20, _omitFieldNames ? '' : 'lifecycleStatus')
    ..aOS(21, _omitFieldNames ? '' : 'avatarConfig')
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

  /// DEPRECATED (docs/43 §4, migration 000077): the kartoteka's only
  /// identifier is working_alias — these always come back empty.
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(16)
  $core.String get patientFirstName => $_getSZ(15);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(16)
  set patientFirstName($core.String value) => $_setString(15, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(16)
  $core.bool hasPatientFirstName() => $_has(15);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(16)
  void clearPatientFirstName() => $_clearField(16);

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(17)
  $core.String get patientLastName => $_getSZ(16);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(17)
  set patientLastName($core.String value) => $_setString(16, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(17)
  $core.bool hasPatientLastName() => $_has(16);
  @$core.Deprecated('This field is deprecated.')
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

  /// RESOLVED client e-mail (never stored on the kartoteka since
  /// migration 000077): the activated account's users.email, else the
  /// latest non-revoked invitation's address. Empty when none.
  /// Drives the invite-sheet seed and the "send action plan" gate.
  @$pb.TagNumber(19)
  $core.String get patientEmail => $_getSZ(18);
  @$pb.TagNumber(19)
  set patientEmail($core.String value) => $_setString(18, value);
  @$pb.TagNumber(19)
  $core.bool hasPatientEmail() => $_has(18);
  @$pb.TagNumber(19)
  void clearPatientEmail() => $_clearField(19);

  /// Therapist-managed lifecycle: "ACTIVE" | "COMPLETED" | "PAUSED".
  /// Persisted in patient_files.lifecycle_status (migration 000058).
  /// Replaces the Flutter-only SharedPreferences-backed lifecycle.
  /// COMPLETED also sets is_process_closed=true for backward compat.
  @$pb.TagNumber(20)
  $core.String get lifecycleStatus => $_getSZ(19);
  @$pb.TagNumber(20)
  set lifecycleStatus($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasLifecycleStatus() => $_has(19);
  @$pb.TagNumber(20)
  void clearLifecycleStatus() => $_clearField(20);

  /// Avatar customization JSON: {"label": "AK", "color": 3}.
  /// Empty string when no customization (use auto-initials + default
  /// color). Persisted in patient_files.avatar_config (migration 000059).
  @$pb.TagNumber(21)
  $core.String get avatarConfig => $_getSZ(20);
  @$pb.TagNumber(21)
  set avatarConfig($core.String value) => $_setString(20, value);
  @$pb.TagNumber(21)
  $core.bool hasAvatarConfig() => $_has(20);
  @$pb.TagNumber(21)
  void clearAvatarConfig() => $_clearField(21);
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
    @$core.Deprecated('This field is deprecated.')
    $core.String? patientFirstName,
    @$core.Deprecated('This field is deprecated.')
    $core.String? patientLastName,
    $core.String? patientLanguageCode,
    @$core.Deprecated('This field is deprecated.') $core.String? patientEmail,
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

  /// DEPRECATED (docs/43 §4): accepted for wire compat with older app
  /// builds and IGNORED — the kartoteka identifies the client by
  /// working_alias only and stores no e-mail (invite flow owns it).
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(8)
  $core.String get patientFirstName => $_getSZ(7);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(8)
  set patientFirstName($core.String value) => $_setString(7, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(8)
  $core.bool hasPatientFirstName() => $_has(7);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(8)
  void clearPatientFirstName() => $_clearField(8);

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(9)
  $core.String get patientLastName => $_getSZ(8);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(9)
  set patientLastName($core.String value) => $_setString(8, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(9)
  $core.bool hasPatientLastName() => $_has(8);
  @$core.Deprecated('This field is deprecated.')
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

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(11)
  $core.String get patientEmail => $_getSZ(10);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(11)
  set patientEmail($core.String value) => $_setString(10, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(11)
  $core.bool hasPatientEmail() => $_has(10);
  @$core.Deprecated('This field is deprecated.')
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
    $core.String? lifecycleStatus,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (workingAlias != null) result.workingAlias = workingAlias;
    if (initialComplaint != null) result.initialComplaint = initialComplaint;
    if (privateTherapistNotes != null)
      result.privateTherapistNotes = privateTherapistNotes;
    if (isProcessClosed != null) result.isProcessClosed = isProcessClosed;
    if (lifecycleStatus != null) result.lifecycleStatus = lifecycleStatus;
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
    ..aOS(6, _omitFieldNames ? '' : 'lifecycleStatus')
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

  /// Lifecycle status: "ACTIVE" | "COMPLETED" | "PAUSED".
  /// When set to "COMPLETED", also flips is_process_closed=true.
  /// When set to "ACTIVE" or "PAUSED", flips is_process_closed=false.
  /// Empty string means "leave unchanged".
  @$pb.TagNumber(6)
  $core.String get lifecycleStatus => $_getSZ(5);
  @$pb.TagNumber(6)
  set lifecycleStatus($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLifecycleStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearLifecycleStatus() => $_clearField(6);
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
    @$core.Deprecated('This field is deprecated.') $core.String? firstName,
    @$core.Deprecated('This field is deprecated.') $core.String? lastName,
    $core.String? languageCode,
    @$core.Deprecated('This field is deprecated.') $core.String? patientEmail,
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

  /// DEPRECATED (docs/43 §4): accepted for wire compat and IGNORED —
  /// client names/e-mail are no longer stored (alias is edited via
  /// UpdatePatientFile; e-mail lives in the identity domain).
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  $core.String get firstName => $_getSZ(1);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  set firstName($core.String value) => $_setString(1, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  $core.bool hasFirstName() => $_has(1);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  void clearFirstName() => $_clearField(2);

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  $core.String get lastName => $_getSZ(2);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  set lastName($core.String value) => $_setString(2, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  $core.bool hasLastName() => $_has(2);
  @$core.Deprecated('This field is deprecated.')
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

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(5)
  $core.String get patientEmail => $_getSZ(4);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(5)
  set patientEmail($core.String value) => $_setString(4, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(5)
  $core.bool hasPatientEmail() => $_has(4);
  @$core.Deprecated('This field is deprecated.')
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
    $core.String? authorRole,
    $3.Timestamp? sharedWithClientAt,
    $3.Timestamp? readByClientAt,
    $3.Timestamp? readByTherapistAt,
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
    if (authorRole != null) result.authorRole = authorRole;
    if (sharedWithClientAt != null)
      result.sharedWithClientAt = sharedWithClientAt;
    if (readByClientAt != null) result.readByClientAt = readByClientAt;
    if (readByTherapistAt != null) result.readByTherapistAt = readByTherapistAt;
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
    ..aOS(11, _omitFieldNames ? '' : 'authorRole')
    ..aOM<$3.Timestamp>(12, _omitFieldNames ? '' : 'sharedWithClientAt',
        subBuilder: $3.Timestamp.create)
    ..aOM<$3.Timestamp>(13, _omitFieldNames ? '' : 'readByClientAt',
        subBuilder: $3.Timestamp.create)
    ..aOM<$3.Timestamp>(14, _omitFieldNames ? '' : 'readByTherapistAt',
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

  /// docs/39 client panel. THERAPIST (default) or PATIENT (CLIENT_NOTE
  /// written by the client — read-only for the therapist).
  @$pb.TagNumber(11)
  $core.String get authorRole => $_getSZ(10);
  @$pb.TagNumber(11)
  set authorRole($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasAuthorRole() => $_has(10);
  @$pb.TagNumber(11)
  void clearAuthorRole() => $_clearField(11);

  /// When the therapist shared this note with the client panel
  /// (ShareNoteWithClient). Unset = not shared. Always unset for
  /// CLIENT_NOTE (those are visible to the client by construction).
  @$pb.TagNumber(12)
  $3.Timestamp get sharedWithClientAt => $_getN(11);
  @$pb.TagNumber(12)
  set sharedWithClientAt($3.Timestamp value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasSharedWithClientAt() => $_has(11);
  @$pb.TagNumber(12)
  void clearSharedWithClientAt() => $_clearField(12);
  @$pb.TagNumber(12)
  $3.Timestamp ensureSharedWithClientAt() => $_ensure(11);

  /// When the client opened a shared therapist note. Unset = unread.
  @$pb.TagNumber(13)
  $3.Timestamp get readByClientAt => $_getN(12);
  @$pb.TagNumber(13)
  set readByClientAt($3.Timestamp value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasReadByClientAt() => $_has(12);
  @$pb.TagNumber(13)
  void clearReadByClientAt() => $_clearField(13);
  @$pb.TagNumber(13)
  $3.Timestamp ensureReadByClientAt() => $_ensure(12);

  /// When the therapist first listed this CLIENT_NOTE. ListPatientNotes
  /// returns the pre-mark state, so a fresh client note arrives with
  /// this unset exactly once — the UI renders its "new" badge off that
  /// edge. Unset for therapist-authored notes too (never marked).
  @$pb.TagNumber(14)
  $3.Timestamp get readByTherapistAt => $_getN(13);
  @$pb.TagNumber(14)
  set readByTherapistAt($3.Timestamp value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasReadByTherapistAt() => $_has(13);
  @$pb.TagNumber(14)
  void clearReadByTherapistAt() => $_clearField(14);
  @$pb.TagNumber(14)
  $3.Timestamp ensureReadByTherapistAt() => $_ensure(13);
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
    $3.Timestamp? reportViewedAt,
    $fixnum.Int64? fileSizeBytes,
    $3.Timestamp? sharedWithClientAt,
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
    if (reportViewedAt != null) result.reportViewedAt = reportViewedAt;
    if (fileSizeBytes != null) result.fileSizeBytes = fileSizeBytes;
    if (sharedWithClientAt != null)
      result.sharedWithClientAt = sharedWithClientAt;
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
    ..aOM<$3.Timestamp>(13, _omitFieldNames ? '' : 'reportViewedAt',
        subBuilder: $3.Timestamp.create)
    ..aInt64(14, _omitFieldNames ? '' : 'fileSizeBytes')
    ..aOM<$3.Timestamp>(15, _omitFieldNames ? '' : 'sharedWithClientAt',
        subBuilder: $3.Timestamp.create)
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

  /// Timestamp when the therapist first opened the report for this
  /// session. Zero/empty when unviewed — Flutter shows "nowy raport"
  /// badge. Set via MarkReportViewed RPC. Migration 000059.
  @$pb.TagNumber(13)
  $3.Timestamp get reportViewedAt => $_getN(12);
  @$pb.TagNumber(13)
  set reportViewedAt($3.Timestamp value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasReportViewedAt() => $_has(12);
  @$pb.TagNumber(13)
  void clearReportViewedAt() => $_clearField(13);
  @$pb.TagNumber(13)
  $3.Timestamp ensureReportViewedAt() => $_ensure(12);

  @$pb.TagNumber(14)
  $fixnum.Int64 get fileSizeBytes => $_getI64(13);
  @$pb.TagNumber(14)
  set fileSizeBytes($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(14)
  $core.bool hasFileSizeBytes() => $_has(13);
  @$pb.TagNumber(14)
  void clearFileSizeBytes() => $_clearField(14);

  /// docs/39: when the therapist shared this session with the client
  /// panel (ShareSessionWithClient). Unset = not shared.
  @$pb.TagNumber(15)
  $3.Timestamp get sharedWithClientAt => $_getN(14);
  @$pb.TagNumber(15)
  set sharedWithClientAt($3.Timestamp value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasSharedWithClientAt() => $_has(14);
  @$pb.TagNumber(15)
  void clearSharedWithClientAt() => $_clearField(15);
  @$pb.TagNumber(15)
  $3.Timestamp ensureSharedWithClientAt() => $_ensure(14);
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

/// MarkReportViewed — sets report_viewed_at on a COMPLETED session.
/// Idempotent (COALESCE preserves first-view timestamp).
class MarkReportViewedRequest extends $pb.GeneratedMessage {
  factory MarkReportViewedRequest({
    $core.String? sessionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  MarkReportViewedRequest._();

  factory MarkReportViewedRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MarkReportViewedRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MarkReportViewedRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkReportViewedRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarkReportViewedRequest copyWith(
          void Function(MarkReportViewedRequest) updates) =>
      super.copyWith((message) => updates(message as MarkReportViewedRequest))
          as MarkReportViewedRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarkReportViewedRequest create() => MarkReportViewedRequest._();
  @$core.override
  MarkReportViewedRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MarkReportViewedRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MarkReportViewedRequest>(create);
  static MarkReportViewedRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

/// SetAvatarConfig — sets or clears avatar customization on a patient file.
class SetAvatarConfigRequest extends $pb.GeneratedMessage {
  factory SetAvatarConfigRequest({
    $core.String? patientFileId,
    $core.String? avatarConfig,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (avatarConfig != null) result.avatarConfig = avatarConfig;
    return result;
  }

  SetAvatarConfigRequest._();

  factory SetAvatarConfigRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetAvatarConfigRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetAvatarConfigRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..aOS(2, _omitFieldNames ? '' : 'avatarConfig')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetAvatarConfigRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetAvatarConfigRequest copyWith(
          void Function(SetAvatarConfigRequest) updates) =>
      super.copyWith((message) => updates(message as SetAvatarConfigRequest))
          as SetAvatarConfigRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetAvatarConfigRequest create() => SetAvatarConfigRequest._();
  @$core.override
  SetAvatarConfigRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetAvatarConfigRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetAvatarConfigRequest>(create);
  static SetAvatarConfigRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);

  /// JSON string: {"label": "AK", "color": 3}. Empty = clear.
  @$pb.TagNumber(2)
  $core.String get avatarConfig => $_getSZ(1);
  @$pb.TagNumber(2)
  set avatarConfig($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAvatarConfig() => $_has(1);
  @$pb.TagNumber(2)
  void clearAvatarConfig() => $_clearField(2);
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
    $core.bool? isExperimental,
    $core.String? pipelineVersion,
    $core.String? ontologyVersion,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (summaryShort != null) result.summaryShort = summaryShort;
    if (content != null) result.content = content;
    if (sentimentLabel != null) result.sentimentLabel = sentimentLabel;
    if (riskLevel != null) result.riskLevel = riskLevel;
    if (isExperimental != null) result.isExperimental = isExperimental;
    if (pipelineVersion != null) result.pipelineVersion = pipelineVersion;
    if (ontologyVersion != null) result.ontologyVersion = ontologyVersion;
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
    ..aOB(7, _omitFieldNames ? '' : 'isExperimental')
    ..aOS(8, _omitFieldNames ? '' : 'pipelineVersion')
    ..aOS(9, _omitFieldNames ? '' : 'ontologyVersion')
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

  /// Czy to raport EKSPERYMENTALNY — zbudowany na ontologii bez
  /// autoryzacji ekspertow (plan 16 §2.5).
  ///
  /// Osobne pole, a nie prefiks w tytule: klient nie moze rozstrzygac o
  /// materiale klinicznym przez dopasowanie napisu. Prefiks zostaje, bo
  /// przezywa kopiowanie i eksport, ale UI ma sie opierac na TYM polu.
  @$pb.TagNumber(7)
  $core.bool get isExperimental => $_getBF(6);
  @$pb.TagNumber(7)
  set isExperimental($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIsExperimental() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsExperimental() => $_clearField(7);

  /// Ktorym potokiem powstal: "legacy" | "ontology_s1s5" |
  /// "ontology_s1s5_experimental". Informacyjne — podczas kalibracji
  /// ontologii (F1) ekspert porownuje przebiegi i musi wiedziec, ktora
  /// wersja wyprodukowala to, co czyta.
  @$pb.TagNumber(8)
  $core.String get pipelineVersion => $_getSZ(7);
  @$pb.TagNumber(8)
  set pipelineVersion($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPipelineVersion() => $_has(7);
  @$pb.TagNumber(8)
  void clearPipelineVersion() => $_clearField(8);

  /// Wersja ontologii, jesli raport powstal potokiem ontologicznym.
  @$pb.TagNumber(9)
  $core.String get ontologyVersion => $_getSZ(8);
  @$pb.TagNumber(9)
  set ontologyVersion($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasOntologyVersion() => $_has(8);
  @$pb.TagNumber(9)
  void clearOntologyVersion() => $_clearField(9);
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
    $core.String? organizationId,
    $core.String? organizationSearch,
  }) {
    final result = create();
    if (startTime != null) result.startTime = startTime;
    if (endTime != null) result.endTime = endTime;
    if (therapistFilter != null) result.therapistFilter = therapistFilter;
    if (pageSize != null) result.pageSize = pageSize;
    if (page != null) result.page = page;
    if (sortBy != null) result.sortBy = sortBy;
    if (sortOrder != null) result.sortOrder = sortOrder;
    if (organizationId != null) result.organizationId = organizationId;
    if (organizationSearch != null)
      result.organizationSearch = organizationSearch;
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
    ..aOS(8, _omitFieldNames ? '' : 'organizationId')
    ..aOS(9, _omitFieldNames ? '' : 'organizationSearch')
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

  /// Optional filter to a single organization (organizations.id). Empty =
  /// all organizations. Matched against the therapist's organization_id.
  @$pb.TagNumber(8)
  $core.String get organizationId => $_getSZ(7);
  @$pb.TagNumber(8)
  set organizationId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasOrganizationId() => $_has(7);
  @$pb.TagNumber(8)
  void clearOrganizationId() => $_clearField(8);

  /// Case-insensitive substring filter on the organization's legal_name.
  /// Empty = no filter. The admin UI uses this as a free-text search box
  /// (same UX as therapist_filter).
  @$pb.TagNumber(9)
  $core.String get organizationSearch => $_getSZ(8);
  @$pb.TagNumber(9)
  set organizationSearch($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasOrganizationSearch() => $_has(8);
  @$pb.TagNumber(9)
  void clearOrganizationSearch() => $_clearField(9);
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

class AdminModalityPrompt extends $pb.GeneratedMessage {
  factory AdminModalityPrompt({
    $core.String? modalityId,
    $core.String? systemCode,
    $core.String? displayName,
    $core.String? modalityType,
    $core.bool? isSupported,
    $core.String? systemPrompt,
    $core.int? version,
    $core.String? updatedByEmail,
    $3.Timestamp? updatedAt,
    $core.String? chatPrompt,
  }) {
    final result = create();
    if (modalityId != null) result.modalityId = modalityId;
    if (systemCode != null) result.systemCode = systemCode;
    if (displayName != null) result.displayName = displayName;
    if (modalityType != null) result.modalityType = modalityType;
    if (isSupported != null) result.isSupported = isSupported;
    if (systemPrompt != null) result.systemPrompt = systemPrompt;
    if (version != null) result.version = version;
    if (updatedByEmail != null) result.updatedByEmail = updatedByEmail;
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (chatPrompt != null) result.chatPrompt = chatPrompt;
    return result;
  }

  AdminModalityPrompt._();

  factory AdminModalityPrompt.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminModalityPrompt.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminModalityPrompt',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'modalityId')
    ..aOS(2, _omitFieldNames ? '' : 'systemCode')
    ..aOS(3, _omitFieldNames ? '' : 'displayName')
    ..aOS(4, _omitFieldNames ? '' : 'modalityType')
    ..aOB(5, _omitFieldNames ? '' : 'isSupported')
    ..aOS(6, _omitFieldNames ? '' : 'systemPrompt')
    ..aI(7, _omitFieldNames ? '' : 'version')
    ..aOS(8, _omitFieldNames ? '' : 'updatedByEmail')
    ..aOM<$3.Timestamp>(9, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $3.Timestamp.create)
    ..aOS(10, _omitFieldNames ? '' : 'chatPrompt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminModalityPrompt clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminModalityPrompt copyWith(void Function(AdminModalityPrompt) updates) =>
      super.copyWith((message) => updates(message as AdminModalityPrompt))
          as AdminModalityPrompt;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminModalityPrompt create() => AdminModalityPrompt._();
  @$core.override
  AdminModalityPrompt createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminModalityPrompt getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminModalityPrompt>(create);
  static AdminModalityPrompt? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get modalityId => $_getSZ(0);
  @$pb.TagNumber(1)
  set modalityId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasModalityId() => $_has(0);
  @$pb.TagNumber(1)
  void clearModalityId() => $_clearField(1);

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
  $core.String get modalityType => $_getSZ(3);
  @$pb.TagNumber(4)
  set modalityType($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasModalityType() => $_has(3);
  @$pb.TagNumber(4)
  void clearModalityType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get isSupported => $_getBF(4);
  @$pb.TagNumber(5)
  set isSupported($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsSupported() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsSupported() => $_clearField(5);

  /// Current live prompt text — therapist_ai_general_prompt["system"].
  @$pb.TagNumber(6)
  $core.String get systemPrompt => $_getSZ(5);
  @$pb.TagNumber(6)
  set systemPrompt($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSystemPrompt() => $_has(5);
  @$pb.TagNumber(6)
  void clearSystemPrompt() => $_clearField(6);

  /// Latest version number in modality_prompt_versions (the live text
  /// always equals this snapshot).
  @$pb.TagNumber(7)
  $core.int get version => $_getIZ(6);
  @$pb.TagNumber(7)
  set version($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasVersion() => $_has(6);
  @$pb.TagNumber(7)
  void clearVersion() => $_clearField(7);

  /// Author of the latest version, for display. Empty for the
  /// migration-seeded v1 when no admin edit happened yet.
  @$pb.TagNumber(8)
  $core.String get updatedByEmail => $_getSZ(7);
  @$pb.TagNumber(8)
  set updatedByEmail($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUpdatedByEmail() => $_has(7);
  @$pb.TagNumber(8)
  void clearUpdatedByEmail() => $_clearField(8);

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

  /// Chat modality lens — therapist_ai_general_prompt["chat"]. Empty =
  /// lens disabled for this modality (the chat then runs on the bare
  /// per-intent prompts). Appended to the generator's system prompt for
  /// grounded intents; invariants are re-asserted by code (Render()), so
  /// an edit here can change language and framing, never the rules.
  @$pb.TagNumber(10)
  $core.String get chatPrompt => $_getSZ(9);
  @$pb.TagNumber(10)
  set chatPrompt($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasChatPrompt() => $_has(9);
  @$pb.TagNumber(10)
  void clearChatPrompt() => $_clearField(10);
}

class OntologyModalitySummary extends $pb.GeneratedMessage {
  factory OntologyModalitySummary({
    $core.String? modalityId,
    $core.String? systemCode,
    $core.String? displayName,
    $core.String? activeVersion,
    $core.String? activeVersionId,
    $core.int? draftCount,
    $core.int? reviewCount,
    $core.String? latestVersion,
  }) {
    final result = create();
    if (modalityId != null) result.modalityId = modalityId;
    if (systemCode != null) result.systemCode = systemCode;
    if (displayName != null) result.displayName = displayName;
    if (activeVersion != null) result.activeVersion = activeVersion;
    if (activeVersionId != null) result.activeVersionId = activeVersionId;
    if (draftCount != null) result.draftCount = draftCount;
    if (reviewCount != null) result.reviewCount = reviewCount;
    if (latestVersion != null) result.latestVersion = latestVersion;
    return result;
  }

  OntologyModalitySummary._();

  factory OntologyModalitySummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OntologyModalitySummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OntologyModalitySummary',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'modalityId')
    ..aOS(2, _omitFieldNames ? '' : 'systemCode')
    ..aOS(3, _omitFieldNames ? '' : 'displayName')
    ..aOS(4, _omitFieldNames ? '' : 'activeVersion')
    ..aOS(5, _omitFieldNames ? '' : 'activeVersionId')
    ..aI(6, _omitFieldNames ? '' : 'draftCount')
    ..aI(7, _omitFieldNames ? '' : 'reviewCount')
    ..aOS(8, _omitFieldNames ? '' : 'latestVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyModalitySummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyModalitySummary copyWith(
          void Function(OntologyModalitySummary) updates) =>
      super.copyWith((message) => updates(message as OntologyModalitySummary))
          as OntologyModalitySummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OntologyModalitySummary create() => OntologyModalitySummary._();
  @$core.override
  OntologyModalitySummary createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OntologyModalitySummary getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OntologyModalitySummary>(create);
  static OntologyModalitySummary? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get modalityId => $_getSZ(0);
  @$pb.TagNumber(1)
  set modalityId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasModalityId() => $_has(0);
  @$pb.TagNumber(1)
  void clearModalityId() => $_clearField(1);

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

  /// Wersja serwowana na produkcji. Puste = potok ontologiczny
  /// niedostepny dla tej modalnosci (llm-worker spada na legacy).
  @$pb.TagNumber(4)
  $core.String get activeVersion => $_getSZ(3);
  @$pb.TagNumber(4)
  set activeVersion($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasActiveVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearActiveVersion() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get activeVersionId => $_getSZ(4);
  @$pb.TagNumber(5)
  set activeVersionId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasActiveVersionId() => $_has(4);
  @$pb.TagNumber(5)
  void clearActiveVersionId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get draftCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set draftCount($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDraftCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearDraftCount() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get reviewCount => $_getIZ(6);
  @$pb.TagNumber(7)
  set reviewCount($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasReviewCount() => $_has(6);
  @$pb.TagNumber(7)
  void clearReviewCount() => $_clearField(7);

  /// Najnowsza wersja niezaleznie od statusu — punkt wejscia do edytora.
  @$pb.TagNumber(8)
  $core.String get latestVersion => $_getSZ(7);
  @$pb.TagNumber(8)
  set latestVersion($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLatestVersion() => $_has(7);
  @$pb.TagNumber(8)
  void clearLatestVersion() => $_clearField(8);
}

class OntologyListModalitiesResponse extends $pb.GeneratedMessage {
  factory OntologyListModalitiesResponse({
    $core.Iterable<OntologyModalitySummary>? modalities,
  }) {
    final result = create();
    if (modalities != null) result.modalities.addAll(modalities);
    return result;
  }

  OntologyListModalitiesResponse._();

  factory OntologyListModalitiesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OntologyListModalitiesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OntologyListModalitiesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<OntologyModalitySummary>(1, _omitFieldNames ? '' : 'modalities',
        subBuilder: OntologyModalitySummary.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyListModalitiesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyListModalitiesResponse copyWith(
          void Function(OntologyListModalitiesResponse) updates) =>
      super.copyWith(
              (message) => updates(message as OntologyListModalitiesResponse))
          as OntologyListModalitiesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OntologyListModalitiesResponse create() =>
      OntologyListModalitiesResponse._();
  @$core.override
  OntologyListModalitiesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OntologyListModalitiesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OntologyListModalitiesResponse>(create);
  static OntologyListModalitiesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<OntologyModalitySummary> get modalities => $_getList(0);
}

class OntologyListVersionsRequest extends $pb.GeneratedMessage {
  factory OntologyListVersionsRequest({
    $core.String? modalityId,
    $core.int? pageSize,
    $core.int? pageOffset,
  }) {
    final result = create();
    if (modalityId != null) result.modalityId = modalityId;
    if (pageSize != null) result.pageSize = pageSize;
    if (pageOffset != null) result.pageOffset = pageOffset;
    return result;
  }

  OntologyListVersionsRequest._();

  factory OntologyListVersionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OntologyListVersionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OntologyListVersionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'modalityId')
    ..aI(2, _omitFieldNames ? '' : 'pageSize')
    ..aI(3, _omitFieldNames ? '' : 'pageOffset')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyListVersionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyListVersionsRequest copyWith(
          void Function(OntologyListVersionsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as OntologyListVersionsRequest))
          as OntologyListVersionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OntologyListVersionsRequest create() =>
      OntologyListVersionsRequest._();
  @$core.override
  OntologyListVersionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OntologyListVersionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OntologyListVersionsRequest>(create);
  static OntologyListVersionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get modalityId => $_getSZ(0);
  @$pb.TagNumber(1)
  set modalityId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasModalityId() => $_has(0);
  @$pb.TagNumber(1)
  void clearModalityId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get pageSize => $_getIZ(1);
  @$pb.TagNumber(2)
  set pageSize($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPageSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearPageSize() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get pageOffset => $_getIZ(2);
  @$pb.TagNumber(3)
  set pageOffset($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPageOffset() => $_has(2);
  @$pb.TagNumber(3)
  void clearPageOffset() => $_clearField(3);
}

/// OntologyVersion niesie tresc jako YAML, nie jako strukture.
///
/// Powod: metaschemat rozwija sie szybciej niz proto (dok. 11 ma juz
/// cztery wersje w tydzien), a odwzorowanie go w komunikatach zamienia
/// kazde rozszerzenie ontologii w zmiane kontraktu API i regeneracje
/// klientow. Walidacja i tak jest serwerowa (pkg/ontology), wiec proto
/// nie musi jej powielac.
class OntologyVersion extends $pb.GeneratedMessage {
  factory OntologyVersion({
    $core.String? id,
    $core.String? modalityId,
    $core.String? version,
    $core.String? contentYaml,
    OntologyStatus? status,
    $core.String? createdByEmail,
    $3.Timestamp? createdAt,
    $core.String? changeNote,
    $core.String? approvedByEmail,
    $3.Timestamp? approvedAt,
    $core.String? approvalNote,
    $core.bool? isActive,
    $core.int? constructCount,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (modalityId != null) result.modalityId = modalityId;
    if (version != null) result.version = version;
    if (contentYaml != null) result.contentYaml = contentYaml;
    if (status != null) result.status = status;
    if (createdByEmail != null) result.createdByEmail = createdByEmail;
    if (createdAt != null) result.createdAt = createdAt;
    if (changeNote != null) result.changeNote = changeNote;
    if (approvedByEmail != null) result.approvedByEmail = approvedByEmail;
    if (approvedAt != null) result.approvedAt = approvedAt;
    if (approvalNote != null) result.approvalNote = approvalNote;
    if (isActive != null) result.isActive = isActive;
    if (constructCount != null) result.constructCount = constructCount;
    return result;
  }

  OntologyVersion._();

  factory OntologyVersion.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OntologyVersion.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OntologyVersion',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'modalityId')
    ..aOS(3, _omitFieldNames ? '' : 'version')
    ..aOS(4, _omitFieldNames ? '' : 'contentYaml')
    ..aE<OntologyStatus>(5, _omitFieldNames ? '' : 'status',
        enumValues: OntologyStatus.values)
    ..aOS(6, _omitFieldNames ? '' : 'createdByEmail')
    ..aOM<$3.Timestamp>(7, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $3.Timestamp.create)
    ..aOS(8, _omitFieldNames ? '' : 'changeNote')
    ..aOS(9, _omitFieldNames ? '' : 'approvedByEmail')
    ..aOM<$3.Timestamp>(10, _omitFieldNames ? '' : 'approvedAt',
        subBuilder: $3.Timestamp.create)
    ..aOS(11, _omitFieldNames ? '' : 'approvalNote')
    ..aOB(12, _omitFieldNames ? '' : 'isActive')
    ..aI(13, _omitFieldNames ? '' : 'constructCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyVersion clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyVersion copyWith(void Function(OntologyVersion) updates) =>
      super.copyWith((message) => updates(message as OntologyVersion))
          as OntologyVersion;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OntologyVersion create() => OntologyVersion._();
  @$core.override
  OntologyVersion createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OntologyVersion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OntologyVersion>(create);
  static OntologyVersion? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get modalityId => $_getSZ(1);
  @$pb.TagNumber(2)
  set modalityId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModalityId() => $_has(1);
  @$pb.TagNumber(2)
  void clearModalityId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get version => $_getSZ(2);
  @$pb.TagNumber(3)
  set version($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearVersion() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get contentYaml => $_getSZ(3);
  @$pb.TagNumber(4)
  set contentYaml($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasContentYaml() => $_has(3);
  @$pb.TagNumber(4)
  void clearContentYaml() => $_clearField(4);

  @$pb.TagNumber(5)
  OntologyStatus get status => $_getN(4);
  @$pb.TagNumber(5)
  set status(OntologyStatus value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearStatus() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get createdByEmail => $_getSZ(5);
  @$pb.TagNumber(6)
  set createdByEmail($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedByEmail() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedByEmail() => $_clearField(6);

  @$pb.TagNumber(7)
  $3.Timestamp get createdAt => $_getN(6);
  @$pb.TagNumber(7)
  set createdAt($3.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCreatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreatedAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $3.Timestamp ensureCreatedAt() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.String get changeNote => $_getSZ(7);
  @$pb.TagNumber(8)
  set changeNote($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasChangeNote() => $_has(7);
  @$pb.TagNumber(8)
  void clearChangeNote() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get approvedByEmail => $_getSZ(8);
  @$pb.TagNumber(9)
  set approvedByEmail($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasApprovedByEmail() => $_has(8);
  @$pb.TagNumber(9)
  void clearApprovedByEmail() => $_clearField(9);

  @$pb.TagNumber(10)
  $3.Timestamp get approvedAt => $_getN(9);
  @$pb.TagNumber(10)
  set approvedAt($3.Timestamp value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasApprovedAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearApprovedAt() => $_clearField(10);
  @$pb.TagNumber(10)
  $3.Timestamp ensureApprovedAt() => $_ensure(9);

  @$pb.TagNumber(11)
  $core.String get approvalNote => $_getSZ(10);
  @$pb.TagNumber(11)
  set approvalNote($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasApprovalNote() => $_has(10);
  @$pb.TagNumber(11)
  void clearApprovalNote() => $_clearField(11);

  /// True dla wersji serwowanej na produkcji.
  @$pb.TagNumber(12)
  $core.bool get isActive => $_getBF(11);
  @$pb.TagNumber(12)
  set isActive($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasIsActive() => $_has(11);
  @$pb.TagNumber(12)
  void clearIsActive() => $_clearField(12);

  /// Liczba konstruktow — do listy, bez parsowania YAML po stronie UI.
  @$pb.TagNumber(13)
  $core.int get constructCount => $_getIZ(12);
  @$pb.TagNumber(13)
  set constructCount($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasConstructCount() => $_has(12);
  @$pb.TagNumber(13)
  void clearConstructCount() => $_clearField(13);
}

class OntologyListVersionsResponse extends $pb.GeneratedMessage {
  factory OntologyListVersionsResponse({
    $core.Iterable<OntologyVersion>? versions,
    $core.bool? hasMore,
  }) {
    final result = create();
    if (versions != null) result.versions.addAll(versions);
    if (hasMore != null) result.hasMore = hasMore;
    return result;
  }

  OntologyListVersionsResponse._();

  factory OntologyListVersionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OntologyListVersionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OntologyListVersionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<OntologyVersion>(1, _omitFieldNames ? '' : 'versions',
        subBuilder: OntologyVersion.create)
    ..aOB(2, _omitFieldNames ? '' : 'hasMore')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyListVersionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyListVersionsResponse copyWith(
          void Function(OntologyListVersionsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as OntologyListVersionsResponse))
          as OntologyListVersionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OntologyListVersionsResponse create() =>
      OntologyListVersionsResponse._();
  @$core.override
  OntologyListVersionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OntologyListVersionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OntologyListVersionsResponse>(create);
  static OntologyListVersionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<OntologyVersion> get versions => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get hasMore => $_getBF(1);
  @$pb.TagNumber(2)
  set hasMore($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHasMore() => $_has(1);
  @$pb.TagNumber(2)
  void clearHasMore() => $_clearField(2);
}

class OntologyGetVersionRequest extends $pb.GeneratedMessage {
  factory OntologyGetVersionRequest({
    $core.String? versionId,
  }) {
    final result = create();
    if (versionId != null) result.versionId = versionId;
    return result;
  }

  OntologyGetVersionRequest._();

  factory OntologyGetVersionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OntologyGetVersionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OntologyGetVersionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'versionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyGetVersionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyGetVersionRequest copyWith(
          void Function(OntologyGetVersionRequest) updates) =>
      super.copyWith((message) => updates(message as OntologyGetVersionRequest))
          as OntologyGetVersionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OntologyGetVersionRequest create() => OntologyGetVersionRequest._();
  @$core.override
  OntologyGetVersionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OntologyGetVersionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OntologyGetVersionRequest>(create);
  static OntologyGetVersionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get versionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set versionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersionId() => $_clearField(1);
}

class OntologyLintRequest extends $pb.GeneratedMessage {
  factory OntologyLintRequest({
    $core.String? contentYaml,
  }) {
    final result = create();
    if (contentYaml != null) result.contentYaml = contentYaml;
    return result;
  }

  OntologyLintRequest._();

  factory OntologyLintRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OntologyLintRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OntologyLintRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'contentYaml')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyLintRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyLintRequest copyWith(void Function(OntologyLintRequest) updates) =>
      super.copyWith((message) => updates(message as OntologyLintRequest))
          as OntologyLintRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OntologyLintRequest create() => OntologyLintRequest._();
  @$core.override
  OntologyLintRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OntologyLintRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OntologyLintRequest>(create);
  static OntologyLintRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get contentYaml => $_getSZ(0);
  @$pb.TagNumber(1)
  set contentYaml($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasContentYaml() => $_has(0);
  @$pb.TagNumber(1)
  void clearContentYaml() => $_clearField(1);
}

class OntologyLintResponse extends $pb.GeneratedMessage {
  factory OntologyLintResponse({
    $core.Iterable<$core.String>? problems,
    $core.int? constructCount,
  }) {
    final result = create();
    if (problems != null) result.problems.addAll(problems);
    if (constructCount != null) result.constructCount = constructCount;
    return result;
  }

  OntologyLintResponse._();

  factory OntologyLintResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OntologyLintResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OntologyLintResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'problems')
    ..aI(2, _omitFieldNames ? '' : 'constructCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyLintResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyLintResponse copyWith(void Function(OntologyLintResponse) updates) =>
      super.copyWith((message) => updates(message as OntologyLintResponse))
          as OntologyLintResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OntologyLintResponse create() => OntologyLintResponse._();
  @$core.override
  OntologyLintResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OntologyLintResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OntologyLintResponse>(create);
  static OntologyLintResponse? _defaultInstance;

  /// Pusta lista = tresc zdatna do zapisu. Zwracamy WSZYSTKIE problemy,
  /// nie pierwszy — autor ma zobaczyc pelna liste do poprawienia.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get problems => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get constructCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set constructCount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConstructCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearConstructCount() => $_clearField(2);
}

class OntologyCreateDraftRequest extends $pb.GeneratedMessage {
  factory OntologyCreateDraftRequest({
    $core.String? modalityId,
    $core.String? version,
    $core.String? contentYaml,
    $core.String? changeNote,
    $core.String? copyFromVersionId,
  }) {
    final result = create();
    if (modalityId != null) result.modalityId = modalityId;
    if (version != null) result.version = version;
    if (contentYaml != null) result.contentYaml = contentYaml;
    if (changeNote != null) result.changeNote = changeNote;
    if (copyFromVersionId != null) result.copyFromVersionId = copyFromVersionId;
    return result;
  }

  OntologyCreateDraftRequest._();

  factory OntologyCreateDraftRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OntologyCreateDraftRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OntologyCreateDraftRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'modalityId')
    ..aOS(2, _omitFieldNames ? '' : 'version')
    ..aOS(3, _omitFieldNames ? '' : 'contentYaml')
    ..aOS(4, _omitFieldNames ? '' : 'changeNote')
    ..aOS(5, _omitFieldNames ? '' : 'copyFromVersionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyCreateDraftRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyCreateDraftRequest copyWith(
          void Function(OntologyCreateDraftRequest) updates) =>
      super.copyWith(
              (message) => updates(message as OntologyCreateDraftRequest))
          as OntologyCreateDraftRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OntologyCreateDraftRequest create() => OntologyCreateDraftRequest._();
  @$core.override
  OntologyCreateDraftRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OntologyCreateDraftRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OntologyCreateDraftRequest>(create);
  static OntologyCreateDraftRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get modalityId => $_getSZ(0);
  @$pb.TagNumber(1)
  set modalityId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasModalityId() => $_has(0);
  @$pb.TagNumber(1)
  void clearModalityId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get version => $_getSZ(1);
  @$pb.TagNumber(2)
  set version($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get contentYaml => $_getSZ(2);
  @$pb.TagNumber(3)
  set contentYaml($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContentYaml() => $_has(2);
  @$pb.TagNumber(3)
  void clearContentYaml() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get changeNote => $_getSZ(3);
  @$pb.TagNumber(4)
  set changeNote($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasChangeNote() => $_has(3);
  @$pb.TagNumber(4)
  void clearChangeNote() => $_clearField(4);

  /// Opcjonalne: skopiuj tresc z istniejacej wersji. Tak dziala "edytuj"
  /// na wersji approved — nie mutujemy jej, tylko rozgalezimy.
  @$pb.TagNumber(5)
  $core.String get copyFromVersionId => $_getSZ(4);
  @$pb.TagNumber(5)
  set copyFromVersionId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCopyFromVersionId() => $_has(4);
  @$pb.TagNumber(5)
  void clearCopyFromVersionId() => $_clearField(5);
}

class OntologyUpdateDraftRequest extends $pb.GeneratedMessage {
  factory OntologyUpdateDraftRequest({
    $core.String? versionId,
    $core.String? contentYaml,
    $core.String? changeNote,
  }) {
    final result = create();
    if (versionId != null) result.versionId = versionId;
    if (contentYaml != null) result.contentYaml = contentYaml;
    if (changeNote != null) result.changeNote = changeNote;
    return result;
  }

  OntologyUpdateDraftRequest._();

  factory OntologyUpdateDraftRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OntologyUpdateDraftRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OntologyUpdateDraftRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'versionId')
    ..aOS(2, _omitFieldNames ? '' : 'contentYaml')
    ..aOS(3, _omitFieldNames ? '' : 'changeNote')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyUpdateDraftRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyUpdateDraftRequest copyWith(
          void Function(OntologyUpdateDraftRequest) updates) =>
      super.copyWith(
              (message) => updates(message as OntologyUpdateDraftRequest))
          as OntologyUpdateDraftRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OntologyUpdateDraftRequest create() => OntologyUpdateDraftRequest._();
  @$core.override
  OntologyUpdateDraftRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OntologyUpdateDraftRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OntologyUpdateDraftRequest>(create);
  static OntologyUpdateDraftRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get versionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set versionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get contentYaml => $_getSZ(1);
  @$pb.TagNumber(2)
  set contentYaml($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasContentYaml() => $_has(1);
  @$pb.TagNumber(2)
  void clearContentYaml() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get changeNote => $_getSZ(2);
  @$pb.TagNumber(3)
  set changeNote($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChangeNote() => $_has(2);
  @$pb.TagNumber(3)
  void clearChangeNote() => $_clearField(3);
}

/// OntologyTransitionRequest obsluguje kazde przejscie statusu i
/// aktywacje. Notatka jest WYMAGANA wszedzie z tego samego powodu co w
/// ChatControls: wpis audytowy czyta nastepny dyzurny.
class OntologyTransitionRequest extends $pb.GeneratedMessage {
  factory OntologyTransitionRequest({
    $core.String? versionId,
    $core.String? note,
  }) {
    final result = create();
    if (versionId != null) result.versionId = versionId;
    if (note != null) result.note = note;
    return result;
  }

  OntologyTransitionRequest._();

  factory OntologyTransitionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OntologyTransitionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OntologyTransitionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'versionId')
    ..aOS(2, _omitFieldNames ? '' : 'note')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyTransitionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OntologyTransitionRequest copyWith(
          void Function(OntologyTransitionRequest) updates) =>
      super.copyWith((message) => updates(message as OntologyTransitionRequest))
          as OntologyTransitionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OntologyTransitionRequest create() => OntologyTransitionRequest._();
  @$core.override
  OntologyTransitionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OntologyTransitionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OntologyTransitionRequest>(create);
  static OntologyTransitionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get versionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set versionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get note => $_getSZ(1);
  @$pb.TagNumber(2)
  set note($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNote() => $_has(1);
  @$pb.TagNumber(2)
  void clearNote() => $_clearField(2);
}

class AdminListModalityPromptsResponse extends $pb.GeneratedMessage {
  factory AdminListModalityPromptsResponse({
    $core.Iterable<AdminModalityPrompt>? prompts,
  }) {
    final result = create();
    if (prompts != null) result.prompts.addAll(prompts);
    return result;
  }

  AdminListModalityPromptsResponse._();

  factory AdminListModalityPromptsResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListModalityPromptsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListModalityPromptsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<AdminModalityPrompt>(1, _omitFieldNames ? '' : 'prompts',
        subBuilder: AdminModalityPrompt.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListModalityPromptsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListModalityPromptsResponse copyWith(
          void Function(AdminListModalityPromptsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as AdminListModalityPromptsResponse))
          as AdminListModalityPromptsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListModalityPromptsResponse create() =>
      AdminListModalityPromptsResponse._();
  @$core.override
  AdminListModalityPromptsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListModalityPromptsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListModalityPromptsResponse>(
          create);
  static AdminListModalityPromptsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AdminModalityPrompt> get prompts => $_getList(0);
}

class AdminGetModalityPromptHistoryRequest extends $pb.GeneratedMessage {
  factory AdminGetModalityPromptHistoryRequest({
    $core.String? modalityId,
    $core.int? pageSize,
    $core.int? pageOffset,
  }) {
    final result = create();
    if (modalityId != null) result.modalityId = modalityId;
    if (pageSize != null) result.pageSize = pageSize;
    if (pageOffset != null) result.pageOffset = pageOffset;
    return result;
  }

  AdminGetModalityPromptHistoryRequest._();

  factory AdminGetModalityPromptHistoryRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminGetModalityPromptHistoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminGetModalityPromptHistoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'modalityId')
    ..aI(2, _omitFieldNames ? '' : 'pageSize')
    ..aI(3, _omitFieldNames ? '' : 'pageOffset')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetModalityPromptHistoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetModalityPromptHistoryRequest copyWith(
          void Function(AdminGetModalityPromptHistoryRequest) updates) =>
      super.copyWith((message) =>
              updates(message as AdminGetModalityPromptHistoryRequest))
          as AdminGetModalityPromptHistoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminGetModalityPromptHistoryRequest create() =>
      AdminGetModalityPromptHistoryRequest._();
  @$core.override
  AdminGetModalityPromptHistoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminGetModalityPromptHistoryRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          AdminGetModalityPromptHistoryRequest>(create);
  static AdminGetModalityPromptHistoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get modalityId => $_getSZ(0);
  @$pb.TagNumber(1)
  set modalityId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasModalityId() => $_has(0);
  @$pb.TagNumber(1)
  void clearModalityId() => $_clearField(1);

  /// Pagination: 0 → server default (20), capped at 50.
  @$pb.TagNumber(2)
  $core.int get pageSize => $_getIZ(1);
  @$pb.TagNumber(2)
  set pageSize($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPageSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearPageSize() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get pageOffset => $_getIZ(2);
  @$pb.TagNumber(3)
  set pageOffset($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPageOffset() => $_has(2);
  @$pb.TagNumber(3)
  void clearPageOffset() => $_clearField(3);
}

class AdminModalityPromptVersion extends $pb.GeneratedMessage {
  factory AdminModalityPromptVersion({
    $core.String? id,
    $core.int? version,
    $core.String? systemPrompt,
    $core.String? changeNote,
    $core.String? createdByEmail,
    $3.Timestamp? createdAt,
    $core.String? chatPrompt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (version != null) result.version = version;
    if (systemPrompt != null) result.systemPrompt = systemPrompt;
    if (changeNote != null) result.changeNote = changeNote;
    if (createdByEmail != null) result.createdByEmail = createdByEmail;
    if (createdAt != null) result.createdAt = createdAt;
    if (chatPrompt != null) result.chatPrompt = chatPrompt;
    return result;
  }

  AdminModalityPromptVersion._();

  factory AdminModalityPromptVersion.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminModalityPromptVersion.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminModalityPromptVersion',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'version')
    ..aOS(3, _omitFieldNames ? '' : 'systemPrompt')
    ..aOS(4, _omitFieldNames ? '' : 'changeNote')
    ..aOS(5, _omitFieldNames ? '' : 'createdByEmail')
    ..aOM<$3.Timestamp>(6, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $3.Timestamp.create)
    ..aOS(7, _omitFieldNames ? '' : 'chatPrompt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminModalityPromptVersion clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminModalityPromptVersion copyWith(
          void Function(AdminModalityPromptVersion) updates) =>
      super.copyWith(
              (message) => updates(message as AdminModalityPromptVersion))
          as AdminModalityPromptVersion;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminModalityPromptVersion create() => AdminModalityPromptVersion._();
  @$core.override
  AdminModalityPromptVersion createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminModalityPromptVersion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminModalityPromptVersion>(create);
  static AdminModalityPromptVersion? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get version => $_getIZ(1);
  @$pb.TagNumber(2)
  set version($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get systemPrompt => $_getSZ(2);
  @$pb.TagNumber(3)
  set systemPrompt($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSystemPrompt() => $_has(2);
  @$pb.TagNumber(3)
  void clearSystemPrompt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get changeNote => $_getSZ(3);
  @$pb.TagNumber(4)
  set changeNote($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasChangeNote() => $_has(3);
  @$pb.TagNumber(4)
  void clearChangeNote() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get createdByEmail => $_getSZ(4);
  @$pb.TagNumber(5)
  set createdByEmail($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCreatedByEmail() => $_has(4);
  @$pb.TagNumber(5)
  void clearCreatedByEmail() => $_clearField(5);

  @$pb.TagNumber(6)
  $3.Timestamp get createdAt => $_getN(5);
  @$pb.TagNumber(6)
  set createdAt($3.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => $_clearField(6);
  @$pb.TagNumber(6)
  $3.Timestamp ensureCreatedAt() => $_ensure(5);

  /// Snapshot of the chat lens at this version. Versions predating the
  /// lens (before 2026-08-20) return "" here — the snapshot column holds
  /// the full JSONB, so no backfill is needed or possible.
  @$pb.TagNumber(7)
  $core.String get chatPrompt => $_getSZ(6);
  @$pb.TagNumber(7)
  set chatPrompt($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasChatPrompt() => $_has(6);
  @$pb.TagNumber(7)
  void clearChatPrompt() => $_clearField(7);
}

class AdminGetModalityPromptHistoryResponse extends $pb.GeneratedMessage {
  factory AdminGetModalityPromptHistoryResponse({
    $core.Iterable<AdminModalityPromptVersion>? versions,
    $core.bool? hasMore,
  }) {
    final result = create();
    if (versions != null) result.versions.addAll(versions);
    if (hasMore != null) result.hasMore = hasMore;
    return result;
  }

  AdminGetModalityPromptHistoryResponse._();

  factory AdminGetModalityPromptHistoryResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminGetModalityPromptHistoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminGetModalityPromptHistoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<AdminModalityPromptVersion>(1, _omitFieldNames ? '' : 'versions',
        subBuilder: AdminModalityPromptVersion.create)
    ..aOB(2, _omitFieldNames ? '' : 'hasMore')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetModalityPromptHistoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetModalityPromptHistoryResponse copyWith(
          void Function(AdminGetModalityPromptHistoryResponse) updates) =>
      super.copyWith((message) =>
              updates(message as AdminGetModalityPromptHistoryResponse))
          as AdminGetModalityPromptHistoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminGetModalityPromptHistoryResponse create() =>
      AdminGetModalityPromptHistoryResponse._();
  @$core.override
  AdminGetModalityPromptHistoryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminGetModalityPromptHistoryResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          AdminGetModalityPromptHistoryResponse>(create);
  static AdminGetModalityPromptHistoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AdminModalityPromptVersion> get versions => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get hasMore => $_getBF(1);
  @$pb.TagNumber(2)
  set hasMore($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHasMore() => $_has(1);
  @$pb.TagNumber(2)
  void clearHasMore() => $_clearField(2);
}

class AdminUpdateModalityPromptRequest extends $pb.GeneratedMessage {
  factory AdminUpdateModalityPromptRequest({
    $core.String? modalityId,
    $core.String? systemPrompt,
    $core.String? changeNote,
    $core.int? expectedVersion,
    $core.String? promptKey,
  }) {
    final result = create();
    if (modalityId != null) result.modalityId = modalityId;
    if (systemPrompt != null) result.systemPrompt = systemPrompt;
    if (changeNote != null) result.changeNote = changeNote;
    if (expectedVersion != null) result.expectedVersion = expectedVersion;
    if (promptKey != null) result.promptKey = promptKey;
    return result;
  }

  AdminUpdateModalityPromptRequest._();

  factory AdminUpdateModalityPromptRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminUpdateModalityPromptRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminUpdateModalityPromptRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'modalityId')
    ..aOS(2, _omitFieldNames ? '' : 'systemPrompt')
    ..aOS(3, _omitFieldNames ? '' : 'changeNote')
    ..aI(4, _omitFieldNames ? '' : 'expectedVersion')
    ..aOS(5, _omitFieldNames ? '' : 'promptKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUpdateModalityPromptRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUpdateModalityPromptRequest copyWith(
          void Function(AdminUpdateModalityPromptRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminUpdateModalityPromptRequest))
          as AdminUpdateModalityPromptRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminUpdateModalityPromptRequest create() =>
      AdminUpdateModalityPromptRequest._();
  @$core.override
  AdminUpdateModalityPromptRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminUpdateModalityPromptRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminUpdateModalityPromptRequest>(
          create);
  static AdminUpdateModalityPromptRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get modalityId => $_getSZ(0);
  @$pb.TagNumber(1)
  set modalityId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasModalityId() => $_has(0);
  @$pb.TagNumber(1)
  void clearModalityId() => $_clearField(1);

  /// Full replacement text for the key selected by prompt_key.
  /// For "system": trimmed non-empty, ≤ 20000 chars.
  /// For "chat": ≤ 5500 chars (the lens rides on every grounded
  /// generator call, so it stays far tighter than the report prompt);
  /// EMPTY IS VALID and disables the lens.
  /// Brand-frame banned words are rejected server-side for "chat".
  @$pb.TagNumber(2)
  $core.String get systemPrompt => $_getSZ(1);
  @$pb.TagNumber(2)
  set systemPrompt($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSystemPrompt() => $_has(1);
  @$pb.TagNumber(2)
  void clearSystemPrompt() => $_clearField(2);

  /// Mandatory reason (≥ 10 chars) — stored on the version row and the
  /// audit_log entry.
  @$pb.TagNumber(3)
  $core.String get changeNote => $_getSZ(2);
  @$pb.TagNumber(3)
  set changeNote($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChangeNote() => $_has(2);
  @$pb.TagNumber(3)
  void clearChangeNote() => $_clearField(3);

  /// Optimistic lock: must equal the current latest version for this
  /// modality or the call fails FailedPrecondition (someone else saved
  /// in between — reload before retrying).
  ///
  /// ONE counter guards BOTH keys on purpose: every version row snapshots
  /// the whole JSONB, so two admins editing "system" and "chat"
  /// concurrently would still silently overwrite each other's snapshot if
  /// the locks were separate.
  @$pb.TagNumber(4)
  $core.int get expectedVersion => $_getIZ(3);
  @$pb.TagNumber(4)
  set expectedVersion($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExpectedVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearExpectedVersion() => $_clearField(4);

  /// Which key this save targets: "system" (default, report prompt) or
  /// "chat" (modality lens for the chat). A string, not an enum, because
  /// the storage is a JSONB key and inventing a parallel enum would just
  /// add a translation layer to drift.
  @$pb.TagNumber(5)
  $core.String get promptKey => $_getSZ(4);
  @$pb.TagNumber(5)
  set promptKey($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPromptKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearPromptKey() => $_clearField(5);
}

class AdminUpdateModalityPromptResponse extends $pb.GeneratedMessage {
  factory AdminUpdateModalityPromptResponse({
    AdminModalityPrompt? prompt,
  }) {
    final result = create();
    if (prompt != null) result.prompt = prompt;
    return result;
  }

  AdminUpdateModalityPromptResponse._();

  factory AdminUpdateModalityPromptResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminUpdateModalityPromptResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminUpdateModalityPromptResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOM<AdminModalityPrompt>(1, _omitFieldNames ? '' : 'prompt',
        subBuilder: AdminModalityPrompt.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUpdateModalityPromptResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUpdateModalityPromptResponse copyWith(
          void Function(AdminUpdateModalityPromptResponse) updates) =>
      super.copyWith((message) =>
              updates(message as AdminUpdateModalityPromptResponse))
          as AdminUpdateModalityPromptResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminUpdateModalityPromptResponse create() =>
      AdminUpdateModalityPromptResponse._();
  @$core.override
  AdminUpdateModalityPromptResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminUpdateModalityPromptResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminUpdateModalityPromptResponse>(
          create);
  static AdminUpdateModalityPromptResponse? _defaultInstance;

  /// The state after the save, for immediate UI refresh without a
  /// second round-trip.
  @$pb.TagNumber(1)
  AdminModalityPrompt get prompt => $_getN(0);
  @$pb.TagNumber(1)
  set prompt(AdminModalityPrompt value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPrompt() => $_has(0);
  @$pb.TagNumber(1)
  void clearPrompt() => $_clearField(1);
  @$pb.TagNumber(1)
  AdminModalityPrompt ensurePrompt() => $_ensure(0);
}

class TrackEventsRequest extends $pb.GeneratedMessage {
  factory TrackEventsRequest({
    $core.Iterable<ClientEvent>? events,
  }) {
    final result = create();
    if (events != null) result.events.addAll(events);
    return result;
  }

  TrackEventsRequest._();

  factory TrackEventsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrackEventsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrackEventsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<ClientEvent>(1, _omitFieldNames ? '' : 'events',
        subBuilder: ClientEvent.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrackEventsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrackEventsRequest copyWith(void Function(TrackEventsRequest) updates) =>
      super.copyWith((message) => updates(message as TrackEventsRequest))
          as TrackEventsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrackEventsRequest create() => TrackEventsRequest._();
  @$core.override
  TrackEventsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrackEventsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrackEventsRequest>(create);
  static TrackEventsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ClientEvent> get events => $_getList(0);
}

class ClientEvent extends $pb.GeneratedMessage {
  factory ClientEvent({
    $core.String? eventName,
    $4.Struct? properties,
    $3.Timestamp? occurredAt,
    $core.String? clientPlatform,
    $core.String? clientVersion,
  }) {
    final result = create();
    if (eventName != null) result.eventName = eventName;
    if (properties != null) result.properties = properties;
    if (occurredAt != null) result.occurredAt = occurredAt;
    if (clientPlatform != null) result.clientPlatform = clientPlatform;
    if (clientVersion != null) result.clientVersion = clientVersion;
    return result;
  }

  ClientEvent._();

  factory ClientEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'eventName')
    ..aOM<$4.Struct>(2, _omitFieldNames ? '' : 'properties',
        subBuilder: $4.Struct.create)
    ..aOM<$3.Timestamp>(3, _omitFieldNames ? '' : 'occurredAt',
        subBuilder: $3.Timestamp.create)
    ..aOS(4, _omitFieldNames ? '' : 'clientPlatform')
    ..aOS(5, _omitFieldNames ? '' : 'clientVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientEvent copyWith(void Function(ClientEvent) updates) =>
      super.copyWith((message) => updates(message as ClientEvent))
          as ClientEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientEvent create() => ClientEvent._();
  @$core.override
  ClientEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientEvent>(create);
  static ClientEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get eventName => $_getSZ(0);
  @$pb.TagNumber(1)
  set eventName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEventName() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventName() => $_clearField(1);

  @$pb.TagNumber(2)
  $4.Struct get properties => $_getN(1);
  @$pb.TagNumber(2)
  set properties($4.Struct value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProperties() => $_has(1);
  @$pb.TagNumber(2)
  void clearProperties() => $_clearField(2);
  @$pb.TagNumber(2)
  $4.Struct ensureProperties() => $_ensure(1);

  @$pb.TagNumber(3)
  $3.Timestamp get occurredAt => $_getN(2);
  @$pb.TagNumber(3)
  set occurredAt($3.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOccurredAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearOccurredAt() => $_clearField(3);
  @$pb.TagNumber(3)
  $3.Timestamp ensureOccurredAt() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get clientPlatform => $_getSZ(3);
  @$pb.TagNumber(4)
  set clientPlatform($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasClientPlatform() => $_has(3);
  @$pb.TagNumber(4)
  void clearClientPlatform() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get clientVersion => $_getSZ(4);
  @$pb.TagNumber(5)
  set clientVersion($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasClientVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearClientVersion() => $_clearField(5);
}

class TrackEventsResponse extends $pb.GeneratedMessage {
  factory TrackEventsResponse() => create();

  TrackEventsResponse._();

  factory TrackEventsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrackEventsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrackEventsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrackEventsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrackEventsResponse copyWith(void Function(TrackEventsResponse) updates) =>
      super.copyWith((message) => updates(message as TrackEventsResponse))
          as TrackEventsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrackEventsResponse create() => TrackEventsResponse._();
  @$core.override
  TrackEventsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrackEventsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrackEventsResponse>(create);
  static TrackEventsResponse? _defaultInstance;
}

class GetAdminAnalyticsRequest extends $pb.GeneratedMessage {
  factory GetAdminAnalyticsRequest({
    $core.String? timeRange,
  }) {
    final result = create();
    if (timeRange != null) result.timeRange = timeRange;
    return result;
  }

  GetAdminAnalyticsRequest._();

  factory GetAdminAnalyticsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetAdminAnalyticsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetAdminAnalyticsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'timeRange')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAdminAnalyticsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAdminAnalyticsRequest copyWith(
          void Function(GetAdminAnalyticsRequest) updates) =>
      super.copyWith((message) => updates(message as GetAdminAnalyticsRequest))
          as GetAdminAnalyticsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAdminAnalyticsRequest create() => GetAdminAnalyticsRequest._();
  @$core.override
  GetAdminAnalyticsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetAdminAnalyticsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetAdminAnalyticsRequest>(create);
  static GetAdminAnalyticsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get timeRange => $_getSZ(0);
  @$pb.TagNumber(1)
  set timeRange($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTimeRange() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimeRange() => $_clearField(1);
}

class GetAdminAnalyticsResponse extends $pb.GeneratedMessage {
  factory GetAdminAnalyticsResponse({
    $fixnum.Int64? kpiWau,
    $fixnum.Int64? kpiSessionsThisWeek,
    $core.double? kpiActivationRate,
    $core.double? kpiSatisfactionRate,
    $core.Iterable<TrendPoint>? wauTrend,
    $core.Iterable<TrendPoint>? sessionsTrend,
    $core.Iterable<TrendPoint>? registrationsTrend,
    $core.Iterable<PlanDistribution>? planDistribution,
    $core.double? kpiAvgCostPerSession,
    $core.double? kpiMonthlySttCost,
    $core.double? kpiMonthlyLlmCost,
    $core.double? kpiAvgTokenUtilization,
    $core.Iterable<CostTrendPoint>? costTrend,
    $core.Iterable<TokenUtilizationHeatmapPoint>? tokenUtilizationHeatmap,
    $core.Iterable<RevenueTrendPoint>? revenueTrend,
    $core.Iterable<TokenUsageTrendPoint>? tokenUsageTrend,
    $core.double? kpiAvgPipelineLatency,
    $core.double? kpiFailureRate7d,
    $core.double? kpiRelabelRate,
    $core.Iterable<SatisfactionTrendPoint>? satisfactionTrend,
    $core.Iterable<IssueCategory>? issueCategories,
    $core.Iterable<LatencyTrendPoint>? latencyTrend,
    $core.Iterable<FailureRatePoint>? failureRateTrend,
    $core.double? kpi30dRetention,
    $core.Iterable<FunnelStep>? funnelSteps,
    $core.Iterable<CohortRetentionPoint>? cohortRetention,
    $core.Iterable<HistogramBucket>? activationTimeHistogram,
    $core.Iterable<HourlyHeatmapPoint>? hourlyHeatmap,
    $core.Iterable<FailureRatePoint>? uploadFailuresTrend,
    $core.Iterable<ModalityDistribution>? modalityDistribution,
    $core.double? kpiAvgSessionDuration,
    $core.Iterable<TrendPoint>? sessionDurationTrend,
    $core.Iterable<PlatformFixedCost>? platformFixedCosts,
    $fixnum.Int64? kpiRatingsTotal,
    $fixnum.Int64? kpiRatingsPositive,
    $fixnum.Int64? kpiRatingsNegative,
    $fixnum.Int64? kpiRatingsWithNotes,
    $core.Iterable<RegisteredUserDetail>? registrationsDetail,
    $core.Iterable<ClientSharingPoint>? clientSharingTrend,
    ClientInvitationFunnel? clientInvitationFunnel,
    $core.Iterable<PairingAttemptBucket>? pairingAttempts,
    ReportReadingStats? reportReading,
    $core.Iterable<PlatformReads>? readingPlatforms,
  }) {
    final result = create();
    if (kpiWau != null) result.kpiWau = kpiWau;
    if (kpiSessionsThisWeek != null)
      result.kpiSessionsThisWeek = kpiSessionsThisWeek;
    if (kpiActivationRate != null) result.kpiActivationRate = kpiActivationRate;
    if (kpiSatisfactionRate != null)
      result.kpiSatisfactionRate = kpiSatisfactionRate;
    if (wauTrend != null) result.wauTrend.addAll(wauTrend);
    if (sessionsTrend != null) result.sessionsTrend.addAll(sessionsTrend);
    if (registrationsTrend != null)
      result.registrationsTrend.addAll(registrationsTrend);
    if (planDistribution != null)
      result.planDistribution.addAll(planDistribution);
    if (kpiAvgCostPerSession != null)
      result.kpiAvgCostPerSession = kpiAvgCostPerSession;
    if (kpiMonthlySttCost != null) result.kpiMonthlySttCost = kpiMonthlySttCost;
    if (kpiMonthlyLlmCost != null) result.kpiMonthlyLlmCost = kpiMonthlyLlmCost;
    if (kpiAvgTokenUtilization != null)
      result.kpiAvgTokenUtilization = kpiAvgTokenUtilization;
    if (costTrend != null) result.costTrend.addAll(costTrend);
    if (tokenUtilizationHeatmap != null)
      result.tokenUtilizationHeatmap.addAll(tokenUtilizationHeatmap);
    if (revenueTrend != null) result.revenueTrend.addAll(revenueTrend);
    if (tokenUsageTrend != null) result.tokenUsageTrend.addAll(tokenUsageTrend);
    if (kpiAvgPipelineLatency != null)
      result.kpiAvgPipelineLatency = kpiAvgPipelineLatency;
    if (kpiFailureRate7d != null) result.kpiFailureRate7d = kpiFailureRate7d;
    if (kpiRelabelRate != null) result.kpiRelabelRate = kpiRelabelRate;
    if (satisfactionTrend != null)
      result.satisfactionTrend.addAll(satisfactionTrend);
    if (issueCategories != null) result.issueCategories.addAll(issueCategories);
    if (latencyTrend != null) result.latencyTrend.addAll(latencyTrend);
    if (failureRateTrend != null)
      result.failureRateTrend.addAll(failureRateTrend);
    if (kpi30dRetention != null) result.kpi30dRetention = kpi30dRetention;
    if (funnelSteps != null) result.funnelSteps.addAll(funnelSteps);
    if (cohortRetention != null) result.cohortRetention.addAll(cohortRetention);
    if (activationTimeHistogram != null)
      result.activationTimeHistogram.addAll(activationTimeHistogram);
    if (hourlyHeatmap != null) result.hourlyHeatmap.addAll(hourlyHeatmap);
    if (uploadFailuresTrend != null)
      result.uploadFailuresTrend.addAll(uploadFailuresTrend);
    if (modalityDistribution != null)
      result.modalityDistribution.addAll(modalityDistribution);
    if (kpiAvgSessionDuration != null)
      result.kpiAvgSessionDuration = kpiAvgSessionDuration;
    if (sessionDurationTrend != null)
      result.sessionDurationTrend.addAll(sessionDurationTrend);
    if (platformFixedCosts != null)
      result.platformFixedCosts.addAll(platformFixedCosts);
    if (kpiRatingsTotal != null) result.kpiRatingsTotal = kpiRatingsTotal;
    if (kpiRatingsPositive != null)
      result.kpiRatingsPositive = kpiRatingsPositive;
    if (kpiRatingsNegative != null)
      result.kpiRatingsNegative = kpiRatingsNegative;
    if (kpiRatingsWithNotes != null)
      result.kpiRatingsWithNotes = kpiRatingsWithNotes;
    if (registrationsDetail != null)
      result.registrationsDetail.addAll(registrationsDetail);
    if (clientSharingTrend != null)
      result.clientSharingTrend.addAll(clientSharingTrend);
    if (clientInvitationFunnel != null)
      result.clientInvitationFunnel = clientInvitationFunnel;
    if (pairingAttempts != null) result.pairingAttempts.addAll(pairingAttempts);
    if (reportReading != null) result.reportReading = reportReading;
    if (readingPlatforms != null)
      result.readingPlatforms.addAll(readingPlatforms);
    return result;
  }

  GetAdminAnalyticsResponse._();

  factory GetAdminAnalyticsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetAdminAnalyticsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetAdminAnalyticsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'kpiWau')
    ..aInt64(2, _omitFieldNames ? '' : 'kpiSessionsThisWeek')
    ..aD(3, _omitFieldNames ? '' : 'kpiActivationRate')
    ..aD(4, _omitFieldNames ? '' : 'kpiSatisfactionRate')
    ..pPM<TrendPoint>(5, _omitFieldNames ? '' : 'wauTrend',
        subBuilder: TrendPoint.create)
    ..pPM<TrendPoint>(6, _omitFieldNames ? '' : 'sessionsTrend',
        subBuilder: TrendPoint.create)
    ..pPM<TrendPoint>(7, _omitFieldNames ? '' : 'registrationsTrend',
        subBuilder: TrendPoint.create)
    ..pPM<PlanDistribution>(8, _omitFieldNames ? '' : 'planDistribution',
        subBuilder: PlanDistribution.create)
    ..aD(9, _omitFieldNames ? '' : 'kpiAvgCostPerSession')
    ..aD(10, _omitFieldNames ? '' : 'kpiMonthlySttCost')
    ..aD(11, _omitFieldNames ? '' : 'kpiMonthlyLlmCost')
    ..aD(12, _omitFieldNames ? '' : 'kpiAvgTokenUtilization')
    ..pPM<CostTrendPoint>(13, _omitFieldNames ? '' : 'costTrend',
        subBuilder: CostTrendPoint.create)
    ..pPM<TokenUtilizationHeatmapPoint>(
        14, _omitFieldNames ? '' : 'tokenUtilizationHeatmap',
        subBuilder: TokenUtilizationHeatmapPoint.create)
    ..pPM<RevenueTrendPoint>(15, _omitFieldNames ? '' : 'revenueTrend',
        subBuilder: RevenueTrendPoint.create)
    ..pPM<TokenUsageTrendPoint>(16, _omitFieldNames ? '' : 'tokenUsageTrend',
        subBuilder: TokenUsageTrendPoint.create)
    ..aD(17, _omitFieldNames ? '' : 'kpiAvgPipelineLatency')
    ..aD(18, _omitFieldNames ? '' : 'kpiFailureRate7d',
        protoName: 'kpi_failure_rate_7d')
    ..aD(19, _omitFieldNames ? '' : 'kpiRelabelRate')
    ..pPM<SatisfactionTrendPoint>(
        20, _omitFieldNames ? '' : 'satisfactionTrend',
        subBuilder: SatisfactionTrendPoint.create)
    ..pPM<IssueCategory>(21, _omitFieldNames ? '' : 'issueCategories',
        subBuilder: IssueCategory.create)
    ..pPM<LatencyTrendPoint>(22, _omitFieldNames ? '' : 'latencyTrend',
        subBuilder: LatencyTrendPoint.create)
    ..pPM<FailureRatePoint>(23, _omitFieldNames ? '' : 'failureRateTrend',
        subBuilder: FailureRatePoint.create)
    ..aD(24, _omitFieldNames ? '' : 'kpi30dRetention',
        protoName: 'kpi_30d_retention')
    ..pPM<FunnelStep>(25, _omitFieldNames ? '' : 'funnelSteps',
        subBuilder: FunnelStep.create)
    ..pPM<CohortRetentionPoint>(26, _omitFieldNames ? '' : 'cohortRetention',
        subBuilder: CohortRetentionPoint.create)
    ..pPM<HistogramBucket>(27, _omitFieldNames ? '' : 'activationTimeHistogram',
        subBuilder: HistogramBucket.create)
    ..pPM<HourlyHeatmapPoint>(28, _omitFieldNames ? '' : 'hourlyHeatmap',
        subBuilder: HourlyHeatmapPoint.create)
    ..pPM<FailureRatePoint>(29, _omitFieldNames ? '' : 'uploadFailuresTrend',
        subBuilder: FailureRatePoint.create)
    ..pPM<ModalityDistribution>(
        30, _omitFieldNames ? '' : 'modalityDistribution',
        subBuilder: ModalityDistribution.create)
    ..aD(31, _omitFieldNames ? '' : 'kpiAvgSessionDuration')
    ..pPM<TrendPoint>(32, _omitFieldNames ? '' : 'sessionDurationTrend',
        subBuilder: TrendPoint.create)
    ..pPM<PlatformFixedCost>(33, _omitFieldNames ? '' : 'platformFixedCosts',
        subBuilder: PlatformFixedCost.create)
    ..aInt64(34, _omitFieldNames ? '' : 'kpiRatingsTotal')
    ..aInt64(35, _omitFieldNames ? '' : 'kpiRatingsPositive')
    ..aInt64(36, _omitFieldNames ? '' : 'kpiRatingsNegative')
    ..aInt64(37, _omitFieldNames ? '' : 'kpiRatingsWithNotes')
    ..pPM<RegisteredUserDetail>(
        38, _omitFieldNames ? '' : 'registrationsDetail',
        subBuilder: RegisteredUserDetail.create)
    ..pPM<ClientSharingPoint>(39, _omitFieldNames ? '' : 'clientSharingTrend',
        subBuilder: ClientSharingPoint.create)
    ..aOM<ClientInvitationFunnel>(
        40, _omitFieldNames ? '' : 'clientInvitationFunnel',
        subBuilder: ClientInvitationFunnel.create)
    ..pPM<PairingAttemptBucket>(41, _omitFieldNames ? '' : 'pairingAttempts',
        subBuilder: PairingAttemptBucket.create)
    ..aOM<ReportReadingStats>(42, _omitFieldNames ? '' : 'reportReading',
        subBuilder: ReportReadingStats.create)
    ..pPM<PlatformReads>(43, _omitFieldNames ? '' : 'readingPlatforms',
        subBuilder: PlatformReads.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAdminAnalyticsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAdminAnalyticsResponse copyWith(
          void Function(GetAdminAnalyticsResponse) updates) =>
      super.copyWith((message) => updates(message as GetAdminAnalyticsResponse))
          as GetAdminAnalyticsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAdminAnalyticsResponse create() => GetAdminAnalyticsResponse._();
  @$core.override
  GetAdminAnalyticsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetAdminAnalyticsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetAdminAnalyticsResponse>(create);
  static GetAdminAnalyticsResponse? _defaultInstance;

  /// Tab 1: Executive Overview
  @$pb.TagNumber(1)
  $fixnum.Int64 get kpiWau => $_getI64(0);
  @$pb.TagNumber(1)
  set kpiWau($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKpiWau() => $_has(0);
  @$pb.TagNumber(1)
  void clearKpiWau() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get kpiSessionsThisWeek => $_getI64(1);
  @$pb.TagNumber(2)
  set kpiSessionsThisWeek($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKpiSessionsThisWeek() => $_has(1);
  @$pb.TagNumber(2)
  void clearKpiSessionsThisWeek() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get kpiActivationRate => $_getN(2);
  @$pb.TagNumber(3)
  set kpiActivationRate($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKpiActivationRate() => $_has(2);
  @$pb.TagNumber(3)
  void clearKpiActivationRate() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get kpiSatisfactionRate => $_getN(3);
  @$pb.TagNumber(4)
  set kpiSatisfactionRate($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasKpiSatisfactionRate() => $_has(3);
  @$pb.TagNumber(4)
  void clearKpiSatisfactionRate() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<TrendPoint> get wauTrend => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<TrendPoint> get sessionsTrend => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbList<TrendPoint> get registrationsTrend => $_getList(6);

  @$pb.TagNumber(8)
  $pb.PbList<PlanDistribution> get planDistribution => $_getList(7);

  /// Tab 2: Unit Economics
  @$pb.TagNumber(9)
  $core.double get kpiAvgCostPerSession => $_getN(8);
  @$pb.TagNumber(9)
  set kpiAvgCostPerSession($core.double value) => $_setDouble(8, value);
  @$pb.TagNumber(9)
  $core.bool hasKpiAvgCostPerSession() => $_has(8);
  @$pb.TagNumber(9)
  void clearKpiAvgCostPerSession() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.double get kpiMonthlySttCost => $_getN(9);
  @$pb.TagNumber(10)
  set kpiMonthlySttCost($core.double value) => $_setDouble(9, value);
  @$pb.TagNumber(10)
  $core.bool hasKpiMonthlySttCost() => $_has(9);
  @$pb.TagNumber(10)
  void clearKpiMonthlySttCost() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.double get kpiMonthlyLlmCost => $_getN(10);
  @$pb.TagNumber(11)
  set kpiMonthlyLlmCost($core.double value) => $_setDouble(10, value);
  @$pb.TagNumber(11)
  $core.bool hasKpiMonthlyLlmCost() => $_has(10);
  @$pb.TagNumber(11)
  void clearKpiMonthlyLlmCost() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.double get kpiAvgTokenUtilization => $_getN(11);
  @$pb.TagNumber(12)
  set kpiAvgTokenUtilization($core.double value) => $_setDouble(11, value);
  @$pb.TagNumber(12)
  $core.bool hasKpiAvgTokenUtilization() => $_has(11);
  @$pb.TagNumber(12)
  void clearKpiAvgTokenUtilization() => $_clearField(12);

  @$pb.TagNumber(13)
  $pb.PbList<CostTrendPoint> get costTrend => $_getList(12);

  @$pb.TagNumber(14)
  $pb.PbList<TokenUtilizationHeatmapPoint> get tokenUtilizationHeatmap =>
      $_getList(13);

  @$pb.TagNumber(15)
  $pb.PbList<RevenueTrendPoint> get revenueTrend => $_getList(14);

  @$pb.TagNumber(16)
  $pb.PbList<TokenUsageTrendPoint> get tokenUsageTrend => $_getList(15);

  /// Tab 3: AI Quality
  @$pb.TagNumber(17)
  $core.double get kpiAvgPipelineLatency => $_getN(16);
  @$pb.TagNumber(17)
  set kpiAvgPipelineLatency($core.double value) => $_setDouble(16, value);
  @$pb.TagNumber(17)
  $core.bool hasKpiAvgPipelineLatency() => $_has(16);
  @$pb.TagNumber(17)
  void clearKpiAvgPipelineLatency() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.double get kpiFailureRate7d => $_getN(17);
  @$pb.TagNumber(18)
  set kpiFailureRate7d($core.double value) => $_setDouble(17, value);
  @$pb.TagNumber(18)
  $core.bool hasKpiFailureRate7d() => $_has(17);
  @$pb.TagNumber(18)
  void clearKpiFailureRate7d() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.double get kpiRelabelRate => $_getN(18);
  @$pb.TagNumber(19)
  set kpiRelabelRate($core.double value) => $_setDouble(18, value);
  @$pb.TagNumber(19)
  $core.bool hasKpiRelabelRate() => $_has(18);
  @$pb.TagNumber(19)
  void clearKpiRelabelRate() => $_clearField(19);

  @$pb.TagNumber(20)
  $pb.PbList<SatisfactionTrendPoint> get satisfactionTrend => $_getList(19);

  @$pb.TagNumber(21)
  $pb.PbList<IssueCategory> get issueCategories => $_getList(20);

  @$pb.TagNumber(22)
  $pb.PbList<LatencyTrendPoint> get latencyTrend => $_getList(21);

  @$pb.TagNumber(23)
  $pb.PbList<FailureRatePoint> get failureRateTrend => $_getList(22);

  /// Tab 4: Funnel & Retention
  @$pb.TagNumber(24)
  $core.double get kpi30dRetention => $_getN(23);
  @$pb.TagNumber(24)
  set kpi30dRetention($core.double value) => $_setDouble(23, value);
  @$pb.TagNumber(24)
  $core.bool hasKpi30dRetention() => $_has(23);
  @$pb.TagNumber(24)
  void clearKpi30dRetention() => $_clearField(24);

  @$pb.TagNumber(25)
  $pb.PbList<FunnelStep> get funnelSteps => $_getList(24);

  @$pb.TagNumber(26)
  $pb.PbList<CohortRetentionPoint> get cohortRetention => $_getList(25);

  @$pb.TagNumber(27)
  $pb.PbList<HistogramBucket> get activationTimeHistogram => $_getList(26);

  /// Tab 5: Operations
  @$pb.TagNumber(28)
  $pb.PbList<HourlyHeatmapPoint> get hourlyHeatmap => $_getList(27);

  @$pb.TagNumber(29)
  $pb.PbList<FailureRatePoint> get uploadFailuresTrend => $_getList(28);

  /// Custom Analytics
  @$pb.TagNumber(30)
  $pb.PbList<ModalityDistribution> get modalityDistribution => $_getList(29);

  @$pb.TagNumber(31)
  $core.double get kpiAvgSessionDuration => $_getN(30);
  @$pb.TagNumber(31)
  set kpiAvgSessionDuration($core.double value) => $_setDouble(30, value);
  @$pb.TagNumber(31)
  $core.bool hasKpiAvgSessionDuration() => $_has(30);
  @$pb.TagNumber(31)
  void clearKpiAvgSessionDuration() => $_clearField(31);

  @$pb.TagNumber(32)
  $pb.PbList<TrendPoint> get sessionDurationTrend => $_getList(31);

  @$pb.TagNumber(33)
  $pb.PbList<PlatformFixedCost> get platformFixedCosts => $_getList(32);

  /// Tab 6: Report Feedback
  @$pb.TagNumber(34)
  $fixnum.Int64 get kpiRatingsTotal => $_getI64(33);
  @$pb.TagNumber(34)
  set kpiRatingsTotal($fixnum.Int64 value) => $_setInt64(33, value);
  @$pb.TagNumber(34)
  $core.bool hasKpiRatingsTotal() => $_has(33);
  @$pb.TagNumber(34)
  void clearKpiRatingsTotal() => $_clearField(34);

  @$pb.TagNumber(35)
  $fixnum.Int64 get kpiRatingsPositive => $_getI64(34);
  @$pb.TagNumber(35)
  set kpiRatingsPositive($fixnum.Int64 value) => $_setInt64(34, value);
  @$pb.TagNumber(35)
  $core.bool hasKpiRatingsPositive() => $_has(34);
  @$pb.TagNumber(35)
  void clearKpiRatingsPositive() => $_clearField(35);

  @$pb.TagNumber(36)
  $fixnum.Int64 get kpiRatingsNegative => $_getI64(35);
  @$pb.TagNumber(36)
  set kpiRatingsNegative($fixnum.Int64 value) => $_setInt64(35, value);
  @$pb.TagNumber(36)
  $core.bool hasKpiRatingsNegative() => $_has(35);
  @$pb.TagNumber(36)
  void clearKpiRatingsNegative() => $_clearField(36);

  @$pb.TagNumber(37)
  $fixnum.Int64 get kpiRatingsWithNotes => $_getI64(36);
  @$pb.TagNumber(37)
  set kpiRatingsWithNotes($fixnum.Int64 value) => $_setInt64(36, value);
  @$pb.TagNumber(37)
  $core.bool hasKpiRatingsWithNotes() => $_has(36);
  @$pb.TagNumber(37)
  void clearKpiRatingsWithNotes() => $_clearField(37);

  /// Tab 1 registrations detail
  @$pb.TagNumber(38)
  $pb.PbList<RegisteredUserDetail> get registrationsDetail => $_getList(37);

  /// Zakładki "Użycie" i "Pętla z klientem" (14.08.2026).
  ///
  /// Panel odpowiadał dotąd na "jak działa system", nie na "jak ludzie z
  /// niego korzystają". Te pola nie wymagają ANI JEDNEGO nowego zdarzenia
  /// — stoją na sessions, invitations i istniejących parach
  /// report.read_started / report.read_finished.
  @$pb.TagNumber(39)
  $pb.PbList<ClientSharingPoint> get clientSharingTrend => $_getList(38);

  @$pb.TagNumber(40)
  ClientInvitationFunnel get clientInvitationFunnel => $_getN(39);
  @$pb.TagNumber(40)
  set clientInvitationFunnel(ClientInvitationFunnel value) =>
      $_setField(40, value);
  @$pb.TagNumber(40)
  $core.bool hasClientInvitationFunnel() => $_has(39);
  @$pb.TagNumber(40)
  void clearClientInvitationFunnel() => $_clearField(40);
  @$pb.TagNumber(40)
  ClientInvitationFunnel ensureClientInvitationFunnel() => $_ensure(39);

  @$pb.TagNumber(41)
  $pb.PbList<PairingAttemptBucket> get pairingAttempts => $_getList(40);

  @$pb.TagNumber(42)
  ReportReadingStats get reportReading => $_getN(41);
  @$pb.TagNumber(42)
  set reportReading(ReportReadingStats value) => $_setField(42, value);
  @$pb.TagNumber(42)
  $core.bool hasReportReading() => $_has(41);
  @$pb.TagNumber(42)
  void clearReportReading() => $_clearField(42);
  @$pb.TagNumber(42)
  ReportReadingStats ensureReportReading() => $_ensure(41);

  @$pb.TagNumber(43)
  $pb.PbList<PlatformReads> get readingPlatforms => $_getList(42);
}

class RegisteredUserDetail extends $pb.GeneratedMessage {
  factory RegisteredUserDetail({
    $core.String? userId,
    $core.String? email,
    $core.String? firstName,
    $core.String? lastName,
    $3.Timestamp? createdAt,
    $fixnum.Int64? loginCount,
    $fixnum.Int64? sessionCount,
    $core.bool? hasMarketingConsent,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (email != null) result.email = email;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (createdAt != null) result.createdAt = createdAt;
    if (loginCount != null) result.loginCount = loginCount;
    if (sessionCount != null) result.sessionCount = sessionCount;
    if (hasMarketingConsent != null)
      result.hasMarketingConsent = hasMarketingConsent;
    return result;
  }

  RegisteredUserDetail._();

  factory RegisteredUserDetail.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisteredUserDetail.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisteredUserDetail',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'email')
    ..aOS(3, _omitFieldNames ? '' : 'firstName')
    ..aOS(4, _omitFieldNames ? '' : 'lastName')
    ..aOM<$3.Timestamp>(5, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $3.Timestamp.create)
    ..aInt64(6, _omitFieldNames ? '' : 'loginCount')
    ..aInt64(7, _omitFieldNames ? '' : 'sessionCount')
    ..aOB(8, _omitFieldNames ? '' : 'hasMarketingConsent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisteredUserDetail clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisteredUserDetail copyWith(void Function(RegisteredUserDetail) updates) =>
      super.copyWith((message) => updates(message as RegisteredUserDetail))
          as RegisteredUserDetail;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisteredUserDetail create() => RegisteredUserDetail._();
  @$core.override
  RegisteredUserDetail createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisteredUserDetail getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisteredUserDetail>(create);
  static RegisteredUserDetail? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get email => $_getSZ(1);
  @$pb.TagNumber(2)
  set email($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmail() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get firstName => $_getSZ(2);
  @$pb.TagNumber(3)
  set firstName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFirstName() => $_has(2);
  @$pb.TagNumber(3)
  void clearFirstName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get lastName => $_getSZ(3);
  @$pb.TagNumber(4)
  set lastName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastName() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastName() => $_clearField(4);

  @$pb.TagNumber(5)
  $3.Timestamp get createdAt => $_getN(4);
  @$pb.TagNumber(5)
  set createdAt($3.Timestamp value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCreatedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearCreatedAt() => $_clearField(5);
  @$pb.TagNumber(5)
  $3.Timestamp ensureCreatedAt() => $_ensure(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get loginCount => $_getI64(5);
  @$pb.TagNumber(6)
  set loginCount($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLoginCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearLoginCount() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get sessionCount => $_getI64(6);
  @$pb.TagNumber(7)
  set sessionCount($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSessionCount() => $_has(6);
  @$pb.TagNumber(7)
  void clearSessionCount() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get hasMarketingConsent => $_getBF(7);
  @$pb.TagNumber(8)
  set hasMarketingConsent($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasHasMarketingConsent() => $_has(7);
  @$pb.TagNumber(8)
  void clearHasMarketingConsent() => $_clearField(8);
}

class TrendPoint extends $pb.GeneratedMessage {
  factory TrendPoint({
    $core.String? label,
    $core.double? value,
  }) {
    final result = create();
    if (label != null) result.label = label;
    if (value != null) result.value = value;
    return result;
  }

  TrendPoint._();

  factory TrendPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrendPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrendPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aD(2, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrendPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrendPoint copyWith(void Function(TrendPoint) updates) =>
      super.copyWith((message) => updates(message as TrendPoint)) as TrendPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrendPoint create() => TrendPoint._();
  @$core.override
  TrendPoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrendPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrendPoint>(create);
  static TrendPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
}

class PlanDistribution extends $pb.GeneratedMessage {
  factory PlanDistribution({
    $core.String? planName,
    $fixnum.Int64? count,
  }) {
    final result = create();
    if (planName != null) result.planName = planName;
    if (count != null) result.count = count;
    return result;
  }

  PlanDistribution._();

  factory PlanDistribution.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlanDistribution.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlanDistribution',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'planName')
    ..aInt64(2, _omitFieldNames ? '' : 'count')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanDistribution clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanDistribution copyWith(void Function(PlanDistribution) updates) =>
      super.copyWith((message) => updates(message as PlanDistribution))
          as PlanDistribution;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlanDistribution create() => PlanDistribution._();
  @$core.override
  PlanDistribution createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlanDistribution getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlanDistribution>(create);
  static PlanDistribution? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get planName => $_getSZ(0);
  @$pb.TagNumber(1)
  set planName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlanName() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlanName() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get count => $_getI64(1);
  @$pb.TagNumber(2)
  set count($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);
}

class ModalityDistribution extends $pb.GeneratedMessage {
  factory ModalityDistribution({
    $core.String? modalityName,
    $fixnum.Int64? count,
  }) {
    final result = create();
    if (modalityName != null) result.modalityName = modalityName;
    if (count != null) result.count = count;
    return result;
  }

  ModalityDistribution._();

  factory ModalityDistribution.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModalityDistribution.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModalityDistribution',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'modalityName')
    ..aInt64(2, _omitFieldNames ? '' : 'count')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModalityDistribution clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModalityDistribution copyWith(void Function(ModalityDistribution) updates) =>
      super.copyWith((message) => updates(message as ModalityDistribution))
          as ModalityDistribution;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModalityDistribution create() => ModalityDistribution._();
  @$core.override
  ModalityDistribution createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModalityDistribution getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModalityDistribution>(create);
  static ModalityDistribution? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get modalityName => $_getSZ(0);
  @$pb.TagNumber(1)
  set modalityName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasModalityName() => $_has(0);
  @$pb.TagNumber(1)
  void clearModalityName() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get count => $_getI64(1);
  @$pb.TagNumber(2)
  set count($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);
}

class CostTrendPoint extends $pb.GeneratedMessage {
  factory CostTrendPoint({
    $core.String? label,
    $core.double? sttCost,
    $core.double? llmCost,
    $core.double? totalCost,
  }) {
    final result = create();
    if (label != null) result.label = label;
    if (sttCost != null) result.sttCost = sttCost;
    if (llmCost != null) result.llmCost = llmCost;
    if (totalCost != null) result.totalCost = totalCost;
    return result;
  }

  CostTrendPoint._();

  factory CostTrendPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CostTrendPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CostTrendPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aD(2, _omitFieldNames ? '' : 'sttCost')
    ..aD(3, _omitFieldNames ? '' : 'llmCost')
    ..aD(4, _omitFieldNames ? '' : 'totalCost')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CostTrendPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CostTrendPoint copyWith(void Function(CostTrendPoint) updates) =>
      super.copyWith((message) => updates(message as CostTrendPoint))
          as CostTrendPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CostTrendPoint create() => CostTrendPoint._();
  @$core.override
  CostTrendPoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CostTrendPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CostTrendPoint>(create);
  static CostTrendPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get sttCost => $_getN(1);
  @$pb.TagNumber(2)
  set sttCost($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSttCost() => $_has(1);
  @$pb.TagNumber(2)
  void clearSttCost() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get llmCost => $_getN(2);
  @$pb.TagNumber(3)
  set llmCost($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLlmCost() => $_has(2);
  @$pb.TagNumber(3)
  void clearLlmCost() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get totalCost => $_getN(3);
  @$pb.TagNumber(4)
  set totalCost($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalCost() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalCost() => $_clearField(4);
}

class TokenUtilizationHeatmapPoint extends $pb.GeneratedMessage {
  factory TokenUtilizationHeatmapPoint({
    $core.String? orgName,
    $core.String? week,
    $core.double? value,
  }) {
    final result = create();
    if (orgName != null) result.orgName = orgName;
    if (week != null) result.week = week;
    if (value != null) result.value = value;
    return result;
  }

  TokenUtilizationHeatmapPoint._();

  factory TokenUtilizationHeatmapPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TokenUtilizationHeatmapPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TokenUtilizationHeatmapPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'orgName')
    ..aOS(2, _omitFieldNames ? '' : 'week')
    ..aD(3, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TokenUtilizationHeatmapPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TokenUtilizationHeatmapPoint copyWith(
          void Function(TokenUtilizationHeatmapPoint) updates) =>
      super.copyWith(
              (message) => updates(message as TokenUtilizationHeatmapPoint))
          as TokenUtilizationHeatmapPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TokenUtilizationHeatmapPoint create() =>
      TokenUtilizationHeatmapPoint._();
  @$core.override
  TokenUtilizationHeatmapPoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TokenUtilizationHeatmapPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TokenUtilizationHeatmapPoint>(create);
  static TokenUtilizationHeatmapPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get orgName => $_getSZ(0);
  @$pb.TagNumber(1)
  set orgName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrgName() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrgName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get week => $_getSZ(1);
  @$pb.TagNumber(2)
  set week($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWeek() => $_has(1);
  @$pb.TagNumber(2)
  void clearWeek() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get value => $_getN(2);
  @$pb.TagNumber(3)
  set value($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearValue() => $_clearField(3);
}

class RevenueTrendPoint extends $pb.GeneratedMessage {
  factory RevenueTrendPoint({
    $core.String? label,
    $core.double? soloRevenue,
    $core.double? proRevenue,
    $core.double? totalRevenue,
  }) {
    final result = create();
    if (label != null) result.label = label;
    if (soloRevenue != null) result.soloRevenue = soloRevenue;
    if (proRevenue != null) result.proRevenue = proRevenue;
    if (totalRevenue != null) result.totalRevenue = totalRevenue;
    return result;
  }

  RevenueTrendPoint._();

  factory RevenueTrendPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RevenueTrendPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevenueTrendPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aD(2, _omitFieldNames ? '' : 'soloRevenue')
    ..aD(3, _omitFieldNames ? '' : 'proRevenue')
    ..aD(4, _omitFieldNames ? '' : 'totalRevenue')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevenueTrendPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevenueTrendPoint copyWith(void Function(RevenueTrendPoint) updates) =>
      super.copyWith((message) => updates(message as RevenueTrendPoint))
          as RevenueTrendPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RevenueTrendPoint create() => RevenueTrendPoint._();
  @$core.override
  RevenueTrendPoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RevenueTrendPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RevenueTrendPoint>(create);
  static RevenueTrendPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get soloRevenue => $_getN(1);
  @$pb.TagNumber(2)
  set soloRevenue($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSoloRevenue() => $_has(1);
  @$pb.TagNumber(2)
  void clearSoloRevenue() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get proRevenue => $_getN(2);
  @$pb.TagNumber(3)
  set proRevenue($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProRevenue() => $_has(2);
  @$pb.TagNumber(3)
  void clearProRevenue() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get totalRevenue => $_getN(3);
  @$pb.TagNumber(4)
  set totalRevenue($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalRevenue() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalRevenue() => $_clearField(4);
}

class TokenUsageTrendPoint extends $pb.GeneratedMessage {
  factory TokenUsageTrendPoint({
    $core.String? label,
    $fixnum.Int64? inputTokens,
    $fixnum.Int64? outputTokens,
  }) {
    final result = create();
    if (label != null) result.label = label;
    if (inputTokens != null) result.inputTokens = inputTokens;
    if (outputTokens != null) result.outputTokens = outputTokens;
    return result;
  }

  TokenUsageTrendPoint._();

  factory TokenUsageTrendPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TokenUsageTrendPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TokenUsageTrendPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aInt64(2, _omitFieldNames ? '' : 'inputTokens')
    ..aInt64(3, _omitFieldNames ? '' : 'outputTokens')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TokenUsageTrendPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TokenUsageTrendPoint copyWith(void Function(TokenUsageTrendPoint) updates) =>
      super.copyWith((message) => updates(message as TokenUsageTrendPoint))
          as TokenUsageTrendPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TokenUsageTrendPoint create() => TokenUsageTrendPoint._();
  @$core.override
  TokenUsageTrendPoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TokenUsageTrendPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TokenUsageTrendPoint>(create);
  static TokenUsageTrendPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get inputTokens => $_getI64(1);
  @$pb.TagNumber(2)
  set inputTokens($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInputTokens() => $_has(1);
  @$pb.TagNumber(2)
  void clearInputTokens() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get outputTokens => $_getI64(2);
  @$pb.TagNumber(3)
  set outputTokens($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOutputTokens() => $_has(2);
  @$pb.TagNumber(3)
  void clearOutputTokens() => $_clearField(3);
}

class SatisfactionTrendPoint extends $pb.GeneratedMessage {
  factory SatisfactionTrendPoint({
    $core.String? label,
    $core.double? satisfactionPct,
  }) {
    final result = create();
    if (label != null) result.label = label;
    if (satisfactionPct != null) result.satisfactionPct = satisfactionPct;
    return result;
  }

  SatisfactionTrendPoint._();

  factory SatisfactionTrendPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SatisfactionTrendPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SatisfactionTrendPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aD(2, _omitFieldNames ? '' : 'satisfactionPct')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SatisfactionTrendPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SatisfactionTrendPoint copyWith(
          void Function(SatisfactionTrendPoint) updates) =>
      super.copyWith((message) => updates(message as SatisfactionTrendPoint))
          as SatisfactionTrendPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SatisfactionTrendPoint create() => SatisfactionTrendPoint._();
  @$core.override
  SatisfactionTrendPoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SatisfactionTrendPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SatisfactionTrendPoint>(create);
  static SatisfactionTrendPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get satisfactionPct => $_getN(1);
  @$pb.TagNumber(2)
  set satisfactionPct($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSatisfactionPct() => $_has(1);
  @$pb.TagNumber(2)
  void clearSatisfactionPct() => $_clearField(2);
}

class IssueCategory extends $pb.GeneratedMessage {
  factory IssueCategory({
    $core.String? category,
    $fixnum.Int64? count,
  }) {
    final result = create();
    if (category != null) result.category = category;
    if (count != null) result.count = count;
    return result;
  }

  IssueCategory._();

  factory IssueCategory.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IssueCategory.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IssueCategory',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'category')
    ..aInt64(2, _omitFieldNames ? '' : 'count')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IssueCategory clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IssueCategory copyWith(void Function(IssueCategory) updates) =>
      super.copyWith((message) => updates(message as IssueCategory))
          as IssueCategory;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IssueCategory create() => IssueCategory._();
  @$core.override
  IssueCategory createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IssueCategory getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IssueCategory>(create);
  static IssueCategory? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get category => $_getSZ(0);
  @$pb.TagNumber(1)
  set category($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCategory() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategory() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get count => $_getI64(1);
  @$pb.TagNumber(2)
  set count($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);
}

class LatencyTrendPoint extends $pb.GeneratedMessage {
  factory LatencyTrendPoint({
    $core.String? label,
    $core.double? p50,
    $core.double? p95,
  }) {
    final result = create();
    if (label != null) result.label = label;
    if (p50 != null) result.p50 = p50;
    if (p95 != null) result.p95 = p95;
    return result;
  }

  LatencyTrendPoint._();

  factory LatencyTrendPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LatencyTrendPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LatencyTrendPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aD(2, _omitFieldNames ? '' : 'p50')
    ..aD(3, _omitFieldNames ? '' : 'p95')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LatencyTrendPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LatencyTrendPoint copyWith(void Function(LatencyTrendPoint) updates) =>
      super.copyWith((message) => updates(message as LatencyTrendPoint))
          as LatencyTrendPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LatencyTrendPoint create() => LatencyTrendPoint._();
  @$core.override
  LatencyTrendPoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LatencyTrendPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LatencyTrendPoint>(create);
  static LatencyTrendPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get p50 => $_getN(1);
  @$pb.TagNumber(2)
  set p50($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasP50() => $_has(1);
  @$pb.TagNumber(2)
  void clearP50() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get p95 => $_getN(2);
  @$pb.TagNumber(3)
  set p95($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasP95() => $_has(2);
  @$pb.TagNumber(3)
  void clearP95() => $_clearField(3);
}

class FailureRatePoint extends $pb.GeneratedMessage {
  factory FailureRatePoint({
    $core.String? label,
    $core.double? failureRate,
    $fixnum.Int64? total,
    $fixnum.Int64? failed,
  }) {
    final result = create();
    if (label != null) result.label = label;
    if (failureRate != null) result.failureRate = failureRate;
    if (total != null) result.total = total;
    if (failed != null) result.failed = failed;
    return result;
  }

  FailureRatePoint._();

  factory FailureRatePoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FailureRatePoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FailureRatePoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aD(2, _omitFieldNames ? '' : 'failureRate')
    ..aInt64(3, _omitFieldNames ? '' : 'total')
    ..aInt64(4, _omitFieldNames ? '' : 'failed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FailureRatePoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FailureRatePoint copyWith(void Function(FailureRatePoint) updates) =>
      super.copyWith((message) => updates(message as FailureRatePoint))
          as FailureRatePoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FailureRatePoint create() => FailureRatePoint._();
  @$core.override
  FailureRatePoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FailureRatePoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FailureRatePoint>(create);
  static FailureRatePoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get failureRate => $_getN(1);
  @$pb.TagNumber(2)
  set failureRate($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFailureRate() => $_has(1);
  @$pb.TagNumber(2)
  void clearFailureRate() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get total => $_getI64(2);
  @$pb.TagNumber(3)
  set total($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotal() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotal() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get failed => $_getI64(3);
  @$pb.TagNumber(4)
  set failed($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFailed() => $_has(3);
  @$pb.TagNumber(4)
  void clearFailed() => $_clearField(4);
}

/// Ile ukończonych sesji trafia do klienta i ile z nich klient ukrywa.
class ClientSharingPoint extends $pb.GeneratedMessage {
  factory ClientSharingPoint({
    $core.String? label,
    $fixnum.Int64? sessionsTotal,
    $fixnum.Int64? shared,
    $fixnum.Int64? hidden,
  }) {
    final result = create();
    if (label != null) result.label = label;
    if (sessionsTotal != null) result.sessionsTotal = sessionsTotal;
    if (shared != null) result.shared = shared;
    if (hidden != null) result.hidden = hidden;
    return result;
  }

  ClientSharingPoint._();

  factory ClientSharingPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientSharingPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientSharingPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aInt64(2, _omitFieldNames ? '' : 'sessionsTotal')
    ..aInt64(3, _omitFieldNames ? '' : 'shared')
    ..aInt64(4, _omitFieldNames ? '' : 'hidden')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientSharingPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientSharingPoint copyWith(void Function(ClientSharingPoint) updates) =>
      super.copyWith((message) => updates(message as ClientSharingPoint))
          as ClientSharingPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientSharingPoint create() => ClientSharingPoint._();
  @$core.override
  ClientSharingPoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientSharingPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientSharingPoint>(create);
  static ClientSharingPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get sessionsTotal => $_getI64(1);
  @$pb.TagNumber(2)
  set sessionsTotal($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionsTotal() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionsTotal() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get shared => $_getI64(2);
  @$pb.TagNumber(3)
  set shared($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasShared() => $_has(2);
  @$pb.TagNumber(3)
  void clearShared() => $_clearField(3);

  /// Raport dotarł, ale klient go schował — sygnał odbioru, nie wysyłki.
  @$pb.TagNumber(4)
  $fixnum.Int64 get hidden => $_getI64(3);
  @$pb.TagNumber(4)
  set hidden($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHidden() => $_has(3);
  @$pb.TagNumber(4)
  void clearHidden() => $_clearField(4);
}

class ClientInvitationFunnel extends $pb.GeneratedMessage {
  factory ClientInvitationFunnel({
    $fixnum.Int64? sent,
    $fixnum.Int64? accepted,
    $fixnum.Int64? revoked,
    $fixnum.Int64? expired,
    $core.double? medianHoursToAccept,
  }) {
    final result = create();
    if (sent != null) result.sent = sent;
    if (accepted != null) result.accepted = accepted;
    if (revoked != null) result.revoked = revoked;
    if (expired != null) result.expired = expired;
    if (medianHoursToAccept != null)
      result.medianHoursToAccept = medianHoursToAccept;
    return result;
  }

  ClientInvitationFunnel._();

  factory ClientInvitationFunnel.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientInvitationFunnel.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientInvitationFunnel',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'sent')
    ..aInt64(2, _omitFieldNames ? '' : 'accepted')
    ..aInt64(3, _omitFieldNames ? '' : 'revoked')
    ..aInt64(4, _omitFieldNames ? '' : 'expired')
    ..aD(5, _omitFieldNames ? '' : 'medianHoursToAccept')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientInvitationFunnel clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientInvitationFunnel copyWith(
          void Function(ClientInvitationFunnel) updates) =>
      super.copyWith((message) => updates(message as ClientInvitationFunnel))
          as ClientInvitationFunnel;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientInvitationFunnel create() => ClientInvitationFunnel._();
  @$core.override
  ClientInvitationFunnel createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientInvitationFunnel getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientInvitationFunnel>(create);
  static ClientInvitationFunnel? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get sent => $_getI64(0);
  @$pb.TagNumber(1)
  set sent($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSent() => $_has(0);
  @$pb.TagNumber(1)
  void clearSent() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get accepted => $_getI64(1);
  @$pb.TagNumber(2)
  set accepted($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAccepted() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccepted() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get revoked => $_getI64(2);
  @$pb.TagNumber(3)
  set revoked($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRevoked() => $_has(2);
  @$pb.TagNumber(3)
  void clearRevoked() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get expired => $_getI64(3);
  @$pb.TagNumber(4)
  set expired($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExpired() => $_has(3);
  @$pb.TagNumber(4)
  void clearExpired() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get medianHoursToAccept => $_getN(4);
  @$pb.TagNumber(5)
  set medianHoursToAccept($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMedianHoursToAccept() => $_has(4);
  @$pb.TagNumber(5)
  void clearMedianHoursToAccept() => $_clearField(5);
}

/// Rozkład, nie średnia — interesuje nas ogon, czyli klienci, którzy
/// męczą się z kodem parowania kilka razy.
class PairingAttemptBucket extends $pb.GeneratedMessage {
  factory PairingAttemptBucket({
    $core.int? attempts,
    $fixnum.Int64? invitations,
  }) {
    final result = create();
    if (attempts != null) result.attempts = attempts;
    if (invitations != null) result.invitations = invitations;
    return result;
  }

  PairingAttemptBucket._();

  factory PairingAttemptBucket.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PairingAttemptBucket.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairingAttemptBucket',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'attempts')
    ..aInt64(2, _omitFieldNames ? '' : 'invitations')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingAttemptBucket clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingAttemptBucket copyWith(void Function(PairingAttemptBucket) updates) =>
      super.copyWith((message) => updates(message as PairingAttemptBucket))
          as PairingAttemptBucket;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PairingAttemptBucket create() => PairingAttemptBucket._();
  @$core.override
  PairingAttemptBucket createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PairingAttemptBucket getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PairingAttemptBucket>(create);
  static PairingAttemptBucket? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get attempts => $_getIZ(0);
  @$pb.TagNumber(1)
  set attempts($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAttempts() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttempts() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get invitations => $_getI64(1);
  @$pb.TagNumber(2)
  set invitations($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInvitations() => $_has(1);
  @$pb.TagNumber(2)
  void clearInvitations() => $_clearField(2);
}

/// active_read_ms mierzy klient i zatrzymuje licznik przy zejściu w tło,
/// więc median_seconds to czas AKTYWNY, nie czas otwartego ekranu.
/// Różnica started-finished to czytania przerwane.
class ReportReadingStats extends $pb.GeneratedMessage {
  factory ReportReadingStats({
    $fixnum.Int64? started,
    $fixnum.Int64? finished,
    $core.double? medianSeconds,
    $core.double? p90Seconds,
  }) {
    final result = create();
    if (started != null) result.started = started;
    if (finished != null) result.finished = finished;
    if (medianSeconds != null) result.medianSeconds = medianSeconds;
    if (p90Seconds != null) result.p90Seconds = p90Seconds;
    return result;
  }

  ReportReadingStats._();

  factory ReportReadingStats.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReportReadingStats.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReportReadingStats',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'started')
    ..aInt64(2, _omitFieldNames ? '' : 'finished')
    ..aD(3, _omitFieldNames ? '' : 'medianSeconds')
    ..aD(4, _omitFieldNames ? '' : 'p90Seconds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReportReadingStats clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReportReadingStats copyWith(void Function(ReportReadingStats) updates) =>
      super.copyWith((message) => updates(message as ReportReadingStats))
          as ReportReadingStats;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReportReadingStats create() => ReportReadingStats._();
  @$core.override
  ReportReadingStats createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReportReadingStats getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReportReadingStats>(create);
  static ReportReadingStats? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get started => $_getI64(0);
  @$pb.TagNumber(1)
  set started($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStarted() => $_has(0);
  @$pb.TagNumber(1)
  void clearStarted() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get finished => $_getI64(1);
  @$pb.TagNumber(2)
  set finished($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFinished() => $_has(1);
  @$pb.TagNumber(2)
  void clearFinished() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get medianSeconds => $_getN(2);
  @$pb.TagNumber(3)
  set medianSeconds($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMedianSeconds() => $_has(2);
  @$pb.TagNumber(3)
  void clearMedianSeconds() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get p90Seconds => $_getN(3);
  @$pb.TagNumber(4)
  set p90Seconds($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasP90Seconds() => $_has(3);
  @$pb.TagNumber(4)
  void clearP90Seconds() => $_clearField(4);
}

class PlatformReads extends $pb.GeneratedMessage {
  factory PlatformReads({
    $core.String? platform,
    $fixnum.Int64? reads,
  }) {
    final result = create();
    if (platform != null) result.platform = platform;
    if (reads != null) result.reads = reads;
    return result;
  }

  PlatformReads._();

  factory PlatformReads.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlatformReads.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlatformReads',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'platform')
    ..aInt64(2, _omitFieldNames ? '' : 'reads')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlatformReads clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlatformReads copyWith(void Function(PlatformReads) updates) =>
      super.copyWith((message) => updates(message as PlatformReads))
          as PlatformReads;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlatformReads create() => PlatformReads._();
  @$core.override
  PlatformReads createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlatformReads getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlatformReads>(create);
  static PlatformReads? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get platform => $_getSZ(0);
  @$pb.TagNumber(1)
  set platform($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlatform() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlatform() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get reads => $_getI64(1);
  @$pb.TagNumber(2)
  set reads($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReads() => $_has(1);
  @$pb.TagNumber(2)
  void clearReads() => $_clearField(2);
}

class FunnelStep extends $pb.GeneratedMessage {
  factory FunnelStep({
    $core.String? stepName,
    $fixnum.Int64? count,
    $core.double? pctOfPrevious,
  }) {
    final result = create();
    if (stepName != null) result.stepName = stepName;
    if (count != null) result.count = count;
    if (pctOfPrevious != null) result.pctOfPrevious = pctOfPrevious;
    return result;
  }

  FunnelStep._();

  factory FunnelStep.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FunnelStep.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FunnelStep',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'stepName')
    ..aInt64(2, _omitFieldNames ? '' : 'count')
    ..aD(3, _omitFieldNames ? '' : 'pctOfPrevious')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FunnelStep clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FunnelStep copyWith(void Function(FunnelStep) updates) =>
      super.copyWith((message) => updates(message as FunnelStep)) as FunnelStep;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FunnelStep create() => FunnelStep._();
  @$core.override
  FunnelStep createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FunnelStep getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FunnelStep>(create);
  static FunnelStep? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get stepName => $_getSZ(0);
  @$pb.TagNumber(1)
  set stepName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStepName() => $_has(0);
  @$pb.TagNumber(1)
  void clearStepName() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get count => $_getI64(1);
  @$pb.TagNumber(2)
  set count($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get pctOfPrevious => $_getN(2);
  @$pb.TagNumber(3)
  set pctOfPrevious($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPctOfPrevious() => $_has(2);
  @$pb.TagNumber(3)
  void clearPctOfPrevious() => $_clearField(3);
}

class CohortRetentionPoint extends $pb.GeneratedMessage {
  factory CohortRetentionPoint({
    $core.String? cohort,
    $core.String? week,
    $core.double? pct,
  }) {
    final result = create();
    if (cohort != null) result.cohort = cohort;
    if (week != null) result.week = week;
    if (pct != null) result.pct = pct;
    return result;
  }

  CohortRetentionPoint._();

  factory CohortRetentionPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CohortRetentionPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CohortRetentionPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cohort')
    ..aOS(2, _omitFieldNames ? '' : 'week')
    ..aD(3, _omitFieldNames ? '' : 'pct')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CohortRetentionPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CohortRetentionPoint copyWith(void Function(CohortRetentionPoint) updates) =>
      super.copyWith((message) => updates(message as CohortRetentionPoint))
          as CohortRetentionPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CohortRetentionPoint create() => CohortRetentionPoint._();
  @$core.override
  CohortRetentionPoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CohortRetentionPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CohortRetentionPoint>(create);
  static CohortRetentionPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cohort => $_getSZ(0);
  @$pb.TagNumber(1)
  set cohort($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCohort() => $_has(0);
  @$pb.TagNumber(1)
  void clearCohort() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get week => $_getSZ(1);
  @$pb.TagNumber(2)
  set week($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWeek() => $_has(1);
  @$pb.TagNumber(2)
  void clearWeek() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get pct => $_getN(2);
  @$pb.TagNumber(3)
  set pct($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPct() => $_has(2);
  @$pb.TagNumber(3)
  void clearPct() => $_clearField(3);
}

class HistogramBucket extends $pb.GeneratedMessage {
  factory HistogramBucket({
    $core.String? bucketLabel,
    $fixnum.Int64? count,
  }) {
    final result = create();
    if (bucketLabel != null) result.bucketLabel = bucketLabel;
    if (count != null) result.count = count;
    return result;
  }

  HistogramBucket._();

  factory HistogramBucket.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HistogramBucket.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HistogramBucket',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'bucketLabel')
    ..aInt64(2, _omitFieldNames ? '' : 'count')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistogramBucket clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistogramBucket copyWith(void Function(HistogramBucket) updates) =>
      super.copyWith((message) => updates(message as HistogramBucket))
          as HistogramBucket;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HistogramBucket create() => HistogramBucket._();
  @$core.override
  HistogramBucket createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HistogramBucket getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HistogramBucket>(create);
  static HistogramBucket? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get bucketLabel => $_getSZ(0);
  @$pb.TagNumber(1)
  set bucketLabel($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBucketLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearBucketLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get count => $_getI64(1);
  @$pb.TagNumber(2)
  set count($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);
}

class HourlyHeatmapPoint extends $pb.GeneratedMessage {
  factory HourlyHeatmapPoint({
    $core.int? dayOfWeek,
    $core.int? hour,
    $fixnum.Int64? count,
  }) {
    final result = create();
    if (dayOfWeek != null) result.dayOfWeek = dayOfWeek;
    if (hour != null) result.hour = hour;
    if (count != null) result.count = count;
    return result;
  }

  HourlyHeatmapPoint._();

  factory HourlyHeatmapPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HourlyHeatmapPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HourlyHeatmapPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'dayOfWeek')
    ..aI(2, _omitFieldNames ? '' : 'hour')
    ..aInt64(3, _omitFieldNames ? '' : 'count')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HourlyHeatmapPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HourlyHeatmapPoint copyWith(void Function(HourlyHeatmapPoint) updates) =>
      super.copyWith((message) => updates(message as HourlyHeatmapPoint))
          as HourlyHeatmapPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HourlyHeatmapPoint create() => HourlyHeatmapPoint._();
  @$core.override
  HourlyHeatmapPoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HourlyHeatmapPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HourlyHeatmapPoint>(create);
  static HourlyHeatmapPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get dayOfWeek => $_getIZ(0);
  @$pb.TagNumber(1)
  set dayOfWeek($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDayOfWeek() => $_has(0);
  @$pb.TagNumber(1)
  void clearDayOfWeek() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get hour => $_getIZ(1);
  @$pb.TagNumber(2)
  set hour($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHour() => $_has(1);
  @$pb.TagNumber(2)
  void clearHour() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get count => $_getI64(2);
  @$pb.TagNumber(3)
  set count($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearCount() => $_clearField(3);
}

class GetOrgAnalyticsRequest extends $pb.GeneratedMessage {
  factory GetOrgAnalyticsRequest() => create();

  GetOrgAnalyticsRequest._();

  factory GetOrgAnalyticsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetOrgAnalyticsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetOrgAnalyticsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetOrgAnalyticsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetOrgAnalyticsRequest copyWith(
          void Function(GetOrgAnalyticsRequest) updates) =>
      super.copyWith((message) => updates(message as GetOrgAnalyticsRequest))
          as GetOrgAnalyticsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetOrgAnalyticsRequest create() => GetOrgAnalyticsRequest._();
  @$core.override
  GetOrgAnalyticsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetOrgAnalyticsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetOrgAnalyticsRequest>(create);
  static GetOrgAnalyticsRequest? _defaultInstance;
}

class GetOrgAnalyticsResponse extends $pb.GeneratedMessage {
  factory GetOrgAnalyticsResponse({
    $fixnum.Int64? kpiWau,
    $fixnum.Int64? kpiSessionsThisWeek,
    $core.double? kpiAvgSessionDuration,
    $core.Iterable<TrendPoint>? sessionsTrend,
    $core.Iterable<TrendPoint>? wauTrend,
    $core.Iterable<TrendPoint>? sessionDurationTrend,
    $core.Iterable<HourlyHeatmapPoint>? hourlyHeatmap,
    $core.Iterable<TokenUtilizationHeatmapPoint>? therapistUtilization,
    $fixnum.Int64? sessionsThisMonth,
    $fixnum.Int64? sessionsThisYear,
  }) {
    final result = create();
    if (kpiWau != null) result.kpiWau = kpiWau;
    if (kpiSessionsThisWeek != null)
      result.kpiSessionsThisWeek = kpiSessionsThisWeek;
    if (kpiAvgSessionDuration != null)
      result.kpiAvgSessionDuration = kpiAvgSessionDuration;
    if (sessionsTrend != null) result.sessionsTrend.addAll(sessionsTrend);
    if (wauTrend != null) result.wauTrend.addAll(wauTrend);
    if (sessionDurationTrend != null)
      result.sessionDurationTrend.addAll(sessionDurationTrend);
    if (hourlyHeatmap != null) result.hourlyHeatmap.addAll(hourlyHeatmap);
    if (therapistUtilization != null)
      result.therapistUtilization.addAll(therapistUtilization);
    if (sessionsThisMonth != null) result.sessionsThisMonth = sessionsThisMonth;
    if (sessionsThisYear != null) result.sessionsThisYear = sessionsThisYear;
    return result;
  }

  GetOrgAnalyticsResponse._();

  factory GetOrgAnalyticsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetOrgAnalyticsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetOrgAnalyticsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'kpiWau')
    ..aInt64(2, _omitFieldNames ? '' : 'kpiSessionsThisWeek')
    ..aD(3, _omitFieldNames ? '' : 'kpiAvgSessionDuration')
    ..pPM<TrendPoint>(4, _omitFieldNames ? '' : 'sessionsTrend',
        subBuilder: TrendPoint.create)
    ..pPM<TrendPoint>(5, _omitFieldNames ? '' : 'wauTrend',
        subBuilder: TrendPoint.create)
    ..pPM<TrendPoint>(6, _omitFieldNames ? '' : 'sessionDurationTrend',
        subBuilder: TrendPoint.create)
    ..pPM<HourlyHeatmapPoint>(7, _omitFieldNames ? '' : 'hourlyHeatmap',
        subBuilder: HourlyHeatmapPoint.create)
    ..pPM<TokenUtilizationHeatmapPoint>(
        8, _omitFieldNames ? '' : 'therapistUtilization',
        subBuilder: TokenUtilizationHeatmapPoint.create)
    ..aInt64(9, _omitFieldNames ? '' : 'sessionsThisMonth')
    ..aInt64(10, _omitFieldNames ? '' : 'sessionsThisYear')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetOrgAnalyticsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetOrgAnalyticsResponse copyWith(
          void Function(GetOrgAnalyticsResponse) updates) =>
      super.copyWith((message) => updates(message as GetOrgAnalyticsResponse))
          as GetOrgAnalyticsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetOrgAnalyticsResponse create() => GetOrgAnalyticsResponse._();
  @$core.override
  GetOrgAnalyticsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetOrgAnalyticsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetOrgAnalyticsResponse>(create);
  static GetOrgAnalyticsResponse? _defaultInstance;

  /// KPI strip
  @$pb.TagNumber(1)
  $fixnum.Int64 get kpiWau => $_getI64(0);
  @$pb.TagNumber(1)
  set kpiWau($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKpiWau() => $_has(0);
  @$pb.TagNumber(1)
  void clearKpiWau() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get kpiSessionsThisWeek => $_getI64(1);
  @$pb.TagNumber(2)
  set kpiSessionsThisWeek($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKpiSessionsThisWeek() => $_has(1);
  @$pb.TagNumber(2)
  void clearKpiSessionsThisWeek() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get kpiAvgSessionDuration => $_getN(2);
  @$pb.TagNumber(3)
  set kpiAvgSessionDuration($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKpiAvgSessionDuration() => $_has(2);
  @$pb.TagNumber(3)
  void clearKpiAvgSessionDuration() => $_clearField(3);

  /// Weekly trends (last ~9 ISO weeks, label "IYYY-IW")
  @$pb.TagNumber(4)
  $pb.PbList<TrendPoint> get sessionsTrend => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<TrendPoint> get wauTrend => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<TrendPoint> get sessionDurationTrend => $_getList(5);

  /// Day × hour recording heatmap (last 90d)
  @$pb.TagNumber(7)
  $pb.PbList<HourlyHeatmapPoint> get hourlyHeatmap => $_getList(6);

  /// Token utilization per THERAPIST per counter period — same shape as
  /// the admin org-level heatmap (org_name carries the therapist name).
  @$pb.TagNumber(8)
  $pb.PbList<TokenUtilizationHeatmapPoint> get therapistUtilization =>
      $_getList(7);

  /// "Czas zaoszczędzony na raportowaniu": sessions × 20 min, computed
  /// client-side from these calendar-window counts.
  @$pb.TagNumber(9)
  $fixnum.Int64 get sessionsThisMonth => $_getI64(8);
  @$pb.TagNumber(9)
  set sessionsThisMonth($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSessionsThisMonth() => $_has(8);
  @$pb.TagNumber(9)
  void clearSessionsThisMonth() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get sessionsThisYear => $_getI64(9);
  @$pb.TagNumber(10)
  set sessionsThisYear($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSessionsThisYear() => $_has(9);
  @$pb.TagNumber(10)
  void clearSessionsThisYear() => $_clearField(10);
}

class ExportPatientDataRequest extends $pb.GeneratedMessage {
  factory ExportPatientDataRequest({
    $core.String? patientFileId,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    return result;
  }

  ExportPatientDataRequest._();

  factory ExportPatientDataRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportPatientDataRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportPatientDataRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportPatientDataRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportPatientDataRequest copyWith(
          void Function(ExportPatientDataRequest) updates) =>
      super.copyWith((message) => updates(message as ExportPatientDataRequest))
          as ExportPatientDataRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportPatientDataRequest create() => ExportPatientDataRequest._();
  @$core.override
  ExportPatientDataRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportPatientDataRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportPatientDataRequest>(create);
  static ExportPatientDataRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);
}

class DecryptedReport extends $pb.GeneratedMessage {
  factory DecryptedReport({
    $core.String? id,
    $core.String? title,
    $core.String? summaryShort,
    $core.String? content,
    $core.String? sentimentLabel,
    $core.String? riskLevel,
    $3.Timestamp? createdAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (summaryShort != null) result.summaryShort = summaryShort;
    if (content != null) result.content = content;
    if (sentimentLabel != null) result.sentimentLabel = sentimentLabel;
    if (riskLevel != null) result.riskLevel = riskLevel;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  DecryptedReport._();

  factory DecryptedReport.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DecryptedReport.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DecryptedReport',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'summaryShort')
    ..aOS(4, _omitFieldNames ? '' : 'content')
    ..aOS(5, _omitFieldNames ? '' : 'sentimentLabel')
    ..aOS(6, _omitFieldNames ? '' : 'riskLevel')
    ..aOM<$3.Timestamp>(7, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $3.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecryptedReport clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecryptedReport copyWith(void Function(DecryptedReport) updates) =>
      super.copyWith((message) => updates(message as DecryptedReport))
          as DecryptedReport;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DecryptedReport create() => DecryptedReport._();
  @$core.override
  DecryptedReport createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DecryptedReport getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DecryptedReport>(create);
  static DecryptedReport? _defaultInstance;

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

  @$pb.TagNumber(7)
  $3.Timestamp get createdAt => $_getN(6);
  @$pb.TagNumber(7)
  set createdAt($3.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCreatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreatedAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $3.Timestamp ensureCreatedAt() => $_ensure(6);
}

class DecryptedSessionSegment extends $pb.GeneratedMessage {
  factory DecryptedSessionSegment({
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

  DecryptedSessionSegment._();

  factory DecryptedSessionSegment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DecryptedSessionSegment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DecryptedSessionSegment',
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
  DecryptedSessionSegment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecryptedSessionSegment copyWith(
          void Function(DecryptedSessionSegment) updates) =>
      super.copyWith((message) => updates(message as DecryptedSessionSegment))
          as DecryptedSessionSegment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DecryptedSessionSegment create() => DecryptedSessionSegment._();
  @$core.override
  DecryptedSessionSegment createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DecryptedSessionSegment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DecryptedSessionSegment>(create);
  static DecryptedSessionSegment? _defaultInstance;

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

class DecryptedSessionTurn extends $pb.GeneratedMessage {
  factory DecryptedSessionTurn({
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

  DecryptedSessionTurn._();

  factory DecryptedSessionTurn.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DecryptedSessionTurn.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DecryptedSessionTurn',
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
  DecryptedSessionTurn clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecryptedSessionTurn copyWith(void Function(DecryptedSessionTurn) updates) =>
      super.copyWith((message) => updates(message as DecryptedSessionTurn))
          as DecryptedSessionTurn;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DecryptedSessionTurn create() => DecryptedSessionTurn._();
  @$core.override
  DecryptedSessionTurn createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DecryptedSessionTurn getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DecryptedSessionTurn>(create);
  static DecryptedSessionTurn? _defaultInstance;

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

class DecryptedSessionTranscript extends $pb.GeneratedMessage {
  factory DecryptedSessionTranscript({
    $core.String? id,
    $core.Iterable<DecryptedSessionSegment>? segments,
    $core.Iterable<DecryptedSessionTurn>? turns,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (segments != null) result.segments.addAll(segments);
    if (turns != null) result.turns.addAll(turns);
    return result;
  }

  DecryptedSessionTranscript._();

  factory DecryptedSessionTranscript.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DecryptedSessionTranscript.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DecryptedSessionTranscript',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..pPM<DecryptedSessionSegment>(2, _omitFieldNames ? '' : 'segments',
        subBuilder: DecryptedSessionSegment.create)
    ..pPM<DecryptedSessionTurn>(3, _omitFieldNames ? '' : 'turns',
        subBuilder: DecryptedSessionTurn.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecryptedSessionTranscript clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecryptedSessionTranscript copyWith(
          void Function(DecryptedSessionTranscript) updates) =>
      super.copyWith(
              (message) => updates(message as DecryptedSessionTranscript))
          as DecryptedSessionTranscript;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DecryptedSessionTranscript create() => DecryptedSessionTranscript._();
  @$core.override
  DecryptedSessionTranscript createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DecryptedSessionTranscript getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DecryptedSessionTranscript>(create);
  static DecryptedSessionTranscript? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<DecryptedSessionSegment> get segments => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<DecryptedSessionTurn> get turns => $_getList(2);
}

class DecryptedSession extends $pb.GeneratedMessage {
  factory DecryptedSession({
    $core.String? id,
    $core.String? name,
    $core.String? sessionDate,
    $core.int? sessionNumber,
    $core.int? durationSeconds,
    $core.String? status,
    $3.Timestamp? createdAt,
    DecryptedSessionTranscript? transcript,
    $core.Iterable<DecryptedReport>? reports,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (sessionDate != null) result.sessionDate = sessionDate;
    if (sessionNumber != null) result.sessionNumber = sessionNumber;
    if (durationSeconds != null) result.durationSeconds = durationSeconds;
    if (status != null) result.status = status;
    if (createdAt != null) result.createdAt = createdAt;
    if (transcript != null) result.transcript = transcript;
    if (reports != null) result.reports.addAll(reports);
    return result;
  }

  DecryptedSession._();

  factory DecryptedSession.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DecryptedSession.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DecryptedSession',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'sessionDate')
    ..aI(4, _omitFieldNames ? '' : 'sessionNumber')
    ..aI(5, _omitFieldNames ? '' : 'durationSeconds')
    ..aOS(6, _omitFieldNames ? '' : 'status')
    ..aOM<$3.Timestamp>(7, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $3.Timestamp.create)
    ..aOM<DecryptedSessionTranscript>(8, _omitFieldNames ? '' : 'transcript',
        subBuilder: DecryptedSessionTranscript.create)
    ..pPM<DecryptedReport>(9, _omitFieldNames ? '' : 'reports',
        subBuilder: DecryptedReport.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecryptedSession clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecryptedSession copyWith(void Function(DecryptedSession) updates) =>
      super.copyWith((message) => updates(message as DecryptedSession))
          as DecryptedSession;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DecryptedSession create() => DecryptedSession._();
  @$core.override
  DecryptedSession createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DecryptedSession getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DecryptedSession>(create);
  static DecryptedSession? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get sessionDate => $_getSZ(2);
  @$pb.TagNumber(3)
  set sessionDate($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSessionDate() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionDate() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get sessionNumber => $_getIZ(3);
  @$pb.TagNumber(4)
  set sessionNumber($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSessionNumber() => $_has(3);
  @$pb.TagNumber(4)
  void clearSessionNumber() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get durationSeconds => $_getIZ(4);
  @$pb.TagNumber(5)
  set durationSeconds($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDurationSeconds() => $_has(4);
  @$pb.TagNumber(5)
  void clearDurationSeconds() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get status => $_getSZ(5);
  @$pb.TagNumber(6)
  set status($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);

  @$pb.TagNumber(7)
  $3.Timestamp get createdAt => $_getN(6);
  @$pb.TagNumber(7)
  set createdAt($3.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCreatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreatedAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $3.Timestamp ensureCreatedAt() => $_ensure(6);

  @$pb.TagNumber(8)
  DecryptedSessionTranscript get transcript => $_getN(7);
  @$pb.TagNumber(8)
  set transcript(DecryptedSessionTranscript value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasTranscript() => $_has(7);
  @$pb.TagNumber(8)
  void clearTranscript() => $_clearField(8);
  @$pb.TagNumber(8)
  DecryptedSessionTranscript ensureTranscript() => $_ensure(7);

  @$pb.TagNumber(9)
  $pb.PbList<DecryptedReport> get reports => $_getList(8);
}

class DecryptedPatientNote extends $pb.GeneratedMessage {
  factory DecryptedPatientNote({
    $core.String? id,
    $core.String? kind,
    $core.String? title,
    $core.String? text,
    $3.Timestamp? sentToPatientAt,
    $core.String? sentToEmail,
    $3.Timestamp? createdAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (kind != null) result.kind = kind;
    if (title != null) result.title = title;
    if (text != null) result.text = text;
    if (sentToPatientAt != null) result.sentToPatientAt = sentToPatientAt;
    if (sentToEmail != null) result.sentToEmail = sentToEmail;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  DecryptedPatientNote._();

  factory DecryptedPatientNote.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DecryptedPatientNote.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DecryptedPatientNote',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'kind')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'text')
    ..aOM<$3.Timestamp>(5, _omitFieldNames ? '' : 'sentToPatientAt',
        subBuilder: $3.Timestamp.create)
    ..aOS(6, _omitFieldNames ? '' : 'sentToEmail')
    ..aOM<$3.Timestamp>(7, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $3.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecryptedPatientNote clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecryptedPatientNote copyWith(void Function(DecryptedPatientNote) updates) =>
      super.copyWith((message) => updates(message as DecryptedPatientNote))
          as DecryptedPatientNote;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DecryptedPatientNote create() => DecryptedPatientNote._();
  @$core.override
  DecryptedPatientNote createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DecryptedPatientNote getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DecryptedPatientNote>(create);
  static DecryptedPatientNote? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get kind => $_getSZ(1);
  @$pb.TagNumber(2)
  set kind($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

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
  $3.Timestamp get sentToPatientAt => $_getN(4);
  @$pb.TagNumber(5)
  set sentToPatientAt($3.Timestamp value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasSentToPatientAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearSentToPatientAt() => $_clearField(5);
  @$pb.TagNumber(5)
  $3.Timestamp ensureSentToPatientAt() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get sentToEmail => $_getSZ(5);
  @$pb.TagNumber(6)
  set sentToEmail($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSentToEmail() => $_has(5);
  @$pb.TagNumber(6)
  void clearSentToEmail() => $_clearField(6);

  @$pb.TagNumber(7)
  $3.Timestamp get createdAt => $_getN(6);
  @$pb.TagNumber(7)
  set createdAt($3.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCreatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreatedAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $3.Timestamp ensureCreatedAt() => $_ensure(6);
}

class ExportPatientDataResponse extends $pb.GeneratedMessage {
  factory ExportPatientDataResponse({
    PatientFile? patientFile,
    $core.Iterable<DecryptedPatientNote>? notes,
    $core.Iterable<DecryptedSession>? sessions,
  }) {
    final result = create();
    if (patientFile != null) result.patientFile = patientFile;
    if (notes != null) result.notes.addAll(notes);
    if (sessions != null) result.sessions.addAll(sessions);
    return result;
  }

  ExportPatientDataResponse._();

  factory ExportPatientDataResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportPatientDataResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportPatientDataResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOM<PatientFile>(1, _omitFieldNames ? '' : 'patientFile',
        subBuilder: PatientFile.create)
    ..pPM<DecryptedPatientNote>(2, _omitFieldNames ? '' : 'notes',
        subBuilder: DecryptedPatientNote.create)
    ..pPM<DecryptedSession>(3, _omitFieldNames ? '' : 'sessions',
        subBuilder: DecryptedSession.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportPatientDataResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportPatientDataResponse copyWith(
          void Function(ExportPatientDataResponse) updates) =>
      super.copyWith((message) => updates(message as ExportPatientDataResponse))
          as ExportPatientDataResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportPatientDataResponse create() => ExportPatientDataResponse._();
  @$core.override
  ExportPatientDataResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportPatientDataResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportPatientDataResponse>(create);
  static ExportPatientDataResponse? _defaultInstance;

  @$pb.TagNumber(1)
  PatientFile get patientFile => $_getN(0);
  @$pb.TagNumber(1)
  set patientFile(PatientFile value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFile() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFile() => $_clearField(1);
  @$pb.TagNumber(1)
  PatientFile ensurePatientFile() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<DecryptedPatientNote> get notes => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<DecryptedSession> get sessions => $_getList(2);
}

class DeletePatientDataRequest extends $pb.GeneratedMessage {
  factory DeletePatientDataRequest({
    $core.String? patientFileId,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    return result;
  }

  DeletePatientDataRequest._();

  factory DeletePatientDataRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeletePatientDataRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeletePatientDataRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePatientDataRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePatientDataRequest copyWith(
          void Function(DeletePatientDataRequest) updates) =>
      super.copyWith((message) => updates(message as DeletePatientDataRequest))
          as DeletePatientDataRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeletePatientDataRequest create() => DeletePatientDataRequest._();
  @$core.override
  DeletePatientDataRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeletePatientDataRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeletePatientDataRequest>(create);
  static DeletePatientDataRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);
}

class PlatformFixedCost extends $pb.GeneratedMessage {
  factory PlatformFixedCost({
    $core.String? id,
    $core.String? name,
    $core.String? provider,
    $core.double? amountUsd,
    $core.String? billingPeriod,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (provider != null) result.provider = provider;
    if (amountUsd != null) result.amountUsd = amountUsd;
    if (billingPeriod != null) result.billingPeriod = billingPeriod;
    return result;
  }

  PlatformFixedCost._();

  factory PlatformFixedCost.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlatformFixedCost.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlatformFixedCost',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'provider')
    ..aD(4, _omitFieldNames ? '' : 'amountUsd')
    ..aOS(5, _omitFieldNames ? '' : 'billingPeriod')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlatformFixedCost clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlatformFixedCost copyWith(void Function(PlatformFixedCost) updates) =>
      super.copyWith((message) => updates(message as PlatformFixedCost))
          as PlatformFixedCost;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlatformFixedCost create() => PlatformFixedCost._();
  @$core.override
  PlatformFixedCost createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlatformFixedCost getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlatformFixedCost>(create);
  static PlatformFixedCost? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get provider => $_getSZ(2);
  @$pb.TagNumber(3)
  set provider($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProvider() => $_has(2);
  @$pb.TagNumber(3)
  void clearProvider() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get amountUsd => $_getN(3);
  @$pb.TagNumber(4)
  set amountUsd($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAmountUsd() => $_has(3);
  @$pb.TagNumber(4)
  void clearAmountUsd() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get billingPeriod => $_getSZ(4);
  @$pb.TagNumber(5)
  set billingPeriod($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBillingPeriod() => $_has(4);
  @$pb.TagNumber(5)
  void clearBillingPeriod() => $_clearField(5);
}

class ClientKartoteka extends $pb.GeneratedMessage {
  factory ClientKartoteka({
    $core.String? patientFileId,
    $core.String? therapistName,
    $core.String? organizationName,
    $core.int? sharedSessions,
    $core.int? sharedNotes,
    $core.int? unreadNotes,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (therapistName != null) result.therapistName = therapistName;
    if (organizationName != null) result.organizationName = organizationName;
    if (sharedSessions != null) result.sharedSessions = sharedSessions;
    if (sharedNotes != null) result.sharedNotes = sharedNotes;
    if (unreadNotes != null) result.unreadNotes = unreadNotes;
    return result;
  }

  ClientKartoteka._();

  factory ClientKartoteka.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientKartoteka.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientKartoteka',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..aOS(2, _omitFieldNames ? '' : 'therapistName')
    ..aOS(3, _omitFieldNames ? '' : 'organizationName')
    ..aI(4, _omitFieldNames ? '' : 'sharedSessions')
    ..aI(5, _omitFieldNames ? '' : 'sharedNotes')
    ..aI(6, _omitFieldNames ? '' : 'unreadNotes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientKartoteka clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientKartoteka copyWith(void Function(ClientKartoteka) updates) =>
      super.copyWith((message) => updates(message as ClientKartoteka))
          as ClientKartoteka;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientKartoteka create() => ClientKartoteka._();
  @$core.override
  ClientKartoteka createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientKartoteka getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientKartoteka>(create);
  static ClientKartoteka? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get therapistName => $_getSZ(1);
  @$pb.TagNumber(2)
  set therapistName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTherapistName() => $_has(1);
  @$pb.TagNumber(2)
  void clearTherapistName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get organizationName => $_getSZ(2);
  @$pb.TagNumber(3)
  set organizationName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOrganizationName() => $_has(2);
  @$pb.TagNumber(3)
  void clearOrganizationName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get sharedSessions => $_getIZ(3);
  @$pb.TagNumber(4)
  set sharedSessions($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSharedSessions() => $_has(3);
  @$pb.TagNumber(4)
  void clearSharedSessions() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get sharedNotes => $_getIZ(4);
  @$pb.TagNumber(5)
  set sharedNotes($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSharedNotes() => $_has(4);
  @$pb.TagNumber(5)
  void clearSharedNotes() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get unreadNotes => $_getIZ(5);
  @$pb.TagNumber(6)
  set unreadNotes($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUnreadNotes() => $_has(5);
  @$pb.TagNumber(6)
  void clearUnreadNotes() => $_clearField(6);
}

class ClientOverview extends $pb.GeneratedMessage {
  factory ClientOverview({
    $core.Iterable<ClientKartoteka>? kartoteki,
  }) {
    final result = create();
    if (kartoteki != null) result.kartoteki.addAll(kartoteki);
    return result;
  }

  ClientOverview._();

  factory ClientOverview.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientOverview.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientOverview',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<ClientKartoteka>(1, _omitFieldNames ? '' : 'kartoteki',
        subBuilder: ClientKartoteka.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientOverview clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientOverview copyWith(void Function(ClientOverview) updates) =>
      super.copyWith((message) => updates(message as ClientOverview))
          as ClientOverview;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientOverview create() => ClientOverview._();
  @$core.override
  ClientOverview createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientOverview getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientOverview>(create);
  static ClientOverview? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ClientKartoteka> get kartoteki => $_getList(0);
}

class ClientListSessionsRequest extends $pb.GeneratedMessage {
  factory ClientListSessionsRequest({
    $core.String? patientFileId,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    return result;
  }

  ClientListSessionsRequest._();

  factory ClientListSessionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientListSessionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientListSessionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientListSessionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientListSessionsRequest copyWith(
          void Function(ClientListSessionsRequest) updates) =>
      super.copyWith((message) => updates(message as ClientListSessionsRequest))
          as ClientListSessionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientListSessionsRequest create() => ClientListSessionsRequest._();
  @$core.override
  ClientListSessionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientListSessionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientListSessionsRequest>(create);
  static ClientListSessionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);
}

class ClientSessionInfo extends $pb.GeneratedMessage {
  factory ClientSessionInfo({
    $core.String? sessionId,
    $core.String? sessionDate,
    $core.int? sessionNumber,
    $core.int? durationSeconds,
    $3.Timestamp? sharedAt,
    $core.bool? hasTranscript,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (sessionDate != null) result.sessionDate = sessionDate;
    if (sessionNumber != null) result.sessionNumber = sessionNumber;
    if (durationSeconds != null) result.durationSeconds = durationSeconds;
    if (sharedAt != null) result.sharedAt = sharedAt;
    if (hasTranscript != null) result.hasTranscript = hasTranscript;
    return result;
  }

  ClientSessionInfo._();

  factory ClientSessionInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientSessionInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientSessionInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'sessionDate')
    ..aI(3, _omitFieldNames ? '' : 'sessionNumber')
    ..aI(4, _omitFieldNames ? '' : 'durationSeconds')
    ..aOM<$3.Timestamp>(5, _omitFieldNames ? '' : 'sharedAt',
        subBuilder: $3.Timestamp.create)
    ..aOB(6, _omitFieldNames ? '' : 'hasTranscript')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientSessionInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientSessionInfo copyWith(void Function(ClientSessionInfo) updates) =>
      super.copyWith((message) => updates(message as ClientSessionInfo))
          as ClientSessionInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientSessionInfo create() => ClientSessionInfo._();
  @$core.override
  ClientSessionInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientSessionInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientSessionInfo>(create);
  static ClientSessionInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionDate => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionDate($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionDate() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionDate() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get sessionNumber => $_getIZ(2);
  @$pb.TagNumber(3)
  set sessionNumber($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSessionNumber() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionNumber() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get durationSeconds => $_getIZ(3);
  @$pb.TagNumber(4)
  set durationSeconds($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDurationSeconds() => $_has(3);
  @$pb.TagNumber(4)
  void clearDurationSeconds() => $_clearField(4);

  @$pb.TagNumber(5)
  $3.Timestamp get sharedAt => $_getN(4);
  @$pb.TagNumber(5)
  set sharedAt($3.Timestamp value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasSharedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearSharedAt() => $_clearField(5);
  @$pb.TagNumber(5)
  $3.Timestamp ensureSharedAt() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.bool get hasTranscript => $_getBF(5);
  @$pb.TagNumber(6)
  set hasTranscript($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHasTranscript() => $_has(5);
  @$pb.TagNumber(6)
  void clearHasTranscript() => $_clearField(6);
}

class ClientListSessionsResponse extends $pb.GeneratedMessage {
  factory ClientListSessionsResponse({
    $core.Iterable<ClientSessionInfo>? sessions,
  }) {
    final result = create();
    if (sessions != null) result.sessions.addAll(sessions);
    return result;
  }

  ClientListSessionsResponse._();

  factory ClientListSessionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientListSessionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientListSessionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<ClientSessionInfo>(1, _omitFieldNames ? '' : 'sessions',
        subBuilder: ClientSessionInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientListSessionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientListSessionsResponse copyWith(
          void Function(ClientListSessionsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ClientListSessionsResponse))
          as ClientListSessionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientListSessionsResponse create() => ClientListSessionsResponse._();
  @$core.override
  ClientListSessionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientListSessionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientListSessionsResponse>(create);
  static ClientListSessionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ClientSessionInfo> get sessions => $_getList(0);
}

class ClientGetTranscriptRequest extends $pb.GeneratedMessage {
  factory ClientGetTranscriptRequest({
    $core.String? sessionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  ClientGetTranscriptRequest._();

  factory ClientGetTranscriptRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientGetTranscriptRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientGetTranscriptRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientGetTranscriptRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientGetTranscriptRequest copyWith(
          void Function(ClientGetTranscriptRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ClientGetTranscriptRequest))
          as ClientGetTranscriptRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientGetTranscriptRequest create() => ClientGetTranscriptRequest._();
  @$core.override
  ClientGetTranscriptRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientGetTranscriptRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientGetTranscriptRequest>(create);
  static ClientGetTranscriptRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

class ClientGetTranscriptResponse extends $pb.GeneratedMessage {
  factory ClientGetTranscriptResponse({
    ClientSessionInfo? session,
    Transcript? transcript,
  }) {
    final result = create();
    if (session != null) result.session = session;
    if (transcript != null) result.transcript = transcript;
    return result;
  }

  ClientGetTranscriptResponse._();

  factory ClientGetTranscriptResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientGetTranscriptResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientGetTranscriptResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOM<ClientSessionInfo>(1, _omitFieldNames ? '' : 'session',
        subBuilder: ClientSessionInfo.create)
    ..aOM<Transcript>(2, _omitFieldNames ? '' : 'transcript',
        subBuilder: Transcript.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientGetTranscriptResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientGetTranscriptResponse copyWith(
          void Function(ClientGetTranscriptResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ClientGetTranscriptResponse))
          as ClientGetTranscriptResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientGetTranscriptResponse create() =>
      ClientGetTranscriptResponse._();
  @$core.override
  ClientGetTranscriptResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientGetTranscriptResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientGetTranscriptResponse>(create);
  static ClientGetTranscriptResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ClientSessionInfo get session => $_getN(0);
  @$pb.TagNumber(1)
  set session(ClientSessionInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSession() => $_has(0);
  @$pb.TagNumber(1)
  void clearSession() => $_clearField(1);
  @$pb.TagNumber(1)
  ClientSessionInfo ensureSession() => $_ensure(0);

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
}

class ClientListNotesRequest extends $pb.GeneratedMessage {
  factory ClientListNotesRequest({
    $core.String? patientFileId,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    return result;
  }

  ClientListNotesRequest._();

  factory ClientListNotesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientListNotesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientListNotesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientListNotesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientListNotesRequest copyWith(
          void Function(ClientListNotesRequest) updates) =>
      super.copyWith((message) => updates(message as ClientListNotesRequest))
          as ClientListNotesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientListNotesRequest create() => ClientListNotesRequest._();
  @$core.override
  ClientListNotesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientListNotesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientListNotesRequest>(create);
  static ClientListNotesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);
}

class ClientNote extends $pb.GeneratedMessage {
  factory ClientNote({
    $core.String? id,
    $core.String? kind,
    $core.String? title,
    $core.String? text,
    $core.String? authorRole,
    $3.Timestamp? createdAt,
    $3.Timestamp? sharedAt,
    $core.bool? read,
    $3.Timestamp? sentToTherapistAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (kind != null) result.kind = kind;
    if (title != null) result.title = title;
    if (text != null) result.text = text;
    if (authorRole != null) result.authorRole = authorRole;
    if (createdAt != null) result.createdAt = createdAt;
    if (sharedAt != null) result.sharedAt = sharedAt;
    if (read != null) result.read = read;
    if (sentToTherapistAt != null) result.sentToTherapistAt = sentToTherapistAt;
    return result;
  }

  ClientNote._();

  factory ClientNote.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientNote.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientNote',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'kind')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'text')
    ..aOS(5, _omitFieldNames ? '' : 'authorRole')
    ..aOM<$3.Timestamp>(6, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $3.Timestamp.create)
    ..aOM<$3.Timestamp>(7, _omitFieldNames ? '' : 'sharedAt',
        subBuilder: $3.Timestamp.create)
    ..aOB(8, _omitFieldNames ? '' : 'read')
    ..aOM<$3.Timestamp>(9, _omitFieldNames ? '' : 'sentToTherapistAt',
        subBuilder: $3.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientNote clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientNote copyWith(void Function(ClientNote) updates) =>
      super.copyWith((message) => updates(message as ClientNote)) as ClientNote;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientNote create() => ClientNote._();
  @$core.override
  ClientNote createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientNote getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientNote>(create);
  static ClientNote? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get kind => $_getSZ(1);
  @$pb.TagNumber(2)
  set kind($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

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
  $core.String get authorRole => $_getSZ(4);
  @$pb.TagNumber(5)
  set authorRole($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAuthorRole() => $_has(4);
  @$pb.TagNumber(5)
  void clearAuthorRole() => $_clearField(5);

  @$pb.TagNumber(6)
  $3.Timestamp get createdAt => $_getN(5);
  @$pb.TagNumber(6)
  set createdAt($3.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => $_clearField(6);
  @$pb.TagNumber(6)
  $3.Timestamp ensureCreatedAt() => $_ensure(5);

  @$pb.TagNumber(7)
  $3.Timestamp get sharedAt => $_getN(6);
  @$pb.TagNumber(7)
  set sharedAt($3.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSharedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearSharedAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $3.Timestamp ensureSharedAt() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.bool get read => $_getBF(7);
  @$pb.TagNumber(8)
  set read($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRead() => $_has(7);
  @$pb.TagNumber(8)
  void clearRead() => $_clearField(8);

  /// Drafts (migration 000068): a CLIENT_NOTE with this unset is a
  /// PRIVATE draft — saved in the panel, invisible to the therapist —
  /// until ClientSendNote (or create with send_to_therapist) stamps it.
  @$pb.TagNumber(9)
  $3.Timestamp get sentToTherapistAt => $_getN(8);
  @$pb.TagNumber(9)
  set sentToTherapistAt($3.Timestamp value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSentToTherapistAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearSentToTherapistAt() => $_clearField(9);
  @$pb.TagNumber(9)
  $3.Timestamp ensureSentToTherapistAt() => $_ensure(8);
}

/// docs/39 PR13.
class ClientDeleteNoteRequest extends $pb.GeneratedMessage {
  factory ClientDeleteNoteRequest({
    $core.String? noteId,
  }) {
    final result = create();
    if (noteId != null) result.noteId = noteId;
    return result;
  }

  ClientDeleteNoteRequest._();

  factory ClientDeleteNoteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientDeleteNoteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientDeleteNoteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'noteId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientDeleteNoteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientDeleteNoteRequest copyWith(
          void Function(ClientDeleteNoteRequest) updates) =>
      super.copyWith((message) => updates(message as ClientDeleteNoteRequest))
          as ClientDeleteNoteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientDeleteNoteRequest create() => ClientDeleteNoteRequest._();
  @$core.override
  ClientDeleteNoteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientDeleteNoteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientDeleteNoteRequest>(create);
  static ClientDeleteNoteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get noteId => $_getSZ(0);
  @$pb.TagNumber(1)
  set noteId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNoteId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNoteId() => $_clearField(1);
}

class ClientHideItemRequest extends $pb.GeneratedMessage {
  factory ClientHideItemRequest({
    $core.String? itemKind,
    $core.String? itemId,
  }) {
    final result = create();
    if (itemKind != null) result.itemKind = itemKind;
    if (itemId != null) result.itemId = itemId;
    return result;
  }

  ClientHideItemRequest._();

  factory ClientHideItemRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientHideItemRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientHideItemRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'itemKind')
    ..aOS(2, _omitFieldNames ? '' : 'itemId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientHideItemRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientHideItemRequest copyWith(
          void Function(ClientHideItemRequest) updates) =>
      super.copyWith((message) => updates(message as ClientHideItemRequest))
          as ClientHideItemRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientHideItemRequest create() => ClientHideItemRequest._();
  @$core.override
  ClientHideItemRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientHideItemRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientHideItemRequest>(create);
  static ClientHideItemRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get itemKind => $_getSZ(0);
  @$pb.TagNumber(1)
  set itemKind($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasItemKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearItemKind() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get itemId => $_getSZ(1);
  @$pb.TagNumber(2)
  set itemId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasItemId() => $_has(1);
  @$pb.TagNumber(2)
  void clearItemId() => $_clearField(2);
}

class ClientListNotesResponse extends $pb.GeneratedMessage {
  factory ClientListNotesResponse({
    $core.Iterable<ClientNote>? notes,
  }) {
    final result = create();
    if (notes != null) result.notes.addAll(notes);
    return result;
  }

  ClientListNotesResponse._();

  factory ClientListNotesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientListNotesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientListNotesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<ClientNote>(1, _omitFieldNames ? '' : 'notes',
        subBuilder: ClientNote.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientListNotesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientListNotesResponse copyWith(
          void Function(ClientListNotesResponse) updates) =>
      super.copyWith((message) => updates(message as ClientListNotesResponse))
          as ClientListNotesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientListNotesResponse create() => ClientListNotesResponse._();
  @$core.override
  ClientListNotesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientListNotesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientListNotesResponse>(create);
  static ClientListNotesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ClientNote> get notes => $_getList(0);
}

class ClientCreateNoteRequest extends $pb.GeneratedMessage {
  factory ClientCreateNoteRequest({
    $core.String? patientFileId,
    $core.String? title,
    $core.String? text,
    $core.bool? sendToTherapist,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (title != null) result.title = title;
    if (text != null) result.text = text;
    if (sendToTherapist != null) result.sendToTherapist = sendToTherapist;
    return result;
  }

  ClientCreateNoteRequest._();

  factory ClientCreateNoteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientCreateNoteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientCreateNoteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..aOB(4, _omitFieldNames ? '' : 'sendToTherapist')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientCreateNoteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientCreateNoteRequest copyWith(
          void Function(ClientCreateNoteRequest) updates) =>
      super.copyWith((message) => updates(message as ClientCreateNoteRequest))
          as ClientCreateNoteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientCreateNoteRequest create() => ClientCreateNoteRequest._();
  @$core.override
  ClientCreateNoteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientCreateNoteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientCreateNoteRequest>(create);
  static ClientCreateNoteRequest? _defaultInstance;

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

  /// false = save as a private draft ("Zapisz"); true = deliver to the
  /// therapist immediately ("Zapisz i wyślij do terapeuty").
  @$pb.TagNumber(4)
  $core.bool get sendToTherapist => $_getBF(3);
  @$pb.TagNumber(4)
  set sendToTherapist($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSendToTherapist() => $_has(3);
  @$pb.TagNumber(4)
  void clearSendToTherapist() => $_clearField(4);
}

/// ClientSendNote — deliver a previously saved draft to the therapist.
/// Idempotent (a delivered note keeps its first sent_to_therapist_at).
class ClientSendNoteRequest extends $pb.GeneratedMessage {
  factory ClientSendNoteRequest({
    $core.String? noteId,
  }) {
    final result = create();
    if (noteId != null) result.noteId = noteId;
    return result;
  }

  ClientSendNoteRequest._();

  factory ClientSendNoteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientSendNoteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientSendNoteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'noteId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientSendNoteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientSendNoteRequest copyWith(
          void Function(ClientSendNoteRequest) updates) =>
      super.copyWith((message) => updates(message as ClientSendNoteRequest))
          as ClientSendNoteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientSendNoteRequest create() => ClientSendNoteRequest._();
  @$core.override
  ClientSendNoteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientSendNoteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientSendNoteRequest>(create);
  static ClientSendNoteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get noteId => $_getSZ(0);
  @$pb.TagNumber(1)
  set noteId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNoteId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNoteId() => $_clearField(1);
}

class ClientMarkNoteReadRequest extends $pb.GeneratedMessage {
  factory ClientMarkNoteReadRequest({
    $core.String? noteId,
  }) {
    final result = create();
    if (noteId != null) result.noteId = noteId;
    return result;
  }

  ClientMarkNoteReadRequest._();

  factory ClientMarkNoteReadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientMarkNoteReadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientMarkNoteReadRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'noteId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientMarkNoteReadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientMarkNoteReadRequest copyWith(
          void Function(ClientMarkNoteReadRequest) updates) =>
      super.copyWith((message) => updates(message as ClientMarkNoteReadRequest))
          as ClientMarkNoteReadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientMarkNoteReadRequest create() => ClientMarkNoteReadRequest._();
  @$core.override
  ClientMarkNoteReadRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientMarkNoteReadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientMarkNoteReadRequest>(create);
  static ClientMarkNoteReadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get noteId => $_getSZ(0);
  @$pb.TagNumber(1)
  set noteId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNoteId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNoteId() => $_clearField(1);
}

class ShareSessionWithClientRequest extends $pb.GeneratedMessage {
  factory ShareSessionWithClientRequest({
    $core.String? sessionId,
    $core.bool? shared,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (shared != null) result.shared = shared;
    return result;
  }

  ShareSessionWithClientRequest._();

  factory ShareSessionWithClientRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ShareSessionWithClientRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShareSessionWithClientRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOB(2, _omitFieldNames ? '' : 'shared')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareSessionWithClientRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareSessionWithClientRequest copyWith(
          void Function(ShareSessionWithClientRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ShareSessionWithClientRequest))
          as ShareSessionWithClientRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShareSessionWithClientRequest create() =>
      ShareSessionWithClientRequest._();
  @$core.override
  ShareSessionWithClientRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ShareSessionWithClientRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShareSessionWithClientRequest>(create);
  static ShareSessionWithClientRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get shared => $_getBF(1);
  @$pb.TagNumber(2)
  set shared($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasShared() => $_has(1);
  @$pb.TagNumber(2)
  void clearShared() => $_clearField(2);
}

class ShareNoteWithClientRequest extends $pb.GeneratedMessage {
  factory ShareNoteWithClientRequest({
    $core.String? noteId,
    $core.bool? shared,
  }) {
    final result = create();
    if (noteId != null) result.noteId = noteId;
    if (shared != null) result.shared = shared;
    return result;
  }

  ShareNoteWithClientRequest._();

  factory ShareNoteWithClientRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ShareNoteWithClientRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShareNoteWithClientRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'noteId')
    ..aOB(2, _omitFieldNames ? '' : 'shared')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareNoteWithClientRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareNoteWithClientRequest copyWith(
          void Function(ShareNoteWithClientRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ShareNoteWithClientRequest))
          as ShareNoteWithClientRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShareNoteWithClientRequest create() => ShareNoteWithClientRequest._();
  @$core.override
  ShareNoteWithClientRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ShareNoteWithClientRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShareNoteWithClientRequest>(create);
  static ShareNoteWithClientRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get noteId => $_getSZ(0);
  @$pb.TagNumber(1)
  set noteId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNoteId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNoteId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get shared => $_getBF(1);
  @$pb.TagNumber(2)
  set shared($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasShared() => $_has(1);
  @$pb.TagNumber(2)
  void clearShared() => $_clearField(2);
}

class GetOrgTherapistMetricsRequest extends $pb.GeneratedMessage {
  factory GetOrgTherapistMetricsRequest({
    $core.int? periodDays,
  }) {
    final result = create();
    if (periodDays != null) result.periodDays = periodDays;
    return result;
  }

  GetOrgTherapistMetricsRequest._();

  factory GetOrgTherapistMetricsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetOrgTherapistMetricsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetOrgTherapistMetricsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'periodDays')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetOrgTherapistMetricsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetOrgTherapistMetricsRequest copyWith(
          void Function(GetOrgTherapistMetricsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetOrgTherapistMetricsRequest))
          as GetOrgTherapistMetricsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetOrgTherapistMetricsRequest create() =>
      GetOrgTherapistMetricsRequest._();
  @$core.override
  GetOrgTherapistMetricsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetOrgTherapistMetricsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetOrgTherapistMetricsRequest>(create);
  static GetOrgTherapistMetricsRequest? _defaultInstance;

  /// Look-back window in days: 7 | 30 | 90 (anything else clamps to
  /// 30). Applies to sessions, new patients and report ratings;
  /// active_patients is a point-in-time count.
  @$pb.TagNumber(1)
  $core.int get periodDays => $_getIZ(0);
  @$pb.TagNumber(1)
  set periodDays($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeriodDays() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeriodDays() => $_clearField(1);
}

/// Metadata aggregates only — zero PHI (docs/38 §7.3).
class TherapistMetrics extends $pb.GeneratedMessage {
  factory TherapistMetrics({
    $core.String? therapistId,
    $core.String? firstName,
    $core.String? lastName,
    $core.bool? isActive,
    $core.int? sessionsCompleted,
    $core.int? sessionsFailed,
    $core.int? sessionsCancelled,
    $fixnum.Int64? totalDurationSeconds,
    $core.int? avgDurationSeconds,
    $core.int? sessionsReportViewed,
    $core.String? lastSessionDate,
    $core.int? activePatients,
    $core.int? newPatients,
    $core.int? ratingsPositive,
    $core.int? ratingsNegative,
  }) {
    final result = create();
    if (therapistId != null) result.therapistId = therapistId;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (isActive != null) result.isActive = isActive;
    if (sessionsCompleted != null) result.sessionsCompleted = sessionsCompleted;
    if (sessionsFailed != null) result.sessionsFailed = sessionsFailed;
    if (sessionsCancelled != null) result.sessionsCancelled = sessionsCancelled;
    if (totalDurationSeconds != null)
      result.totalDurationSeconds = totalDurationSeconds;
    if (avgDurationSeconds != null)
      result.avgDurationSeconds = avgDurationSeconds;
    if (sessionsReportViewed != null)
      result.sessionsReportViewed = sessionsReportViewed;
    if (lastSessionDate != null) result.lastSessionDate = lastSessionDate;
    if (activePatients != null) result.activePatients = activePatients;
    if (newPatients != null) result.newPatients = newPatients;
    if (ratingsPositive != null) result.ratingsPositive = ratingsPositive;
    if (ratingsNegative != null) result.ratingsNegative = ratingsNegative;
    return result;
  }

  TherapistMetrics._();

  factory TherapistMetrics.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TherapistMetrics.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TherapistMetrics',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'therapistId')
    ..aOS(2, _omitFieldNames ? '' : 'firstName')
    ..aOS(3, _omitFieldNames ? '' : 'lastName')
    ..aOB(4, _omitFieldNames ? '' : 'isActive')
    ..aI(5, _omitFieldNames ? '' : 'sessionsCompleted')
    ..aI(6, _omitFieldNames ? '' : 'sessionsFailed')
    ..aI(7, _omitFieldNames ? '' : 'sessionsCancelled')
    ..aInt64(8, _omitFieldNames ? '' : 'totalDurationSeconds')
    ..aI(9, _omitFieldNames ? '' : 'avgDurationSeconds')
    ..aI(10, _omitFieldNames ? '' : 'sessionsReportViewed')
    ..aOS(11, _omitFieldNames ? '' : 'lastSessionDate')
    ..aI(12, _omitFieldNames ? '' : 'activePatients')
    ..aI(13, _omitFieldNames ? '' : 'newPatients')
    ..aI(14, _omitFieldNames ? '' : 'ratingsPositive')
    ..aI(15, _omitFieldNames ? '' : 'ratingsNegative')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TherapistMetrics clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TherapistMetrics copyWith(void Function(TherapistMetrics) updates) =>
      super.copyWith((message) => updates(message as TherapistMetrics))
          as TherapistMetrics;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TherapistMetrics create() => TherapistMetrics._();
  @$core.override
  TherapistMetrics createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TherapistMetrics getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TherapistMetrics>(create);
  static TherapistMetrics? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get therapistId => $_getSZ(0);
  @$pb.TagNumber(1)
  set therapistId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTherapistId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTherapistId() => $_clearField(1);

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
  $core.bool get isActive => $_getBF(3);
  @$pb.TagNumber(4)
  set isActive($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsActive() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsActive() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get sessionsCompleted => $_getIZ(4);
  @$pb.TagNumber(5)
  set sessionsCompleted($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSessionsCompleted() => $_has(4);
  @$pb.TagNumber(5)
  void clearSessionsCompleted() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get sessionsFailed => $_getIZ(5);
  @$pb.TagNumber(6)
  set sessionsFailed($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSessionsFailed() => $_has(5);
  @$pb.TagNumber(6)
  void clearSessionsFailed() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get sessionsCancelled => $_getIZ(6);
  @$pb.TagNumber(7)
  set sessionsCancelled($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSessionsCancelled() => $_has(6);
  @$pb.TagNumber(7)
  void clearSessionsCancelled() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get totalDurationSeconds => $_getI64(7);
  @$pb.TagNumber(8)
  set totalDurationSeconds($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTotalDurationSeconds() => $_has(7);
  @$pb.TagNumber(8)
  void clearTotalDurationSeconds() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get avgDurationSeconds => $_getIZ(8);
  @$pb.TagNumber(9)
  set avgDurationSeconds($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAvgDurationSeconds() => $_has(8);
  @$pb.TagNumber(9)
  void clearAvgDurationSeconds() => $_clearField(9);

  /// Sessions whose report the therapist actually opened.
  @$pb.TagNumber(10)
  $core.int get sessionsReportViewed => $_getIZ(9);
  @$pb.TagNumber(10)
  set sessionsReportViewed($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSessionsReportViewed() => $_has(9);
  @$pb.TagNumber(10)
  void clearSessionsReportViewed() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get lastSessionDate => $_getSZ(10);
  @$pb.TagNumber(11)
  set lastSessionDate($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasLastSessionDate() => $_has(10);
  @$pb.TagNumber(11)
  void clearLastSessionDate() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get activePatients => $_getIZ(11);
  @$pb.TagNumber(12)
  set activePatients($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasActivePatients() => $_has(11);
  @$pb.TagNumber(12)
  void clearActivePatients() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get newPatients => $_getIZ(12);
  @$pb.TagNumber(13)
  set newPatients($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasNewPatients() => $_has(12);
  @$pb.TagNumber(13)
  void clearNewPatients() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get ratingsPositive => $_getIZ(13);
  @$pb.TagNumber(14)
  set ratingsPositive($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasRatingsPositive() => $_has(13);
  @$pb.TagNumber(14)
  void clearRatingsPositive() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get ratingsNegative => $_getIZ(14);
  @$pb.TagNumber(15)
  set ratingsNegative($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasRatingsNegative() => $_has(14);
  @$pb.TagNumber(15)
  void clearRatingsNegative() => $_clearField(15);
}

class OrgTherapistMetricsResponse extends $pb.GeneratedMessage {
  factory OrgTherapistMetricsResponse({
    $core.Iterable<TherapistMetrics>? therapists,
    TherapistMetrics? totals,
    $core.int? periodDays,
  }) {
    final result = create();
    if (therapists != null) result.therapists.addAll(therapists);
    if (totals != null) result.totals = totals;
    if (periodDays != null) result.periodDays = periodDays;
    return result;
  }

  OrgTherapistMetricsResponse._();

  factory OrgTherapistMetricsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OrgTherapistMetricsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OrgTherapistMetricsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<TherapistMetrics>(1, _omitFieldNames ? '' : 'therapists',
        subBuilder: TherapistMetrics.create)
    ..aOM<TherapistMetrics>(2, _omitFieldNames ? '' : 'totals',
        subBuilder: TherapistMetrics.create)
    ..aI(3, _omitFieldNames ? '' : 'periodDays')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OrgTherapistMetricsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OrgTherapistMetricsResponse copyWith(
          void Function(OrgTherapistMetricsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as OrgTherapistMetricsResponse))
          as OrgTherapistMetricsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OrgTherapistMetricsResponse create() =>
      OrgTherapistMetricsResponse._();
  @$core.override
  OrgTherapistMetricsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OrgTherapistMetricsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OrgTherapistMetricsResponse>(create);
  static OrgTherapistMetricsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TherapistMetrics> get therapists => $_getList(0);

  /// Column sums over `therapists` (avg fields re-averaged).
  @$pb.TagNumber(2)
  TherapistMetrics get totals => $_getN(1);
  @$pb.TagNumber(2)
  set totals(TherapistMetrics value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTotals() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotals() => $_clearField(2);
  @$pb.TagNumber(2)
  TherapistMetrics ensureTotals() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.int get periodDays => $_getIZ(2);
  @$pb.TagNumber(3)
  set periodDays($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPeriodDays() => $_has(2);
  @$pb.TagNumber(3)
  void clearPeriodDays() => $_clearField(3);
}

class AdminListReportRatingsRequest extends $pb.GeneratedMessage {
  factory AdminListReportRatingsRequest({
    $core.int? pageSize,
    $core.int? page,
    $core.String? ratingFilter,
    $core.String? statusFilter,
    $core.String? search,
  }) {
    final result = create();
    if (pageSize != null) result.pageSize = pageSize;
    if (page != null) result.page = page;
    if (ratingFilter != null) result.ratingFilter = ratingFilter;
    if (statusFilter != null) result.statusFilter = statusFilter;
    if (search != null) result.search = search;
    return result;
  }

  AdminListReportRatingsRequest._();

  factory AdminListReportRatingsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListReportRatingsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListReportRatingsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'pageSize')
    ..aI(2, _omitFieldNames ? '' : 'page')
    ..aOS(3, _omitFieldNames ? '' : 'ratingFilter')
    ..aOS(4, _omitFieldNames ? '' : 'statusFilter')
    ..aOS(5, _omitFieldNames ? '' : 'search')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListReportRatingsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListReportRatingsRequest copyWith(
          void Function(AdminListReportRatingsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminListReportRatingsRequest))
          as AdminListReportRatingsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListReportRatingsRequest create() =>
      AdminListReportRatingsRequest._();
  @$core.override
  AdminListReportRatingsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListReportRatingsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListReportRatingsRequest>(create);
  static AdminListReportRatingsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get pageSize => $_getIZ(0);
  @$pb.TagNumber(1)
  set pageSize($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPageSize() => $_has(0);
  @$pb.TagNumber(1)
  void clearPageSize() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get page => $_getIZ(1);
  @$pb.TagNumber(2)
  set page($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPage() => $_has(1);
  @$pb.TagNumber(2)
  void clearPage() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get ratingFilter => $_getSZ(2);
  @$pb.TagNumber(3)
  set ratingFilter($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRatingFilter() => $_has(2);
  @$pb.TagNumber(3)
  void clearRatingFilter() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get statusFilter => $_getSZ(3);
  @$pb.TagNumber(4)
  set statusFilter($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatusFilter() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatusFilter() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get search => $_getSZ(4);
  @$pb.TagNumber(5)
  set search($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSearch() => $_has(4);
  @$pb.TagNumber(5)
  void clearSearch() => $_clearField(5);
}

class AdminReportRatingRow extends $pb.GeneratedMessage {
  factory AdminReportRatingRow({
    $core.String? id,
    $core.String? reportId,
    $core.String? therapistId,
    $core.String? therapistName,
    $core.String? therapistEmail,
    $core.String? rating,
    $core.Iterable<$core.String>? issues,
    $core.String? notes,
    $core.String? source,
    $core.String? adminReviewStatus,
    $3.Timestamp? createdAt,
    $3.Timestamp? updatedAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (reportId != null) result.reportId = reportId;
    if (therapistId != null) result.therapistId = therapistId;
    if (therapistName != null) result.therapistName = therapistName;
    if (therapistEmail != null) result.therapistEmail = therapistEmail;
    if (rating != null) result.rating = rating;
    if (issues != null) result.issues.addAll(issues);
    if (notes != null) result.notes = notes;
    if (source != null) result.source = source;
    if (adminReviewStatus != null) result.adminReviewStatus = adminReviewStatus;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  AdminReportRatingRow._();

  factory AdminReportRatingRow.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminReportRatingRow.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminReportRatingRow',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'reportId')
    ..aOS(3, _omitFieldNames ? '' : 'therapistId')
    ..aOS(4, _omitFieldNames ? '' : 'therapistName')
    ..aOS(5, _omitFieldNames ? '' : 'therapistEmail')
    ..aOS(6, _omitFieldNames ? '' : 'rating')
    ..pPS(7, _omitFieldNames ? '' : 'issues')
    ..aOS(8, _omitFieldNames ? '' : 'notes')
    ..aOS(9, _omitFieldNames ? '' : 'source')
    ..aOS(10, _omitFieldNames ? '' : 'adminReviewStatus')
    ..aOM<$3.Timestamp>(11, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $3.Timestamp.create)
    ..aOM<$3.Timestamp>(12, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $3.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminReportRatingRow clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminReportRatingRow copyWith(void Function(AdminReportRatingRow) updates) =>
      super.copyWith((message) => updates(message as AdminReportRatingRow))
          as AdminReportRatingRow;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminReportRatingRow create() => AdminReportRatingRow._();
  @$core.override
  AdminReportRatingRow createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminReportRatingRow getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminReportRatingRow>(create);
  static AdminReportRatingRow? _defaultInstance;

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

  @$pb.TagNumber(4)
  $core.String get therapistName => $_getSZ(3);
  @$pb.TagNumber(4)
  set therapistName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTherapistName() => $_has(3);
  @$pb.TagNumber(4)
  void clearTherapistName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get therapistEmail => $_getSZ(4);
  @$pb.TagNumber(5)
  set therapistEmail($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTherapistEmail() => $_has(4);
  @$pb.TagNumber(5)
  void clearTherapistEmail() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get rating => $_getSZ(5);
  @$pb.TagNumber(6)
  set rating($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRating() => $_has(5);
  @$pb.TagNumber(6)
  void clearRating() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get issues => $_getList(6);

  @$pb.TagNumber(8)
  $core.String get notes => $_getSZ(7);
  @$pb.TagNumber(8)
  set notes($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasNotes() => $_has(7);
  @$pb.TagNumber(8)
  void clearNotes() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get source => $_getSZ(8);
  @$pb.TagNumber(9)
  set source($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSource() => $_has(8);
  @$pb.TagNumber(9)
  void clearSource() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get adminReviewStatus => $_getSZ(9);
  @$pb.TagNumber(10)
  set adminReviewStatus($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAdminReviewStatus() => $_has(9);
  @$pb.TagNumber(10)
  void clearAdminReviewStatus() => $_clearField(10);

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

  @$pb.TagNumber(12)
  $3.Timestamp get updatedAt => $_getN(11);
  @$pb.TagNumber(12)
  set updatedAt($3.Timestamp value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasUpdatedAt() => $_has(11);
  @$pb.TagNumber(12)
  void clearUpdatedAt() => $_clearField(12);
  @$pb.TagNumber(12)
  $3.Timestamp ensureUpdatedAt() => $_ensure(11);
}

class AdminListReportRatingsResponse extends $pb.GeneratedMessage {
  factory AdminListReportRatingsResponse({
    $core.Iterable<AdminReportRatingRow>? ratings,
    $fixnum.Int64? totalCount,
  }) {
    final result = create();
    if (ratings != null) result.ratings.addAll(ratings);
    if (totalCount != null) result.totalCount = totalCount;
    return result;
  }

  AdminListReportRatingsResponse._();

  factory AdminListReportRatingsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListReportRatingsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListReportRatingsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<AdminReportRatingRow>(1, _omitFieldNames ? '' : 'ratings',
        subBuilder: AdminReportRatingRow.create)
    ..aInt64(2, _omitFieldNames ? '' : 'totalCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListReportRatingsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListReportRatingsResponse copyWith(
          void Function(AdminListReportRatingsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as AdminListReportRatingsResponse))
          as AdminListReportRatingsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListReportRatingsResponse create() =>
      AdminListReportRatingsResponse._();
  @$core.override
  AdminListReportRatingsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListReportRatingsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListReportRatingsResponse>(create);
  static AdminListReportRatingsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AdminReportRatingRow> get ratings => $_getList(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get totalCount => $_getI64(1);
  @$pb.TagNumber(2)
  set totalCount($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalCount() => $_clearField(2);
}

class AdminSetRatingReviewStatusRequest extends $pb.GeneratedMessage {
  factory AdminSetRatingReviewStatusRequest({
    $core.String? ratingId,
    $core.String? status,
  }) {
    final result = create();
    if (ratingId != null) result.ratingId = ratingId;
    if (status != null) result.status = status;
    return result;
  }

  AdminSetRatingReviewStatusRequest._();

  factory AdminSetRatingReviewStatusRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminSetRatingReviewStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminSetRatingReviewStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'ratingId')
    ..aOS(2, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminSetRatingReviewStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminSetRatingReviewStatusRequest copyWith(
          void Function(AdminSetRatingReviewStatusRequest) updates) =>
      super.copyWith((message) =>
              updates(message as AdminSetRatingReviewStatusRequest))
          as AdminSetRatingReviewStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminSetRatingReviewStatusRequest create() =>
      AdminSetRatingReviewStatusRequest._();
  @$core.override
  AdminSetRatingReviewStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminSetRatingReviewStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminSetRatingReviewStatusRequest>(
          create);
  static AdminSetRatingReviewStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get ratingId => $_getSZ(0);
  @$pb.TagNumber(1)
  set ratingId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRatingId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRatingId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get status => $_getSZ(1);
  @$pb.TagNumber(2)
  set status($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);
}

class EditTranscriptSegmentRequest extends $pb.GeneratedMessage {
  factory EditTranscriptSegmentRequest({
    $core.String? sessionId,
    $fixnum.Int64? startOffsetMs,
    $core.String? newText,
    $core.int? newSpeakerTag,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (startOffsetMs != null) result.startOffsetMs = startOffsetMs;
    if (newText != null) result.newText = newText;
    if (newSpeakerTag != null) result.newSpeakerTag = newSpeakerTag;
    return result;
  }

  EditTranscriptSegmentRequest._();

  factory EditTranscriptSegmentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditTranscriptSegmentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditTranscriptSegmentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aInt64(2, _omitFieldNames ? '' : 'startOffsetMs')
    ..aOS(3, _omitFieldNames ? '' : 'newText')
    ..aI(4, _omitFieldNames ? '' : 'newSpeakerTag')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditTranscriptSegmentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditTranscriptSegmentRequest copyWith(
          void Function(EditTranscriptSegmentRequest) updates) =>
      super.copyWith(
              (message) => updates(message as EditTranscriptSegmentRequest))
          as EditTranscriptSegmentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditTranscriptSegmentRequest create() =>
      EditTranscriptSegmentRequest._();
  @$core.override
  EditTranscriptSegmentRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditTranscriptSegmentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditTranscriptSegmentRequest>(create);
  static EditTranscriptSegmentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get startOffsetMs => $_getI64(1);
  @$pb.TagNumber(2)
  set startOffsetMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStartOffsetMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartOffsetMs() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get newText => $_getSZ(2);
  @$pb.TagNumber(3)
  set newText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNewText() => $_has(2);
  @$pb.TagNumber(3)
  void clearNewText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get newSpeakerTag => $_getIZ(3);
  @$pb.TagNumber(4)
  set newSpeakerTag($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNewSpeakerTag() => $_has(3);
  @$pb.TagNumber(4)
  void clearNewSpeakerTag() => $_clearField(4);
}

class EditTranscriptSegmentResponse extends $pb.GeneratedMessage {
  factory EditTranscriptSegmentResponse({
    $core.String? sessionId,
    Transcript? transcript,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (transcript != null) result.transcript = transcript;
    return result;
  }

  EditTranscriptSegmentResponse._();

  factory EditTranscriptSegmentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditTranscriptSegmentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditTranscriptSegmentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOM<Transcript>(2, _omitFieldNames ? '' : 'transcript',
        subBuilder: Transcript.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditTranscriptSegmentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditTranscriptSegmentResponse copyWith(
          void Function(EditTranscriptSegmentResponse) updates) =>
      super.copyWith(
              (message) => updates(message as EditTranscriptSegmentResponse))
          as EditTranscriptSegmentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditTranscriptSegmentResponse create() =>
      EditTranscriptSegmentResponse._();
  @$core.override
  EditTranscriptSegmentResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditTranscriptSegmentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditTranscriptSegmentResponse>(create);
  static EditTranscriptSegmentResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

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
}

class SplitTranscriptSegmentRequest extends $pb.GeneratedMessage {
  factory SplitTranscriptSegmentRequest({
    $core.String? sessionId,
    $fixnum.Int64? startOffsetMs,
    $core.int? splitWordIndex,
    $core.int? secondPartSpeakerTag,
    $core.int? firstPartSpeakerTag,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (startOffsetMs != null) result.startOffsetMs = startOffsetMs;
    if (splitWordIndex != null) result.splitWordIndex = splitWordIndex;
    if (secondPartSpeakerTag != null)
      result.secondPartSpeakerTag = secondPartSpeakerTag;
    if (firstPartSpeakerTag != null)
      result.firstPartSpeakerTag = firstPartSpeakerTag;
    return result;
  }

  SplitTranscriptSegmentRequest._();

  factory SplitTranscriptSegmentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SplitTranscriptSegmentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SplitTranscriptSegmentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aInt64(2, _omitFieldNames ? '' : 'startOffsetMs')
    ..aI(3, _omitFieldNames ? '' : 'splitWordIndex')
    ..aI(4, _omitFieldNames ? '' : 'secondPartSpeakerTag')
    ..aI(5, _omitFieldNames ? '' : 'firstPartSpeakerTag')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SplitTranscriptSegmentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SplitTranscriptSegmentRequest copyWith(
          void Function(SplitTranscriptSegmentRequest) updates) =>
      super.copyWith(
              (message) => updates(message as SplitTranscriptSegmentRequest))
          as SplitTranscriptSegmentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SplitTranscriptSegmentRequest create() =>
      SplitTranscriptSegmentRequest._();
  @$core.override
  SplitTranscriptSegmentRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SplitTranscriptSegmentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SplitTranscriptSegmentRequest>(create);
  static SplitTranscriptSegmentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get startOffsetMs => $_getI64(1);
  @$pb.TagNumber(2)
  set startOffsetMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStartOffsetMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartOffsetMs() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get splitWordIndex => $_getIZ(2);
  @$pb.TagNumber(3)
  set splitWordIndex($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSplitWordIndex() => $_has(2);
  @$pb.TagNumber(3)
  void clearSplitWordIndex() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get secondPartSpeakerTag => $_getIZ(3);
  @$pb.TagNumber(4)
  set secondPartSpeakerTag($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSecondPartSpeakerTag() => $_has(3);
  @$pb.TagNumber(4)
  void clearSecondPartSpeakerTag() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get firstPartSpeakerTag => $_getIZ(4);
  @$pb.TagNumber(5)
  set firstPartSpeakerTag($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFirstPartSpeakerTag() => $_has(4);
  @$pb.TagNumber(5)
  void clearFirstPartSpeakerTag() => $_clearField(5);
}

class SplitTranscriptSegmentResponse extends $pb.GeneratedMessage {
  factory SplitTranscriptSegmentResponse({
    $core.String? sessionId,
    Transcript? transcript,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (transcript != null) result.transcript = transcript;
    return result;
  }

  SplitTranscriptSegmentResponse._();

  factory SplitTranscriptSegmentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SplitTranscriptSegmentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SplitTranscriptSegmentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOM<Transcript>(2, _omitFieldNames ? '' : 'transcript',
        subBuilder: Transcript.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SplitTranscriptSegmentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SplitTranscriptSegmentResponse copyWith(
          void Function(SplitTranscriptSegmentResponse) updates) =>
      super.copyWith(
              (message) => updates(message as SplitTranscriptSegmentResponse))
          as SplitTranscriptSegmentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SplitTranscriptSegmentResponse create() =>
      SplitTranscriptSegmentResponse._();
  @$core.override
  SplitTranscriptSegmentResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SplitTranscriptSegmentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SplitTranscriptSegmentResponse>(create);
  static SplitTranscriptSegmentResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

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
}

/// Faza 1: one-shot briefing. The server fetches RAG context, generates
/// a Gemini response, and returns it in a single unary call.
class GenerateSessionBriefRequest extends $pb.GeneratedMessage {
  factory GenerateSessionBriefRequest({
    $core.String? patientFileId,
    $core.String? focusHint,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (focusHint != null) result.focusHint = focusHint;
    return result;
  }

  GenerateSessionBriefRequest._();

  factory GenerateSessionBriefRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateSessionBriefRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateSessionBriefRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..aOS(2, _omitFieldNames ? '' : 'focusHint')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateSessionBriefRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateSessionBriefRequest copyWith(
          void Function(GenerateSessionBriefRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GenerateSessionBriefRequest))
          as GenerateSessionBriefRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateSessionBriefRequest create() =>
      GenerateSessionBriefRequest._();
  @$core.override
  GenerateSessionBriefRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateSessionBriefRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateSessionBriefRequest>(create);
  static GenerateSessionBriefRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);

  /// Optional free-text focus hint: "wzorce lękowe", "cele terapii", etc.
  /// When empty, the server uses a generic "session preparation" query.
  @$pb.TagNumber(2)
  $core.String get focusHint => $_getSZ(1);
  @$pb.TagNumber(2)
  set focusHint($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFocusHint() => $_has(1);
  @$pb.TagNumber(2)
  void clearFocusHint() => $_clearField(2);
}

class GenerateSessionBriefResponse extends $pb.GeneratedMessage {
  factory GenerateSessionBriefResponse({
    $core.String? briefMarkdown,
    $core.String? conversationId,
    $core.int? ragHitsUsed,
  }) {
    final result = create();
    if (briefMarkdown != null) result.briefMarkdown = briefMarkdown;
    if (conversationId != null) result.conversationId = conversationId;
    if (ragHitsUsed != null) result.ragHitsUsed = ragHitsUsed;
    return result;
  }

  GenerateSessionBriefResponse._();

  factory GenerateSessionBriefResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateSessionBriefResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateSessionBriefResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'briefMarkdown')
    ..aOS(2, _omitFieldNames ? '' : 'conversationId')
    ..aI(3, _omitFieldNames ? '' : 'ragHitsUsed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateSessionBriefResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateSessionBriefResponse copyWith(
          void Function(GenerateSessionBriefResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GenerateSessionBriefResponse))
          as GenerateSessionBriefResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateSessionBriefResponse create() =>
      GenerateSessionBriefResponse._();
  @$core.override
  GenerateSessionBriefResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateSessionBriefResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateSessionBriefResponse>(create);
  static GenerateSessionBriefResponse? _defaultInstance;

  /// The generated brief in markdown format.
  @$pb.TagNumber(1)
  $core.String get briefMarkdown => $_getSZ(0);
  @$pb.TagNumber(1)
  set briefMarkdown($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBriefMarkdown() => $_has(0);
  @$pb.TagNumber(1)
  void clearBriefMarkdown() => $_clearField(1);

  /// Stable conversation ID. Pass this to AskPatientQuestion to continue
  /// asking follow-up questions in the context of this brief.
  @$pb.TagNumber(2)
  $core.String get conversationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set conversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConversationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConversationId() => $_clearField(2);

  /// Number of RAG memory hits used to build context.
  @$pb.TagNumber(3)
  $core.int get ragHitsUsed => $_getIZ(2);
  @$pb.TagNumber(3)
  set ragHitsUsed($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRagHitsUsed() => $_has(2);
  @$pb.TagNumber(3)
  void clearRagHitsUsed() => $_clearField(3);
}

class AdminGetChatControlsRequest extends $pb.GeneratedMessage {
  factory AdminGetChatControlsRequest({
    $core.String? organizationId,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    return result;
  }

  AdminGetChatControlsRequest._();

  factory AdminGetChatControlsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminGetChatControlsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminGetChatControlsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetChatControlsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetChatControlsRequest copyWith(
          void Function(AdminGetChatControlsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminGetChatControlsRequest))
          as AdminGetChatControlsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminGetChatControlsRequest create() =>
      AdminGetChatControlsRequest._();
  @$core.override
  AdminGetChatControlsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminGetChatControlsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminGetChatControlsRequest>(create);
  static AdminGetChatControlsRequest? _defaultInstance;

  /// Empty = the global defaults. Set to inspect one organization's
  /// effective settings, including any override.
  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);
}

class AdminChatControls extends $pb.GeneratedMessage {
  factory AdminChatControls({
    $core.bool? enabled,
    $core.String? mode,
    $core.double? classifierTau,
    $fixnum.Int64? quotaMicroUsd,
    $core.bool? isOrgOverride,
    $core.String? note,
    $3.Timestamp? updatedAt,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (mode != null) result.mode = mode;
    if (classifierTau != null) result.classifierTau = classifierTau;
    if (quotaMicroUsd != null) result.quotaMicroUsd = quotaMicroUsd;
    if (isOrgOverride != null) result.isOrgOverride = isOrgOverride;
    if (note != null) result.note = note;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  AdminChatControls._();

  factory AdminChatControls.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminChatControls.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminChatControls',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..aOS(2, _omitFieldNames ? '' : 'mode')
    ..aD(3, _omitFieldNames ? '' : 'classifierTau')
    ..aInt64(4, _omitFieldNames ? '' : 'quotaMicroUsd')
    ..aOB(5, _omitFieldNames ? '' : 'isOrgOverride')
    ..aOS(6, _omitFieldNames ? '' : 'note')
    ..aOM<$3.Timestamp>(7, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $3.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminChatControls clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminChatControls copyWith(void Function(AdminChatControls) updates) =>
      super.copyWith((message) => updates(message as AdminChatControls))
          as AdminChatControls;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminChatControls create() => AdminChatControls._();
  @$core.override
  AdminChatControls createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminChatControls getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminChatControls>(create);
  static AdminChatControls? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  /// "full" | "defined_ops"
  @$pb.TagNumber(2)
  $core.String get mode => $_getSZ(1);
  @$pb.TagNumber(2)
  set mode($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMode() => $_has(1);
  @$pb.TagNumber(2)
  void clearMode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get classifierTau => $_getN(2);
  @$pb.TagNumber(3)
  set classifierTau($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasClassifierTau() => $_has(2);
  @$pb.TagNumber(3)
  void clearClassifierTau() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get quotaMicroUsd => $_getI64(3);
  @$pb.TagNumber(4)
  set quotaMicroUsd($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasQuotaMicroUsd() => $_has(3);
  @$pb.TagNumber(4)
  void clearQuotaMicroUsd() => $_clearField(4);

  /// True when these values come from an organization override rather
  /// than the global row.
  @$pb.TagNumber(5)
  $core.bool get isOrgOverride => $_getBF(4);
  @$pb.TagNumber(5)
  set isOrgOverride($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsOrgOverride() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsOrgOverride() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get note => $_getSZ(5);
  @$pb.TagNumber(6)
  set note($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNote() => $_has(5);
  @$pb.TagNumber(6)
  void clearNote() => $_clearField(6);

  @$pb.TagNumber(7)
  $3.Timestamp get updatedAt => $_getN(6);
  @$pb.TagNumber(7)
  set updatedAt($3.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasUpdatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearUpdatedAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $3.Timestamp ensureUpdatedAt() => $_ensure(6);
}

class AdminSetChatControlsRequest extends $pb.GeneratedMessage {
  factory AdminSetChatControlsRequest({
    $core.String? organizationId,
    $core.bool? enabled,
    $core.String? mode,
    $core.double? classifierTau,
    $fixnum.Int64? quotaMicroUsd,
    $core.String? note,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (enabled != null) result.enabled = enabled;
    if (mode != null) result.mode = mode;
    if (classifierTau != null) result.classifierTau = classifierTau;
    if (quotaMicroUsd != null) result.quotaMicroUsd = quotaMicroUsd;
    if (note != null) result.note = note;
    return result;
  }

  AdminSetChatControlsRequest._();

  factory AdminSetChatControlsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminSetChatControlsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminSetChatControlsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..aOB(2, _omitFieldNames ? '' : 'enabled')
    ..aOS(3, _omitFieldNames ? '' : 'mode')
    ..aD(4, _omitFieldNames ? '' : 'classifierTau')
    ..aInt64(5, _omitFieldNames ? '' : 'quotaMicroUsd')
    ..aOS(6, _omitFieldNames ? '' : 'note')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminSetChatControlsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminSetChatControlsRequest copyWith(
          void Function(AdminSetChatControlsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminSetChatControlsRequest))
          as AdminSetChatControlsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminSetChatControlsRequest create() =>
      AdminSetChatControlsRequest._();
  @$core.override
  AdminSetChatControlsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminSetChatControlsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminSetChatControlsRequest>(create);
  static AdminSetChatControlsRequest? _defaultInstance;

  /// Empty = change the global default; set = create or update an
  /// organization override.
  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  /// Only the fields present are changed. optional (not a default value)
  /// so "leave enabled alone while switching mode" is expressible —
  /// without it, every partial update would silently re-enable a chat
  /// someone had just switched off.
  @$pb.TagNumber(2)
  $core.bool get enabled => $_getBF(1);
  @$pb.TagNumber(2)
  set enabled($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEnabled() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnabled() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get mode => $_getSZ(2);
  @$pb.TagNumber(3)
  set mode($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMode() => $_has(2);
  @$pb.TagNumber(3)
  void clearMode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get classifierTau => $_getN(3);
  @$pb.TagNumber(4)
  set classifierTau($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasClassifierTau() => $_has(3);
  @$pb.TagNumber(4)
  void clearClassifierTau() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get quotaMicroUsd => $_getI64(4);
  @$pb.TagNumber(5)
  set quotaMicroUsd($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasQuotaMicroUsd() => $_has(4);
  @$pb.TagNumber(5)
  void clearQuotaMicroUsd() => $_clearField(5);

  /// Why. Required for any change: the note is what the next responder
  /// reads at 3am, and the audit event is worth little without it.
  @$pb.TagNumber(6)
  $core.String get note => $_getSZ(5);
  @$pb.TagNumber(6)
  set note($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNote() => $_has(5);
  @$pb.TagNumber(6)
  void clearNote() => $_clearField(6);
}

class AdminGetExperimentalControlsRequest extends $pb.GeneratedMessage {
  factory AdminGetExperimentalControlsRequest({
    $core.String? organizationId,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    return result;
  }

  AdminGetExperimentalControlsRequest._();

  factory AdminGetExperimentalControlsRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminGetExperimentalControlsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminGetExperimentalControlsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetExperimentalControlsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetExperimentalControlsRequest copyWith(
          void Function(AdminGetExperimentalControlsRequest) updates) =>
      super.copyWith((message) =>
              updates(message as AdminGetExperimentalControlsRequest))
          as AdminGetExperimentalControlsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminGetExperimentalControlsRequest create() =>
      AdminGetExperimentalControlsRequest._();
  @$core.override
  AdminGetExperimentalControlsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminGetExperimentalControlsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          AdminGetExperimentalControlsRequest>(create);
  static AdminGetExperimentalControlsRequest? _defaultInstance;

  /// Puste = wartosci globalne. Ustawione = wartosci SKUTECZNE dla tej
  /// organizacji, wraz z informacja, czy pochodza z nadpisania.
  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);
}

class AdminExperimentalControls extends $pb.GeneratedMessage {
  factory AdminExperimentalControls({
    $core.bool? enabled,
    $fixnum.Int64? dailyLimit,
    $core.bool? isOrgOverride,
    $core.String? note,
    $3.Timestamp? updatedAt,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (dailyLimit != null) result.dailyLimit = dailyLimit;
    if (isOrgOverride != null) result.isOrgOverride = isOrgOverride;
    if (note != null) result.note = note;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  AdminExperimentalControls._();

  factory AdminExperimentalControls.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminExperimentalControls.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminExperimentalControls',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..aInt64(2, _omitFieldNames ? '' : 'dailyLimit')
    ..aOB(3, _omitFieldNames ? '' : 'isOrgOverride')
    ..aOS(4, _omitFieldNames ? '' : 'note')
    ..aOM<$3.Timestamp>(5, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $3.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminExperimentalControls clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminExperimentalControls copyWith(
          void Function(AdminExperimentalControls) updates) =>
      super.copyWith((message) => updates(message as AdminExperimentalControls))
          as AdminExperimentalControls;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminExperimentalControls create() => AdminExperimentalControls._();
  @$core.override
  AdminExperimentalControls createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminExperimentalControls getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminExperimentalControls>(create);
  static AdminExperimentalControls? _defaultInstance;

  /// Czy organizacja moze generowac raporty na ontologii BEZ autoryzacji.
  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  /// Dobowy limit na terapeute. Potok wieloetapowy na Pro jest drogi, a
  /// dual-run podwaja koszt kazdej sesji.
  @$pb.TagNumber(2)
  $fixnum.Int64 get dailyLimit => $_getI64(1);
  @$pb.TagNumber(2)
  set dailyLimit($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDailyLimit() => $_has(1);
  @$pb.TagNumber(2)
  void clearDailyLimit() => $_clearField(2);

  /// True, gdy wartosci pochodza z nadpisania organizacji, a nie z
  /// wiersza globalnego.
  @$pb.TagNumber(3)
  $core.bool get isOrgOverride => $_getBF(2);
  @$pb.TagNumber(3)
  set isOrgOverride($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsOrgOverride() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsOrgOverride() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get note => $_getSZ(3);
  @$pb.TagNumber(4)
  set note($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNote() => $_has(3);
  @$pb.TagNumber(4)
  void clearNote() => $_clearField(4);

  @$pb.TagNumber(5)
  $3.Timestamp get updatedAt => $_getN(4);
  @$pb.TagNumber(5)
  set updatedAt($3.Timestamp value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasUpdatedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearUpdatedAt() => $_clearField(5);
  @$pb.TagNumber(5)
  $3.Timestamp ensureUpdatedAt() => $_ensure(4);
}

class AdminSetExperimentalControlsRequest extends $pb.GeneratedMessage {
  factory AdminSetExperimentalControlsRequest({
    $core.String? organizationId,
    $core.bool? enabled,
    $fixnum.Int64? dailyLimit,
    $core.String? note,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (enabled != null) result.enabled = enabled;
    if (dailyLimit != null) result.dailyLimit = dailyLimit;
    if (note != null) result.note = note;
    return result;
  }

  AdminSetExperimentalControlsRequest._();

  factory AdminSetExperimentalControlsRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminSetExperimentalControlsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminSetExperimentalControlsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..aOB(2, _omitFieldNames ? '' : 'enabled')
    ..aInt64(3, _omitFieldNames ? '' : 'dailyLimit')
    ..aOS(4, _omitFieldNames ? '' : 'note')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminSetExperimentalControlsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminSetExperimentalControlsRequest copyWith(
          void Function(AdminSetExperimentalControlsRequest) updates) =>
      super.copyWith((message) =>
              updates(message as AdminSetExperimentalControlsRequest))
          as AdminSetExperimentalControlsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminSetExperimentalControlsRequest create() =>
      AdminSetExperimentalControlsRequest._();
  @$core.override
  AdminSetExperimentalControlsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminSetExperimentalControlsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          AdminSetExperimentalControlsRequest>(create);
  static AdminSetExperimentalControlsRequest? _defaultInstance;

  /// Puste = zmiana wartosci globalnej; ustawione = nadpisanie dla
  /// organizacji. Wlaczanie globalne jest mozliwe, ale nie jest tym, po
  /// co ten przelacznik powstal — tryb ma dzialac na organizacji
  /// eksperckiej, nie u wszystkich.
  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  /// Zmieniane sa WYLACZNIE pola obecne. optional, nie wartosc domyslna:
  /// bez tego "zmien limit, zostaw flage" cicho przestawialoby flage.
  @$pb.TagNumber(2)
  $core.bool get enabled => $_getBF(1);
  @$pb.TagNumber(2)
  set enabled($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEnabled() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnabled() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get dailyLimit => $_getI64(2);
  @$pb.TagNumber(3)
  set dailyLimit($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDailyLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearDailyLimit() => $_clearField(3);

  /// Dlaczego. Wymagane przy kazdej zmianie — wpis audytowy bez powodu
  /// nie odpowiada na zadne pytanie, ktore ktos potem zada.
  @$pb.TagNumber(4)
  $core.String get note => $_getSZ(3);
  @$pb.TagNumber(4)
  set note($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNote() => $_has(3);
  @$pb.TagNumber(4)
  void clearNote() => $_clearField(4);
}

class AskPatientQuestionRequest extends $pb.GeneratedMessage {
  factory AskPatientQuestionRequest({
    $core.String? patientFileId,
    $core.String? question,
    $core.String? conversationId,
    $core.String? starterId,
    $core.bool? starterEdited,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (question != null) result.question = question;
    if (conversationId != null) result.conversationId = conversationId;
    if (starterId != null) result.starterId = starterId;
    if (starterEdited != null) result.starterEdited = starterEdited;
    return result;
  }

  AskPatientQuestionRequest._();

  factory AskPatientQuestionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AskPatientQuestionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AskPatientQuestionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..aOS(2, _omitFieldNames ? '' : 'question')
    ..aOS(3, _omitFieldNames ? '' : 'conversationId')
    ..aOS(4, _omitFieldNames ? '' : 'starterId')
    ..aOB(5, _omitFieldNames ? '' : 'starterEdited')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AskPatientQuestionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AskPatientQuestionRequest copyWith(
          void Function(AskPatientQuestionRequest) updates) =>
      super.copyWith((message) => updates(message as AskPatientQuestionRequest))
          as AskPatientQuestionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AskPatientQuestionRequest create() => AskPatientQuestionRequest._();
  @$core.override
  AskPatientQuestionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AskPatientQuestionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AskPatientQuestionRequest>(create);
  static AskPatientQuestionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get question => $_getSZ(1);
  @$pb.TagNumber(2)
  set question($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuestion() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuestion() => $_clearField(2);

  /// Conversation ID from GenerateSessionBrief or a prior
  /// AskPatientQuestion response. Empty = new conversation.
  @$pb.TagNumber(3)
  $core.String get conversationId => $_getSZ(2);
  @$pb.TagNumber(3)
  set conversationId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConversationId() => $_has(2);
  @$pb.TagNumber(3)
  void clearConversationId() => $_clearField(3);

  /// Starter prompt this text came from, if any (ADR v1.3 section 6).
  /// Set only when the therapist tapped a curated starter.
  @$pb.TagNumber(4)
  $core.String get starterId => $_getSZ(3);
  @$pb.TagNumber(4)
  set starterId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStarterId() => $_has(3);
  @$pb.TagNumber(4)
  void clearStarterId() => $_clearField(4);

  /// True when the therapist edited the starter text before sending.
  /// An UNEDITED starter has a known intent and curated wording, so the
  /// server may skip the classifier for it; an edited one never is.
  @$pb.TagNumber(5)
  $core.bool get starterEdited => $_getBF(4);
  @$pb.TagNumber(5)
  set starterEdited($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStarterEdited() => $_has(4);
  @$pb.TagNumber(5)
  void clearStarterEdited() => $_clearField(5);
}

/// Quote is a verbatim span of a decrypted transcript segment. The
/// verifier checks each one as a literal substring of its source before
/// the response leaves the server, so a quote here is evidence, not a
/// paraphrase the model believes it saw.
class Quote extends $pb.GeneratedMessage {
  factory Quote({
    $core.String? sessionId,
    $core.String? segmentId,
    $core.String? text,
    $core.String? speaker,
    $core.int? tsStartMs,
    $core.int? tsEndMs,
    $3.Timestamp? sessionAt,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (segmentId != null) result.segmentId = segmentId;
    if (text != null) result.text = text;
    if (speaker != null) result.speaker = speaker;
    if (tsStartMs != null) result.tsStartMs = tsStartMs;
    if (tsEndMs != null) result.tsEndMs = tsEndMs;
    if (sessionAt != null) result.sessionAt = sessionAt;
    return result;
  }

  Quote._();

  factory Quote.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Quote.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Quote',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'segmentId')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..aOS(4, _omitFieldNames ? '' : 'speaker')
    ..aI(5, _omitFieldNames ? '' : 'tsStartMs')
    ..aI(6, _omitFieldNames ? '' : 'tsEndMs')
    ..aOM<$3.Timestamp>(7, _omitFieldNames ? '' : 'sessionAt',
        subBuilder: $3.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Quote clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Quote copyWith(void Function(Quote) updates) =>
      super.copyWith((message) => updates(message as Quote)) as Quote;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Quote create() => Quote._();
  @$core.override
  Quote createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Quote getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Quote>(create);
  static Quote? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get segmentId => $_getSZ(1);
  @$pb.TagNumber(2)
  set segmentId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSegmentId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSegmentId() => $_clearField(2);

  /// Verbatim text. May contain pseudonymization tokens such as
  /// [MIEJSCOWOSC-A] — the transcript is redacted at rest (decision D2
  /// is open on whether to change that for this surface).
  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get speaker => $_getSZ(3);
  @$pb.TagNumber(4)
  set speaker($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSpeaker() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpeaker() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get tsStartMs => $_getIZ(4);
  @$pb.TagNumber(5)
  set tsStartMs($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTsStartMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearTsStartMs() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get tsEndMs => $_getIZ(5);
  @$pb.TagNumber(6)
  set tsEndMs($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTsEndMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearTsEndMs() => $_clearField(6);

  @$pb.TagNumber(7)
  $3.Timestamp get sessionAt => $_getN(6);
  @$pb.TagNumber(7)
  set sessionAt($3.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSessionAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearSessionAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $3.Timestamp ensureSessionAt() => $_ensure(6);
}

class AnswerSection extends $pb.GeneratedMessage {
  factory AnswerSection({
    $core.String? title,
    $core.String? body,
    $core.Iterable<Quote>? quotes,
    SectionKind? kind,
    $core.bool? userAuthored,
  }) {
    final result = create();
    if (title != null) result.title = title;
    if (body != null) result.body = body;
    if (quotes != null) result.quotes.addAll(quotes);
    if (kind != null) result.kind = kind;
    if (userAuthored != null) result.userAuthored = userAuthored;
    return result;
  }

  AnswerSection._();

  factory AnswerSection.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AnswerSection.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnswerSection',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'body')
    ..pPM<Quote>(3, _omitFieldNames ? '' : 'quotes', subBuilder: Quote.create)
    ..aE<SectionKind>(4, _omitFieldNames ? '' : 'kind',
        enumValues: SectionKind.values)
    ..aOB(5, _omitFieldNames ? '' : 'userAuthored')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerSection clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerSection copyWith(void Function(AnswerSection) updates) =>
      super.copyWith((message) => updates(message as AnswerSection))
          as AnswerSection;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AnswerSection create() => AnswerSection._();
  @$core.override
  AnswerSection createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AnswerSection getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnswerSection>(create);
  static AnswerSection? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  /// Model-authored prose. ALWAYS empty when kind is USER_ONLY.
  @$pb.TagNumber(2)
  $core.String get body => $_getSZ(1);
  @$pb.TagNumber(2)
  set body($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBody() => $_has(1);
  @$pb.TagNumber(2)
  void clearBody() => $_clearField(2);

  /// Grounding. For SECTION_KIND_HYPOTHESIS the server guarantees at
  /// least one quote: the schema handed to the model makes a hypothesis
  /// without a quote structurally unrepresentable.
  @$pb.TagNumber(3)
  $pb.PbList<Quote> get quotes => $_getList(2);

  @$pb.TagNumber(4)
  SectionKind get kind => $_getN(3);
  @$pb.TagNumber(4)
  set kind(SectionKind value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasKind() => $_has(3);
  @$pb.TagNumber(4)
  void clearKind() => $_clearField(4);

  /// True when this field belongs to the therapist. The schema sent to
  /// the model has no such field at all; the server appends it empty
  /// after validation.
  @$pb.TagNumber(5)
  $core.bool get userAuthored => $_getBF(4);
  @$pb.TagNumber(5)
  set userAuthored($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUserAuthored() => $_has(4);
  @$pb.TagNumber(5)
  void clearUserAuthored() => $_clearField(5);
}

/// SuggestedQuestion is an AI-proposed question for the therapist to
/// consider asking (ADR v1.2, A5). Grounded like any hypothesis, and put
/// through the verifier for smuggled diagnosis / medication / risk
/// content — a question is a cheap place to hide an assertion.
class SuggestedQuestion extends $pb.GeneratedMessage {
  factory SuggestedQuestion({
    $core.String? question,
    $core.Iterable<Quote>? quotes,
  }) {
    final result = create();
    if (question != null) result.question = question;
    if (quotes != null) result.quotes.addAll(quotes);
    return result;
  }

  SuggestedQuestion._();

  factory SuggestedQuestion.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SuggestedQuestion.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SuggestedQuestion',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'question')
    ..pPM<Quote>(2, _omitFieldNames ? '' : 'quotes', subBuilder: Quote.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SuggestedQuestion clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SuggestedQuestion copyWith(void Function(SuggestedQuestion) updates) =>
      super.copyWith((message) => updates(message as SuggestedQuestion))
          as SuggestedQuestion;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SuggestedQuestion create() => SuggestedQuestion._();
  @$core.override
  SuggestedQuestion createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SuggestedQuestion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SuggestedQuestion>(create);
  static SuggestedQuestion? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get question => $_getSZ(0);
  @$pb.TagNumber(1)
  set question($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuestion() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuestion() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<Quote> get quotes => $_getList(1);
}

class ChatAnswer extends $pb.GeneratedMessage {
  factory ChatAnswer({
    $core.Iterable<AnswerSection>? sections,
    $core.Iterable<SuggestedQuestion>? suggestedQuestions,
  }) {
    final result = create();
    if (sections != null) result.sections.addAll(sections);
    if (suggestedQuestions != null)
      result.suggestedQuestions.addAll(suggestedQuestions);
    return result;
  }

  ChatAnswer._();

  factory ChatAnswer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChatAnswer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatAnswer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..pPM<AnswerSection>(1, _omitFieldNames ? '' : 'sections',
        subBuilder: AnswerSection.create)
    ..pPM<SuggestedQuestion>(2, _omitFieldNames ? '' : 'suggestedQuestions',
        subBuilder: SuggestedQuestion.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatAnswer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatAnswer copyWith(void Function(ChatAnswer) updates) =>
      super.copyWith((message) => updates(message as ChatAnswer)) as ChatAnswer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatAnswer create() => ChatAnswer._();
  @$core.override
  ChatAnswer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChatAnswer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChatAnswer>(create);
  static ChatAnswer? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AnswerSection> get sections => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<SuggestedQuestion> get suggestedQuestions => $_getList(1);
}

/// ChatRefusal is a constructive refusal: one sentence plus up to three
/// offered alternatives. It never repeats the refusal text on retry.
class ChatRefusal extends $pb.GeneratedMessage {
  factory ChatRefusal({
    $core.String? message,
    $core.Iterable<RefusalAlternative>? alternatives,
    $core.bool? showCrisisInformation,
  }) {
    final result = create();
    if (message != null) result.message = message;
    if (alternatives != null) result.alternatives.addAll(alternatives);
    if (showCrisisInformation != null)
      result.showCrisisInformation = showCrisisInformation;
    return result;
  }

  ChatRefusal._();

  factory ChatRefusal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChatRefusal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatRefusal',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..pPM<RefusalAlternative>(2, _omitFieldNames ? '' : 'alternatives',
        subBuilder: RefusalAlternative.create)
    ..aOB(3, _omitFieldNames ? '' : 'showCrisisInformation')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatRefusal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatRefusal copyWith(void Function(ChatRefusal) updates) =>
      super.copyWith((message) => updates(message as ChatRefusal))
          as ChatRefusal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatRefusal create() => ChatRefusal._();
  @$core.override
  ChatRefusal createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChatRefusal getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChatRefusal>(create);
  static ChatRefusal? _defaultInstance;

  /// Localized single-sentence explanation.
  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);

  /// Offered alternatives, e.g. "conceptualization instead of diagnosis"
  /// for a P1 refusal.
  @$pb.TagNumber(2)
  $pb.PbList<RefusalAlternative> get alternatives => $_getList(1);

  /// Set for R_RISK: crisis information is always reachable and does not
  /// depend on the chat working.
  @$pb.TagNumber(3)
  $core.bool get showCrisisInformation => $_getBF(2);
  @$pb.TagNumber(3)
  set showCrisisInformation($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasShowCrisisInformation() => $_has(2);
  @$pb.TagNumber(3)
  void clearShowCrisisInformation() => $_clearField(3);
}

class RefusalAlternative extends $pb.GeneratedMessage {
  factory RefusalAlternative({
    ChatIntent? intent,
    $core.String? label,
    $core.String? prefill,
  }) {
    final result = create();
    if (intent != null) result.intent = intent;
    if (label != null) result.label = label;
    if (prefill != null) result.prefill = prefill;
    return result;
  }

  RefusalAlternative._();

  factory RefusalAlternative.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RefusalAlternative.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefusalAlternative',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aE<ChatIntent>(1, _omitFieldNames ? '' : 'intent',
        enumValues: ChatIntent.values)
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'prefill')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefusalAlternative clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefusalAlternative copyWith(void Function(RefusalAlternative) updates) =>
      super.copyWith((message) => updates(message as RefusalAlternative))
          as RefusalAlternative;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RefusalAlternative create() => RefusalAlternative._();
  @$core.override
  RefusalAlternative createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RefusalAlternative getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefusalAlternative>(create);
  static RefusalAlternative? _defaultInstance;

  /// Intent the alternative would run as.
  @$pb.TagNumber(1)
  ChatIntent get intent => $_getN(0);
  @$pb.TagNumber(1)
  set intent(ChatIntent value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasIntent() => $_has(0);
  @$pb.TagNumber(1)
  void clearIntent() => $_clearField(1);

  /// Localized button label.
  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  /// Pre-filled question text for the composer.
  @$pb.TagNumber(3)
  $core.String get prefill => $_getSZ(2);
  @$pb.TagNumber(3)
  set prefill($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPrefill() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrefill() => $_clearField(3);
}

/// ChatMeta is observability, not content. It carries nothing that could
/// reconstruct the question or the answer.
class ChatMeta extends $pb.GeneratedMessage {
  factory ChatMeta({
    ChatIntent? intent,
    $core.String? confidenceBucket,
    $core.String? degradeReason,
    $fixnum.Int64? costMicroUsd,
    $fixnum.Int64? quotaRemainingMicroUsd,
    $core.int? ragHitsUsed,
    $core.int? latencyMs,
  }) {
    final result = create();
    if (intent != null) result.intent = intent;
    if (confidenceBucket != null) result.confidenceBucket = confidenceBucket;
    if (degradeReason != null) result.degradeReason = degradeReason;
    if (costMicroUsd != null) result.costMicroUsd = costMicroUsd;
    if (quotaRemainingMicroUsd != null)
      result.quotaRemainingMicroUsd = quotaRemainingMicroUsd;
    if (ragHitsUsed != null) result.ragHitsUsed = ragHitsUsed;
    if (latencyMs != null) result.latencyMs = latencyMs;
    return result;
  }

  ChatMeta._();

  factory ChatMeta.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChatMeta.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatMeta',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aE<ChatIntent>(1, _omitFieldNames ? '' : 'intent',
        enumValues: ChatIntent.values)
    ..aOS(2, _omitFieldNames ? '' : 'confidenceBucket')
    ..aOS(3, _omitFieldNames ? '' : 'degradeReason')
    ..aInt64(4, _omitFieldNames ? '' : 'costMicroUsd')
    ..aInt64(5, _omitFieldNames ? '' : 'quotaRemainingMicroUsd')
    ..aI(6, _omitFieldNames ? '' : 'ragHitsUsed')
    ..aI(7, _omitFieldNames ? '' : 'latencyMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatMeta clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatMeta copyWith(void Function(ChatMeta) updates) =>
      super.copyWith((message) => updates(message as ChatMeta)) as ChatMeta;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatMeta create() => ChatMeta._();
  @$core.override
  ChatMeta createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChatMeta getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatMeta>(create);
  static ChatMeta? _defaultInstance;

  @$pb.TagNumber(1)
  ChatIntent get intent => $_getN(0);
  @$pb.TagNumber(1)
  set intent(ChatIntent value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasIntent() => $_has(0);
  @$pb.TagNumber(1)
  void clearIntent() => $_clearField(1);

  /// Bucketed, never the raw score — the raw value is a model artefact
  /// that invites over-reading.
  @$pb.TagNumber(2)
  $core.String get confidenceBucket => $_getSZ(1);
  @$pb.TagNumber(2)
  set confidenceBucket($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConfidenceBucket() => $_has(1);
  @$pb.TagNumber(2)
  void clearConfidenceBucket() => $_clearField(2);

  /// Why the answer was degraded, when it was: "low_conf" | "defined_ops"
  /// | "quota" | "verifier_block".
  @$pb.TagNumber(3)
  $core.String get degradeReason => $_getSZ(2);
  @$pb.TagNumber(3)
  set degradeReason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDegradeReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearDegradeReason() => $_clearField(3);

  /// Micro-USD charged for this turn, and what is left this period.
  @$pb.TagNumber(4)
  $fixnum.Int64 get costMicroUsd => $_getI64(3);
  @$pb.TagNumber(4)
  set costMicroUsd($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCostMicroUsd() => $_has(3);
  @$pb.TagNumber(4)
  void clearCostMicroUsd() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get quotaRemainingMicroUsd => $_getI64(4);
  @$pb.TagNumber(5)
  set quotaRemainingMicroUsd($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasQuotaRemainingMicroUsd() => $_has(4);
  @$pb.TagNumber(5)
  void clearQuotaRemainingMicroUsd() => $_clearField(5);

  /// Number of rag_memories rows used to preselect candidate sessions.
  @$pb.TagNumber(6)
  $core.int get ragHitsUsed => $_getIZ(5);
  @$pb.TagNumber(6)
  set ragHitsUsed($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRagHitsUsed() => $_has(5);
  @$pb.TagNumber(6)
  void clearRagHitsUsed() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get latencyMs => $_getIZ(6);
  @$pb.TagNumber(7)
  set latencyMs($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLatencyMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearLatencyMs() => $_clearField(7);
}

enum AskPatientQuestionResponse_Payload { answer, refusal, notSet }

class AskPatientQuestionResponse extends $pb.GeneratedMessage {
  factory AskPatientQuestionResponse({
    $core.String? conversationId,
    ChatOutcome? outcome,
    ChatAnswer? answer,
    ChatRefusal? refusal,
    ChatMeta? meta,
  }) {
    final result = create();
    if (conversationId != null) result.conversationId = conversationId;
    if (outcome != null) result.outcome = outcome;
    if (answer != null) result.answer = answer;
    if (refusal != null) result.refusal = refusal;
    if (meta != null) result.meta = meta;
    return result;
  }

  AskPatientQuestionResponse._();

  factory AskPatientQuestionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AskPatientQuestionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, AskPatientQuestionResponse_Payload>
      _AskPatientQuestionResponse_PayloadByTag = {
    3: AskPatientQuestionResponse_Payload.answer,
    4: AskPatientQuestionResponse_Payload.refusal,
    0: AskPatientQuestionResponse_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AskPatientQuestionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..oo(0, [3, 4])
    ..aOS(1, _omitFieldNames ? '' : 'conversationId')
    ..aE<ChatOutcome>(2, _omitFieldNames ? '' : 'outcome',
        enumValues: ChatOutcome.values)
    ..aOM<ChatAnswer>(3, _omitFieldNames ? '' : 'answer',
        subBuilder: ChatAnswer.create)
    ..aOM<ChatRefusal>(4, _omitFieldNames ? '' : 'refusal',
        subBuilder: ChatRefusal.create)
    ..aOM<ChatMeta>(5, _omitFieldNames ? '' : 'meta',
        subBuilder: ChatMeta.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AskPatientQuestionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AskPatientQuestionResponse copyWith(
          void Function(AskPatientQuestionResponse) updates) =>
      super.copyWith(
              (message) => updates(message as AskPatientQuestionResponse))
          as AskPatientQuestionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AskPatientQuestionResponse create() => AskPatientQuestionResponse._();
  @$core.override
  AskPatientQuestionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AskPatientQuestionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AskPatientQuestionResponse>(create);
  static AskPatientQuestionResponse? _defaultInstance;

  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  AskPatientQuestionResponse_Payload whichPayload() =>
      _AskPatientQuestionResponse_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get conversationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set conversationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConversationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearConversationId() => $_clearField(1);

  @$pb.TagNumber(2)
  ChatOutcome get outcome => $_getN(1);
  @$pb.TagNumber(2)
  set outcome(ChatOutcome value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOutcome() => $_has(1);
  @$pb.TagNumber(2)
  void clearOutcome() => $_clearField(2);

  @$pb.TagNumber(3)
  ChatAnswer get answer => $_getN(2);
  @$pb.TagNumber(3)
  set answer(ChatAnswer value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAnswer() => $_has(2);
  @$pb.TagNumber(3)
  void clearAnswer() => $_clearField(3);
  @$pb.TagNumber(3)
  ChatAnswer ensureAnswer() => $_ensure(2);

  @$pb.TagNumber(4)
  ChatRefusal get refusal => $_getN(3);
  @$pb.TagNumber(4)
  set refusal(ChatRefusal value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRefusal() => $_has(3);
  @$pb.TagNumber(4)
  void clearRefusal() => $_clearField(4);
  @$pb.TagNumber(4)
  ChatRefusal ensureRefusal() => $_ensure(3);

  @$pb.TagNumber(5)
  ChatMeta get meta => $_getN(4);
  @$pb.TagNumber(5)
  set meta(ChatMeta value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasMeta() => $_has(4);
  @$pb.TagNumber(5)
  void clearMeta() => $_clearField(5);
  @$pb.TagNumber(5)
  ChatMeta ensureMeta() => $_ensure(4);
}

class GenerateExperimentalReportRequest extends $pb.GeneratedMessage {
  factory GenerateExperimentalReportRequest({
    $core.String? sessionId,
    $core.String? modalityCode,
    $core.String? ontologyVersionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (modalityCode != null) result.modalityCode = modalityCode;
    if (ontologyVersionId != null) result.ontologyVersionId = ontologyVersionId;
    return result;
  }

  GenerateExperimentalReportRequest._();

  factory GenerateExperimentalReportRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateExperimentalReportRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateExperimentalReportRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'modalityCode')
    ..aOS(3, _omitFieldNames ? '' : 'ontologyVersionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateExperimentalReportRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateExperimentalReportRequest copyWith(
          void Function(GenerateExperimentalReportRequest) updates) =>
      super.copyWith((message) =>
              updates(message as GenerateExperimentalReportRequest))
          as GenerateExperimentalReportRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateExperimentalReportRequest create() =>
      GenerateExperimentalReportRequest._();
  @$core.override
  GenerateExperimentalReportRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateExperimentalReportRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateExperimentalReportRequest>(
          create);
  static GenerateExperimentalReportRequest? _defaultInstance;

  /// Sesja, ktorej transkrypcja posluzy za material. Musi miec
  /// transkrypcje — stare sesje sa GLOWNYM przypadkiem uzycia, bo
  /// kalibracja ekspercka zaczyna sie od istniejacego materialu.
  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  /// Kod modalnosci, ktorej ontologia obsluzy przebieg. Puste =
  /// modalnosc kartoteki. Rozne od niej pozwala na "raport CBT dla
  /// kartoteki PPT" — porownanie miedzymodalnosciowe wymaga jawnego
  /// wyboru, bo automat zawsze idzie za kartoteka.
  @$pb.TagNumber(2)
  $core.String get modalityCode => $_getSZ(1);
  @$pb.TagNumber(2)
  set modalityCode($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModalityCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearModalityCode() => $_clearField(2);

  /// Konkretna wersja ontologii, takze `draft`. Puste = najnowsza
  /// wersja wskazanej modalnosci.
  @$pb.TagNumber(3)
  $core.String get ontologyVersionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set ontologyVersionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOntologyVersionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearOntologyVersionId() => $_clearField(3);
}

class GenerateExperimentalReportResponse extends $pb.GeneratedMessage {
  factory GenerateExperimentalReportResponse({
    $core.String? requestId,
    $core.int? remainingToday,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (remainingToday != null) result.remainingToday = remainingToday;
    return result;
  }

  GenerateExperimentalReportResponse._();

  factory GenerateExperimentalReportResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateExperimentalReportResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateExperimentalReportResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'clinical.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aI(2, _omitFieldNames ? '' : 'remainingToday')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateExperimentalReportResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateExperimentalReportResponse copyWith(
          void Function(GenerateExperimentalReportResponse) updates) =>
      super.copyWith((message) =>
              updates(message as GenerateExperimentalReportResponse))
          as GenerateExperimentalReportResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateExperimentalReportResponse create() =>
      GenerateExperimentalReportResponse._();
  @$core.override
  GenerateExperimentalReportResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateExperimentalReportResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateExperimentalReportResponse>(
          create);
  static GenerateExperimentalReportResponse? _defaultInstance;

  /// Identyfikator ZAMOWIENIA, nie raportu: raport jeszcze nie
  /// istnieje. Klient uzywa go do skojarzenia z dokumentem inbox.
  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  /// Ile zamowien zostalo w dobowym limicie PO tym zamowieniu.
  @$pb.TagNumber(2)
  $core.int get remainingToday => $_getIZ(1);
  @$pb.TagNumber(2)
  set remainingToday($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRemainingToday() => $_has(1);
  @$pb.TagNumber(2)
  void clearRemainingToday() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
