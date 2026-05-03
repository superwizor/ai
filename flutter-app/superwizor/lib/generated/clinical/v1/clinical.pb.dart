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
    as $2;

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
    $2.Timestamp? consentGivenAt,
    $2.Timestamp? firstConsultationAt,
    $core.String? privateTherapistNotes,
    $2.Timestamp? createdAt,
    $2.Timestamp? updatedAt,
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
    ..aOM<$2.Timestamp>(11, _omitFieldNames ? '' : 'consentGivenAt',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(12, _omitFieldNames ? '' : 'firstConsultationAt',
        subBuilder: $2.Timestamp.create)
    ..aOS(13, _omitFieldNames ? '' : 'privateTherapistNotes')
    ..aOM<$2.Timestamp>(14, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(15, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $2.Timestamp.create)
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
  $2.Timestamp get consentGivenAt => $_getN(10);
  @$pb.TagNumber(11)
  set consentGivenAt($2.Timestamp value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasConsentGivenAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearConsentGivenAt() => $_clearField(11);
  @$pb.TagNumber(11)
  $2.Timestamp ensureConsentGivenAt() => $_ensure(10);

  @$pb.TagNumber(12)
  $2.Timestamp get firstConsultationAt => $_getN(11);
  @$pb.TagNumber(12)
  set firstConsultationAt($2.Timestamp value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasFirstConsultationAt() => $_has(11);
  @$pb.TagNumber(12)
  void clearFirstConsultationAt() => $_clearField(12);
  @$pb.TagNumber(12)
  $2.Timestamp ensureFirstConsultationAt() => $_ensure(11);

  @$pb.TagNumber(13)
  $core.String get privateTherapistNotes => $_getSZ(12);
  @$pb.TagNumber(13)
  set privateTherapistNotes($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasPrivateTherapistNotes() => $_has(12);
  @$pb.TagNumber(13)
  void clearPrivateTherapistNotes() => $_clearField(13);

  @$pb.TagNumber(14)
  $2.Timestamp get createdAt => $_getN(13);
  @$pb.TagNumber(14)
  set createdAt($2.Timestamp value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasCreatedAt() => $_has(13);
  @$pb.TagNumber(14)
  void clearCreatedAt() => $_clearField(14);
  @$pb.TagNumber(14)
  $2.Timestamp ensureCreatedAt() => $_ensure(13);

  @$pb.TagNumber(15)
  $2.Timestamp get updatedAt => $_getN(14);
  @$pb.TagNumber(15)
  set updatedAt($2.Timestamp value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasUpdatedAt() => $_has(14);
  @$pb.TagNumber(15)
  void clearUpdatedAt() => $_clearField(15);
  @$pb.TagNumber(15)
  $2.Timestamp ensureUpdatedAt() => $_ensure(14);
}

class Modality extends $pb.GeneratedMessage {
  factory Modality({
    $core.String? id,
    $core.String? systemCode,
    $core.String? displayName,
    $core.bool? isSupported,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (systemCode != null) result.systemCode = systemCode;
    if (displayName != null) result.displayName = displayName;
    if (isSupported != null) result.isSupported = isSupported;
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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
